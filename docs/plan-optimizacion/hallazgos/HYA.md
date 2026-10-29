# Hallazgos · HYA · Driver Hong Yang (Marca 5) · UIGASHONGYANG.pas

> Anexo del [plan de optimización](../PLAN_OPTIMIZACION.md). Código auditado: `IgasDispensarios@26ccfb4`, `IgasDispensariosBridge@99edafd`. Las líneas pueden haber cambiado: ubica las rutinas por su nombre.

## Cómo funciona este módulo

Togcvdispensarios_hongyang es el TService que PDISPENSARIOS.exe crea cuando [CONF] Marca=5. Habla con los CPUs Hong Yang por un TApdComPort en un bus multipunto: el byte de dirección se manda con paridad MARK y el resto con SPACE, y la paridad se cambia escribiendo directo el DCB (CambiaParidad/SetCommState). Las tramas son [dir][long][lado][cmd][BCD][BCC]. Comandos usados: A (estatus, importe y volumen), N (totales), V (leer precio), U (cambiar precio), S/L (preset en importe o litros), C/D (modo prepago o normal).

Cada manguera corresponde a un par dirección:lado de ConfPos ('1:1,2:1;1:2,2:2'). Las posiciones y mangueras se cargan desde el JSON de INITIALIZE en los arreglos globales TPosCarga[1..32] y TMangueras[1..100]. Los comandos de OpenGas pasan por TabCmnd[1..200] (folio interno) y se traducen a una cola TColaCmnd[1..50] de comandos seriales.

Timer1 (15 ms) es la máquina de estados A→N→V→Z→W. Da prioridad total a la cola, sondea las mangueras activas en cada ciclo y las inactivas cada 2 s. Cada 3er tick regenera rootJSON completo y lo envía al Bridge. Timer2 (200 ms) se encarga de conectar y mandar PING/JSON mientras no hay conexión o el servicio no está en marcha.

Los comandos del Bridge se procesan en ClientSocket1Read y su resultado viaja en Peticiones (máximo 2 elementos) en el siguiente envío.

Modelo de hilos, ya verificado: Timer1, Timer2 y el socket (que se activa solo en Timer2Timer) corren en el hilo principal. Async Pro casi seguro también, aunque con certeza media. Por eso no hay carreras reales en la operación normal, salvo en el arranque y el cierre. El costo es que cada Sleep o SaveToFile detiene serial y socket a la vez.

Los riesgos principales:

- Lógica de venta y preset: el chequeo de posición ocupada está anulado por la precedencia de 'not', los presets se confirman sin ACK y se rechazan si traen más de 2 decimales, HoraOcc queda obsoleta y los totales salen mal o truncados.

- Precios: se dan por aplicados antes de que el dispensario los confirme.

- Robustez serial: reinicio forzado del puerto por cualquier trama de longitud inesperada, reintentos ilimitados que dejan sin sondeo a las demás mangueras, una cola que descarta en silencio y un solo timeout que deja la posición 5 s sin sondeo.

- Índices fuera de rango con -$R-.

- BLOCK no bloquea físicamente.

- Una recursión en el guardado de logs que puede tumbar el servicio.

Además hay mucho código muerto (estados 7/8 inalcanzables, IniciarPrecios, Encrypt/Decrypt) y unas 25 rutinas copiadas de otros drivers.

### Ciclo serial

Timer1 es la única máquina de estados. En el .dfm tiene Interval=15 ms, que en Windows equivale a ~15.6 ms reales por la resolución del temporizador. Además se reinicia con Enabled false/true dentro de ComandoConsola y de cada OnTriggerAvail. Corre en el hilo principal, igual que el socket y Timer2.



Cada tick hace lo siguiente:

1. Si SwEsperaCmnd está activo, solo vigila tiempos. Tras 0.5 s sin bytes procesa como trama lo que haya en LineaProc, aunque esté incompleto (1983-1986). Tras 1 s sin respuesta pone estatus 0 a la manguera y Estatus=0 al JSON de la posición, fija ProxSondeo=+5 s y descarta el comando, sin reintento ni tolerancia (1987-1995).

2. Si no espera, primero revisa el reinicio programado cada 6 h (1881-1884). Con CmndProc='A' llama ProcesaComandosExternos, que recorre TabCmnd[1..200] y traduce OCC/OCL/AMP/DMP/TOTAL a la cola. Si hay cola, envía un comando y hace Exit (1886-1892): la cola tiene prioridad total y bloquea el sondeo mientras no se vacíe.

3. Recorre los estados encadenados con goto:

   - 'A' manda un comando A por tick a la siguiente manguera que toque: Now>=ProxSondeo (2 s con ModoPreset=Si, 1 s si no), estatus>1 o SwPreset con estatus>0. Las que no tocan se saltan en el mismo tick.

   - 'N' lee totales solo de mangueras con SwCargaTotales (al inicializar y por TOTAL).

   - 'V' lee el precio solo después de un 'U' exitoso.

   - 'Z' ejecuta PublicaEstatusDispensarios y ProcesaComandosExternos.

   - 'W' vacía la cola, un comando por tick, y vuelve a 'A'.



En el finally, cada 3er tick se genera y envía el JSON.



Envío (ComandoConsola): la trama es [dirección][longitud][lado][código][datos BCD LSB primero][BCC = 256 - suma mod 256]. El primer byte sale con paridad MARK y el resto con SPACE, cambiando el DCB directo con CambiaParidad/SetCommState. Entre los dos va EsperaTransmision: hasta 100×Sleep(1) mientras OutBuffUsed o cbOutQue no sean 0, más Sleep(22000 div Baud + 1). Esto bloquea el hilo principal ~2-35 ms por comando según la resolución del temporizador, y no deja registro si el buffer no se vacía.



Recepción (pSerialTriggerAvail): lee todos los bytes disponibles a LineaBuff, carácter por carácter, y arma LineaProc tomando el primer byte como longitud total. Al completarse llama ProcesaLineaRec:

- Si el BCC es inválido, reencola LinCmnd una vez. La bandera SwReintentoCmnd se rearma en cada tick, así que en la práctica los reintentos son ilimitados.

- Exige la longitud esperada por comando: A=12, C/D/U/S/L=3, V=7, N=21. Cualquier otra longitud dispara ReiniciarPuerto forzado: Detener, Sleep(200), Iniciar y tres SaveToFile, aunque haya ventas en curso.

- Los bytes sobrantes de LineaBuff y los parciales que llegan después del timeout no se limpian antes del siguiente comando, así que pueden desalinear las tramas siguientes.

- Si SwProcesando está activo sale sin leer; con todo serializado en un hilo esa condición prácticamente nunca ocurre.



Tiempos efectivos:

- Manguera activa: se sondea cada ~2-4 ticks, ≈35-70 ms más el tiempo en línea. A 9600 bps una consulta A son ~7 bytes de ida y 12 de vuelta, ≈20 ms.

- Inactivas: cada 2 s.

- Sin comunicación: cada 5 s.

- Con el ConfPos de ejemplo (4 mangueras): ~2 consultas/s en reposo y ~15-25 consultas/s durante una venta.



No se usa ProcessMessages. Las esperas activas son EsperaTransmision, el Sleep(200) de ReiniciarPuerto y el bucle de ~1 s de Timer2Timer al reconectar.

### Contrato con el Bridge, visto desde este módulo

- **Conexión:** TClientSocket ClientSocket1 en ctNonBlocking hacia [CONF] ServidorSocket de PDISPENSARIOS.ini (por omisión 127.0.0.1:1004; el ini versionado no lo define). Host y Port se asignan en ServiceExecute (277-278; el puerto usa StrToInt sin valor por omisión). El socket se activa SOLO en Timer2Timer (2033), así que su HWND y sus eventos quedan en el hilo principal. OnConnect pone conectado:=True (402-406). OnDisconnect pone conectado:=False, Timer1 off y Timer2 on (408-414). No hay manejador OnError. Este driver no usa TServerSocket ni habla directo con OpenGas.
- **Ciclo de envío:** Timer2 (200 ms, habilitado desde el .dfm) actúa mientras no hay conexión o estado<=0. Si no hay conexión hace Active:=True y espera hasta 101×Sleep(10). Luego manda 'PING' si respJson=False o TlkJSON.GenerateText(rootJSON) si es True. Con estado>0 y conexión, apaga Timer2 y enciende Timer1. Timer1, en su finally (2005-2021), genera el JSON completo cada tercer tick (xTurnoSocket=3, ≈50-100 ms reales). Lo envía si cambió, si socketResponse está asignado o si pasaron 0.5 s. Como socketResponse se asigna en cada lectura (390), incluida la respuesta NOTHING, en la práctica envía en cada 3er tick. Responder usa socketResponse si está asignado y si no ClientSocket1.Socket, y no revisa el valor de retorno de SendText. Timer1 no verifica conectado, a diferencia de Gilbarco/Wayne 2W.
- **PING vs JSON:** Solo se manda PING mientras respJson=False, es decir antes de que llegue el primer comando del Bridge. AddPeticionJSON pone respJson:=True (2833) y nunca vuelve a False (PAM/Wayne sí lo reinician). Timer1 siempre manda JSON. Al arrancar, el Bridge solo recibe PING, marca los datos como obsoletos (>5 s) y encola un TRACE automático, que aquí ejecuta GuardarLog y escribe los dos archivos de log.
- **Peticiones:** AddPeticionJSON(folio, resultado) agrega {Folio, Resultado} a rootJSON.Peticiones y conserva máximo 2: borra el índice 0. uLkJSON._Delete mueve el último elemento al hueco; con 2 elementos el orden se conserva. Todo comando agrega una entrada, incluido NOTHING (folio 0, 'True\|'). Detener(0)/Iniciar(0), llamados desde ReiniciarPuerto, también agregan entradas con folio 0. Así, un resultado sobrevive solo dos agregados más. Formato: 'True\|...\|' o 'False\|mensaje\|'. AUTHORIZE, SELFSERVICE, FULLSERVICE y PAYMENT devuelven 'True\|<folio TabCmnd>\|'. TOTALS devuelve 'True\|0\|0\|0\|0\|0\|0\|<folio>\|'. El resultado real se consulta con RESPCMND <folio> (ResultadoComando devuelve '*' si aún no hay respuesta, que llega como 'False\|*\|'). El Bridge descarta la respuesta de PRICES/AUTHORIZE/PAYMENT (CliSock=nil), así que el folio de TabCmnd nunca llega a OpenGas.
- **Reconexión:** Al desconectarse se apaga Timer1, así que deja de sondear dispensarios, y se enciende Timer2. Timer2Timer hace Active:=True y espera con Sleep(10)×101 a que conectado sea True. Ese bucle nunca termina antes de tiempo porque OnConnect se despacha en el mismo hilo: bloquea ~1-1.6 s y sale por Exit. La conexión se usa hasta el siguiente tick. Cada intento fallido, sin OnError, termina en ESocketError en el Visor de eventos. Cualquier byte serial que llegue tarde reactiva Timer1 en el finally de pSerialTriggerAvail. Si un envío falla, ScktComp desconecta y el except de Timer1 apaga Timer1 y enciende Timer2.
- **Comandos:**
  - NOTHING -> AddPeticionJSON(folio,'True\|') (expulsa resultados pendientes)
  - INITIALIZE -> Inicializar: LiberaInicializacion si ya estaba inicializado, IniciaPSerial (Consoles[0].Connection), AgregaPosCarga (Dispensers + ConfPos), LPrecios[ProductId] (Products); estado:=0
  - PARAMETERS -> 'True\|' sin efecto
  - LOGIN/LOGOUT -> MD5(usuario\|yyyy-mm-ddThh:nn); Token no se usa
  - PRICES -> IniciaPrecios: actualiza LPrecios y encola 'U' por manguera sin esperar confirmación
  - AUTHORIZE -> AutorizarVenta: 'OCL pos litros comb finv' si litros>0, si no 'OCC pos importe comb finv' en TabCmnd; ProcesaComandosExternos encola 'S'/'L'
  - SELFSERVICE / FULLSERVICE -> 'AMP'/'DMP' -> cola 'C'/'D' por manguera
  - PAYMENT -> 'FINV' -> responde OK sin efecto
  - TOTALS -> 'TOTAL pos' -> encola 'N' de la manguera activa y responde vía RESPCMND
  - HALT (Detener), RUN (Iniciar), SHUTDOWN (ServiceThread.Terminate), TERMINATE (Terminar)
  - TRACE -> GuardarLog; SAVELOGREQ -> GuardarLogPetRes
  - RESPCMND -> RespuestaComando(folio TabCmnd)
  - BLOCK / UNBLOCK -> SwDesHabilitado (solo rechaza presets)
  - LOG / LOGREQ -> últimas r+1 líneas del log dentro del resultado
  - STOP / START -> no implementados: 'False\|Comando desconocido\|'
- **Campos JSON:**
  - Estado (-1 no inicializado, 0 detenido, 1 en marcha)
  - PosCarga[].DispenserId
  - PosCarga[].HoraOcc ('yyyy-mm-ddThh:nn'; solo se actualiza en ProcesoComandoN)
  - PosCarga[].Manguera (HoseId de posactual2)
  - PosCarga[].Combustible (ProductId de posactual2)
  - PosCarga[].Estatus (externo: 0 sin com, 1 inactivo, 2 despachando, 9 autorizado; 3/5/8 inalcanzables)
  - PosCarga[].Importe / Volumen (display de la manguera posactual2)
  - PosCarga[].Precio (LPrecios[Combustible], no el de la venta)
  - PosCarga[].Hoses[].HoseId / ProductId / Total (litros; el Bridge no los usa)
  - Peticiones[].Folio / Resultado (máx. 2)
- **Desviaciones respecto a otros drivers:**
  - El filtro 'enviar JSON solo si cambió' (fd48cc2) no tiene efecto, porque socketResponse se asigna también con NOTHING
  - Timer1 no verifica conectado antes de Responder; Gilbarco/Wayne 2W sí
  - Cola propia TColaCmnd[50] con prioridad total sobre el sondeo, y reinicio de puerto propio (ReiniciarPuerto forzado por trama de longitud inesperada y periódico cada 6 h) que agrega Peticiones con folio 0
  - STOP/START no soportados (Bennett, Gilbarco, PAM, Team y Kairos sí)
  - AUTHORIZE sin producto (comb 0) no soportado ('Manguera no existe')
  - OCC/OCL no normalizan a 2 decimales (Wayne 2W sí, commit 60e5fde)
  - Nunca se reporta el estatus 3 (fin de carga): FinVenta nunca vale 1; PAYMENT no hace nada
  - HoraOcc solo cambia al leer totales (TOTALS), no al terminar la venta
  - TOTALS calcula el importe como litros × precio actual y solo refresca la manguera activa
  - Hoses[].Total se escribe por índice (xpos-1) y no por DispenserId
  - OperationMode del INITIALIZE se ignora (siempre 'Prepago') y BLOCK no envía comando físico
  - respJson nunca vuelve a False

### Bloques duplicados con otros módulos

| Rutina | Líneas | Nota |
|---|---|---|
| AgregaLog | 469-487 | Escapa los caracteres de control uno por uno y recorta a 10000 líneas con Delete(0). Idéntica (normalizada) en Bennett, Gilbarco, Kairos, PAM y Team; variante en Triton, Wayne y Wayne 2W. |
| AgregaLogPetRes | 416-434 | Mismo algoritmo sobre ListaLogPetRes. Idéntica en Bennett, Gilbarco, Kairos, PAM, Team, Triton y Wayne. |
| AddPeticionJSON | 2807-2840 | Peticiones con tope de 2 elementos y respJson:=True. Idéntica en Bennett, Gilbarco, PAM, Triton, Wayne y Wayne 2W. |
| ActualizaCampoJSON | 2758-2805 | Búsqueda lineal por DispenserId en PosCarga y GuardarLog en el except. Presente en los 8 drivers con Bridge, con diferencias menores. |
| SetEstadoJSON | 2842-2854 | Idéntica en PAM y Team; equivalente en el resto. |
| ApplyTotalLitrosToJSON | 2856-2891 | Ubica la posición por índice xpos-1 (bug compartido). Idéntica en Gilbarco, PAM, Triton y Wayne. |
| Responder | 450-467 | Usa socketResponse o ClientSocket1.Socket y no revisa el retorno de SendText. Presente en todos los drivers con pequeñas variantes. |
| Timer2Timer | 2025-2059 | Conexión con bucle Sleep(10)×101, PING o JSON y conmutación entre Timer1 y Timer2. Misma lógica que Gilbarco (solo cambia una variable local) y equivalente en el resto. |
| ClientSocket1Connect / ClientSocket1Disconnect | 402-414 | Idénticas en Gilbarco, PAM, Team, Triton y Wayne. |
| ClientSocket1Read | 316-400 | Mismo parser 'folio\|DISPENSERS\|CMD\|params' y despacho por GetEnumValue(TMetodos) en todos los drivers con Bridge. En Hong Yang faltan STOP y START. |
| Login / Logout / MD5 | 796-857 | Login y Logout idénticas en Bennett, PAM y Team. MD5 con TIdHashMessageDigest5 equivalente en los 9 drivers. |
| Encrypt / Decrypt | 2693-2727 | 3DES de LockBox con clave derivada de MD5. Copias en Bennett y PAM; sin uso en Hong Yang. |
| GuardarLog / GuardarLogPetRes | 2436-2450, 816-832 | Incluyen la recursión mutua ante falla. GuardarLog idéntica en Triton, Wayne y Wayne 2W; GuardarLogPetRes además en Gilbarco. |
| ObtenerLog / ObtenerLogPetRes | 2479-2529 | Con el off-by-one r+1. Idénticas en Gilbarco y equivalentes en el resto. |
| IniciaPSerial | 489-558 | Parseo de 'COM,COMn,baud,paridad,datos,stop'. Idéntica en Bennett, PAM, Team, Triton, Wayne y Wayne 2W. |
| Inicializar / LiberaInicializacion / AgregaPosCarga | 560-794 | Mismo esqueleto (Consoles, Dispensers, Products con LPrecios[productID] sin validar) en todos los drivers, adaptado a cada marca. LiberaInicializacion se agregó en todos con el commit 6b4f482. |
| EjecutaComando / ResultadoComando / RespuestaComando | 1143-1182, 2531-2548, 2452-2477 | TabCmnd[1..200] con el repeat que evalúa TabCmnd[201], presente en los 9 drivers. RespuestaComando idéntica en Bennett. |
| AutorizarVenta / FinVenta | 1184-1227, 1256-1269 | Arman 'OCC/OCL pos cantidad comb finv' y 'FINV'. Idénticas en Bennett, Gilbarco, PAM, Team, Wayne y Wayne 2W. |
| ActivaModoPrepago / DesactivaModoPrepago | 1229-1254 | Arman 'AMP/DMP pos' sin validar. El mismo patrón aparece en los demás drivers. |
| TotalesBomba | 2550-2571 | Respuesta 'True\|0\|0\|0\|0\|0\|0\|folio\|'. Idéntica en Bennett, PAM y Team; mismo formato en los 9 drivers. |
| Detener / Iniciar / Shutdown / Terminar | 2317-2434 | Detener idéntica en Team, Triton y Wayne. Shutdown idéntica en 7 drivers. Terminar idéntica en Gilbarco, PAM, Team y Wayne. Iniciar comparte en todos el bloque HASP comentado más CoInitialize. |
| Bloquear / Desbloquear | 2594-2670 | Mismo patrón 'si ModoOpera=Normal enviar AMP'; Desbloquear también envía AMP. Presente en varios drivers. |
| ValidaCifra | 2283-2315 | Presente en 7 drivers. Wayne 2W normaliza a 2 decimales antes de llamarla; Hong Yang no. |
| GuardaLogComandos | 2672-2691 | Copia en Bennett, PAM y Wayne 2W. |
| CRC16 / FechaHoraExtToStr | 436-448, 834-838 | CRC16 (sin uso aquí) idéntica en Bennett, PAM y Wayne. FechaHoraExtToStr idéntica en 6 drivers. |
| CalculaBCC / StrToHexSep / HexToBinario | 884-916, 1471-1502 | Utilidades de trama. CalculaBCC también existe en Bennett, PAM y Wayne; StrToHexSep y HexToBinario en Team. |
| ServiceExecute | 270-314 | Mismo esqueleto en todos: lee el ini, crea las listas y rootJSON y entra al bucle ProcessRequests. Comparte el TIniFile sin liberar y StrToInt sin default. |

## Hallazgos (37)

<a id="HYA-01"></a>
#### HYA-01 · 🟠 Alta · correccion · bug — La precedencia de 'not' anula el chequeo de posición ocupada en OCC/OCL

- **Ubicación:** `UIGASHONGYANG.pas` líneas 2136-2147, 2187-2198, 1356-1372
- **Módulos afectados:** UIGASHONGYANG.pas
- **Se atiende en:** [E1.3](../PLAN_OPTIMIZACION.md#e13--presets-montos-decimales-y-validaciones)
- **Verificación:** sin verificación independiente
- **Qué pasa:** En ProcesaComandosExternos (OCC y OCL), Delphi evalúa `(not TMangueras[i].estatus in [1,3])` como `(not estatus) in [1,3]`. Sobre un Integer, `not` es complemento bit a bit (not 1 = -2, not 5 = -6), que nunca pertenece a [1,3]. Por eso el rechazo 'Posicion de carga no esta disponible' jamás se ejecuta y solo se valida la manguera destino. Aunque se corrija, el rsp asignado antes del Break se sobrescribe después con ValidaCifra si xmang ya se había encontrado. Además, el driver publica una sola manguera por posición: posactual2 solo cambia si SwDisponible (1358-1361), e Importe/Volumen/Precio solo se escriben si poscomb=posactual2 (1368-1372). Una segunda venta simultánea en otra manguera de la misma posición (cada manguera es un CPU distinto según ConfPos) no llega a PosCarga.
- **Evidencia:** 2141 y 2192: `if (not TMangueras[i].estatus in [1,3]) then begin rsp:='Posicion de carga no esta disponible'; Break; end;` seguido de 2147-2151: `if (xmang in [1..MaxMangueras]) then begin if (TMangueras[xmang].estatus in [1,3]) then begin ... rsp:=ValidaCifra(xImporte,4,2);` y 2168 MeteACola('S'...). El bug es exclusivo de este driver (grep en los demás).
- **Impacto:** Se puede autorizar un preset en una posición que está despachando por otra manguera. Esa venta no se publica en TRANSACTION, o se mezcla con los datos de la otra manguera, y la transacción se pierde o se cobra mal.
- **Recomendación:** Cambiar 2141 y 2192 a `if not (TMangueras[i].estatus in [1,3]) then`. Después del ciclo, continuar solo si rsp='OK'. Validar con emulador: manguera 2 en estatus 5 y OCC a la manguera 1 debe responder 'Posicion de carga no esta disponible' sin encolar 'S'.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="HYA-02"></a>
#### HYA-02 · 🟠 Alta · protocolo · bug — AUTHORIZE se reporta exitoso aunque el preset se rechace o nunca llegue al dispensario

- **Ubicación:** `UIGASHONGYANG.pas` líneas 1222, 2131-2172, 2182-2224, 2268-2271, 1643-1685, 1987-1995
- **Módulos afectados:** UIGASHONGYANG.pas, UIGASBRIDGE.pas
- **Se atiende en:** [E5.2](../PLAN_OPTIMIZACION.md#e52--confirmación-real-de-prices-authorize-y-payment)
- **Verificación:** sin verificación independiente
- **Qué pasa:** OCC/OCL responden 'OK' (TabCmnd.SwResp/Respuesta) en cuanto el 'S'/'L' entra a la cola, sin esperar el ACK del CPU. ProcesoComandoS/L solo encienden SwPreset si no viene el bit de error y no informan el rechazo. El timeout de 1 s descarta el comando sin reintento y MeteACola descarta en silencio con la cola llena. Encima, el Bridge trata AUTHORIZE como fire-and-forget (CliSock=nil y respuesta inmediata 'DISPENSERS|AUTHORIZE|True|0|'): el folio de TabCmnd que devuelve AutorizarVenta nunca llega a OpenGas y RESPCMND no sirve. Los rechazos del driver ('Manguera no existe', 'Posicion Bloqueada', 'Manguera no esta disponible', decimales) solo quedan en el log.
- **Evidencia:** 1222: AddPeticionJSON(folio, 'True|'+IntToStr(EjecutaComando(cmd+...))+'|'); 2159-2169: if rsp='OK' then begin ... MeteACola('S'+...); SwSalir:=true; end; UIGASBRIDGE.pas 372-373: if metodoEnum in [PRICES_e, AUTHORIZE_e, PAYMENT_e] then p.CliSock:=nil.
- **Impacto:** El POS da por autorizada una venta que el dispensario no recibió o rechazó. El cliente espera, el despachador reintenta a mano y, en prepago, puede haber cobro adelantado sin despacho.
- **Recomendación:** Driver: guardar el folio de TabCmnd junto al elemento de cola y resolver la respuesta en ProcesoComandoS/L (OK o 'Rechazado por dispensario') o en el timeout ('Sin respuesta'). Bridge/OpenGas: esperar la respuesta de AUTHORIZE o exponer el folio del driver para que RESPCMND funcione. Probar con un emulador que conteste con bit de error y otro que no conteste.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** sí

<a id="HYA-03"></a>
#### HYA-03 · 🟠 Alta · correccion · bug — Presets con más de 2 decimales se rechazan en silencio (no se portó la corrección de Wayne 2W)

- **Ubicación:** `UIGASHONGYANG.pas` líneas 2149-2158, 2200-2209
- **Módulos afectados:** UIGASHONGYANG.pas
- **Se atiende en:** [E1.3](../PLAN_OPTIMIZACION.md#e13--presets-montos-decimales-y-validaciones)
- **Verificación:** sin verificación independiente
- **Qué pasa:** OCC y OCL validan con ValidaCifra(x,4,2), que responde 'Numero de decimales excede maximo permitido' si el valor no es exacto con 2 decimales. El commit 60e5fde corrigió esto en Wayne 2W porque OpenGas envía cantidades con 5 decimales (p.ej. litros calculados). Aquí el preset se descarta y, por el fire-and-forget del Bridge, OpenGas no se entera. Además, cualquier importe 0<x<1 se convierte en 9999 (venta 'lleno').
- **Evidencia:** 2150-2154: xImporte:=StrToFLoat(...); rsp:=ValidaCifra(xImporte,4,2); if rsp='OK' then if (xImporte<1) then xImporte:=9999; 2201-2205: igual para litros con mínimo 0.5. UIGASWAYNE2W.pas (60e5fde) trunca a 2 decimales antes de validar.
- **Impacto:** Ventas en litros (y algunas en importe) que no se pueden autorizar, sin aviso. Un preset de $0.50 autoriza un lleno.
- **Recomendación:** Normalizar a 2 decimales antes de ValidaCifra, como en Wayne 2W (Trunc(x*100+0.5)/100 o recorte de la cadena). Tratar 0 explícitamente como 'lleno' y rechazar 0<x<1. Probar con 'OCL 1 20.12345 1 0' y 'OCC 1 100.00000 1 0'.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="HYA-04"></a>
#### HYA-04 · 🟠 Alta · correccion · bug — HoraOcc de TRANSACTION queda con la hora de la última lectura de totales, no con la del fin de venta

- **Ubicación:** `UIGASHONGYANG.pas` líneas 732, 1570-1589, 1924-1940, 2236-2240, 705
- **Módulos afectados:** UIGASHONGYANG.pas
- **Se atiende en:** [E1.9](../PLAN_OPTIMIZACION.md#e19--coherencia-del-estado-publicado-estatus-fin-de-venta-horaocc-estado)
- **Verificación:** sin verificación independiente
- **Qué pasa:** HoraOcc solo se escribe al crear PosCarga (732) y en ProcesoComandoN cuando hay diferencia en el totalizador (1577-1578). ProcesoComandoN solo corre si SwCargaTotales=True. Eso ocurre al inicializar (705) y únicamente con un TOTAL, y solo para la manguera activa (2238); tras la primera lectura queda en False (1570). Al terminar una venta (5→1) HoraOcc no cambia. Si OpenGas pide TRANSACTION antes que TOTALS recibe la hora de la venta anterior o la de INITIALIZE. Ese mismo bloque es el único que reencola 'C' (prepago) tras la venta (1579-1580).
- **Evidencia:** Las únicas referencias a 'HoraOcc' son 732 y 1578. SwCargaTotales: 705 (True), 1570 (False), 2238 (True por TOTAL). Team, PAM, Gilbarco y Wayne 2W actualizan HoraOcc al procesar la venta (UIGASTEAM.pas 1760/2669, UIGASPAM.pas 1199, UIGASWAYNE2W.pas 2804).
- **Impacto:** Fecha y hora incorrectas en tickets, facturación y conciliaciones.
- **Recomendación:** En ProcesoComandoA, al pasar de 5 a 1 con swcargando, fijar HoraFV:=Now, actualizar HoraOcc y poner SwCargaTotales:=True para leer totales automáticamente. Probar en emulador: venta, espera y TRANSACTION; HoraOcc debe ser la hora del fin.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="HYA-05"></a>
#### HYA-05 · 🟠 Alta · correccion · bug — TOTALS devuelve importes calculados (litros × precio actual) y solo refresca la manguera activa

- **Ubicación:** `UIGASHONGYANG.pas` líneas 2232-2255, 1558-1570
- **Módulos afectados:** UIGASHONGYANG.pas
- **Se atiende en:** [E1.7](../PLAN_OPTIMIZACION.md#e17--totales-confiables)
- **Verificación:** sin verificación independiente
- **Qué pasa:** TOTAL marca SwCargaTotales y encola 'N' solo para PosManguera[PosActual2]. Las demás mangueras de la posición conservan el TotalLitros de su última lectura (2244-2247), que puede tener horas si se despachó por otra manguera. El importe total que se responde es FormatoMoneda(TotalLitros*LPrecios[...]), no el totalizador de importe que el dispensario manda en los bytes 15-20 de la respuesta N; ProcesoComandoN solo lee los bytes 9-14 (1562). En posiciones con menos de 3 mangueras Combustible[3]=0 y se lee LPrecios[0], fuera de rango. FormatFloat('0.000') depende del DecimalSeparator.
- **Evidencia:** 2238-2239: TMangueras[PosManguera[PosActual2]].SwCargaTotales:=True; MeteACola('N'+inttoclavenum(PosManguera[PosActual2],2)); 2248: rsp:='OK'+FormatFloat('0.000',ToTalLitros[1])+'|'+FormatoMoneda(ToTalLitros[1]*LPrecios[Combustible[1]])+...; 1562: totallitros:=ExtraeBCD(ss,9,14).
- **Impacto:** Totales de turno y controles volumétricos con importes inexactos después de cambios de precio, y litros desactualizados en las mangueras no activas.
- **Recomendación:** En TOTAL encolar 'N' para todas las mangueras de la posición y responder cuando todas tengan SwCargaTotales=False. Guardar por manguera el totalizador de importe con ExtraeBCD(ss,15,20) y devolver ese valor. Indexar LPrecios solo si Combustible está en 1..4. Formatear con TFormatSettings fijo.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="HYA-06"></a>
#### HYA-06 · 🟠 Alta · correccion · bug — La respuesta de TOTAL se trunca por RegCmnd.Respuesta string[80]

- **Ubicación:** `UIGASHONGYANG.pas` líneas 194-202, 2248-2250, 2270, 2462-2469
- **Módulos afectados:** UIGASHONGYANG.pas
- **Se atiende en:** [E1.5](../PLAN_OPTIMIZACION.md#e15--tabla-de-comandos-tabcmnd-y-respuestas-de-comandos-asíncronos)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Con 3 mangueras la respuesta de TOTAL es 'OK' más tres bloques (litros '0.000' + '|' + importe FormatoMoneda + '|'). Con totalizadores de millones de litros (p.ej. 5000000.000 L y 120,000,000.00 = ~27 caracteres por manguera) pasa de 80 caracteres. Al asignarla a un ShortString de 80 se corta en silencio y RESPCMND devuelve el último bloque recortado. Comando también es string[80].
- **Evidencia:** 201: Respuesta :string[80]; 2270: TabCmnd[xcmnd].Respuesta:=rsp; RespuestaComando 2466: resp:=copy(resp,3,Length(resp)-2)+'|'.
- **Impacto:** Totales con dígitos perdidos en la tercera manguera en estaciones con totalizadores altos.
- **Recomendación:** Cambiar Comando y Respuesta a string (AnsiString) o a string[255]. Agregar una prueba con totales de 9,999,999.999 L en 3 mangueras.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="HYA-07"></a>
#### HYA-07 · 🟠 Alta · robustez · bug — Una trama de longitud inesperada reinicia el puerto (forzado) aunque haya ventas en curso

- **Ubicación:** `UIGASHONGYANG.pas` líneas 1713-1746, 2729-2755, 2326-2332, 2382-2399
- **Módulos afectados:** UIGASHONGYANG.pas
- **Se atiende en:** [E2.8](../PLAN_OPTIMIZACION.md#e28--recepción-serial-robusta-tramas-bcc-acknak)
- **Verificación:** sin verificación independiente
- **Qué pasa:** ProcesaLineaRec llama ReiniciarPuerto con forzado=True (valor por omisión) ante cualquier longitud distinta de la esperada (A=12, C/D/U/S/L=3, V=7, N=21). Basta un byte de ruido, una respuesta tardía o una trama corta de error. ReiniciarPuerto(True) ignora PosicionesLibres y ejecuta Detener(0), Sleep(200) e Iniciar(0). Luego escribe tres archivos (LogDisp, LogDispPetRes y LogDispComandos) bloqueando el hilo principal. Detener(0) e Iniciar(0) agregan dos Peticiones con folio 0 que expulsan resultados pendientes. Además se cierra y reabre el TApdComPort desde su propio OnTriggerAvail (pSerialTriggerAvail→ProcesaLineaRec→ReiniciarPuerto), patrón que Async Pro desaconseja; según la versión podría diferir el cierre o provocar un AV (certeza baja).
- **Evidencia:** 1714-1717: 'A':if length(LineaRsp)=12 then ProcesoComandoA(LineaRsp) else ReiniciarPuerto; 2735-2748: Detener(0); Sleep(200); ... Iniciar(0); ... if forzado then begin GuardarLog(0); GuardarLogPetRes(0); GuardaLogComandos; end; 2332/2399: AddPeticionJSON(folio,'True|') con folio 0.
- **Impacto:** Un CPU que conteste tramas cortas provoca reinicios en cadena: sin sondeo durante ventas, escritura masiva de logs (riesgo de llenar el disco) y timeouts del Bridge por respuestas expulsadas.
- **Recomendación:** Ante longitud inesperada: registrar, descartar, limpiar LineaBuff/LineaProc y hacer pSerial.FlushInBuffer, y contar el error por manguera. Reiniciar solo tras N errores consecutivos, con PosicionesLibres y fuera del evento serial (bandera atendida en Timer1). En Detener/Iniciar no llamar AddPeticionJSON si folio=0. Probar inyectando respuestas de 3 bytes a un comando 'A'.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="HYA-08"></a>
#### HYA-08 · 🟠 Alta · robustez · bug — Los reintentos por BCC son ilimitados y, con la prioridad de la cola, un CPU con respuestas corruptas paraliza el sondeo

- **Ubicación:** `UIGASHONGYANG.pas` líneas 1700-1712, 1879-1893
- **Módulos afectados:** UIGASHONGYANG.pas
- **Se atiende en:** [E1.4](../PLAN_OPTIMIZACION.md#e14--sondeo-que-se-congela-livelocks-y-bloqueos-de-la-máquina-de-estados)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Ante un BCC inválido se reencola LinCmnd una sola vez, controlado por SwReintentoCmnd. Pero esa bandera se pone en False al inicio de cada tick sin espera (1880), así que el reintento se repite sin límite. La cola tiene prioridad absoluta: con CmndProc='A' y ApCola>0, cada tick manda un comando de la cola y hace Exit sin avanzar MangCiclo. Si una manguera responde siempre con BCC incorrecto (ruido, CPU dañado o dirección duplicada en ConfPos), el driver queda reintentando ese comando y deja de sondear todas las demás. El reintento además va al final de la cola.
- **Evidencia:** 1880: SwReintentoCmnd:=false; 1706-1710: if not SwReintentoCmnd then begin SwReintentoCmnd:=true; MeteACola(LinCmnd); end; 1888-1891: if ApCola>0 then begin SacaDeCola(xcmnd); ComandoConsola(xcmnd); Exit; end;
- **Impacto:** La estación entera queda sin actualizar estatus (OpenGas ve datos congelados u obsoletos) mientras dure la falla de un solo equipo.
- **Recomendación:** Llevar un contador de reintentos por comando (en el elemento de cola) y descartarlo tras 1-2 intentos, marcando la falla de la manguera. No rearmar SwReintentoCmnd en cada tick. Intercalar como máximo un comando de cola por cada sondeo 'A'. Probar con un emulador que devuelva BCC erróneo de forma permanente para una dirección.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="HYA-09"></a>
#### HYA-09 · 🟠 Alta · robustez · bug — La cola de 50 comandos descarta en silencio y AMP/DMP 0 encola MaxPosiciones × MaxMangueras comandos

- **Ubicación:** `UIGASHONGYANG.pas` líneas 1456-1469, 2077-2097, 2105-2125, 1886-1892
- **Módulos afectados:** UIGASHONGYANG.pas
- **Se atiende en:** [E8.3](../PLAN_OPTIMIZACION.md#e83--código-muerto-variables-globales-y-duplicación-interna)
- **Verificación:** sin verificación independiente
- **Qué pasa:** MeteACola descarta sin log cuando ApCola>=50. En AMP/DMP con posición 0, el filtro por posición está comentado dentro de un ciclo por posición, así que cada manguera recibe MaxPosiciones comandos 'C'/'D' (p.ej. 8 posiciones × 16 mangueras = 128). La cola se llena y los 'S'/'L' (presets) o 'U' (precios) que llegan después se pierden, mientras TabCmnd ya respondió 'OK'. Mientras haya cola tampoco se sondean estatus (~50 ms por comando).
- **Evidencia:** 1459-1462: if ApCola<50 then begin inc(ApCola); TColaCmnd[ApCola]:=xstr; end; 2079-2086: for xpos:=1 to MaxPosiciones do begin for i:=1 to MaxMangueras do begin //if (TMangueras[i].PosCarga=xpos) then begin MeteACola('C'+inttoclavenum(i,2)); (igual en DMP 2107-2114).
- **Impacto:** Presets y cambios de precio perdidos sin aviso, y varios segundos sin sondeo después de un SELFSERVICE/FULLSERVICE global.
- **Recomendación:** Con xpos=0, recorrer solo las mangueras (un 'C'/'D' por manguera). Hacer que MeteACola registre y devuelva False cuando la cola está llena, y propagar ese error a la respuesta del comando. Evitar duplicados (mismo comando y manguera) y considerar una cola dinámica.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="HYA-10"></a>
#### HYA-10 · 🟠 Alta · robustez · bug — Un solo timeout marca la posición sin comunicación y la deja 5 s sin sondeo, aun en plena venta

- **Ubicación:** `UIGASHONGYANG.pas` líneas 1987-1996, 1900
- **Módulos afectados:** UIGASHONGYANG.pas
- **Se atiende en:** [E1.4](../PLAN_OPTIMIZACION.md#e14--sondeo-que-se-congela-livelocks-y-bloqueos-de-la-máquina-de-estados)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Si la respuesta no llega en 1 s, Timer1 pone estatus:=0 a la manguera, escribe Estatus=0 en el JSON de la posición y fija ProxSondeo:=Now+5 s. La condición de sondeo pide Now>=ProxSondeo o Estatus>1, y el estatus ya es 0, así que una manguera que estaba despachando deja de leerse 5 s. No hay tolerancia (Wayne 2W y Gilbarco esperan 3 fallas, commits 7160ea2 y 34a7278) ni reintento del comando: si era 'S', 'L' o 'U' se pierde. Si la manguera que falló no es posactual2, el siguiente PublicaEstatusDispensarios reescribe el estatus de la otra manguera y la posición parpadea entre 0 y 1.
- **Evidencia:** 1987-1995: else if ((Now-TimeCmnd)>TmSegundo) then begin SwEsperaCmnd:=false; with TMangueras[MangCmnd] do begin estatus:=0; descestat:='Sin Comunicacion'; ProxSondeo:=Now+5*TmSegundo; ActualizaCampoJSON(PosCarga, 'Estatus', 0); end; end;
- **Impacto:** OpenGas ve 'sin comunicación' a mitad de una venta por un solo paquete perdido (ruido RS-485), con datos congelados 5 s; el POS podría cancelar o cerrar mal la transacción.
- **Recomendación:** Usar un contador de fallas por manguera y reportar 0 solo tras N fallas consecutivas (configurable). Reintentar una vez el comando fallido. Mantener el sondeo continuo si el estatus previo era >1. Publicar el estatus mediante PublicaEstatusDispensarios.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="HYA-11"></a>
#### HYA-11 · 🟠 Alta · correccion · bug — El precio publicado puede no coincidir con el del dispensario (el cambio se asume antes de confirmarse)

- **Ubicación:** `UIGASHONGYANG.pas` líneas 918-940, 1290, 1599-1641, 1942-1958, 603, 687, 2573-2592
- **Módulos afectados:** UIGASHONGYANG.pas
- **Se atiende en:** [E1.6](../PLAN_OPTIMIZACION.md#e16--precios-aplicar-solo-lo-confirmado)
- **Verificación:** sin verificación independiente
- **Qué pasa:** IniciaPrecios escribe LPrecios[Combustible] y el precio de la manguera en cuanto llega PRICES, y encola 'U' sin mirar el estatus, es decir también a mangueras que despachan. Si el 'U' falla (bit de error, timeout o cola llena) no hay reintento: ActualizarPrecio se asigna pero nunca se usa para reenviar. LPrecios queda con el precio nuevo, que ProcesoComandoA publica en cada sondeo, mientras el dispensario sigue cobrando el anterior. El precio físico (V) solo se lee después de un 'U' exitoso. Los precios de INITIALIZE se guardan pero nunca se envían ni se verifican, porque IniciarPrecios no se llama. El precio de una venta en curso cambia en el JSON al llegar PRICES. Un precio >=100.00 no cabe en IntToClaveNum(ii,4) / copy(LinCmnd,4,4) y se envía recortado, sin validación.
- **Evidencia:** 929-932: LPrecios[Combustible]:=precioComb; ... precio:=precioComb; MeteACola('U'+IntToClaveNum(i,2)+inttoclavenum(ii,4)); 1290: precio:=LPrecios[Combustible]; 1608-1611: if not SwErr then begin ActualizarPrecio:=false; LeerPrecio:=true; end; 687: LeerPrecio:=false al inicializar.
- **Impacto:** TRANSACTION con un Precio distinto al que usó el dispensario (Importe y Volumen no cuadran), inconsistencias fiscales y precios no aplicados sin aviso (PRICES es fire-and-forget en el Bridge).
- **Recomendación:** Guardar el precio pendiente por manguera y actualizar LPrecios solo cuando V lo confirme. Enviar 'U' solo a mangueras en estatus 1 y reintentar usando ActualizarPrecio como bandera de una fase del ciclo. En Iniciar poner LeerPrecio:=True en todas las mangueras para leer el precio físico. Congelar el precio de la venta al pasar a 5. Validar 0<precio<=99.99.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="HYA-12"></a>
#### HYA-12 · 🟠 Alta · robustez · bug — Índices fuera de rango sin validar en INITIALIZE y en el ciclo (con -$R- corrompen variables globales)

- **Ubicación:** `UIGASHONGYANG.pas` líneas 222-231, 597-604, 663-672, 725-787, 1564-1569, 1819-1821, 1898-1901, 2867-2875
- **Módulos afectados:** UIGASHONGYANG.pas, PDISPENSARIOS.cfg
- **Se atiende en:** [E1.8](../PLAN_OPTIMIZACION.md#e18--índices-fuera-de-rango-y-carga-de-posiciones-r-)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  PDISPENSARIOS.cfg compila con -$R- y -$Q-, así que estos accesos escriben memoria vecina en silencio:
  (1) LPrecios es array[1..4] y se indexa con ProductId en 603, 929 y 1632. Un ProductId fuera de 1..4 probablemente sobrescribe PreciosInicio, MaxMangueras y Token, declarados justo después.
  (2) Un DispenserId fuera de 1..32 indexa TPosCarga directamente (726-762).
  (3) Una posición con más de 3 mangueras escribe Combustible[xpcomb] y PosMangueraDisp[xpcomb] (762, 780) fuera del guard de 756, y TotalLitros[4] en 1566.
  (4) Con IDs no contiguos, PublicaEstatusDispensarios usa PosManguera[PosActual2]=0, es decir TMangueras[0] (1820). ApplyTotalLitrosToJSON localiza la posición por índice xpos-1 y no por DispenserId (2871), así que publica totales en otra posición.
  (5) MangCiclo es una variable global sin inicializar y solo LiberaInicializacion la pone en 1. En el primer RUN el estado 'A' lee TMangueras[0] y escribe su ProxSondeo (1898-1901).
  (6) TPosCarga.Combustible, TotalLitros y PosMangueraDisp no se limpian al reinicializar.
  Por último, un ConfPos incompleto produce un EConvertError genérico (753-754).
- **Evidencia:** 603: LPrecios[productID]:=productos.Child[i].Field['Price'].Value; 225-228: LPrecios :array[1..4] of Double; PreciosInicio:Boolean; MaxMangueras:integer; Token:string; 2871: posIndex0 := xpos - 1; 1820: xmang:=PosManguera[PosActual2]; PDISPENSARIOS.cfg: -$R- -$Q-.
- **Impacto:** Con catálogos de producto o numeración de posiciones distintos de 1..n contiguos: MaxMangueras o Token corruptos (sondeo erróneo, AV al liberar el string) y estatus o totales publicados en la posición equivocada.
- **Recomendación:** Validar en Inicializar: ProductId en 1..4, DispenserId en 1..32, máximo 3 mangueras por posición, total <=99 y que ConfPos tenga entrada para cada manguera (con mensaje explícito). Inicializar MangCiclo:=1 en Iniciar. Buscar por DispenserId en ApplyTotalLitrosToJSON. Saltar las posiciones sin mangueras en PublicaEstatusDispensarios. Compilar una versión de pruebas con {$R+}{$Q+}.
- **Esfuerzo:** M · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="HYA-13"></a>
#### HYA-13 · 🟠 Alta · seguridad · bug — BLOCK/UNBLOCK no bloquean físicamente y el modo de operación se fuerza a 'Prepago'

- **Ubicación:** `UIGASHONGYANG.pas` líneas 743-746, 772-776, 2084, 2094, 2112, 2122, 2606-2628, 2649-2663
- **Módulos afectados:** UIGASHONGYANG.pas
- **Se atiende en:** [E5.4](../PLAN_OPTIMIZACION.md#e54--comandos-homogéneos-entre-marcas)
- **Verificación:** sin verificación independiente
- **Qué pasa:** AgregaPosCarga asigna ModoOpera:='Prepago' en las dos ramas del if de OperationMode. DMP también deja ModoOpera:='Prepago' (2112, 2122), aunque envía 'D' (modo normal, desenllavado) y pone SwPrepagoM:=False. Bloquear y Desbloquear solo envían 'AMP' si TPosCarga[xpos].ModoOpera='Normal', y eso nunca ocurre; además Desbloquear envía AMP en vez de DMP (error de copia). En la práctica BLOCK solo hace que el driver rechace presets (SwDesHabilitado). Si la posición está en modo normal tras un FULLSERVICE, se puede seguir despachando libremente. Al iniciar tampoco se envía 'C', así que el modo físico del CPU puede no coincidir con SwPrepagoM=True.
- **Evidencia:** 743-746: if UpperCase(...)='FULLSERVICE' then TPosCarga[xpos].ModoOpera:='Prepago' else TPosCarga[xpos].ModoOpera:='Prepago'; 2611-2612: if TPosCarga[xpos].ModoOpera='Normal' then EjecutaComando('AMP '+IntToClaveNum(xpos,2)); 2653-2654: igual en Desbloquear.
- **Impacto:** OpenGas cree bloqueada una posición que sigue despachando en modo normal (riesgo operativo y de fraude), y el OperationMode configurado se ignora.
- **Recomendación:** Mantener el modo real por posición en TPosCarga.ModoOpera, actualizado por AMP/DMP. En BLOCK enviar 'C' (sin preset no despacha) y guardar el modo previo para restaurarlo en UNBLOCK. Respetar OperationMode y, en RUN, enviar 'C'/'D' según la configuración.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="HYA-14"></a>
#### HYA-14 · 🟠 Alta · robustez · bug — Recursión infinita entre GuardarLog y GuardarLogPetRes si solo falla el guardado de peticiones

- **Ubicación:** `UIGASHONGYANG.pas` líneas 816-832, 2436-2450
- **Módulos afectados:** UIGASHONGYANG.pas
- **Se atiende en:** [E2.4](../PLAN_OPTIMIZACION.md#e24--bitácoras-que-no-bloquean-append-incremental-rotación-y-sin-json-repetido)
- **Verificación:** sin verificación independiente
- **Qué pasa:** GuardarLog guarda ListaLog y luego llama GuardarLogPetRes(0) (2443). Si ListaLogPetRes.SaveToFile falla, su except llama GuardarLog(0) (827). GuardarLog vuelve a guardar ListaLog con éxito, vuelve a llamar GuardarLogPetRes, y así hasta EStackOverflow. Es plausible con el disco casi lleno: LogDispPetRes guarda el JSON completo de cada intercambio y es el archivo más grande. También con un archivo bloqueado.
- **Evidencia:** 825-830: on e:Exception do begin AgregaLog('False|Excepcion: '+e.Message+'|'); GuardarLog(0); ...; 2442-2443: ListaLog.SaveToFile(...); GuardarLogPetRes(0);
- **Impacto:** Caída del servicio por desbordamiento de pila, con cientos de reescrituras del log en segundos.
- **Recomendación:** En el except de GuardarLogPetRes solo registrar en ListaLog, sin llamar GuardarLog. Proteger ambos procedimientos con una bandera de reentrada. Revisar el espacio libre antes de guardar.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="HYA-15"></a>
#### HYA-15 · 🟡 Media · protocolo · riesgo — El enlace Bridge-driver no delimita mensajes y Peticiones se limita a 2 (las entradas de folio 0 expulsan resultados)

- **Ubicación:** `UIGASHONGYANG.pas` líneas 324-337, 342-343, 2807-2840
- **Módulos afectados:** UIGASHONGYANG.pas, UIGASBRIDGE.pas
- **Se atiende en:** [E6.1](../PLAN_OPTIMIZACION.md#e61--framing-y-buffer-por-conexión-en-los-dos-sentidos-y-del-lado-de-opengas)
- **Verificación:** sin verificación independiente
- **Qué pasa:** ClientSocket1Read trata todo Socket.ReceiveText como un solo mensaje 'folio|DISPENSERS|CMD|params'. Si llegan dos respuestas pegadas, los parámetros del primero absorben al segundo (p.ej. '...|24.10' + '12|DISPENSERS|NOTHING' da el precio '24.1012') y el segundo comando se pierde; un mensaje parcial se malinterpreta. En sentido contrario, el Bridge parsea con TlkJSON.ParseText, que se queda con el primer objeto e ignora el resto (uLkJSON 2030) o devuelve nil si el JSON viene truncado. AddPeticionJSON conserva solo 2 elementos y NOTHING agrega {0,'True|'}, igual que Detener(0)/Iniciar(0). Un resultado que no viaje en los dos envíos siguientes se pierde y OpenGas recibe 'Timeout excedido' a los 2 s.
- **Evidencia:** 343: NOTHING_e: AddPeticionJSON(folio, 'True|'); 2825-2826: while petArr.Count >= 2 do petArr.Delete(0); UIGASBRIDGE.pas 760-767: responde a cada mensaje con la siguiente petición o con '0|DISPENSERS|NOTHING'.
- **Impacto:** Pérdida intermitente de respuestas (INITIALIZE, RUN, TOTALS, RESPCMND) cuando un lado se bloquea (SaveToFile, ReiniciarPuerto) y se acumulan mensajes.
- **Recomendación:** Acordar un delimitador (#3, CRLF o prefijo de longitud) y un buffer de acumulación en ambos lados. No generar resultado para NOTHING ni para folio 0. Conservar cada resultado hasta que el Bridge confirme su folio, en lugar de un tope fijo de 2.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** sí

<a id="HYA-16"></a>
#### HYA-16 · 🟡 Media · rendimiento · optimizacion — El filtro 'publicar JSON solo al cambiar' no tiene efecto y el JSON se regenera completo cada 3 ticks

- **Ubicación:** `UIGASHONGYANG.pas` líneas 390, 2005-2021, 450-467
- **Módulos afectados:** UIGASHONGYANG.pas
- **Se atiende en:** [E4.1](../PLAN_OPTIMIZACION.md#e41--responder-al-bridge-en-cuanto-se-procesa-un-comando-y-homologar-la-cadencia)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Timer1 llama TlkJSON.GenerateText(rootJSON) cada tercer tick (≈50-100 ms) y envía si el JSON cambió, si socketResponse está asignado o si pasaron 0.5 s. Pero socketResponse se asigna en cada lectura del socket, incluida la respuesta NOTHING que el Bridge manda a cada envío, así que la condición casi siempre es verdadera y el tráfico es el mismo que antes de fd48cc2. Cada envío y cada respuesta se copian carácter por carácter al log (Responder 460, ClientSocket1Read 326). A diferencia de Gilbarco y Wayne 2W, no se verifica conectado: con el socket caído SendText no envía nada, pero igual se registra 'E ...'.
- **Evidencia:** 390: socketResponse:=Socket; 2009: if (xjson<>UltimoJSON)or(Assigned(socketResponse))or((Now-HoraUltimoJSON)>=TmSegundo*0.5) then; UIGASWAYNE2W.pas 2959: if (conectado) and (xTurnoSocket=3) then.
- **Impacto:** Unos 10-20 JSON por segundo con su log, consumiendo CPU del hilo principal (el mismo que atiende el serial), y un log de peticiones que solo guarda 4-8 minutos.
- **Recomendación:** Asignar socketResponse solo cuando el comando no sea NOTHING. Mantener el envío de 0.5 s como latido. Generar el JSON solo cuando una bandera 'sucio' (puesta en ActualizaCampoJSON/AddPeticionJSON/SetEstadoJSON) lo indique. Agregar 'if conectado'. Medir líneas por minuto en LogDispPetRes antes y después, y confirmar que el Bridge no marque datos obsoletos.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="HYA-17"></a>
#### HYA-17 · 🟡 Media · robustez · bug — Parámetros de comandos sin validar y comandos pendientes que nunca expiran

- **Ubicación:** `UIGASHONGYANG.pas` líneas 1143-1182, 2070-2101, 2133-2136, 2232-2255, 2550-2566, 2594-2670, 1229-1254
- **Módulos afectados:** UIGASHONGYANG.pas
- **Se atiende en:** [E1.5](../PLAN_OPTIMIZACION.md#e15--tabla-de-comandos-tabcmnd-y-respuestas-de-comandos-asíncronos), [E8.3](../PLAN_OPTIMIZACION.md#e83--código-muerto-variables-globales-y-duplicación-interna)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  Problemas de validación:
  - TotalesBomba solo exige xpos>=1. Con xpos>32 o una posición sin mangueras, TOTAL usa TPosCarga[xpos] y TMangueras[PosManguera[PosActual2]] fuera de rango. TPosCarga[33] probablemente cae sobre TMangueras, así que escribe SwCargaTotales y TotalLitros en memoria de otra manguera.
  - OCC/OCL usan TPosCarga[xpos] sin validar.
  - AMP/DMP con un parámetro inválido (-1) no se aplican (SwAplicaCmnd:=false) y nunca se responden.
  - Bloquear/Desbloquear con MaxPosiciones<xpos<=32 no responden nada, y Bloquear indexa LinEstadoGen[xpos], que puede estar vacío.
  Problemas de expiración en TabCmnd:
  - Una entrada solo se libera cuando EjecutaComando pasa por ella, y ese recorrido se detiene en el primer hueco libre. Un comando no respondido puede quedar activo para siempre, y se reprocesa y registra en cada llamada a ProcesaComandosExternos (2 o más por tick). Si además lanza excepción, aborta el tick antes del sondeo.
  - El repeat evalúa TabCmnd[201] antes de comprobar ind>200.
- **Evidencia:** 2234-2238: xpos:=StrToIntDef(...,0); with TPosCarga[xpos] do begin if TabCmnd[xcmnd].SwNuevo then begin TMangueras[PosManguera[PosActual2]].SwCargaTotales:=True; 1156: until (not TabCmnd[ind].SwActivo)or(ind>200); 2100: else SwAplicaCmnd:=false; 2619-2628: sin rama else.
- **Impacto:** Un TOTALS mal formado corrompe datos de mangueras; hay comandos sin respuesta (timeouts del Bridge), el log crece sin control y, en el peor caso, el sondeo queda detenido.
- **Recomendación:** Validar 1<=xpos<=MaxPosiciones (y que la posición tenga mangueras) en TotalesBomba, AutorizarVenta, Activa/DesactivaModoPrepago, Bloquear y Desbloquear, respondiendo 'False|Posicion no existe|'. En ProcesaComandosExternos responder con error y liberar todo comando con más de N segundos. Reescribir el repeat con chequeo previo de índice. Responder siempre en Bloquear/Desbloquear.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="HYA-18"></a>
#### HYA-18 · 🟡 Media · protocolo · bug — Los buffers de recepción no se limpian entre comandos: una respuesta tardía o un byte de ruido desalinea las tramas siguientes

- **Ubicación:** `UIGASHONGYANG.pas` líneas 1759-1796, 1983-1986, 1022-1098
- **Módulos afectados:** UIGASHONGYANG.pas
- **Se atiende en:** [E2.8](../PLAN_OPTIMIZACION.md#e28--recepción-serial-robusta-tramas-bcc-acknak)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El enmarcado toma el primer byte como longitud total. LineaBuff conserva los bytes que sobran después de una trama completa. ComandoConsola no limpia LineaBuff ni LineaProc, ni vacía el buffer de Async Pro antes de enviar. En el timeout de 1 s no se limpian los parciales que llegaron después de 0.5 s, y en el caso de 0.5 s se procesa como trama una línea incompleta. Un primer byte 0 o grande (0xFF) acumula bytes hasta que haya 0.5 s de silencio y absorbe respuestas válidas. El resultado típico es un BCC inválido (reintento) o una longitud inesperada (ReiniciarPuerto forzado). Además pSerialTriggerAvail sale sin leer si SwProcesando está activo (1766).
- **Evidencia:** 1774-1781: while (not FinLinea)and(Length(LineaBuff)>0) do begin c:=LineaBuff[1]; delete(LineaBuff,1,1); LineaProc:=LineaProc+C; xlong:=ord(LineaProc[1]); if length(LineaProc)=xlong then FinLinea:=true; end; ComandoConsola (1027-1098) no toca LineaBuff ni LineaProc.
- **Impacto:** Un solo evento de ruido desencadena errores de comunicación y reinicios de puerto en cascada.
- **Recomendación:** Antes de cada envío: LineaBuff:='', LineaProc:='', FinLinea:=False y pSerial.FlushInBuffer. Descartar un primer byte que no sea una longitud válida para el comando en curso (3, 7, 12 o 21). Limpiar todo en el timeout.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="HYA-19"></a>
#### HYA-19 · 🟡 Media · robustez · bug — Respuestas con bit de error o con dígitos no BCD se descartan sin registro y congelan el estatus

- **Ubicación:** `UIGASHONGYANG.pas` líneas 1276-1284, 1435-1454, 1388-1433
- **Módulos afectados:** UIGASHONGYANG.pas
- **Se atiende en:** [E1.9](../PLAN_OPTIMIZACION.md#e19--coherencia-del-estado-publicado-estatus-fin-de-venta-horaocc-estado)
- **Verificación:** sin verificación independiente
- **Qué pasa:** ProcesoComandoA sale sin actualizar nada si DameEstatus detecta el bit de error (bit 5): no registra nada ni cambia el estatus. Si el CPU reporta error de forma persistente durante una venta, la posición queda 'despachando' con los últimos importes indefinidamente. ExtraeBCD une los bytes en hexadecimal y los convierte con StrToInt. Un nibble A-F (pantalla en blanco o reset) lanza una excepción que se relanza hasta el Visor de eventos. Un totalizador mayor a 21,474,836.47 L (12 dígitos en ExtraeBCD(ss,9,14)) desborda Integer y ProcesoComandoN falla siempre, así que TOTAL nunca se responde.
- **Evidencia:** 1280-1282: ee:=DameEstatus(ss,SwEnllavado,SwErrorCmnd); if SwErrorCmnd then exit; 1447: result:=strtoint(ss)/100;
- **Impacto:** Estados congelados sin diagnóstico y totales imposibles de leer en equipos con mucho volumen acumulado.
- **Recomendación:** Registrar el error y publicarlo (p.ej. estatus 0 tras N repeticiones). En ExtraeBCD validar cada nibble y acumular en Int64, devolviendo un error controlado en vez de una excepción.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="HYA-20"></a>
#### HYA-20 · 🟡 Media · correccion · riesgo — El importe de 3 bytes BCD (máx. 9,999.99) no tiene corrección de desbordamiento

- **Ubicación:** `UIGASHONGYANG.pas` líneas 1288-1289, 2200-2205
- **Módulos afectados:** UIGASHONGYANG.pas
- **Se atiende en:** [E1.2](../PLAN_OPTIMIZACION.md#e12--importes-y-volúmenes-de-venta-mal-calculados)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El importe de la venta se lee de 3 bytes BCD (ExtraeBCD(ss,3,5)) y el volumen de otros 3 (9-11). OCL acepta presets de hasta 9,999.99 L, lo que con precios actuales supera 9,999.99 pesos (p.ej. 450 L de diésel). Wayne 2W corrigió el mismo caso (commit ea8feb7) recalculando con el volumen; Hong Yang publica el importe tal cual. No está verificado si el CPU Hong Yang limita la venta a 6 dígitos ni qué contienen los bytes 6-8 de la respuesta A.
- **Evidencia:** 1288: importe:=ExtraeBCD(ss,3,5); 1289: volumen:=ExtraeBCD(ss,9,11); 2202: rsp:=ValidaCifra(xLitros,4,2) sin tope por importe estimado.
- **Impacto:** Posible cobro incorrecto en ventas grandes (camiones de carga).
- **Recomendación:** Comparar el importe con volumen*precio y corregir como en Wayne 2W si la diferencia supera una tolerancia. Limitar OCL a litros*precio<=9999.99. Confirmar con el fabricante el formato completo de la respuesta A.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="HYA-21"></a>
#### HYA-21 · 🟡 Media · correccion · bug — La venta anterior se pierde si el display reinicia sin pasar por inactivo, y el fin de venta nunca se reporta

- **Ubicación:** `UIGASHONGYANG.pas` líneas 1294-1323, 1581-1582, 1819-1832, 2160, 2211, 2256-2266
- **Módulos afectados:** UIGASHONGYANG.pas, UIGASBRIDGE.pas
- **Se atiende en:** [E1.9](../PLAN_OPTIMIZACION.md#e19--coherencia-del-estado-publicado-estatus-fin-de-venta-horaocc-estado)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Si el estatus sigue en 5 y el importe baja más de 0.5 (nueva venta sin ver el estado 1), el código intercambia importe, volumen y precio con los anteriores, pone swdesp:=true (bandera que nadie lee) y los restaura de inmediato. No guarda la venta previa en ningún lado, y como el driver solo publica la última lectura por posición, esa venta se sobrescribe. Los estados 7/8 ('Fin de venta', externo 3) son inalcanzables porque FinVenta nunca vale 1 (las asignaciones están comentadas en 2160 y 2211). La posición pasa de 2 a 1 directamente: si otro cliente usa otra manguera (posactual2 cambia) antes de que OpenGas lea TRANSACTION, la venta se reemplaza. El estatus 2 de una manguera que no es posactual2 no se publica (1820).
- **Evidencia:** 1296-1305: ximp:=importe; importe:=importeant; ... try swdesp:=true; finally importe:=ximp; volumen:=xvol; precio:=xpre; end; 1307: if (estatus=1)and(finventa=1)and(swfinventa) then (finventa siempre 0).
- **Impacto:** Transacciones que OpenGas no captura cuando hay despachos consecutivos rápidos o el sondeo se atrasa.
- **Recomendación:** Guardar por posición la última venta cerrada (importe, volumen, precio, manguera, hora y un consecutivo), separada de la lectura en curso, y publicarla. Reportar el estatus 3 hasta PAYMENT, implementando FINV. En el caso 'CAMBIO', cerrar la venta anterior con importeant/volumenant.
- **Esfuerzo:** M · **Riesgo del cambio:** alto · **Toca contrato:** sí

<a id="HYA-22"></a>
#### HYA-22 · 🟡 Media · robustez · riesgo — INITIALIZE con el servicio en marcha reinicia todo sin revisar ventas en curso

- **Ubicación:** `UIGASHONGYANG.pas` líneas 568-572, 614-641, 656-659, 673-738
- **Módulos afectados:** UIGASHONGYANG.pas
- **Se atiende en:** [E2.7](../PLAN_OPTIMIZACION.md#e27--initialize-idempotente-y-seguro-con-ventas-en-curso)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Desde el commit 6b4f482, Inicializar llama LiberaInicializacion si estado>-1. Eso cierra el puerto, limpia TabCmnd y la cola, y pone detenido:=True, con lo que el chequeo de AgregaPosCarga ('Es necesario detener el proceso') deja de proteger. AgregaPosCarga pone en cero importe, volumen y estatus de todas las mangueras y recrea PosCarga con valores en 0. Una venta en curso, o terminada y no leída, desaparece del JSON, y los presets pendientes se descartan sin respuesta.
- **Evidencia:** 569-572: if estado>-1 then begin AgregaLog('INITIALIZE con servicio inicializado ...'); LiberaInicializacion; end; 688-692: importe:=0; ... volumen:=0; 736-737: posObj.Add('Importe', 0); posObj.Add('Volumen', 0);
- **Impacto:** Si OpenGas reenvía INITIALIZE durante un despacho (p.ej. al reiniciarse), la transacción en curso se pierde.
- **Recomendación:** Rechazar o diferir el INITIALIZE mientras haya mangueras con estatus>1 o ventas sin leer, o conservar los datos de las posiciones cuya configuración no cambió.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="HYA-23"></a>
#### HYA-23 · 🟡 Media · concurrencia · riesgo — Modelo de hilos: todo se serializa en el hilo principal; las carreras reales están en el arranque y el cierre

- **Ubicación:** `UIGASHONGYANG.pas` líneas 270-314, 1766, 2033, 2409-2417; UIGASHONGYANG.dfm 33-38
- **Módulos afectados:** UIGASHONGYANG.pas, UIGASHONGYANG.dfm
- **Se atiende en:** [E0.2](../PLAN_OPTIMIZACION.md#e02--identificar-el-hilo-de-cada-evento-instrumentación)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  Qué corre en el hilo principal:
  - Timers (certeza alta): el TService se crea con Application.CreateForm en el hilo principal (PDISPENSARIOS.dpr) y TTimer asigna su ventana en el constructor, así que Timer1 y Timer2 corren en el bucle Forms.Application.HandleMessage de SvcMgr.
  - Socket (certeza alta): se activa solo en Timer2Timer (2033) y ScktComp asigna el HWND en el hilo que lo activa.
  - Async Pro (certeza media): OnTriggerAvail llega por Synchronize o por la ventana del hilo que abrió el puerto (Iniciar corre desde ClientSocket1Read o Timer1). Indicio: pSerialTriggerAvail cambia Timer1.Enabled y SetTimer exige que la ventana pertenezca al hilo llamante; si corriera en el hilo despachador se verían EOutOfResources 'Not enough timers available' en el Visor de eventos.
  Consecuencias: no hay acceso concurrente a rootJSON ni a TMangueras, y SwProcesando es casi código muerto. A cambio, cualquier espera detiene serial y socket a la vez.
  Concurrencia real:
  (a) En el arranque, Timer2 viene habilitado desde el .dfm y puede disparar antes de que ServiceExecute (hilo del servicio) cree ListaLog y rootJSON y asigne Host/Port. Active:=True falla y el except llama AgregaLog con ListaLog=nil (AV).
  (b) Al detener, ClientSocket1.Active:=False se ejecuta desde el hilo del servicio (303).
  (c) SHUTDOWN solo llama ServiceThread.Terminate: ProcessRequests(True) sigue bloqueado en GetMessage hasta que llegue otro mensaje, así que el servicio puede no detenerse.
- **Evidencia:** .dfm 33-38: Timer2 con Interval=200 y Enabled en True por omisión; 295-297: las listas se crean después de leer el ini; 301-302: while not Terminated do ServiceThread.ProcessRequests(True); 2415: ServiceThread.Terminate;
- **Impacto:** Excepciones en el arranque lento (p.ej. al encender el equipo), cierre no limpio y un SHUTDOWN que responde True sin detener el servicio.
- **Recomendación:** Poner Timer2.Enabled=False en el .dfm y habilitarlo al final de la inicialización de ServiceExecute, o crear listas y rootJSON en OnCreate. En Shutdown, tras Terminate, mandar PostThreadMessage(ServiceThread.ThreadID, WM_QUIT, 0, 0). Cerrar el socket en el hilo principal. Si se necesita desacoplar, mover el I/O serial a un hilo propio con una cola protegida.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="HYA-24"></a>
#### HYA-24 · 🟡 Media · rendimiento · riesgo — El cambio de paridad usa esperas activas que dependen de la resolución del temporizador y no se verifica

- **Ubicación:** `UIGASHONGYANG.pas` líneas 1084-1098, 1118-1141
- **Módulos afectados:** UIGASHONGYANG.pas
- **Se atiende en:** [E2.5](../PLAN_OPTIMIZACION.md#e25--reentrancia-comandos-del-bridge-durante-una-transacción-serial), [E4.3](../PLAN_OPTIMIZACION.md#e43--ciclo-serial-eficiente)
- **Verificación:** sin verificación independiente
- **Qué pasa:** ComandoConsola cambia la paridad con CambiaParidad (SetCommState directo) y llama EsperaTransmision: hasta 100 iteraciones de ClearCommError+Sleep(1) y luego Sleep(22000 div Baud + 1). Con la resolución por omisión de Windows cada Sleep dura ~16 ms, así que cada comando bloquea el hilo principal 16-35 ms. Si otra aplicación activa timeBeginPeriod(1), el margen final baja a ~3 ms, poco para adaptadores USB-serial que reportan cbOutQue=0 con el byte aún en su FIFO: la dirección saldría con paridad SPACE y el CPU no contestaría (fallas intermitentes según el equipo). Además: no se registra si se agotan las 100 iteraciones, no se revisa el resultado de Get/SetCommState, Baud=0 provoca división entre cero y el DCB interno de Async Pro queda desincronizado.
- **Evidencia:** 1122-1125: GetCommState(pSerial.Dispatcher.ComHandle, dcb); dcb.Parity:=xparidad; ... SetCommState(...); 1134-1140: for i:=1 to 100 do begin ClearCommError(...); if (pSerial.OutBuffUsed=0)and(stat.cbOutQue=0) then Break; Sleep(1); end; Sleep(22000 div pSerial.Baud+1);
- **Impacto:** Latencia y comunicación intermitente según el hardware y la carga del equipo, con CPU dormido en el mismo hilo que atiende al Bridge.
- **Recomendación:** Hacer configurable el retardo posterior (ini) y medirlo con el adaptador real del sitio. Usar WaitCommEvent(EV_TXEMPTY) con timeout, o timeBeginPeriod(1) acotado. Registrar cuando el buffer no se vacía. Validar Baud>0 en IniciaPSerial y revisar el resultado de SetCommState.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="HYA-25"></a>
#### HYA-25 · 🟡 Media · robustez · bug — La reconexión al Bridge bloquea el hilo ~1 s por intento, llena el Visor de eventos y detiene el sondeo

- **Ubicación:** `UIGASHONGYANG.pas` líneas 2025-2059, 402-414, 1786-1789
- **Módulos afectados:** UIGASHONGYANG.pas
- **Se atiende en:** [E2.2](../PLAN_OPTIMIZACION.md#e22--reconexión-no-bloqueante-y-con-manejo-de-errores)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Timer2Timer activa el socket y espera con Sleep(10)×101 a que conectado sea True. ClientSocket1Connect solo puede correr cuando el mismo hilo despache FD_CONNECT, cosa imposible durante el Sleep. Por eso el bucle siempre dura completo (~1-1.6 s) y termina en Exit. ClientSocket1 no tiene OnError: cada intento fallido con el Bridge abajo lanza ESocketError al manejador global, que en SvcMgr escribe en el Visor de eventos (~3000 entradas por hora). Al desconectarse se apaga Timer1, así que sin Bridge no se vigilan los dispensarios. Aun así, cualquier byte serial tardío lo vuelve a encender en el finally de pSerialTriggerAvail, dejando un estado inconsistente.
- **Evidencia:** 2033-2038: ClientSocket1.Active:=True; for i:=0 to 100 do begin Sleep(10); if conectado then Break; end; if not conectado then Exit; 412: Timer1.Enabled:=False; 1788: Timer1.Enabled:=true;
- **Impacto:** Durante una caída del Bridge el servicio queda casi bloqueado y sin vigilar los dispensarios, y el registro de eventos se inunda.
- **Recomendación:** Quitar el bucle de espera y enviar en el tick siguiente a OnConnect. Agregar OnError que ponga ErrorCode:=0, registre y reintente con backoff de 1-5 s. Mantener el sondeo serial aunque no haya Bridge y solo dejar de enviar JSON.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="HYA-26"></a>
#### HYA-26 · 🟡 Media · memoria_recursos · optimizacion — Bitácoras costosas: copia carácter por carácter, Delete(0) O(n), JSON completo en memoria y SaveToFile en rutas críticas

- **Ubicación:** `UIGASHONGYANG.pas` líneas 416-434, 469-487, 1692-1695, 2436-2450, 2801-2802, 2836-2837, 2052-2053
- **Módulos afectados:** UIGASHONGYANG.pas
- **Se atiende en:** [E2.4](../PLAN_OPTIMIZACION.md#e24--bitácoras-que-no-bloquean-append-incremental-rotación-y-sin-json-repetido)
- **Verificación:** sin verificación independiente
- **Qué pasa:** AgregaLog y AgregaLogPetRes arman la línea carácter por carácter y recortan con while Count>10000 do Delete(0), que desplaza 10000 punteros por cada línea. ListaLogPetRes guarda el JSON completo de cada envío y respuesta: 10000 líneas equivalen a solo 4-8 minutos y a decenas de MB en memoria con muchas posiciones. GuardarLog escribe los dos archivos completos y se llama desde rutas calientes: ProcesaLineaRec cada MinutosLog (antes de procesar la respuesta serial), excepciones de ActualizaCampoJSON/AddPeticionJSON, Timer2, ComandoConsola y ReiniciarPuerto. Los nombres llevan fecha-hora y no se depuran archivos viejos. No hay OnStop ni OnShutdown, así que el log en memoria se pierde al detener el servicio.
- **Evidencia:** 429: else lin2:=lin2+lin[i]; 431-432: while ListaLogPetRes.Count>10000 do ListaLogPetRes.Delete(0); 1692-1694: if (minutosLog>0) and (MinutesBetween(Now,horaLog)>=minutosLog) then begin horaLog:=Now; GuardarLog(0); end;
- **Impacto:** Uso de CPU y memoria en el hilo serial, pausas de cientos de ms al guardar, riesgo de llenar el disco con un MinutosLog bajo y poca historia para diagnosticar.
- **Recomendación:** Escapar los caracteres de control con un buffer preasignado. Recortar por lotes (p.ej. 1000 líneas) o usar un buffer circular. Registrar el JSON solo cuando cambie o en modo debug. Escribir de forma incremental (TFileStream en modo anexar) con rotación por tamaño y depuración por antigüedad. Agregar OnStop que guarde los logs.
- **Esfuerzo:** M · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="HYA-27"></a>
#### HYA-27 · 🟡 Media · observabilidad · deuda_tecnica — Mensajes de log repetitivos desplazan la información útil

- **Ubicación:** `UIGASHONGYANG.pas` líneas 2070-2073, 1886-1887, 1960-1962, 1823-1824, 1459-1462, 1080, 1704
- **Módulos afectados:** UIGASHONGYANG.pas
- **Se atiende en:** [E2.4](../PLAN_OPTIMIZACION.md#e24--bitácoras-que-no-bloquean-append-incremental-rotación-y-sin-json-repetido)
- **Verificación:** sin verificación independiente
- **Qué pasa:** ProcesaComandosExternos registra el texto de cada comando activo sin respuesta en cada llamada, y se llama al inicio de cada tick en el estado 'A' y otra vez en 'Z'. Un TOTAL que espera su 'N', o un AMP inválido, genera decenas de líneas por segundo. PublicaEstatusDispensarios escribe '>>Estatus inesperado 2' cuando una manguera está autorizada, aunque 2 es el estado normal tras un preset, en cada pasada por 'Z'. MeteACola descarta sin registrar nada. TotalTramas y TotalErrores se incrementan pero nunca se publican.
- **Evidencia:** 2073: AgregaLog(TabCmnd[xcmnd].Comando); 1823-1824: if estatus in [2,3,4] then AgregaLog('>>Estatus inesperado '+...+' - revisar secuencia si se repite');
- **Impacto:** El log de 10000 líneas se llena de ruido en minutos y se pierde el diagnóstico de incidentes.
- **Recomendación:** Registrar cada comando solo al recibirlo (SwNuevo) y al responderlo. Quitar el 2 del aviso de estatus inesperado o avisar solo cuando el estatus cambie. Registrar los descartes de cola. Escribir periódicamente contadores de tramas, errores y timeouts por manguera.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="HYA-28"></a>
#### HYA-28 · 🟡 Media · protocolo · bug — LOG/LOGREQ meten hasta 10000 líneas en un solo resultado JSON

- **Ubicación:** `UIGASHONGYANG.pas` líneas 2479-2529, 450-467
- **Módulos afectados:** UIGASHONGYANG.pas
- **Se atiende en:** [E4.4](../PLAN_OPTIMIZACION.md#e44--log-y-logreq-acotados)
- **Verificación:** sin verificación independiente
- **Qué pasa:** ObtenerLog y ObtenerLogPetRes concatenan las últimas r+1 líneas (hay un off-by-one en i:=Count-(r+1)) en un solo string. Ese string se agrega a Peticiones y viaja en los 2-3 JSON siguientes, se copia carácter por carácter al log de peticiones y se envía con SendText sin revisar el valor de retorno. En un socket no bloqueante un envío parcial truncaría el JSON y el Bridge lo descartaría. Con r grande (MB de texto) el hilo principal se bloquea varios segundos sin sondeo serial.
- **Evidencia:** 2494-2502: i:=ListaLog.Count-(r+1); if i<1 then i:=0; log:='True|'; for i:=i to ListaLog.Count-1 do log:=log+ListaLog[i]+'|'; AddPeticionJSON(folio, log); 454: socketResponse.SendText(resp);
- **Impacto:** Un comando de diagnóstico que degrada la operación y puede perder su propia respuesta.
- **Recomendación:** Limitar r (p.ej. 200) y el tamaño en bytes del resultado. Corregir el cálculo a Count-r. Armar el texto con TStringList.Text. En Responder verificar los bytes enviados y reintentar el resto.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="HYA-29"></a>
#### HYA-29 · 🟡 Media · protocolo · deuda_tecnica — Funciones de OpenGas que este driver no soporta o que no hacen nada, a diferencia de otros drivers

- **Ubicación:** `UIGASHONGYANG.pas` líneas 214-217, 341-388, 2131-2175, 1215-1220, 2256-2266
- **Módulos afectados:** UIGASHONGYANG.pas
- **Se atiende en:** [E5.4](../PLAN_OPTIMIZACION.md#e54--comandos-homogéneos-entre-marcas)
- **Verificación:** sin verificación independiente
- **Qué pasa:** STOP_e y START_e están en TMetodos pero no tienen rama en ClientSocket1Read, así que OpenGas recibe 'Comando desconocido' y no puede detener ni reanudar una venta (Bennett, Gilbarco, PAM, Team y Kairos sí lo implementan). AUTHORIZE sin producto (comb vacío, que se vuelve '00') no se acepta: OCC/OCL solo buscan la manguera con Combustible=xcomb y responden 'Manguera no existe', mientras otros drivers aceptan xcomb=0. PAYMENT (FINV) solo responde 'OK', y el campo finv de AUTHORIZE se calcula pero se ignora (asignación comentada en 2160).
- **Evidencia:** 217: ... STOP_e, START_e); 386-387: else AddPeticionJSON(folio, 'False|Comando desconocido|'); UIGASGILBARCO.pas 3158-3161: STOP_e: DetenerVenta(...); START_e: ReanudarVenta(...); UIGASWAYNE2W.pas 2552: if xcomb>0 then.
- **Impacto:** No hay paro remoto de despacho (seguridad operativa) y los presets sin producto se rechazan sin aviso.
- **Recomendación:** Implementar STOP/START si el protocolo Hong Yang tiene comando de paro; si no, responder 'False|No soportado|'. Con xcomb=0, autorizar la única manguera libre de la posición. Documentar qué hace PAYMENT.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="HYA-30"></a>
#### HYA-30 · 🟡 Media · configuracion · riesgo — Las conversiones numéricas dependen de la configuración regional y los precios inválidos se aceptan

- **Ubicación:** `UIGASHONGYANG.pas` líneas 926-935, 1190-1196, 2150, 2201, 2248-2250
- **Módulos afectados:** UIGASHONGYANG.pas
- **Se atiende en:** [E8.2](../PLAN_OPTIMIZACION.md#e82--configuración-regional-locale-explícita)
- **Verificación:** sin verificación independiente
- **Qué pasa:** StrToFloat/StrToFloatDef y FormatFloat/FormatoMoneda usan el DecimalSeparator de la cuenta del servicio (LocalSystem, con la configuración regional .DEFAULT). Si ese separador es ',', los presets '100.50' fallan con 'Error en Importe', AutorizarVenta toma los litros como 0 y los totales salen con coma. IniciaPrecios ignora sin aviso los precios no convertibles o <=0 y aun así responde 'True|'. uLkJSON, en cambio, sí normaliza el punto decimal.
- **Evidencia:** 926-928: precioComb:=StrToFloatDef(ExtraeElemStrSep(msj,Combustible,'|'),-1); if precioComb<=0 then Continue; 935: AddPeticionJSON(folio, 'True|');
- **Impacto:** Instalaciones con otra configuración regional fallan en presets y precios sin un indicio claro.
- **Recomendación:** Usar TFormatSettings con DecimalSeparator='.' (Delphi 7 tiene sobrecargas de StrToFloat y FormatFloat que lo aceptan). En IniciaPrecios responder False si algún precio solicitado es inválido.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="HYA-31"></a>
#### HYA-31 · 🟡 Media · robustez · bug — El reinicio de puerto programado cada 6 h tiene un aplazamiento que no funciona

- **Ubicación:** `UIGASHONGYANG.pas` líneas 1879-1884, 2729-2755
- **Módulos afectados:** UIGASHONGYANG.pas
- **Se atiende en:** [E4.3](../PLAN_OPTIMIZACION.md#e43--ciclo-serial-eficiente)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Timer1 llama ReiniciarPuerto(False) cuando pasan 6 h. Si hay posiciones ocupadas, ejecuta IncMinute(horaReinicio,1), que es una función y su resultado se descarta: no aplaza nada y el intento se repite en cada tick hasta que se liberen las posiciones. El reinicio usa Detener(0) e Iniciar(0), que agregan Peticiones con folio 0 y expulsan resultados. También alterna modoPreset alrededor de Iniciar sin efecto, porque Iniciar no lo usa. PosicionesLibres considera libre una posición en estatus 0.
- **Evidencia:** 2754: IncMinute(horaReinicio,1); 2737-2741: if modoPreset then begin modoPreset:=False; Iniciar(0); modoPreset:=True; end
- **Impacto:** Reinicios periódicos sin justificación documentada que pueden expulsar respuestas pendientes, y lógica que confunde.
- **Recomendación:** Hacer configurable el reinicio periódico (0 = desactivado) y documentar su motivo. Usar horaReinicio:=IncMinute(horaReinicio,1). Quitar el juego con modoPreset. No generar Peticiones con folio 0.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="HYA-36"></a>
#### HYA-36 · 🟡 Media · mantenibilidad · deuda_tecnica — Duplicación interna y con los demás drivers

- **Ubicación:** `UIGASHONGYANG.pas` líneas 942-1020, 1034-1078, 1504-1685, 2075-2231, 2479-2529
- **Módulos afectados:** UIGASHONGYANG.pas, UIGASBENNETT.pas, UIGASGILBARCO.pas, UIGASPAM.pas, UIGASTEAM.pas, UIGASTRITON.pas, UIGASWAYNE.pas, UIGASWAYNE2W.pas, UIGASKAIROS.pas
- **Se atiende en:** [E7.1](../PLAN_OPTIMIZACION.md#e71--updisplogpas-logger-común), [E7.3](../PLAN_OPTIMIZACION.md#e73--updispcomandospas-tabcmnd-despacho-y-resultados)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Dentro del archivo: ProcesoComandoC/D/U/S/L son variantes de DameEstatus más una bandera; ComandoA/C/D/N/V solo cambian el código de comando; el case de ComandoConsola repite el mismo patrón 8 veces; OCC/OCL y AMP/DMP están copiados con diferencias mínimas; ObtenerLog/ObtenerLogPetRes son iguales salvo la lista. Entre drivers, más de 20 rutinas genéricas son copias (ver bloques_duplicados). Por eso correcciones como la de los decimales de presets en Wayne 2W no llegaron aquí.
- **Evidencia:** Comparación normalizada (sin espacios ni nombre de clase): AgregaLogPetRes es idéntica en 8 drivers; AddPeticionJSON, IniciaPSerial, AutorizarVenta, FinVenta y Shutdown en 7.
- **Impacto:** Los bugs se replican y los fixes no se propagan.
- **Recomendación:** Extraer una unidad común (UDispBase.pas) con log, JSON, TabCmnd y socket. En este driver, parametrizar ComandoX(addr,lado,codigo,datos) y unificar el procesamiento de ACK.
- **Esfuerzo:** L · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="HYA-32"></a>
#### HYA-32 · ⚪ Baja · configuracion · deuda_tecnica — Parámetros de tiempo y capacidad fijos en el código

- **Ubicación:** `UIGASHONGYANG.pas` líneas 276, 1459, 1881, 1901, 1983-1992, 1151; UIGASHONGYANG.dfm 16-22, 33-38
- **Módulos afectados:** UIGASHONGYANG.pas, UIGASHONGYANG.dfm
- **Se atiende en:** [E0.5](../PLAN_OPTIMIZACION.md#e05--configuración-documentada-y-validada-al-arrancar)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Están fijos: Timer1 de 15 ms y Timer2 de 200 ms (.dfm), timeout de respuesta de 1 s y de trama parcial de 0.5 s, espera de 5 s sin comunicación, sondeo de inactivas de 2 s o 1 s según ModoPreset, reinicio cada 6 h, cola de 50, expiración de TabCmnd de 1 min, log de 10000 líneas y ruta 'C:\ImagenCo' por omisión. Nada de esto se puede ajustar en PDISPENSARIOS.ini, y el ini versionado no trae ServidorSocket ni parámetros de Hong Yang. ModoPreset solo cambia el intervalo de sondeo, no el modo de operación.
- **Evidencia:** 1901: ProxSondeo:=Now+IfThen(modoPreset,2,1)*TmSegundo; 1881: if HoursBetween(Now, horaReinicio)>=6 then; PDISPENSARIOS.ini: Marca=5, ConfPos=1:1,2:1;1:2,2:2.
- **Impacto:** Cualquier ajuste en campo requiere recompilar.
- **Recomendación:** Leer estos valores en ServiceExecute desde una sección [HONGYANG], con los valores actuales como default, y registrarlos al arrancar.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="HYA-33"></a>
#### HYA-33 · ⚪ Baja · seguridad · riesgo — La autenticación y el licenciamiento no tienen efecto real

- **Ubicación:** `UIGASHONGYANG.pas` líneas 796-814, 2693-2727, 2350-2380, 282-284
- **Módulos afectados:** UIGASHONGYANG.pas, PDISPENSARIOS.ini
- **Se atiende en:** [E8.1](../PLAN_OPTIMIZACION.md#e81--autenticación-licencia-y-modo-emulación)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Login valida password = MD5(usuario|yyyy-mm-ddThh:nn): cualquiera puede calcularlo y falla justo en el cambio de minuto. El Token resultante no se verifica en ningún comando. Encrypt/Decrypt (3DES con clave derivada de MD5) no se usan. La validación HASP está comentada, pero se sigue leyendo Licencia y se hace CoInitialize en cada RUN. El PDISPENSARIOS.ini versionado contiene un número de licencia.
- **Evidencia:** 802: if MD5(usuario+'|'+FormatDateTime('yyyy-mm-dd',Date)+'T'+FormatDateTime('hh:nn',Now))<>password then; Token solo se asigna en 805 y 812.
- **Impacto:** Cualquier proceso local que alcance el Bridge puede operar el dispensario, y la licencia no se aplica.
- **Recomendación:** Decidir si LOGIN es obligatorio; si lo es, verificar el Token por comando o en el Bridge. Eliminar Encrypt/Decrypt, sacar la licencia del ini versionado y decidir si HASP regresa o se elimina su código.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** sí

<a id="HYA-34"></a>
#### HYA-34 · ⚪ Baja · memoria_recursos · bug — La inicialización del servicio es frágil y tiene fugas menores

- **Ubicación:** `UIGASHONGYANG.pas` líneas 270-314, 574, 436-448, 840-857
- **Módulos afectados:** UIGASHONGYANG.pas
- **Se atiende en:** [E2.7](../PLAN_OPTIMIZACION.md#e27--initialize-idempotente-y-seguro-con-ventas-en-curso)
- **Verificación:** sin verificación independiente
- **Qué pasa:** ServiceExecute no libera el TIniFile y usa StrToInt sin default para el puerto y para MinutosLog. Si algo falla antes de la línea 295, su except usa ListaLog cuando aún no existe; además guarda ListaLog con el nombre LogDispPetRes. Inicializar no libera el árbol que devuelve TlkJSON.ParseText en cada INITIALIZE. ListaCmnd se crea y nunca se usa. MD5 y CRC16 liberan sus objetos sin try/finally.
- **Evidencia:** 275: config:= TIniFile.Create(...) sin Free; 278: StrToInt(ExtraeElemStrSep(...,2,':')); 306-307: ListaLog.Add(...); ListaLog.SaveToFile(rutaLog+...+'LogDispPetRes'+...); 574: js := TlkJSON.ParseText(...) sin Free.
- **Impacto:** Un ini mal escrito tumba el arranque con un AV en lugar de un mensaje claro, además de fugas menores.
- **Recomendación:** Usar try/finally con config.Free; usar StrToIntDef con defaults y registrar los valores leídos; crear las listas al principio; liberar js en el finally de Inicializar.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="HYA-35"></a>
#### HYA-35 · ⚪ Baja · mantenibilidad · deuda_tecnica — Código muerto y variables sin uso

- **Ubicación:** `UIGASHONGYANG.pas` líneas 2573-2592, 436-448, 874, 1504-1546, 1408-1409, 1356-1365, 1080-1083, 25-54, 131-251, 2352-2380
- **Módulos afectados:** UIGASHONGYANG.pas
- **Se atiende en:** [E8.3](../PLAN_OPTIMIZACION.md#e83--código-muerto-variables-globales-y-duplicación-interna)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  Rutinas sin uso o sin efecto:
  - IniciarPrecios no se llama; CRC16 y Encrypt/Decrypt tampoco se usan.
  - ConvierteBCD calcula xaux:=StrToHexSep(xres) y lo descarta en cada U/S/L.
  - ProcesoComandoC/D tienen el cuerpo comentado.
  - En DameEstatus la rama 'Enllavado' (ee:=9) es inalcanzable, porque las condiciones anteriores ya cubren todas las combinaciones de los bits 3 y 6. TraduceEstatusExterno 3, 4 y 6 nunca ocurren.
  - posactual y PosEstatus se calculan y no se usan.
  - ContadorAlarma>10 pone LinEstadoGen en ceros sin efecto en el JSON.
  Campos y variables sin uso: SwInicio2, IniciaCarga, SwCargaPreset, Estat_Cons, TipoPago, Boucher, ContInicDesp, Hora, SwDesp, SwPresetImp, impopreset, litrospreset, ActualizarPrecio, SegundosFinv, NumPaso, licencia, GSentinelKey, SwCerrar, swcierrabd, SwDespEmular, MangueraActual, PreciosInicio y las constantes NivelPrecio*/MaxEsperaRsp.
  Bloques comentados: HASP, FINV y 'D' previo al preset.
- **Evidencia:** grep: IniciarPrecios aparece solo en 117 y 2573-2589; SwDesp solo se asigna (770, 1300, 1576); SwDespEmular solo se declara (233).
- **Impacto:** Dificulta saber qué lógica está vigente; por ejemplo, parece que existe un fin de venta 7/8.
- **Recomendación:** Eliminar o documentar ese código; el historial queda en git.
- **Esfuerzo:** M · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="HYA-37"></a>
#### HYA-37 · ⚪ Baja · pruebas · deuda_tecnica — No hay pruebas automatizadas ni emulador del protocolo Hong Yang

- **Ubicación:** `UIGASHONGYANG.pas` líneas 859-916, 942-1020, 1388-1454, 1548-1553
- **Módulos afectados:** UIGASHONGYANG.pas
- **Se atiende en:** [E0.4](../PLAN_OPTIMIZACION.md#e04--simuladores-de-opengas-y-de-driver--batería-de-pruebas-de-protocolo), [E7.4](../PLAN_OPTIMIZACION.md#e74--separar-la-lógica-de-protocolo-serial-de-la-del-servicio-testeable)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Las funciones puras del protocolo (CalculaBCC, ConvierteBCD, ExtraeBCD, DameEstatus y el armado de tramas) y la máquina de estados no tienen pruebas. El modo emulación que menciona el historial (commit 8ba4373) ya no existe: SwDespEmular no se usa. Los bugs de precedencia, decimales y truncamiento se habrían detectado con pruebas sencillas.
- **Evidencia:** El repositorio no tiene proyectos de prueba; los comentarios de 943-1018 y 1548-1553 ya traen tramas de ejemplo utilizables como vectores.
- **Impacto:** Cambios a producción sin red de seguridad; p.ej. fd48cc2 cambió tiempos y paridad sin pruebas.
- **Recomendación:** Crear un proyecto DUnit o de consola con vectores de tramas reales, y un emulador serial (com0com más un script) que conteste A/N/V/S y permita inyectar errores de BCC, de longitud y silencios.
- **Esfuerzo:** M · **Riesgo del cambio:** bajo · **Toca contrato:** no

