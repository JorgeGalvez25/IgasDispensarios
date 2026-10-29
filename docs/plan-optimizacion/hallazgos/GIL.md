# Hallazgos · GIL · Driver Gilbarco 2W (Marca 6) · UIGASGILBARCO.pas

> Anexo del [plan de optimización](../PLAN_OPTIMIZACION.md). Código auditado: `IgasDispensarios@26ccfb4`, `IgasDispensariosBridge@99edafd`. Las líneas pueden haber cambiado: ubica las rutinas por su nombre.

## Cómo funciona este módulo

Togcvdispensarios_gilbarco2W es el TService de PDISPENSARIOS.exe para dispensarios Gilbarco de 2 hilos (protocolo de un byte de comando = nibble alto de comando + nibble bajo de dirección, más bloques BCD $E0-$E9 con palabras de control $F0-$FF y LRC de nibbles). Habla con el puerto serial mediante TApdComPort (pSerial) y con el Bridge mediante TClientSocket (ClientSocket1, pull iniciado por el driver).

ServiceExecute (hilo del servicio) solo lee PDISPENSARIOS.ini, crea las listas de log y rootJSON y se queda en ProcessRequests(True). Todo lo demás corre en el hilo principal: Timer1/Timer2 se crean desde el .dfm en el hilo principal, el socket se activa en Timer2Timer (así su HWND es del hilo principal) y los eventos de Async Pro llegan por mensajes que TransmiteComando bombea con ServiceThread.ProcessRequests(False) (llamado desde el hilo principal, así que bombea la cola del hilo principal). La certeza es alta para timers y socket y media para APRO. En operación estable no hay paralelismo real sobre rootJSON ni TPosCarga, pero sí reentrancia: ClientSocket1Read (INITIALIZE, HALT, TRACE...) y Timer2Timer se ejecutan dentro de las esperas seriales. Las únicas carreras entre hilos reales están en el arranque y el paro.

Ciclo: Timer1 (50 ms) ejecuta un paso por tick de una máquina de estados por posición: 0 nivel de precio, 1 estatus $0x, 2 lectura de venta $40, 3 totales $50 con fallback calculado, 4 autoriza en modo Normal, 5 importe en proceso $60, 6 ProcesaComandos, 7 cambio de precio (código muerto). Las posiciones en reposo se sondean en 3 grupos rotativos. El JSON completo se manda al Bridge cada 3 ticks desde el finally de Timer1Timer. Con el proceso detenido, Timer2 (200 ms) manda PING o JSON.

Los comandos del Bridge se procesan en ClientSocket1Read. Los que tocan el dispensario se encolan en TabCmnd[1..200] (OCC/OCL/DVC/REANUDAR/FINV/TOTAL/CPREC), contestan de inmediato 'True|folioCmnd|' y el resultado real se consulta con RESPCMND. Los resultados viajan en rootJSON.Peticiones (máximo 2).

Riesgos principales:

- Publica Estatus=3 antes de leer la venta.

- EsperaFinVenta nunca se activa (se lee el token 6, que no existe).

- Una dirección >16 desborda el byte de comando y puede autorizar otra bomba.

- CPREC puede quedar en bucle infinito y bloquear la cola, y además bloquea el hilo decenas de segundos.

- El envío al Bridge depende de la duración de los ticks.

- RESPCMND solo busca en 40 slots.

- Los totales de 8 dígitos desbordan Integer y el fallback de totales es incorrecto.

- Logs de decenas de MB y recursión GuardarLog/GuardarLogPetRes.

- Wayne 2W ya corrigió varias de estas fallas compartidas y Gilbarco no las tiene.

### Ciclo serial

TIMERS: Timer1 tiene Interval=50 ms y Enabled=False en el .dfm. Se habilita en Iniciar (RUN), en Timer2Timer cuando estado>0 y en el finally de TransmiteComando (Timer1.Enabled := estado>0). TransmiteComando lo apaga al empezar, así que el intervalo se reinicia en cada transacción: tick real ≈ 50-62 ms + duración de la transacción. Timer2 tiene Interval=200 ms y está habilitado desde el .dfm (dispara desde que se crea el formulario, antes incluso de ServiceExecute). Opera cuando estado<=0 o sin conexión.



MÁQUINA DE ESTADOS (Timer1Timer, líneas 2525-2924). Cada tick ejecuta UN paso NumPaso para la posición PosCiclo:

- 0: PonNivelPrecio ($2x con F4) si estatus=1, SwNivelPrecio y Now>=HoraNivelPrecio.

- 1: DameEstatus ($0x, 1 byte) si stciclo=xciclo o estatus>1, la posición no está bloqueada y no está SinComunicacion (o ya pasaron RandomRange(55,65) s). Aplica tolerancia de 3 fallas (MaxFallasEstatus) solo si había un estatus previo distinto de 0. Detecta la recuperación de una venta interrumpida (0→1 con swcargando ⇒ estatus 3) y la transición a reposo.

- 2: lectura de venta DameLecturas6/8 ($40) si SwLeeVenta; hasta 4 visitas por vuelta (ContLeeVenta<3).

- 3: totales DameTotales6/8 ($50) si SwTotales y estatus=1; si falla, AplicarFallbackTotales.

- 4: autoriza ($1x) si estatus=5 y ModoOpera='Normal'.

- 5: importe en proceso ($60) si estatus=2. Deja Volumen=0 y Precio=0 en el JSON.

- 6: ProcesaComandos. Además se ejecuta al inicio de cualquier tick si CmndNuevo.

- 7: cambio de precio por posición. Es código muerto porque TCambioPrecN1/N2 nunca se ponen en True.

- 8: AvanzaPosCiclo.

En L01 se saltan los pasos 2-5 según las banderas, así que una posición en reposo consume 3 ticks (1, 6 y 7). AvanzaPosCiclo reparte las posiciones 1..32 en tres grupos (xCiclo 0,1,2) y StCiclo rota en cada vuelta: las posiciones con estatus<=1 se visitan 1 de cada 3 vueltas y las que tienen estatus>1 en todas. Las posiciones hueco (sin configurar) dentro de 1..MaxPosCarga también se recorren y se sondean.



TRANSMISIÓN (TransmiteComando, 1189-1398):

- Flush de entrada y salida, PutChar del byte de comando y luego espera activa SIN Sleep (repeat ProcessCommunications until OutBuffUsed=0 or timeout).

- Espera de la respuesta: repeat Sleep(5); ServiceThread.ProcessRequests(False) until bListo or timeout or el puerto se cierra.

- Timeout de GtwTimeout (1000 ms por defecto) o GtwTimeout/3 para $20.

- Reintentos: $40 y $50 hasta MaxIntentosLRC=3, con sleep(GtwTiempoCmnd=100 ms) entre intentos. $00 y $20 un solo intento. $10, $30 y $F0 no esperan respuesta y siempre devuelven True.

- $20 (preset, precio o nivel): $2x, espera $Dx, Sleep(10), bloque de datos byte por byte (cada byte con espera activa), Sleep(GtwTiempoCmnd) y sondeo $0x de confirmación (solo compara el nibble bajo).

- Si hay excepción, cierra y reabre el puerto (Sleep 200), lo que borra los data triggers, y llama a GuardarLog(0).



TRAMAS PARCIALES: pSerialTriggerAvail concatena char por char en sRespuesta y pone bListo al alcanzar iBytesEsperados (estatus 1; $40: 33 o 39; $50: 184 o 256; $60: 6 o 8) o cuando se disparó alguno de los data triggers #$F0 (ETX) o #$8A (agregados en Iniciar). Cada bloque parcial rearma el timeout a 300 ms. Validación: el estatus por nibble bajo igual a la dirección; $40 y $50 por longitud + ETX + LRC de nibbles (ValidaLRC); $60 por longitud exacta. La dirección 16 se envía como 0. Las direcciones >16 no se validan.



TIEMPOS EFECTIVOS:

- Posición en reposo: ≈3 ticks ≈ 170-200 ms + ~10-20 ms de transacción. Cada posición en reposo se sondea aproximadamente cada 3 vueltas (16 posiciones en reposo ≈ 3 s).

- Posición despachando: pasos 1, 5, 6 y 7 en cada vuelta.

- Un $40 sin respuesta cuesta ≈3.2 s por tick y puede repetirse 4 ticks (≈13 s).

- Un $50 fallido cuesta ≈3.2 s y se reintenta en cada vuelta sin backoff.

- Un $20 cuesta ≈150-800 ms.

- CPREC aplica todos los precios en un solo tick: 15-75 s para 16 posiciones con 3 productos.

- El JSON sale cada 3 ticks, así que su periodo va de ≈200 ms a decenas de segundos.



SIN COMUNICACIÓN: tras 3 fallas consecutivas (o 1 si la posición nunca respondió) queda estatus 0 y SinComunicacion; se reintenta cada 55-65 s, salvo si hay venta en curso (swcargando), que se sigue sondeando con timeout de 1 s en cada vuelta.

### Contrato con el Bridge, visto desde este módulo

- **Conexión:** TClientSocket ClientSocket1 no bloqueante (ctNonBlocking). El host y el puerto salen de PDISPENSARIOS.ini [CONF] ServidorSocket (default '127.0.0.1:1004'); el .dfm trae 127.0.0.1:8585, que ServiceExecute sobrescribe (líneas 321-322, con StrToInt sin default). Se activa en Timer2Timer (hilo principal), así que OnConnect/OnDisconnect/OnRead corren en el hilo principal. No tiene OnError. No hay servidor propio, a diferencia de Kairos (Marca 7).
- **Ciclo de envío:** Proceso detenido o no inicializado (estado<=0), o desconectado: Timer2 cada 200 ms envía PING o el JSON y en su finally se rehabilita (Timer2.Enabled := not conectado or estado<=0); si estado>0 apaga Timer2 y enciende Timer1. Proceso en marcha (estado=1): Iniciar apaga Timer2 y el finally de Timer1Timer envía TlkJSON.GenerateText(rootJSON) completo cada tercer tick (xTurnoSocket=3) si conectado, sin importar respJson (líneas 2535-2537 y 2913-2914). El periodo real depende de lo que duren los ticks: ≈200-400 ms normalmente, varios segundos con timeouts seriales y decenas de segundos durante CPREC. Cada envío genera exactamente una respuesta del Bridge: el siguiente comando 'folio\|DISPENSERS\|CMD\|params' o '0\|DISPENSERS\|NOTHING'.
- **PING vs JSON:** respJson arranca en False, así que Timer2 manda 'PING' hasta el primer AddPeticionJSON, que puede ser la propia respuesta a NOTHING. A partir de ahí respJson queda True para siempre y Timer2 también manda el JSON completo. Timer1 nunca manda PING. El Bridge no parsea los PING y no actualizan horaUltimoDatoReal, así que no cuentan para la detección de datos obsoletos (5 s), aunque sí cuentan para horaAct (10 s).
- **Peticiones:** AddPeticionJSON (3280-3313) agrega {Folio, Resultado} a rootJSON.Peticiones, conserva solo los 2 más recientes (Delete(0) mientras Count>=2) y pone respJson=True. Como la respuesta a NOTHING también agrega {Folio:0,'True\|'}, en estado estable cada resultado real viaja en los 2 envíos siguientes y después se descarta. El Bridge hace TryPopByFolio con la primera copia y la segunda no encuentra nada. Si entre dos envíos llegaran 3 respuestas, se perdería la más antigua. Los comandos encolados en TabCmnd contestan de inmediato el folio interno, no el resultado.
- **Reconexión:** ClientSocket1Disconnect pone conectado=False, apaga Timer1 (deja de sondear los dispensarios) y enciende Timer2; no limpia socketResponse. Timer2Timer: si no hay conexión hace ClientSocket1.Active := True (sin poner antes Active := False) y espera hasta ~1 s con Sleep(10)×101 SIN bombear mensajes. Como OnConnect es un mensaje del mismo hilo, la espera casi siempre se agota y el procedimiento sale. En el siguiente tick (200 ms después) conectado ya está en True, manda el JSON y, si estado>0, rehabilita Timer1. No hay OnError ni watchdog de inactividad del Bridge (Wayne 2W corta la conexión si pasan 2 s sin respuesta). Si el envío falla en el finally de Timer1, apaga Timer1 y enciende Timer2. TransmiteComando puede volver a encender Timer1 (estado>0) aunque una desconexión anidada lo haya apagado.
- **Comandos:**
  - NOTHING: AddPeticionJSON(folio 0, 'True\|'). Ocupa uno de los 2 lugares de Peticiones.
  - INITIALIZE (json\|variables): Inicializar. Si estado>-1 primero llama a LiberaInicializacion (cierra puerto, limpia TabCmnd y LPrecios, estado -1, Timer2 on). Configura el puerto con Consoles[0].Connection (IniciaPSerial, no lo abre), lee las variables GTW* (DecimalesGilbarco con StrToInt), arma PosCarga (AgregaPosCarga) y llena LPrecios[ProductId]. Deja estado 0.
  - PARAMETERS: 'True\|' sin hacer nada.
  - PRICES: IniciaPrecios encola 'CPREC p1\|p2\|...' y responde 'True\|' (el Bridge ya confirmó a OpenGas).
  - AUTHORIZE (pos\|comb\|importe\|litros\|finv): AutorizarVenta. Usa OCL si litros>0; si no, OCC con importe (importe <0.50 se trata como venta libre; litros <0.10 se convierten en 999 L). finv se invierte. Encola y responde 'True\|folioCmnd\|'.
  - STOP: 'DVC pos', TransmiteComando $3x si estatus está en [2,9]. Siempre responde OK.
  - START: 'REANUDAR pos', $1x si estatus=8. Siempre responde OK.
  - SELFSERVICE / FULLSERVICE: ModoOpera Prepago o Normal. FULLSERVICE solo actúa si PermiteModoNormal=Si; si no, responde True\| sin hacer nada.
  - BLOCK / UNBLOCK: SwDesHabil. Solo deja de sondear la posición; no la publica como 7 ni impide OCC.
  - PAYMENT: 'FINV pos'.
  - TOTALS: 'TOTAL pos'. Responde 'True\|0\|0\|0\|0\|0\|0\|folioCmnd\|'; el valor real llega por RESPCMND como 'True\|lts1\|$1\|lts2\|$2\|lts3\|$3\|'.
  - HALT: Detener. Cierra el puerto, Timer1 off, Timer2 on, estado 0.
  - RUN: Iniciar. Abre el puerto, agrega los triggers $F0/$8A, Timer1 on, Timer2 off, estado 1.
  - SHUTDOWN: ServiceThread.Terminate si estado<=0.
  - TERMINATE: cierra el puerto, LPrecios=0, estado -1.
  - LOGIN / LOGOUT: Token = MD5(usuario\|yyyy-mm-ddThh:nn). No se valida en ninguna otra parte.
  - TRACE: GuardarLog(folio), responde 'True\|ruta\|'.
  - SAVELOGREQ: GuardarLogPetRes.
  - RESPCMND: ResultadoComando(folio). Solo busca en TabCmnd[1..40].
  - LOG / LOGREQ: devuelven las últimas r+1 líneas unidas con '\|'.
  - STATE y cualquier otro comando: 'False\|Comando desconocido\|'. STATE/STATUS/TRANSACTION los contesta el Bridge desde el snapshot.
- **Campos JSON:**
  - Estado (-1 sin inicializar, 0 detenido, 1 en marcha), con SetEstadoJSON
  - PosCarga[].DispenserId
  - PosCarga[].HoraOcc ('yyyy-mm-ddThh:nn', resolución de minuto; es la hora de LECTURA de la venta, no la del fin)
  - PosCarga[].Manguera (TMang[PosActual]; 0 mientras despacha)
  - PosCarga[].Combustible (ProductId de la última venta; 0 mientras despacha)
  - PosCarga[].Estatus (valor CRUDO 0/1/2/3/5/8/9: 3 desde el EOT aunque la venta no se haya leído; nunca 7 para posiciones bloqueadas)
  - PosCarga[].Importe (importe parcial con $60 durante el despacho; importe final después del paso 2)
  - PosCarga[].Volumen (0 durante el despacho; al final se recalcula como importe/precio si difiere más de 0.01)
  - PosCarga[].Precio (0 durante el despacho)
  - PosCarga[].TotalesEstimados (exclusivo de Gilbarco; el Bridge no lo lee)
  - PosCarga[].Hoses[] {HoseId, ProductId, Total}. Total = TotalLitros por slot; el Bridge no lo usa.
  - Peticiones[] {Folio, Resultado}, máximo 2
- **Desviaciones respecto a otros drivers:**
  - Publica 'Estatus' crudo (3 al detectar EOT, antes de leer la venta). Wayne (UIGASWAYNE.pas 1015-1018), Wayne 2W (SwLecturaFinalPendiente, 2772-2775, commit e4a7475) y Bennett (xestado, 1369) publican 2 hasta tener la lectura final. Tampoco publica 7 para posiciones bloqueadas.
  - EsperaFinVenta se lee del token 6 del comando OCC/OCL (líneas 2168 y 2271), que no existe. Wayne 2W (2054, 2170) y Kairos (2304, 2357) usan el token 5. Resultado: el estatus 3 nunca queda fijo hasta PAYMENT.
  - ResultadoComando busca solo en 1..40 (líneas 957-959); Wayne 2W ya busca en 1..200 con Break.
  - ApplyTotalLitrosToJSON localiza la posición por índice (xpos-1); Wayne 2W la busca por DispenserId.
  - No tiene watchdog horaAct de inactividad del Bridge (Wayne 2W 2633-2638), ni Active:=False antes de reconectar, ni limpia socketResponse en Disconnect.
  - No tiene SwRecibida/PuedeSondear (Wayne 2W): sondea posiciones hueco dentro de 1..MaxPosCarga.
  - Agrega el campo TotalesEstimados y un fallback de totales calculados que ningún consumidor interpreta.
  - No tiene modo emulación (Wayne 2W sí).
  - El sondeo serial depende de la conexión al Bridge: Disconnect apaga Timer1.

### Bloques duplicados con otros módulos

| Rutina | Líneas | Nota |
|---|---|---|
| AgregaLog / AgregaLogPetRes | 355-381, 383-409 | Son idénticas entre sí salvo la lista destino: escapado char por char de SOH/STX/ETX/ACK/NAK/ETB, tope de 10000 líneas con Delete(0). Están copiadas en todos los drivers (por ejemplo, UIGASWAYNE2W.pas 459). Conviene una unidad común con un buffer circular. |
| Responder | 411-430 | Envía por socketResponse o por ClientSocket1.Socket y registra 'E '+resp. Mismo código en UIGASBENNETT 409, UIGASHONGYANG 450, UIGASPAM 485, UIGASTEAM 482, UIGASTRITON 367, UIGASWAYNE 2954 y UIGASWAYNE2W 534 (Kairos 633 tiene una variante con socket como parámetro). |
| FechaHoraExtToStr / CRC16 / MD5 | 432-449, 493-503 | Utilitarios copiados en todos los drivers. CRC16 no se usa en Gilbarco. MD5 con TIdHashMessageDigest5 (UIGASWAYNE2W.pas 969). |
| GuardarLog / GuardarLogPetRes | 451-491 | Mismo patrón (con la recursión mutua) en todos los drivers del Bridge; por ejemplo, UIGASWAYNE2W.pas 3545. |
| Login / Logout | 3363-3382 | Token MD5(usuario\|minuto). Idéntico en todos los drivers (UIGASWAYNE2W.pas 3712). |
| Bloquear / Desbloquear / ActivaModoPrepago / DesactivaModoPrepago | 505-573, 1020-1075 | Copiados en todos los drivers con la misma laguna de respuesta para MaxPosCarga < xpos <= 32. |
| Detener / Iniciar / Shutdown / Terminar | 575-689, 1093-1109 | Ciclo de vida estándar (HALT/RUN/SHUTDOWN/TERMINATE). Iniciar incluye el bloque HASP comentado, compartido con los demás drivers. Shutdown es idéntico al de UIGASWAYNE2W.pas 3840. |
| AutorizarVenta / DetenerVenta / ReanudarVenta / FinVenta / TotalesBomba / IniciaPrecios / RespuestaComando | 691-770, 923-950, 1077-1091, 1172-1187, 1532-1554 | Traducción de los comandos del Bridge a comandos internos de TabCmnd. Igual a UIGASWAYNE2W.pas 3345 (AutorizarVenta) y 3530 (FinVenta). La diferencia está en ProcesaComandos (token 6 en lugar de 5 para EsperaFinVenta). |
| EjecutaComando / ResultadoComando | 772-809, 952-960 | Cola TabCmnd[1..200] con expiración perezosa. Copiada en los 9 drivers. Wayne 2W (981, 1061) ya busca en 1..200; Gilbarco, Kairos (907) y Team (3004) siguen buscando en 1..40. |
| ObtenerLog / ObtenerLogPetRes | 962-1018 | Mismo off-by-one y sin límite de r. Igual en UIGASWAYNE2W.pas 3732 y en el resto. |
| ValidaCifra / NoElemStrEnter / ExtraeElemStrEnter | 2059-2107, 2466-2494 | Utilitarios de cadena y validación duplicados (UIGASWAYNE2W.pas 929 y el resto de los drivers salvo Triton y HongYang). Deberían vivir en ULIBGRAL. |
| IniciaPSerial / Inicializar / LiberaInicializacion / AgregaPosCarga | 1676-2057 | Inicialización estándar a partir de INITIALIZE (Consoles/Dispensers/Products/variables) y armado de PosCarga. Las mismas fugas (js sin liberar) en todos. Wayne 2W (736, 807) agrega SwRecibida; Gilbarco no. |
| ClientSocket1Connect / ClientSocket1Disconnect / Timer2Timer / ClientSocket1Read | 3059-3228 | Lado cliente del contrato Bridge (PING/JSON, despacho por TMetodos con GetEnumValue). Wayne 2W (3892-3990) tiene la versión corregida (Active:=False antes de reconectar, socketResponse:=nil, horaAct); Gilbarco no. |
| ActualizaCampoJSON / AddPeticionJSON / ApplyTotalLitrosToJSON / SetEstadoJSON | 3230-3361 | Manejo del snapshot rootJSON. Copiado en los 8 drivers del Bridge. ApplyTotalLitrosToJSON por índice (xpos-1) también en HongYang 2871, PAM 2941, Triton 1387 y Wayne 2268; Wayne 2W (3299) ya busca por DispenserId. |
| Protocolo Gilbarco: BcdToInt, BcdToStr, DLChar, LoNibbleChar, HiNibbleChar, LrcCheckChar | 242-298 | Ayudantes BCD/LRC duplicados en UIGASKAIROS.pas 320-370 (driver legado de Gilbarco). Tienen el mismo desbordamiento de Integer en BcdToInt. |
| TransmiteComando, DameEstatus, DameLecturas6/8, DameTotales6/8, DameVentaProceso6/8, EnviaPresetBomba6/8, CambiaPrecio6/8, PonNivelPrecio, pSerialTriggerAvail/Data, AvanzaPosCiclo | 1144-1674, 2496-2523, 2926-2949, 3010-3052 | Pila completa del protocolo Gilbarco 2W duplicada en UIGASKAIROS.pas (DameEstatus 1816, TransmiteComando 1891, AvanzaPosCiclo 2068, DameLecturas6 2081, DameTotales6 2115, DameTotales8 2153, CambiaPrecio6 2519, EnviaPresetBomba6 2620, pSerialTriggerAvail 2678). Los triggers $F0/$8A y AvanzaPosCiclo también aparecen en UIGASWAYNE2W.pas (3646). Conviene una unidad UGilbarcoProto compartida. |
| ProcesaComandos / Timer1Timer (máquina NumPaso, bloques OCC/OCL/FINV/DVC/TOTAL) | 2109-2464, 2525-2924 | Estructura copiada de UIGASKAIROS.pas 2224 y UIGASWAYNE2W.pas. El bloque TOTAL (2375-2401) con 'OK'+FormatFloat(TotalLitros)+FormatoMoneda(TotalLitros*LPrecios[TComb[k]]) está repetido en Bennett 1646, HongYang 2248, Kairos 2452, PAM 1657, Team 2142, Wayne 1798 y Wayne 2W 2383. |
| CombustibleEnPosicion / PosicionDeCombustible / PosicionDeCombustibleTotales | 1111-1142, 3384-3401 | Búsquedas lineales por combustible y manguera presentes en todos los drivers con TPosCarga. La variante de totales (TPosTotales/MapeoTotales) es exclusiva de Gilbarco. |
| ServiceController / GetServiceController / ServiceExecute | 300-353 | Plantilla de TService idéntica en todos los drivers: lectura de PDISPENSARIOS.ini, creación de listas y rootJSON, ciclo ProcessRequests(True). |

## Hallazgos (47)

<a id="GIL-01"></a>
#### GIL-01 · 🔴 Crítica · protocolo · bug — Estatus 3 (fin de venta) se publica antes de leer la venta: TRANSACTION puede devolver datos de la venta en proceso

- **Ubicación:** `UIGASGILBARCO.pas` líneas 2588-2615, 2655-2700, 2777-2796, 2862-2869, 2998-3000, 2913-2914
- **Módulos afectados:** UIGASGILBARCO.pas, UIGASBRIDGE.pas (consumidor del snapshot), OpenGas
- **Se atiende en:** [E1.9](../PLAN_OPTIMIZACION.md#e19--coherencia-del-estado-publicado-estatus-fin-de-venta-horaocc-estado)
- **Verificación:** sin verificación independiente
- **Qué pasa:** DameEstatus convierte $A, $B y $3 (EOT) en 3. En el paso 1, EstatusDispensarios publica ActualizaCampoJSON(xpos,'Estatus',estatus) con ese valor crudo. SwLeeVenta se arma después, en L01 (2862-2869), y la lectura $40 que actualiza Volumen, Precio, Importe, HoraOcc, Manguera y Combustible ocurre en el paso 2, en un tick posterior. Mientras tanto el JSON trae lo que dejó el paso 5 durante el despacho (Volumen=0, Precio=0, Importe parcial del $60) y la HoraOcc de la venta anterior. El finally de Timer1Timer envía el snapshot cada 3 ticks, así que puede salir Estatus=3 con esos datos. Pasa lo mismo con el estatus 3 forzado al recuperar comunicación (2607-2613). Si DameLecturas falla (hasta 4 visitas × 3 intentos), la ventana dura segundos o vueltas completas. El Bridge contesta STATUS y TRANSACTION directo del snapshot (UIGASBRIDGE.pas 664-676 y 729-730). Wayne, Wayne 2W y Bennett enmascaran el 3 como 2 hasta tener la lectura final; Gilbarco no lo hace.
- **Evidencia:** Línea 3000: ActualizaCampoJSON(xpos, 'Estatus', estatus). Líneas 2779-2780: volumen := 0; precio := 0 en el paso 5. En cambio, UIGASWAYNE.pas 1015-1016 hace 'if (estatus = 3) and (swcargando) then ActualizaCampoJSON(xpos,'Estatus',2)', y UIGASWAYNE2W.pas 2772-2773 usa 'if SwLecturaFinalPendiente then ActualizaCampoJSON(PosCiclo,'Estatus',2)' (commit e4a7475 'esperar lectura final de dispensario antes de FINV').
- **Impacto:** OpenGas puede registrar la venta con Volumen 0, Precio 0 e Importe parcial, o con la HoraOcc de la venta anterior, o mandar PAYMENT antes de la lectura final. Esto da cobros o ventas mal registradas y diferencias en los controles volumétricos.
- **Recomendación:** Agregar SwLecturaFinalPendiente a tiposcarga. Ponerla en True cuando el estatus pase a 3 (incluido el 3 forzado de 2607-2613) y en False solo después de un DameLecturas6/8 exitoso y de actualizar todos los campos de la venta. Mientras esté en True, publicar 'Estatus'=2. Publicar 7 cuando SwDesHabil. Probar con un emulador o con el equipo: inducir un fallo en $40 al terminar la venta y verificar que TRANSACTION nunca devuelva Estatus 3 con Volumen 0 ni con la HoraOcc anterior.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="GIL-02"></a>
#### GIL-02 · 🟠 Alta · correccion · bug — EsperaFinVenta se lee del token 6, que no existe: el estatus 3 nunca queda fijo hasta PAYMENT

- **Ubicación:** `UIGASGILBARCO.pas` líneas 726-733, 2160, 2168, 2263, 2271, 2625-2632, 2316-2345
- **Se atiende en:** [E1.3](../PLAN_OPTIMIZACION.md#e13--presets-montos-decimales-y-validaciones)
- **Verificación:** sin verificación independiente
- **Qué pasa:** AutorizarVenta arma 'OCC|OCL pos cantidad comb finv', que tiene 5 tokens. ProcesaComandos asigna tipopago desde el token 5 (es el finv invertido) y Esperafinventa := StrToIntDef(ExtraeElemStrSep(Comando, 6, ' '), 0), que siempre da 0. Por eso, en 2625-2632, al pasar a reposo nunca se fuerza Estatus := 3 en espera de PAYMENT, y el parámetro finv de OpenGas no tiene efecto. Además, FINV (2323-2337) contesta 'Posicion no esta despachando' cuando la posición está en EOT con swcargando=True, y su rama 'swcargando and Estatus=1' es inalcanzable.
- **Evidencia:** Líneas 2168 y 2271: ExtraeElemStrSep(TabCmnd[xcmnd].Comando, 6, ' '). UIGASWAYNE2W.pas 2054 y 2170, y UIGASKAIROS.pas 2304 y 2357, usan el token 5. El error existe desde el commit inicial 8ba4373.
- **Impacto:** El driver no retiene el fin de venta. Si el EOT del Gilbarco dura poco o OpenGas no consulta a tiempo, la posición vuelve a 1 y OpenGas puede no ver el 3, con riesgo de perder la venta. PAYMENT responde errores engañosos, que el Bridge además ya confirmó como True a OpenGas.
- **Recomendación:** Leer Esperafinventa del token 5, como Wayne 2W, y eliminar tipopago o leerlo de su token real. Corregir FINV como en Wayne 2W: si hay lectura final pendiente, responder 'Posicion aun tiene lectura final pendiente'; si no, esperafinventa := 0. Probar AUTHORIZE con finv=0 y finv=1 y verificar que Estatus se quede en 3 hasta PAYMENT.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="GIL-03"></a>
#### GIL-03 · 🟠 Alta · protocolo · bug — Una dirección de bomba mayor que 16 desborda el byte de comando: el sondeo de la posición 17 autoriza la bomba 1

- **Ubicación:** `UIGASGILBARCO.pas` líneas 1244-1246, 1755-1760, 210, 227
- **Se atiende en:** [E1.8](../PLAN_OPTIMIZACION.md#e18--índices-fuera-de-rango-y-carga-de-posiciones-r-)
- **Verificación:** sin verificación independiente
- **Qué pasa:** TransmiteComando forma chComando := char(iComando + xNPos) y solo convierte 16 en 0. AgregaPosCarga acepta cualquier DispenserId (MaximoDePosiciones=32, TPosCarga[1..32]) sin validar el rango 1..16 del lazo Gilbarco 2W. Para xNPos=17, un sondeo de estatus ($00+17) sale como $11, que es el comando de autorizar la bomba 1; $40+17 = $51 pide totales a la bomba 1; $20+17 = $31 detiene la bomba 1.
- **Evidencia:** Líneas 1244-1246: 'if (xNPos = 16) then xNPos := 0; chComando := char(iComando + xNPos);'. Línea 1757: xpos := posiciones.Child[i].Field['DispenserId'].Value, sin validar.
- **Impacto:** Si se configura una posición mayor que 16 (sitios grandes o numeración continua entre consolas), el driver autoriza o detiene otras bombas sin que OpenGas lo pida. Hay riesgo de despacho no cobrado.
- **Recomendación:** En AgregaPosCarga, rechazar el INITIALIZE con 'False|DispenserId fuera de rango 1..16 para Gilbarco 2W|' si algún DispenserId no está en 1..16. En TransmiteComando, abortar sin transmitir si xNPos no está en 1..16. Agregar una prueba unitaria del armado de chComando.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="GIL-04"></a>
#### GIL-04 · 🟠 Alta · correccion · bug — CPREC sale con Exit sin responder: queda activo para siempre, repite los cambios de precio y bloquea los comandos de slots posteriores

- **Ubicación:** `UIGASGILBARCO.pas` líneas 2402-2420, 2121-2127, 2451-2459, 772-809
- **Se atiende en:** [E1.5](../PLAN_OPTIMIZACION.md#e15--tabla-de-comandos-tabcmnd-y-respuestas-de-comandos-asíncronos)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Si un precio no se puede convertir (StrToFloatDef(..., -1) = -1; por ejemplo, PRICES trae menos precios que los productos configurados o usa coma decimal), CPREC asigna rsp y hace Exit de TODO ProcesaComandos sin marcar SwResp. El comando sigue en SwActivo y sin respuesta. En cada llamada siguiente (al inicio de cada tick con CmndNuevo y en el paso 6 de cada posición), ProcesaComandos vuelve a ejecutarlo: reenvía los cambios de precio a las posiciones anteriores al fallo y vuelve a salir. Los comandos que estén en slots posteriores de TabCmnd nunca se procesan. Los slots solo se liberan de forma perezosa en EjecutaComando, cuando la búsqueda pasa por ellos y tienen más de 1 minuto.
- **Evidencia:** Líneas 2412-2417: 'precioComb := StrToFloatDef(ExtraeElemStrSep(precios, TComb[i], '|'), -1); if precioComb = -1 then begin rsp := ...; Exit; end;'. Las líneas 2451-2459 (SwResp := true) nunca se alcanzan.
- **Impacto:** Tráfico $20 continuo en el lazo (se degrada el sondeo de todas las posiciones), AUTHORIZE/STOP/PAYMENT encolados que no se ejecutan o se ejecutan minutos después, y precios aplicados a medias.
- **Recomendación:** Cambiar Exit por la marca de error del comando ('Precio incorrecto', SwResp := true) y seguir con el siguiente comando (Continue o salir del ciclo de posiciones). Validar la cadena completa de precios en IniciaPrecios antes de encolar y contestar False si viene incompleta. Probar con PRICES de 2 precios y una posición de 3 productos.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="GIL-05"></a>
#### GIL-05 · 🟠 Alta · rendimiento · bug — CPREC aplica todo el cambio de precios dentro de un solo tick: decenas de segundos sin enviar JSON, el Bridge marca datos obsoletos y corta a OpenGas

- **Ubicación:** `UIGASGILBARCO.pas` líneas 2402-2448, 1334, 1340, 1356, 2427, 2438, 2913-2914
- **Módulos afectados:** UIGASGILBARCO.pas, UIGASBRIDGE.pas
- **Se atiende en:** [E1.6](../PLAN_OPTIMIZACION.md#e16--precios-aplicar-solo-lo-confirmado), [E4.3](../PLAN_OPTIMIZACION.md#e43--ciclo-serial-eficiente)
- **Verificación:** sin verificación independiente
- **Qué pasa:** CPREC recorre todas las posiciones y productos y hace 2 transacciones $20 por producto (nivel 1 y nivel 2) más Sleep(50). Cada $20 lleva: espera de respuesta (hasta GtwTimeout/3), Sleep(10), bloque de datos byte a byte con espera activa, Sleep(GtwTiempoCmnd=100) y un sondeo de confirmación. Son ≈0.3-0.8 s por producto: 16 posiciones × 3 productos ≈ 15-40 s, y ≈75 s en el peor caso con timeouts. Todo pasa dentro de un Timer1Timer, así que el JSON (que sale en el finally cada 3 ticks) no se envía. En el Bridge, después de TimeoutDatosObsoletos (5 s) STATE, STATUS y TRANSACTION responden False y se manda un TRACE automático. Si pasan 10 s sin actividad, AddPeticion hace CancelarPeticiones y SSocketOG.Active:=False (UIGASBRIDGE.pas 409-412). Las peticiones ya entregadas al driver vencen a los 2 s (TimeoutRespSrv).
- **Evidencia:** Bucle anidado de 2405-2447 con CambiaPrecio6/8 dos veces y Sleep(50). TransmiteComando incluye sleep(10) en 1340 y sleep(GtwTiempoCmnd) en 1334 y 1356. El único envío en marcha está en 2913-2914.
- **Impacto:** Cada cambio de precio en un sitio mediano deja a OpenGas sin datos o desconectado y cancela sus peticiones. Además se detiene el sondeo de ventas durante el cambio.
- **Recomendación:** Llevar el cambio de precio a la máquina de estados por posición: CPREC solo marca TNuevoPrec/TCambioPrecN1/N2 por manguera, y el paso 7 (ya existe) aplica una manguera por tick cuando estatus=1. Otra opción es enviar el JSON por tiempo transcurrido también dentro del ciclo. Medir con 16 posiciones que el intervalo entre envíos se mantenga por debajo de 1 s.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="GIL-06"></a>
#### GIL-06 · 🟠 Alta · protocolo · bug — El JSON al Bridge solo sale cada 3 ticks de Timer1, y un tick puede durar varios segundos por los reintentos seriales

- **Ubicación:** `UIGASGILBARCO.pas` líneas 2535-2537, 2877-2881, 1220-1223, 1257, 1265-1271, 2913-2914
- **Módulos afectados:** UIGASGILBARCO.pas, UIGASBRIDGE.pas
- **Se atiende en:** [E4.1](../PLAN_OPTIMIZACION.md#e41--responder-al-bridge-en-cuanto-se-procesa-un-comando-y-homologar-la-cadencia)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Mientras el proceso está en marcha, el único envío al Bridge es el del finally de Timer1Timer cuando xTurnoSocket=3. Un tick del paso 2 con un $40 sin respuesta dura ≈3×GtwTimeout + 2×GtwTiempoCmnd ≈ 3.2 s, y ContLeeVenta repite el paso hasta 4 veces. Lo mismo pasa con los totales $50 (3 intentos). Entre dos envíos puede haber 9-13 s. Con eso se cumplen los umbrales del Bridge: 5 s para datos obsoletos con TRACE automático, 2 s para que OpenGas reciba 'Timeout excedido' aunque el driver sí ejecutó, y 10 s para cancelar peticiones y desactivar SSocketOG. La latencia de cualquier comando también depende de esta cadencia.
- **Evidencia:** Línea 1221: iMaxIntentos := MaxIntentosLRC (3) para $40/$50. Línea 1257: timeout de GtwTimeout (1000 ms). Líneas 2877-2881: reintento del paso 2. Líneas 2913-2914: envío condicionado a xTurnoSocket=3.
- **Impacto:** Una sola bomba con mala comunicación de lectura degrada a TODO el sitio: STATE/STATUS en False, peticiones vencidas y posibles desconexiones de OpenGas.
- **Recomendación:** Enviar por tiempo transcurrido (GetTickCount; por ejemplo, si pasaron 250 ms desde el último envío) en el finally y también dentro de los bucles de espera de TransmiteComando, o entre intentos. Limitar la duración total de un paso (presupuesto por tick). A mediano plazo, mover el diálogo serial a un hilo propio. Validar desconectando la línea de datos de una bomba y midiendo el intervalo entre envíos en el log del Bridge.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="GIL-07"></a>
#### GIL-07 · 🟠 Alta · correccion · bug — ResultadoComando solo busca en TabCmnd[1..40]: RESPCMND devuelve '*' para comandos en los slots 41..200

- **Ubicación:** `UIGASGILBARCO.pas` líneas 952-960, 772-809, 1545-1549
- **Se atiende en:** [E1.5](../PLAN_OPTIMIZACION.md#e15--tabla-de-comandos-tabcmnd-y-respuestas-de-comandos-asíncronos)
- **Verificación:** sin verificación independiente
- **Qué pasa:** EjecutaComando ocupa el primer slot libre de 1..200 y los slots no se liberan al responder: siguen SwActivo hasta que tienen más de 1 minuto y la búsqueda pasa por ellos. Con más de 40 comandos por minuto (AUTHORIZE, PAYMENT y TOTALS por cada venta en sitios de 12-16 posiciones), los folios caen en slots mayores que 40 y ResultadoComando devuelve '*'. RespuestaComando responde entonces 'False|*|'.
- **Evidencia:** Línea 957: 'for i := 1 to 40 do'. En UIGASWAYNE2W.pas 1067 ya está corregido a 'for i:=1 to 200 do ... Break'.
- **Impacto:** OpenGas no obtiene los totales (TOTALS se consulta por RESPCMND) ni el resultado de AUTHORIZE en horas pico.
- **Recomendación:** Recorrer 1..200 con Break, igual que Wayne 2W. Mejor aún, usar un diccionario folio→slot. Probar encolando 60 comandos en menos de un minuto y consultando RESPCMND de los últimos.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="GIL-08"></a>
#### GIL-08 · 🟠 Alta · correccion · bug — El fallback de totales calculados publica totales falsos y OpenGas no tiene forma de saber que son estimados

- **Ubicación:** `UIGASGILBARCO.pas` líneas 850-921, 2617-2622, 2662-2685, 1725, 2394
- **Módulos afectados:** UIGASGILBARCO.pas, OpenGas
- **Se atiende en:** [E1.7](../PLAN_OPTIMIZACION.md#e17--totales-confiables), [E5.3](../PLAN_OPTIMIZACION.md#e53--totals-y-respcmnd-desde-el-snapshot)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Al arrancar o al recuperar comunicación (estatus 0→1), las líneas 2617-2622 arman SwLeeVenta, y el paso 2 relee la ÚLTIMA venta del equipo, que ya está incluida en sus totalizadores. CapturarVentaPendiente la suma como delta pendiente. Si después Lee Totales falla MaxFallosTotales veces (2 si hay un TOTAL esperando), AplicarFallbackTotales hace TotalLitros[k] += pendiente. Justo después de INITIALIZE, TotalLitros vale 0 (1725), así que el total publicado es el volumen de la última venta (unas decenas de litros en lugar de millones). Después de una reconexión, la última venta queda contada dos veces. La bandera TotalesEstimados solo va en el snapshot, que el Bridge no lee, y la respuesta TOTAL por RESPCMND (2394) usa TotalLitros sin ninguna indicación.
- **Evidencia:** Línea 899: TotalLitros[k] := TotalLitros[k] + PendingVentaLts[k], sin verificar que hubo una lectura real previa. En UIGASBRIDGE.pas no aparecen 'TotalesEstimados' ni 'Total'.
- **Impacto:** Totalizadores incorrectos en los cortes y en los controles volumétricos, presentados a OpenGas como reales.
- **Recomendación:** Aplicar el fallback solo si existe una lectura real previa (bandera TotalesValidos por posición). No capturar como pendiente la venta releída por arranque o reconexión. Si no hay base válida, responder TOTAL con 'False|Totales no disponibles|'. Si se quiere exponer que son estimados, acordar un campo en la respuesta con OpenGas.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** sí

<a id="GIL-09"></a>
#### GIL-09 · 🟠 Alta · correccion · bug — Los totalizadores de 8 dígitos (12 dígitos BCD) desbordan Integer en BcdToInt y DataControlWordValue

- **Ubicación:** `UIGASGILBARCO.pas` líneas 242-254, 1400-1411, 1512-1523
- **Se atiende en:** [E1.7](../PLAN_OPTIMIZACION.md#e17--totales-confiables)
- **Verificación:** sin verificación independiente
- **Qué pasa:** BcdToInt acumula en Integer, con xMult también Integer, a partir del dígito menos significativo. DameTotales8 lee 12 dígitos: xMult desborda desde 10^10 y el resultado se envuelve en silencio en cuanto pasa de 2,147,483,647, porque el proyecto compila con -$Q- y -$R- (PDISPENSARIOS.cfg). GtwDivTotLts se queda en 100 por defecto (no se ajusta con DigitosGilbarco), así que un totalizador mayor que 21,474,836.47 L da basura, y con divisor 1000 basta con superar 2,147,483.647 L, algo normal en 1-2 años de uso.
- **Evidencia:** Líneas 244-251: 'xValor, xMult, i: integer; ... xValor := xValor + (ord(xBCD[i]) and $0F) * xMult; xMult := xMult * 10;'. Línea 1512: DataControlWordValue(#$F9, 12). DataControlWordValue devuelve longint.
- **Impacto:** Totales de litros (y de pesos, si alguna vez se usan) negativos o absurdos en bombas de 8 dígitos.
- **Recomendación:** Crear BcdToInt64 que recorra del dígito más significativo al menos significativo (x := x*10 + d) con Int64, y hacer que DataControlWordValue devuelva Int64. Probar con tramas sintéticas de 999999999999 y 2147483648.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="GIL-10"></a>
#### GIL-10 · 🟠 Alta · concurrencia · riesgo — Reentrancia: ServiceThread.ProcessRequests(False) dentro de la espera serial ejecuta comandos del Bridge y Timer2 a mitad de una transacción

- **Ubicación:** `UIGASGILBARCO.pas` líneas 1268-1271, 1365-1368, 1393-1397, 3064-3069, 3071-3112, 3114-3228, 2031-2057, 1676-1753
- **Se atiende en:** [E2.5](../PLAN_OPTIMIZACION.md#e25--reentrancia-comandos-del-bridge-durante-una-transacción-serial)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Modelo de hilos verificado. Timer1 y Timer2 se crean desde el .dfm en el hilo principal (Application.CreateForm en PDISPENSARIOS.dpr). ClientSocket1 se activa en Timer2Timer, así que su ventana es del hilo principal. ServiceExecute solo hace ProcessRequests(True) en el hilo del servicio. TransmiteComando, llamado desde Timer1Timer, invoca ServiceThread.ProcessRequests(False) desde el hilo principal; eso es un PeekMessage/DispatchMessage de la cola principal. En consecuencia, dentro de cada espera serial se pueden ejecutar: ClientSocket1Read con INITIALIZE (LiberaInicializacion y AgregaPosCarga reescriben TPosCarga, MaxPosCarga y TabCmnd mientras Timer1Timer está a medio paso dentro de 'with TPosCarga[PosCiclo]'; al volver, escribe estatus, FallosEstat y SinComunicacion sobre el registro recién inicializado, y ProcesaComandos marca SwResp en slots ya limpiados), HALT (cierra el puerto) o TRACE (escribe archivos de decenas de MB y provoca timeouts seriales). También ClientSocket1Disconnect: apaga Timer1, pero el finally de TransmiteComando lo vuelve a encender porque estado>0, y entonces Timer2Timer puede correr anidado y bloquear ~1 s con Sleep, lo que da timeouts falsos y suma FallosEstat. No hay paralelismo real sobre rootJSON ni las listas en estado estable; el riesgo es reentrancia. Certeza: alta para timers y socket, media para el despacho de eventos de Async Pro (que exige bombear mensajes).
- **Evidencia:** Líneas 1268-1271: 'repeat Sleep(5); ServiceThread.ProcessRequests(False); until ((bListo) or ...'. Línea 1395: comentario 'HALT o INITIALIZE pueden llegar mientras se espera respuesta'. Línea 1396: Timer1.Enabled := estado > 0. Líneas 3067-3068: Disconnect apaga Timer1.
- **Impacto:** Estado corrupto después de un INITIALIZE en caliente, posiciones marcadas sin comunicación por pausas anidadas, y comportamiento difícil de reproducir.
- **Recomendación:** Corto plazo: mientras Transmitiendo (o dentro de Timer1Timer), que ClientSocket1Read encole en una lista los comandos INITIALIZE, HALT, RUN, TERMINATE, TRACE y SAVELOGREQ y que Timer1Timer los aplique al final del tick. En el finally de TransmiteComando, restaurar el estado previo de Timer1 en lugar de forzarlo. Mediano plazo: hilo serial dedicado con esperas sobre eventos (sin bombear la cola de la VCL) y publicación de resultados por PostMessage. Probar mandando INITIALIZE y HALT en ráfaga durante un CPREC.
- **Esfuerzo:** L · **Riesgo del cambio:** alto · **Toca contrato:** no

<a id="GIL-11"></a>
#### GIL-11 · 🟠 Alta · robustez · bug — Reconexión al Bridge frágil: el sondeo serial se detiene, la espera no bombea mensajes y no hay OnError ni watchdog

- **Ubicación:** `UIGASGILBARCO.pas` líneas 3059-3069, 3071-3112, 2913-2922
- **Se atiende en:** [E2.1](../PLAN_OPTIMIZACION.md#e21--desacoplar-timer1-sondeo-serial-de-la-conexión-con-el-bridge), [E2.2](../PLAN_OPTIMIZACION.md#e22--reconexión-no-bloqueante-y-con-manejo-de-errores)
- **Verificación:** sin verificación independiente
- **Qué pasa:** (1) ClientSocket1Disconnect apaga Timer1, así que mientras no hay Bridge no se sondean los dispensarios: una venta que termina en ese lapso puede no detectarse (ver la transición 2→1). (2) Timer2Timer hace Active := True sin Active := False y espera ~1 s con Sleep(10) sin bombear mensajes. OnConnect es un mensaje del mismo hilo, así que nunca llega dentro de la espera: la espera se agota siempre y bloquea el hilo principal ~1 s cada 200 ms mientras dura la caída. (3) Sin OnError, un fallo de conexión lanza ESocketError desde el manejador de mensajes; si el socket queda con Active=True, el siguiente Active := True no hace nada y no se reconecta (certeza media; Wayne 2W pone Active := False explícitamente antes de reconectar). (4) No hay watchdog de inactividad: Wayne 2W corta si pasan 2 s sin respuesta del Bridge (UIGASWAYNE2W.pas 2633-2638). Con una conexión medio abierta, Gilbarco sigue enviando para siempre. (5) Disconnect no limpia socketResponse.
- **Evidencia:** Líneas 3081-3089: 'ClientSocket1.Active := True; for i := 0 to 100 do begin Sleep(10); if conectado then Break; end;'. En cambio, UIGASWAYNE2W.pas 3899-3907: 'socketResponse:=nil; try ClientSocket1.Active := False; except end; Sleep(500); ClientSocket1.Active := True;'.
- **Impacto:** Ventas no detectadas durante caídas del Bridge, hilo principal bloqueado y posibles bloqueos permanentes de reconexión.
- **Recomendación:** Portar la versión de Wayne 2W (Active := False antes de reconectar, limpiar socketResponse, watchdog horaAct de 2-3 s). Agregar ClientSocket1Error con ErrorCode := 0 y Socket.Close. No detener Timer1 por la desconexión: seguir sondeando y que solo se omita el envío. Reemplazar la espera con Sleep por una reconexión asíncrona (dejar que OnConnect habilite el envío). Probar deteniendo y arrancando PDISPBRIDGE con una venta en curso.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="GIL-12"></a>
#### GIL-12 · 🟠 Alta · correccion · bug — La transición 2→1 sin haber visto el EOT no dispara la lectura de la venta

- **Ubicación:** `UIGASGILBARCO.pas` líneas 2617-2632, 2862-2869, 2633-2640
- **Se atiende en:** [E1.4](../PLAN_OPTIMIZACION.md#e14--sondeo-que-se-congela-livelocks-y-bloqueos-de-la-máquina-de-estados)
- **Verificación:** sin verificación independiente
- **Qué pasa:** SwLeeVenta solo se arma cuando el estatus es 3 en L01 (2862-2869) o en la transición 0→1 (2617-2621). Si el estatus pasa de 2 (despachando) a 1 (reposo) sin que se haya observado el EOT, se limpia swcargando y solo se arma SwTotales (2625-2631): la venta no se lee y nunca se publica como 3. Esto puede pasar si el sondeo estuvo detenido (desconexión del Bridge), con ticks de varios segundos, con posiciones bloqueadas que no se sondean, o con equipos que reportan reposo enseguida. Wayne 2W trata esa transición como fin de venta ('Detecto Fin Venta', SwLecturaFinalPendiente). Certeza: el flujo del código es seguro; qué tan seguido el Gilbarco pasa a reposo sin un EOT visible depende del equipo y del firmware.
- **Evidencia:** Líneas 2625-2632: 'if (EstatusAnt in [2, 3, 4]) and (Estatus = 1) then begin swcargando := false; if EsperaFinVenta = 1 then Estatus := 3 else SwTotales := true; end;'. Ahí no se toca SwLeeVenta.
- **Impacto:** Transacciones perdidas: venta despachada que OpenGas nunca registra.
- **Recomendación:** En la transición (EstatusAnt=2) and (Estatus=1), o cuando swcargando=True y el estatus es 1, armar SwLeeVenta y SwLecturaFinalPendiente y publicar 2 hasta leer la venta. Probar simulando la pérdida de sondeos durante el colgado de la manguera.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="GIL-13"></a>
#### GIL-13 · 🟠 Alta · correccion · bug — CPREC no verifica el estado de la posición ni reintenta; el mecanismo de reintento del paso 7 es código muerto

- **Ubicación:** `UIGASGILBARCO.pas` líneas 2402-2448, 2801-2850, 1726-1728, 2420
- **Se atiende en:** [E1.6](../PLAN_OPTIMIZACION.md#e16--precios-aplicar-solo-lo-confirmado)
- **Verificación:** sin verificación independiente
- **Qué pasa:** CPREC envía el precio a todas las posiciones sin revisar el estatus (despachando, autorizada, sin comunicación o bloqueada). Si el $20 falla, solo deja rsp='Error en cambio de precios' en TabCmnd, que nadie consulta (PRICES ya fue confirmado por el Bridge). LPrecios[TComb[i]] se actualiza aunque el equipo no haya aceptado el precio. TCambioPrecN1, TCambioPrecN2 y TNuevoPrec solo se inicializan en False o 0 y nunca se activan, así que el paso 7 nunca hace nada. Además, su rama N2 manda nivel 1 en lugar de 2 (2833 y 2841).
- **Evidencia:** grep: TCambioPrecN1 no se asigna en True en ninguna parte (solo en 1726 y 2816). En 2405-2446 no hay ninguna condición sobre estatus.
- **Impacto:** Una posición que estaba despachando o sin comunicación al momento del cambio se queda con el precio anterior hasta el siguiente PRICES: ventas a precio incorrecto, y TOTAL calcula pesos con el precio nuevo.
- **Recomendación:** En CPREC, solo registrar TNuevoPrec y TCambioPrecN1/N2 por manguera y devolver OK. En el paso 7, aplicar cuando estatus=1 con reintentos, usando nivel 2 para N2. Verificar el precio leído en $40 (F7) en la siguiente venta. Registrar en el log las posiciones con precio pendiente.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="GIL-25"></a>
#### GIL-25 · 🟠 Alta · rendimiento · optimizacion — Bitácoras: el JSON completo se guarda en cada envío, char por char, con 10000 líneas en memoria y SaveToFile en cada error o TRACE

- **Ubicación:** `UIGASGILBARCO.pas` líneas 355-409, 411-422, 451-491, 962-1018, 1256, 1272, 1370, 2127, 2898
- **Se atiende en:** [E2.4](../PLAN_OPTIMIZACION.md#e24--bitácoras-que-no-bloquean-append-incremental-rotación-y-sin-json-repetido)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Responder registra 'E ' + JSON completo (≈5 KB con 16 posiciones) cada ≈300 ms. AgregaLogPetRes lo copia char por char (cada carácter es una concatenación con realloc) y lo guarda en ListaLogPetRes (10000 líneas): ≈50 MB en memoria y apenas ≈50 minutos de historia, con las peticiones reales diluidas. Cuando la lista se llena, ListaLog.Delete(0) mueve 40 KB de punteros por cada línea nueva. GuardarLog y GuardarLogPetRes escriben archivos nuevos de hasta decenas de MB, con nombre por segundo, en el hilo principal: en cada excepción (TransmiteComando, ActualizaCampoJSON, AddPeticionJSON, AvanzaPosCiclo, ClientSocket1Read, paso 1), en cada MinutosLog y en el TRACE automático del Bridge, que llega justo cuando el driver ya va lento. Nunca se depuran. Además se registra 'NumPaso=' en cada tick y el carácter de comando crudo (#0..#15 dentro del texto). LOG y LOGREQ no limitan r: el resultado, de varios MB, viaja dos veces dentro del JSON.
- **Evidencia:** Línea 422: AgregaLogPetRes('E ' + resp). Líneas 361-377: concatenación char por char. Líneas 378-379: 'while ListaLog.Count > 10000 do ListaLog.Delete(0)'. Línea 479: SaveToFile. Línea 2898: AgregaLog('NumPaso=' ...).
- **Impacto:** Pausas de segundos en el hilo que atiende el serial (timeouts, datos obsoletos en el Bridge), crecimiento sin control del disco y bitácoras inútiles para diagnosticar peticiones.
- **Recomendación:** Registrar los snapshots solo cuando cambian (hash) o en un log separado rotativo. Usar un buffer circular de tamaño fijo en lugar de Delete(0). Reemplazar el escapado char por char por StringReplace o un SetLength previo. Escribir el log de forma incremental (append) y no completo. Depurar los archivos con más de N días. Limitar r en LOG y LOGREQ (por ejemplo, 500 líneas). Quitar 'NumPaso=' o dejarlo detrás de una bandera de depuración.
- **Esfuerzo:** M · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="GIL-26"></a>
#### GIL-26 · 🟠 Alta · robustez · bug — Recursión mutua entre GuardarLog y GuardarLogPetRes cuando falla el guardado de LogDispPetRes

- **Ubicación:** `UIGASGILBARCO.pas` líneas 451-491
- **Se atiende en:** [E2.4](../PLAN_OPTIMIZACION.md#e24--bitácoras-que-no-bloquean-append-incremental-rotación-y-sin-json-repetido)
- **Verificación:** sin verificación independiente
- **Qué pasa:** GuardarLog guarda LogDisp y llama a GuardarLogPetRes. Si el SaveToFile de LogDispPetRes lanza una excepción (disco lleno, cosa probable con estos archivos de decenas de MB; archivo bloqueado; antivirus), su except llama a GuardarLog(0). Ese vuelve a guardar LogDisp con éxito y vuelve a llamar a GuardarLogPetRes, que falla otra vez, y así sigue. Es una recursión infinita que escribe un archivo LogDisp por nivel hasta EStackOverflow.
- **Evidencia:** Línea 464: GuardarLogPetRes(0) dentro de GuardarLog. Línea 486: GuardarLog(0) dentro del except de GuardarLogPetRes.
- **Impacto:** Caída del servicio y disco saturado precisamente cuando ya está casi lleno.
- **Recomendación:** No llamar a GuardarLog desde el except de GuardarLogPetRes; registrar el error solo con AgregaLog. Proteger con una bandera de reentrancia (Guardando). Probar con una carpeta RutaLog de solo lectura para el archivo PetRes.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="GIL-14"></a>
#### GIL-14 · 🟡 Media · correccion · bug — Índices de grado, manguera y combustible inconsistentes (TMang, TPosx, índice i, TPosTotales y orden del JSON)

- **Ubicación:** `UIGASGILBARCO.pas` líneas 1800-1818, 2425-2443, 2690-2692, 2986-2991, 2711-2722, 3338-3348
- **Se atiende en:** [E1.8](../PLAN_OPTIMIZACION.md#e18--índices-fuera-de-rango-y-carga-de-posiciones-r-)
- **Verificación:** sin verificación independiente
- **Qué pasa:** (a) CPREC usa TMang[i] (HoseId) para el nivel 1 y el índice i para el nivel 2. Si HoseId=0, TMang queda en 0 y se transmite chr($E0+0-1)=$DF, un grado inválido. Si las mangueras no vienen ordenadas, el nivel 2 recibe el precio de otro grado. (b) MangActual := TMang[PosActual] indexa con el número de grado del protocolo (1..16) un arreglo indexado por combustible (1..4): la manguera sale mal si las mangueras no están ordenadas por HoseId, y con un grado mayor que 4 se lee fuera de rango (con -$R-). (c) En el paso 3 se usa xtotallitros[xp] con xp=TPosx, que puede ser un HoseId mayor que 4. (d) ApplyTotalLitrosToJSON escribe el slot TotalLitros[k] en Hoses[k-1] (orden de inserción), y TOTAL multiplica TotalLitros[k] (slot) por LPrecios[TComb[k]] (índice de combustible).
- **Evidencia:** Línea 2425: CambiaPrecio6(xpos, TMang[i], 1, ...). Línea 2428: CambiaPrecio6(xpos, i, 2, ...). Líneas 2692 y 2990: MangActual := TMang[PosActual]. Línea 1807: TPosx[NoComb] := TMang[NoComb].
- **Impacto:** Precios aplicados a la manguera equivocada (sobre todo en el nivel 2), manguera errónea en TRANSACTION y totales asignados al producto equivocado cuando HoseId o MapeoTotales no son la identidad.
- **Recomendación:** Construir en AgregaPosCarga una tabla única por posición: grado del protocolo → (índice, HoseId, ProductId, slot de totales), y usarla en CPREC, en el paso 2, en EstatusDispensarios, en el paso 3, en TOTAL y en ApplyTotalLitrosToJSON. Rechazar HoseId fuera de 1..MCxP. Probar con mangueras declaradas en desorden.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="GIL-15"></a>
#### GIL-15 · 🟡 Media · correccion · bug — ApplyTotalLitrosToJSON busca la posición por índice del arreglo (xpos-1) en lugar de por DispenserId

- **Ubicación:** `UIGASGILBARCO.pas` líneas 3315-3349
- **Se atiende en:** [E1.8](../PLAN_OPTIMIZACION.md#e18--índices-fuera-de-rango-y-carga-de-posiciones-r-)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Si los DispenserId no son contiguos o no vienen en orden (por ejemplo 1, 2, 5), los totales de la posición 5 nunca se publican, porque el índice 4 es mayor o igual que Count, y con orden distinto se escriben en otra posición. ActualizaCampoJSON sí busca por DispenserId. Wayne 2W ya corrigió esta función. Hoy el Bridge no consume Hoses[].Total, así que el impacto es latente.
- **Evidencia:** Líneas 3329-3333: 'posIndex0 := xpos - 1; ... posObj := TlkJSONobject(posCargaList.Child[posIndex0]);'. En cambio, UIGASWAYNE2W.pas 3314-3321 recorre el arreglo comparando Field['DispenserId'].Value = xpos.
- **Impacto:** Totales del snapshot en la posición equivocada; afectaría a cualquier consumidor futuro de Hoses[].Total.
- **Recomendación:** Portar la búsqueda por DispenserId de Wayne 2W y extraerla a una función común del snapshot (FindPosObj).
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="GIL-16"></a>
#### GIL-16 · 🟡 Media · correccion · bug — TOTAL calcula los pesos con el precio actual, lee LPrecios[0] fuera de rango y descarta el totalizador de pesos del equipo

- **Ubicación:** `UIGASGILBARCO.pas` líneas 2394, 2711, 2736, 229
- **Se atiende en:** [E1.7](../PLAN_OPTIMIZACION.md#e17--totales-confiables)
- **Verificación:** sin verificación independiente
- **Qué pasa:** La respuesta TOTAL arma los pesos como TotalLitros[k] × LPrecios[TComb[k]], es decir, litros acumulados por el precio vigente, y no con el totalizador de importe que el equipo sí entrega ($FA): DameTotales devuelve n1..n3 y se descartan. En posiciones con menos de 3 productos, TComb[k]=0 y se lee LPrecios[0] (arreglo 1..4, con -$R-), que es memoria del final de TabCmnd[200]: el importe sale con basura.
- **Evidencia:** Línea 2394: FormatoMoneda(ToTalLitros[3] * LPrecios[TComb[3]]). Línea 2711: DameTotales6(PosCiclo, xtotallitros[1], n1, ...). n1, n2 y n3 no se usan después. Línea 229: LPrecios: array[1..4] of Double.
- **Impacto:** Totales en pesos incorrectos después de cualquier cambio de precio y valores basura en posiciones de 1 o 2 productos.
- **Recomendación:** Guardar los totalizadores de pesos por slot (TotalPesos[1..MCxP]) y devolverlos tal cual. Devolver 0 cuando k > NoComb. Mantener el formato de la respuesta para no tocar el contrato.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="GIL-17"></a>
#### GIL-17 · 🟡 Media · correccion · bug — Lectura de totales: solo 3 grados, xtotallitros[4] sin inicializar, escrituras fuera de rango con MapeoTotales y truco 0→0.01

- **Ubicación:** `UIGASGILBARCO.pas` líneas 1456-1484, 1509-1525, 2531, 2716-2721, 1816, 1459-1461
- **Se atiende en:** [E1.7](../PLAN_OPTIMIZACION.md#e17--totales-confiables)
- **Verificación:** sin verificación independiente
- **Qué pasa:** DameTotales6/8 solo interpretan los grados 1..3 (case 1..3), aunque MCxP=4. El arreglo local xtotallitros[1..4] no se inicializa, así que para un cuarto producto se publica basura de la pila. Si MapeoTotales trae 0 o un valor mayor que 4, xt sale fuera de 1..4 y TotalLitros[xt] escribe fuera del arreglo (con -$R-), corrompiendo el registro. DameTotales6 convierte un totalizador 0 en 0.01; DameTotales8 no lo hace.
- **Evidencia:** Línea 2531: 'xtotallitros: array[1..4] of real;' sin inicializar. Línea 1816: TPosTotales[NoComb] := StrToIntDef(..., TPosx[NoComb]) sin validar el rango. Líneas 1460-1461: 'if rTotalizadorLitros1 = 0 then rTotalizadorLitros1 := 0.01'.
- **Impacto:** Totales incorrectos o memoria corrupta en configuraciones de 4 productos o con MapeoTotales mal capturado.
- **Recomendación:** Generalizar el parseo a N grados con un arreglo de salida inicializado en 0. Validar 1<=slot<=MCxP al leer MapeoTotales y rechazar el INITIALIZE si no se cumple. Quitar o documentar el 0.01 y aplicar el mismo criterio en 6 y 8 dígitos.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="GIL-18"></a>
#### GIL-18 · 🟡 Media · robustez · bug — AgregaPosCarga e Inicializar no validan rangos; además se sondean las posiciones hueco

- **Ubicación:** `UIGASGILBARCO.pas` líneas 1755-1760, 1800-1803, 2004-2014, 2420, 2561, 3013-3023
- **Se atiende en:** [E1.8](../PLAN_OPTIMIZACION.md#e18--índices-fuera-de-rango-y-carga-de-posiciones-r-)
- **Verificación:** sin verificación independiente
- **Qué pasa:** No se valida: DispenserId fuera de 1..32 (TPosCarga[xpos] escribe fuera del arreglo y pisa TabCmnd), más de MCxP=4 mangueras por posición (TComb[5] pisa TPosx), ni ProductId fuera de 1..4 (LPrecios[productID] en 2013 y LPrecios[TComb[i]] en 2420 escriben fuera de rango sobre TAdicf o las cadenas globales). Todo esto con -$R-, en silencio. Además, Timer1 y AvanzaPosCiclo recorren 1..MaxPosCarga, así que las posiciones no configuradas (huecos) también se sondean: tienen timeout de 1 s, pasan a SinComunicacion y generan el log 'DispenserId no encontrado' en cada actualización. Wayne 2W usa SwRecibida y PuedeSondear para evitarlo.
- **Evidencia:** Línea 1760: 'with TPosCarga[xpos] do' sin validar. Línea 1802: inc(NoComb) sin tope. Línea 2013: LPrecios[productID] := ... Línea 2561: 'if PosCiclo in [1..MaxPosCarga]'.
- **Impacto:** Corrupción de memoria o caída del servicio por una configuración errónea, y ciclo de sondeo más lento en sitios con numeración no contigua.
- **Recomendación:** Validar al inicio de AgregaPosCarga: 1<=DispenserId<=16, mangueras <= MCxP y ProductId en 1..High(LPrecios). Responder False con un mensaje claro. Agregar SwRecibida y saltar en AvanzaPosCiclo las posiciones no recibidas. Compilar en pruebas con {$R+}.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="GIL-19"></a>
#### GIL-19 · 🟡 Media · correccion · bug — La bandera 'existe' no se reinicia por manguera: después del primer producto repetido se descartan todas las mangueras siguientes

- **Ubicación:** `UIGASGILBARCO.pas` líneas 1763, 1793-1800
- **Se atiende en:** [E1.8](../PLAN_OPTIMIZACION.md#e18--índices-fuera-de-rango-y-carga-de-posiciones-r-)
- **Verificación:** sin verificación independiente
- **Qué pasa:** existe := false se asigna una sola vez por posición, antes del ciclo de mangueras. En cuanto una manguera repite un producto, existe queda en True para el resto del ciclo y todas las mangueras siguientes, aunque sean de otros productos, se omiten: no se registran en TComb/TPosx ni en Hoses del JSON.
- **Evidencia:** Línea 1763: 'existe := false;' fuera del 'for j := 0 to mangueras.Count - 1'. Línea 1798: 'existe := true;'. No hay ningún reinicio.
- **Impacto:** En posiciones con dos mangueras del mismo producto, los productos declarados después no se pueden prefijar (xp=0, sin selección de grado) y no reportan venta ni totales.
- **Recomendación:** Mover 'existe := false' al inicio del cuerpo del ciclo de mangueras. Probar con Hoses [P1, P1, P2].
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="GIL-20"></a>
#### GIL-20 · 🟡 Media · correccion · bug — Un preset con un combustible que no existe en la posición se envía sin selección de grado (habilita cualquier manguera)

- **Ubicación:** `UIGASGILBARCO.pas` líneas 2165-2167, 2268-2270, 1624-1627, 1652-1655, 721-724
- **Se atiende en:** [E1.3](../PLAN_OPTIMIZACION.md#e13--presets-montos-decimales-y-validaciones)
- **Verificación:** sin verificación independiente
- **Qué pasa:** PosicionDeCombustible devuelve 0 si el combustible pedido no está en la posición. EnviaPresetBomba6/8 interpretan xNMang=0 como 'sin grado' (sGrade=''), así que se autoriza la bomba para cualquier producto. Lo mismo pasa con comb '00' por defecto, que es una venta libre de producto que sí es intencional. No se distingue 'no especificado' de 'inválido'.
- **Evidencia:** Líneas 2166-2167: 'xcomb := StrToIntDef(ss, 0); xp := PosicionDeCombustible(xpos, xcomb);'. Líneas 1624-1625: 'if (xNMang = 0) then sGrade := '''.
- **Impacto:** Un preset en litros pagado para un producto puede despacharse en otro más caro; el ticket y el inventario quedan inconsistentes.
- **Recomendación:** Si xcomb>0 y xp=0, responder 'Combustible no existe en la posicion' sin transmitir. Solo enviar sin grado cuando xcomb=0.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="GIL-21"></a>
#### GIL-21 · 🟡 Media · correccion · bug — El ajuste de decimales del preset solo trunca con exactamente 5 decimales; con 3, 4 o más de 5 rechaza en silencio

- **Ubicación:** `UIGASGILBARCO.pas` líneas 2138-2156, 2244-2257, 2466-2494
- **Se atiende en:** [E1.3](../PLAN_OPTIMIZACION.md#e13--presets-montos-decimales-y-validaciones)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El commit a55a853 trunca a 2 decimales solo si la cadena tiene exactamente 5 decimales. Con 3 o 4 decimales (por ejemplo '150.125') o con más de 5 que no sean ceros, ValidaCifra responde 'Numero de decimales excede maximo permitido' y no se autoriza. Además, cuando sí aplica, trunca en lugar de redondear. Como el Bridge contesta AUTHORIZE como True de inmediato (fire-and-forget), OpenGas no se entera del rechazo salvo que consulte RESPCMND.
- **Evidencia:** Líneas 2141-2145: 'if (i > 0) and (Length(cantidadPreset) - i = 5) then begin cantidadPreset := Copy(cantidadPreset, 1, i + 2); ...'. Línea 2150: rsp := ValidaCifra(ximporte, 4, 2).
- **Impacto:** Clientes en espera con la bomba sin autorizar si OpenGas cambia el formato numérico del preset.
- **Recomendación:** Normalizar siempre con RoundTo o un redondeo explícito a 2 decimales (o truncar de forma documentada) antes de ValidaCifra. Registrar en el log el rechazo con folio. Agregar pruebas con 0, 2, 3, 5 y 6 decimales.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="GIL-22"></a>
#### GIL-22 · 🟡 Media · configuracion · riesgo — Conversión de flotantes dependiente de DecimalSeparator del sistema

- **Ubicación:** `UIGASGILBARCO.pas` líneas 697-705, 2139, 2144, 2245, 2250, 2412, 2394, 1463, 2422, 2668
- **Se atiende en:** [E8.2](../PLAN_OPTIMIZACION.md#e82--configuración-regional-locale-explícita)
- **Verificación:** sin verificación independiente
- **Qué pasa:** StrToFloat, StrToFloatDef, FloatToStr, FormatFloat y FormatoMoneda usan la configuración regional de la cuenta del servicio. Ni el driver ni el .dpr fijan DecimalSeparator o ThousandSeparator (grep sin resultados). uLkJSON sí normaliza a '.', pero los parámetros 'pos|comb|150.00|...' y los precios 'p1|p2' se convierten con StrToFloat local. Con una configuración regional que use coma decimal, AUTHORIZE da 'Error en Importe' y CPREC dispara el Exit del hallazgo de CPREC. La respuesta TOTAL usaría coma.
- **Evidencia:** Línea 2139: ximporte := StrToFloat(cantidadPreset). Línea 2412: StrToFloatDef(ExtraeElemStrSep(precios, TComb[i], '|'), -1). No existe ninguna asignación a DecimalSeparator en el repositorio.
- **Impacto:** Fallas masivas de AUTHORIZE y PRICES al instalar en equipos con otra configuración regional.
- **Recomendación:** Fijar DecimalSeparator := '.' y ThousandSeparator := ',' en ServiceExecute, o usar TFormatSettings explícito en las conversiones del protocolo. Probar con la configuración regional es-ES.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="GIL-23"></a>
#### GIL-23 · 🟡 Media · configuracion · bug — Las variables GtwDivImporte y GtwDivLitros de INITIALIZE se ignoran en las posiciones configuradas

- **Ubicación:** `UIGASGILBARCO.pas` líneas 1707-1708, 1777-1778, 1980-1983, 1572-1573, 1606
- **Se atiende en:** [E8.2](../PLAN_OPTIMIZACION.md#e82--configuración-regional-locale-explícita)
- **Verificación:** sin verificación independiente
- **Qué pasa:** AgregaPosCarga asigna DivImporte := GtwDivImporte y DivLitros := GtwDivLitros a todas las posiciones (1707-1708), pero al configurar cada posición las sobrescribe con IfThen(DigitosGilbarco = 8, 1000, 100) (1777-1778). Las lecturas de venta y de importe en proceso usan TPosCarga[].DivImporte y DivLitros, así que los valores capturados en las variables nunca se aplican.
- **Evidencia:** Línea 1777: 'DivImporte := IfThen(DigitosGilbarco = 8, 1000, 100);'. Línea 1573: rPesos := rPesos / TPosCarga[PosCiclo].DivImporte.
- **Impacto:** En equipos con otra cantidad de decimales, el importe sale multiplicado o dividido por 10 sin aviso. El recálculo de volumen (importe/precio) además lo disfraza.
- **Recomendación:** Usar las variables si vienen en INITIALIZE (o permitir 'DivImporte' y 'DivLitros' por posición en el ini) y caer a 100/1000 solo si no se configuraron. Registrar en el log los divisores efectivos por posición.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="GIL-24"></a>
#### GIL-24 · 🟡 Media · correccion · riesgo — El volumen reportado por el equipo se reemplaza por importe/precio con tolerancia de 0.01 L

- **Ubicación:** `UIGASGILBARCO.pas` líneas 2665-2667, 2679-2681
- **Se atiende en:** [E1.2](../PLAN_OPTIMIZACION.md#e12--importes-y-volúmenes-de-venta-mal-calculados)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Después de leer la venta, si |volumen − round3(importe/precio)| > 0.01, se publica el volumen calculado en lugar del medido. Si el precio leído es 0 o está mal escalado (GtwDivPrecio), dividefloat da 0 o un valor erróneo y la venta se reporta con ese volumen. Wayne 2W usa una tolerancia de 0.5.
- **Evidencia:** Líneas 2665-2667: 'xvolumen := ajustafloat(dividefloat(importe, precio), 3); if abs(volumen - xvolumen) > 0.01 then volumen := xvolumen;'.
- **Impacto:** Volúmenes no metrológicos en controles volumétricos, o ventas con volumen 0 si el precio viene en 0.
- **Recomendación:** No reemplazar el volumen medido. Si la diferencia supera un umbral, registrar una alerta y conservar el valor del equipo. Si precio <= 0, nunca recalcular. Validarlo con el área metrológica (CENAM).
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="GIL-27"></a>
#### GIL-27 · 🟡 Media · robustez · bug — La reapertura del puerto en el except de TransmiteComando pierde los data triggers $F0/$8A; un RUN repetido los acumula

- **Ubicación:** `UIGASGILBARCO.pas` líneas 1379-1391, 655-656, 3033-3039, 3041-3052, 1229, 1238
- **Se atiende en:** [E2.8](../PLAN_OPTIMIZACION.md#e28--recepción-serial-robusta-tramas-bcc-acknak)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Los data triggers se agregan solo en Iniciar. En Async Pro viven en el despachador del puerto, que se destruye al cerrarlo (certeza media). Si TransmiteComando cae en su except y reabre el puerto (Open False, Sleep 200, Open True), las respuestas de longitud variable dependen de nuevo de iBytesEsperados. La respuesta $50 con 1-5 grados (34-154 bytes) nunca llega a 184 o 256, así que se agota el timeout, Lee Totales falla para siempre y se activa el fallback de totales estimados, hasta el siguiente HALT/RUN. Un RUN con el puerto ya abierto vuelve a agregar los triggers y sobrescribe wTriggerEOT/wTriggerLF. Además, después de FlushInBuffer puede llegar un TriggerAvail atrasado con un Count que ya no es válido, y GetChar se ejecuta sobre un buffer vacío (posible excepción que provoca una nueva reapertura).
- **Evidencia:** Líneas 1386-1388: 'pSerial.Open := False; Sleep(200); pSerial.Open := True;' sin AddDataTrigger. Líneas 655-656: los triggers solo se agregan en Iniciar. Línea 1229: iBytesEsperados := 184 para $50.
- **Impacto:** Totales que fallan permanentemente después de un error serial transitorio, y totales estimados publicados.
- **Recomendación:** Encapsular la apertura en AbrirPuerto: Open, RemoveAllTriggers y AddDataTrigger, y usarla en Iniciar y en la recuperación. En pSerialTriggerAvail leer con 'while pSerial.CharReady do' en lugar de confiar en Count. Probar desconectando y reconectando el convertidor USB-serial.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="GIL-28"></a>
#### GIL-28 · 🟡 Media · rendimiento · optimizacion — Esperas activas y Sleep fijos en el diálogo serial

- **Ubicación:** `UIGASGILBARCO.pas` líneas 1254-1261, 1268-1271, 1348-1355, 1359-1368, 1334, 1340, 1356
- **Se atiende en:** [E2.5](../PLAN_OPTIMIZACION.md#e25--reentrancia-comandos-del-bridge-durante-una-transacción-serial), [E4.3](../PLAN_OPTIMIZACION.md#e43--ciclo-serial-eficiente)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Después de cada PutChar, el bucle 'repeat ProcessCommunications until OutBuffUsed=0 or timeout' gira al 100% de CPU sin Sleep. En el bloque de datos $20 lo hace por cada byte. Si OutBuffUsed no llega a 0 (control de flujo o puerto en mal estado), gira GtwTimeout/3 por cada byte: unos 4 s para 12 bytes, sin bombear mensajes. La espera de la respuesta usa Sleep(5), con granularidad real de ~15.6 ms. Los Sleep(10) y Sleep(GtwTiempoCmnd=100) son fijos y se suman en cada $20 (≈200 ms muertos por transacción). Hay ramas idénticas en 1264-1267.
- **Evidencia:** Líneas 1259-1261: 'repeat pSerial.ProcessCommunications; until ((pSerial.OutBuffUsed = 0) or (timerexpired(etTimeOut)));'. Líneas 1348-1355: lo mismo por cada byte del bloque de datos.
- **Impacto:** Consumo de CPU y latencia del ciclo (menos sondeos por segundo, ventas detectadas más tarde).
- **Recomendación:** Enviar el bloque completo con PutString y esperar el vaciado una sola vez con Sleep(1) en el ciclo. Usar eventos o triggers de Async Pro (OnTriggerOutbuffFree) o un hilo serial con WaitForSingleObject. Hacer configurables y medir los Sleep entre comandos (Gilbarco suele necesitar unos ~20-50 ms de turnaround, no 100 ms).
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="GIL-29"></a>
#### GIL-29 · 🟡 Media · concurrencia · riesgo — Carrera de arranque y de paro entre el hilo principal (Timer2) y el hilo del servicio (ServiceExecute)

- **Ubicación:** `UIGASGILBARCO.dfm` líneas 38-43 (dfm); UIGASGILBARCO.pas 310-342, 3071-3095
- **Módulos afectados:** UIGASGILBARCO.dfm, UIGASGILBARCO.pas, resto de drivers (mismo patrón)
- **Se atiende en:** [E0.2](../PLAN_OPTIMIZACION.md#e02--identificar-el-hilo-de-cada-evento-instrumentación), [E2.3](../PLAN_OPTIMIZACION.md#e23--arranque-y-paro-ordenados-del-servicio)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Timer2 está habilitado en el .dfm y empieza a disparar en el hilo principal desde Application.CreateForm. ServiceExecute, que crea ListaLog, ListaLogPetRes y rootJSON y asigna Host/Port, corre en el hilo del servicio cuando el SCM lo arranca. Si Timer2 gana la carrera (arranques lentos del SCM al encender el equipo): activa ClientSocket1 con el Host/Port del .dfm (127.0.0.1:8585) y usa listas en nil, lo que provoca un AV. Luego ServiceExecute intenta cambiar Host/Port con el socket activo; ScktComp lanza 'cannot change while active', el except usa ListaLog (todavía nil), ServiceExecute aborta y el servicio cae. Al detenerse, la línea 342 (ClientSocket1.Active := False) se ejecuta en el hilo del servicio sobre un socket del hilo principal. Certeza media, porque depende de la latencia del SCM.
- **Evidencia:** .dfm líneas 38-43: Timer2 sin 'Enabled = False' y con Interval = 200. ServiceExecute crea ListaLog en la línea 335, después de asignar ClientSocket1.Port en la 322.
- **Impacto:** Fallas de arranque intermitentes y difíciles de diagnosticar, y conexión al puerto equivocado.
- **Recomendación:** Poner Enabled = False en Timer2 en el .dfm y habilitarlo al final de la inicialización de ServiceExecute (por ejemplo, con PostMessage o un flag que lea Timer2Timer). Crear las listas antes que cualquier otra cosa. Al detenerse, pedir al hilo principal que cierre el socket.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="GIL-30"></a>
#### GIL-30 · 🟡 Media · configuracion · bug — ServiceExecute: StrToInt sin valor por defecto, TIniFile sin liberar y log de error guardado con el nombre equivocado

- **Ubicación:** `UIGASGILBARCO.pas` líneas 319-353
- **Se atiende en:** [E2.3](../PLAN_OPTIMIZACION.md#e23--arranque-y-paro-ordenados-del-servicio)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El puerto de ServidorSocket y MinutosLog se convierten con StrToInt: si ServidorSocket viene sin puerto o MinutosLog vacío, se lanza EConvertError. En el except se usan ListaLog y ListaLogPetRes, que todavía no existen (se crean en 335-336), lo que da un AV dentro del except y el servicio no arranca con un error confuso. El TIniFile nunca se libera. El log de error se guarda como 'LogDispPetRes...' con el contenido de ListaLog, y GuardarLogPetRes lo sobrescribe en el mismo segundo.
- **Evidencia:** Línea 322: StrToInt(ExtraeElemStrSep(..., 2, ':')). Línea 324: StrToInt(config.ReadString('CONF', 'MinutosLog', '0')). Línea 347: ListaLog.SaveToFile(rutaLog + '\LogDispPetRes' ...).
- **Impacto:** El servicio no arranca por un error de captura en el ini, y se pierde el diagnóstico.
- **Recomendación:** Usar StrToIntDef o ReadInteger. Crear las listas al principio. Liberar config en un try/finally. Guardar el error en LogDisp. Registrar la configuración efectiva al arrancar.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="GIL-31"></a>
#### GIL-31 · 🟡 Media · memoria_recursos · bug — Inicializar: el JSON parseado no se libera, y StrToInt sobre una variable sin uso aborta el INITIALIZE

- **Ubicación:** `UIGASGILBARCO.pas` líneas 1927, 1943-1946, 1956, 1972-1973, 2002-2013
- **Se atiende en:** [E2.7](../PLAN_OPTIMIZACION.md#e27--initialize-idempotente-y-seguro-con-ventas-en-curso)
- **Verificación:** sin verificación independiente
- **Qué pasa:** js := TlkJSON.ParseText(json) nunca se libera; se fuga el árbol completo de configuración en cada INITIALIZE, que ahora puede repetirse en caliente. DecimalesGilbarco se convierte con StrToInt sin default y no se usa en ninguna parte: un valor como '2.0' o vacío aborta todo el INITIALIZE cuando el puerto ya se configuró. Tampoco se verifica que existan Consoles, Dispensers ni Products (AV atrapado con un mensaje genérico).
- **Evidencia:** Línea 1943: js := TlkJSON.ParseText(json); no hay js.Free (grep sin resultados en todos los drivers). Línea 1973: DecimalesGilbarco := StrToInt(...). DecimalesGilbarco solo se asigna.
- **Impacto:** Fuga de memoria acumulativa y rechazos de INITIALIZE por una variable irrelevante.
- **Recomendación:** try/finally js.Free. Usar StrToIntDef o eliminar DecimalesGilbarco. Validar los nodos y responder 'False|Falta nodo X|'.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="GIL-32"></a>
#### GIL-32 · 🟡 Media · observabilidad · bug — ProcesaComandos se traga todas las excepciones y deja el comando sin respuesta, reintentándose indefinidamente

- **Ubicación:** `UIGASGILBARCO.pas` líneas 2116, 2462-2463
- **Se atiende en:** [E1.5](../PLAN_OPTIMIZACION.md#e15--tabla-de-comandos-tabcmnd-y-respuestas-de-comandos-asíncronos)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Todo ProcesaComandos está envuelto en 'try ... except end;' sin registro. Si se produce un AV (por ejemplo, TOTAL con una posición fuera de rango: 'with TPosCarga[xpos]' en 2379 sin validar) o cualquier otra excepción, el ciclo se aborta, el comando actual no se marca como respondido y en la siguiente llamada vuelve a fallar. Igual que con el Exit de CPREC, bloquea los comandos posteriores sin dejar ningún rastro.
- **Evidencia:** Líneas 2462-2463: 'except end;'. Línea 2379: 'with TPosCarga[xpos] do' sin comprobar xpos in [1..MaxPosCarga] (TotalesBomba solo verifica xpos>=1).
- **Impacto:** Comandos 'perdidos' sin diagnóstico posible.
- **Recomendación:** Poner try/except por comando: registrar 'Excepcion comando X: msg', marcar SwResp con un error y continuar. Validar xpos en TOTAL (y en TotalesBomba, xpos<=MaxPosCarga).
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="GIL-33"></a>
#### GIL-33 · 🟡 Media · correccion · riesgo — Los comandos no tienen vigencia: un AUTHORIZE recibido con el proceso detenido se ejecuta al hacer RUN

- **Ubicación:** `UIGASGILBARCO.pas` líneas 691-738, 772-809, 2121-2125, 3141-3217
- **Se atiende en:** [E1.5](../PLAN_OPTIMIZACION.md#e15--tabla-de-comandos-tabcmnd-y-respuestas-de-comandos-asíncronos)
- **Verificación:** sin verificación independiente
- **Qué pasa:** ClientSocket1Read acepta AUTHORIZE, STOP, START, PAYMENT y PRICES aunque estado<=0 (Timer1 apagado), y los deja en TabCmnd. ProcesaComandos ejecuta cualquier comando activo sin respuesta sin importar su antigüedad, y EjecutaComando solo expira de forma perezosa los slots de más de 1 minuto que recorre al buscar lugar. Después de un HALT, un AUTHORIZE pendiente se ejecuta minutos más tarde al hacer RUN si la posición conserva el estatus 1 o 5 de antes del HALT. Además, los slots respondidos no se liberan: siguen SwActivo y consumen capacidad.
- **Evidencia:** AutorizarVenta (691-738) no revisa estado. Línea 2123: 'if (TabCmnd[xcmnd].SwActivo) and (not TabCmnd[xcmnd].SwResp)', sin revisar la hora. Línea 780: la expiración solo ocurre durante la búsqueda.
- **Impacto:** Autorizaciones fuera de contexto (cliente que ya se fue o preset pagado por otra persona).
- **Recomendación:** Rechazar AUTHORIZE, STOP, START y PAYMENT con 'False|Proceso detenido|' si estado<>1. En ProcesaComandos, descartar comandos de despacho con más de N segundos (por ejemplo, 30) y responder 'Comando expirado'. Liberar el slot tras la consulta RESPCMND o a los 60 s.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="GIL-34"></a>
#### GIL-34 · 🟡 Media · correccion · riesgo — Autorizar, detener y reanudar no verifican su efecto; DVC y REANUDAR siempre responden OK

- **Ubicación:** `UIGASGILBARCO.pas` líneas 1200-1204, 2496-2509, 2347-2374
- **Se atiende en:** [E5.4](../PLAN_OPTIMIZACION.md#e54--comandos-homogéneos-entre-marcas)
- **Verificación:** sin verificación independiente
- **Qué pasa:** $10 y $30 no esperan respuesta (bOk := true, iMaxIntentos := 0), así que Autoriza, DetenerDespacho y ReanudaDespacho siempre devuelven True. OCC y OCL marcan SwPreset y responden OK aunque el byte se haya perdido por ruido. DVC y REANUDAR devuelven OK aunque la posición no esté en el estado requerido y no se haga nada.
- **Evidencia:** Líneas 1200-1204: 'if (iComando in [$10, $30, $F0]) then begin bOk := true; iMaxIntentos := 0;'. Líneas 2349-2359: rsp := 'OK' antes de evaluar el estatus.
- **Impacto:** OpenGas cree que la bomba está autorizada o detenida cuando no lo está: cliente en espera, o despacho que no se detiene.
- **Recomendación:** Después de $10, sondear el estatus ($0x) y esperar $8x/$9x; si no, reintentar una vez y responder 'No se pudo autorizar'. Después de $30, esperar $Cx/$Fx. Para DVC y REANUDAR, responder un error si el estatus no es el esperado.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="GIL-35"></a>
#### GIL-35 · 🟡 Media · correccion · bug — BLOCK/UNBLOCK y los modos: respuestas faltantes, bloqueo que no impide autorizar y estado que no se publica

- **Ubicación:** `UIGASGILBARCO.pas` líneas 518-533, 553-568, 2133-2135, 2239-2241, 2960-2985, 1052-1070
- **Se atiende en:** [E5.4](../PLAN_OPTIMIZACION.md#e54--comandos-homogéneos-entre-marcas)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Bloquear y Desbloquear no responden nada cuando MaxPosCarga < xpos <= 32, así que el folio vence en el Bridge por timeout. Una posición bloqueada (SwDesHabil) solo deja de sondearse: OCC y OCL no revisan SwDesHabil y la autorizan, y en el JSON conserva su último estatus en lugar de 7 (el '7' solo existe en la cadena xestado del log). DesactivaModoPrepago responde True sin hacer nada cuando PermiteModoNormal=No.
- **Evidencia:** Líneas 526-530: 'else if (xpos in [1..maxposcarga]) then' sin else. Línea 2135: solo revisa estatus. Línea 3000: publica estatus, no xestado. Líneas 1052-1070.
- **Impacto:** Timeouts en OpenGas, posiciones 'bloqueadas' que siguen despachando y estado mal reportado.
- **Recomendación:** Contestar 'False|Posicion no Existe|' en todos los casos fuera de rango. Rechazar OCC y OCL si SwDesHabil. Publicar 7 en el JSON. Responder False en FULLSERVICE cuando no está permitido.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="GIL-36"></a>
#### GIL-36 · 🟡 Media · correccion · bug — SwNivelPrecio se evalúa sobre la posición anterior porque 'with' ya tomó la dirección del registro antes de AvanzaPosCiclo

- **Ubicación:** `UIGASGILBARCO.pas` líneas 2857, 2891-2897, 2565-2580
- **Se atiende en:** [E1.9](../PLAN_OPTIMIZACION.md#e19--coherencia-del-estado-publicado-estatus-fin-de-venta-horaocc-estado)
- **Verificación:** sin verificación independiente
- **Qué pasa:** En L01, 'with TPosCarga[PosCiclo] do' calcula la dirección del registro al entrar. Dentro de ese bloque se llama a AvanzaPosCiclo, que cambia PosCiclo, y luego a 'if SwNivelPrecio then NumPaso := 0'. SwNivelPrecio se resuelve sobre el registro de la posición ANTERIOR. El paso 0 (PonNivelPrecio) de la nueva posición se ejecuta o no según la bandera de su vecina, así que después de una venta o una reconexión el nivel de precio 1 puede no restablecerse nunca.
- **Evidencia:** Línea 2857: 'with TPosCarga[PosCiclo] do'. Líneas 2893-2896: 'AvanzaPosCiclo; NumPaso := 1; if SwNivelPrecio then NumPaso := 0;'.
- **Impacto:** La bomba puede quedarse en nivel de precio 2 (crédito) para ventas libres o en modo Normal.
- **Recomendación:** Después de AvanzaPosCiclo, usar TPosCarga[PosCiclo].SwNivelPrecio de forma explícita, fuera del with. Probar con 2 posiciones, una con la bandera activa.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="GIL-37"></a>
#### GIL-37 · 🟡 Media · robustez · bug — Al arrancar, una sola falla del primer sondeo marca la posición sin comunicación y no se vuelve a sondear durante 55-65 s

- **Ubicación:** `UIGASGILBARCO.pas` líneas 2585, 2590-2599, 2636-2640
- **Se atiende en:** [E1.4](../PLAN_OPTIMIZACION.md#e14--sondeo-que-se-congela-livelocks-y-bloqueos-de-la-máquina-de-estados)
- **Verificación:** sin verificación independiente
- **Qué pasa:** La tolerancia de MaxFallasEstatus solo aplica si Estatusant<>0. Después de RUN todas las posiciones tienen estatus 0, así que la primera falla (ruido al abrir el puerto, un byte perdido) cumple 'estatusant=0 and estatus=0 and not swcargando' y pone SinComunicacion := True, HoraDesconexion := Now. La posición se publica como 0 y no se sondea durante ~1 minuto.
- **Evidencia:** Línea 2593: 'if (Estatusant <> 0) and (FallosEstat < MaxFallasEstatus)'. Líneas 2636-2640: SinComunicacion := True.
- **Impacto:** Posiciones 'sin comunicación' falsas durante el primer minuto después de cada RUN o INITIALIZE.
- **Recomendación:** Aplicar el umbral de FallosEstat también cuando Estatusant=0 (exigir MaxFallasEstatus fallas antes de SinComunicacion), o reintentar más rápido (5 s) las primeras veces.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="GIL-38"></a>
#### GIL-38 · 🟡 Media · rendimiento · optimizacion — Lee Totales y Lee Venta se reintentan sin backoff; un TOTAL puede quedar sin respuesta para siempre

- **Ubicación:** `UIGASGILBARCO.pas` líneas 874-921, 892, 2703-2759, 2392-2398, 2873-2884
- **Se atiende en:** [E1.4](../PLAN_OPTIMIZACION.md#e14--sondeo-que-se-congela-livelocks-y-bloqueos-de-la-máquina-de-estados), [E4.3](../PLAN_OPTIMIZACION.md#e43--ciclo-serial-eficiente)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Si $50 falla y no hay venta pendiente (PendingVentaActiva=False), AplicarFallbackTotales solo incrementa ContFallosTotales y SwTotales sigue en True. El paso 3 se repite en cada vuelta de esa posición (≈3.2 s por intento con 3 reintentos de 1 s) y frena a todas las demás. El TOTAL pendiente nunca cumple '(not swtotales) or SecondsBetween <= 10' y RESPCMND devuelve '*' hasta que el slot expira. Lo mismo con Lee Venta: 4 visitas por vuelta.
- **Evidencia:** Línea 892: 'if (ContFallosTotales >= xLimite) and PendingVentaActiva then'. Sin rama else para el caso sin pendiente. Línea 2392: condición de respuesta del TOTAL.
- **Impacto:** Ciclo de sondeo lento en todo el sitio por una bomba con problemas de totales, y totales que nunca se contestan.
- **Recomendación:** Después de N fallas, usar backoff exponencial (30 s, 60 s...), responder el TOTAL con 'False|Totales no disponibles|' y registrar una alarma. Limitar el presupuesto de tiempo por vuelta.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="GIL-39"></a>
#### GIL-39 · 🟡 Media · protocolo · riesgo — ClientSocket1Read no delimita mensajes: una lectura parcial o dos mensajes concatenados rompen el comando

- **Ubicación:** `UIGASGILBARCO.pas` líneas 3121-3137
- **Módulos afectados:** UIGASGILBARCO.pas, UIGASBRIDGE.pas, resto de drivers
- **Se atiende en:** [E6.1](../PLAN_OPTIMIZACION.md#e61--framing-y-buffer-por-conexión-en-los-dos-sentidos-y-del-lado-de-opengas)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Cada OnRead se toma como exactamente un mensaje completo (ReceiveText). El protocolo Bridge-driver no tiene terminador ni longitud. Un INITIALIZE grande (varios KB) puede llegar fragmentado: el JSON queda truncado y se responde con una excepción, y el resto se interpreta como un mensaje nuevo con folio basura. Si llegaran dos respuestas juntas (por ejemplo, con envíos duplicados durante reconexiones), la segunda se agregaría a los parámetros de la primera. El armado de parametro con ExtraeElemStrSep dentro del ciclo es O(n²) sobre mensajes grandes.
- **Evidencia:** Línea 3121: mensaje := Socket.ReceiveText. Líneas 3132-3133: 'for i := 4 to NoElemStrSep(mensaje, '|') do parametro := parametro + ExtraeElemStrSep(mensaje, i, '|') + '|';'.
- **Impacto:** Comandos perdidos o mal interpretados de forma esporádica, sobre todo INITIALIZE.
- **Recomendación:** Acordar con el Bridge un delimitador de trama (por ejemplo, ETX o CRLF, o un prefijo de longitud), acumular en un buffer por conexión y procesar solo las tramas completas. Armar parametro con Copy desde la posición del tercer '|'. Hay que desplegar Bridge y drivers de forma coordinada.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** sí

<a id="GIL-47"></a>
#### GIL-47 · 🟡 Media · pruebas · deuda_tecnica — No hay modo emulación ni pruebas del protocolo Gilbarco

- **Ubicación:** `UIGASGILBARCO.pas` líneas 1-3404
- **Se atiende en:** [E0.4](../PLAN_OPTIMIZACION.md#e04--simuladores-de-opengas-y-de-driver--batería-de-pruebas-de-protocolo), [E7.4](../PLAN_OPTIMIZACION.md#e74--separar-la-lógica-de-protocolo-serial-de-la-del-servicio-testeable)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Wayne 2W tiene un modo emulación (SwModoEmulacion, AvanzaEmulacion) para validar el flujo con el Bridge sin hardware. Gilbarco no lo tiene: grep 'emula' no da resultados, aunque el commit inicial dice 'Ventas aleatorias al modo emulación'. Tampoco hay pruebas unitarias de las funciones puras (BcdToInt, LrcCheckChar, DLChar, ValidaLRC, el armado de tramas de preset y precio, ni el parseo de $40/$50). Las correcciones propuestas aquí (EOT, totales de 8 dígitos, mapeo de grados) no se pueden validar sin equipo.
- **Evidencia:** grep -i 'emula' en UIGASGILBARCO.pas da 0 coincidencias; en UIGASWAYNE2W.pas da 43.
- **Impacto:** Alto riesgo de regresión en producción con cada cambio.
- **Recomendación:** Extraer las funciones de trama a una unidad UGilbarcoProto.pas con pruebas DUnit (vectores conocidos de status, $40, $50 de 6 y 8 dígitos, preset y precio). Portar el modo emulación de Wayne 2W para Gilbarco (bomba virtual que responda $0x, $40, $50 y $60).
- **Esfuerzo:** L · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="GIL-40"></a>
#### GIL-40 · ⚪ Baja · rendimiento · optimizacion — El snapshot se recorre y se regenera completo: EstatusDispensarios es O(N²) y GenerateText corre cada 3 ticks

- **Ubicación:** `UIGASGILBARCO.pas` líneas 2951-3008, 3230-3278, 3017, 2913-2914, 3315-3349
- **Se atiende en:** [E4.2](../PLAN_OPTIMIZACION.md#e42--json-más-barato-generar-menos-redondear-y-buscar-menos)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Cada sondeo de estatus y cada vuelta de AvanzaPosCiclo llaman a EstatusDispensarios, que hace 3 ActualizaCampoJSON por posición. Cada ActualizaCampoJSON busca 'PosCarga' por nombre y recorre la lista comparando DispenserId: unas 400 búsquedas de campo y conversiones Variant por sondeo con 16 posiciones. Además, TlkJSON.GenerateText serializa todo el árbol, incluidos Hoses[].Total y TotalesEstimados que el Bridge no usa, cada ~300 ms. Se arma la cadena xmodo, que no se usa.
- **Evidencia:** Líneas 2956-3001: un ciclo con 3 ActualizaCampoJSON. Líneas 3241-3258: búsqueda lineal. Línea 2959: xmodo := xmodo + ModoOpera[1] (sin uso).
- **Impacto:** CPU y latencia en el hilo que atiende el serial; menor en sitios chicos.
- **Recomendación:** Guardar referencias directas a los TlkJSONobject por posición (arreglo 1..32) al construir PosCarga. Actualizar solo los campos que cambiaron. Generar el JSON solo si hubo cambios o venció el intervalo. Quitar xmodo.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="GIL-41"></a>
#### GIL-41 · ⚪ Baja · seguridad · riesgo — LOGIN sin secreto: la 'contraseña' es MD5(usuario|fecha-hora al minuto) y el Token nunca se valida

- **Ubicación:** `UIGASGILBARCO.pas` líneas 3363-3382, 493-503, 224
- **Se atiende en:** [E8.1](../PLAN_OPTIMIZACION.md#e81--autenticación-licencia-y-modo-emulación)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Login compara la contraseña con MD5(usuario + '|' + yyyy-mm-ddThh:nn), que cualquiera puede calcular. El Token resultante (variable global) no se revisa en ningún comando. Si el login se hace justo en el cambio de minuto, falla aunque sea legítimo.
- **Evidencia:** Línea 3369: 'if MD5(usuario + '|' + FormatDateTime('yyyy-mm-dd', Date) + 'T' + FormatDateTime('hh:nn', Now)) <> password'. grep: Token solo aparece en Login y Logout.
- **Impacto:** Da una falsa sensación de autenticación; cualquiera con acceso al puerto 1001 del Bridge puede mandar comandos.
- **Recomendación:** Documentar que no hay autenticación, o implementarla de verdad en el Bridge (lado OpenGas) con un secreto configurable (HMAC) y validación del token por comando. Mientras tanto, limitar el Bridge a localhost o a una IP permitida.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** sí

<a id="GIL-42"></a>
#### GIL-42 · ⚪ Baja · robustez · bug — SHUTDOWN no despierta al hilo del servicio: Terminate se llama mientras ese hilo está bloqueado en GetMessage

- **Ubicación:** `UIGASGILBARCO.pas` líneas 680-689, 340-342
- **Se atiende en:** [E2.3](../PLAN_OPTIMIZACION.md#e23--arranque-y-paro-ordenados-del-servicio)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Shutdown, ejecutado desde ClientSocket1Read en el hilo principal, llama a ServiceThread.Terminate. El hilo del servicio está bloqueado en ProcessRequests(True), que es un GetMessage, y solo revisa Terminated antes de bloquearse. Mientras no llegue otro mensaje del SCM el servicio no termina, aunque ya se respondió 'True|'. Certeza media-alta según la implementación de SvcMgr de Delphi 7.
- **Evidencia:** Línea 687: ServiceThread.Terminate. Líneas 340-341: 'while not Terminated do ServiceThread.ProcessRequests(True);'.
- **Impacto:** SHUTDOWN no tiene efecto inmediato; el operador cree que el servicio se detuvo.
- **Recomendación:** Después de Terminate, ejecutar PostThreadMessage(ServiceThread.ThreadID, WM_NULL, 0, 0), o usar ServiceThread.ProcessRequests(False) con un ciclo y espera corta. Probar SHUTDOWN y verificar el estado en services.msc.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="GIL-43"></a>
#### GIL-43 · ⚪ Baja · correccion · bug — EjecutaComando lee TabCmnd[201] y hay resultados de función que nunca se inicializan

- **Ubicación:** `UIGASGILBARCO.pas` líneas 778-792, 1556-1580, 1676-1835, 1837-1923
- **Se atiende en:** [E1.5](../PLAN_OPTIMIZACION.md#e15--tabla-de-comandos-tabcmnd-y-respuestas-de-comandos-asíncronos)
- **Verificación:** sin verificación independiente
- **Qué pasa:** En EjecutaComando, cuando ind llega a 201 se evalúa TabCmnd[201].SwActivo antes de 'ind > 200', y dentro del ciclo hasta se escribe si el dato basura parece un comando activo y viejo. Pasa con 200 comandos activos en menos de un minuto. DameLecturas6 atrapa la excepción sin asignar Result, así que devuelve un booleano indeterminado. AgregaPosCarga e IniciaPSerial no asignan Result en el camino exitoso y funcionan solo porque la variable receptora vale ''.
- **Evidencia:** Líneas 778-786: 'repeat inc(ind); if (TabCmnd[ind].SwActivo) ... until (not TabCmnd[ind].SwActivo) or (ind > 200);'. Líneas 1576-1579: except sin Result.
- **Impacto:** Corrupción de memoria rara, y lecturas de venta tomadas como exitosas sin datos válidos.
- **Recomendación:** Reescribir el ciclo como 'for ind := 1 to 200 do'. Inicializar Result := False o '' al inicio de cada función. Compilar las pruebas con {$R+}.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="GIL-44"></a>
#### GIL-44 · ⚪ Baja · protocolo · riesgo — HoraOcc tiene resolución de minuto y es la hora de lectura, no la del fin de venta

- **Ubicación:** `UIGASGILBARCO.pas` líneas 1782, 2664, 2678, 2697
- **Módulos afectados:** UIGASGILBARCO.pas, UIGASBRIDGE.pas, OpenGas, resto de drivers
- **Se atiende en:** [E5.1](../PLAN_OPTIMIZACION.md#e51--semántica-única-de-estatus-y-campos-de-venta)
- **Verificación:** sin verificación independiente
- **Qué pasa:** HoraOcc se asigna con Now al leer la venta en el paso 2, que puede ocurrir segundos o vueltas después del EOT, y se publica como 'yyyy-mm-ddThh:nn'. Dos ventas en la misma posición dentro del mismo minuto quedan con HoraOcc idéntica. Si OpenGas usa HoraOcc para distinguir ventas nuevas, puede omitir la segunda. Es el mismo formato que en el resto de los drivers.
- **Evidencia:** Línea 2664: HoraOcc := Now. Línea 2697: FormatDateTime('hh:nn', HoraOcc).
- **Impacto:** Ventas rápidas consecutivas que se confunden.
- **Recomendación:** Registrar la hora en que se detectó el EOT. Acordar con OpenGas un formato con segundos ('hh:nn:ss') o un contador de transacción por posición (TransId) en el snapshot y en TRANSACTION.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** sí

<a id="GIL-45"></a>
#### GIL-45 · ⚪ Baja · configuracion · riesgo — Valores hardcodeados y sin validar: tracing APRO siempre activo, anchos BCD fijos y GtwTimeout/GtwTiempoCmnd sin límites

- **Ubicación:** `UIGASGILBARCO.pas` líneas 1916-1918, 1152, 1166, 1635, 1640, 1966-1967, 1988-1991
- **Se atiende en:** [E0.1](../PLAN_OPTIMIZACION.md#e01--build-reproducible-de-ambos-ejecutables)
- **Verificación:** sin verificación independiente
- **Qué pasa:** IniciaPSerial activa siempre el tracing de Async Pro hacia 'c:\\OGTrace.txt'; el .dfm también trae Tracing=tlOn con TraceName relativo 'APRO.TRC', Baud=5700 y Port=8585. Las tramas de precio y preset usan anchos fijos ('%4.4d' para el precio en 6 dígitos y '%5.5d' para el preset en litros): si GtwDivPrecio=1000 o el precio es de 100.00 o más, se generan más dígitos BCD y la trama sale corrupta sin ningún aviso. GtwTimeout y GtwTiempoCmnd aceptan 0 o valores negativos.
- **Evidencia:** Líneas 1917-1918: 'pSerial.TraceName := 'c:\\OGTrace.txt'; pSerial.Tracing := tlOn;'. Línea 1152: format('%4.4d', [round(rPrecio * GtwDivPrecio)]).
- **Impacto:** Sobrecarga de tracing y archivos en la raíz de C:; cambios de precio o presets rechazados por el equipo sin explicación.
- **Recomendación:** Hacer configurable el tracing (desactivado por defecto, ruta dentro de RutaLog). Validar que round(valor*div) quepa en el ancho BCD antes de transmitir y responder un error. Acotar GtwTimeout a 200..5000 y GtwTiempoCmnd a 0..500.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="GIL-46"></a>
#### GIL-46 · ⚪ Baja · mantenibilidad · deuda_tecnica — Código muerto, comentado y variables sin uso

- **Ubicación:** `UIGASGILBARCO.pas` líneas 607-642, 2801-2850, 2548-2560, 1264-1267, 437-449, 225-233, 56-67, 1172-1176, 2329-2336, 171-176
- **Se atiende en:** [E8.3](../PLAN_OPTIMIZACION.md#e83--código-muerto-variables-globales-y-duplicación-interna)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  Hay varios bloques que no se usan o no hacen nada:
  - La validación HASP está comentada y deja locales sin uso (haspObj y demás).
  - El paso 7 de cambio de precio nunca se activa y su rama N2 manda nivel 1.
  - SwEspera/HoraEspera son vestigios: SwEspera siempre vuelve a False en el finally.
  - Hay ramas idénticas en el sw2 de TransmiteComando (1264-1267).
  - CRC16 no se usa.
  - La rama 'swcargando and Estatus=1' de FINV es inalcanzable.
  - IniciaPrecios declara locales sin uso.
  - Globales y campos sin uso: TAdicf, Tagx, Licencia3Ok, PreciosInicio, ListaCmnd (se crea y nunca se libera), LinCmnd, CharCmnd, SwEsperaRsp, ContEsperaRsp, ContadorTotPos, ContadorTot, MaxEspera*, NivelPrecio*, SwPreset (solo se escribe), SwFinVenta, MontoPreset, ImportePreset, Isla, tipopago, confPos, licencia, GSentinelKey y DecimalesGilbarco.
  - TPosCarga y TabCmnd son variables globales de la unidad en lugar de campos del servicio.
- **Evidencia:** grep de usos: TAdicf aparece 2 veces (declaración e inicialización), Tagx 1, Licencia3Ok 1, ListaCmnd 2, TCambioPrecN1 nunca recibe True, CRC16 solo aparece en su definición.
- **Impacto:** Hace más difícil la auditoría y facilita portar bugs entre drivers.
- **Recomendación:** Eliminar el código muerto en un commit separado y sin cambios de comportamiento. Mover el estado a campos de la clase. Dejar HASP detrás de una directiva {$IFDEF HASP} en lugar de comentarlo.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

