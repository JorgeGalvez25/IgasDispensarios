# Hallazgos · PERF · Rendimiento (transversal)

> Anexo del [plan de optimización](../PLAN_OPTIMIZACION.md). Código auditado: `IgasDispensarios@26ccfb4`, `IgasDispensariosBridge@99edafd`. Las líneas pueden haber cambiado: ubica las rutinas por su nombre. Kairos (Marca 7) y Triton (Marca 10) quedan fuera de alcance: si el texto los menciona, es solo como contexto.

## Cómo funciona este módulo

1) Modelo de hilos. Lo verifiqué leyendo el código y la semántica de SvcMgr en D7. Los TTimer del .dfm se crean en el hilo principal (Application.CreateForm en el .dpr), así que sus OnTimer corren ahí. El socket queda en el hilo que lo activa primero: en Bennett es el hilo del servicio (ServiceExecute:276); en los otros 6 drivers es el hilo principal, porque lo activa Timer2Timer. El Bridge corre completo en el hilo del servicio, incluido TimerTimeout, que se crea en ServiceExecute:256. Los eventos de Async Pro llegan al hilo principal por mensajes. Esto último tiene certeza media: lo deduzco de que Gilbarco y Wayne 2W bombean el hilo principal para recibir bListo. Consecuencia: solo hay carreras reales en Bennett y en el arranque y el paro (ya reportadas: BEN-01, E2E-06, HYA-23, W2W-28). En los demás drivers el riesgo es la reentrada por ProcessRequests(False) (GIL-10, W2W-12), y cualquier bloqueo del hilo principal retrasa a la vez el sondeo serial y el socket.

2) Timer2 (200 ms) solo corre en los 7 drivers cuando no hay conexión o cuando estado<=0. En RUN, la cadencia hacia el Bridge (T_d) la marca Timer1 o la llegada de tramas serial:

   - Bennett y Wayne: un JSON por trama serial (~4-6/s).

   - PAM: un JSON por tick (~3-4/s).

   - Gilbarco y Wayne 2W: un JSON cada 3 ticks (≥190 ms; segundos si el tick incluye $50, $20 o CPREC).

   - HongYang: cada 3 ticks de 15 ms (~10-20/s, y casi siempre se envía, E2E-26).

   - Team: cada 750 ms.

3) Presupuesto de Timer1, con la resolución real de Windows de 15.6 ms. Ver ciclo_serial.

   - HongYang: 15→15.6 ms, más ≥31 ms de EsperaTransmision por comando.

   - Gilbarco y Wayne 2W: 50→~62.5 ms, un paso de una posición por tick. En Gilbarco una posición inactiva cuesta 3 ticks y solo uno de ellos hace E/S.

   - Team: se fija a 50 ms en Inicializar:662.

   - Bennett: 150 ms + RTT.

   - PAM y Wayne: 250 ms + RTT.

   - En Bennett, PAM, Team, Wayne y HongYang, cada OnTriggerAvail y cada ComandoConsola reinicia el intervalo.

4) Qué bloquea el hilo principal:

   - Reconexión: Sleep(500) + 101×Sleep(10), unos 1.6-2.1 s por intento.

   - EsperaMiliSeg: 300 ms en Bennett, 100-500 ms en PAM, 500 ms en Team y 250×4 o 1000 ms en Wayne.

   - Gilbarco: Sleep(5)+ProcessRequests y Sleep(GtwTiempoCmnd) por transacción.

   - Wayne 2W: espera activa al 100 % de un núcleo y envío byte a byte sin plazo (nuevo).

   - SaveToFile de anillos de 10 000 líneas con JSON (15-35 MB) en TRACE, MinutosLog o excepciones, unos 0.3-3 s según el disco.

5) Bridge. TimerTimeout (500 ms) hace poco trabajo: revisa la cabeza vencida y la obsolescencia. El timeout efectivo es de 2.0-2.5 s. Por cada mensaje del driver: copia al log, AnsiContainsText (dos copias del texto en mayúsculas), ParseText completo, Free del árbol anterior, recorrido de Peticiones y una sola respuesta. Estimo 0.5-3 ms con 16 posiciones (no medido).

6) Latencia estimada:

   - Comando con respuesta por folio: espera al siguiente mensaje del driver (0..T_d) más un T_d, o sea ~1.5·T_d de media y 2·T_d como máximo. HongYang ~0.1-0.2 s; Bennett, Gilbarco y Wayne 2W ~0.3-0.4 s nominales (segundos con el serial degradado); PAM y Wayne ~0.45 s; Team ~1.1 s (máximo 1.5 s más bloqueos) frente a un timeout de 2 s.

   - AUTHORIZE, PRICES y PAYMENT: OpenGas recibe la confirmación en ms (es falsa, BRG-02). El comando llega al driver en ≤T_d y luego sigue la secuencia serial: 0.1-0.6 s; ≥1 s en Team.

   - Ver un cambio de estatus: B global en ≤0.3 s (Bennett, PAM, Wayne). En Gilbarco y Wayne 2W las posiciones inactivas se visitan cada 3 vueltas: 1-3 s con 8-16 posiciones. HongYang revisa las mangueras inactivas cada 1-2 s. A todo esto se suma ≤T_d.

7) Costos de CPU, en orden: esperas activas; copia carácter por carácter y volcado de logs con JSON; Generate/Parse de JSON (0.3-2 ms por mensaje). Muy por debajo quedan, en µs: Delete(0) de TStringList (memmove de ~80 KB), colas TStringList de pocos elementos, ExtraeElemStrSep sobre tramas cortas, IntToHex por byte y FechaHoraExtToStr por línea. Field[] de uLkJSON usa un árbol balanceado, no búsqueda lineal; lo lineal es recorrer PosCarga.

8) Plan de medición:

   - Unidad común con QueryPerformanceCounter e histogramas fijos.

   - En los drivers: duración y periodo de Timer1 y Timer2, RTT serial por comando y posición, tiempo de vuelta y edad de la lectura por posición, GenerateText (µs y bytes), latencia de respuesta del Bridge, SaveToFile (ms y MB), líneas de log por segundo, GetHeapStatus y PrivateUsage.

   - En el Bridge: t_cola y t_driver por comando, ParseText, mensajes por segundo y edad del snapshot.

   - Una línea STAT cada 60 s con p50/p95/p99/máx.

   - Banco con el emulador de Wayne 2W y com0com + script para las demás marcas: 24 h por marca antes y después de cada cambio, más 7 días de prueba de memoria.

   - Criterios de aceptación: p95 de comando <600 ms (Team <1.2 s), 0 timeouts en operación normal, CPU <10 % y memoria estable.

### Ciclo serial

Bennett (Timer1 150 ms, ≈156 ms reales):

- Sin comando en curso envía 'B00', el estatus global de todas las posiciones.

- ComandoConsola (921/932) y pSerialTriggerAvail (951/982) apagan y encienden Timer1, lo que reinicia el intervalo. El periodo real es ~156 ms + RTT (~0.2 s).

- ProcesaLinea genera y envía el JSON en cada trama (1680-1681).

- La cola ListaCmnd avanza con cada respuesta.

- Espera fija: EsperaMiliSeg(300) en el reintento de preset.



Gilbarco 2W (Timer1 50 ms, ≈62.5 ms reales):

- Un paso de una posición por tick (NumPaso 0..7).

- Paso 1 (estatus $0x): 1 byte de ida y 1 de vuelta a ~5787 baud. La respuesta se detecta con Sleep(5)+ProcessRequests(False), es decir con granularidad de 15.6 ms.

- Una posición inactiva consume los ticks 1, 6 y 7 (≈190 ms).

- Las posiciones inactivas se visitan una de cada 3 vueltas (xCiclo); las que no tienen comunicación, cada 55-65 s.

- $40 y $50 transfieren 33-256 bytes (≈0.06-0.5 s). $20 lleva un bloque de datos byte a byte más Sleep(GtwTiempoCmnd) y Sleep(10).

- CPREC se ejecuta completo en un tick (GIL-05).

- JSON cada 3 ticks.



HongYang (Timer1 15 ms, ≈15.6 ms reales):

- Un comando por tick con la secuencia CmndProc A→N→V→Z→W.

- Cada envío cambia la paridad dos veces y bloquea en EsperaTransmision (≥2 cuantos, ≈31 ms).

- Mangueras inactivas cada 1-2 s (ProxSondeo); activas o con preset, siempre.

- Timeout de respuesta de 1 s; después, 5 s sin sondear esa manguera.

- GenerateText cada 3 ticks.



PAM (Timer1 250 ms):

- 'B00' global con NumPaso 0-4.

- Esperas contadas en ticks (11 para B00, 3-10 en los pasos 2-5).

- Cada trama reinicia Timer1.

- JSON en cada tick (2258).



Team (250 ms en el .dfm; Inicializar:662 lo fija a Max(15,Min(PausaCmnd,50)) = 50 ms):

- Un 'Bxx' por tick y por posición. Las inactivas se sondean cada 3 ciclos y las que tuvieron actividad reciente, en cada ciclo.

- PausaCmnd = 50 ms y MaxEsperaRspMs = 750 ms.

- Espera de 1250 ms después de un 'U'.

- JSON por tiempo, cada 750 ms.



Wayne (Timer1 250 ms):

- 'B' global; JSON en cada trama (1386).

- EsperaMiliSeg(250)×4 en CPREC y EsperaMiliSeg(1000) en el mapeo.

- ComandoConsolaBuff vacía la cola si el último envío fue hace más de 2 s.



Wayne 2W (Timer1 50 ms, ≈62.5 ms reales):

- Un paso por tick, como Gilbarco, pero ya salta los pasos 6 y 7 cuando no tienen trabajo.

- Envía byte a byte con espera activa sin plazo.

- La respuesta se espera con ProcessRequests(False) sin Sleep (100 % de un núcleo).

- JSON cada 3 ticks; watchdog de 2 s sobre horaAct.



Todos los drivers: Timer2 (200 ms) solo se activa sin conexión o con estado<=0. La reconexión bloquea ~1.6-2.1 s por intento.

### Contrato con el Bridge, visto desde este módulo

- **Conexión:** TCP (ini ServidorSocket, 127.0.0.1:1004 por omisión) con TClientSocket no bloqueante. Hilo del socket en el driver: el principal en 6 drivers, porque lo activa Timer2Timer; el hilo del servicio en Bennett. El Bridge atiende todo, incluido TimerTimeout, en el hilo del servicio.
- **Ciclo de envío:** En RUN la cadencia la marca Timer1 o la llegada de tramas serial, no Timer2: Bennett y Wayne, una vez por trama; PAM, una vez por tick (250 ms + RTT); Gilbarco y Wayne 2W, cada 3 ticks (≥190 ms); HongYang, cada 3 ticks de 15 ms; Team, cada 750 ms. El driver no espera la respuesta del Bridge antes de volver a enviar.
- **PING vs JSON:** El driver manda PING solo mientras respJson=False, es decir, antes de procesar el primer comando. Después manda siempre el JSON completo. El Bridge reconoce el PING buscando la subcadena (AnsiContainsText), lo que convierte a mayúsculas el JSON entero en cada mensaje.
- **Peticiones:** El Bridge entrega una sola petición por cada evento de lectura del driver, o '0\|DISPENSERS\|NOTHING' si no hay. El resultado regresa en Peticiones del JSON siguiente (como máximo 2 entradas). La latencia de un comando con respuesta por folio es ~1.5·T_d de media y 2·T_d como máximo.
- **Reconexión:** Timer2Timer hace Active:=True y espera con 101×Sleep(10). En Bennett y Wayne 2W lo precede un Sleep(500). Esa espera no puede ver OnConnect, porque bloquea el mismo hilo que debería procesarlo. Bennett y Wayne 2W tienen además un watchdog de 2 s sobre horaAct, medido con Now.
- **Comandos:**
  - NOTHING
  - INITIALIZE
  - PARAMETERS
  - LOGIN
  - LOGOUT
  - PRICES
  - AUTHORIZE
  - STOP
  - START
  - SELFSERVICE
  - FULLSERVICE
  - BLOCK
  - UNBLOCK
  - PAYMENT
  - TOTALS
  - HALT
  - RUN
  - SHUTDOWN
  - TERMINATE
  - TRACE
  - SAVELOGREQ
  - RESPCMND
  - LOG
  - LOGREQ
- **Campos JSON:**
  - Estado
  - PosCarga[].DispenserId
  - PosCarga[].HoraOcc
  - PosCarga[].Manguera
  - PosCarga[].Combustible
  - PosCarga[].Estatus
  - PosCarga[].Importe
  - PosCarga[].Volumen
  - PosCarga[].Precio
  - PosCarga[].Hoses[].HoseId
  - PosCarga[].Hoses[].ProductId
  - PosCarga[].Hoses[].Total
  - PosCarga[].TotalesEstimados (solo Gilbarco)
  - Peticiones[].Folio
  - Peticiones[].Resultado
- **Desviaciones respecto a otros drivers:**
  - Team envía cada 750 ms: es el T_d más largo y deja ~0.5-1 s de margen frente al timeout efectivo de 2.0-2.5 s.
  - HongYang genera el JSON cada 3 ticks de 15 ms y casi siempre lo envía (E2E-26).
  - Bennett y Wayne envían un JSON por trama serial, también por los ACK/NAK.
  - Gilbarco y Wayne 2W envían por número de ticks, no por tiempo, así que la cadencia depende de lo que dure cada tick.
  - Los manejadores de RUN y de '0'/'1' mandan además un envío inmediato fuera del ciclo (Bennett 1918, Wayne 2792/2799, Wayne 2W 3701, PAM 398/405).

### Bloques duplicados con otros módulos

| Rutina | Líneas | Nota |
|---|---|---|
| Timer2Timer (reconexión con Sleep y envío PING/JSON) | BENNETT 575-615; GILBARCO 3071-3112; HONGYANG 2025-2059; PAM 319-353; TEAM 354-389; WAYNE 2917-2952; WAYNE2W 3892-3933 | Es el mismo bloque en los 7 drivers: Active:=True y 101×Sleep(10) en el hilo principal, sin poder ver OnConnect. Corregir la espera, o fijar la resolución del temporizador, exige tocar 7 copias. Conviene moverlo a la unidad común de E2E-41. |
| AgregaLog / AgregaLogPetRes (copia carácter por carácter, anillo de 10 000 líneas) | BENNETT 617-655; GILBARCO 355-409; HONGYANG 416-487; PAM 599-637; TEAM 1412-1438; WAYNE 346-364, 823-844; WAYNE2W 459-511; UIGASBRIDGE 439-457, 776-783 | Es la ruta caliente de bitácora en todos los módulos: FechaHoraExtToStr por línea, escapado carácter por carácter y Delete(0). Cualquier mejora (registrar el JSON solo cuando cambie, escritura incremental, métricas de líneas por segundo) hay que repetirla en 8 lugares. |
| ActualizaCampoJSON (recorrido de PosCarga con Field['DispenserId'] por posición) | BENNETT 473-518; GILBARCO 3230-3278; HONGYANG 2758-2805; PAM 504-548; TEAM 501-533; WAYNE 2169-2216; WAYNE2W 3215-3262 | Las 7 copias hacen el mismo trabajo O(N) por campo, con copias de WideString y comparaciones Variant. Un índice de nodos por posición (array[1..32] de referencias) eliminaría el costo en todos a la vez. |

## Hallazgos (8)

<a id="PERF-01"></a>
#### PERF-01 · 🟡 Media (originalmente alta) · robustez · bug — Amplía W2W-14: el envío byte a byte espera OutBuffUsed=0 sin plazo ni salida; si el puerto deja de vaciarse, el hilo principal queda colgado

- **Ubicación:** `IgasDispensarios/UIGASWAYNE2W.pas` líneas 1201-1206, 3046-3051 (comparar con UIGASGILBARCO.pas 1259-1261, 1352-1354)
- **Módulos afectados:** UIGASWAYNE2W.pas
- **Se atiende en:** [E1.3](../PLAN_OPTIMIZACION.md#e13--sondeo-que-se-congela-livelocks-y-bloqueos-de-la-máquina-de-estados)
- **Verificación:** ☑️ confirmado parcialmente por un verificador (ver nota) — Lo que se confirma: en UIGASWAYNE2W.pas 1201-1206 (pSerial) y 3046-3051 (pSerial2) hay un bucle 'repeat ProcessCommunications until OutBuffUsed=0' por cada byte. No tiene plazo, no revisa Open y no bombea mensajes; la única salida es una excepción. En cambio, la espera de respuesta que sigue (1207-1211 y 3052-3056) sí tiene timerexpired y 'not pSerial.Open'. Gilbarco acota esa misma espera con timerexpired(etTimeOut) en 1259-1261 y 1352-1354, y también en 1363. Las llamadas corren en el hilo principal: Timer1Timer (2624) y Timer2Timer (3892) son TTimer del .dfm creados con Application.CreateForm (PDISPENSARIOS.dpr 58), y el socket se activa en Timer2Timer, línea 3907; las líneas 2635 y 3903 solo lo desactivan. Ninguna otra ruta puede romper el bucle: ServiceStop (3167-3171) y ServiceShutdown solo llaman a GuardarLog(0) y no cierran el puerto. Si el bucle se cuelga, el servicio puede reportar csStopped, pero el hilo principal no atiende el WM_QUIT y el proceso se queda con el COM. Esa parte del razonamiento se sostiene.
Lo que cambia: 1) Que el bucle no termine depende de cómo se comporte Async Pro cuando falla WriteFile o se retira el dispositivo. Eso no se puede verificar porque la biblioteca no está en el repo. HongYang 1136 compara OutBuffUsed con ClearCommError.cbOutQue, lo que sugiere que OutBuffUsed mide solo el búfer interno de APRO; queda atascado únicamente si su hilo de salida deja de vaciarlo ante el error. 2) El control de flujo por hardware no está configurado: UIGASWAYNE2W.dfm 12-44 no define HWFlowOptions ni SWFlowOptions, y el código no los modifica. Ese disparador es hipotético y exigiría cambiar la configuración. En operación normal el UART se vacía siempre. 3) El patrón viene del commit inicial 8ba4373 y no es exclusivo de Wayne 2W: Kairos tiene el mismo bucle sin plazo en UIGASKAIROS.pas 1946-1950, 2012-2016 y 2040-2044, así que el alcance es mayor. 4) Hay 35 llamadas reales a TransmiteComando1/2(DataBlock); 41 es el total de menciones, que incluye declaraciones, definiciones y logs. 5) No se sostienen sin la fuente de APRO dos afirmaciones: que los eventos de Async Pro corren en ese mismo hilo y que el giro quita cuantos completos de 20-120 ms en un equipo de un núcleo (ProcessCommunications podría ceder con Sleep(0)); son especulativas.
Por qué baja a media: la falta de salida es un defecto seguro de robustez. Pero el cuelgue solo ocurre si coinciden una falla de hardware y un comportamiento no verificado de la biblioteca. Además, el Bridge detecta los datos obsoletos a los 5 s, así que OpenGas no recibe datos falsos, solo errores. Si se agrega el plazo, la recuperación sí sería posible: HALT/RUN cierran y reabren el puerto (Detener 3480-3495, apertura 3637-3643), algo que hoy el cuelgue impide. Las recomendaciones de plazo y registro son válidas; revisar 'not pSerial.Open' ayuda poco, porque APRO no cierra el puerto solo cuando se retira el dispositivo.
- **Qué pasa:**
  W2W-14 trata el consumo de CPU de esta espera. Aquí el problema es otro: la espera puede no terminar nunca. En TransmiteComando1 y TransmiteComando2, por cada byte se hace PutChar y después 'repeat pSerial.ProcessCommunications until pSerial.OutBuffUsed=0', sin timerexpired, sin revisar pSerial.Open y sin bombear mensajes. Gilbarco tiene el mismo diseño pero sí acota la espera con timerexpired(etTimeOut).
  Si el búfer de salida no se vacía, el bucle no sale. Puede pasar si el adaptador USB-serial se desconecta o se reinicia por ruido eléctrico, si su controlador se cuelga o si alguien activa control de flujo por hardware. En ese mismo hilo corren Timer1, Timer2, el socket al Bridge (lo activa Timer2Timer en el hilo principal, 3907) y los eventos de Async Pro. El servicio deja de sondear y de hablar con el Bridge, pero el SCM lo sigue viendo en ejecución porque el hilo del servicio está vivo. Al pedir el paro, ese hilo termina, pero el principal sigue en el bucle: el proceso no se cierra y retiene el COM, así que reiniciar el servicio falla hasta matar el proceso.
  Certeza: el bucle sin salida es seguro. No verifiqué si Async Pro deja OutBuffUsed>0 tras retirar el dispositivo (la biblioteca no está en el repo); hay que probarlo en banco. Además, a prioridad normal y en un equipo de un núcleo, este giro le quita cuantos completos (20-120 ms) al Bridge y a OpenGas.
- **Evidencia:** UIGASWAYNE2W.pas 1201-1206: 'for i:= 1 to length ( DataBlock ) do begin pSerial.PutChar(DataBlock[i]); repeat pSerial.ProcessCommunications; until ( pSerial.OutBuffUsed=0 ); end;'. Igual para pSerial2 en 3046-3051. Todo el tráfico serial de Wayne 2W pasa por TransmiteComando1/2 (41 llamadas). En cambio, Gilbarco 1259-1261 usa 'until ((pSerial.OutBuffUsed = 0) or (timerexpired(etTimeOut)))'. El socket se activa en Timer2Timer (3907), en el hilo principal.
- **Impacto:** La isla queda sin control hasta que alguien intervenga a mano. El Bridge responde 'Datos obsoletos' a los 5 s y OpenGas no puede vender ni cobrar en esas posiciones. Reiniciar desde el SCM no basta.
- **Recomendación:**
  1) Escribir la trama completa con pSerial.PutString(DataBlock) (o PutBlock) después de verificar OutBuffFree>=Length(DataBlock).
  2) Esperar el vaciado con plazo: newtimer(etTimeOut,MSecs2Ticks(GtwTimeout)); repeat ... until (OutBuffUsed=0) or timerexpired(etTimeOut) or (not pSerial.Open).
  3) Si vence el plazo: registrar en el log, hacer FlushOutBuffer, devolver False y contar las fallas consecutivas. Tras N fallas, cerrar y reabrir el puerto desde Timer1, no dentro de un except.
  4) Agregar un latido de Timer1 (marca monotónica) que el hilo del servicio vigile; si pasa de 30 s, registrar la alarma y, si así se configura, terminar el proceso para que la política de recuperación del SCM lo reinicie.
  Prueba: en banco, desconectar el adaptador USB-serial durante el sondeo. El servicio debe seguir contestando al Bridge, registrar la falla y recuperarse al reconectar.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="PERF-02"></a>
#### PERF-02 · 🟡 Media · robustez · bug — Esperas, reintentos y watchdogs se miden con la hora de pared (Now): un ajuste del reloj congela el sondeo, retiene estados o provoca desconexiones

- **Ubicación:** `IgasDispensarios/UIGASHONGYANG.pas` líneas 1319, 1900-1901, 1983-1996 (además BENNETT 1129-1132, 2086; TEAM 1608, 1617, 2287-2292, 2313; GILBARCO 2548, 2569, 2612, 2620; WAYNE 2133-2135; WAYNE2W 2633-2638, 2664; UIGASBRIDGE 190-191, 409-412, 519-520)
- **Módulos afectados:** UIGASHONGYANG.pas, UIGASBENNETT.pas, UIGASTEAM.pas, UIGASGILBARCO.pas, UIGASWAYNE.pas, UIGASWAYNE2W.pas, UIGASBRIDGE.pas
- **Se atiende en:** [E2.9](../PLAN_OPTIMIZACION.md#e29--tiempos-monotónicos-y-resolución-del-temporizador)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  Ningún módulo usa un reloj monotónico: no aparecen GetTickCount, timeGetTime ni QueryPerformanceCounter para medir intervalos. Todos los plazos se calculan con Now, la hora local de Windows, así que cualquier cambio de hora los mueve a todos a la vez. Causas posibles: corrección manual del reloj, Windows Time cuando corrige por salto, cambio de la pila CMOS, o el horario de verano que sigue vigente en los municipios de la frontera norte.
  Hay dos patrones:
  (a) Restas directas (Now-HoraX) o comparaciones Now>=HoraProx. Si el reloj retrocede, el plazo se alarga lo que dure el salto (p.ej. 1 h).
  (b) SecondsBetween o MilliSecondsBetween de DateUtils, que usan valor absoluto. Cualquier salto mayor que el umbral, hacia adelante o hacia atrás, dispara el watchdog de inmediato.
  Certeza alta sobre el mecanismo, porque se lee directo en el código. La frecuencia depende del sitio.
- **Evidencia:**
  HONGYANG:
  - 1319: 'if (estatus in [7,8])and((now-HoraFV)>10*tmsegundo)'.
  - 1900-1901: 'if (Now>=ProxSondeo)or(Estatus>1)... ProxSondeo:=Now+IfThen(modoPreset,2,1)*TmSegundo'.
  - 1983/1987: '((Now-TimeResp)>TmSegundo*0.5)' y '((Now-TimeCmnd)>TmSegundo)'.
  BENNETT:
  - 1129-1132: 'HoraFinv:=Now; if (Now-HoraFinv)>=(SegundosFinv*tmSegundo) then ComandoConsolaBuff(J..)'.
  - 2086: 'SecondsBetween(Now,horaAct)>=2'.
  TEAM:
  - 1608: 'HoraFinEsperaU:=IncMilliSecond(Now,MsEsperaCambioPrecio)'.
  - 2313: 'if Now<HoraFinEsperaU then exit'.
  - 2292: '(now-HoraComandoB>5*TmSegundo)' provoca el Reset del COM.
  GILBARCO:
  - 2569: '(Now >= HoraNivelPrecio)'.
  - 2548: '((now - horaespera) > 3 * tmsegundo)'.
  WAYNE:
  - 2133-2135: 'if SecondsBetween(HoraEnvioPuerto,Now)>2 then begin ListaCmnd.Clear;'.
  WAYNE2W:
  - 2633-2637: 'SecondsBetween(Now,horaAct)>=2' cierra el socket y apaga Timer1.
  BRIDGE:
  - 191: TryPopExpired con SecondsBetween.
  - 409-411: 'if SecondsBetween(Now, horaAct)>=10 then begin CancelarPeticiones(...); SSocketOG.Active:=False;'.
  - 519-520: DatosObsoletos.
- **Impacto:**
  HongYang: si el reloj retrocede 1 h, las mangueras inactivas no se sondean durante esa hora (no se ve la pistola levantada ni un despacho sin preset). Las posiciones en 7/8 (fin de carga, publicado como 3) no vuelven a 1 a los 10 s. Si se pierde una respuesta durante el salto, el ciclo serial completo queda esperando.
  Bennett: el 'J' automático del fin de venta (30 s) se retrasa lo que dure el salto.
  Team: si el salto cae dentro de los 1.25 s posteriores a un cambio de precios, se suspende el sondeo. Un salto hacia adelante de más de 5 s ejecuta el Reset del COM.
  Wayne: se vacía ListaCmnd y se pierden en silencio los presets y precios encolados.
  Bennett y Wayne 2W: el watchdog cierra el socket y detiene el sondeo hasta reconectar (E2E-05).
  Bridge: la petición en vuelo vence al instante. Si llega un comando de OpenGas antes del siguiente mensaje del driver tras un salto de 10 s o más, se cancelan todas las peticiones y se cierra SSocketOG, con lo que se desconectan todos los clientes de OpenGas.
- **Recomendación:**
  1) Crear una unidad común (UTiempo.pas, igual en ambos repos) con 'function MsMonotonico: Int64', basada en QueryPerformanceCounter. Otra opción es GetTickCount con resta Cardinal, que tolera el desborde de 49.7 días.
  2) Sustituir por milisegundos monotónicos todas las marcas que miden intervalos: horaAct, HoraEnvio, HoraEnvioPuerto, ProxSondeo, HoraFV, HoraFinv, TimeCmnd, TimeResp, HoraFinEsperaU, HoraComandoB/HoraRspB, horaespera, HoraNivelPrecio, horaUltimoDatoReal y horaUltimoAutoKick.
  3) Conservar Now solo para HoraOcc, los nombres de archivo y los logs.
  4) Avanzar driver por driver, empezando por HongYang y Bennett.
  Prueba en banco: durante el sondeo y con una venta en curso, adelantar y atrasar el reloj 1 h. Verificar que no se cae la conexión con el Bridge, que las mangueras inactivas se siguen sondeando, que 'J' y la salida de FINV ocurren a los 30 s y 10 s, y que no se pierden comandos encolados.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="PERF-03"></a>
#### PERF-03 · 🟡 Media · rendimiento · optimizacion — Los plazos del código suponen precisión de milisegundos, pero Windows redondea TTimer, Sleep y Now a ~15.6 ms; el resultado cambia según el equipo y los otros procesos

- **Ubicación:** `IgasDispensarios/UIGASGILBARCO.pas` líneas 1268-1271, 1334, 1340, 1356, 1365-1368, 3082-3087; UIGASGILBARCO.dfm 22 (además HONGYANG 1129-1141, .dfm 18; TEAM 662, 1618, 2317, 2322; WAYNE2W .dfm 27, 1208, 3906-3911; reconexión BENNETT 588-593, HONGYANG 2033-2037, PAM 327-331, TEAM 362-366, WAYNE 2926-2930)
- **Módulos afectados:** UIGASGILBARCO.pas, UIGASHONGYANG.pas, UIGASTEAM.pas, UIGASWAYNE2W.pas, UIGASBENNETT.pas, UIGASPAM.pas, UIGASWAYNE.pas
- **Se atiende en:** [E2.9](../PLAN_OPTIMIZACION.md#e29--tiempos-monotónicos-y-resolución-del-temporizador)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  Ningún módulo llama a timeBeginPeriod (lo comprobé con grep). Con la resolución por omisión de Windows (64 Hz, 15.625 ms), SetTimer, Sleep y la hora de GetLocalTime (Now) avanzan en saltos de ~15.6 ms. Efectos en el presupuesto de tiempo:
  (1) Gilbarco espera cada respuesta con 'repeat Sleep(5); ServiceThread.ProcessRequests(False) until bListo...'. Una respuesta de estatus de 1 byte, que llega en ~2-4 ms, se detecta hasta los ~15.6 ms. Timer1 de 50 ms dura ~62.5 ms; lo mismo pasa en Wayne 2W y en Team, que en 662 fija Timer1.Interval:=Max(15,Min(PausaCmnd,50)).
  (2) HongYang (amplía HYA-24): EsperaTransmision hace Sleep(1) y luego Sleep(22000 div Baud+1), que es Sleep(3) a 9600. Son dos cuantos, ≈31 ms por comando en vez de ~4 ms, lo que limita el ritmo a ~25-30 comandos/s.
  (3) PausaCmnd y MaxEsperaRspMs de Team se miden con MilliSecondsBetween(Now,...), con la misma granularidad.
  (4) Los bucles de reconexión de 101×Sleep(10) bloquean ~1.58 s en lugar de 1.01 s.
  (5) Los timeouts de Async Pro (newtimer/MSecs2Ticks) se expresan en ticks de APro, de ~55 ms por convención de la biblioteca. Certeza media, porque OoMisc.pas no está en el repo.
  Además, en Windows 7, POSReady y Windows 10 anterior a la versión 2004, la resolución es global: si otro proceso del equipo (la interfaz de OpenGas, un navegador, SQL Server) llamó timeBeginPeriod(1), esos mismos Sleep duran 1-5 ms. El comportamiento serial cambia entre estaciones y entre momentos sin que cambie el código, lo que vuelve irreproducibles algunos fallos de tiempo.
- **Evidencia:**
  Gilbarco 1268-1271: 'repeat Sleep(5); ServiceThread.ProcessRequests(False); until ((bListo) or (timerexpired(etTimeOut)) or (not pSerial.Open));'. Igual en 1365-1368. Hay sleep(GtwTiempoCmnd) en 1334 y 1356 y sleep(10) en 1340.
  HongYang 1134-1140: 'for i:=1 to 100 do begin ClearCommError(...); if (pSerial.OutBuffUsed=0)and(stat.cbOutQue=0) then Break; Sleep(1); end; Sleep(22000 div pSerial.Baud+1);'.
  Team 662: 'Timer1.Interval:=Max(15,Min(PausaCmnd,50));'.
  Intervalos en los .dfm: HongYang 15, Gilbarco 50, Wayne 2W 50, Bennett 150, PAM, Team y Wayne 250.
  Reconexión, p.ej. PAM 328-331: 'for i:=0 to 100 do begin Sleep(10); if conectado then Break; end;'.
  No hay timeBeginPeriod en ningún .pas.
- **Impacto:** Entre el 20 % y el 25 % del ciclo de Gilbarco, Wayne 2W y Team es cuantización: 62.5 ms por tick en vez de 50, y 15.6 ms por espera en vez de 5. HongYang pasa ~60 % de cada comando dormido. Cada intento de reconexión bloquea el hilo principal (sondeo y socket) ~1.6-2.1 s. Además, el comportamiento no es reproducible de un equipo a otro.
- **Recomendación:**
  1) Llamar timeBeginPeriod(1) (unidad MMSystem) al inicio de ServiceExecute en PDISPENSARIOS, y timeEndPeriod(1) al salir y en OnStop/OnShutdown. Al arrancar, registrar la resolución efectiva midiendo 100×Sleep(1) con QueryPerformanceCounter.
  2) Antes de activarlo, hacer configurables las esperas que pudieron calibrarse a mano con 15.6 ms: GtwTiempoCmnd, el retardo posterior al cambio de paridad de HongYang y PausaCmndTeam.
  3) A mediano plazo, reemplazar Sleep+bombeo por una espera sobre un TEvent que se active en OnTriggerAvail (WaitForSingleObject o MsgWaitForMultipleObjects, con 1 ms de resolución). Esto también elimina la espera activa de Wayne 2W.
  Validar en banco por marca con el plan de medición: RTT por comando, ticks por segundo, tiempo de vuelta, CPU y contadores de BCC y timeout, antes y después. En HongYang, confirmar que no aumentan los errores de paridad con adaptadores USB-serial.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="PERF-04"></a>
#### PERF-04 · 🟡 Media · memoria_recursos · riesgo — Los dos servicios usan el administrador de memoria de Delphi 7 con un patrón de asignación de alto recambio: riesgo de fragmentación y de EOutOfMemory al volcar los logs

- **Ubicación:** `IgasDispensarios/PDISPENSARIOS.dpr` líneas 3-20 (uses sin FastMM); IgasDispensariosBridge/PDISPBRIDGE.dpr 3-6; uLkJSON.pas 1480-1497, 1617-1622; UIGASBRIDGE.pas 742, 753-754, 798, 812-814, 866
- **Módulos afectados:** PDISPENSARIOS.dpr, PDISPBRIDGE.dpr, uLkJSON.pas, UIGASBRIDGE.pas, UIGASBENNETT.pas, UIGASGILBARCO.pas, UIGASHONGYANG.pas, UIGASPAM.pas, UIGASTEAM.pas, UIGASWAYNE.pas, UIGASWAYNE2W.pas
- **Se atiende en:** [E4.5](../PLAN_OPTIMIZACION.md#e45--ulkjson-y-administrador-de-memoria)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  Ninguno de los dos .dpr incluye FastMM4 ni otro reemplazo. Ambos usan el administrador de memoria original de Delphi 7, en un proceso de 32 bits limitado a 2 GB. Delphi 2006 lo sustituyó justo por su fragmentación y su lentitud en procesos de larga vida con muchos bloques medianos y grandes. Estos servicios son el peor caso:
  (1) Cada GenerateText reserva 50 000 bytes con AllocMem (que los pone en cero), copia el resultado a un string y libera el búfer. También crea y destruye un TlkJSONstring con su WideString por cada nombre de campo. Ocurre 5-20 veces por segundo.
  (2) AgregaLog y AgregaLogPetRes hacen crecer el string carácter por carácter, con un ReallocMem por carácter, sobre JSON de 3-7 KB.
  (3) El Bridge, en cada mensaje del driver, construye un árbol completo con ParseText (cientos de objetos, WideStrings y nodos) y libera el anterior.
  (4) Los anillos de 10 000 líneas ocupan ~15-35 MB por lista, porque la mitad de las líneas son JSON completos.
  (5) TStringList.SaveToFile primero arma un único string con todo el texto (TStrings.GetTextStr) y luego lo escribe. Necesita un bloque contiguo de ese tamaño en cada TRACE, MinutosLog o excepción.
  Certeza: el mecanismo es seguro; el grado real de fragmentación no se ha medido.
- **Evidencia:**
  PDISPENSARIOS.dpr 3-20 enumera SvcMgr, IniFiles, SysUtils y las unidades del proyecto, sin FastMM4. PDISPBRIDGE.dpr 3-6 usa SvcMgr, UVersionModulo y UIGASBRIDGE.
  uLkJSON 1482-1486: 'delta := 50000; if pt0 = nil then begin pt0 := AllocMem(delta); ...'. En 1617-1622: 'pt0 := nil; get_more_memory; gn_base(obj); mem_ch(#0); result := string(pt0); freemem(pt0);'.
  Bridge 812-814: 'if Assigned(rootJSON) then rootJSON.Free; rootJSON := nuevoJSON;' en cada mensaje que no es PING. ListaLogPDisp guarda 'R '+JSON por cada mensaje (754) y se vuelca con SaveToFile (866).
- **Impacto:** Tras semanas de operación crecen la memoria y la latencia de asignación. En un espacio de direcciones fragmentado, un SaveToFile de decenas de MB puede fallar con EOutOfMemory dentro de un except, justo donde ya se reportaron recursiones GuardarLog/GuardarLogPetRes (GIL-26, HYA-14, WAY-15) que pueden terminar el proceso. También encarece los patrones O(n²) de concatenación carácter por carácter.
- **Recomendación:**
  1) Agregar FastMM4 (versión 4.99x, compatible con Delphi 7) como primera unidad del uses de PDISPENSARIOS.dpr y PDISPBRIDGE.dpr. En las compilaciones de QA, activar FullDebugMode y el reporte de fugas al cerrar; detectará, entre otras, los árboles de INITIALIZE que nunca se liberan.
  2) Cada 10 min, registrar GetHeapStatus (TotalAddrSpace, TotalAllocated, TotalFree, FreeBig, Unused), o GetMemoryManagerState si ya se usa FastMM. Registrar también PrivateUsage de GetProcessMemoryInfo y el mayor bloque libre de memoria virtual (recorriendo VirtualQuery).
  3) Hacer una prueba de resistencia de 7 días en banco, antes y después, con el driver a la tasa real y TRACE periódicos.
  4) Reducir el recambio en el origen: registrar el JSON solo cuando cambie, no reparsear snapshots idénticos y escribir el log en modo append en lugar de SaveToFile.
  Riesgo: FastMM puede sacar a la luz accesos a memoria ya liberada que hoy pasan desapercibidos (p.ej. punteros de socket colgantes, BRG-14). Por eso conviene la fase de QA con FullDebugMode.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="PERF-05"></a>
#### PERF-05 · 🟡 Media · rendimiento · optimizacion — uLkJSON tiene costos ocultos por llamada (copias de WideString, objetos temporales, configuración regional y búfer de 50 KB), y el Bridge reparsea snapshots idénticos

- **Ubicación:** `IgasDispensarios/uLkJSON.pas (copia idéntica en IgasDispensariosBridge)` líneas 165, 203, 421, 434, 1086-1102, 1104-1127, 1250-1256, 1480-1497, 1517-1608 (1537, 1587-1595), 1611-1622, 1891-1925, 1927-1960, 1962-1996, 1998-2009, 2014-2016, 2547-2559; UIGASBRIDGE.pas 753-758, 798, 812-814
- **Módulos afectados:** uLkJSON.pas, UIGASBRIDGE.pas, UIGASBENNETT.pas, UIGASGILBARCO.pas, UIGASHONGYANG.pas, UIGASPAM.pas, UIGASTEAM.pas, UIGASWAYNE.pas, UIGASWAYNE2W.pas
- **Se atiende en:** [E4.5](../PLAN_OPTIMIZACION.md#e45--ulkjson-y-administrador-de-memoria)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  Amplía E2E-25 y precisa BRG-38/BEN-13: Field[] no busca por nombre de forma lineal. Aunque USE_HASH está desactivado (165), TlkJSONobject se crea con UseHash=True por omisión y usa el árbol balanceado TlkBalTree (1104-1127, 2547-2559), que es O(log k). Lo lineal es recorrer PosCarga en ActualizaCampoJSON. El costo real por llamada está en otra parte:
  (1) OldGetField recibe 'nm: WideString' por valor (421), así que cada búsqueda copia un BSTR con el asignador OLE, además de convertir a WideString el literal o el 'campo: string'. En los 7 drivers rootJSON está declarado como TlkJSONbase, por lo que rootJSON.Field['PosCarga'] pasa además por la propiedad Variant (203, 1250-1256). Cada ActualizaCampoJSON hace 2 búsquedas de 'DispenserId' y una comparación Variant por cada posición que recorre; con 16 posiciones, un EstatusDispensarios genera ~1500 asignaciones y liberaciones de BSTR.
  (2) GenerateText, con HAVE_FORMATSETTING (definido en D7), llama a GetLocaleFormatSettings(GetThreadLocale) en cada llamada (1612-1614) y reserva 50 000 bytes con AllocMem. Crea y destruye un TlkJSONstring por cada nombre de campo (1587-1595), hace UTF8Encode de cada cadena y escribe los números con FloatToStr a 15 dígitos.
  (3) ParseText vuelve a llamar a GetLocaleFormatSettings (2014-2016). js_base prueba boolean y null con copy() antes que número o cadena; js_list crea un TlkJSONlist antes de comprobar el '[' (1897-1903) y js_object crea su objeto y su árbol antes del '{'. Por cada campo crea un TlkJSONobjectmethod y un TlkJSONstring, hace UTF8Decode e inserta en el árbol: unas 6-10 operaciones de heap por campo, sobre ~300 campos con 16 posiciones.
  (4) En el Bridge, cada mensaje se copia al log (754), AnsiContainsText pasa el JSON completo a mayúsculas dos veces (757) y se hacen ParseText y Free del árbol anterior aunque el texto sea idéntico al anterior, que es lo normal con la estación en reposo.
  Estimación, no medida: 0.3-2 ms por Generate o Parse con 16 posiciones. Es secundario frente a las esperas activas y los SaveToFile, pero ocurre en cada mensaje y en los dos procesos.
- **Evidencia:**
  uLkJSON 421: 'function OldGetField(nm: WideString): TlkJSONbase;' (parámetro por valor). 1267-1275: 'constructor TlkJSONobject.Create(bUseHash: Boolean); ... FUseHash := bUseHash; ... ht := TlkBalTree.Create;', con bUseHash=true por omisión. 1109-1126: si FUseHash, 'result := ht.IndexOf(aname)'.
  1612-1614: 'GetLocaleFormatSettings(GetThreadLocale, fs); fs.DecimalSeparator := '.';'. 1588-1594: 'xs := TlkJSONstring.Create; xs.FValue := TlkJSONobjectmethod(obj).FName; ... FreeAndNil(xs)'.
  1897-1902: 'js := TlkJSONlist.Create; skip_spc(idx); ... result := txt[idx] = '[';'.
  Bridge 757: 'if not AnsiContainsText(respTxt,'PING') then ProcesaRespuestasJSON(respTxt);'. 798: 'nuevoJSON := TlkJSONobject(TlkJSON.ParseText(ATexto));'.
  En los 7 drivers, 'rootJSON : TlkJSONbase'.
- **Impacto:** Cerca de 1-5 % de CPU por proceso a 5-20 mensajes/s, más miles de asignaciones por segundo que alimentan el recambio de memoria del hallazgo anterior. En el Bridge, que atiende a OpenGas y al driver con un solo hilo, cada milisegundo se suma a la latencia de STATUS, TRANSACTION y de la respuesta al driver.
- **Recomendación:**
  (a) En el Bridge, sin cambiar el contrato: guardar UltimoTextoPDisp. Si respTxt es igual, solo actualizar horaUltimoDatoReal y omitir ParseText y el recorrido de Peticiones; esos folios ya se procesaron, y así se evita además emparejar un resultado viejo con un folio reutilizado (BRG-11). Reemplazar AnsiContainsText por la comparación exacta de BRG-04: Trim(respTxt)='PING', o que el primer carácter sea '{'.
  (b) En los drivers: guardar referencias a los nodos por posición y campo (ya se propuso en BEN-13, PAM-29 y W2W-34), declarar rootJSON como TlkJSONobject para evitar el camino Variant, y generar el JSON solo si cambió algo o toca el latido.
  (c) Aplicar el mismo parche a las dos copias de uLkJSON (BRG-40): 'const nm: WideString' en OldGetField y OldSetField; un TFormatSettings calculado una sola vez en la sección initialization; búfer inicial de 8 KB con GetMem en lugar de AllocMem(50000); y en js_base, decidir por el primer carácter.
  Validar con un micro-benchmark (QueryPerformanceCounter, 10 000 iteraciones de Generate y Parse sobre un snapshot real de 16 posiciones) y con una prueba de ida y vuelta (Generate→Parse→Generate debe dar el mismo texto) antes de desplegar.
- **Esfuerzo:** M · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="PERF-06"></a>
#### PERF-06 · 🟡 Media · rendimiento · optimizacion — Amplía W2W-35 a Gilbarco: cada posición inactiva consume 3 ticks (~190 ms) y solo uno hace E/S, porque los pasos 6 y 7 nunca se saltan

- **Ubicación:** `IgasDispensarios/UIGASGILBARCO.pas` líneas 2799-2850, 2872-2897, 2545-2546, 2117-2125, 2898, 1256, 1272, 1700, 3010-3023
- **Módulos afectados:** UIGASGILBARCO.pas
- **Se atiende en:** [E4.3](../PLAN_OPTIMIZACION.md#e43--ciclo-serial-eficiente)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  Después del paso 1 (estatus), la lógica de L01 salta 2→3→4→5→6 cuando esos pasos no aplican (2873-2888), pero no tiene salto para el 6 ni para el 7. Wayne 2W sí los tiene (UIGASWAYNE2W.pas 2923-2929).
  En cada visita a una posición se gasta un tick en el paso 6, ProcesaComandos, que recorre los 200 slots de TabCmnd y vuelve a registrar en el log cada comando pendiente (2120-2125). Eso pasa aunque ProcesaComandos ya corre al inicio de cada tick cuando hay comando nuevo (2545-2546). Se gasta otro tick en el paso 7 aunque no haya cambio de precio pendiente.
  Con Timer1 de 50 ms (~62.5 ms reales), una posición inactiva cuesta ~190 ms, de los que ~125 ms no hacen nada. Las posiciones inactivas solo se visitan una de cada tres vueltas (xCiclo, 1700 y 3023). Con 16 posiciones en reposo una vuelta dura ~1 s, así que detectar una pistola levantada puede tardar ~3 s, y con ella la autorización automática del paso 4 en modo Normal.
  Cada tick vacío escribe además 'NumPaso=' en el log (2898), y cada transacción escribe 'E ...' y 'sRespuesta1 Length' (1256, 1272). Son ~25-40 líneas/s, con lo que el anillo de 10 000 líneas solo cubre 4-7 min.
- **Evidencia:**
  2872-2888: 'inc(NumPaso); if (NumPaso = 2) and (not SwLeeVenta) then NumPaso := 3; ... if (NumPaso = 4) and (estatus <> 5) then NumPaso := 5; if (NumPaso = 5) and (estatus <> 2) then NumPaso := 6;'. No hay condición para 6→7 ni para 7→8.
  2799-2800: '6: ProcesaComandos;'. 2801-2850: el paso 7 itera las mangueras aunque TCambioPrecN1/N2 estén en False.
  2898: 'AgregaLog('NumPaso=' + IntToStr(NumPaso));' en cada tick.
  En Wayne 2W 2923-2929: 'if (NumPaso=6) and (PosCiclo<MaxPosCarga) then NumPaso:=7; if (NumPaso=7) then begin swprec:=TPosCarga[PosCiclo].TCambioPrecN1; if not swprec then NumPaso:=8;'.
- **Impacto:** En las estaciones Gilbarco la detección de cambios de estatus tarda unas 3 veces más de lo necesario, y la bitácora solo cubre unos minutos.
- **Recomendación:**
  1) Portar los saltos de Wayne 2W: 'if (NumPaso=6) and (ComandosPendientes=0) then NumPaso:=7; if (NumPaso=7) and not CambioPrecioPendiente(PosCiclo) then NumPaso:=8;'. ComandosPendientes cuenta los TabCmnd activos sin respuesta y se actualiza en EjecutaComando y en ProcesaComandos; CambioPrecioPendiente revisa TCambioPrecN1/N2 de la posición.
  2) Conservar el ProcesaComandos del inicio del tick.
  3) Registrar 'NumPaso=' solo en un nivel de depuración.
  Validar en banco con 8 y 16 posiciones, midiendo el tiempo de vuelta y el tiempo entre levantar la pistola y ver 5 en el JSON. Verificar que los OCC pendientes se siguen reintentando.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="PERF-07"></a>
#### PERF-07 · 🟡 Media · protocolo · bug — Amplía BRG-01/E2E-03: los drivers envían sin esperar la respuesta del Bridge; limitar a un mensaje en vuelo evita la concatenación sin cambiar el contrato y baja la latencia

- **Ubicación:** `IgasDispensariosBridge/UIGASBRIDGE.pas` líneas 760-767, 768-773; uLkJSON.pas 2030; Responder: BENNETT 409-436, GILBARCO 411-430, HONGYANG 450-467, PAM 485-502, TEAM 482-499, WAYNE 2954-2971, WAYNE2W 534-557; envíos fuera del ciclo: BENNETT 1918, PAM 398 y 405, WAYNE 2792 y 2799, WAYNE2W 3701
- **Módulos afectados:** UIGASBRIDGE.pas, uLkJSON.pas, UIGASBENNETT.pas, UIGASGILBARCO.pas, UIGASHONGYANG.pas, UIGASPAM.pas, UIGASTEAM.pas, UIGASWAYNE.pas, UIGASWAYNE2W.pas
- **Se atiende en:** [E4.1](../PLAN_OPTIMIZACION.md#e41--responder-al-bridge-en-cuanto-se-procesa-un-comando-y-homologar-la-cadencia)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  BRG-01 ya describe las consecuencias: con mensajes pegados, ParseText instala el primer objeto (2030), se pierden los resultados posteriores y el Bridge responde una sola vez. Su solución, igual que la de E2E-03, es definir un framing, lo que cambia el contrato y obliga a desplegar los dos lados juntos.
  Hay una mitigación más barata. El Bridge solo escribe al driver dentro de SSocketPDispClientRead, una vez por evento de lectura (760-767), y en el except no contesta nada (768-773). Los drivers, en cambio, envían por reloj (Timer1 o Timer2) o por trama serial sin importar si ya les contestaron el mensaje anterior. Algunos manejadores (RUN y '0'/'1') añaden un envío inmediato además del periódico.
  Si el driver aplica 'un mensaje en vuelo' (parada y espera), desaparece la concatenación en los dos sentidos durante la operación normal, porque el Bridge solo escribe como respuesta. Solo queda la fragmentación de mensajes muy grandes, como los de LOG. El formato no cambia.
- **Evidencia:**
  Bridge 760-767: 'if ListaPeticiones.TryStartNext(p) then begin ... Socket.SendText(IntToStr(p.Folio)+'|'+p.Peticion); Exit; end; ... Socket.SendText('0|DISPENSERS|NOTHING');'. 768-773: el except solo registra y llama GuardaLogPDisp, sin responder.
  Gilbarco 2913-2914: 'if (conectado) and (xTurnoSocket=3) then Responder(TlkJSON.GenerateText(rootJSON));', sin revisar si hay respuesta pendiente.
  PAM 2258: envía en cada tick. Team 2368-2370: envía cada 750 ms.
  Responder, en todos los drivers, hace SendText de inmediato, p.ej. Gilbarco 414-420.
- **Impacto:** Mitiga un hallazgo alto (BRG-01) sin necesidad de un despliegue coordinado. Además baja la latencia de los resultados: al llegar la respuesta del Bridge se puede enviar de inmediato si hay un resultado nuevo, sin esperar al siguiente tick, y el ritmo de envío se adapta solo a la capacidad del Bridge.
- **Recomendación:**
  1) En cada driver, o en la unidad común de E2E-41, agregar los campos EsperandoRespuesta, MsEnvio (monotónico) y EnvioPendiente.
  2) En Responder: si EsperandoRespuesta y no han pasado 1000 ms (configurable), no enviar y marcar EnvioPendiente. Nada se pierde: los snapshots son idempotentes y los resultados siguen en rootJSON.Peticiones. Si ya pasó el plazo, registrar 'sin respuesta del Bridge', contarlo y enviar.
  3) En ClientSocket1Read: EsperandoRespuesta:=False y, si hay EnvioPendiente o se agregó un resultado con folio>0, enviar de inmediato el JSON actual.
  4) Reiniciar las banderas al reconectar. Respetar el watchdog de 2 s de Bennett y Wayne 2W.
  Validar en banco forzando bloqueos del Bridge (TRACE con logs grandes). Contar, antes y después, los 'ParseText devolvio nil', los folios en Timeout cuyo resultado sí aparece en el log del driver, y el p95 de latencia de RESPCMND.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="PERF-08"></a>
#### PERF-08 · 🟡 Media · observabilidad · deuda_tecnica — Amplía E2E-36 y BRG-29 a los drivers: no se mide la duración de los ticks, el RTT serial, el tiempo de vuelta ni el costo del JSON y de los logs

- **Ubicación:** `IgasDispensarios/UIGAS*.pas (7 drivers en alcance) e IgasDispensariosBridge/UIGASBRIDGE.pas` líneas BENNETT 946-984, 1678-1689, 2083-2115; GILBARCO 1189-1398, 2525-2924; HONGYANG 1022-1110, 1866-2023; PAM 714-738, 2195-2268; TEAM 1482-1612, 2281-2380; WAYNE 1390-1448, 1497-1912; WAYNE2W 1176-1237, 2624-2966; UIGASBRIDGE 745-774, 785-859, 869-902
- **Módulos afectados:** UIGASBENNETT.pas, UIGASGILBARCO.pas, UIGASHONGYANG.pas, UIGASPAM.pas, UIGASTEAM.pas, UIGASWAYNE.pas, UIGASWAYNE2W.pas, UIGASBRIDGE.pas
- **Se atiende en:** [E0.3](../PLAN_OPTIMIZACION.md#e03--métricas-y-correlación-de-punta-a-punta-en-el-bridge)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  Ningún módulo mide intervalos con QueryPerformanceCounter ni con GetTickCount (lo comprobé con grep). Los logs llevan marca de hora con milisegundos (FechaHoraExtToStr), pero no duraciones, contadores ni percentiles. Las propuestas existentes (E2E-36, BRG-29) solo instrumentan el Bridge.
  Sin datos del lado del driver no se puede saber si un tick duró 60 ms o 3 s, cuánto tarda cada transacción por tipo y posición, cuánto envejece la lectura de una posición inactiva, ni cuánto cuestan GenerateText y SaveToFile. Tampoco se pueden validar las optimizaciones de este análisis: timeBeginPeriod, saltar pasos vacíos, FastMM y no reparsear JSON idénticos.
- **Evidencia:** grep de 'QueryPerformance|GetTickCount|timeGetTime' en UIGAS*.pas y UIGASBRIDGE.pas: sin resultados. Los Timer1Timer de los 7 drivers no registran su duración ni la de cada transacción; Gilbarco y Wayne 2W solo registran texto ('sRespuesta1 Length', 'PosCiclo/NumPaso').
- **Impacto:** Las decisiones de rendimiento se toman a ciegas y las regresiones de latencia pasan desapercibidas. Cuando aparece un 'Timeout excedido con Pdispensarios' no se puede saber si la causa está en el serial, en el driver o en el Bridge.
- **Recomendación:**
  1) Crear una unidad común UMetricas.pas, igual en ambos repos: contadores e histogramas con buckets fijos (1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000 ms) medidos con QueryPerformanceCounter, sin asignar memoria por muestra.
  2) En los drivers medir:
  - duración y periodo real de Timer1Timer y Timer2Timer;
  - RTT por tipo de comando serial y por posición;
  - timeouts, NAK y errores de BCC/LRC por posición;
  - tiempo de vuelta completa y edad máxima de la última lectura de cada posición;
  - GenerateText (µs y bytes) y Responder;
  - latencia de respuesta del Bridge (envío → ClientSocket1Read);
  - SaveToFile (ms y MB) y líneas de log por segundo;
  - GetHeapStatus y PrivateUsage.
  3) En el Bridge medir t_cola y t_driver por comando, ParseText (µs y bytes), mensajes por segundo, edad del snapshot en cada STATUS/TRANSACTION y duración de cada manejador.
  4) Escribir una línea 'STAT' cada 60 s con p50/p95/p99/máx y reiniciar los histogramas.
  5) Protocolo de medición: banco con el modo emulación de Wayne 2W, y com0com más un script emulador para las demás marcas; 24 h por marca antes y después de cada cambio, más una prueba de memoria de 7 días.
  6) Criterios de aceptación propuestos: p95 de comando con folio <600 ms (Team <1.2 s); 0 timeouts en operación normal; p95 del tiempo de vuelta conocido por marca; CPU <10 %; PrivateUsage estable.
- **Esfuerzo:** M · **Riesgo del cambio:** bajo · **Toca contrato:** no

