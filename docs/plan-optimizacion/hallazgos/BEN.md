# Hallazgos · BEN · Driver Bennett (Marca 2) · UIGASBENNETT.pas

> Anexo del [plan de optimización](../PLAN_OPTIMIZACION.md). Código auditado: `IgasDispensarios@26ccfb4`, `IgasDispensariosBridge@99edafd`. Las líneas pueden haber cambiado: ubica las rutinas por su nombre.

## Cómo funciona este módulo

Togcvdispensarios_bennett es el TService que PDISPENSARIOS.exe crea cuando [CONF] Marca=2. Habla con la consola Bennett por TApdComPort (pSerial) con tramas STX+cmd+ETX+BCC: B00 para el estatus de todas las posiciones, Ann o 1nn para importe, volumen y precio en 6 u 8 digitos, Nnn para totalizadores, y K/P/5/L/S/E/F/J/U para modo, preset, nivel de precio, autorizacion, paro, litros, fin de venta y precios. Hacia el Bridge usa TClientSocket (127.0.0.1:1004) con el modelo pull. Timer2 (200 ms) reconecta y manda PING o el JSON mientras estado<=0. Al pasar a RUN (estado=1), Timer1 (150 ms) lleva el sondeo, y al final de cada trama serial procesada (ProcesaLinea) se manda el JSON completo (Estado, PosCarga[], Peticiones[]). Cada respuesta del Bridge ('folio|DISPENSERS|CMD|params') se procesa en ClientSocket1Read. INITIALIZE, PRICES, BLOCK y otros se ejecutan ahi mismo. AUTHORIZE, STOP, START, PAYMENT y TOTALS se guardan en TabCmnd[1..200] y se ejecutan en el paso NumPaso=4 del ciclo serial; su resultado se consulta con RESPCMND. Los resultados viajan en Peticiones (maximo 2) en el siguiente JSON. STATE, STATUS y TRANSACTION los contesta el Bridge con el snapshot. El driver se alineo con Wayne 2W en la reconexion (watchdog de 2 s, Responder con reconexion), pero se desvia en varios puntos: manda JSON en cada trama sin el filtro xTurnoSocket, nunca actualiza HoraOcc, su Terminar apaga Timer2 y no soporta '0'/'1'. Riesgos principales: (1) concurrencia real sin sincronizacion entre el hilo del servicio, donde corren los eventos del socket, y el hilo principal, donde corren los timers y casi seguro la serial, sobre listas de log, rootJSON, TPosCarga, TabCmnd y pSerial; (2) TERMINATE deja al driver mudo hasta reiniciar; (3) la perdida de comunicacion serial no se refleja (estatus congelados) y no se valida el BCC ni se reintenta ante NAK; (4) presets sin caducidad que se reaplican al volver la comunicacion; (5) precios de INITIALIZE nunca programados y PRICES ignorado si aun no hubo respuesta B; (6) TRANSACTION siempre con fecha 1899-12-30; (7) escrituras fuera de rango en LPrecios y TComb. Certeza del modelo de hilos: alta para socket y timers (basada en el comportamiento de ScktComp, TTimer y SvcMgr de Delphi 7; las fuentes VCL no estan en el repo), media para el hilo de OnTriggerAvail de Async Pro.

### Ciclo serial

Relojes: Timer1 (Interval 150 ms, Enabled=False en el dfm, corre en el hilo principal) lleva el sondeo. ComandoConsola (lineas 921/932) y pSerialTriggerAvail (lineas 951/982) lo apagan y lo vuelven a encender en cada envio y en cada recepcion, asi que el tick llega 150 ms despues de la ultima actividad. Ambos lo encienden sin mirar estado ni detenido. Timer2 (200 ms) solo actua con el socket caido o con estado<=0.



Timer1Timer (lineas 2083-2115):

1. Watchdog del Bridge: si pasan 2 s o mas sin respuesta, cierra el socket, apaga Timer1, enciende Timer2 y sale.

2. Si no hay comando en espera (SwEsperaRsp=False), envia 'B00'.

3. Si hay un comando en espera, incrementa ContEsperaRsp. Al pasar MaxEsperaRsp=4 (5 ticks, unos 750 ms) simula una respuesta y llama ProcesaLinea:

   - para B: STX STX 'B00' ETX '.*'. Por el doble STX no entra al case 'B' y los estatus quedan congelados.

   - para A/N: 'A00'/'N00' con posicion 0, que se ignora.

   - para el resto: NAK, que tampoco tiene efecto.

Las excepciones se tragan con un except vacio.



Transmision (ComandoConsola, lineas 910-934):

- Un solo comando en vuelo (SwEsperaRsp/LinCmnd/CharCmnd).

- La cola es ListaCmnd (TStringList FIFO; ComandoConsolaBuff manda directo si la linea esta libre).

- Trama: STX + cmd + ETX + BCC, donde BCC = 256 - (suma de cmd+ETX mod 256).

- Solo se envia si OutBuffFree alcanza y el puerto esta abierto. Si no, el comando se descarta en silencio y se espera el timeout.

- Limpia LineaBuff pero no Linea, SwBcc ni FinLinea.



Recepcion (pSerialTriggerAvail, lineas 946-984):

- Agrega a LineaBuff los Count bytes con GetChar y los pasa a Linea hasta un ACK, un NAK o el byte que sigue a ETX (el BCC, que no se valida).

- Linea y SwBcc persisten entre eventos, asi que las tramas parciales se completan. Pero los bytes que quedan despues de FinLinea esperan al siguiente evento o se borran en el siguiente envio, y un fragmento huerfano se pega a la siguiente respuesta.

- Cualquier trama, aunque sea tardia, pone SwEsperaRsp:=False (linea 1017).



Maquina de estados (NumPaso en ProcesaLinea, lineas 987-1690):

- Respuesta 'B': NumPaso=1. MaxPosCargaActiva = longitud/2, con tope en MaxPosCarga. Para cada posicion registrada se lee PosActual (0 se fuerza a 1) y estatus. Un estatus 0 se enmascara durante 4 lecturas (stcero). Reglas por estado:

  - 1: limpia el preset y manda F..9999 si hubo litros.

  - 3: si viene de 4 y hay PresetImpo, reenvia el preset al 4to ciclo.

  - 7: tras SegundosFinv (30 s) encola J.

  - Con SwInicio manda K..1, L..1 y E..

  - La autorizacion automatica 'S' solo aplica en modo 'Normal', que nunca se asigna.

- Tras vaciar ListaCmnd, NumPaso=2: encola 'A'+pos ('1'+pos en 8 digitos) para posiciones con cambio de estatus, estatus>=5 (incluye 9 por precedencia), SwA, swinicio2 o swcargando.

- Respuestas A/1: volumen, importe y precio, con recalculos y try/except vacio. En 8 digitos, J inmediato si finventa=0.

- NumPaso=3: bloque muerto (MaximoDePosiciones<24 siempre es falso).

- Siempre se reconstruyen LinEstado/LinEstadoGen y se actualizan Estatus, Combustible y Manguera en el JSON.

- NumPaso=4: recorre TabCmnd[1..200] activos y sin respuesta y ejecuta OCC, OCL, FINV, EFV, DVC/PARAR, REANUDAR y TOTAL (TOTAL manda N y la respuesta 'N' lleva NumPaso a 3 y luego a 4). Despues vuelve a NumPaso=1 y el siguiente tick manda B00.

- Los ACK de K/P/L/S/U/J/E/F no se interpretan: solo liberan la linea.



Presets OCC/OCL:

- Secuencia K..2, P/5 importe, L..1, S..(+caracter de producto). OCL manda antes F+litros y usa un importe de 9999.99.

- Se valida en el siguiente ciclo con SwCmndB: si sigue en 1/3, reintenta hasta BennetReintentosPreset (5) veces, cada vez con esperamiliseg(500) bloqueante. Si no lo logra, responde 'Error al aplicar PRESET'.

- No hay caducidad por tiempo.



Esperas activas:

- esperamiliseg(500) por cada reintento de preset (lineas 1440, 1514) y 300 ms tras F en OCL (linea 1543).

- Muertas: 300 ms de swcierrabd y 100 ms por comando en IniciarPrecios.

- Timer2Timer: Sleep(500) mas hasta 1 s de Sleep(10) por intento de reconexion.

- No hay ProcessMessages explicito. EsperaMiliSeg vive en ULIBGRAL y no esta disponible para verificarlo.



Tiempos efectivos (estimados para 9600 bps, sin medicion):

- Estacion ociosa: B00 (unos 40-70 ms de ida y vuelta) + 150 ms de espera, o sea unos 200-250 ms por ciclo (4-5 ciclos/s).

- Cada posicion despachando suma unos 30-60 ms por su lectura A/1.

- Cada posicion que no contesta A o esta en error suma unos 750 ms por ciclo.

- Un preset son 4 intercambios (unos 150-250 ms) y se valida en el ciclo siguiente. Con reintentos, hasta unos 3 s bloqueantes.

- En cada trama o timeout se regenera y envia el JSON completo al Bridge y se registra caracter por caracter en ListaLogPetRes.

### Contrato con el Bridge, visto desde este módulo

- **Conexión:** TClientSocket ClientSocket1 (dfm: ctNonBlocking, Port=0, solo OnConnect/OnDisconnect/OnRead, sin OnError). Host y puerto se leen de PDISPENSARIOS.ini [CONF] ServidorSocket (default '127.0.0.1:1004') con ExtraeElemStrSep y StrToInt sin default (lineas 264-265). Se activa en ServiceExecute (linea 276, hilo del servicio, antes de crear ListaLog, ListaLogPetRes y rootJSON) y se reactiva en Timer2Timer (lineas 585-589, hilo principal). No habla con OpenGas directo: todo pasa por el Bridge en modo pull. El driver siempre inicia y el Bridge (SSocketPDispClientRead) contesta exactamente una linea por cada mensaje recibido: la siguiente peticion pendiente 'folio\|DISPENSERS\|CMD\|params' o '0\|DISPENSERS\|NOTHING'. No hay delimitador ni longitud de mensaje.
- **Ciclo de envío:** (a) Timer2 (200 ms, Enabled=True desde el dfm) mientras no este conectado o estado<=0: si no esta conectado hace Active:=False, Sleep(500), Active:=True y espera hasta 101 x Sleep(10) a que OnConnect ponga conectado; luego Responder('PING') o Responder(GenerateText(rootJSON)). Si estado>0 apaga Timer2 y enciende Timer1 (lineas 575-615). (b) En operacion (estado=1), el finally de ProcesaLinea (lineas 1678-1689) hace Responder(TlkJSON.GenerateText(rootJSON)) en CADA trama serial procesada (B00, cada A/1/N, cada ACK de K/P/L/S/U/J/E/F) y en cada timeout simulado por Timer1Timer: unos 4-5 envios/s con la estacion ociosa y 10-20 envios/s con posiciones despachando. xTurnoSocket se calcula (lineas 1007-1009) pero ya no filtra, porque el filtro se quito en el commit 0e02888. (c) Iniciar (RUN) envia el JSON de inmediato desde el hilo del socket (linea 1918). Cada envio provoca una respuesta del Bridge.
- **PING vs JSON:** respJson arranca en False (campo sin inicializar) y AddPeticionJSON lo pone en True (linea 464) con la primera respuesta procesada, incluida '0\|DISPENSERS\|NOTHING' (NOTHING_e llama AddPeticionJSON(0,'True\|')). Nunca vuelve a False (Wayne y PAM si lo regresan a False en el comando '0'). En la practica solo se manda PING al arrancar, hasta el primer comando (el Bridge lo resuelve con el auto-kick TRACE a los 5 s). Despues siempre se manda JSON, tambien desde Timer2 cuando estado<=0. En el Bridge cualquier mensaje que contenga el texto 'PING' (AnsiContainsText) no se parsea; esto afecta resultados de LOG/LOGREQ que incluyan lineas 'E PING'.
- **Peticiones:** AddPeticionJSON (lineas 438-471) crea Peticiones si no existe, borra con Delete(0) mientras Count>=2 (uLkJSON _Delete libera el objeto) y agrega {Folio, Resultado}. Asi quedan siempre los 2 ultimos. Como cada respuesta NOTHING agrega {Folio:0, Resultado:'True\|'}, un resultado real viaja como maximo en 2 envios consecutivos y el Bridge lo empareja por folio con TryPopByFolio. Resultado usa el formato 'True\|...\|' o 'False\|mensaje\|'. Para AUTHORIZE, STOP, START, PAYMENT y TOTALS el resultado es 'True\|<folio interno TabCmnd>\|' (TOTALS: 'True\|0\|0\|0\|0\|0\|0\|folio\|'), y el resultado real se obtiene despues con RESPCMND\|folio. Pero AUTHORIZE, PRICES y PAYMENT los confirma el Bridge al momento (CliSock=nil), asi que OpenGas nunca ve ese folio ni los errores.
- **Reconexión:** Cuatro caminos ponen conectado:=False y pasan el control a Timer2. (1) ClientSocket1Disconnect: socketResponse:=nil, Timer1 apagado, Timer2 encendido. (2) Excepcion en Responder: log, GuardarLog, Active:=False en try, Timer1 apagado, Timer2 encendido. (3) Watchdog en Timer1Timer: si SecondsBetween(Now,horaAct)>=2, sin respuesta del Bridge en 2 s (horaAct solo se actualiza en OnConnect y OnRead), cierra el socket, apaga Timer1 y enciende Timer2. (4) Excepcion en el envio del finally de ProcesaLinea: apaga Timer1 y enciende Timer2. Despues Timer2Timer bloquea el hilo principal unos 0.5 a 1.5 s por intento (Sleep(500) mas un bucle Sleep(10)), con un intento cada 1.7 s mas o menos. El bucle solo detecta la conexion porque OnConnect se despacha en otro hilo, el del servicio. Mientras no hay conexion, el sondeo serial queda detenido; Timer1 solo se reactiva cuando Timer2Timer reconecta y envia con estado>0.
- **Comandos:**
  - NOTHING -> AddPeticionJSON(0,'True\|') en cada respuesta vacia
  - INITIALIZE (json\|variables con CRLF: SoportaSeleccionProducto, Bennett8Digitos, BennetReintentosPreset) -> LiberaInicializacion si estado>-1, IniciaPSerial, AgregaPosCarga, LPrecios por Products; estado:=0
  - PARAMETERS (json CounterToPaySale) -> SegundosFinv
  - LOGIN usuario\|MD5(usuario\|yyyy-mm-ddThh:nn) -> Token (no se valida en ningun otro comando)
  - LOGOUT -> Token:=''
  - PRICES p1\|p2\|p3\|p4 -> comandos U contado y credito por posicion y manguera (solo hasta MaxPosCargaActiva)
  - AUTHORIZE pos\|comb\|importe\|litros\|finv -> TabCmnd 'OCC pos importe comb finv' u 'OCL pos litros comb finv' (finv invertido)
  - STOP pos -> 'DVC pos' (E y, en modo Normal, P9999)
  - START pos -> 'REANUDAR pos' (S solo si estatus=6)
  - SELFSERVICE pos\|0 -> ModoOpera='Prepago'
  - FULLSERVICE pos\|0 -> tambien ModoOpera='Prepago' (no hace nada)
  - BLOCK pos\|0 / UNBLOCK pos\|0 -> SwDesHabilitado (no manda nada a la consola)
  - PAYMENT pos -> 'FINV pos' (J)
  - TOTALS pos -> 'TOTAL pos' (N y respuesta por RESPCMND)
  - HALT -> Detener (cierra el puerto, estado 0)
  - RUN -> Iniciar (abre el puerto, estado 1, envia JSON)
  - SHUTDOWN -> ServiceThread.Terminate (si estado<=0)
  - TERMINATE -> Terminar (estado -1, apaga Timer1 y Timer2)
  - TRACE -> GuardarLog (3 archivos)
  - SAVELOGREQ -> GuardarLogPetRes
  - RESPCMND folio -> ResultadoComando de TabCmnd
  - LOG n / LOGREQ n -> ultimas n+1 lineas del log en Resultado
  - No manejados (los contesta el Bridge o caen en 'Comando desconocido'): STATE, STATUS, TRANSACTION, y los mensajes '0'/'1' que el Bridge reenvia como 'DISPENSERS\|0/1'
- **Campos JSON:**
  - Estado (numero: -1 sin inicializar, 0 inicializado o detenido, 1 corriendo; SetEstadoJSON)
  - PosCarga[].DispenserId (numero, solo posiciones de INITIALIZE, 1..32)
  - PosCarga[].HoraOcc (texto 'yyyy-mm-ddThh:nn', se pone una sola vez con HoraOcc=0, siempre '1899-12-30T00:00', NUNCA se actualiza)
  - PosCarga[].Manguera (MangActual: manguera de PosActual del ultimo B00, 4 se muestra como 3, 0 se fuerza a 1; se actualiza en cada trama)
  - PosCarga[].Combustible (CombActual = TComb de PosActual; ProductId original, sin MapeoCombustibles)
  - PosCarga[].Estatus (numero de codigo OpenGas: 0 sin com., 1 inactivo, 2 cargando, 3 fin de carga, 5 llamando, 7 bloqueado, 8 detenido, 9 autorizado; se recalcula en cada trama)
  - PosCarga[].Importe / Volumen / Precio (solo en respuestas A/1; volumen reescrito como importe/precio con 3 decimales e importe recalculado si hay overflow de 6 digitos)
  - PosCarga[].Hoses[].HoseId (TMang: la manguera 3 se publica como 4)
  - PosCarga[].Hoses[].ProductId (producto mapeado por MapeoCombustibles si existe)
  - PosCarga[].Hoses[].Total (TotalLitros desde la respuesta N, en litros; el Bridge no lo usa)
  - Peticiones[] {Folio, Resultado}, maximo 2
- **Desviaciones respecto a otros drivers:**
  - Envia el JSON completo en CADA ProcesaLinea, sin el filtro xTurnoSocket=3 de Wayne2W/Gilbarco ni MsEnvioJSON de Team. El filtro se quito en 0e02888 y la variable xTurnoSocket quedo muerta.
  - Es el unico driver que nunca actualiza PosCarga[].HoraOcc (los demas llaman ActualizaCampoJSON(...,'HoraOcc',...)), asi que TRANSACTION via Bridge da 1899-12-30T00:00.
  - Terminar apaga tambien Timer2 (Wayne, Wayne2W y PAM no lo hacen) y el driver deja de emitir.
  - No tiene la rama de mensajes '0'/'1' (liberar o retomar el puerto) que si tienen Wayne y PAM.
  - Timer2Timer no valida pSerial.Open antes de reactivar Timer1 (Wayne si).
  - Responder con reconexion y watchdog horaAct de 2 s en Timer1Timer: solo Bennett y Wayne2W.
  - Iniciar (RUN) manda el JSON de inmediato desde el hilo del socket.
  - PosRegistrada/SwRegistrada (huecos en DispenserId) solo existe en Bennett (d9151e4).
  - Hoses[].HoseId publica 4 para la manguera 3 (mapeo Bennett), mientras Manguera publica 3.
  - TOTAL calcula los importes del totalizador como litros x precio actual de LPrecios y reporta solo 3 mangueras.
  - Parametros es un metodo propio (CounterToPaySale -> SegundosFinv con J automatico).

### Bloques duplicados con otros módulos

| Rutina | Líneas | Nota |
|---|---|---|
| AgregaLog | 617-635 | Igual a Team 1412-1424, PAM 599-617, HongYang 469-487 y Gilbarco 355-381; hay variantes en Wayne 823-844, Triton 240-261 y Wayne2W 459-484. Su cuerpo es el mismo de AgregaLogPetRes (637-655), solo cambia la lista, y el de AgregaLogOG del Bridge (UIGASBRIDGE.pas 439-457). |
| AgregaLogPetRes | 637-655 | Igual a Wayne 346-364, Team 1426-1438, PAM 619-637, HongYang 416-434, Gilbarco 383-409 y Triton 204-222; Wayne2W 486-511 es una variante. |
| AddPeticionJSON | 438-471 | Igual a Wayne 2218-2251, PAM 563-597, HongYang 2807-2840, Gilbarco 3280-3313, Wayne2W 3264-3297 y Triton 281-314; Team 535-564 es una variante. |
| ActualizaCampoJSON | 473-518 | La misma busqueda por DispenserId o por indice aparece con variantes menores en Wayne 2169-2216 (igual a Wayne2W 3215-3262 y Triton 1323-1370), Team 501-533, PAM 504-548, HongYang 2758-2805 y Gilbarco 3230-3278. |
| SetEstadoJSON | 563-573 | Igual a Wayne 2701-2711, Gilbarco 3351-3361, Wayne2W 3828-3838 y Triton 192-202; Team 566-577, PAM 550-561 y HongYang 2842-2854 son variantes. |
| ApplyTotalLitrosToJSON | 520-561 | Variante del bloque que comparten Wayne 2253-2288, PAM 2926-2961, HongYang 2856-2891, Gilbarco 3315-3349 y Triton 1372-1407; Team 579-619 y Wayne2W 3299-3340 tienen otras variantes. |
| Responder | 409-436 | Es la version con reconexion de Wayne2W 534-557; solo cambia el try alrededor de Active:=False y el texto del log. Wayne 2954-2971, Team 482-499, PAM 485-502, Gilbarco 411-430 y Triton 367-384 usan la version sin reconexion. |
| Timer2Timer | 575-615 | Mismo patron que Wayne2W 3892-3933: Sleep(500) y un bucle de 101 Sleep(10). Wayne 2917-2952 agrega la condicion pSerial.Open. Team 354-389, PAM 319-353, HongYang 2025-2059, Gilbarco 3071-3112 y Triton 330-365 son variantes. |
| ClientSocket1Connect / ClientSocket1Disconnect | 304-318 | Iguales a Wayne2W 3935-3949. Los demas drivers (Wayne 2903-2915, Team 340-352, PAM 355-367, HongYang 402-414, Gilbarco 3059-3069, Triton 316-328) no manejan horaAct ni socketResponse. |
| ClientSocket1Read | 320-407 | Todos los drivers tienen el mismo esqueleto: 'folio\|DISPENSERS\|CMD\|params', reconstruccion de parametros con ExtraeElemStrSep, GetEnumValue(TMetodos) y un case. Wayne 2764-2901 y PAM 369-483 agregan la rama '0'/'1'. |
| Login / Logout / MD5 | 2535-2559, 2578-2582 | Login y Logout son iguales a Team 1037-1055, PAM 2830-2860 y HongYang 796-814. MD5 es igual a Wayne 701-711, Team 3052-3062, PAM 2844-2854, Gilbarco 493-503, Wayne2W 969-979 y Triton 1090-1100. |
| Encrypt / Decrypt | 2630-2650 | Hay variantes en PAM 2882-2916 y HongYang 2693-2727; en Bennett no se usan. |
| GuardarLog / GuardarLogPetRes / GuardaLogComandos | 1958-1984, 2610-2628 | GuardarLogPetRes es igual a Team 1376-1385 y PAM 2475-2486. GuardaLogComandos es igual a PAM 2862-2880 (con el mismo 'Exception.Create' sin raise). GuardarLog es una variante de Wayne 2479-2493, HongYang 2436-2450, Wayne2W 3545-3559 y Triton 224-238. |
| ObtenerLog / ObtenerLogPetRes | 1986-2036 | Iguales a PAM 2515-2565. Hay variantes en Wayne 2605-2655, Wayne2W 3732-3782, Triton 1038-1088, HongYang 2479-2529, Gilbarco 962-1018 y Team 1387-1410. Las dos funciones de Bennett son iguales entre si, salvo la lista que leen. |
| ExtraeElemStrEnter / NoElemStrEnter | 2652-2690 | Iguales a Wayne 2075-2113, Team 3013-3050, PAM 2791-2828, Gilbarco 2059-2107 y Wayne2W 929-967. |
| IniciaPSerial | 657-725 | Igual a Wayne 495-564, Team 1445-1480, PAM 644-712, HongYang 489-558, Wayne2W 736-805 y Triton 667-736; Gilbarco 1837-1923 es una variante. |
| Inicializar / LiberaInicializacion / AgregaPosCarga | 2399-2501, 761-890 | Todos los drivers comparten el mismo esqueleto (parseo de Consoles, Dispensers y Products, reutilizacion del nodo PosCarga y construccion de Hoses) con variantes por marca: Wayne 366-699, Team 621-900, PAM 1896-2021 y 2643-2758, HongYang 560-794, Gilbarco 1676-2057, Wayne2W 578-927 y Triton 490-665. |
| EjecutaComando / ResultadoComando / RespuestaComando / ValidaCifra | 1765-1839, 2117-2142 | ResultadoComando es igual a PAM 2567-2581 y Wayne2W 1061-1076. ValidaCifra es igual a PAM 1855-1879 y Gilbarco 2466-2494. RespuestaComando es igual a HongYang 2452-2477. EjecutaComando es una variante de PAM 2036-2068 y Team 2234-2266 (que son iguales entre si). |
| Manejadores de comandos (AutorizarVenta, DetenerVenta, ReanudarVenta, FinVenta, TotalesBomba) | 2038-2081, 2144-2172, 2224-2237, 2294-2315 | AutorizarVenta es igual en Wayne 2290-2334, Team 902-937, PAM 2070-2113, HongYang 1184-1227, Gilbarco 691-738 y Wayne2W 3342-3386. DetenerVenta es igual en Wayne, Team, PAM, Gilbarco, Wayne2W y Triton. ReanudarVenta es igual en Wayne, Team, PAM, Gilbarco y Wayne2W. FinVenta es igual en Wayne, Team, PAM, HongYang, Gilbarco y Wayne2W. TotalesBomba es igual a Team 1215-1231, PAM 2335-2356 y HongYang 2550-2571. |
| ActivaModoPrepago / DesactivaModoPrepago / Bloquear / Desbloquear | 2174-2222, 2327-2397 | Los dos manejadores de modo tienen el mismo cuerpo dentro de Bennett (los dos asignan 'Prepago'). Existen variantes en todos los drivers; Wayne 2143-2167 y 2366-2390 tambien asigna 'Prepago' en los dos. Bloquear y Desbloquear siguen el mismo esqueleto en todos los drivers. |
| Iniciar / Detener / Terminar / Shutdown | 1862-1951, 2317-2325, 2503-2519 | Todos los drivers comparten el esqueleto, con el mismo bloque HASP comentado y CoInitialize. El Terminar de Bennett se aparta del de Wayne 2723-2738, Team 1326-1341 y PAM 2760-2775 porque apaga Timer2. Shutdown es una variante del de Wayne, Team y PAM 2446-2454. |
| ComandoConsola / pSerialTriggerAvail / CalculaBCC | 910-984, 936-944 | ComandoConsola es igual a PAM 714-738. pSerialTriggerAvail es casi igual a PAM 784-823 (PAM agrega SwError). CalculaBCC es una variante de PAM 740-750. |
| Bloque TabCmnd OCC/OCL ('Valida que se haya aplicado el PRESET') | 1405-1476, 1478-1567 | OCC y OCL estan duplicados dentro del mismo archivo: unas 160 lineas de diff y alrededor de 70% del logico es igual. El mismo patron aparece en PAM (1402, 1491) y Wayne (1588, 1655). Lo mismo pasa con la respuesta de TOTAL, que se arma dos veces (1646-1648 y 1655-1657). |
| CombustibleEnPosicion / PosicionDeCombustible | 1739-1749, 1841-1854 | Iguales a Team 2268-2279 y 2933-2946; hay variantes en Wayne, PAM y Gilbarco. |
| CRC16 / FechaHoraExtToStr | 2521-2533, 892-895 | CRC16 es igual a Wayne 332-344, PAM 2777-2789 y HongYang 436-448; en Bennett no se usa y en el Bridge hay otra copia. FechaHoraExtToStr es igual a Wayne 769-773, Team 1440-1443, PAM 639-642, HongYang 834-838 y Gilbarco 432-435. |
| IniciaPrecios / IniciarPrecios | 727-759, 2584-2608 | Las dos generan los mismos comandos U de contado y credito por posicion y manguera dentro del archivo; IniciarPrecios no se ejecuta nunca. Wayne 2048-2073 y HongYang 2573-2592 tienen variantes. |

## Hallazgos (43)

<a id="BEN-01"></a>
#### BEN-01 · 🔴 Crítica · concurrencia · bug — Acceso concurrente sin sincronizacion entre el hilo del servicio (socket) y el hilo principal (timers/serial)

- **Ubicación:** `UIGASBENNETT.pas` líneas 276, 290-291, 320-407 (331), 409-436 (413,419), 438-471, 575-615, 637-655, 820-821, 897-934, 1398-1403, 1678-1689, 1765-1797 (1784-1795), 1918, 1937, 2470-2501
- **Módulos afectados:** UIGASBENNETT, UIGASWAYNE2W, UIGASWAYNE, UIGASTEAM, UIGASPAM, UIGASGILBARCO, UIGASHONGYANG, UIGASTRITON
- **Se atiende en:** [E0.2](../PLAN_OPTIMIZACION.md#e02--identificar-el-hilo-de-cada-evento-instrumentación), [E2.6](../PLAN_OPTIMIZACION.md#e26--bennett-todo-en-un-solo-hilo)
- **Verificación:** sin verificación independiente
- **Qué pasa:** ServiceExecute activa ClientSocket1 (linea 276) y bombea mensajes con ServiceThread.ProcessRequests(True) (lineas 290-291). En ScktComp de Delphi 7 el HWND del socket se crea con AllocateHWnd en el hilo que lo activa por primera vez y no se destruye al cerrar. Por eso OnRead, OnConnect y OnDisconnect corren en el hilo del servicio, aunque Timer2 lo reactive despues. Timer1 y Timer2 se crean en Application.CreateForm, en el hilo principal, que corre el bucle Forms.Application.HandleMessage, asi que sus eventos corren ahi. OnTriggerAvail de Async Pro llega al hilo principal (sincronizado) o a su hilo despachador; en ambos casos queda en un hilo distinto al del socket. No hay ninguna seccion critica en el driver (grep de CriticalSection/Synchronize vacio). Certeza alta para socket y timers, media para el hilo de la serial; las fuentes VCL y APRO no estan en el repo.
- **Evidencia:** ClientSocket1Read (hilo del servicio) hace AgregaLogPetRes('R '+mensaje) en la linea 331 y AddPeticionJSON, que hace petArr.Delete(0) y Add en las lineas 456-463. Al mismo tiempo ProcesaLinea (linea 1681) y Timer2Timer (lineas 598-600) hacen GenerateText(rootJSON) y Responder, que registra 'E '+JSON con AgregaLogPetRes en la linea 419 DESPUES del SendText de la linea 413. La respuesta del Bridge, que es local (unos 1 ms), llega mientras el hilo principal todavia escapa el JSON caracter por caracter, y los dos hilos ejecutan 'while Count>10000 do Delete(0); Add(lin2)' sobre el mismo TStringList. Hay mas casos: EjecutaComando pone SwActivo:=true (linea 1790) antes de copiar Comando (linea 1791) mientras NumPaso=4 recorre TabCmnd (lineas 1398-1403); IniciaPrecios llega a ComandoConsola y escribe pSerial, SwEsperaRsp y ListaCmnd desde el socket; Detener y LiberaInicializacion cierran pSerial (lineas 1937 y 2476-2477); AgregaPosCarga borra PosCarga (lineas 820-821) con Timer2 activo; Iniciar llama Responder desde el socket (linea 1918).
- **Impacto:** AV intermitentes y corrupcion de heap: conteo de referencias de strings, FCount/FList de TStringList y objetos JSON liberados mientras GenerateText los recorre. Tambien JSON invalido hacia el Bridge, y la posible reejecucion de un comando viejo (OCC con el Comando anterior) en la ventana entre SwActivo y Comando. Puede terminar en caida del servicio sin causa clara. La exposicion es mayor que en Wayne2W/Gilbarco porque Bennett envia y registra el JSON en cada trama (5-20 por segundo).
- **Recomendación:** Serializar el trabajo en un solo hilo. En ClientSocket1Read solo encolar el texto recibido en una cola protegida y avisar al hilo principal con PostMessage a un HWND propio, o drenar la cola en Timer1/Timer2. Asi los comandos (INITIALIZE, PRICES, AUTHORIZE...) se ejecutan en el mismo hilo que ProcesaLinea. Otra opcion es activar el socket solo desde el hilo principal (quitar la linea 276 y habilitar Timer2 al final de ServiceExecute). Como paliativo inmediato, proteger ListaLog, ListaLogPetRes, rootJSON, TabCmnd, ListaCmnd y pSerial con un TCriticalSection unico. Validar con un Bridge simulado que conteste en menos de 1 ms a 20 mensajes/s durante 24 h, con FastMM FullDebugMode.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="BEN-02"></a>
#### BEN-02 · 🔴 Crítica · protocolo · bug — TERMINATE apaga Timer2: el driver deja de emitir y el protocolo pull queda bloqueado

- **Ubicación:** `UIGASBENNETT.pas` líneas 2503-2519 (2508-2509, 2517)
- **Se atiende en:** [E1.4](../PLAN_OPTIMIZACION.md#e14--sondeo-que-se-congela-livelocks-y-bloqueos-de-la-máquina-de-estados)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Terminar hace Timer1.Enabled:=False y Timer2.Enabled:=False. El driver solo envia algo al Bridge desde Timer2Timer, desde ProcesaLinea (que necesita Timer1 o eventos serial; el puerto queda cerrado en la linea 2510) o desde Iniciar (que necesita recibir RUN). El Bridge solo manda comandos como respuesta a un mensaje del driver. Ni Wayne, ni Wayne2W, ni PAM apagan Timer2 en Terminar.
- **Evidencia:** Lineas 2508-2509: 'Timer1.Enabled:=False; Timer2.Enabled:=False;'. El resultado 'True|' de la linea 2517 se queda en Peticiones y nunca se envia. En el Bridge, AddPeticion (UIGASBRIDGE.pas 410-413) cancela las peticiones y hace SSocketOG.Active:=False cuando lleva 10 s sin actividad del driver, y solo lo reactiva en SSocketPDispClientRead, es decir, cuando el driver vuelve a enviar algo.
- **Impacto:** Despues de TERMINATE (por ejemplo en la secuencia HALT, TERMINATE, INITIALIZE, RUN) no se acepta ningun INITIALIZE ni RUN, OpenGas recibe timeout y luego pierde el puerto 1001, y los dispensarios quedan sin control hasta reiniciar PDISPENSARIOS o el Bridge. Solo la desconexion TCP reactiva Timer2 via ClientSocket1Disconnect.
- **Recomendación:** Quitar 'Timer2.Enabled:=False' de Terminar (dejar Timer2 encendido como hace LiberaInicializacion en la linea 2500). Opcionalmente responder de inmediato con Responder(GenerateText(rootJSON)). Validar la secuencia HALT, TERMINATE, INITIALIZE, RUN contra el Bridge comprobando que cada paso responde True.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BEN-03"></a>
#### BEN-03 · 🟠 Alta · protocolo · bug — PosCarga[].HoraOcc nunca se actualiza: TRANSACTION via Bridge siempre da 1899-12-30T00:00

- **Ubicación:** `UIGASBENNETT.pas` líneas 807, 842, 1129-1130, 1434, 1508, 2239-2262 (2256)
- **Se atiende en:** [E1.9](../PLAN_OPTIMIZACION.md#e19--coherencia-del-estado-publicado-estatus-fin-de-venta-horaocc-estado)
- **Verificación:** sin verificación independiente
- **Qué pasa:** AgregaPosCarga publica HoraOcc con TPosCarga.HoraOcc=0 (lineas 807 y 842) y no hay ningun ActualizaCampoJSON(...,'HoraOcc',...) en el archivo. El Bridge arma TRANSACTION con posObj.Field['HoraOcc'].Value (UIGASBRIDGE.pas 727). Antes del commit 0e02888 el driver contestaba TRANSACTION con TransaccionPosCarga, que usaba HoraFinv (linea 2256); al pasar esa respuesta al Bridge, el campo quedo sin alimentar.
- **Evidencia:** grep "'HoraOcc'": Bennett solo tiene la linea 842 (Add). Wayne (2018), Wayne2W (2804, 4447), Gilbarco (2697), Team (1760, 2669), PAM (1199), HongYang (1578) y Triton (804, 1275) si lo actualizan. HoraFinv se calcula en las lineas 1129-1130 y HoraOcc en OCC/OCL (lineas 1434 y 1508), pero ninguno de los dos llega al JSON.
- **Impacto:** Todas las transacciones Bennett llegan a OpenGas con fecha y hora 1899-12-30T00:00. Si OpenGas usa HoraOcc para fechar, deduplicar o distinguir ventas consecutivas, puede registrar ventas con fecha erronea o confundir dos ventas.
- **Recomendación:** Al entrar a estatus 7 (linea 1129) o al detectar el fin de venta en A/1 (swdesp), hacer ActualizaCampoJSON(xpos,'HoraOcc',FormatDateTime('yyyy-mm-dd',HoraFinv)+'T'+FormatDateTime('hh:nn',HoraFinv)), igual que hacia TransaccionPosCarga. Validar con TRANSACTION despues de una venta real.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BEN-04"></a>
#### BEN-04 · 🟠 Alta · robustez · bug — La perdida de comunicacion con la consola no se refleja: los estatus quedan congelados

- **Ubicación:** `UIGASBENNETT.pas` líneas 2101-2111 (2106), 1019-1029, 918-920, 1344-1390 (1369, 1390)
- **Se atiende en:** [E1.9](../PLAN_OPTIMIZACION.md#e19--coherencia-del-estado-publicado-estatus-fin-de-venta-horaocc-estado)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Cuando B00 hace timeout, Timer1Timer simula LineaTimer:=idStx+idStx+'B00'+idEtx+'.*' (linea 2106). ProcesaLinea solo recorta hasta el primer STX y copia desde la posicion 2 (lineas 1020-1022), asi que lin[1]=#2 y no entra al case 'B': TPosCarga[].estatus se queda igual. El mecanismo ContadorAlarma>10, que pone LinEstadoGen en ceros (lineas 919-920), se pierde porque ProcesaLinea sobrescribe LinEstadoGen:=xestado en la linea 1390. El JSON (Estatus, linea 1369) se sigue calculando con el estatus viejo y se envia en cada timeout (linea 1681).
- **Evidencia:** Timer1Timer, linea 2106: caso 'B' con STX duplicado. ProcesaLinea, lineas 1020-1029: case lin[1] sin rama para #2. Linea 1390: LinEstadoGen:=xestado sin condicion.
- **Impacto:** Con la consola o el cable caidos, OpenGas ve indefinidamente el ultimo estado (por ejemplo 'Cargando' o 'Inactivo') y puede autorizar o cobrar sobre una posicion que no responde. La deteccion de datos obsoletos del Bridge no se activa porque sigue llegando JSON.
- **Recomendación:** Llevar un contador de timeouts consecutivos de B00. Al llegar a N (configurable, por ejemplo 5), poner estatus:=0 en las posiciones registradas, publicar Estatus=0 y registrar la alarma en el log; al recibir un B valido, volver a la normalidad. Quitar el doble STX de la trama simulada (o manejar el timeout con una rama explicita) y eliminar ContadorAlarma/LinEstadoGen. Validar desconectando el cable con una venta en curso.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BEN-05"></a>
#### BEN-05 · 🟠 Alta · protocolo · bug — No se valida el BCC de las tramas recibidas y se ignoran ACK y NAK (sin reintento)

- **Ubicación:** `UIGASBENNETT.pas` líneas 946-984 (957-969), 1019-1029, 1177-1181, 1215-1219, 1251-1254, 2108, 1692-1737
- **Se atiende en:** [E2.8](../PLAN_OPTIMIZACION.md#e28--recepción-serial-robusta-tramas-bcc-acknak)
- **Verificación:** sin verificación independiente
- **Qué pasa:** pSerialTriggerAvail da la trama por terminada en el byte que sigue a ETX (el BCC), pero nunca lo verifica: CalculaBCC solo se usa al transmitir (linea 924). ProcesaLinea convierte digitos de volumen, importe, precio y totales sin validar. Las respuestas de un solo caracter ACK o NAK (lin=#6 o #21) no tienen rama en el case: solo liberan la linea y se pasa al siguiente comando de la cola. El NAK simulado en un timeout (linea 2108) tampoco produce reintento.
- **Evidencia:** Lineas 961-966: SwBcc y FinLinea sin comparar contra CalculaBCC. Case de las lineas 1029-1264: solo existen las ramas 'B', 'A', '1' y 'N'. EnviaPreset encola K, P, L y S de forma independiente (lineas 1708-1733).
- **Impacto:** Con ruido en la linea se aceptan digitos alterados como importe, volumen, precio o totales. En modo de 8 digitos la venta puede cerrarse con J inmediato (lineas 1228-1233) usando una lectura corrupta. Si la consola contesta NAK al P (preset) y despues acepta el S, la bomba queda autorizada sin preset o con el anterior. Los U (precios) rechazados se pierden en silencio.
- **Recomendación:** Validar el BCC (CalculaBCC sobre payload+ETX) y descartar o reintentar la trama invalida. Ante NAK, reintentar LinCmnd hasta N veces y, si falla un P/5, abortar el resto de la secuencia (quitar L y S de ListaCmnd) y marcar el OCC con error. Registrar en el log. Probar con un puerto virtual que corrompa bytes.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="BEN-06"></a>
#### BEN-06 · 🟠 Alta · correccion · bug — Un preset pendiente no caduca y se vuelve a aplicar cuando regresa la comunicacion

- **Ubicación:** `UIGASBENNETT.pas` líneas 1398-1400, 1417-1430, 1431-1466, 1491-1504, 1505-1556, 1765-1777 (1772)
- **Se atiende en:** [E1.3](../PLAN_OPTIMIZACION.md#e13--presets-montos-decimales-y-validaciones)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Despues del primer EnviaPreset quedan SwOCC=true y SwCmndB=false. Si no llega una respuesta 'B' valida (SwCmndB:=true solo en la linea 1047), la rama 'else SwAplicaCmnd:=false' (lineas 1429 y 1503) deja el comando pendiente sin limite. La unica caducidad (mas de tmMinuto) se revisa en EjecutaComando, y solo al buscar un slot libre (linea 1772). NumPaso=4 procesa cualquier TabCmnd activo y sin respuesta sin revisar 'hora'.
- **Evidencia:** Cuando vuelve la consola se cumple SwOCC, SwCmndB, estatus in [1,3] y ContOCC>0, asi que se hace SwOCC:=false (lineas 1419-1421) y la condicion de la linea 1431 reenvia K, P, L y S con el SnImporte del comando original (lineas 1444-1463).
- **Impacto:** Un prepago de hace varios minutos se aplica en cuanto la comunicacion se recupera. El siguiente cliente que levante la pistola despacha con el pago del anterior, o la venta se cobra dos veces.
- **Recomendación:** En NumPaso=4, responder con error y desactivar los OCC/OCL cuyo (Now-hora) pase de un limite configurable (por ejemplo 30-60 s) o que lleven SwOCC activo demasiado tiempo. Limpiar SwOCC y ContOCC de la posicion y registrar el evento. Validar desconectando la consola despues del primer envio del preset y reconectandola 2 minutos despues.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BEN-07"></a>
#### BEN-07 · 🟠 Alta · correccion · bug — Precios no programados: PRICES se ignora si aun no hubo respuesta B y los precios de INITIALIZE nunca se envian

- **Ubicación:** `UIGASBENNETT.pas` líneas 727-759 (734, 738-741), 1035-1039, 2457-2459, 2494, 2584-2608
- **Se atiende en:** [E1.6](../PLAN_OPTIMIZACION.md#e16--precios-aplicar-solo-lo-confirmado)
- **Verificación:** sin verificación independiente
- **Qué pasa:** IniciaPrecios itera hasta MaxPosCargaActiva (linea 734). LiberaInicializacion pone esa variable en 0 (linea 2494) y solo se recalcula al procesar una respuesta 'B' (linea 1035). Un PRICES que llega despues de INITIALIZE o RUN y antes de la primera respuesta B contesta 'True|' sin mandar ningun U. Inicializar guarda Products[].Price en LPrecios (linea 2457) pero pone PreciosInicio:=False (linea 2459) y nada lo pone en True, asi que IniciarPrecios (lineas 1038-1039 y 2584-2608) nunca se ejecuta. Ademas, si un precio es invalido se sale con Exit (lineas 738-741) cuando ya se mandaron U a las posiciones anteriores.
- **Evidencia:** grep PreciosInicio: solo hay asignaciones a False (lineas 2459 y 2607). PRICES es fire-and-forget en el Bridge (UIGASBRIDGE.pas 377-387), asi que OpenGas siempre recibe True.
- **Impacto:** Tras un reinicio o una reinicializacion los dispensarios pueden seguir con el precio viejo mientras OpenGas cree aplicado el nuevo: cobro a un precio distinto del oficial. Una actualizacion parcial deja precios diferentes para el mismo producto entre posiciones.
- **Recomendación:** Guardar el ultimo PRICES en LPrecios y marcar PreciosInicio:=True (tambien al final de Inicializar) para que se aplique en la primera respuesta B. Validar todos los precios antes de enviar cualquiera. Iterar sobre las posiciones registradas, no sobre MaxPosCargaActiva. Confirmar el ACK de cada U. Probar INITIALIZE, PRICES y RUN con la consola encendida tarde.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BEN-08"></a>
#### BEN-08 · 🟠 Alta · memoria_recursos · bug — Escrituras fuera de rango en LPrecios[1..4] y en TComb/TPos/TMang[1..MCxP]

- **Ubicación:** `UIGASBENNETT.pas` líneas 221, 2451-2458 (2457), 744, 858-864, 149-153
- **Se atiende en:** [E1.8](../PLAN_OPTIMIZACION.md#e18--índices-fuera-de-rango-y-carga-de-posiciones-r-)
- **Verificación:** sin verificación independiente
- **Qué pasa:** LPrecios es array[1..4] of Double (linea 221). Inicializar escribe LPrecios[productID] con el ProductId del JSON sin validar (lineas 2452-2457), e IniciaPrecios escribe LPrecios[TComb[i]] (linea 744) sin el filtro 'TComb[i] in [1..4]' que si tiene IniciarPrecios (linea 2592). AgregaPosCarga hace inc(NoComb) y escribe TComb[NoComb] sin tope MCxP=4 (lineas 862-864). Delphi 7 compila sin {$R+} por defecto, asi que no hay excepcion: se escribe sobre memoria ajena.
- **Evidencia:** Linea 2457: 'LPrecios[productID]:=productos.Child[i].Field['Price'].Value;' sin validar el rango. Lineas 862-864: 'inc(NoComb); TComb[NoComb]:=...'.
- **Impacto:** Un ProductId 0 o mayor o igual a 5 corrompe las globales contiguas (AvanceBar, SwAplicaCmnd, PreciosInicio, ContDA y punteros de string como LinEstado, LinEstadoGen o Token), con AV posteriores dificiles de diagnosticar. Mas de 4 productos por posicion corrompen el registro tiposcarga siguiente.
- **Recomendación:** Validar ProductId in [1..4] (o usar una estructura indexada por ProductId) y NoComb<MCxP, devolviendo 'False|ProductId fuera de rango|' en INITIALIZE y PRICES. Activar {$R+} en compilaciones de prueba. Probar INITIALIZE con ProductId=5 y con 5 mangueras.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BEN-09"></a>
#### BEN-09 · 🟠 Alta · protocolo · riesgo — OpenGas nunca recibe el resultado real de AUTHORIZE, PRICES ni PAYMENT

- **Ubicación:** `UIGASBENNETT.pas` líneas 2038-2081 (2076), 727-759, 2224-2237, 1423, 1465, 1520-1526, 1699, 1704
- **Módulos afectados:** UIGASBENNETT, UIGASBRIDGE, todos los drivers con Bridge
- **Se atiende en:** [E5.2](../PLAN_OPTIMIZACION.md#e52--confirmación-real-de-prices-authorize-y-payment)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El Bridge contesta de inmediato 'DISPENSERS|AUTHORIZE|True|0|' (y lo mismo para PRICES y PAYMENT) con CliSock=nil, y descarta el Resultado que manda el driver. AutorizarVenta devuelve el folio interno de TabCmnd ('True|'+IntToStr(EjecutaComando(...))), que nunca llega a OpenGas, asi que no hay forma de consultarlo con RESPCMND.
- **Evidencia:** Bridge AddPeticion (UIGASBRIDGE.pas 377-391). Errores del driver que no llegan a OpenGas: 'Error al aplicar PRESET' (linea 1423), 'Combustible no existe en esta posicion' (linea 1465), 'Solo se permiten valores enteros' para litros con decimales (ValidaCifra(SnLitros,4,0), linea 1520), 'Posicion no Disponible' y 'Posicion Bloqueada' (lineas 1699 y 1704), 'El precio X es incorrecto' (linea 739) y 'Posicion aun no esta en fin de venta' (linea 1584).
- **Impacto:** Prepagos rechazados o no aplicados se reportan como exitosos: el cliente paga y la bomba no se autoriza, o se autoriza otro producto, sin que el POS lo sepa. Lo mismo pasa con precios no aplicados.
- **Recomendación:** Acordar un cambio de contrato: que el Bridge espere la respuesta del driver para AUTHORIZE y PAYMENT (y devuelva el folio de comando), o que el driver publique en PosCarga el ultimo resultado de preset (por ejemplo PresetFolio y PresetResultado). Mientras tanto, registrar estos rechazos como alarma en el log y admitir litros con decimales si la consola los soporta. Desplegar Bridge y driver juntos.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** sí

<a id="BEN-10"></a>
#### BEN-10 · 🟠 Alta · robustez · riesgo — El sondeo serial se detiene cuando falla el Bridge (watchdog de 2 s)

- **Ubicación:** `UIGASBENNETT.pas` líneas 2086-2096, 311-318, 424-431, 602-605, 613, 1684-1686
- **Módulos afectados:** UIGASBENNETT, UIGASWAYNE2W
- **Se atiende en:** [E2.1](../PLAN_OPTIMIZACION.md#e21--desacoplar-timer1-sondeo-serial-de-la-conexión-con-el-bridge)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Timer1Timer cierra el socket y apaga Timer1 si pasan 2 s sin respuesta del Bridge (lineas 2086-2095). ClientSocket1Disconnect, el except de Responder y el except del envio en ProcesaLinea hacen lo mismo. Solo Timer2Timer vuelve a encender Timer1, despues de reconectar y enviar con estado>0 (lineas 602-605).
- **Evidencia:** horaAct solo se actualiza en OnConnect y OnRead (lineas 308 y 328). Si el Bridge tarda mas de 2 s (por ejemplo en GuardaLogOG o GuardaLogPDisp de un TRACE, con listas de 10000 JSON) o se reinicia, el driver deja de sondear la consola.
- **Impacto:** Durante una caida, un reinicio o un bloqueo del Bridge no se manda J de fin de venta (las bombas en estado 7 no se liberan hasta reconectar), no se aplican presets pendientes y no se leen importes finales. Ademas pueden aparecer ciclos de reconexion cada vez que el Bridge guarda logs.
- **Recomendación:** Separar el sondeo de la conexion: con estado=1, mantener Timer1 activo aunque el socket este caido y solo omitir Responder. Dejar que el watchdog solo dispare la reconexion. Subir el umbral a 5-10 s, alineado con TimeoutDatosObsoletos. Probar reiniciando el Bridge con una venta en curso.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="BEN-11"></a>
#### BEN-11 · 🟡 Media · rendimiento · optimizacion — El JSON completo se regenera y envia en cada trama serial

- **Ubicación:** `UIGASBENNETT.pas` líneas 1678-1689, 1007-1009, 598-600, 347-348
- **Se atiende en:** [E4.1](../PLAN_OPTIMIZACION.md#e41--responder-al-bridge-en-cuanto-se-procesa-un-comando-y-homologar-la-cadencia)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El finally de ProcesaLinea hace Responder(TlkJSON.GenerateText(rootJSON)) siempre que haya conexion (lineas 1680-1681), es decir, por cada respuesta de la consola y por cada timeout simulado. xTurnoSocket se incrementa (lineas 1007-1009) pero ya no se usa, porque el filtro 'xTurnoSocket=3' se quito en el commit 0e02888. Wayne2W y Gilbarco envian 1 de cada 3 turnos y Team cada MsEnvioJSON ms.
- **Evidencia:** git show 0e02888: '-if (conectado) and (xTurnoSocket=3) then' / '+if (conectado) then'. Cada envio genera una respuesta NOTHING del Bridge, que agrega {Folio:0} a Peticiones (lineas 347-348).
- **Impacto:** Entre 5 y 20 mensajes JSON por segundo (5-10 KB cada uno con 16-32 posiciones), CPU gastado en GenerateText y en los logs de driver y Bridge, y una ventana de concurrencia mas amplia, todo para ganar menos de 200 ms de frescura.
- **Recomendación:** Enviar como maximo cada N ms (configurable, por ejemplo 250-500 ms) o cuando haya cambios (bandera dirty), y siempre de inmediato si hay un resultado nuevo en Peticiones. Validar la latencia de STATUS y TRANSACTION y la tasa de mensajes en LogPDisp.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BEN-12"></a>
#### BEN-12 · 🟡 Media · rendimiento · optimizacion — Logs costosos: concatenacion caracter por caracter, Delete(0) O(n) y 10000 JSON completos en memoria

- **Ubicación:** `UIGASBENNETT.pas` líneas 617-635, 637-655, 419, 331, 972, 927
- **Se atiende en:** [E2.4](../PLAN_OPTIMIZACION.md#e24--bitácoras-que-no-bloquean-append-incremental-rotación-y-sin-json-repetido)
- **Verificación:** sin verificación independiente
- **Qué pasa:** AgregaLog y AgregaLogPetRes recorren cada caracter y hacen lin2:=lin2+lin[i] (lineas 622-631 y 642-651). Con el JSON de cada envio (linea 419) eso son miles de realocaciones por mensaje. 'while Count>10000 do Delete(0)' mueve unos 40 KB de punteros en cada linea agregada. ListaLogPetRes guarda 10000 entradas 'E <JSON>'.
- **Evidencia:** Lineas 642-654. Con 16-32 posiciones, cada JSON mide 5-10 KB, asi que ListaLogPetRes ocupa 50-100 MB en memoria y cada SaveToFile escribe ese tamano.
- **Impacto:** CPU y latencia en el hilo que atiende la serial, fragmentacion de memoria y archivos de log enormes.
- **Recomendación:** Escapar solo cuando haya caracteres menores a #32 (con un buffer prealocado con SetLength, o con StringReplace). Usar un buffer circular de tamano fijo en lugar de Delete(0). Registrar el JSON solo cuando cambie, o truncado, segun un nivel de detalle configurable.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BEN-13"></a>
#### BEN-13 · 🟡 Media · rendimiento · optimizacion — ActualizaCampoJSON busca linealmente por nombre en cada actualizacion

- **Ubicación:** `UIGASBENNETT.pas` líneas 473-518, 1199-1201, 1235-1237, 1369-1376, 520-561
- **Se atiende en:** [E4.2](../PLAN_OPTIMIZACION.md#e42--json-más-barato-generar-menos-redondear-y-buscar-menos)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Por cada posicion y cada trama se llama ActualizaCampoJSON 3 veces (Estatus, Combustible, Manguera) y otras 3 en A/1 (Volumen, Importe, Precio). Cada llamada recorre PosCarga desde 0 comparando posObj.Field['DispenserId'] (busqueda por WideString y comparacion Variant), lo que da O(N^2) por trama. Los campos se escriben aunque el valor no haya cambiado.
- **Evidencia:** Lineas 489-511 (bucle) y 1369-1376 (llamadas por posicion dentro del bucle de la linea 1345).
- **Impacto:** Con 32 posiciones son miles de busquedas y asignaciones de WideString por trama, a 5-20 tramas por segundo.
- **Recomendación:** En AgregaPosCarga, guardar en TPosCarga[xpos] las referencias a posObj y a sus nodos (Estatus, Importe, etc.) y asignar directo, solo cuando el valor cambie.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BEN-14"></a>
#### BEN-14 · 🟡 Media · correccion · bug — La reautorizacion en estado 3 se descarta porque el estatus se enmascara antes de EnviaPreset

- **Ubicación:** `UIGASBENNETT.pas` líneas 1105-1116 (1112-1114), 1698-1701
- **Se atiende en:** [E1.3](../PLAN_OPTIMIZACION.md#e13--presets-montos-decimales-y-validaciones)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Si estatusant=4 y PresetImpo>=0.01, se incrementa PresetImpoN y, mientras sea <=3, se asigna estatus:=estatusant (4) ANTES de llamar EnviaPreset (lineas 1111-1114). EnviaPreset rechaza con 'Posicion no Disponible' si el estatus no esta en [1..3] (lineas 1698-1701). Resultado: los tres primeros 'reintentos' no mandan nada, el rsp se ignora, y solo en el cuarto ciclo se reenvia K/P/L/S.
- **Evidencia:** Linea 1113: 'estatus:=estatusant;'. Linea 1114: 'EnviaPreset(rsp,PresetComb);'. Linea 1698: 'if not (TPosCarga[xpos].estatus in [1..3]) then ... exit'.
- **Impacto:** La logica de reintento no funciona y confunde. Ademas el driver reautoriza solo un prepago al pasar de 4 a 3 sin confirmar que sigue siendo el mismo cliente.
- **Recomendación:** Definir el comportamiento esperado (debounce de N ciclos o reintento inmediato), separar el estatus que se publica del que se usa para decidir, y registrar cada reautorizacion en el log. Probar levantando y colgando la pistola despues de un preset.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="BEN-15"></a>
#### BEN-15 · 🟡 Media · correccion · bug — FULLSERVICE no activa el modo 'Normal' y aun asi responde True; ramas 'Normal' muertas

- **Ubicación:** `UIGASBENNETT.pas` líneas 2199-2222 (2212, 2215), 1156-1164, 1606-1611, 1721
- **Se atiende en:** [E5.4](../PLAN_OPTIMIZACION.md#e54--comandos-homogéneos-entre-marcas)
- **Verificación:** sin verificación independiente
- **Qué pasa:** DesactivaModoPrepago asigna 'Prepago', igual que ActivaModoPrepago. Las ramas que dependen de ModoOpera='Normal' (autorizacion automatica en las lineas 1156-1163 y P9999 en DVC, lineas 1606-1611) nunca se ejecutan. Wayne tiene el mismo codigo (2366-2390); parece una decision de negocio no documentada. Relacionado: en EnviaPreset la condicion SnImporte<>9999 (linea 1721) nunca es falsa porque OCL usa 9999.99 o 999999.99 (lineas 1546-1548), asi que el caracter de seleccion de producto se manda tambien en presets por litros.
- **Evidencia:** Lineas 2212 y 2215: "TPosCarga[xpos].ModoOpera:='Prepago';" dentro de DesactivaModoPrepago.
- **Impacto:** OpenGas cree que la posicion paso a servicio completo, pero la bomba nunca se autoriza sola y el despachador no puede surtir sin prepago.
- **Recomendación:** Si es intencional, responder 'False|Servicio completo no soportado|' y eliminar las ramas muertas. Si no, asignar 'Normal'. Corregir la comparacion de la linea 1721 (usar una bandera de preset por litros). Probar FULLSERVICE levantando la pistola.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="BEN-16"></a>
#### BEN-16 · 🟡 Media · correccion · riesgo — El volumen y el importe que se publican se reescriben por calculo, no son los medidos

- **Ubicación:** `UIGASBENNETT.pas` líneas 1183-1193, 1220-1222
- **Se atiende en:** [E1.2](../PLAN_OPTIMIZACION.md#e12--importes-y-volúmenes-de-venta-mal-calculados)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Despues de leer de la consola, si |volumen*precio - importe| es mayor o igual a 900, el driver reemplaza importe:=AjustaFloat(volumen*precio,2) (lineas 1184-1188). Luego calcula xvol:=AjustaFloat(importe/precio,3) y, si |volumen-xvol| es menor a 0.05, reemplaza el volumen medido por xvol (lineas 1191-1193 y 1220-1222).
- **Evidencia:** Linea 1193 (y 1222): 'if abs(volumen-xvol)<0.05 then volumen:=xvol;'.
- **Impacto:** El volumen reportado no es el que midio el dispensario: se inventa un tercer decimal y puede diferir hasta 0.05 L, lo cual es riesgo para controles volumetricos y metrologia (CENAM). El importe recalculado arriba de $10000 puede diferir algunos centavos de lo que cobro la bomba.
- **Recomendación:** Publicar el volumen medido tal cual. Si hace falta corregir el desbordamiento de 6 digitos, aplicarlo solo al importe, registrarlo en el log y preferir el modo de 8 digitos. Validar con ventas por importe a varios precios comparando contra el display.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="BEN-17"></a>
#### BEN-17 · 🟡 Media · correccion · bug — Manguera y Combustible del JSON no corresponden a la lectura de importe y volumen

- **Ubicación:** `UIGASBENNETT.pas` líneas 1048-1050, 1371-1376, 1751-1763
- **Se atiende en:** [E1.2](../PLAN_OPTIMIZACION.md#e12--importes-y-volúmenes-de-venta-mal-calculados)
- **Verificación:** sin verificación independiente
- **Qué pasa:** PosActual se toma de cada B00, y si viene 0 se fuerza a 1 (lineas 1048-1050). CombActual y MangActual se recalculan y publican en cada trama (lineas 1371-1376), pero Volumen, Importe y Precio solo cambian con las lecturas A/1. El Bridge arma TRANSACTION con los cuatro campos (UIGASBRIDGE.pas 727-728).
- **Evidencia:** Linea 1371: 'xcomb:=CombustibleEnPosicion(xpos,PosActual)' para todas las posiciones registradas en cada ProcesaLinea, sin importar el estatus.
- **Impacto:** Si al colgar la pistola, o al levantar otra manguera, la consola reporta otra manguera (o 0, que se convierte en 1), TRANSACTION puede reportar el producto y la manguera equivocados con el importe de la venta anterior.
- **Recomendación:** Fijar CombActual y MangActual cuando la posicion esta en 5, 7 u 8 (o en la lectura A con estatus>=5) y no sobrescribirlos hasta que inicie otra venta. No forzar 0 a 1. Probar una venta en la manguera 2 y leer TRANSACTION despues de colgar.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="BEN-18"></a>
#### BEN-18 · 🟡 Media · correccion · bug — TOTAL: importes calculados con el precio actual, indices sin validar, rama artificial y respuesta truncada

- **Ubicación:** `UIGASBENNETT.pas` líneas 1629-1663 (1646-1648, 1652-1657), 193, 790-791
- **Se atiende en:** [E1.7](../PLAN_OPTIMIZACION.md#e17--totales-confiables)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Los 'totales en pesos' se calculan como TotalLitros[k]*LPrecios[TComb[k]], es decir con el precio actual, no con un totalizador monetario. Solo se reportan 3 mangueras aunque MCxP=4. Con NoComb<3, TComb[2..3] quedan en 0 o con valores de un INITIALIZE anterior (AgregaPosCarga no los limpia), y LPrecios[0] se lee fuera de rango. La rama estatus=9 suma el volumen a TotalLitros[MangActual], que es un indice de manguera y no de producto, y MangActual puede valer 0. RegCmnd.Respuesta es string[80] (linea 193): con totalizadores de 7 digitos la cadena pasa de 80 caracteres y se trunca sin aviso.
- **Evidencia:** Lineas 1646-1648: 'OK'+FormatFloat('0.000',ToTalLitros[1])+'|'+FormatoMoneda(ToTalLitros[1]*LPrecios[TComb[1]])... Linea 1653: 'TotalLitros[MangActual]:=TotalLitros[MangActual]+volumen'.
- **Impacto:** Importes de totalizador incorrectos despues de cada cambio de precio, litros alterados artificialmente y el ultimo total truncado en los cortes.
- **Recomendación:** Reportar los litros reales (y el totalizador monetario si la consola lo da), iterar 1..NoComb, validar TComb in [1..4], quitar la suma artificial de la rama estatus 9 y ampliar Respuesta a string largo. Si cambia el numero de campos de RESPCMND, coordinarlo con OpenGas.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** sí

<a id="BEN-19"></a>
#### BEN-19 · 🟡 Media · robustez · bug — El parseo de la respuesta 'N' no esta protegido y la excepcion sale de pSerialTriggerAvail

- **Ubicación:** `UIGASBENNETT.pas` líneas 1243-1263 (1251-1254), 1006/1678, 946-984, 531-561 (539)
- **Se atiende en:** [E2.8](../PLAN_OPTIMIZACION.md#e28--recepción-serial-robusta-tramas-bcc-acknak)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Totlts[k]:=StrToFloat(copy(lin,...,10))/1000 no tiene try (lineas 1251-1254). lin incluye el ETX final, asi que una respuesta con menos de 4 totalizadores, o con un byte corrupto, provoca EConvertError. ProcesaLinea solo tiene try/finally y pSerialTriggerAvail tampoco captura (finally en las lineas 981-983). ApplyTotalLitrosToJSON no revisa nil en Field['DispenserId'] (linea 539).
- **Evidencia:** Las ramas 'A' y '1' si tienen try/except (lineas 1175 y 1213); la rama 'N' no.
- **Impacto:** Los totales no se actualizan: TOTAL nunca responde y se reenvia N cada 10 s. En esa vuelta tampoco se despacha la cola de comandos. La excepcion llega al despachador de Async Pro; su efecto depende de la version y, en el peor caso, detiene los eventos del puerto.
- **Recomendación:** Validar longitud minima y que sean digitos (StrToFloatDef), envolver el parseo en try/except con log, y agregar un try/except general con log en pSerialTriggerAvail y en Timer1Timer.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BEN-20"></a>
#### BEN-20 · 🟡 Media · protocolo · bug — El armado de tramas serial es fragil: quedan restos, se desincroniza y las respuestas tardias se atribuyen mal

- **Ubicación:** `UIGASBENNETT.pas` líneas 910-934 (923), 946-984, 1017, 2101-2111
- **Se atiende en:** [E2.8](../PLAN_OPTIMIZACION.md#e28--recepción-serial-robusta-tramas-bcc-acknak)
- **Verificación:** sin verificación independiente
- **Qué pasa:** ComandoConsola limpia LineaBuff (linea 923) pero no Linea, SwBcc ni FinLinea. Un fragmento de un comando que hizo timeout queda como prefijo de la siguiente respuesta. Si el fragmento termino en ETX (SwBcc=true), el STX de la siguiente trama se toma como BCC. Los bytes que siguen a FinLinea se quedan en LineaBuff y se procesan hasta el siguiente evento, o se pierden en el siguiente ComandoConsola. Cualquier respuesta, aunque sea tardia, se toma como la del comando actual (linea 1017: SwEsperaRsp:=false).
- **Evidencia:** Linea 923: "LineaBuff:='';" sin limpiar Linea ni SwBcc. Lineas 957-969: el bucle se detiene en el primer FinLinea.
- **Impacto:** Tramas 'B' mezcladas con datos de 'A' producen estatus falsos por un ciclo (por ejemplo un 7 o un 3 que disparan J o un re-preset) y las respuestas quedan fuera de secuencia despues de un timeout.
- **Recomendación:** En ComandoConsola reiniciar Linea, SwBcc y FinLinea. Procesar en bucle todas las tramas completas que haya en LineaBuff. Descartar la respuesta si su tipo no corresponde a CharCmnd. Combinarlo con la validacion de BCC.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="BEN-21"></a>
#### BEN-21 · 🟡 Media · protocolo · riesgo — El socket no delimita mensajes y SendText no verifica si el envio fue parcial

- **Ubicación:** `UIGASBENNETT.pas` líneas 329-342, 409-436 (413, 417)
- **Módulos afectados:** UIGASBENNETT, UIGASBRIDGE, todos los drivers con Bridge
- **Se atiende en:** [E6.1](../PLAN_OPTIMIZACION.md#e61--framing-y-buffer-por-conexión-en-los-dos-sentidos-y-del-lado-de-opengas)
- **Verificación:** sin verificación independiente
- **Qué pasa:** ClientSocket1Read toma todo lo que devuelve ReceiveText como un unico 'folio|DISPENSERS|CMD|params'. Dos respuestas del Bridge que lleguen juntas se interpretan como una sola, con parametros contaminados; por ejemplo el finv de AUTHORIZE se pega con el '0' del NOTHING siguiente. Una respuesta fragmentada (un INITIALIZE grande) se procesa como dos mensajes. En modo ctNonBlocking SendText puede enviar solo una parte y el valor de retorno no se revisa. El Bridge tampoco delimita.
- **Evidencia:** Linea 329: 'mensaje:=Socket.ReceiveText;' y parseo con ExtraeElemStrSep por '|' sin buscar ningun terminador. Lineas 413 y 417: el resultado de SendText se ignora.
- **Impacto:** Comandos perdidos (el Bridge da timeout) o con parametros alterados, INITIALIZE con JSON truncado, y JSON truncado hacia el Bridge con resultados perdidos. La probabilidad es baja en loopback, pero crece con el tamano del JSON (LOG/LOGREQ) y cuando los hilos estan ocupados.
- **Recomendación:** Definir en los dos lados un terminador (#3 o CRLF) o un prefijo de longitud, acumular en buffer hasta tener el mensaje completo, y revisar el retorno de SendText (o usar SendStream con buffer de salida). Desplegar Bridge y driver al mismo tiempo.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** sí

<a id="BEN-22"></a>
#### BEN-22 · 🟡 Media · rendimiento · optimizacion — Esperas bloqueantes dentro de ProcesaLinea y Timer2Timer

- **Ubicación:** `UIGASBENNETT.pas` líneas 1440, 1514, 1543, 1394-1397, 2599, 2603, 588-593
- **Se atiende en:** [E2.5](../PLAN_OPTIMIZACION.md#e25--reentrancia-comandos-del-bridge-durante-una-transacción-serial)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Hay esperamiliseg(500) en cada reintento de OCC y OCL (lineas 1440 y 1514) y EsperaMiliSeg(300) despues de F en OCL (linea 1543). Las de swcierrabd (linea 1395) e IniciarPrecios (100 ms por comando) estan en codigo muerto. Timer2Timer usa Sleep(500) mas hasta 101 Sleep(10) en el hilo principal (lineas 588-593). EsperaMiliSeg viene de ULIBGRAL y no esta en el repo: si usa Sleep bloquea el hilo; si usa Application.ProcessMessages, permite que Timer1Timer o pSerialTriggerAvail reentren en ProcesaLinea.
- **Evidencia:** Lineas 1438-1441: 'dec(TPosCarga[SnPosCarga].ContOCC); esperamiliseg(500);' dentro del recorrido de TabCmnd en NumPaso=4.
- **Impacto:** Hasta unos 3 s de bloqueo por un preset con 5 reintentos. Se retrasan las lecturas de las demas posiciones y, si hay reentrada, se corrompen NumPaso y LineaTimer.
- **Recomendación:** Reemplazar las esperas por una marca de tiempo 'no antes de' por posicion que se revise en cada ciclo. En Timer2, reconectar sin Sleep: Active:=True y revisar conectado en el siguiente tick. Confirmar como esta implementado EsperaMiliSeg.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="BEN-23"></a>
#### BEN-23 · 🟡 Media · rendimiento · bug — Precedencia en la condicion de sondeo: las posiciones en error o que no responden se consultan en cada ciclo

- **Ubicación:** `UIGASBENNETT.pas` líneas 1281, 1176, 1214, 2101-2111
- **Se atiende en:** [E4.3](../PLAN_OPTIMIZACION.md#e43--ciclo-serial-eficiente)
- **Verificación:** sin verificación independiente
- **Qué pasa:** La condicion es '(estatus<>9)and(estatus<>estatusant)or(estatus>=5)or(SwA)or(swinicio2)or(swcargando)'. Como and tiene mayor precedencia que or, estatus=9 (que cumple >=5) se consulta siempre y la guarda contra 9 no sirve. swinicio2 solo se limpia al parsear una respuesta A/1 valida (lineas 1176 y 1214), asi que una posicion que nunca contesta A se consulta en cada ciclo, y cada consulta espera el timeout de unos 750 ms.
- **Evidencia:** Linea 1281 (condicion completa), MaxEsperaRsp=4 (linea 203) y el timeout en las lineas 2102-2110.
- **Impacto:** Cada posicion muda o en error alarga unos 0.75 s el ciclo de todas las demas: sube la latencia de estatus, de presets (NumPaso=4 corre una vez por ciclo) y de fin de venta.
- **Recomendación:** Poner parentesis explicitos segun la intencion. Aplicar backoff a las posiciones que no responden y limpiar swinicio2 despues de N fallos.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BEN-24"></a>
#### BEN-24 · 🟡 Media · concurrencia · riesgo — Timer2 arranca habilitado desde el .dfm y el hilo dueno del socket depende de una carrera al iniciar

- **Ubicación:** `UIGASBENNETT.dfm` líneas 33-38 (dfm); pas 256-289, 575-594
- **Se atiende en:** [E2.3](../PLAN_OPTIMIZACION.md#e23--arranque-y-paro-ordenados-del-servicio)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Timer2 no declara Enabled=False, asi que arranca habilitado con Interval=200. Su primer tick puede llegar antes de que ServiceExecute asigne Host y Port (lineas 264-265) y cree ListaLog, ListaLogPetRes y rootJSON (lineas 283-287). En ese caso Timer2Timer hace ClientSocket1.Active:=True desde el hilo principal con Port=0, lo que lanza ESocketError, y el except llama AgregaLog con ListaLog=nil (AV). Ademas el HWND del socket queda en el hilo principal y cambia el modelo de hilos: el bucle de espera de las lineas 590-593 nunca ve conectado y se pierde un tick.
- **Evidencia:** En el dfm, Timer2 solo declara Interval = 200 y OnTimer. En ServiceExecute, ClientSocket1.Active:=True (linea 276) se ejecuta antes de crear las listas (lineas 283-285).
- **Impacto:** El arranque no es determinista (sobre todo cuando el equipo arranca con carga), puede haber excepciones al iniciar y el modelo de concurrencia cambia segun que hilo gane.
- **Recomendación:** Poner Enabled=False a Timer2 en el .dfm y encenderlo al final de ServiceExecute, despues de crear listas y rootJSON y de configurar Host y Port. Elegir de forma explicita el hilo que activa el socket.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BEN-25"></a>
#### BEN-25 · 🟡 Media · observabilidad · riesgo — ClientSocket1 no tiene OnError: los errores de conexion van al Visor de eventos y no al log

- **Ubicación:** `UIGASBENNETT.dfm` líneas 23-32 (dfm); pas 304-318, 575-615
- **Se atiende en:** [E2.2](../PLAN_OPTIMIZACION.md#e22--reconexión-no-bloqueante-y-con-manejo-de-errores)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El .dfm solo asigna OnConnect, OnDisconnect y OnRead. Con el Bridge caido, cada intento de Timer2 (aproximadamente cada 1.7 s) produce un error asincrono de conexion. ScktComp lanza ESocketError dentro del WndProc del socket y la excepcion termina en Application.HandleException (que en SvcMgr la registra en el Visor de eventos), sin pasar por LogDisp.
- **Evidencia:** En el dfm, ClientSocket1 no tiene OnError; ningun driver lo define (grep).
- **Impacto:** El log de eventos de Windows se inunda (decenas de miles de entradas al dia) y LogDisp no deja rastro de por que se cayo la conexion.
- **Recomendación:** Agregar un OnError que registre con AgregaLog, ponga ErrorCode:=0 y marque conectado:=False.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BEN-26"></a>
#### BEN-26 · 🟡 Media · memoria_recursos · bug — LOG y LOGREQ no limitan el tamano y el resultado puede contener 'PING'

- **Ubicación:** `UIGASBENNETT.pas` líneas 1986-2036 (2001-2007, 2027-2033), 392-394
- **Se atiende en:** [E4.4](../PLAN_OPTIMIZACION.md#e44--log-y-logreq-acotados)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El numero de registros r viene de OpenGas sin tope. res:=res+ListaLog[i]+'|' concatena hasta 10000 lineas; las de ListaLogPetRes incluyen JSON completos, asi que pueden ser decenas de MB. El resultado se queda en Peticiones, se reenvia en cada trama (hasta 2 veces) y se registra caracter por caracter. El Bridge trata como PING cualquier mensaje que contenga 'PING' (AnsiContainsText, UIGASBRIDGE.pas 756), y el log de peticiones tiene lineas 'E PING' del arranque. Detalle menor: ObtenerLog devuelve r+1 lineas (lineas 2001-2002).
- **Evidencia:** Lineas 2006-2007: 'for i:=i to ListaLog.Count-1 do res:=res+ListaLog[i]+'|';' sin limite de tamano.
- **Impacto:** Picos de memoria y CPU, posible EOutOfMemory, SendText parcial y fragmentacion en el Bridge (cada fragmento provoca una respuesta). La respuesta se pierde y OpenGas recibe timeout.
- **Recomendación:** Limitar r (por ejemplo a 200) y el tamano total (por ejemplo 64 KB), o guardar el log a archivo y devolver la ruta. En el Bridge, comparar respTxt='PING' de forma exacta.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BEN-27"></a>
#### BEN-27 · 🟡 Media · observabilidad · riesgo — GuardarLog en cada excepcion y de forma periodica, sin rotacion, y en el hilo serial

- **Ubicación:** `UIGASBENNETT.pas` líneas 1958-1971, 1011-1014, 262, 296-299, 404, 422-423, 467-468, 514-515, 609, 2610-2628
- **Se atiende en:** [E2.4](../PLAN_OPTIMIZACION.md#e24--bitácoras-que-no-bloquean-append-incremental-rotación-y-sin-json-repetido)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Cada GuardarLog vuelca completas tres listas a tres archivos nuevos con timestamp (LogDisp, LogDispPetRes, LogDispComandos). Se llama desde los except de ClientSocket1Read, Responder, AddPeticionJSON, ActualizaCampoJSON y Timer2Timer, cada MinutosLog dentro de ProcesaLinea, y en cada TRACE, incluido el auto-kick del Bridge cada 3 s mientras haya datos obsoletos. No hay rotacion ni borrado. RutaLog vale por defecto 'C:\ImagenCo', distinto del Bridge ('C:\OpenGas\Logs'). Si la carpeta no existe, SaveToFile falla y con folio=0 el error se traga.
- **Evidencia:** Lineas 1962-1964: SaveToFile y GuardarLogPetRes/GuardaLogComandos. Lineas 1011-1014: guardado periodico dentro de ProcesaLinea.
- **Impacto:** Se llena el disco, el hilo que atiende la serial se bloquea segundos (lo que dispara el watchdog de 2 s) y los logs pueden faltar sin aviso.
- **Recomendación:** Escribir en modo append e incremental con rotacion por tamano o fecha y borrado de archivos viejos. En los except de rutas calientes solo agregar una linea, no volcar. Limitar la frecuencia de TRACE. Crear RutaLog con ForceDirectories.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BEN-28"></a>
#### BEN-28 · 🟡 Media · correccion · bug — Timer1 se vuelve a encender sin condiciones y HALT no se respeta

- **Ubicación:** `UIGASBENNETT.pas` líneas 931-933, 981-983, 926, 1936-1941, 727-759, 2113-2114
- **Se atiende en:** [E2.3](../PLAN_OPTIMIZACION.md#e23--arranque-y-paro-ordenados-del-servicio)
- **Verificación:** sin verificación independiente
- **Qué pasa:** ComandoConsola y pSerialTriggerAvail terminan con 'Timer1.Enabled:=true' sin revisar estado ni detenido. Detener apaga Timer1 y cierra el puerto (lineas 1937-1938). Si despues llega un PRICES y la linea estaba libre, ComandoConsolaBuff llama a ComandoConsola, que vuelve a encender Timer1. pSerial.OutBuffFree (linea 926) con el puerto cerrado lanza EPortNotOpen, o lo reabre si AutoOpen=True (valor por defecto de TApdComPort, que el .dfm no cambia). Timer1Timer traga las excepciones (lineas 2113-2114). Certeza media sobre AutoOpen, porque depende de la version de APRO.
- **Evidencia:** Lineas 931-933 y 981-983: 'finally Timer1.Enabled:=true;'.
- **Impacto:** Despues de HALT el sondeo y los comandos pendientes pueden seguir ejecutandose, o se generan excepciones silenciosas cada 150 ms; los precios enviados durante HALT pueden perderse.
- **Recomendación:** Usar 'Timer1.Enabled:=(estado=1) and (not detenido)' en ambos finally, poner AutoOpen=False en el .dfm y, si PRICES llega con el puerto cerrado, guardar los precios para aplicarlos en RUN.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BEN-29"></a>
#### BEN-29 · 🟡 Media · correccion · bug — En modo de 6 digitos no se cierra la venta con J cuando finventa=0

- **Ubicación:** `UIGASBENNETT.pas` líneas 1169-1206, 1228-1233, 1127-1133
- **Se atiende en:** [E1.9](../PLAN_OPTIMIZACION.md#e19--coherencia-del-estado-publicado-estatus-fin-de-venta-horaocc-estado)
- **Verificación:** sin verificación independiente
- **Qué pasa:** La rama '1' (8 digitos) manda 'J' de inmediato al leer estatus 7/8 con finventa=0 (lineas 1228-1233). La rama 'A' (6 digitos) no lo hace, y solo queda el cierre automatico despues de SegundosFinv (30 s por defecto) en la rama 'B' (lineas 1129-1132) o un PAYMENT.
- **Evidencia:** Comparando 1169-1206 con 1207-1242: el bloque 'if (TPosCarga[xpos].finventa=0) then ... J' solo existe en la rama '1'.
- **Impacto:** Con consolas de 6 digitos, una venta que no espera pago (finv distinto de 0) deja la posicion en 'Fin de venta' unos 30 s antes de aceptar la siguiente.
- **Recomendación:** Unificar el comportamiento de las dos ramas en una funcion comun de post-lectura y confirmar con OpenGas que significa finventa.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="BEN-30"></a>
#### BEN-30 · 🟡 Media · protocolo · bug — No soporta los mensajes '0' y '1' que el Bridge reenvia

- **Ubicación:** `UIGASBENNETT.pas` líneas 344-397
- **Se atiende en:** [E5.4](../PLAN_OPTIMIZACION.md#e54--comandos-homogéneos-entre-marcas)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El Bridge reenvia los mensajes de un caracter '0' y '1' de OpenGas como 'folio|DISPENSERS|0' o '|1' (UIGASBRIDGE.pas 289-292). Wayne (2780-2803) y PAM (378-406) tienen una rama que cierra o abre el puerto y reanuda. En Bennett, GetEnumValue('1_e') devuelve -1 y se contesta 'False|Comando desconocido|'.
- **Evidencia:** grep "StrToIntDef(comando,-99) in [0,1]": solo aparece en UIGASPAM.pas y UIGASWAYNE.pas.
- **Impacto:** Con Bennett no funciona la opcion de OpenGas para liberar y retomar el puerto serial; OpenGas recibe False.
- **Recomendación:** Portar la rama de Wayne y PAM, o documentar que no esta soportado. Probar enviando '0' y luego '1'.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BEN-31"></a>
#### BEN-31 · 🟡 Media · correccion · bug — AgregaPosCarga: 'existe' no se reinicia por manguera y el mapeo de mangueras y productos es inconsistente

- **Ubicación:** `UIGASBENNETT.pas` líneas 837, 853-880, 855, 863-872, 1751-1763
- **Se atiende en:** [E1.8](../PLAN_OPTIMIZACION.md#e18--índices-fuera-de-rango-y-carga-de-posiciones-r-)
- **Verificación:** sin verificación independiente
- **Qué pasa:** existe:=false se asigna una sola vez por posicion (linea 837) y no dentro del for j. Despues de la primera manguera con producto repetido, todas las siguientes se descartan aunque su producto sea nuevo. TComb, TPos y TMang no se limpian al reinicializar. HoseId=3 se mapea a 4 (lineas 865-867), asi que si se configura una HoseId 4 choca con ella. Hoses[].HoseId publica 4 para la manguera 3 mientras 'Manguera' publica 3. Con MapeoCombustibles, el StrToInt sin default de la linea 855 aborta INITIALIZE, y Hoses[].ProductId publica el producto mapeado mientras 'Combustible' publica el original.
- **Evidencia:** Linea 837: 'existe:=false;' fuera del bucle de la linea 853. Lineas 858-860: 'for k:=1 to NoComb do if TCombx[k]=xcomb then existe:=true;'.
- **Impacto:** Faltan productos en algunas posiciones (presets con 'Combustible no existe' y precios que no se aplican) y el JSON queda inconsistente entre mangueras y productos.
- **Recomendación:** Reiniciar existe en cada manguera, limpiar los arreglos, validar HoseId<=3 y NoComb<=MCxP, publicar la HoseId original y usar StrToIntDef con un error explicito.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BEN-32"></a>
#### BEN-32 · 🟡 Media · configuracion · riesgo — Precios, importes y litros dependen del separador decimal del sistema

- **Ubicación:** `UIGASBENNETT.pas` líneas 737, 1444, 1518, 2044, 2048, 1711-1713
- **Se atiende en:** [E8.2](../PLAN_OPTIMIZACION.md#e82--configuración-regional-locale-explícita)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Los precios (StrToFloatDef, linea 737) y los importes y litros de los presets (StrToFLoat en las lineas 1444 y 1518, StrToFloatDef en las lineas 2044 y 2048) se convierten con el DecimalSeparator global, mientras que OpenGas manda '.'. Al construir P/5 se filtran los digitos y el problema no aparece, pero en la entrada si.
- **Evidencia:** Linea 2044: 'StrToFloatDef(ExtraeElemStrSep(msj,4,'|'),0)>0' sin TFormatSettings.
- **Impacto:** En un servidor con configuracion regional de coma decimal fallan todos los presets y precios, y como el Bridge los confirma de inmediato, fallan en silencio.
- **Recomendación:** Usar un TFormatSettings con DecimalSeparator='.' (StrToFloat(s,fs)) y registrar el DecimalSeparator al arrancar.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BEN-33"></a>
#### BEN-33 · 🟡 Media · seguridad · riesgo — Validacion HASP comentada, CoInitialize sin uso y clave de licencia en el repositorio

- **Ubicación:** `UIGASBENNETT.pas` líneas 1864-1900, 1870, 1924, 267, 270; PDISPENSARIOS.ini 5
- **Se atiende en:** [E8.1](../PLAN_OPTIMIZACION.md#e81--autenticación-licencia-y-modo-emulación)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El bloque de validacion HASP esta comentado completo (lineas 1872-1900), pero en cada RUN se siguen llamando CoInitialize y CoUninitialize (lineas 1870 y 1924). Licencia y GSentinelKey se leen (lineas 267 y 270) y no se usan. PDISPENSARIOS.ini esta versionado con 'Licencia=805626469450465124'.
- **Evidencia:** Lineas 1872-1900 comentadas con //. PDISPENSARIOS.ini, linea 5.
- **Impacto:** No hay control de licencia, la clave queda expuesta en el repositorio y el codigo confunde a quien lo lee.
- **Recomendación:** Decidir entre reactivar HASP con pruebas de regresion o eliminar el bloque, las variables y CoInitialize. Quitar la clave del .ini versionado y usar una plantilla .ini.example.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="BEN-34"></a>
#### BEN-34 · ⚪ Baja · seguridad · riesgo — Login predecible y Token que no se valida en ningun lado

- **Ubicación:** `UIGASBENNETT.pas` líneas 2535-2547, 2549-2559, 2578-2582, 2630-2650, 238
- **Se atiende en:** [E8.1](../PLAN_OPTIMIZACION.md#e81--autenticación-licencia-y-modo-emulación)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El password es MD5(usuario+'|'+yyyy-mm-ddThh:nn), sin ningun secreto. Token (global, linea 238) se asigna pero ningun comando lo valida. El login falla si cliente y servidor quedan en minutos distintos. Encrypt y Decrypt (3DES con clave derivada por MD5) no se usan.
- **Evidencia:** Linea 2541: 'if MD5(usuario+'|'+FormatDateTime('yyyy-mm-dd',Date)+'T'+FormatDateTime('hh:nn',Now))<>password'.
- **Impacto:** La autenticacion es nominal: quien conozca el algoritmo genera el password, y de todos modos no protege ningun comando.
- **Recomendación:** Si se necesita autenticacion, usar HMAC con un secreto configurable y tolerancia de 1 minuto, y validar el Token en comandos sensibles. Si no, documentarlo y eliminar Encrypt y Decrypt.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** sí

<a id="BEN-35"></a>
#### BEN-35 · ⚪ Baja · robustez · bug — Fugas y falta de validacion de nil en ServiceExecute, Inicializar y Parametros

- **Ubicación:** `UIGASBENNETT.pas` líneas 261, 265, 268, 283-287, 293-300 (296), 2413, 2429-2457, 2566-2568
- **Se atiende en:** [E2.7](../PLAN_OPTIMIZACION.md#e27--initialize-idempotente-y-seguro-con-ventas-en-curso)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El TIniFile de la linea 261 y los JSON de TlkJSON.ParseText (lineas 2413 y 2566) nunca se liberan. Field['Consoles'].Child[0], Field['Products'] y Field['CounterToPaySale'] se usan sin revisar nil, y el error llega como 'Excepcion: Access violation...'. Un PARAMETERS sin CounterToPaySale cae en el except y reinicia SegundosFinv a 30. El puerto y MinutosLog se leen con StrToInt sin default (lineas 265 y 268). El except de ServiceExecute usa ListaLog antes de crearla (linea 283) y la guarda con el nombre LogDispPetRes (linea 296).
- **Evidencia:** Linea 2413: 'js := TlkJSON.ParseText(...)' sin Free. Linea 2567: 'if js.Field['CounterToPaySale'].Value>0' sin revisar nil.
- **Impacto:** Fugas pequenas en cada reinicializacion, mensajes de error poco utiles y un servicio que no arranca sin diagnostico si el .ini esta mal escrito.
- **Recomendación:** Liberar con try/finally, validar los nodos y devolver mensajes claros, usar ReadInteger o StrToIntDef, y crear las listas al inicio de ServiceExecute.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BEN-36"></a>
#### BEN-36 · ⚪ Baja · robustez · bug — ComandoConsola descarta comandos sin avisar

- **Ubicación:** `UIGASBENNETT.pas` líneas 910-930 (916, 926-930)
- **Se atiende en:** [E8.3](../PLAN_OPTIMIZACION.md#e83--código-muerto-variables-globales-y-duplicación-interna)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Si OutBuffFree es menor que la longitud de la trama, o si el puerto esta cerrado, el comando no se envia ni se registra, pero SwEsperaRsp ya quedo en true (linea 916). El driver espera el timeout (unos 750 ms) y el comando se pierde.
- **Evidencia:** Lineas 926-930: 'if pSerial.OutBuffFree >= Length(S1) then begin ... end;' sin rama else.
- **Impacto:** Comandos perdidos (presets, precios, J) que no dejan rastro en el log.
- **Recomendación:** Registrar el descarte, volver a encolar el comando y no marcar espera si no se envio.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BEN-37"></a>
#### BEN-37 · ⚪ Baja · memoria_recursos · bug — EjecutaComando accede a TabCmnd[201] antes de revisar el limite

- **Ubicación:** `UIGASBENNETT.pas` líneas 1770-1782
- **Se atiende en:** [E1.5](../PLAN_OPTIMIZACION.md#e15--tabla-de-comandos-tabcmnd-y-respuestas-de-comandos-asíncronos)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El repeat incrementa ind y lee y escribe TabCmnd[ind] antes de evaluar ind>200. Si los 200 slots estan activos (comandos del ultimo minuto), se accede a TabCmnd[201], fuera de rango, cuya memoria es la de LPrecios y otras globales, antes de salir. Ademas los slots solo se liberan cuando caducan, no cuando se responden.
- **Evidencia:** Lineas 1770-1777: 'repeat inc(ind); if (TabCmnd[ind].SwActivo)and(...) ... until (not TabCmnd[ind].SwActivo)or(ind>200);'.
- **Impacto:** Poco probable (requiere 200 comandos en un minuto), pero si ocurre corrompe precios y otras globales.
- **Recomendación:** Usar un bucle 'for ind:=1 to 200' que revise antes de acceder, y liberar el slot cuando se consulta su respuesta.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BEN-38"></a>
#### BEN-38 · ⚪ Baja · mantenibilidad · deuda_tecnica — Estado global de unidad y variables duplicadas como campos que las ocultan

- **Ubicación:** `UIGASBENNETT.pas` líneas 217-238, 56-72, 39, 1064-1071
- **Se atiende en:** [E8.3](../PLAN_OPTIMIZACION.md#e83--código-muerto-variables-globales-y-duplicación-interna)
- **Verificación:** sin verificación independiente
- **Qué pasa:** TPosCarga, TabCmnd, LPrecios, ContDA, PreciosInicio, LinEstado, LinEstadoGen y Token son globales de la unidad. ListaCmnd, LinCmnd, CharCmnd, SwEsperaRsp, ContEsperaRsp y NumPaso estan declaradas como globales (lineas 230-235) y tambien como campos (lineas 64-68 y 39); los metodos usan los campos, asi que las globales estan muertas. ContDA es un contador global compartido por todas las posiciones (lineas 1064-1071) y solo alimenta SwActivo, que no se usa.
- **Evidencia:** Linea 230 'ListaCmnd :TStrings;' (global) y linea 64 'ListaCmnd :TStrings;' (campo).
- **Impacto:** Confusion y riesgo de usar la variable equivocada. ContDA mezcla datos de distintas posiciones.
- **Recomendación:** Mover todo a campos de la clase, eliminar las globales duplicadas y quitar ContDA y SwActivo.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BEN-39"></a>
#### BEN-39 · ⚪ Baja · mantenibilidad · deuda_tecnica — Codigo muerto que confunde el analisis de tiempos y protocolo

- **Ubicación:** `UIGASBENNETT.pas` líneas 1007-1009, 1026/1033, 1297-1342 (1302), 1389, 1394-1397, 1592-1600, 1602, 2239-2292, 1953-1956, 2521-2533, 2584-2608, 2630-2650, 222-228, 36-38
- **Se atiende en:** [E8.3](../PLAN_OPTIMIZACION.md#e83--código-muerto-variables-globales-y-duplicación-interna)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  Inventario de codigo que no tiene efecto:
  - xTurnoSocket no se usa.
  - UltimoStatus:=LineaTimer se asigna despues de LineaTimer:='', asi que siempre vale ''.
  - El bloque NumPaso=3 depende de 'if MaximoDePosiciones<24', siempre falso porque la constante vale 32 (linea 200); xestado2, xdisp2 y xmodo2 quedan vacios y LinEstado solo lo usa ese bloque.
  - swcierrabd nunca vale true.
  - Ningun metodo genera los comandos EFV ni PARAR.
  - TransaccionPosCarga, EstadoPosiciones y ObtenerEstado quedaron sin uso desde que el case ya no maneja TRANSACTION, STATUS ni STATE (commit 0e02888).
  - CRC16, Encrypt, Decrypt e IniciarPrecios no se ejecutan nunca.
  - AvanceBar, SwSolOk, StErrSol, ruta_db, ContEspera, ContEsperaPaso2, ContEsperaPaso3, SwEspera, SwPresetHora y PresetHora no se usan.
- **Evidencia:** grep: Encrypt, Decrypt, CRC16, TransaccionPosCarga, EstadoPosiciones y ObtenerEstado solo aparecen en la declaracion y la implementacion (2 referencias cada uno). PreciosInicio nunca se pone en True.
- **Impacto:** Unas 300 lineas que despistan al revisar el protocolo y la maquina de estados.
- **Recomendación:** Eliminarlas despues de confirmar con el historial git y dejarlo explicado en un commit.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BEN-40"></a>
#### BEN-40 · ⚪ Baja · correccion · bug — Mensajes y validaciones menores incorrectos

- **Ubicación:** `UIGASBENNETT.pas` líneas 1580-1581, 1620-1628, 2001-2002, 2027-2028, 2294-2310
- **Se atiende en:** [E8.3](../PLAN_OPTIMIZACION.md#e83--código-muerto-variables-globales-y-duplicación-interna)
- **Verificación:** sin verificación independiente
- **Qué pasa:** FINV con swcargando=true responde 'Posicion no esta despachando', al reves de lo que pasa. REANUDAR responde 'OK' para posiciones no registradas o que no estan detenidas, porque falta el else. ObtenerLog y ObtenerLogPetRes devuelven r+1 lineas. TotalesBomba crea el comando para posiciones no registradas y responde True.
- **Evidencia:** Lineas 1576-1581, 1623-1627 (sin else) y 2001: 'i:=ListaLog.Count-(r+1)'.
- **Impacto:** Diagnosticos enganosos para OpenGas y para soporte.
- **Recomendación:** Corregir los textos y validar PosRegistrada en TotalesBomba y REANUDAR.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BEN-41"></a>
#### BEN-41 · ⚪ Baja · robustez · bug — SHUTDOWN termina el hilo antes de responder y no cierra recursos

- **Ubicación:** `UIGASBENNETT.pas` líneas 2317-2325, 290-292
- **Se atiende en:** [E2.3](../PLAN_OPTIMIZACION.md#e23--arranque-y-paro-ordenados-del-servicio)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Shutdown llama ServiceThread.Terminate antes de AddPeticionJSON. El bucle de ServiceExecute termina y desactiva el socket (linea 292) sin haber enviado el resultado, y no cierra el puerto ni los timers.
- **Evidencia:** Lineas 2322-2323. PAM llama AddPeticionJSON antes de Terminate, aunque tampoco envia el resultado.
- **Impacto:** OpenGas recibe timeout del Bridge en SHUTDOWN y el puerto sigue abierto hasta que termina el proceso.
- **Recomendación:** Enviar el JSON con el resultado antes de Terminate, y cerrar pSerial y los timers al salir del bucle o en OnStop.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BEN-42"></a>
#### BEN-42 · ⚪ Baja · build_despliegue · riesgo — El proyecto referencia unidades que se borraron del repositorio

- **Ubicación:** `PDISPENSARIOS.dpr` líneas 8-10, 23
- **Módulos afectados:** PDISPENSARIOS, UIGASBENNETT, todos los drivers
- **Se atiende en:** [E0.1](../PLAN_OPTIMIZACION.md#e01--build-reproducible-de-ambos-ejecutables)
- **Verificación:** sin verificación independiente
- **Qué pasa:** PDISPENSARIOS.dpr declara CRCs in 'CRCs.pas', IdHashMessageDigest in 'IdHashMessageDigest.pas' e IdHash in 'IdHash.pas', pero el commit 8230dd7 ('Eliminacion de archivos hasp anteriores') borro esos tres archivos. Bennett los usa para CRC16 y MD5. Ademas .gitignore excluye *.res mientras el dpr hace {$R *.RES}.
- **Evidencia:** git show 8230dd7 --stat: CRCs.pas, IdHash.pas e IdHashMessageDigest.pas borrados. Las lineas 8-10 del dpr siguen apuntando a ellos.
- **Impacto:** Una compilacion desde un checkout limpio falla o toma versiones distintas de esas unidades segun la maquina; el build no es reproducible.
- **Recomendación:** Volver a versionar esas unidades (o apuntar a una ruta de dependencias documentada), versionar el .res o generarlo en el script de build, y documentar en el README las dependencias externas (ULIBGRAL, Async Pro).
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BEN-43"></a>
#### BEN-43 · ⚪ Baja · pruebas · deuda_tecnica — No hay emulador ni pruebas automatizadas del protocolo Bennett

- **Ubicación:** `UIGASBENNETT.pas` líneas 946-1690, 2083-2115
- **Se atiende en:** [E0.4](../PLAN_OPTIMIZACION.md#e04--simuladores-de-opengas-y-de-driver--batería-de-pruebas-de-protocolo), [E7.4](../PLAN_OPTIMIZACION.md#e74--separar-la-lógica-de-protocolo-serial-de-la-del-servicio-testeable)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Wayne2W tiene un modo de emulacion (SwModoEmulacion, 22 referencias). Bennett no tiene nada parecido ni pruebas. Varios de los problemas descritos (BCC, NAK, timeouts, tramas parciales, presets sin caducidad, concurrencia) solo se reproducen con hardware real.
- **Evidencia:** grep SwModoEmulacion: 0 en UIGASBENNETT.pas; el repo no tiene proyecto de pruebas.
- **Impacto:** Las regresiones solo se detectan en campo o en las pruebas CENAM.
- **Recomendación:** Separar la logica de parseo y de la maquina de estados en una unidad sin VCL, probarla con DUnit y armar un emulador de consola Bennett sobre un puerto virtual (com0com) que inyecte errores.
- **Esfuerzo:** L · **Riesgo del cambio:** bajo · **Toca contrato:** no

