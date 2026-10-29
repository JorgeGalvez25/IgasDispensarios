# Hallazgos · WAY · Driver Wayne (Marca 1) · UIGASWAYNE.pas

> Anexo del [plan de optimización](../PLAN_OPTIMIZACION.md). Código auditado: `IgasDispensarios@26ccfb4`, `IgasDispensariosBridge@99edafd`. Las líneas pueden haber cambiado: ubica las rutinas por su nombre.

## Cómo funciona este módulo

Driver TService para consolas Wayne (protocolo STX datos ETX BCC-XOR, respuestas ACK/NAK) que publica un snapshot JSON hacia el Bridge (PDISPBRIDGE) por un TClientSocket no bloqueante (ini [CONF] ServidorSocket, default 127.0.0.1:1004).

Componentes (dfm): pSerial TApdComPort (solo OnTriggerAvail, AutoOpen por omision), Timer1 250 ms deshabilitado (ciclo serial), Timer2 200 ms HABILITADO desde la creacion (latido/reconexion al Bridge), ClientSocket1 ctNonBlocking.

Arranque: ServiceExecute (hilo del servicio) lee PDISPENSARIOS.ini, crea listas de log y rootJSON con Estado=-1 y se queda en ProcessRequests. Timer2 (hilo principal) conecta al Bridge y envia PING/JSON; el Bridge contesta en cada mensaje con la siguiente peticion 'folio|DISPENSERS|CMD|params' que ClientSocket1Read despacha (INITIALIZE, RUN, AUTHORIZE, etc.) dejando el resultado en Peticiones (max 2) del JSON.

INITIALIZE configura puerto, variables Wayne (WayneFusion/V3, AjusteWayne*, Decimales*, etc.) y PosCarga; RUN abre el puerto, envia 'N' y 'l1', activa Timer1 y apaga Timer2. En operacion el unico emisor hacia el Bridge es el finally de ProcesaLinea: cada trama serial procesada (o timeout sintetico) envia el JSON completo.

Ciclo serial: B00 (estatus de todas) -> comandos encolados -> 'A' por posicion activa (importe/volumen/precio) -> mapeo 'g' -> 'C' de totales pendientes -> silencio 250 ms -> Timer1Timer procesa TabCmnd (presets OCC/OCL, FINV, DVC, TOTAL, CPREC) y reinicia con B00.

Modelo de hilos verificado: timers creados en el hilo principal (Application.CreateForm) y socket activado en Timer2Timer, por lo que socket y timers comparten el hilo principal (la hipotesis de socket en el hilo del servicio no aplica a Wayne); APRO entrega OnTriggerAvail sincronizado al hilo principal (certeza media). Concurrencia real solo con ServiceStop/ServiceShutdown/ServiceExecute (hilo del servicio) sobre las listas de log. El riesgo dominante es reentrancia/bloqueo por EsperaMiliSeg y Sleep en el hilo principal.

Problemas mas graves: livelock del paso de totales cuando una 'C' no se responde/NAK (congela todo el sondeo y sigue enviando JSON fresco), mezcla de indices logicos y fisicos de manguera, estatus 2->1 publicado antes de la lectura final, variables sin inicializar (i, xcomb), sobrescritura de la cadena de estados en el bucle 'B', finventa leido del elemento equivocado, AgregaPosCarga que descarta mangueras, cambios de precio sin verificacion, mensajes del socket sin delimitar, ausencia de trafico al Bridge con la consola caida, reconexion sin las correcciones ya aplicadas a Bennett/Wayne2W, y log PetRes con el JSON completo en cada envio con recursion GuardarLog/GuardarLogPetRes.

Compilado con -$R- -$Q- (PDISPENSARIOS.cfg 17-18): todos los indices fuera de rango corrompen memoria en silencio.

### Ciclo serial

Timers: Timer1 (250 ms, Enabled=False en dfm) es el ciclo serial; Timer1Timer se auto-deshabilita al entrar y se re-arma en su finally (1507, 1911). pSerialTriggerAvail tambien hace Timer1.Enabled:=False/True (1402, 1440), por lo que Timer1 solo dispara tras 250 ms de silencio serial. Timer2 (200 ms) solo actua mientras no hay Bridge, estado<=0 o puerto cerrado.

Maquina de estados (NumPaso): 0 -> Timer1Timer envia 'B00' y pasa a 1 (1893-1898). 1 -> espera respuesta 'B'; si no llega, cada 10 ticks (>=2.5 s) reenvia 'B00' (1887-1891). Respuesta 'B' (990-1155): actualiza estatus por posicion (7->0, fin de venta virtual 2->1 => 3, auto-reanudar 8, stop 2->9, FINV con 'R'), publica Estatus, activa SwComandoB, y en la primera vista en 1 de cada posicion (InicializaWayne=Si) envia 'h'/'k' + prepara 'g' y re-procesa la misma trama (SwReinicio/UltimaLineaTimer). Luego NumPaso=2.

NumPaso 2 (1312-1335): primero se vacian los comandos encolados en ListaCmnd (uno por respuesta, 1306-1311); luego 'A'+pos por cada posicion con NoComb>0, estatus<>9 y (cambio, estatus 2/3, cargando o primera lectura), con cursor PosicionCargaActual; respuesta 'A' (1156-1279) calcula importe/volumen/precio con heuristicas (V3, /10, AjusteWayne*), detecta EOT y marca totales. Si no responde: 20 ticks (>=5 s) y se salta la posicion con '.A00..'. Al final, si hay SwMapea envia 'g' directo + EsperaMiliSeg(1000).

NumPaso 3 -> 4 inmediato. NumPaso 4 (1341-1378): barre desde la posicion 1 en cada llamada y pide 'C'+pos+k para el primer flag SwCargaTotales; timeout 6 ticks (>=1.5 s) inyecta '.C00..' que NO avanza ni limpia el flag (livelock). Al no quedar flags NumPaso=0. NumPaso 5 y las esperas de paso 3 son codigo muerto.

Timer1Timer en NumPaso 0 (tras 250 ms de silencio): si hubo 'B' (SwComandoB) recorre TabCmnd[1..200] y ejecuta OCC/OCL (EnviaPreset con hasta 3 reintentos de 500 ms), FINV, EFV, DVC/PARAR, REANUDAR, TOTAL, CPREC; ademas aplica un producto de CPREC por tick (2 comandos 'a' directos + 2x250 ms). Reinicio diario: Detener+Terminar+Shutdown si ReinicioDiario y 24 h y 30 s sin estatus 2.

Envio: ComandoConsolaBuff encola si hay respuesta pendiente (SwEsperaRsp) y VACIA la cola si el ultimo envio fue hace >2 s; ComandoConsola arma STX+cmd+ETX+BCC, limpia LineaBuff, incrementa ContadorAlarma (>=10 sin respuesta -> log de desconexion y comando 'N' tras 5 tramas al recuperar) y no envia si OutBuffFree es insuficiente. ACK y NAK no se distinguen y nunca se reintenta LinCmnd.

Recepcion/tramas parciales (1390-1448): todos los bytes disponibles se agregan a LineaBuff (GetChar char a char); se extrae UNA trama por evento hasta ETX+BCC o ACK/NAK; las tramas incompletas se acumulan en Linea entre eventos; BCC (XOR desde el caracter siguiente a STX hasta ETX) invalido se convierte en NAK; bytes sobrantes quedan en LineaBuff y se pierden con el siguiente ComandoConsola; sin resincronizacion a STX ni limite de longitud.

Tiempos efectivos: ciclo ~= 250 ms + B (~40-60 ms) + 40-60 ms por cada 'A'/'C'/comando encolado; con 16 posiciones en reposo ~0.3-0.35 s por ciclo (~3 JSON/s hacia el Bridge); con ventas activas 0.5-1 s. La latencia de un preset es el resto del ciclo + 250 ms. Esperas activas en el hilo principal: EsperaMiliSeg(1000) mapeo (1327), 4x250 ms CPREC por producto (1541-1549), 500 ms por reintento de preset (1615, 1682), Sleep(100)+2x100 ms en Iniciar (2560-2565), hasta ~1 s de Sleep en Timer2Timer (2927-2930); EsperaMiliSeg esta en ULIBGRAL (no incluido): si bombea mensajes hay reentrancia de Timer1Timer/ProcesaLinea/ClientSocket1Read; si no, bloquea serial y socket.

Hilos: timers (creados en el hilo principal por Application.CreateForm), socket (activado en Timer2Timer) y, con certeza media, los eventos de APRO (sincronizados al hilo principal) comparten el hilo principal; ServiceExecute/ServiceStop/ServiceShutdown corren en TServiceThread y tocan las listas de log sin sincronizacion.

### Contrato con el Bridge, visto desde este módulo

- **Conexión:** TClientSocket ClientSocket1 (ctNonBlocking) como cliente del Bridge. Host/Port se leen en ServiceExecute (293-294) de [CONF] ServidorSocket (default 127.0.0.1:1004, StrToInt sin default). La conexion se abre de forma perezosa en Timer2Timer (2925-2926, hilo principal), por lo que la ventana del socket y sus eventos (Connect/Disconnect/Read) viven en el hilo principal. ClientSocket1Connect solo pone conectado:=True (2903-2907). No hay OnError: los errores asincronos de conexion se convierten en excepciones no manejadas en el ciclo de mensajes. Respuestas via Responder (2954-2971): usa socketResponse (asignado al final de ClientSocket1Read) o ClientSocket1.Socket; SendText sin verificar bytes enviados.
- **Ciclo de envío:** Dos emisores: (1) Timer2Timer cada 200 ms solo mientras (not conectado) or (estado<=0) or (not pSerial.Open) (finally 2950): conecta si hace falta y envia PING o JSON; si estado>0 y puerto abierto apaga Timer2 y enciende Timer1 (2939-2942). (2) En operacion (estado=1, puerto abierto, conectado) el envio lo hace el finally de ProcesaLinea (1385-1387): TlkJSON.GenerateText(rootJSON) completo en CADA trama serial procesada y en cada timeout sintetico de Timer1 ('.A00..', '.C00..'), sin throttling ni verificacion de conectado. (3) Los comandos de 1 caracter '0'/'1' responden de inmediato con el JSON (2792, 2799). No hay keep-alive cuando la consola no responde (NumPaso=1): el driver queda mudo hacia el Bridge.
- **PING vs JSON:** respJson inicia False -> el primer mensaje es 'PING'. AddPeticionJSON pone respJson:=True (2244) y solo el comando '0' lo regresa a False (2800). Como el Bridge contesta el PING con '0\|DISPENSERS\|NOTHING' y NOTHING agrega una Peticion {Folio:0}, a partir del primer intercambio siempre se envia JSON. ProcesaLinea envia JSON sin consultar respJson. En la practica PING solo existe al arranque y tras '0'.
- **Peticiones:** AddPeticionJSON (2218-2251) agrega {Folio, Resultado} a rootJSON.Peticiones, conservando solo los 2 ultimos (borra el indice 0 mientras Count>=2) y nunca las limpia tras enviarlas: cada resultado viaja en al menos 2 mensajes y el Bridge empareja por Folio (TryPopByFolio) ignorando repetidos. Resultados: 'True\|...\|' / 'False\|mensaje\|' / '1' para los comandos '0'/'1'. Los comandos asincronos (AUTHORIZE/STOP/START/PAYMENT/TOTALS/PRICES) responden de inmediato con el folio interno de TabCmnd; el resultado real solo se obtiene con RESPCMND mientras la entrada no caduque (1 minuto, 893). Si ClientSocket1Read lanza excepcion no se agrega Peticion y el Bridge cae en TimeoutRespSrv.
- **Reconexión:** ClientSocket1Disconnect (2909-2915): conectado:=False, Timer1 off (se suspende el sondeo serial), Timer2 on; NO limpia socketResponse. Timer2Timer (2925-2931): ClientSocket1.Active:=True sin Active:=False previo y espera activa for i:=0 to 100 Sleep(10) hasta conectado; como el evento Connect solo se despacha al bombear mensajes del hilo principal, el bucle siempre agota ~1 s y sale por Exit; el siguiente tick (200 ms) ya ve conectado y envia. Responder ante excepcion solo registra y guarda PetRes, no marca desconexion. No hay watchdog de silencio del Bridge (horaAct). Bennett (commit 0d95b7f) y Wayne2W ya implementan Active:=False + Sleep(500) + socketResponse:=nil + desconexion en Responder + watchdog de 2 s; Wayne no.
- **Comandos:**
  - Formato recibido: 'folio\|DISPENSERS\|CMD\|p1\|p2...'; folio=elemento 1, comando=UpperCase(elemento 3), parametros = elementos 4..n re-unidos con '\|' (2777-2812); TMetodos(GetEnumValue(CMD+'_e')); desconocido -> 'False\|Comando desconocido\|'
  - '1' (1 caracter): abre pSerial, NumPaso:=0, SwEsperaRsp:=False, Timer2 off, Timer1 on solo si estado>0; AddPeticionJSON(folio,'1') y Responder inmediato (2782-2793)
  - '0' (1 caracter): cierra pSerial, Timer1 off, AddPeticionJSON(folio,'1'), Responder inmediato, respJson:=False, Timer2 on; estado no cambia (2794-2802)
  - NOTHING -> AddPeticionJSON(folio,'True\|') (2818-2819)
  - INITIALIZE json\|variables -> Inicializar: re-inicializa si estado>-1 (LiberaInicializacion), lee variables CRLF, Consoles[0].Connection -> IniciaPSerial, Dispensers -> AgregaPosCarga; 'True\|' o 'False\|msg\|' (366-462)
  - PARAMETERS -> 'True\|' sin efecto (2824-2825)
  - PRICES p1\|p2\|... -> IniciaPrecios: EjecutaComando('CPREC ...') -> 'True\|' inmediato; aplicacion diferida en Timer1Timer (713-724, 1533-1566, 1806-1820)
  - AUTHORIZE pos\|comb\|importe\|litros\|finv -> AutorizarVenta: arma 'OCC/OCL pos cantidad comb finv' en TabCmnd y responde 'True\|<folioCmnd>\|' sin validar (2290-2334)
  - STOP pos -> 'True\|'+EjecutaComando('DVC pos') (2448-2462); START pos -> 'REANUDAR pos' (2657-2671); PAYMENT pos -> 'FINV pos' (2464-2477)
  - SELFSERVICE/FULLSERVICE pos -> ModoOpera:='Prepago' en ambos casos (2143-2167, 2366-2390)
  - BLOCK/UNBLOCK pos (0=todas) -> SwDesHabilitado (2336-2421)
  - TOTALS pos -> 'True\|0\|0\|0\|0\|0\|0\|<folioCmnd>\|' inmediato; totales reales via RESPCMND del comando TOTAL (2740-2762, 1769-1805)
  - HALT -> Detener; RUN -> Iniciar; SHUTDOWN -> ServiceThread.Terminate si estado<=0; TERMINATE -> Terminar (2423-2446, 2513-2583, 2713-2738)
  - LOGIN usuario\|md5 -> 'True\|token\|' si MD5(usuario\|yyyy-mm-ddThh:nn) coincide; LOGOUT -> Token:='' (2585-2603)
  - TRACE -> GuardarLog(folio) 'True\|ruta\|'; SAVELOGREQ -> GuardarLogPetRes 'True\|'; LOG n / LOGREQ n -> 'True\|linea\|linea\|...' (2479-2511, 2605-2655)
  - RESPCMND folioCmnd -> ResultadoComando: 'True\|<resp sin OK>' o 'False\|<resp>\|' ('*' si no hay respuesta) (2673-2699)
- **Campos JSON:**
  - Estado (number): -1 no inicializado, 0 inicializado/detenido, 1 en proceso (SetEstadoJSON 2701-2711)
  - PosCarga[] creado en AgregaPosCarga en el orden de Dispensers del INITIALIZE (635-693)
  - PosCarga[].DispenserId (number)
  - PosCarga[].HoraOcc (string 'yyyy-mm-ddThh:nn', hora del ultimo preset EnviaPreset 2017-2018; inicial 1899-12-30T00:00)
  - PosCarga[].Manguera (MangueraEnPosicion(xpos,PosDispActual), 1264-1266)
  - PosCarga[].Combustible (CombustibleEnPosicion -> ProductId sin mapear)
  - PosCarga[].Estatus (estatus crudo de la trama 'B'; 7->0; 3 con swcargando->2; 3 tambien desde la rama 'A' 1270-1271; no publica 7=deshabilitado)
  - PosCarga[].Importe, Volumen, Precio (double, desde la trama 'A' tras ajustes 1168-1232)
  - PosCarga[].Hoses[] {HoseId (TMang), ProductId (xcomb mapeado por MapeoCombustibles), Total (TotalLitros via ApplyTotalLitrosToJSON indexado por xpos-1)}
  - Peticiones[] {Folio (number), Resultado (string)} max 2
- **Desviaciones respecto a otros drivers:**
  - Envia el JSON completo en cada ProcesaLinea (cada trama y cada timeout sintetico); Bennett, Wayne2W, Gilbarco y HongYang envian 1 de cada 3 (xTurnoSocket) y Bennett/Wayne2W/Gilbarco verifican conectado antes de Responder.
  - No tiene watchdog horaAct (Bennett 2086, Wayne2W 2633): con la consola sin responder el driver deja de hablar con el Bridge y este cierra el socket OpenGas a los 10 s.
  - Reconexion sin Active:=False/Sleep(500)/socketResponse:=nil y Responder sin manejo de desconexion (corregido en Bennett y Wayne2W; igual de debil en PAM, Team, Triton, HongYang y Gilbarco).
  - Procesa el mensaje de 1 caracter '0'/'1' (solo Wayne y PAM); con estado<=0 el '1' deja ambos timers apagados.
  - OCC/OCL leen finventa del elemento 6 (como Team) aunque AutorizarVenta arma 5 elementos; Bennett y PAM lo leen del elemento 5.
  - ApplyTotalLitrosToJSON indexa PosCarga por xpos-1; Wayne2W busca por DispenserId.
  - CPREC se aplica con ComandoConsola directo + EsperaMiliSeg dentro de Timer1Timer (PAM encola con ComandoConsolaBuff; Wayne2W lo modela por manguera con TNuevoPrec).
  - AgregaPosCarga no reinicia existe por manguera (Wayne2W 685 y Team 859 si) y no valida DispenserId/NoComb.
  - MangueraEnPosicion devuelve TComb[1] por omision (Bennett TMang[1], PAM 0).
  - AgregaLog tiene except vacio (Wayne2W registra el error).
  - Timer2 final enable agrega (not pSerial.Open), por lo que tras '0' Timer2 sigue latiendo (Wayne2W/Team/HongYang/Gilbarco solo usan conectado/estado).
  - Estatus publicado crudo con 7->0 y 3(cargando)->2, antes de aplicar el fin de venta virtual; el estado legado LinEstadoGen (con 7=deshabilitado) se calcula y no se publica.

### Bloques duplicados con otros módulos

| Rutina | Líneas | Nota |
|---|---|---|
| ServiceExecute | 284-330 | Lectura de PDISPENSARIOS.ini, creacion de listas/rootJSON y bucle ProcessRequests; misma estructura en todos los drivers (Bennett 256, Gilbarco 310, HongYang 270, PAM 268, Team 293, Triton 159, Wayne2W 411) con variaciones de claves del ini. En Wayne el except guarda ListaLog con nombre LogDispPetRes. |
| AgregaLog / AgregaLogPetRes | 823-844, 346-364 | Escapado char a char de SOH/STX/ETX/ACK/NAK/ETB y recorte a 10000 lineas con Delete(0); copiados en todos los drivers y en el Bridge (AgregaLogOG). Wayne: AgregaLog con except vacio y AgregaLogPetRes sin try; Wayne2W registra el error. |
| FechaHoraExtToStr | 769-773 | FechaPaq + hh:mm:ss.zzz; identica en Bennett, Gilbarco, HongYang, Kairos, PAM, Team y el Bridge. |
| Inicializar | 366-462 | Re-inicializacion via LiberaInicializacion, lectura de variables por CRLF y parseo de Consoles/Dispensers; esqueleto comun a todos los drivers (Bennett 2399, Gilbarco 1925, HongYang 560, PAM 2643, Team 621, Triton 490, Wayne2W 807), variables especificas de Wayne. |
| LiberaInicializacion | 464-493 | Agregado en 6b4f482 a todos los drivers (Bennett 2470, Gilbarco 2031, HongYang 614, Kairos 1205, PAM 2735, Team 705, Triton 548, Wayne2W 903) con el mismo patron. |
| IniciaPSerial | 495-564 | Parseo 'tipo,COMn,baudios,paridad,bits,stop' y asignacion a TApdComPort; copiado en Bennett 657, Gilbarco 1837, HongYang 489, Kairos 1242, PAM 644, Team 1445, Triton 667, Wayne2W 736. |
| AgregaPosCarga | 566-699 | Reset de TPosCarga y construccion de PosCarga/Hoses en rootJSON reutilizando el nodo; patron en Bennett 761, Gilbarco 1676, HongYang 643, Kairos 966, PAM 1896, Team 736, Triton 573, Wayne2W 578. Wayne no reinicia existe por manguera (Wayne2W 685 y Team 859 si). |
| MD5 / Login / Logout | 701-711, 2585-2603 | MD5 con TIdHashMessageDigest5 y login por MD5(usuario\|fecha-hora minuto); identicos en Wayne2W y casi identicos (4 lineas) en PAM, Bennett, Team, HongYang, Gilbarco, Triton y Kairos. |
| CRC16 | 332-344 | CRC16 con TCRC (unidad CRCs); presente en todos los drivers y en el Bridge; en Wayne no se usa. |
| IniciaPrecios | 713-724 | EjecutaComando('CPREC '+msj) -> True/False; identico en los 9 drivers; la aplicacion (rama CPREC de Timer1Timer 1533-1566 y 1806-1820) es especifica de cada marca. |
| ValidaCifra | 735-767 | Validacion de enteros/decimales con AjustaFloat; copiada en Bennett, Gilbarco, HongYang, Kairos, PAM y Wayne2W. |
| ComandoConsola / CalculaBCC / XorChar / ComandoConsolaBuff | 775-802, 804-821, 846-883, 2131-2141 | Armado STX+cmd+ETX+BCC XOR y cola con vaciado a 2 s; CalculaBCC en Bennett, HongYang y PAM; XorChar bit a bit solo en PAM y Wayne; ComandoConsolaBuff en Bennett, PAM y Team. |
| EjecutaComando / ResultadoComando | 885-924, 926-940 | Tabla TabCmnd[1..200] con caducidad de 1 minuto y folio incremental; casi identico en Wayne2W (1 linea), variantes en PAM/Bennett/Team/Gilbarco/HongYang/Kairos/Triton. Mismo defecto de evaluar TabCmnd[201]. |
| CombustibleEnPosicion / PosicionDeCombustible / MangueraEnPosicion | 1477-1495, 1915-1936, 2028-2046 | Busquedas por TPos/TComb/TMang; CombustibleEnPosicion en Bennett, Gilbarco, Kairos, PAM y Team; PosicionDeCombustible tambien en Wayne2W; MangueraEnPosicion en Bennett (default TMang[1]) y PAM (default 0) mientras Wayne usa TComb[1]. |
| EnviaPreset y ramas OCC/OCL de Timer1Timer | 1938-2026, 1582-1647, 1649-1716 | EnviaPreset existe en Bennett, PAM y Team con formatos de cada marca; dentro de Wayne las ramas OCC y OCL son ~65 lineas casi identicas (solo cambian importe/litros y validaciones), con el mismo error de finventa en el elemento 6 (tambien en Team 2068-2069 y 2092-2093). |
| ExtraeElemStrEnter / NoElemStrEnter | 2075-2097, 2099-2113 | Separacion por CRLF; identicas en Wayne2W y Bennett, casi identicas en PAM, Team, Gilbarco y Kairos (duplican funciones de ULIBGRAL). |
| ServiceDestroy / ServiceShutdown / ServiceStop | 2115-2129 | Solo GuardarLog(0); mismo patron en los demas drivers (ejecutado en el hilo del servicio para Stop/Shutdown). |
| ActivaModoPrepago / DesactivaModoPrepago | 2143-2167, 2366-2390 | Ambos asignan ModoOpera:='Prepago'; replicado en los 9 drivers (Team es el unico con 'Normal' en otra ruta, 2477). |
| ActualizaCampoJSON | 2169-2216 | Busqueda de PosCarga por DispenserId y asignacion de campo; identico en Wayne2W, 2-3 lineas de diferencia en PAM y Bennett, variante en Team, Gilbarco, HongYang y Triton. |
| AddPeticionJSON | 2218-2251 | Peticiones max 2 y respJson:=True; textualmente identico en Wayne2W, PAM y Bennett; variante menor en Team; tambien en Gilbarco, HongYang y Triton. |
| ApplyTotalLitrosToJSON | 2253-2288 | Publicacion de Hoses[].Total; Wayne indexa por xpos-1 (igual que PAM con 4 lineas de diferencia); Wayne2W ya busca por DispenserId; variantes en Bennett, Team, Gilbarco, HongYang y Triton. |
| SetEstadoJSON | 2701-2711 | Crea/actualiza Estado; identico en Wayne2W y Bennett, 1 linea de diferencia en PAM y Team; tambien en Gilbarco, HongYang y Triton. |
| AutorizarVenta / DetenerVenta / ReanudarVenta / FinVenta / TotalesBomba / RespuestaComando | 2290-2334, 2448-2477, 2657-2671, 2740-2762, 2673-2699 | Traduccion de comandos OpenGas a TabCmnd ('OCC/OCL', 'DVC', 'REANUDAR', 'FINV', 'TOTAL') y lectura por RESPCMND; replicados en los 9 drivers con la misma inversion de finv ('0'->'1'). |
| Bloquear / Desbloquear | 2336-2364, 2392-2421 | Cambio de SwDesHabilitado (0=todas); identicos en los 9 drivers. |
| Detener / Iniciar / Shutdown / Terminar | 2423-2446, 2513-2583, 2713-2721, 2723-2738 | Ciclo de vida del servicio y apertura de puerto; mismo patron en Bennett, Gilbarco, HongYang, PAM, Team, Triton y Wayne2W; Iniciar conserva el bloque HASP comentado en todos. |
| GuardarLog / GuardarLogPetRes | 2479-2511 | SaveToFile con nombre por fecha-hora e InfoVersionModulo; Wayne2W difiere en 2 lineas; PAM, Bennett, Team, HongYang, Gilbarco y Triton con variaciones; la recursion mutua ante error esta en la version de Wayne. |
| ObtenerLog / ObtenerLogPetRes | 2605-2655 | Ultimas r lineas concatenadas con '\|'; identicos en Wayne2W y Triton, variantes en PAM, Bennett, Team, HongYang y Gilbarco. |
| ClientSocket1Read | 2764-2901 | Despachador TMetodos por GetEnumValue; misma tabla de casos en todos los drivers con Bridge. Wayne y PAM agregan la rama de 1 caracter '0'/'1'; Wayne2W/Bennett actualizan horaAct. |
| ClientSocket1Connect / ClientSocket1Disconnect / Timer2Timer / Responder | 2903-2915, 2917-2952, 2954-2971 | Latido y reconexion al Bridge: identicos (sin Active:=False) en PAM, Team, Triton, HongYang y Gilbarco; Bennett y Wayne2W tienen la version corregida (Active:=False, Sleep(500), socketResponse:=nil, Responder que marca desconexion). Responder de Wayne es textualmente igual al de PAM y Team. |
| Declaraciones de tipos tiposcarga / RegCmnd / TMetodos y globales | 165-266 | Registro de posicion, tabla de comandos y enumeracion de metodos copiados con variantes en cada unidad; TMetodos identica a la de los demas drivers con Bridge. |

## Hallazgos (45)

<a id="WAY-01"></a>
#### WAY-01 · 🔴 Crítica · correccion · bug — Livelock en el paso de totales (NumPaso=4): una 'C' sin respuesta o con NAK congela todo el sondeo

- **Ubicación:** `UIGASWAYNE.pas` líneas 1280-1304, 1341-1378, 1842-1850, 682, 1569, 1886-1898
- **Módulos afectados:** UIGASWAYNE
- **Se atiende en:** [E1.4](../PLAN_OPTIMIZACION.md#e14--sondeo-que-se-congela-livelocks-y-bloqueos-de-la-máquina-de-estados)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El paso 4 reinicia el barrido en la posicion 1 en cada invocacion (PosicionCargaActual2:=0) y pide 'C' para el primer par (pos,k) con SwCargaTotales[k]=true. El flag solo se limpia en la rama 'C' cuando existe TPos[xpr]=i. Si la consola no responde a esa 'C' (dispensario apagado o sin comunicacion), responde NAK (LineaTimer=#21 no entra a la rama 'C') o devuelve una posicion fisica que no esta en TPos (HoseId no contiguos), el flag nunca se limpia: Timer1 inyecta '.C00..' tras 6 ticks, ProcesaLinea no limpia nada (xpos=0), vuelve a NumPaso=4 y pide la misma 'C' para siempre. NumPaso nunca regresa a 0/1, asi que no se vuelve a enviar 'B00' ni a activar SwComandoB.
- **Evidencia:** 1343: PosicionCargaActual2:=0; 1359-1362: if SwCargaTotales[PosicionDispenActual] then begin ... ComandoConsolaBuff('C'+...); exit; end; 1288-1293: SwCargaTotales[i]:=false solo dentro de 'if TPos[xpr]=i'; 1844-1847: if ContEsperaPaso5>5 then begin LineaTimer:='.C00..'; ProcesaLinea; exit; end; 1832-1884: con NumPaso>1 Timer1Timer termina en exit sin llegar a 'B00' (1893-1898); 682: SwCargaTotales[NoComb]:=true para todas las mangueras al inicializar; 1569: TabCmnd solo se procesa si SwComandoB.
- **Impacto:** Toda la estacion queda sin sondeo de estatus/importes; los presets (ya confirmados por el Bridge), STOP y PAYMENT nunca se ejecutan. Como el timeout sigue llamando ProcesaLinea, el JSON con datos congelados se envia cada 1.5-3 s y el Bridge lo considera dato real (no obsoleto), por lo que OpenGas ve estados viejos como vigentes. Puede ocurrir en el arranque si un dispensario esta apagado (todos los flags inician en true) o tras cualquier venta en un dispensario que deje de responder.
- **Recomendación:** Mantener un cursor persistente (no reiniciar PosicionCargaActual2 en cada llamada), avanzar al siguiente par en timeout/NAK con contador de reintentos por manguera (p.ej. 2) y diferir el flag al siguiente ciclo; al terminar el barrido volver siempre a NumPaso=0 para enviar 'B00'. Validar con un simulador que no conteste 'C' para una posicion y verificar en LogDisp que 'B00' sigue saliendo cada ciclo.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="WAY-02"></a>
#### WAY-02 · 🟠 Alta · correccion · bug — Totales: se mezcla indice logico de manguera (1..NoComb) con posicion fisica (TPos/HoseId 1..4)

- **Ubicación:** `UIGASWAYNE.pas` líneas 682, 1247, 1284-1294, 1345-1361, 1774-1795
- **Módulos afectados:** UIGASWAYNE
- **Se atiende en:** [E1.7](../PLAN_OPTIMIZACION.md#e17--totales-confiables)
- **Verificación:** sin verificación independiente
- **Qué pasa:** SwCargaTotales se inicializa por indice logico NoComb, se marca al fin de venta por posicion fisica PosDispActual (lin[4] de la trama 'A'), se limpia por posicion fisica i de la respuesta, y el barrido envia 'C'+pos+k con k=1..NoComb tratando el indice logico como posicion fisica. TotalLitros se guarda por indice logico xpr pero TOTAL usa TotalLitros[PosDispActual]. Solo es coherente si los HoseId son exactamente 1..NoComb.
- **Evidencia:** 682: SwCargaTotales[NoComb]:=true; 1247: SwCargaTotales[PosDispActual]:=True; 1289-1293: if TPos[xpr]=i then begin TotalLitros[xpr]:=...; SwCargaTotales[i]:=false; end; 1361: 'C'+IntToClaveNum(PosicionCargaActual2,2)+IntToStr(PosicionDispenActual)+'0' con PosicionDispenActual en 1..NoComb; 1790-1792: ToTalLitros[PosDispActual]:=ToTalLitros[PosDispActual]+volumen.
- **Impacto:** Con mangueras en posiciones fisicas no contiguas (p.ej. HoseId 1 y 3, o diesel solo en 3) la manguera fisica 3 nunca se consulta, su flag nunca se limpia, la 'C' de la posicion 2 provoca el livelock del hallazgo anterior y TOTAL devuelve totales de otra manguera o estimados.
- **Recomendación:** Normalizar todo por indice logico xpr: marcar SwCargaTotales[xpr] donde TPos[xpr]=PosDispActual, enviar 'C'+pos+IntToStr(TPos[xpr]) y al recibir buscar xpr con TPos[xpr]=i; en AgregaPosCarga validar HoseId en 1..4 y unico por posicion. Probar con una configuracion HoseId {1,3}.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="WAY-03"></a>
#### WAY-03 · 🟠 Alta · protocolo · bug — Fin de venta 2->1 se publica con importe/volumen no finales (Estatus se escribe antes de la logica virtual)

- **Ubicación:** `UIGASWAYNE.pas` líneas 1011-1018, 1037-1046, 1250-1271, 1317-1319, 1385-1387
- **Módulos afectados:** UIGASWAYNE, UIGASBRIDGE
- **Se atiende en:** [E1.9](../PLAN_OPTIMIZACION.md#e19--coherencia-del-estado-publicado-estatus-fin-de-venta-horaocc-estado)
- **Verificación:** sin verificación independiente
- **Qué pasa:** En la trama 'B' el Estatus del JSON se actualiza con el valor crudo antes de aplicar la conversion a fin de venta virtual (2->1 => 3); el mapeo a 2 solo cubre (estatus=3) and swcargando. El snapshot de esa trama sale al Bridge con Estatus=1 e Importe/Volumen de la lectura 'A' anterior (durante el despacho). La lectura final 'A' llega despues; con finventa=0 (siempre, ver hallazgo de finventa) el 3 virtual se convierte en 1 sin publicar nunca 3.
- **Evidencia:** 1011: estatus:=StrToIntDef(ss[xpos],0); 1015-1018: if (estatus=3) and (swcargando) then ActualizaCampoJSON(xpos,'Estatus',2) else ActualizaCampoJSON(xpos,'Estatus',estatus); 1038-1041: if (estatus=1)and(estatusant=2) then begin sw3virtual:=true; ... estatus:=3; end; 1250-1258: if finventa=0 ... if sw3virtual then ... estatus:=1; 1270: Estatus solo se publica en 'A' si estatus=3; 1386: Responder(TlkJSON.GenerateText(rootJSON)) al final de cada trama.
- **Impacto:** Durante una o varias tramas (un 'A' por cada posicion activa de numero menor mas comandos encolados) el Bridge responde STATUS=1 y TRANSACTION con importe/volumen parciales. Si OpenGas cierra la venta al ver un estatus distinto de 2, registra un importe o volumen incorrecto (cobro incorrecto). El estado 3 virtual nunca es visible para OpenGas.
- **Recomendación:** Mover la publicacion de Estatus despues de la logica virtual y publicar 2 mientras swcargando sea true (crudo 1 o 3); publicar 1/3 solo en la rama 'A' despues de actualizar Importe/Volumen/Precio (1265-1271). Validar registrando en LogDispPetRes el orden de snapshots de una venta 2->1.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="WAY-04"></a>
#### WAY-04 · 🟠 Alta · correccion · bug — La cadena de estados 'ss' se sobrescribe dentro del bucle de la trama 'B'

- **Ubicación:** `UIGASWAYNE.pas` líneas 1001, 1011, 1093-1099, 1134-1146
- **Módulos afectados:** UIGASWAYNE
- **Se atiende en:** [E1.9](../PLAN_OPTIMIZACION.md#e19--coherencia-del-estado-publicado-estatus-fin-de-venta-horaocc-estado)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El bucle recorre 'for xpos:=1 to length(ss)' (limite evaluado una sola vez) leyendo ss[xpos], pero cuando una posicion pasa de 2 a 9 se reutiliza ss para armar el comando de paro. Las posiciones siguientes de ese ciclo leen estatus de los caracteres 'E0n' o de memoria fuera de la cadena ($R-). El segundo bucle (enllavado) usa la longitud del ss sobrescrito.
- **Evidencia:** 1096-1098: if estatusant=2 then begin ss:='E'+IntToClaveNum(xpos,2); ComandoConsolaBuff(ss); end; 1011: estatus:=StrToIntDef(ss[xpos],0); 1134: for xpos:=1 to length(ss) do ...; 1141-1143 tambien reutilizan ss para 'h'/'k'.
- **Impacto:** En ese ciclo, una posicion que esta despachando puede leerse como 1 o 0: se dispara fin de venta virtual, SwDesp/SwPidiendoTotales, logs de desconexion y se publica un Estatus erroneo que OpenGas puede interpretar como fin de venta con importe parcial.
- **Recomendación:** Usar una variable local distinta para los comandos (cmd) y conservar la cadena de estados en una variable inmutable (estados:=copy(lin,4,...)).
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="WAY-05"></a>
#### WAY-05 · 🟠 Alta · correccion · bug — Variable 'i' sin inicializar decide si se reanuda (G) o se libera (R) un dispensario detenido

- **Ubicación:** `UIGASWAYNE.pas` líneas 1080-1092
- **Módulos afectados:** UIGASWAYNE
- **Se atiende en:** [E1.9](../PLAN_OPTIMIZACION.md#e19--coherencia-del-estado-publicado-estatus-fin-de-venta-horaocc-estado)
- **Verificación:** sin verificación independiente
- **Qué pasa:** En estatus 8 (detenido) no originado por el sistema, el driver envia G o R hasta 5 ciclos segun 'if i<3', pero i es local de ProcesaLinea y en la rama 'B' nunca se asigna (solo en la rama 'C'). El comportamiento depende de basura en registro/pila. Ademas, la reanudacion automatica revierte un paro hecho en la isla.
- **Evidencia:** 1083-1089: if (not SwParado) then begin inc(ContDetenido); if ContDetenido<6 then begin if i<3 then ComandoConsolaBuff('G'+inttoclavenum(xpos,2)) else ComandoConsolaBuff('R'+inttoclavenum(xpos,2)); end; end; — i solo se asigna en 1284.
- **Impacto:** Respuesta no determinista ante un paro: puede reanudar un despacho que el despachador detuvo (riesgo de seguridad) o enviar 'R' (liberar/fin de venta) a una venta en curso.
- **Recomendación:** Reemplazar por la condicion intencionada (probablemente ContDetenido<3) y decidir con operacion si debe existir la reanudacion automatica; registrar en log cada G/R automatico. Activar los warnings de variable no inicializada del compilador.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="WAY-06"></a>
#### WAY-06 · 🟠 Alta · protocolo · bug — finventa de AUTHORIZE se lee del elemento 6 del comando, que no existe: la espera de fin de venta nunca se activa

- **Ubicación:** `UIGASWAYNE.pas` líneas 1629-1630, 1699-1700, 2322-2329, 1250-1261, 1740-1748
- **Módulos afectados:** UIGASWAYNE, UIGASTEAM
- **Se atiende en:** [E1.3](../PLAN_OPTIMIZACION.md#e13--presets-montos-decimales-y-validaciones)
- **Verificación:** sin verificación independiente
- **Qué pasa:** AutorizarVenta arma 'OCC|OCL pos cantidad comb finv' (5 elementos separados por espacio) pero Timer1Timer toma tipopago del elemento 5 y finventa del elemento 6 (vacio => 0). El comando EFV, que tambien pone finventa, no se genera desde ningun comando del Bridge.
- **Evidencia:** 2329: EjecutaComando(cmd+' '+posCarga+' '+cantidad+' '+comb+' '+finv); 1629-1630: tipopago:=StrToIntDef(ExtraeElemStrSep(Comando,5,' '),0); finventa:=StrToIntDef(ExtraeElemStrSep(Comando,6,' '),0); UIGASBENNETT 1461 y UIGASPAM 1460 leen finventa del elemento 5.
- **Impacto:** El parametro de OpenGas para esperar el pago se ignora: en 1250-1259 el fin de venta virtual se limpia en la primera lectura y la posicion se publica libre antes del PAYMENT; tipopago recibe el valor de finv.
- **Recomendación:** Leer finventa del elemento 5 (como Bennett/PAM) y fijar tipopago de forma explicita, o documentar que Wayne no soporta espera de fin de venta. Probar AUTHORIZE con finv=0 y verificar que la posicion queda en 3 hasta PAYMENT.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="WAY-07"></a>
#### WAY-07 · 🟠 Alta · correccion · bug — AgregaPosCarga no reinicia 'existe' por manguera: tras un producto repetido se descartan todas las mangueras siguientes

- **Ubicación:** `UIGASWAYNE.pas` líneas 651, 653-690
- **Módulos afectados:** UIGASWAYNE
- **Se atiende en:** [E1.8](../PLAN_OPTIMIZACION.md#e18--índices-fuera-de-rango-y-carga-de-posiciones-r-)
- **Verificación:** sin verificación independiente
- **Qué pasa:** existe:=false se ejecuta una vez por posicion, fuera del bucle de mangueras; en cuanto una manguera repite producto, todas las posteriores quedan descartadas. Ademas se compara TComb (ProductId sin mapear) contra xcomb (mapeado por MapeoCombustibles).
- **Evidencia:** 651: existe:=false; 664-667: for k:=1 to NoComb do if TComb[k]=xcomb then existe:=true; if not existe then begin ... TComb[NoComb]:=mangueras.Child[j].Field['ProductId'].Value; — UIGASWAYNE2W 685 y UIGASTEAM 859 ponen existe:=false dentro del bucle.
- **Impacto:** En dispensarios con dos mangueras del mismo producto, el producto de las mangueras siguientes desaparece: AUTHORIZE responde 'Combustible no existe en esta posicion' y no se leen ni publican sus totales.
- **Recomendación:** Mover existe:=false dentro del for j, comparar con el mismo identificador que se almacena (TCombx o TComb) y registrar en log las mangueras omitidas.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="WAY-08"></a>
#### WAY-08 · 🟠 Alta · robustez · bug — Indices fuera de rango por parametros externos con range checking desactivado

- **Ubicación:** `UIGASWAYNE.pas` líneas 627-630, 664-682, 891-898, 1537, 1540, 1771-1779, 2747-2753
- **Módulos afectados:** UIGASWAYNE
- **Se atiende en:** [E1.8](../PLAN_OPTIMIZACION.md#e18--índices-fuera-de-rango-y-carga-de-posiciones-r-)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Varios arreglos estaticos se indexan con valores recibidos de OpenGas sin validar: TPosCarga[1..32] con DispenserId, TComb/TPos[1..4] con NoComb sin tope y TPrec/TDigvol/TDigPreset con HoseId, LPrecios[1..4] con el indice de PRICES, TPosCarga[xpos] en TOTAL, y TabCmnd[201] en EjecutaComando. El proyecto compila con -$R- -$Q-.
- **Evidencia:** 627-630: xpos:=...DispenserId; with TPosCarga[xpos]; 668: inc(NoComb) sin limite; 678-681: TPrec[TPos[NoComb]]...; 1537: LPrecios[CPRECIndice]:=precioComb (CPRECTotal=NoElemStrSep); 1540: 'a'+IntToStr(CPRECIndice) con 2 digitos para >=10; 1773-1779: with TPosCarga[xpos] ... SwCargaTotales[1..4]:=true con xpos solo validado >=1 (2748); 898: until (not TabCmnd[ind].SwActivo)or(ind>200) evalua TabCmnd[201]; PDISPENSARIOS.cfg 17-18.
- **Impacto:** Corrupcion silenciosa de memoria: p.ej. un PRICES con 5 precios escribe sobre las globales declaradas despues de LPrecios (MaxPosCarga, ContDA), cambiando el numero de posiciones sondeadas; DispenserId>32 o TOTALS con posicion>32 escriben fuera de TPosCarga. Posibles AV o comportamiento erratico dificil de diagnosticar.
- **Recomendación:** Validar en la frontera y responder False|...: 1<=DispenserId<=32, NoComb<4, 1<=HoseId<=4, indice de precio 1..4 (o arreglo dinamico), 1<=xpos<=MaxPosCarga con NoComb>0 en TOTALS; reescribir el bucle de EjecutaComando como for ind:=1 to 200. Compilar builds de prueba con {$R+}{$Q+}.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="WAY-09"></a>
#### WAY-09 · 🟠 Alta · correccion · bug — Cambio de precios sin verificacion: precios invalidos o rechazados se descartan en silencio

- **Ubicación:** `UIGASWAYNE.pas` líneas 713-724, 1533-1566, 1806-1820, 2048-2073
- **Módulos afectados:** UIGASWAYNE, UIGASBRIDGE
- **Se atiende en:** [E1.6](../PLAN_OPTIMIZACION.md#e16--precios-aplicar-solo-lo-confirmado)
- **Verificación:** sin verificación independiente
- **Qué pasa:** CPREC se responde OK de inmediato (y el Bridge ya confirmo PRICES a OpenGas). En la aplicacion, los precios que no pasan ValidaCifra(precio,2,2) (>=100.00 o con 3 decimales) se saltan sin log ni error; los comandos 'a' se envian con ComandoConsola directo (fuera de la cola, limpiando LineaBuff) con EsperaMiliSeg entre ellos, y el ACK/NAK de la consola no se verifica. LPrecios se actualiza antes de validar. IniciarPrecios (reaplicacion al arranque) es inalcanzable porque PreciosInicio nunca es True.
- **Evidencia:** 1816: rsp:='OK'; // se responde de una vez; 1554-1556: else begin Inc(CPRECIndice); // precio invalido; 1540-1549: ComandoConsola('a'+...); EsperaMiliSeg(250); ...; 1564: AgregaLog('CPREC Finalizado') siempre; 455 y 2066: PreciosInicio:=False (nunca True).
- **Impacto:** Los dispensarios pueden seguir vendiendo al precio anterior mientras OpenGas factura con el nuevo (cobro incorrecto) sin ninguna alerta. Los envios directos pueden corromper la respuesta en curso de otro comando del ciclo.
- **Recomendación:** Encolar los 'a' con ComandoConsolaBuff y confirmar ACK por comando con reintentos; registrar y exponer el fallo (respuesta de TabCmnd con error consultable por RESPCMND y un indicador en el JSON); rechazar explicitamente precios fuera de formato; opcionalmente comparar con el precio leido en la siguiente trama 'A'.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="WAY-10"></a>
#### WAY-10 · 🟠 Alta · protocolo · bug — ACK y NAK no se distinguen, no hay reintentos y la cola de comandos se vacia si la consola tarda mas de 2 s

- **Ubicación:** `UIGASWAYNE.pas` líneas 775-802, 1419-1432, 1749-1768, 2131-2141
- **Módulos afectados:** UIGASWAYNE
- **Se atiende en:** [E2.8](../PLAN_OPTIMIZACION.md#e28--recepción-serial-robusta-tramas-bcc-acknak)
- **Verificación:** sin verificación independiente
- **Qué pasa:** ACK y NAK terminan la trama igual y ProcesaLinea no tiene rama para ninguno; LinCmnd se guarda pero nunca se reenvia. ComandoConsolaBuff descarta toda la cola si el ultimo envio fue hace >2 s; ComandoConsola no envia (sin log) si OutBuffFree es insuficiente pero marca SwEsperaRsp. DVC/PARAR responde OK con solo encolar 'E'.
- **Evidencia:** 1419-1421: if (C=idACK)or(c=idNAK) then FinLinea:=true; 1430-1431: BCC invalido -> LineaTimer:=idNak; 780: LinCmnd:=ss (sin uso posterior); 2133-2136: if SecondsBetween(HoraEnvioPuerto,Now)>2 then begin ListaCmnd.Clear; SwEsperaRsp:=False; end; 790-795: if pSerial.OutBuffFree >= Length(S1) then ...; 1749-1758: rsp:='OK'; ... ComandoConsolaBuff('E'+...).
- **Impacto:** Un STOP ('E'), FINV ('R'), reanudar ('G') o enllavado ('h'/'k') rechazado o descartado no se reintenta y OpenGas ya recibio OK: un paro solicitado puede no ejecutarse y el dispensario sigue despachando.
- **Recomendación:** Implementar ACK/NAK explicito con reintento de LinCmnd (N veces) ante NAK o timeout; expirar solo el comando en curso en lugar de vaciar la cola; confirmar DVC/PARAR verificando estatus 8 en la siguiente 'B' antes de responder OK (como ya se hace con OCC).
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="WAY-11"></a>
#### WAY-11 · 🟠 Alta · robustez · bug — Con la consola sin responder el driver deja de comunicarse con el Bridge (no hay latido)

- **Ubicación:** `UIGASWAYNE.pas` líneas 1886-1898, 1385-1387, 2939-2942, 2950
- **Módulos afectados:** UIGASWAYNE, UIGASBRIDGE
- **Se atiende en:** [E2.1](../PLAN_OPTIMIZACION.md#e21--desacoplar-timer1-sondeo-serial-de-la-conexión-con-el-bridge)
- **Verificación:** sin verificación independiente
- **Qué pasa:** En operacion el unico emisor hacia el Bridge es el finally de ProcesaLinea y Timer2 esta deshabilitado. Si la consola no contesta 'B00' (NumPaso=1), Timer1Timer solo reenvia 'B00' cada 10 ticks y nunca llama ProcesaLinea, por lo que no sale ningun mensaje y, al ser un protocolo pull, el Bridge no puede entregar comandos.
- **Evidencia:** 1887-1891: if (NumPaso=1)and(not swreinicio) then begin inc(ContEspera); if ContEspera<10 then exit; end; 2939-2942 y 2950: Timer2 se apaga si estado>0, puerto abierto y conectado; UIGASBRIDGE.pas 437-440: SecondsBetween(Now,horaAct)>=10 -> CancelarPeticiones y SSocketOG.Active:=False. Bennett 2086 y Wayne2W 2633 tienen un watchdog horaAct que regresa a Timer2.
- **Impacto:** Una falla serial (consola apagada, cable) deja a OpenGas sin poder enviar HALT/TRACE/INITIALIZE, el auto-kick TRACE del Bridge nunca se entrega y a los 10 s el Bridge cancela peticiones y cierra el socket de OpenGas: una falla de dispositivo se convierte en caida del canal de control.
- **Recomendación:** Agregar un latido: si pasaron >500-1000 ms sin envio al Bridge, enviar el JSON desde Timer1Timer (o mantener Timer2 activo como latido independiente); al superar ContadorAlarma publicar Estatus 0 en todas las posiciones para que OpenGas vea la desconexion.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="WAY-12"></a>
#### WAY-12 · 🟠 Alta · robustez · riesgo — Reconexion al Bridge sin las correcciones ya aplicadas a Bennett/Wayne2W

- **Ubicación:** `UIGASWAYNE.pas` líneas 2903-2915, 2917-2952, 2954-2971
- **Módulos afectados:** UIGASWAYNE, UIGASPAM, UIGASTEAM, UIGASTRITON, UIGASHONGYANG, UIGASGILBARCO
- **Se atiende en:** [E2.2](../PLAN_OPTIMIZACION.md#e22--reconexión-no-bloqueante-y-con-manejo-de-errores)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Disconnect no limpia socketResponse; Timer2Timer reactiva el socket sin Active:=False previo y espera con Sleep(10) hasta 101 veces, pero el evento Connect solo se despacha al bombear mensajes del hilo principal (el socket se activo en este mismo hilo), asi que el bucle siempre agota ~1 s bloqueando serial y timers. Responder ante excepcion no marca desconexion. No hay OnError, por lo que un connect rechazado produce excepciones no manejadas en el ciclo de mensajes. El detalle interno de ScktComp tras un connect fallido (reutilizacion/fuga de handle) es de certeza media; la ausencia del patron corregido es cierta.
- **Evidencia:** 2909-2915: conectado:=False; Timer1.Enabled:=False; Timer2.Enabled:=True; 2925-2931: ClientSocket1.Active:=True; for i:=0 to 100 do begin Sleep(10); if conectado then Break; end; 2965-2969: except ... AgregaLogPetRes; GuardarLogPetRes(0). Commit 0d95b7f (Bennett) y UIGASWAYNE2W 3899-3908, 3946, 545-553 agregan Active:=False, Sleep(500), socketResponse:=nil y desconexion en Responder.
- **Impacto:** Tras caidas o reinicios del Bridge la reconexion puede demorar o fallar hasta reiniciar el servicio, cada intento congela el hilo principal ~1 s y pueden acumularse handles/eventos de error en el visor de eventos.
- **Recomendación:** Portar el patron de Wayne2W/Bennett: OnError con ErrorCode:=0 y marca de desconexion, Active:=False antes de reintentar, socketResponse:=nil en Disconnect, sin Sleep (reintentar en el siguiente tick) y Responder que no envie si not conectado. Validar matando PDISPBRIDGE.exe y observando reconexion y numero de handles.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="WAY-13"></a>
#### WAY-13 · 🟠 Alta · protocolo · riesgo — Mensajes del socket sin delimitacion: respuestas concatenadas o parciales pierden comandos

- **Ubicación:** `UIGASWAYNE.pas` líneas 2764-2812, 1386, 2954-2962
- **Módulos afectados:** UIGASWAYNE, UIGASBRIDGE, UIGASPAM, UIGASBENNETT, UIGASTEAM, UIGASHONGYANG, UIGASGILBARCO, UIGASWAYNE2W, UIGASTRITON
- **Se atiende en:** [E6.1](../PLAN_OPTIMIZACION.md#e61--framing-y-buffer-por-conexión-en-los-dos-sentidos-y-del-lado-de-opengas)
- **Verificación:** sin verificación independiente
- **Qué pasa:** ClientSocket1Read asume que cada ReceiveText contiene exactamente un mensaje 'folio|DISPENSERS|CMD|...'. El Bridge envia sin terminador y una respuesta por cada mensaje del driver, y el driver envia un JSON por cada trama serial sin esperar la respuesta anterior, por lo que puede haber varias respuestas en vuelo. SendText tampoco verifica bytes enviados (envio parcial o WSAEWOULDBLOCK en no bloqueante).
- **Evidencia:** 2772-2779: mensaje:=Socket.ReceiveText; folio:=elemento 1; comando:=elemento 3; UIGASBRIDGE.pas 762 y 767: Socket.SendText(IntToStr(p.Folio)+'|'+p.Peticion) / SendText('0|DISPENSERS|NOTHING'); 2958/2962: SendText(resp) sin revisar el resultado.
- **Impacto:** Si dos respuestas llegan juntas (hilo principal ocupado en SaveToFile o EsperaMiliSeg) se parsea folio 0 con comando 'NOTHING15...' y el comando real se pierde; si era AUTHORIZE/PRICES/PAYMENT, el Bridge ya lo confirmo a OpenGas y se descarta sin aviso (preset no aplicado, precio no cambiado). Un INITIALIZE grande partido en dos lecturas falla; un JSON truncado es descartado por el Bridge.
- **Recomendación:** Definir delimitador (p.ej. ETX o CRLF) o prefijo de longitud en ambos sentidos; acumular en un buffer de lectura y procesar todos los mensajes completos; manejar envios parciales con cola de salida y OnWrite. Desplegar Bridge y drivers de forma coordinada (o aceptar ambos formatos durante la transicion).
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** sí

<a id="WAY-14"></a>
#### WAY-14 · 🟠 Alta · rendimiento · optimizacion — JSON completo regenerado, enviado y registrado en el log PetRes en cada trama serial

- **Ubicación:** `UIGASWAYNE.pas` líneas 346-364, 1385-1387, 2934-2937, 2954-2964
- **Módulos afectados:** UIGASWAYNE, UIGASBRIDGE
- **Se atiende en:** [E4.1](../PLAN_OPTIMIZACION.md#e41--responder-al-bridge-en-cuanto-se-procesa-un-comando-y-homologar-la-cadencia)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Cada ProcesaLinea ejecuta GenerateText sobre todo rootJSON y lo envia; Responder agrega 'E '+JSON a ListaLogPetRes copiando caracter por caracter y la lista conserva 10000 lineas (la mitad son JSON completos). No hay throttling ni deteccion de cambios.
- **Evidencia:** 1386: Responder(TlkJSON.GenerateText(rootJSON)); 2964: AgregaLogPetRes('E '+resp); 351-359: for i:=1 to length(lin) do ... lin2:=lin2+lin[i]; 361-362: while ListaLogPetRes.Count>10000 do ListaLogPetRes.Delete(0); Bennett/Wayne2W/Gilbarco/HongYang usan xTurnoSocket (1 de cada 3).
- **Impacto:** Con 3-10 tramas/s y JSON de 2-10 KB (8-32 posiciones) el log PetRes ocupa decenas de MB en RAM, cada envio cuesta miles de concatenaciones y cada GuardarLog escribe archivos de decenas de MB en el hilo principal, bloqueando serial y socket; el Bridge tambien parsea y registra cada snapshot.
- **Recomendación:** Enviar solo si hubo cambios (flag sucio en ActualizaCampoJSON/AddPeticionJSON) o con throttling mas latido periodico; registrar en PetRes solo Peticiones o un resumen del JSON; sustituir la copia char a char por StringReplace o buffer preasignado y usar un buffer circular en lugar de Delete(0).
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="WAY-15"></a>
#### WAY-15 · 🟠 Alta · robustez · bug — Recursion mutua GuardarLog <-> GuardarLogPetRes y guardado de logs en cada excepcion sin rotacion

- **Ubicación:** `UIGASWAYNE.pas` líneas 2479-2511, 959-962, 321-328, 764, 799, 817, 879, 921, 1382, 1445, 1907, 2213, 2248
- **Módulos afectados:** UIGASWAYNE
- **Se atiende en:** [E2.4](../PLAN_OPTIMIZACION.md#e24--bitácoras-que-no-bloquean-append-incremental-rotación-y-sin-json-repetido)
- **Verificación:** sin verificación independiente
- **Qué pasa:** GuardarLog guarda LogDisp y llama GuardarLogPetRes; si el SaveToFile de PetRes falla, su except llama GuardarLog(0), que vuelve a llamar GuardarLogPetRes, y asi sucesivamente. Ademas GuardarLog(0) se invoca desde casi todos los except y periodicamente, con nombres por fecha-hora sin rotacion ni purga.
- **Evidencia:** 2485-2486: ListaLog.SaveToFile(...LogDisp...); GuardarLogPetRes(0); 2500: ListaLogPetRes.SaveToFile(...); 2504-2506: except ... GuardarLog(0); GuardarLog(0) en los except de ValidaCifra (764), ComandoConsola (799), CalculaBCC (817), XorChar (879), EjecutaComando (921), ProcesaLinea (1382), pSerialTriggerAvail (1445), Timer1Timer (1907), ActualizaCampoJSON (2213), AddPeticionJSON (2248).
- **Impacto:** Con disco casi lleno (LogDisp pequeño cabe, PetRes grande no) o el archivo PetRes bloqueado, se escriben LogDisp repetidos hasta llenar el disco o desbordar la pila (caida del servicio). Una excepcion repetitiva (p.ej. en cada tick) escribe archivos de MB varias veces por segundo y llena el disco en horas.
- **Recomendación:** Romper la recursion (GuardarLogPetRes no debe llamar GuardarLog; flag de reentrada), limitar el guardado por excepcion (p.ej. una vez por minuto), rotar/purgar por antiguedad y tamaño, y escribir en append o en un hilo dedicado.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="WAY-16"></a>
#### WAY-16 · 🟠 Alta · correccion · bug — AjusteWayne3 calcula con importe/volumen/precio de la lectura anterior y altera centavos

- **Ubicación:** `UIGASWAYNE.pas` líneas 1190-1206
- **Módulos afectados:** UIGASWAYNE
- **Se atiende en:** [E1.2](../PLAN_OPTIMIZACION.md#e12--importes-y-volúmenes-de-venta-mal-calculados)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Dentro de with TPosCarga[xpos], el bloque AjusteWayne3 usa los campos importe, volumen y precio (valores previos) en lugar de ximporte/xvolumen/xprecio recien leidos; ademas redondea el importe al peso cuando los centavos son >=95 o <=5 y repite la condicion AjusteWayne3.
- **Evidencia:** 1199-1205: if (importe<(volumen*precio*0.9)) then ximporte:=trunc(volumen*precio*100)/100 else begin xvol:=ajustafloat(dividefloat(importe,precio),3); if abs(volumen-xvol)<0.02 then xvolumen:=xvol; end; 1192-1197: centavos:=Round(Frac(ximporte)*100); if centavos >= 95 then ximporte:=ximpo+1 else if centavos <= 5 then ximporte:=ximpo; 1191: if AjusteWayne3='Si' redundante.
- **Impacto:** En sitios con AjusteWayne3=Si el importe final publicado puede ser el calculado con datos de la lectura previa y el volumen puede reemplazarse por un valor viejo; el importe difiere hasta 5 centavos del display. Venta/cobro incorrecto.
- **Recomendación:** Usar ximporte/xvolumen/xprecio en todo el bloque, eliminar el if redundante y reconsiderar el redondeo de centavos; crear pruebas de ProcesaLinea con tramas 'A' reales para cada combinacion de AjusteWayne*.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="WAY-17"></a>
#### WAY-17 · 🟠 Alta · concurrencia · riesgo — Esperas activas en el hilo principal (EsperaMiliSeg/Sleep): bloqueo o reentrancia de Timer1Timer/ProcesaLinea

- **Ubicación:** `UIGASWAYNE.pas` líneas 1324-1328, 1533-1550, 1611-1616, 1678-1683, 2560-2565, 2926-2930, 1439-1441
- **Módulos afectados:** UIGASWAYNE
- **Se atiende en:** [E2.5](../PLAN_OPTIMIZACION.md#e25--reentrancia-comandos-del-bridge-durante-una-transacción-serial)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El hilo principal atiende serial, socket y timers, y varios handlers esperan dentro: 1000 ms tras el mapeo, 2x250 ms por producto en CPREC, 500 ms por reintento de preset dentro del bucle de 200 comandos, 300 ms en Iniciar y hasta ~1 s en Timer2Timer. EsperaMiliSeg esta en ULIBGRAL (no incluido): si bombea mensajes (Application.ProcessMessages), durante la espera corren pSerialTriggerAvail (que re-arma Timer1 en su finally), un Timer1Timer anidado y ClientSocket1Read; si usa Sleep, bloquea todo.
- **Evidencia:** 1327: ComandoConsola(ValorMapeo); EsperaMiliSeg(1000); 1541-1549: EsperaMiliSeg(250) x2 antes de Inc(CPRECIndice) en 1551; 1615/1682: esperamiliseg(500); 2560-2565: Sleep(100); ...esperamiliseg(100); 2927-2928: Sleep(10) en bucle; 1440: finally Timer1.Enabled:=true en pSerialTriggerAvail.
- **Impacto:** Con bombeo de mensajes: un Timer1Timer anidado puede reenviar el mismo precio e incrementar CPRECIndice dos veces (saltando un producto), duplicar presets u operar TabCmnd mientras un INITIALIZE lo reinicia. Con Sleep: el hilo queda bloqueado 0.5-1 s, los resultados no llegan al Bridge dentro de TimeoutRespSrv (2 s) y OpenGas recibe Timeout de comandos que si se ejecutaron.
- **Recomendación:** Eliminar las esperas modelando CPREC, reintentos de preset y mapeo como pasos de la maquina de estados (un comando por respuesta o tick); no esperar la conexion en Timer2. Confirmar la implementacion de EsperaMiliSeg y, mientras exista, proteger Timer1Timer y ProcesaLinea con un flag de reentrada.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="WAY-18"></a>
#### WAY-18 · 🟠 Alta · robustez · riesgo — Reinicio diario termina el servicio sin re-arranque y aun con ventas pendientes

- **Ubicación:** `UIGASWAYNE.pas` líneas 1509-1514, 1123-1124, 2713-2721, 297
- **Módulos afectados:** UIGASWAYNE
- **Se atiende en:** [E2.3](../PLAN_OPTIMIZACION.md#e23--arranque-y-paro-ordenados-del-servicio)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Con ReinicioDiario=Si, tras 24 h y 30 s sin ninguna posicion en estatus 2, se ejecuta Detener+Terminar+Shutdown, que llama ServiceThread.Terminate (salida normal, codigo 0). No se revisan posiciones autorizadas (9), en fin de venta (3) o comandos pendientes. En los repos no hay mecanismo de re-arranque (instalador.bat solo hace /INSTALL; las acciones de recuperacion del SCM no aplican a una salida normal).
- **Evidencia:** 1509-1513: if (reinicioDiario) and (HoursBetween(Now,horaInicio)>=24) and (SecondsBetween(Now,horaDespacho)>=30) then begin Detener(0); Terminar(0); Shutdown(0); Exit; end; horaDespacho solo se actualiza con estatus=2 (1123-1124); 2719: ServiceThread.Terminate; el finally de Timer1Timer (1911) re-arma Timer1 tras Detener.
- **Impacto:** Si no existe un vigilante externo, la estacion queda sin driver hasta intervencion manual; con un preset autorizado o una venta esperando PAYMENT se pierde el estado en memoria (TabCmnd, flags, totales).
- **Recomendación:** Antes de reiniciar verificar que ninguna posicion este en [2,3,5,8,9] y que TabCmnd no tenga comandos activos; documentar o automatizar el re-arranque (sc failure con flag de fallas no criticas o reinicio coordinado por OpenGas), o preferir una reinicializacion interna sin terminar el proceso.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="WAY-19"></a>
#### WAY-19 · 🟠 Alta · configuracion · bug — Ajuste de digitos del preset inconsistente: DigitoAjustePreset/DigitoAjusteVol/Con_Precio nunca se inicializan

- **Ubicación:** `UIGASWAYNE.pas` líneas 42-45, 594, 678-681, 1966-2015
- **Módulos afectados:** UIGASWAYNE
- **Se atiende en:** [E1.3](../PLAN_OPTIMIZACION.md#e13--presets-montos-decimales-y-validaciones)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Las variables Con_Precio, DigitoAjusteVol y DigitoAjustePreset nunca se asignan (0 desde la version inicial). TDiga[1] recibe Con_DigitoAjuste siempre en el indice 1 y TDigPreset[TPos] recibe 0 solo para posiciones fisicas existentes; TDigPreset[1] queda en -1 si la posicion no tiene manguera en la posicion fisica 1. Con DecimalesPresetWayne=-1 (default) el preset usa TDigPreset[1] o TDiga[1] segun ese accidente. DecimalesPresetWayneLitros fuera de 1..4 deja el valor vacio y DecimalesPresetWayne=0 redondea el importe a entero.
- **Evidencia:** 679: TDiga[1]:=Con_DigitoAjuste; 681: TDigPreset[TPos[NoComb]]:=DigitoAjustePreset; 1984-1990: if TPosCarga[SnPosCarga].tdigpreset[1]>=0 then ndig:=...tdigpreset[1] else ndig:=...tdiga[1]; if ndig>0 then begin sval:=IntToClaveNum(0,ndig)+sval; sval:=copy(sval,1,8); end; 1998-2003: case DecimalesPresetWayneLitros of 1..4 (sin else); 1974-1975: FormatFloat('00000000',SnImporte).
- **Impacto:** Con CONDIGITOAJUSTE>0 y sin DECIMALESPRESETWAYNE, las posiciones sin manguera en la posicion fisica 1 reciben el preset desplazado un digito (200.00 se envia como 20.00) mientras las demas no, aunque la lectura aplica el ajuste a todas. Preset distinto al pagado.
- **Recomendación:** Eliminar las variables muertas o leerlas de INITIALIZE; aplicar el mismo ajuste en preset y lectura por posicion; validar DecimalesPresetWayne en [-1..3] y DecimalesPresetWayneLitros en [1..4] en Inicializar y rechazar OCC con decimales no representables.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="WAY-20"></a>
#### WAY-20 · 🟡 Media · correccion · riesgo — Por omision el volumen publicado se recalcula como importe/precio (no es el medido)

- **Ubicación:** `UIGASWAYNE.pas` líneas 1207-1215
- **Módulos afectados:** UIGASWAYNE
- **Se atiende en:** [E1.2](../PLAN_OPTIMIZACION.md#e12--importes-y-volúmenes-de-venta-mal-calculados)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Con AjusteWayne, AjusteWayne2 y AjusteWayne3 en 'No' (default), si el importe no es menor al 90% de vol*precio se reemplaza el volumen leido por ajustafloat(importe/precio,3); en caso contrario se reemplaza el importe por vol*precio truncado. Si el precio leido es 0, el resultado depende de DivideFloat (ULIBGRAL, no incluido).
- **Evidencia:** 1208-1214: if (ximporte<(xvolumen*xprecio*0.9)) then begin ximporte:=trunc(xvolumen*xprecio*100)/100; ... end else begin xvolumen:=ajustafloat(dividefloat(ximporte,xprecio),3); end;
- **Impacto:** El volumen reportado a OpenGas difiere por redondeo del display y de los totalizadores; relevante para verificacion metrologica y controles volumetricos. Puede ser intencional pero no esta documentado.
- **Recomendación:** Publicar el volumen medido y, si se requiere consistencia importe=vol*precio, hacerlo de forma explicita por variable o en OpenGas; proteger contra xprecio<=0.
- **Esfuerzo:** S · **Riesgo del cambio:** alto · **Toca contrato:** no

<a id="WAY-21"></a>
#### WAY-21 · 🟡 Media · correccion · bug — Heuristicas apiladas para el numero de decimales del importe (x10, /10, /100 vs /1000)

- **Ubicación:** `UIGASWAYNE.pas` líneas 1168-1183
- **Módulos afectados:** UIGASWAYNE
- **Se atiende en:** [E1.2](../PLAN_OPTIMIZACION.md#e12--importes-y-volúmenes-de-venta-mal-calculados)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El importe se lee con 3 decimales, en V3 se cambia a 2 si queda mas cerca de vol*precio, WayneAjusteImporte lo multiplica por 10 y, fuera de V3, se divide entre 10 si 2*vol*precio<importe. Con volumen 0 al inicio de una venta cualquier importe positivo se divide entre 10.
- **Evidencia:** 1174: ximporte:=StrToFloat(simp)/1000; 1177-1179: if (WayneFusionV3='Si')and(xvolumen>0)and(xprecio>0)and(abs(StrToFloat(simp)/100-...)<abs(...)) then ximporte:=StrToFloat(simp)/100; 1180-1181: ximporte:=10*ximporte; 1182-1183: if (WayneFusionV3<>'Si')and(2*xvolumen*xprecio<ximporte) then ximporte:=ximporte/10;
- **Impacto:** Importes transitorios x10 o /10 publicados al Bridge y logica no verificable sin la especificacion de cada version de consola.
- **Recomendación:** Configurar explicitamente los decimales de importe por modelo (V2/V3) en lugar de inferirlos; no aplicar la regla cuando volumen o precio sean 0; pruebas con tramas capturadas.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="WAY-22"></a>
#### WAY-22 · 🟡 Media · correccion · bug — Variable 'xcomb' sin inicializar en la deteccion de avance de venta

- **Ubicación:** `UIGASWAYNE.pas` líneas 1235-1238
- **Módulos afectados:** UIGASWAYNE
- **Se atiende en:** [E1.9](../PLAN_OPTIMIZACION.md#e19--coherencia-del-estado-publicado-estatus-fin-de-venta-horaocc-estado)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El umbral de swAvanzoVenta usa IfThen(xcomb=3,80,40), pero xcomb es local de ProcesaLinea y en la rama 'A' nunca se asigna (en 'B' solo es variable de control de bucles, cuyo valor posterior es indefinido).
- **Evidencia:** 1236: swAvanzoVenta:=(importe<>importeant) and (SwCargando) and (importe>0) and ((importeant>0) or (importe-importeant<IfThen(xcomb=3,80,40)));
- **Impacto:** Umbral aleatorio; con lecturas iniciales grandes la deteccion de fin de venta (SwDesp, SwPidiendoTotales, refresco de totales) se retrasa o se omite.
- **Recomendación:** Usar el producto de la manguera actual (CombActual o CombustibleEnPosicion(xpos,PosDispActual)) calculado antes de la condicion, o eliminarla.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="WAY-23"></a>
#### WAY-23 · 🟡 Media · concurrencia · riesgo — Modelo de hilos: ServiceStop/ServiceShutdown/ServiceExecute tocan las listas de log desde el hilo del servicio

- **Ubicación:** `UIGASWAYNE.pas` líneas 284-330, 2115-2129, 36-41 (UIGASWAYNE.dfm)
- **Módulos afectados:** UIGASWAYNE
- **Se atiende en:** [E0.2](../PLAN_OPTIMIZACION.md#e02--identificar-el-hilo-de-cada-evento-instrumentación)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Verificado: los TTimer del dfm crean su ventana en el constructor (hilo principal, Application.CreateForm en PDISPENSARIOS.dpr) y ClientSocket1 se activa en Timer2Timer, asi que timers y socket comparten el hilo principal (la hipotesis de socket en el hilo del servicio NO aplica a Wayne); APRO entrega OnTriggerAvail sincronizado al hilo principal (certeza media). En cambio OnStop/OnShutdown se ejecutan en TServiceThread (dentro de ProcessRequests) y llaman GuardarLog(0) sin sincronizacion; ServiceExecute crea ListaLog y rootJSON en el hilo del servicio mientras Timer2 (habilitado por omision en el dfm) ya dispara en el principal, y al salir desactiva el socket desde el hilo del servicio.
- **Evidencia:** 2117, 2122, 2128: GuardarLog(0) en ServiceDestroy/Shutdown/Stop; 289-315: creacion de ListaLog/ListaLogPetRes/rootJSON en ServiceExecute; UIGASWAYNE.dfm 36-41: Timer2 sin Enabled=False; 320: ClientSocket1.Active := False en el hilo del servicio.
- **Impacto:** Posible AV o corrupcion de TStringList al detener el servicio (log final perdido, stop colgado). Al arranque, Timer2 puede ejecutar con ListaLog=nil y Host vacio (excepciones tragadas).
- **Recomendación:** En OnStop/OnShutdown solo marcar un flag o PostMessage y hacer el guardado y el cierre del socket/puerto en el hilo principal, o proteger las listas con TCriticalSection; poner Timer2.Enabled=False en el dfm y habilitarlo al final de ServiceExecute.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="WAY-24"></a>
#### WAY-24 · 🟡 Media · protocolo · bug — Comandos '0'/'1': con estado<=0 el '1' deja el driver mudo y el '0' deja Estado=1 con el puerto cerrado

- **Ubicación:** `UIGASWAYNE.pas` líneas 2781-2804
- **Módulos afectados:** UIGASWAYNE, UIGASPAM
- **Se atiende en:** [E5.4](../PLAN_OPTIMIZACION.md#e54--comandos-homogéneos-entre-marcas)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El '1' apaga Timer2 y solo enciende Timer1 si estado>0; con el servicio inicializado pero detenido (0) o sin inicializar (-1) no queda ningun emisor hacia el Bridge. El '0' cierra el puerto y apaga Timer1 sin cambiar estado, por lo que el JSON sigue reportando Estado=1.
- **Evidencia:** 2788-2790: Timer2.Enabled:=False; if estado>0 then Timer1.Enabled:=True; 2795-2801: pSerial.Open:=False; Timer1.Enabled:=False; ... respJson:=False; Timer2.Enabled:=True; (estado sin cambio). Mismo codigo en UIGASPAM 386-410.
- **Impacto:** Un '1' recibido antes de RUN deja al Bridge sin mensajes: no puede entregar RUN y a los 10 s cancela peticiones y cierra el socket OpenGas. Tras '0', OpenGas ve el servicio como operando sin datos reales.
- **Recomendación:** En '1' dejar Timer2 activo cuando estado<=0 (misma expresion del finally de Timer2Timer); en '0' publicar un estado distinto o un indicador de puerto cerrado.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="WAY-25"></a>
#### WAY-25 · 🟡 Media · correccion · bug — Comando de mapeo 'g' armado con indice logico, ProductId sin validar y envio directo con espera de 1 s

- **Ubicación:** `UIGASWAYNE.pas` líneas 1137-1147, 1324-1329, 1450-1495, 1899-1902
- **Módulos afectados:** UIGASWAYNE
- **Se atiende en:** [E1.8](../PLAN_OPTIMIZACION.md#e18--índices-fuera-de-rango-y-carga-de-posiciones-r-)
- **Verificación:** sin verificación independiente
- **Qué pasa:** MapeaPosicion recorre 1..NoComb como si fueran posiciones fisicas y concatena IntToStr(CombustibleEnPosicion), que devuelve TComb[1] cuando no hay TPos coincidente y genera 2 caracteres para ProductId>=10. El campo Mapa nunca se asigna. El comando se envia con ComandoConsola directo y EsperaMiliSeg(1000), una posicion por ciclo, re-procesando la ultima trama 'B'.
- **Evidencia:** 1462-1463: for xpr:=1 to nocomb do ss:=ss+IntToStr(CombustibleEnPosicion(xpos,xpr)); 1483: result:=TComb[1]; 1458: if length(mapa)=nocomb (mapa siempre vacio); 1326-1327: ComandoConsola(ValorMapeo); EsperaMiliSeg(1000); 1139-1146: SwReinicio:=true; ... exit.
- **Impacto:** Con HoseId no contiguos o ProductId de dos digitos se programa un mapeo de productos incorrecto en la consola (la semantica exacta de 'g' no es verificable en el repo); si la consola asocia el nivel de precio al mapeo, una manguera podria vender con el precio de otro producto. El arranque cuesta >=1 s bloqueante por posicion.
- **Recomendación:** Construir el mapeo por posicion fisica 1..4 (buscar xpr con TPos[xpr]=p, '0' si no existe) con grados validados 1..9; encolar 'g' y confirmar ACK en lugar de esperar; documentar el formato del comando.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="WAY-26"></a>
#### WAY-26 · 🟡 Media · correccion · bug — MangueraEnPosicion devuelve un ProductId (TComb[1]) como manguera por omision

- **Ubicación:** `UIGASWAYNE.pas` líneas 2028-2046, 1263-1266
- **Módulos afectados:** UIGASWAYNE
- **Se atiende en:** [E1.8](../PLAN_OPTIMIZACION.md#e18--índices-fuera-de-rango-y-carga-de-posiciones-r-)
- **Verificación:** sin verificación independiente
- **Qué pasa:** La funcion que debe devolver la manguera (TMang) usa TComb[1] como valor por omision cuando PosDispActual no coincide con ningun TPos.
- **Evidencia:** 2034: result:=TComb[1]; 2036-2037: if TPos[i]=xposcarga then result:=TMang[i]; UIGASBENNETT 1755 usa TMang[1] y UIGASPAM 1847 usa 0.
- **Impacto:** El campo Manguera del JSON (y TRANSACTION en el Bridge) puede reportar el producto en lugar de la manguera.
- **Recomendación:** Usar TMang[1] o 0 y registrar la inconsistencia.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="WAY-27"></a>
#### WAY-27 · 🟡 Media · protocolo · bug — ApplyTotalLitrosToJSON indexa PosCarga por xpos-1 en lugar de buscar DispenserId

- **Ubicación:** `UIGASWAYNE.pas` líneas 2253-2288, 1295
- **Módulos afectados:** UIGASWAYNE
- **Se atiende en:** [E1.8](../PLAN_OPTIMIZACION.md#e18--índices-fuera-de-rango-y-carga-de-posiciones-r-)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Asume que PosCarga esta ordenado y sin huecos (DispenserId=indice+1). ActualizaCampoJSON si busca por DispenserId y el Bridge advierte que PosCarga puede llegar en cualquier orden; Wayne2W ya corrigio esta funcion.
- **Evidencia:** 2268-2272: posIndex0 := xpos - 1; if (posIndex0 < 0) or (posIndex0 >= posCargaList.Count) then Exit; posObj := TlkJSONobject(posCargaList.Child[posIndex0]); UIGASWAYNE2W 3314-3322 busca por DispenserId.
- **Impacto:** Con DispenserId no consecutivos (1,2,5,6) o desordenados en INITIALIZE, Hoses[].Total se publica en otra posicion o no se publica. Hoy el Bridge no consume Total, pero forma parte del contrato.
- **Recomendación:** Portar la version de Wayne2W (busqueda por DispenserId) o mantener un mapa xpos->objeto creado en AgregaPosCarga.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="WAY-28"></a>
#### WAY-28 · 🟡 Media · correccion · bug — TOTAL devuelve totalizadores estimados y un importe sin sentido; omite la 4a manguera

- **Ubicación:** `UIGASWAYNE.pas` líneas 1769-1805, 2740-2762
- **Módulos afectados:** UIGASWAYNE
- **Se atiende en:** [E1.7](../PLAN_OPTIMIZACION.md#e17--totales-confiables)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Si 3 s despues de una venta no se leyo el total, se suma el volumen de la venta al total anterior y se responde como real. El importe por manguera se calcula como litros acumulados por LPrecios del mismo indice (indice de manguera usado como indice de producto de PRICES). Solo se reportan 3 mangueras. swAllTotals queda sin inicializar si NoComb=0. TOTALS responde True|0|0|0|0|0|0|folio antes de tener datos.
- **Evidencia:** 1790-1795: ToTalLitros[PosDispActual]:=ToTalLitros[PosDispActual]+volumen; ... swAllTotals:=True; 1798-1800: FormatFloat('0.000',ToTalLitros[1])+'|'+FormatoMoneda(ToTalLitros[1]*LPrecios[1])... (3 mangueras); 1782-1788: swAllTotals solo se asigna dentro del for; 2757.
- **Impacto:** Cortes y conciliaciones con totalizadores estimados o de otra manguera; datos de la manguera 4 nunca reportados.
- **Recomendación:** No estimar: responder pendiente/error sin lectura real; reportar todas las mangueras con HoseId/ProductId; si se requiere importe usar el totalizador de importe de la consola o el precio del producto correcto; formatear con TFormatSettings fijo.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="WAY-29"></a>
#### WAY-29 · 🟡 Media · observabilidad · deuda_tecnica — Excepciones tragadas sin registro y resultados indefinidos

- **Ubicación:** `UIGASWAYNE.pas` líneas 823-844, 1273-1276, 804-821, 846-883, 1477-1495, 1915-1936, 2895-2900
- **Módulos afectados:** UIGASWAYNE
- **Se atiende en:** [E2.4](../PLAN_OPTIMIZACION.md#e24--bitácoras-que-no-bloquean-append-incremental-rotación-y-sin-json-repetido)
- **Verificación:** sin verificación independiente
- **Qué pasa:** AgregaLog tiene except vacio; la lectura 'A' tiene un except sin 'on E' que solo ajusta SwCargando; CalculaBCC, XorChar, CombustibleEnPosicion y PosicionDeCombustible devuelven un Result indefinido tras una excepcion; una excepcion en ClientSocket1Read no agrega respuesta a Peticiones.
- **Evidencia:** 842-843: except end; 1273-1276: except if estatus<>2 then SwCargando:=false; end; 2895-2899: except on e ... AgregaLogPetRes; GuardarLog(0) (sin AddPeticionJSON).
- **Impacto:** Tramas 'A' corruptas (StrToFloat sobre texto corto) se pierden sin rastro; diagnostico en campo dificil; OpenGas recibe Timeout del Bridge en lugar de un error.
- **Recomendación:** Registrar siempre e.ClassName/e.Message con limitador de frecuencia, inicializar Result antes del try y responder AddPeticionJSON(folio,'False|Excepcion: ...|') en el except de ClientSocket1Read.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="WAY-30"></a>
#### WAY-30 · 🟡 Media · protocolo · riesgo — Comandos asincronos responden True sin validacion sincrona; el resultado real solo via RESPCMND por 1 minuto

- **Ubicación:** `UIGASWAYNE.pas` líneas 885-924, 1569-1571, 1915-1929, 2290-2334, 2448-2477, 2657-2671, 2673-2699
- **Módulos afectados:** UIGASWAYNE, UIGASBRIDGE
- **Se atiende en:** [E5.2](../PLAN_OPTIMIZACION.md#e52--confirmación-real-de-prices-authorize-y-payment)
- **Verificación:** sin verificación independiente
- **Qué pasa:** AUTHORIZE, STOP, START, PAYMENT y TOTALS responden 'True|<folioCmnd>|' sin validar estado del servicio, posicion configurada, estatus ni combustible. La validacion ocurre en Timer1Timer solo despues de una trama 'B' y las entradas de TabCmnd caducan al minuto. En posiciones <=MaxPosCarga no configuradas, comb '00' hace que PosicionDeCombustible devuelva 1 y se envie un preset a una posicion inexistente.
- **Evidencia:** 2329, 2457, 2472, 2666, 2757: AddPeticionJSON(folio,'True|'+IntToStr(EjecutaComando(...))+'|'); 1569: if SwComandoB then ...; 893: (now-TabCmnd[ind].hora)>tmMinuto; 1928: else result:=1.
- **Impacto:** Combinado con la confirmacion inmediata del Bridge (AUTHORIZE/PAYMENT fire-and-forget), OpenGas cree aplicados comandos imposibles; el error real se pierde si no consulta RESPCMND a tiempo; con estado<=0 los comandos nunca se procesan.
- **Recomendación:** Validar sincronamente lo verificable (estado>0, 1<=pos<=MaxPosCarga y NoComb>0, combustible existente, posicion no deshabilitada) y responder False de inmediato; acordar con el Bridge que AUTHORIZE/PAYMENT esperen esa respuesta.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** sí

<a id="WAY-31"></a>
#### WAY-31 · 🟡 Media · protocolo · bug — Posiciones bloqueadas no visibles en STATUS y FULLSERVICE sin efecto

- **Ubicación:** `UIGASWAYNE.pas` líneas 1107-1127, 786, 266, 2336-2421, 2366-2390
- **Módulos afectados:** UIGASWAYNE
- **Se atiende en:** [E5.1](../PLAN_OPTIMIZACION.md#e51--semántica-única-de-estatus-y-campos-de-venta)
- **Verificación:** sin verificación independiente
- **Qué pasa:** LinEstadoGen (estado legado con 7=deshabilitado, 3 en carga=2, ceros en alarma) se calcula y nunca se publica ni se usa; el JSON publica el estatus crudo. BLOCK/UNBLOCK solo cambian SwDesHabilitado, consultado unicamente en EnviaPreset. DesactivaModoPrepago (FULLSERVICE) asigna 'Prepago' igual que SELFSERVICE (patron repetido en todos los drivers).
- **Evidencia:** 1122: else xestado:=xestado+'7'; 1127: LinEstadoGen:=xestado (sin lectores); 1958: if TPosCarga[xpos].SwDesHabilitado then ...; 2380/2383: ModoOpera:='Prepago'.
- **Impacto:** OpenGas no puede saber por STATUS que una posicion esta bloqueada; FULLSERVICE responde True sin hacer nada.
- **Recomendación:** Publicar Estatus 7 (o un campo Bloqueada) para posiciones deshabilitadas coordinando con OpenGas, eliminar LinEstadoGen, y decidir si FULLSERVICE debe poner 'Normal' o responder False|No soportado.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="WAY-32"></a>
#### WAY-32 · 🟡 Media · robustez · bug — Recepcion serial: una trama por evento, sobrantes descartados y sin resincronizacion a STX

- **Ubicación:** `UIGASWAYNE.pas` líneas 1405-1438, 787
- **Módulos afectados:** UIGASWAYNE
- **Se atiende en:** [E2.8](../PLAN_OPTIMIZACION.md#e28--recepción-serial-robusta-tramas-bcc-acknak)
- **Verificación:** sin verificación independiente
- **Qué pasa:** pSerialTriggerAvail extrae una sola trama por evento; los bytes restantes quedan en LineaBuff hasta el siguiente evento y ComandoConsola los borra. No se descarta basura previa a STX, no hay limite de longitud y Linea no se limpia cuando expira la espera. Acumulacion char a char con delete(LineaBuff,1,1).
- **Evidencia:** 1409-1422: while (not FinLinea)and(Length(LineaBuff)>0) do begin c:=LineaBuff[1]; delete(LineaBuff,1,1); Linea:=Linea+C; ...; 787: LineaBuff:=''; 1428: xlin:=copy(lineatimer,2,...) asume STX en la posicion 1.
- **Impacto:** Tramas validas perdidas o procesadas como respuesta del comando siguiente (desfase), esperas de 1.5-5 s y ciclos mas lentos ante ruido en la linea.
- **Recomendación:** Procesar en bucle todas las tramas completas del buffer, descartar bytes hasta STX/ACK/NAK, limitar longitud, limpiar Linea al expirar la espera y usar GetBlock en lugar de GetChar.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="WAY-33"></a>
#### WAY-33 · 🟡 Media · configuracion · bug — INITIALIZE libera la configuracion vigente antes de validar la nueva; StrToInt sin default

- **Ubicación:** `UIGASWAYNE.pas` líneas 293-296, 375-378, 422-427, 432-451
- **Módulos afectados:** UIGASWAYNE
- **Se atiende en:** [E2.7](../PLAN_OPTIMIZACION.md#e27--initialize-idempotente-y-seguro-con-ventas-en-curso)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Con el servicio inicializado, LiberaInicializacion (cierra puerto, borra TabCmnd, estado:=-1) se ejecuta antes de parsear el mensaje. Las variables numericas usan StrToInt sin default y el JSON no se valida (ParseText nil o Consoles vacio terminan en AV capturado). En ServiceExecute, StrToInt del puerto del Bridge y de MinutosLog hacen que el servicio termine si el ini trae un valor no numerico.
- **Evidencia:** 375-378: if estado>-1 then begin ... LiberaInicializacion; end; 423, 425, 427: StrToInt(ExtraeElemStrSep(variable,2,'=')); 432-435: js := TlkJSON.ParseText(json); consolas := js.Field['Consoles']; consolas.Child[0]...; 294, 296: StrToInt(...).
- **Impacto:** Un INITIALIZE mal formado durante la operacion deja des-inicializada una estacion que funcionaba hasta recibir uno correcto; un ini con error impide arrancar el servicio.
- **Recomendación:** Parsear y validar todo en variables locales y solo despues llamar LiberaInicializacion y aplicar; StrToIntDef con valores por omision y mensajes de error especificos.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="WAY-34"></a>
#### WAY-34 · 🟡 Media · robustez · riesgo — Timer1 se re-arma incondicionalmente en finally; con AutoOpen el puerto puede reabrirse tras un HALT

- **Ubicación:** `UIGASWAYNE.pas` líneas 1439-1441, 1910-1912, 790-794, 2423-2446, 2794-2801
- **Módulos afectados:** UIGASWAYNE
- **Se atiende en:** [E2.3](../PLAN_OPTIMIZACION.md#e23--arranque-y-paro-ordenados-del-servicio)
- **Verificación:** sin verificación independiente
- **Qué pasa:** pSerialTriggerAvail y Timer1Timer ponen Timer1.Enabled:=True en su finally sin consultar estado/detenido. Si Detener, LiberaInicializacion o el comando '0' se ejecutan durante un handler (reentrancia) o queda un evento serial pendiente, el sondeo se reactiva; TApdComPort tiene AutoOpen True por omision (no se cambia en el dfm), por lo que OutBuffFree/PutString en ComandoConsola reabririan el puerto (certeza media sobre AutoOpen).
- **Evidencia:** 1440: finally Timer1.Enabled:=true; 1911: finally Timer1.Enabled:=True; 790: if pSerial.OutBuffFree >= Length(S1); UIGASWAYNE.dfm 12-18 sin AutoOpen; 1510-1513: Detener dentro de Timer1Timer.
- **Impacto:** Sondeo de la consola con el servicio detenido o deshabilitado por OpenGas; errores repetidos con guardado de logs en cada tick.
- **Recomendación:** Re-armar Timer1 solo si (estado=1) and (not detenido) and pSerial.Open; fijar pSerial.AutoOpen:=False en el dfm.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="WAY-35"></a>
#### WAY-35 · 🟡 Media · robustez · riesgo — Una caida del Bridge suspende el sondeo de la consola

- **Ubicación:** `UIGASWAYNE.pas` líneas 2909-2915, 2939-2942
- **Módulos afectados:** UIGASWAYNE
- **Se atiende en:** [E2.1](../PLAN_OPTIMIZACION.md#e21--desacoplar-timer1-sondeo-serial-de-la-conexión-con-el-bridge)
- **Verificación:** sin verificación independiente
- **Qué pasa:** ClientSocket1Disconnect apaga Timer1, por lo que la consola no se sondea mientras el Bridge esta caido; el sondeo se reanuda solo cuando Timer2Timer reconecta y envia.
- **Evidencia:** 2913: Timer1.Enabled:=False; 2939-2941: if (estado>0) and (pSerial.Open) then begin Timer2.Enabled:=False; Timer1.Enabled:=True; end;
- **Impacto:** Durante un reinicio del Bridge no se siguen ventas en curso, no se leen importes finales ni totales y, segun configuracion de la consola Wayne, esta puede pasar a modo autonomo por falta de host.
- **Recomendación:** Desacoplar: mantener el ciclo serial y suspender solo el envio; al reconectar enviar el snapshot completo de inmediato.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="WAY-36"></a>
#### WAY-36 · 🟡 Media · protocolo · riesgo — PosCarga sin identificador de venta y HoraOcc con resolucion de minutos y hora de autorizacion

- **Ubicación:** `UIGASWAYNE.pas` líneas 635-643, 2017-2018, 1262-1269
- **Módulos afectados:** UIGASWAYNE, UIGASBRIDGE
- **Se atiende en:** [E5.1](../PLAN_OPTIMIZACION.md#e51--semántica-única-de-estatus-y-campos-de-venta)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El snapshot solo trae los ultimos Importe/Volumen/Precio por posicion; no hay consecutivo de venta. HoraOcc es la hora del ultimo preset (no del fin de venta), en formato yyyy-mm-ddThh:nn, y no cambia en ventas no autorizadas por el driver.
- **Evidencia:** 637: posObj.Add('HoraOcc', FormatDateTime('yyyy-mm-dd',HoraOcc)+'T'+FormatDateTime('hh:nn',HoraOcc)); 2017-2018: HoraOcc:=now en EnviaPreset; UIGASBRIDGE ObtenerTranPosCarga 718-720 arma TRANSACTION con esos campos.
- **Impacto:** OpenGas no puede distinguir dos ventas consecutivas iguales en la misma posicion ni ordenar eventos dentro del mismo minuto; riesgo de duplicar u omitir transacciones tras reconexiones.
- **Recomendación:** Agregar un consecutivo de venta por posicion (incrementar en EOT) y hora de fin con segundos; requiere cambios en Bridge y OpenGas.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** sí

<a id="WAY-45"></a>
#### WAY-45 · 🟡 Media · build_despliegue · riesgo — Compilacion con -$R- -$Q-, rutas absolutas de un equipo y sin pruebas automatizadas

- **Ubicación:** `PDISPENSARIOS.cfg` líneas 17-18, 35-39
- **Módulos afectados:** UIGASWAYNE, PDISPENSARIOS
- **Se atiende en:** [E0.1](../PLAN_OPTIMIZACION.md#e01--build-reproducible-de-ambos-ejecutables)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El proyecto desactiva range y overflow checking, por lo que todos los indices fuera de rango del driver corrompen memoria en silencio. El .cfg depende de rutas locales (C:\Users\jorge\Dropbox..., \Imagen Ib libs...) y de ULIBGRAL/APRO no versionados. No hay pruebas ni simulador de consola Wayne para validar ProcesaLinea con tramas reales, pese a cambios frecuentes en esta logica (80b88ef, 6b4f482, 82757e3).
- **Evidencia:** PDISPENSARIOS.cfg 17: -$Q-; 18: -$R-; 35: -E"C:\Users\jorge\Dropbox\Proyectos\IgasDispensarios"; 39: -U con rutas \Imagen Ib ...
- **Impacto:** Bugs de memoria no detectables en pruebas; builds no reproducibles en otra maquina; regresiones en calculo de importes/totales sin red de seguridad.
- **Recomendación:** Build de pruebas con {$R+}{$Q+}; versionar o documentar dependencias (ULIBGRAL, APRO, Indy) y rutas relativas; crear un arnes que alimente ProcesaLinea con tramas capturadas de LogDisp y verifique el JSON resultante.
- **Esfuerzo:** M · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="WAY-37"></a>
#### WAY-37 · ⚪ Baja · memoria_recursos · bug — Fugas de TIniFile y del arbol JSON de INITIALIZE

- **Ubicación:** `UIGASWAYNE.pas` líneas 291, 432, 453, 109
- **Módulos afectados:** UIGASWAYNE
- **Se atiende en:** [E2.7](../PLAN_OPTIMIZACION.md#e27--initialize-idempotente-y-seguro-con-ventas-en-curso)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El TIniFile de ServiceExecute nunca se libera y el resultado de TlkJSON.ParseText de cada INITIALIZE tampoco (ahora INITIALIZE puede repetirse). 'productos' se lee y no se usa; ListaComandos se declara y nunca se crea.
- **Evidencia:** 291: config:= TIniFile.Create(...) sin Free; 432: js := TlkJSON.ParseText(json) sin Free; 453: productos := js.Field['Products'] sin uso.
- **Impacto:** Fuga acumulativa en sitios que reinicializan con frecuencia; menor.
- **Recomendación:** try/finally con js.Free y config.Free; eliminar variables sin uso.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="WAY-38"></a>
#### WAY-38 · ⚪ Baja · seguridad · riesgo — Login sin secreto, Token nunca validado y licencia HASP deshabilitada

- **Ubicación:** `UIGASWAYNE.pas` líneas 2585-2603, 2521-2549, 295, 299
- **Módulos afectados:** UIGASWAYNE, UIGASBRIDGE
- **Se atiende en:** [E8.1](../PLAN_OPTIMIZACION.md#e81--autenticación-licencia-y-modo-emulación)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Login compara el password con MD5(usuario|fecha|hh:nn), calculable por cualquiera; el Token se guarda pero ningun comando lo verifica. La validacion HASP esta comentada desde d3bdad5 aunque Licencia/GSentinelKey se leen. El canal Bridge-driver es TCP en claro sin autenticacion.
- **Evidencia:** 2591: if MD5(usuario+'|'+FormatDateTime('yyyy-mm-dd',Date)+'T'+FormatDateTime('hh:nn',Now))<>password then ...; Token solo se asigna en 2594/2601; 2521-2549 comentado.
- **Impacto:** Control de acceso nominal; cualquier proceso que alcance el Bridge controla los dispensarios; la licencia no se aplica.
- **Recomendación:** Si se requiere, usar un secreto compartido (HMAC) y validar Token en comandos de control; restringir ServidorSocket a loopback; decidir explicitamente sobre HASP y retirar el codigo comentado.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** sí

<a id="WAY-39"></a>
#### WAY-39 · ⚪ Baja · mantenibilidad · deuda_tecnica — Codigo muerto y declaraciones engañosas

- **Ubicación:** `UIGASWAYNE.pas` líneas 241, 255, 263, 332-344, 586, 998-999, 1067, 1516-1525, 1577-1580, 1740-1748, 1851-1874, 2048-2073, 7-8
- **Módulos afectados:** UIGASWAYNE
- **Se atiende en:** [E8.3](../PLAN_OPTIMIZACION.md#e83--código-muerto-variables-globales-y-duplicación-interna)
- **Verificación:** sin verificación independiente
- **Qué pasa:** PreciosInicio nunca es True (IniciarPrecios inalcanzable); PrecioFisicoProc/PrecioCambioProc nunca >0; NumPaso 5 se pisa con 0 y StEsperaPaso3 siempre vale 0 (timeouts de pasos 3 y 5 muertos); CERRAR y EFV no se generan desde el Bridge; CRC16, TCombx, Mapa, ListaComandos, TPrecio, MaximoDePosiciones, campos aros_*, ContadorTot y ContEsperaRsp sin uso; la global ListaCmnd (263) queda ensombrecida por el campo homonimo (94); 'tag:=1' dentro de with TPosCarga asigna el Tag del servicio; uses LbCipher, LbString, ComObj, ActiveX y Dialogs sin uso.
- **Evidencia:** 1367 NumPaso:=5 seguido de 1371 NumPaso:=0; 1330/1333 StEsperaPaso3:=0 unicas asignaciones; 455/2066 PreciosInicio:=False; 586/1067 tag:=1 (no es campo de tiposcarga).
- **Impacto:** Dificulta razonar sobre la maquina de estados y oculta bugs reales (p.ej. variables de ajuste nunca inicializadas).
- **Recomendación:** Eliminar en un commit aislado sin cambios funcionales, compilando con hints y warnings activos.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="WAY-40"></a>
#### WAY-40 · ⚪ Baja · rendimiento · optimizacion — ActualizaCampoJSON: busqueda lineal, nil checks que no salen y log por cada posicion no configurada

- **Ubicación:** `UIGASWAYNE.pas` líneas 2169-2216, 1001-1018
- **Módulos afectados:** UIGASWAYNE
- **Se atiende en:** [E4.2](../PLAN_OPTIMIZACION.md#e42--json-más-barato-generar-menos-redondear-y-buscar-menos)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Cada actualizacion (8 por lectura 'A') recorre PosCarga buscando DispenserId; si rootJSON o PosCarga son nil solo registra y sigue (AV posterior + GuardarLog). El bucle 'B' recorre 1..MaxPosCarga, por lo que las posiciones no configuradas generan 'DispenserId no encontrado' en cada ciclo.
- **Evidencia:** 2178-2183: if rootJSON = nil then AgregaLog(...); (sin Exit); 2185-2199: for i := 0 to posArr.Count - 1 ...; 2209: AgregaLog('DispenserId no encontrado en PosCarga.').
- **Impacto:** Ruido en el log (desplaza informacion util del buffer de 10000 lineas) y escrituras de log innecesarias.
- **Recomendación:** Salir temprano en nil; indexar los objetos por DispenserId al crearlos (arreglo [1..32] de TlkJSONobject); omitir posiciones con NoComb=0 en el bucle 'B'.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="WAY-41"></a>
#### WAY-41 · ⚪ Baja · rendimiento · optimizacion — Parseo repetido con ExtraeElemStrSep y concatenaciones O(n2)

- **Ubicación:** `UIGASWAYNE.pas` líneas 398-430, 846-883, 1574-1630, 2605-2655, 2806-2812
- **Módulos afectados:** UIGASWAYNE
- **Se atiende en:** sin item asignado (baja prioridad, ver E8.3)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Inicializar evalua UpperCase(ExtraeElemStrSep(variable,1,'=')) hasta 15 veces por variable; ClientSocket1Read reconstruye parametros llamando NoElemStrSep/ExtraeElemStrSep por elemento; Timer1Timer re-parsea el comando en cada pasada; ObtenerLog concatena todo el log (y devuelve r+1 lineas); XorChar descompone bits en arreglos.
- **Evidencia:** 2807-2808: for i:=4 to NoElemStrSep(mensaje,'|') do parametro:=parametro+ExtraeElemStrSep(mensaje,i,'|')+'|'; 2620-2626: i:=ListaLog.Count-(r+1); ... log:=log+ListaLog[i]+'|'; 854-874: calculo bit a bit.
- **Impacto:** CPU menor en general; un LOG con r grande bloquea el hilo principal y genera un Resultado de MB que viaja en el JSON.
- **Recomendación:** Parsear una vez (split a TStringList), tomar parametros con Copy desde la posicion del tercer '|', limitar r y usar un buffer para LOG; XorChar como Chr(Ord(c1) xor Ord(c2)).
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="WAY-42"></a>
#### WAY-42 · ⚪ Baja · configuracion · deuda_tecnica — Valores operativos fijos en codigo

- **Ubicación:** `UIGASWAYNE.pas` líneas 238-241, 292-294, 361, 839, 893, 1509, 1834-1853, 2133, UIGASWAYNE.dfm 19-41
- **Módulos afectados:** UIGASWAYNE
- **Se atiende en:** [E0.5](../PLAN_OPTIMIZACION.md#e05--configuración-documentada-y-validada-al-arrancar)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Ruta de log 'C:\ImagenCo', Bridge '127.0.0.1:1004' (leido dos veces), MaxEspera2/31/3, 6 ticks para 'C', 10 ticks para 'B', 10000 lineas de log, 200 comandos, caducidad de 1 minuto, vaciado de cola a 2 s, 24 h/30 s del reinicio diario e intervalos de timers en el dfm.
- **Evidencia:** 292: 'C:\ImagenCo'; 293-294: ServidorSocket leido dos veces; 238-240: MaxEspera2=20, MaxEspera31=10, MaxEspera3=20; 1844: ContEsperaPaso5>5; 2133: >2; 893: tmMinuto.
- **Impacto:** Ajustar tiempos a consolas lentas o grandes requiere recompilar.
- **Recomendación:** Mover a [CONF] o a variables de INITIALIZE con defaults actuales y registrarlos en el log de arranque.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="WAY-43"></a>
#### WAY-43 · ⚪ Baja · configuracion · riesgo — Conversiones numericas de protocolo dependientes de la configuracion regional

- **Ubicación:** `UIGASWAYNE.pas` líneas 1535, 1619, 1687, 2297, 2301, 1798-1800
- **Módulos afectados:** UIGASWAYNE
- **Se atiende en:** [E8.2](../PLAN_OPTIMIZACION.md#e82--configuración-regional-locale-explícita)
- **Verificación:** sin verificación independiente
- **Qué pasa:** StrToFloat/StrToFloatDef de importes, litros y precios recibidos de OpenGas, y FormatFloat/FormatoMoneda de la respuesta TOTAL, usan el DecimalSeparator del proceso (servicio bajo LocalSystem). El JSON si es independiente (uLkJSON usa TFormatSettings con '.' en Delphi 7).
- **Evidencia:** 1619: SnImporte:=StrToFLoat(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,3,' ')); 1535: StrToFloatDef(...CPRECComando...,-1); 2297: StrToFloatDef(ExtraeElemStrSep(msj,4,'|'),0).
- **Impacto:** En un equipo con separador ',' los presets fallan con 'Error en Importe', los precios se descartan en silencio y TOTAL devuelve comas.
- **Recomendación:** Usar un TFormatSettings local con DecimalSeparator='.' en todas las conversiones de protocolo.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="WAY-44"></a>
#### WAY-44 · ⚪ Baja · protocolo · optimizacion — Peticiones nunca se vacian, NOTHING genera peticiones y PING casi no se usa

- **Ubicación:** `UIGASWAYNE.pas` líneas 2218-2251, 2818-2819, 2934-2937, 2800
- **Módulos afectados:** UIGASWAYNE, UIGASBRIDGE
- **Se atiende en:** [E6.2](../PLAN_OPTIMIZACION.md#e62--push-de-comandos-resultados-inmediatos-y-ack)
- **Verificación:** sin verificación independiente
- **Qué pasa:** AddPeticionJSON conserva las 2 ultimas peticiones sin limpiarlas tras enviarlas; cada NOTHING agrega {Folio:0}; respJson pasa a True con la primera peticion y solo vuelve a False con '0', por lo que PING solo sale antes del primer comando o tras '0' (donde el Bridge marcara datos obsoletos aunque el driver este bien). Resultados grandes (LOG/LOGREQ) viajan al menos dos veces.
- **Evidencia:** 2236-2237: while petArr.Count >= 2 do petArr.Delete(0); 2244: respJson:=True; 2819: AddPeticionJSON(folio, 'True|'); 2800: respJson:=False.
- **Impacto:** Trafico y log redundantes; semantica de PING ambigua.
- **Recomendación:** Vaciar Peticiones cuando llegue la siguiente orden del Bridge (implica que proceso el envio anterior); no registrar NOTHING como peticion; definir explicitamente el uso de PING.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

