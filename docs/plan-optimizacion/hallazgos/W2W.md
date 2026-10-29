# Hallazgos · W2W · Driver Wayne 2W (Marca 9) · UIGASWAYNE2W.pas

> Anexo del [plan de optimización](../PLAN_OPTIMIZACION.md). Código auditado: `IgasDispensarios@26ccfb4`, `IgasDispensariosBridge@99edafd`. Las líneas pueden haber cambiado: ubica las rutinas por su nombre.

## Cómo funciona este módulo

Driver TService (Togcvdispensarios_wayne2w) para bombas Wayne de lazo de corriente 2 hilos. ServiceExecute (hilo del servicio) solo lee PDISPENSARIOS.ini (RutaLog, MinutosLog, ServidorSocket, MapeoMangueras, DetenerPresetExcedido, ProtocoloExtendido, Licencia), crea listas de log y rootJSON y se queda en ProcessRequests(True). Todo el trabajo real corre en el hilo principal: Timer2 (200 ms, habilitado en el .dfm) activa el TClientSocket hacia el Bridge y envia PING/JSON mientras el servicio no esta corriendo; Timer1 (50 ms) ejecuta una maquina de pasos (NumPaso 0..8) por posicion (PosCiclo) y en su finally envia el JSON completo cada 3 ticks.

Protocolo serial: tramas de 13 bytes 00 00 + 5 pares (dato, complemento) + FF; comandos por bloque (ControlByte = pos*8+cmd): estatus (cmd 1), detener/reanudar/autorizar/Sale End (bloque 0), extendidos 0F xx (precio, importe 2A, volumen 26, digitos 7-8 38h, totales 04/02/16, preset 21h/23h BCD o 39h/3Bh binario en protocolo extendido, cambio de precio 01).

Los comandos del Bridge llegan en ClientSocket1Read ('folio|DISPENSERS|CMD|params'); los que tocan la bomba (AUTHORIZE, STOP, START, PAYMENT, TOTALS, PRICES) se encolan en TabCmnd[1..200] via EjecutaComando y se ejecutan en ProcesaComandos dentro de Timer1; el resto se resuelve en linea. Cada resultado se agrega a rootJSON.Peticiones (max 2) y viaja en el siguiente envio.

Funcionalidades especificas: tolerancia a fallas de estatus y backoff de posiciones sin comunicacion, correccion de importe desbordado (>9999.99) via volumen o digitos 7-8, conversion de importe a litros para presets grandes, vigilancia de preset excedido, cierre forzado con Sale End de transacciones cobradas, segundo puerto (pSerial2) para un segmento extendido y un modo emulacion completo con ventas ficticias.

Modelo de hilos (verificado en el codigo): ClientSocket1.Active:=True solo se ejecuta en Timer2Timer (hilo principal), por lo que la ventana del socket, los TTimer y (por diseno, certeza media) los eventos de Async Pro se despachan en el hilo principal. No hay concurrencia real socket vs timers; el riesgo real es la REENTRADA: TransmiteComando1/2 bombea la cola del hilo principal con ServiceThread.ProcessRequests(False), lo que ejecuta ClientSocket1Read y Timer2Timer anidados a mitad de una transaccion serial. La concurrencia real existe solo con el hilo del servicio (inicializacion en ServiceExecute, GuardarLog en ServiceStop/ServiceShutdown).

Principales riesgos encontrados: importe desbordado aceptado si falla la lectura de volumen, precio 0 en CPREC parcial, STOP que no cancela presets con pistola levantada, precios internos obsoletos tras PRICES, puerto 2 nunca abierto, latencia de respuestas ligada a ticks (pierde el TimeoutRespSrv de 2 s con serial degradado), logs de peticiones con el JSON completo (decenas de MB, O(n^2)) y GuardarLog en cada excepcion.

### Ciclo serial

Timers: Timer1 Interval=50 ms (Enabled=False en .dfm; se prende en Iniciar/RUN, en Timer2Timer si estado>0 y en el finally de TransmiteComando1/2 con estado>0). Por la resolucion de WM_TIMER (~15.6 ms) el periodo minimo real es ~62 ms y cada tick ejecuta como maximo UN paso de UNA posicion. Timer2 Interval=200 ms (habilitado desde el .dfm) solo para el Bridge.

Maquina de estados por posicion (Timer1Timer 2624-2966): NumPaso 0 = leer precios (LeePrecios, una vez tras INITIALIZE y solo si la posicion ya respondio); 1 = estatus (DameEstatus, comando 1; tolerancia MaxFallasEstatus=3 conservando el ultimo estatus; SinComunicacion y backoff PuedeSondear de 10-13 s, o 45-48 s si nunca respondio; deteccion de fin de venta swdesp->[1,3,5]; Sale End cada 10 s para transacciones cobradas abiertas; desautorizacion 2/3->9 con Esperamiliseg(300)+Detener+Esperamiliseg(300)+Reanudar); 2 = lectura final (DameLecturas xFinal: importe 0F 2A, precio 0F 00, y si es final o cerca del limite volumen 0F 26 y digitos 7-8 0F 38), hasta 3 reintentos consecutivos (contleeventa); 3 = totales de una manguera por visita (3 comandos 0F 04/02/16, MaxReintentosTotal=3, libera los TOTAL pendientes con error); 4 = preset + autorizacion al levantar pistola (siempre se visita por el bug de precedencia de la linea 2919); 5 = lectura en proceso para estatus 2/8 y vigilancia de preset excedido; 6 = ProcesaComandos solo en la ultima posicion; 7 = cambio de precios en posiciones inactivas (2 comandos por manguera + 50 ms); 8 = AvanzaPosCiclo. Ademas ProcesaComandos corre al inicio de cada tick si CmndNuevo. AvanzaPosCiclo salta posiciones no recibidas y las inactivas (Estatus<=1) cuyo xCiclo (0,1,2) no coincide con StCiclo: las inactivas y sin comunicacion se visitan cada 3 vueltas. Guardas: SwEspera (vence a los 3 s) contra reentrada de Timer1 y SwPasoBien/goto L01 para saltar pasos que terminaron con exit.

Transaccion serial (TransmiteComando1 1176-1237 / TransmiteComando2 3021-3082): apaga Timer1, iBytesEsperados=13, por intento: limpia sRespuesta, FlushInBuffer/FlushOutBuffer, PutChar byte a byte con spin 'repeat ProcessCommunications until OutBuffUsed=0', luego espera hasta bListo (>=13 bytes acumulados en pSerialTriggerAvail) o vencimiento de GtwTimeout (300 ms por defecto; se reinicia con cada fragmento recibido) bombeando la cola con ServiceThread.ProcessRequests(False) en un bucle sin bloqueo (CPU 100%). Acepta solo longitud exacta 13; si no, Sleep(GtwTiempoCmnd=50 ms) y reintenta hasta GtwIntentos (2). En finally Timer1.Enabled:=estado>0. Los triggers de datos F0/8A (AddDataTrigger en Iniciar) solo prenden bEndOfText/bLineFeed, que no se usan. DesEmpacaWayne valida 00 00 ... FF y los complementos, pero no que el byte de control de la respuesta corresponda a la posicion/comando enviado. Tramas parciales: se acumulan; mas de 13 bytes = fallo y reintento (sin resincronizacion ni busqueda de cabecera); una respuesta tardia que llega despues del Flush del siguiente comando se toma como respuesta de ese comando.

Esperas activas: spin de envio por byte, spin de PeekMessage en la espera, Sleep(50) entre reintentos, Esperamiliseg(50) en LeePrecios/CambiaPrecios/OCC/OCL/DameEstatus, Esperamiliseg(300) x2 en desautorizacion y Sleep(500)+101xSleep(10) en Timer2Timer (que puede correr anidado en la espera serial cuando el Bridge esta caido).

Tiempos efectivos aproximados (5760 bps, bomba que responde de inmediato): un comando ~50-70 ms; posicion inactiva visitada = 2 ticks (estatus + paso 4 vacio) ~180-200 ms; posicion despachando = 3 ticks y 3 comandos ~350-400 ms; lectura final 2-4 comandos. Con 16 posiciones (2 despachando) una vuelta tarda ~1-2 s y una pistola levantada en posicion inactiva puede tardar hasta 3 vueltas en detectarse. Con una posicion que no responde cada comando cuesta 2x(300+50)=~0.65 s y un tick de lectura final puede llegar a ~2.8 s; en ese escenario el envio al Bridge (cada 3 ticks) supera 2 s y dispara el watchdog de Timer1 y el TimeoutRespSrv del Bridge.

Hilos: los eventos de Timer1/Timer2/ClientSocket1 corren en el hilo principal (certeza alta: el socket se activa en Timer2Timer y TTimer asigna su ventana al crearse el modulo en Application.CreateForm); los eventos de Async Pro se reciben a traves del bombeo de mensajes del hilo principal (certeza media, inferida porque la espera depende de ProcessRequests para que bListo cambie). Por eso el riesgo es reentrada anidada (ClientSocket1Read y Timer2Timer dentro de una transaccion), no concurrencia real entre socket y timers.

### Contrato con el Bridge, visto desde este módulo

- **Conexión:** TClientSocket ctNonBlocking (ClientSocket1, Port=0 en .dfm). Host/Port se toman en ServiceExecute de [CONF] ServidorSocket (default 127.0.0.1:1004, StrToInt sin default para el puerto; lineas 420-421). La conexion la abre Timer2Timer (lineas 3900-3913) en el hilo principal; OnConnect pone conectado:=True y horaAct:=Now (3935-3940). No habla directo con OpenGas.
- **Ciclo de envío:** Dos emisores: (a) Timer2 (200 ms) mientras estado<=0 o no conectado: envia PING o JSON y en su finally se re-habilita con (not conectado) or (estado<=0) (3931); si estado>0 habilita Timer1 y se apaga (3920-3923). (b) Timer1, en el finally de cada tick, envia TlkJSON.GenerateText(rootJSON) cuando xTurnoSocket=3, es decir cada 3 ticks (2640-2642, 2959-2960), sin importar si llego respuesta al envio anterior; el periodo real depende de la duracion de los pasos seriales (aprox. 0.2-0.4 s sano, >2 s con posiciones sin respuesta). (c) Iniciar (RUN) envia el JSON de inmediato dentro de ClientSocket1Read (3701). Las respuestas del Bridge (comando o '0\|DISPENSERS\|NOTHING') refrescan horaAct.
- **PING vs JSON:** respJson inicia en False y AddPeticionJSON lo pone en True en la primera peticion y nunca se regresa a False (3290). Por lo tanto solo antes de la primera peticion (normalmente INITIALIZE) Timer2 envia 'PING'; despues siempre JSON completo. Timer1 nunca envia PING. A diferencia de Wayne/PAM, no hay rama que regrese a PING (Wayne lo hace en el comando '0').
- **Peticiones:** AddPeticionJSON (3264-3297): crea rootJSON.Peticiones si no existe, elimina por el frente mientras Count>=2 y agrega {Folio, Resultado}; marca respJson. Las peticiones NUNCA se eliminan despues de enviarse: cada JSON re-envia las dos ultimas (incluidas las {Folio:0,'True\|'} que agrega cada NOTHING), y un resultado se pierde si llegan dos respuestas del Bridge antes del siguiente envio. Resultados grandes (LOG/LOGREQ) se re-envian en cada JSON hasta que dos peticiones nuevas los desplacen.
- **Reconexión:** ClientSocket1Disconnect: conectado:=False, socketResponse:=nil, Timer1 off, Timer2 on (3942-3949). Responder con excepcion hace lo mismo y ademas ClientSocket1.Active:=False (546-554). Watchdog en Timer1: si SecondsBetween(Now,horaAct)>=2 cierra el socket, apaga Timer1 y prende Timer2 (2633-2638). Timer2Timer: socketResponse:=nil, Active:=False, Sleep(500), Active:=True y espera 101 x Sleep(10) a que conectado sea True; como OnConnect se despacha por mensajes en el mismo hilo principal, la espera nunca puede tener exito: siempre sale por 'if not conectado then Exit' y la conexion se completa cuando el hilo vuelve al bucle de mensajes; el siguiente tick de Timer2 ya encuentra conectado=True. Cada intento bloquea el hilo principal ~1.5 s. Ademas TransmiteComando1/2 re-habilitan Timer1 en su finally (estado>0), por lo que durante la desconexion Timer1 y Timer2 corren a la vez y Timer2 puede ejecutarse anidado dentro de una espera serial.
- **Comandos:**
  - NOTHING -> AddPeticionJSON(folio 0,'True\|') en cada respuesta vacia del Bridge (3980-3981)
  - INITIALIZE -> Inicializar: si estado>-1 llama LiberaInicializacion (cierra puertos, limpia TabCmnd, estado -1); parsea JSON (Consoles/Dispensers/Products) y variables CRLF (WTWDIVIMPORTE, WTWDIVLITROS, GTWTIMEOUT, GTWTIEMPOCMND, GTWINTENTOS, WTWPOSINIEXT, MODOEMULACION); configura pSerial/pSerial2 sin abrirlos; AgregaPosCarga; LPrecios[ProductId]; estado 0 (807-901)
  - PARAMETERS -> 'True\|' sin efecto
  - PRICES -> IniciaPrecios encola 'CPREC p1\|p2\|..' y responde True si hay lugar en TabCmnd (3579-3595); el Bridge ya confirmo a OpenGas
  - AUTHORIZE -> AutorizarVenta: params pos\|comb\|importe\|litros\|finv; litros>0 => 'OCL', si importe numerico => 'OCC'; finv '0' => EsperaFinVenta 1, cualquier otro => 0 (invertido); responde 'True\|<folioCmnd>\|' (3342-3386)
  - STOP -> 'DVC pos'; START -> 'REANUDAR pos'; PAYMENT -> 'FINV pos' (encolados, respuesta inmediata 'True\|folio\|')
  - SELFSERVICE/FULLSERVICE -> cambia ModoOpera (sin efecto en modo serial, solo emulacion)
  - BLOCK/UNBLOCK -> SwDesHabil (0 = todas); no se envia nada a la bomba ni se publica en JSON
  - TOTALS -> encola 'TOTAL pos' y responde 'True\|0\|0\|0\|0\|0\|0\|folio\|' (3868-3890); el valor real se obtiene con RESPCMND
  - RESPCMND -> ResultadoComando(folio): '*' = pendiente; 'OK..' => 'True\|..' (3800-3826)
  - HALT -> Detener (cierra pSerial, estado 0, Timer2 on); RUN -> Iniciar (abre pSerial, AddDataTrigger, estado 1, Timer1 on, envia JSON); SHUTDOWN -> ServiceThread.Terminate si estado<=0; TERMINATE -> cierra puerto, LPrecios=0, estado -1
  - LOGIN/LOGOUT -> MD5(usuario\|yyyy-mm-ddThh:nn) y Token (no se usa en ningun comando)
  - TRACE -> GuardarLog(folio); SAVELOGREQ -> GuardarLogPetRes(folio); LOG/LOGREQ -> ultimas r lineas de ListaLog/ListaLogPetRes concatenadas en el Resultado
  - STATE/STATUS/TRANSACTION existen en TMetodos pero no tienen rama: caen en 'False\|Comando desconocido\|' (los contesta el Bridge desde el snapshot)
  - Mensajes de 1 caracter ('folio\|DISPENSERS\|0' o '\|1', comando '1' del Bridge) -> 'False\|Comando desconocido\|' (Wayne y PAM si los manejan)
- **Campos JSON:**
  - Estado (raiz, SetEstadoJSON: -1 sin inicializar, 0 detenido, 1 corriendo)
  - PosCarga[] (una entrada por DispenserId recibido 1..32 en el orden de INITIALIZE, mas huecos hasta MaxPosCarga con Hoses vacio)
  - PosCarga[].DispenserId
  - PosCarga[].HoraOcc ('yyyy-mm-ddThh:nn', se fija al leer la venta final o al aceptar el preset)
  - PosCarga[].Manguera (TMang[PosActual], se actualiza en cada EstatusDispensarios)
  - PosCarga[].Combustible (TComb[PosActual])
  - PosCarga[].Estatus (0 sin com, 1 inactivo, 2 despachando o lectura final pendiente, 3 fin de venta, 5 pistola levantada, 8 detenida, 9 autorizada; nunca 7 aunque este bloqueada)
  - PosCarga[].Importe / Volumen / Precio (lecturas en proceso y finales; no se limpian al pagar)
  - PosCarga[].Hoses[] {HoseId, ProductId, Total} (Total = totalizador en litros por indice de manguera, ApplyTotalLitrosToJSON)
  - Peticiones[] {Folio, Resultado} (max 2)
- **Desviaciones respecto a otros drivers:**
  - Timer2Timer cierra el socket y duerme 500 ms antes de reconectar (solo Wayne 2W); los demas solo hacen Active:=True + espera de 1 s.
  - Watchdog de 2 s sin lectura del Bridge en Timer1 (2633-2638), compartido solo con Bennett (UIGASBENNETT.pas:2086); los demas drivers no cierran el socket por silencio.
  - Responder en error apaga Timer1, cierra el socket y prende Timer2 (546-554); en Wayne (UIGASWAYNE.pas:2954) solo se registra el error.
  - No soporta los comandos de 1 caracter 0/1 que el Bridge encola con comando '1' (UIGASBRIDGE.pas:291-292); Wayne y PAM si (abren/cierran el puerto y regresan a PING).
  - Timer2 habilita Timer1 con estado>0 sin verificar pSerial.Open (Wayne y PAM si lo verifican).
  - Respuestas solo por el envio de Timer1 cada 3 ticks (no por tiempo); la latencia de un resultado depende de la duracion de los pasos seriales y puede superar TimeoutRespSrv=2 s del Bridge.
  - ModoOpera (SELFSERVICE/FULLSERVICE) no tiene efecto en modo serial; Gilbarco auto-autoriza en 'Normal' (UIGASGILBARCO.pas:2761).
  - BLOCK no se refleja en PosCarga[].Estatus (el '7' solo existe en la cadena xestado, que no se publica).
  - PAYMENT puede ser rechazado por el driver (lectura final pendiente, estatus fuera de [3,4]) aunque el Bridge ya lo confirmo a OpenGas.
  - El log de peticiones (LOGREQ) contiene el texto 'PING' y el Bridge descarta cualquier mensaje que contenga 'PING' (AnsiContainsText, UIGASBRIDGE.pas:757), con lo que un JSON con ese Resultado se ignora completo.
  - Incluye modo emulacion activable por variable de INITIALIZE que genera ventas ficticias y publica PosCarga como si fueran reales.
  - TOTALS responde 3 mangueras con importe = litros x precio de INITIALIZE (LPrecios), limitado a 80 caracteres (RegCmnd.Respuesta string[80]).

### Bloques duplicados con otros módulos

| Rutina | Líneas | Nota |
|---|---|---|
| AgregaLog / AgregaLogPetRes | 459-511 | Concatenacion caracter por caracter con sustitucion de SOH/STX/ETX/ACK/NAK/ETB y tope de 10000 lineas con Delete(0). Copias en UIGASWAYNE.pas:823/346, UIGASBENNETT.pas:617/637, UIGASTEAM.pas:1412/1426, UIGASPAM.pas:599/619, UIGASHONGYANG.pas:469/416, UIGASGILBARCO.pas:355/383, UIGASTRITON.pas:240/204 y UIGASKAIROS.pas:593/613. |
| CRC16 | 513-532 | Calculo CRC16 con TCRC copiado del contrato OpenGas; codigo muerto en este driver. |
| Responder | 534-557 | Envio por socketResponse o ClientSocket1.Socket y log 'E '. Variante: aqui el error apaga Timer1, cierra el socket y prende Timer2; en UIGASWAYNE.pas:2954 solo registra. Tambien en BENNETT:409, TEAM:482, PAM:485, HONGYANG:450, GILBARCO:411 y TRITON:367. |
| GuardaLogComandos | 559-576 | Volcado de TabCmnd a archivo copiado de los drivers legados; muerto aqui y con 'Exception.Create' sin raise. |
| AgregaPosCarga | 578-734 | Inicializacion de TPosCarga[1..32] y construccion de PosCarga/Hoses en rootJSON a partir de Dispensers de INITIALIZE (reutiliza el nodo, con huecos hasta MaxPosCarga). Patron compartido con UIGASWAYNE.pas:566, BENNETT:761, TEAM:736, PAM:1896, HONGYANG:643, GILBARCO:1676 y TRITON:573. |
| IniciaPSerial / IniciaPSerial2 | 736-805, 3096-3165 | Parseo 'tipo,COMn,baud,paridad,databits,stopbits'. Duplicado interno (pSerial vs pSerial2) y copiado en UIGASWAYNE.pas:495, BENNETT:657, TEAM:1445, PAM:644, HONGYANG:489, GILBARCO:1837, TRITON:667 y KAIROS:1242. |
| Inicializar / LiberaInicializacion | 807-927 | Parseo de INITIALIZE (Consoles/Dispensers/Products y variables CRLF) y reinicializacion en caliente (commit 6b4f482). Mismo esquema en UIGASWAYNE.pas:366, BENNETT:2399, TEAM:621, PAM:2643, HONGYANG:560, GILBARCO:1925 y TRITON:490. |
| ExtraeElemStrEnter / NoElemStrEnter | 929-967 | Separacion por CRLF con concatenacion caracter por caracter. Copias en UIGASWAYNE.pas:2075/2099, BENNETT:2652/2676, TEAM:3013/3036, PAM:2807/2791, GILBARCO:2079/2059 y KAIROS:1075/1320. |
| MD5 / Login / Logout | 969-979, 3712-3730 | MD5 con Indy y 'password' = MD5(usuario\|fecha-hora-minuto) sin secreto. Identico en UIGASWAYNE.pas:701/2585, BENNETT:2549/2535, TEAM:3052/1037, PAM:2844/2830, HONGYANG:840/796, GILBARCO:493/3363, TRITON:1090/960 y KAIROS:819/799. |
| EjecutaComando / ResultadoComando / RespuestaComando | 981-1021, 1061-1076, 3800-3826 | Cola TabCmnd[1..200] con purga por antiguedad de 1 minuto y consulta por folio ('*' = pendiente). Copiado en todos los drivers (WAYNE:885/926/2673, BENNETT:1765/1799/2117, TEAM:2234/3004/1343, PAM:2036/2567/2488, HONGYANG:1143/2531/2452, GILBARCO:772/952/923, TRITON:819/1021/993, KAIROS:846/907/880), incluido el acceso a TabCmnd[201] con la tabla llena. |
| TransaccionPosCarga / ObtenerEstado | 1023-1059 | Respuestas TRANSACTION/STATE del protocolo legado (antes del Bridge); muertas aqui porque el Bridge las contesta desde el snapshot. |
| TransmiteComando1/2 + pSerialTriggerAvail/Data (y pSerial2) | 1078-1113, 1176-1237, 2991-3082 | Transaccion con espera por ServiceThread.ProcessRequests(False). Duplicado interno por puerto; el mismo patron de bombeo esta en UIGASGILBARCO.pas:1270 y 1367. |
| Ramas SegmActual=1 / SegmActual=2 en funciones de comando | 1133-1166, 1277-1420, 1522-1529, 1554-1561, 1577-1586, 1600-1609, 1662-1799, 1829-1890, 1972-1994, 2587-2614 | Mismo cuerpo duplicado para sRespuesta/TransmiteComando1 y sRespuesta2/TransmiteComando2 en LeePrecios, DameEstatus, DetenerDespacho, EnviaSaleEnd, LeeVolumen, LeeDigitos78, DameLecturas, DameTotal, EnviaPresetPesosBomba y CambiaPrecios. |
| Bloques OCC / OCL de ProcesaComandos | 2021-2142, 2143-2244 | Validacion del monto (truncado de 5 a 2 decimales, ValidaCifra) y bloque de emulacion casi identicos entre OCC y OCL. ValidaCifra (2421-2453) tambien esta copiada en BENNETT, GILBARCO, HONGYANG, KAIROS, PAM y WAYNE. |
| ActualizaCampoJSON / AddPeticionJSON / ApplyTotalLitrosToJSON / SetEstadoJSON | 3215-3340, 3828-3838 | Helpers de rootJSON (busqueda lineal por DispenserId, Peticiones con tope de 2, Totales por indice de manguera, Estado). Copias en UIGASWAYNE.pas:2169/2218/2253/2701, BENNETT:473/438/520/563, TEAM:501/535/579/566, PAM:504/563/2926/550, HONGYANG:2758/2807/2856/2842, GILBARCO:3230/3280/3315/3351 y TRITON:1323/281/1372/192. |
| Handlers de comandos simples (AutorizarVenta, DetenerVenta, FinVenta, ReanudarVenta, IniciaPrecios, TotalesBomba) | 3342-3386, 3514-3543, 3579-3595, 3784-3798, 3868-3890 | Validan el parametro y encolan OCC/OCL/DVC/FINV/REANUDAR/CPREC/TOTAL respondiendo 'True\|folio\|'. Mismo esquema en AutorizarVenta de WAYNE:2290, BENNETT:2038, TEAM:902, PAM:2070, HONGYANG:1184, GILBARCO:691, TRITON:784 y KAIROS:1442, y TotalesBomba de WAYNE:2740, BENNETT:2294, TEAM:1215, etc. |
| Bloquear/Desbloquear y ActivaModoPrepago/DesactivaModoPrepago | 3183-3213, 3388-3479 | Pares casi identicos entre si (solo cambia el valor asignado) y copiados en todos los drivers (Bloquear en WAYNE:2336, BENNETT:2327, TEAM:1070, PAM:2583, HONGYANG:2594, GILBARCO:505, TRITON:1464 y KAIROS:660). |
| Detener / Iniciar / Shutdown / Terminar | 3481-3512, 3597-3710, 3840-3866 | Ciclo de vida HALT/RUN/SHUTDOWN/TERMINATE con el bloque HASP comentado, comun a los drivers del Bridge. |
| GuardarLog / GuardarLogPetRes / ObtenerLog / ObtenerLogPetRes | 3545-3577, 3732-3782 | SaveToFile de las listas completas con InfoVersionModulo y devolucion de las ultimas r lineas. Copias en WAYNE:2479/2495/2605/2631, BENNETT:1958/1973/1986/2012, TEAM:1363/1376/1387/1399, PAM:2461/2475/2515/2541, HONGYANG:2436/816/2479/2505, GILBARCO:451/474/962/991, TRITON:224/263/1038/1064 y KAIROS:746/759/1336/1359. |
| Timer2Timer | 3892-3933 | Reconexion y envio PING/JSON. Base comun con WAYNE:2917, BENNETT:575, TEAM:354, PAM:319, HONGYANG:2025, GILBARCO:3071 y TRITON:330. Wayne 2W agrega Active:=False + Sleep(500) y no verifica pSerial.Open (Wayne/PAM si). |
| ClientSocket1Connect / ClientSocket1Disconnect / ClientSocket1Read | 3935-4064 | Despacho por GetEnumValue(TMetodos). Igual a WAYNE:2764/2903/2909 salvo horaAct:=Now (aqui) y la rama de comandos de 1 caracter (solo Wayne/PAM). Tambien en BENNETT:320, TEAM:391, PAM:369, HONGYANG:316, GILBARCO:3114 y TRITON:386. |
| ServiceExecute / ServiceStop / ServiceShutdown / ServiceDestroy | 411-457, 3167-3181 | Lectura de PDISPENSARIOS.ini, creacion de listas y rootJSON, y bucle ProcessRequests(True); los eventos de parada solo guardan el log. Plantilla comun a todos los drivers. |
| Watchdog horaAct en Timer1 | 2633-2638 | Cierre del socket si no hay lectura del Bridge en >=2 s; mismo bloque en UIGASBENNETT.pas:2086. |
| EstatusDispensarios / AvanzaPosCiclo / ProcesaComandos (esqueleto) | 1452-1508, 2968-2989, 2004-2419 | Esqueleto heredado del driver legado (cadena xestado/lin del protocolo viejo, rotacion por xCiclo/StCiclo, tabla de comandos OCC/OCL/FINV/EFV/DVC/TOTAL/CPREC). Presente con variaciones en GILBARCO:2951/3010/2109, KAIROS:1832/2068/2224, TEAM:1974 y TRITON:1131. |

## Hallazgos (44)

<a id="W2W-01"></a>
#### W2W-01 · 🔴 Crítica · correccion · bug — Venta mayor a 9,999.99 se cierra con el importe desbordado si falla la lectura de volumen al cierre

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 1620-1640, 1686-1690, 1755-1759, 2787-2803
- **Se atiende en:** [E1.2](../PLAN_OPTIMIZACION.md#e12--importes-y-volúmenes-de-venta-mal-calculados)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El importe llega en 6 digitos BCD y se envuelve en 1,000,000/DivImporte. La correccion (CorrigeDesbordeImporte) depende de que LeeVolumen responda (y de LeeDigitos78 con protocolo extendido). Si LeeVolumen falla (2 intentos de 300 ms), el procedimiento hace Exit sin corregir y sin avisar. DameLecturas devuelve True de todos modos y el paso 2 de Timer1 da por buena la lectura final: SwLecturaFinalPendiente:=false y el JSON pasa a Estatus 3 con el importe envuelto. Los litros se calcularon como importe/precio, asi que son coherentes con el importe equivocado y el chequeo de 0.5 L de la linea 2792 no lo detecta.
- **Evidencia:** CorrigeDesbordeImporte: 'if not LeeVolumen(xPosCarga,xLitros) then Exit;' (1625-1626); DameLecturas: 'if xFinal or (rPesos>=xLimite) or (rPesosAnt>=xLimite) then CorrigeDesbordeImporte(...); result:=true;' (1688-1690). Timer1 paso 2: 'if DameLecturas(PosCiclo,Volumen,Precio,Importe,true) then begin ... SwLecturaFinalPendiente:=false' (2787-2796).
- **Impacto:** Una venta real de $10,500 (420 L) se reporta y cobra como $500 / 20 L. Es una perdida directa en ventas grandes de diesel o flotillas cuando hay ruido en la linea.
- **Recomendación:** Hacer que CorrigeDesbordeImporte devuelva Boolean. En DameLecturas, cuando xFinal o rPesos/rPesosAnt>=xLimite y no se pudo confirmar el volumen (o los digitos 7-8), devolver False y restaurar rLitros/rPrecio/rPesos previos. Asi la lectura final se reintenta (SwLecturaFinalPendiente sigue True y el JSON mantiene Estatus 2). Registrar el evento. Validar en banco con una venta >9,999.99 forzando la falla del comando 0F 26.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="W2W-02"></a>
#### W2W-02 · 🟠 Alta · correccion · bug — CPREC puede programar precio 0.00 en mangueras cuyo producto no viene (o viene invalido) en PRICES

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 624-626, 2391-2401, 2580-2599
- **Se atiende en:** [E1.6](../PLAN_OPTIMIZACION.md#e16--precios-aplicar-solo-lo-confirmado)
- **Verificación:** sin verificación independiente
- **Qué pasa:** TNuevoPrec se inicializa en 0 en AgregaPosCarga. CPREC solo lo sobrescribe para los productos con precio >0 en el mensaje (StrToFloatDef(..,-1)), pero marca TCambioPrecN1 en TODAS las posiciones. CambiaPrecios envia TNuevoPrec de TODAS las mangueras sin validar que sea >0. Si el primer PRICES tras INITIALIZE omite un producto, lo trae vacio, en 0 o con un valor no numerico, esa manguera se programa a $0.00 (val1=val2=0) en los dos niveles de precio. Ademas CPREC no asigna rsp, asi que hereda el texto del comando anterior del mismo ciclo.
- **Evidencia:** 'nprec:=StrToFloatDef(ExtraeElemStrSep(precios,i,'|'),-1); for xp:=1 to NoComb do if (i=TComb[xp]) and (nprec>0) then TNuevoPrec[xp]:=nprec; ... TCambioPrecN1:=true;' (2394-2399); 'xprecio:=Trunc(TPosCarga[xPosCarga].TNuevoPrec[xp]*100+0.01);' (2582) sin validacion.
- **Impacto:** Combustible despachado a precio cero hasta que alguien lo note. El Bridge ya confirmo PRICES a OpenGas (fire-and-forget), asi que nadie recibe un error. Si OpenGas siempre manda la lista completa y valida, el riesgo queda latente.
- **Recomendación:** Inicializar TNuevoPrec con el precio vigente (TPrecio leido o LPrecios) y llevar una bandera por manguera de 'precio nuevo'. Enviar solo las mangueras con precio nuevo >0 y marcar TCambioPrecN1 solo en las posiciones afectadas. Rechazar CPREC con algun precio invalido. Probar con 'PRICES 23.50||25.10', 'PRICES 23.50' y 'PRICES abc'.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="W2W-03"></a>
#### W2W-03 · 🟠 Alta · correccion · bug — STOP/DVC no cancela un preset pendiente con la pistola levantada (estatus 5) ni cuando falla el envio

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 2308-2346, 2849-2865
- **Se atiende en:** [E1.3](../PLAN_OPTIMIZACION.md#e13--presets-montos-decimales-y-validaciones)
- **Verificación:** sin verificación independiente
- **Qué pasa:** DVC solo actua para estatus 2 (DetenerDespacho) y 9 (reprograma 9999.99 y limpia SwPreset solo si el envio tuvo exito). Con preset pendiente y pistola levantada DameEstatus devuelve 5, y con la posicion sin comunicacion devuelve 0. En esos casos no se hace nada, se responde OK y en el siguiente tick el paso 4 (estatus=5, SwPreset, PosPreset=PosMangLev) envia el preset y autoriza. Si la bomba ya estaba autorizada (tbit3), un preset de 9999.99 no quita la autorizacion: la venta cancelada queda abierta hasta 9,999.99.
- **Evidencia:** 'if (TPosCarga[xpos].estatus=2) then begin if DetenerDespacho(xpos) then begin end; end else if (TPosCarga[xpos].estatus=9) then begin if EnviaPresetPesosBomba(xpos,1,9999.99) then begin TPosCarga[xpos].SwPreset:=false; ...' (2333-2343); paso 4: 'if (SwPreset)and(PosPreset=PosMangLev) then ... AutorizaPm' (2852-2857).
- **Impacto:** Una venta prepagada que el cajero cancelo (y posiblemente reembolso) se autoriza igual y el cliente despacha. Diferencias de caja y despacho sin cobro.
- **Recomendación:** En DVC/PARAR limpiar siempre SwPreset, SwPreset2, SwVigilaPreset y PosPreset en cualquier estatus distinto de 2. Si la bomba esta autorizada, enviar un comando real de cancelacion/stop y confirmarlo con DameEstatus. Responder error si no se pudo. Probar: OCC, levantar pistola, STOP antes del siguiente tick.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="W2W-04"></a>
#### W2W-04 · 🟠 Alta · correccion · bug — TPrecio (base de la conversion importe->litros) queda obsoleto despues de un cambio de precios

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 2458-2482, 2683-2686, 2884-2889, 2567-2622, 642
- **Se atiende en:** [E1.6](../PLAN_OPTIMIZACION.md#e16--precios-aplicar-solo-lo-confirmado)
- **Verificación:** sin verificación independiente
- **Qué pasa:** ConvierteImporteALitros usa TPosCarga[x].TPrecio[xp], que solo se lee en el paso 0 (LeePrecios) mientras SwLeePrecios=True. Esa bandera solo se pone en True en AgregaPosCarga y se apaga al primer exito. CambiaPrecios no actualiza TPrecio ni LPrecios, ni reactiva SwLeePrecios. Despues de un PRICES, los presets en pesos mayores al maximo (9,999.99, o 99,999.99 en extendido) se convierten a litros con el precio anterior.
- **Evidencia:** 'xprecio:=TPosCarga[xpos].TPrecio[xp]; ... xlitros:=Trunc(ximporte*100/xprecio+0.000001)/100;' (2471-2476); 'SwLeePrecios:=true' solo en la linea 642; paso 7: 'if CambiaPrecios(PosCiclo) then TCambioPrecN1:=false;' (2888-2889) sin refrescar precios.
- **Impacto:** Con un aumento de precio, un preset de $12,000 a 24.00 (500 L) contra un precio real de 24.50 (489.8 L) sobredespacha ~10 L (~$250). Con una baja, subdespacha.
- **Recomendación:** Al confirmar CambiaPrecios copiar TNuevoPrec a TPrecio (y a LPrecios por producto) o poner SwLeePrecios:=True para releerlos. Mejor aun, leer el precio de la manguera justo antes de convertir. Probar: PRICES con aumento y luego OCC 12000.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="W2W-05"></a>
#### W2W-05 · 🟠 Alta · correccion · bug — Respuesta de TOTAL truncada a 80 caracteres, solo 3 mangueras e importe calculado con precios de INITIALIZE

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 231-239, 2367-2390, 891, 3858-3861
- **Se atiende en:** [E1.5](../PLAN_OPTIMIZACION.md#e15--tabla-de-comandos-tabcmnd-y-respuestas-de-comandos-asíncronos), [E5.3](../PLAN_OPTIMIZACION.md#e53--totals-y-respcmnd-desde-el-snapshot)
- **Verificación:** sin verificación independiente
- **Qué pasa:** La respuesta se guarda en RegCmnd.Respuesta: string[80]. 'OK' + 3 x (litros|importe) supera 80 caracteres en cuanto un totalizador pasa de ~10 millones de litros (12 + 1 + 14 caracteres por manguera), y se trunca en silencio. Solo se reportan TotalLitros[1..3] aunque MCxP=4. El importe es TotalLitros x LPrecios[TComb[k]]: LPrecios se fija en INITIALIZE y nunca se actualiza con PRICES, y el importe no es un totalizador real de dinero. Con NoComb<3 se lee LPrecios[0] (TComb[k]=0), fuera de rango con $R-. Los mensajes de error largos de ConvierteImporteALitros (>80) tambien se truncan.
- **Evidencia:** 'Respuesta  :string[80];' (238); 'rsp:='OK'+FormatFloat('0.000',ToTalLitros[1])+'|'+FormatoMoneda(ToTalLitros[1]*LPrecios[TComb[1]])+...ToTalLitros[3]...' (2383-2385); LPrecios solo se asigna en 891 y se limpia en 3858-3861.
- **Impacto:** Totales incompletos o cortados hacia OpenGas (controles volumetricos/cortes), cuarta manguera omitida e importes totales ficticios despues de cualquier cambio de precio.
- **Recomendación:** Ampliar Respuesta a string largo (AnsiString) o guardar el resultado de TOTAL aparte. Iterar 1..NoComb. Leer el totalizador de importe real de la bomba si el protocolo lo permite (o documentar que es estimado) y no indexar LPrecios sin validar 1..4. Coordinar con OpenGas si cambia el numero de campos.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** sí

<a id="W2W-07"></a>
#### W2W-07 · 🟠 Alta · correccion · bug — El segundo puerto (pSerial2, segmento extendido) nunca se abre y varios comandos siempre salen por el puerto 1

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 855-868, 3084-3094, 3021-3082, 1442, 1913, 1941, 3637-3647, 3491-3495, 3074
- **Se atiende en:** [E1.4](../PLAN_OPTIMIZACION.md#e14--sondeo-que-se-congela-livelocks-y-bloqueos-de-la-máquina-de-estados)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Con dos consoles en INITIALIZE se configura pSerial2 (IniciaPSerial2), pero no existe ningun 'pSerial2.Open:=True': Iniciar solo abre pSerial y solo le agrega triggers a ese puerto. PonPuertoPos pone SegmActual=2 para posiciones >=WtwPosIniExt y todas las funciones que respetan SegmActual van a TransmiteComando2, que falla con el puerto cerrado. Ademas ReanudaDespacho, Autoriza y AutorizaPm usan siempre TransmiteComando1/sRespuesta, aun para el segmento 2. Detener no cierra pSerial2. El mensaje de error de TransmiteComando2 dice 'TransmiteComando1'.
- **Evidencia:** Unicas referencias: 'if pSerial2.Open then pSerial2.Open:=False' (914-915) y comprobaciones en 3056/3070/3102. 'if ( ( TransmiteComando1(DataBlock) ) and ( length(sRespuesta)=13 ) )' en ReanudaDespacho (1442), Autoriza (1913) y AutorizaPm (1941).
- **Impacto:** En instalaciones con dos lazos todas las posiciones del segmento extendido quedan sin comunicacion: no autorizan ni reportan ventas. Ademas cada intento dispara excepcion + GuardarLog.
- **Recomendación:** Abrir pSerial2 en Iniciar (y cerrarlo en Detener/Terminar). Unificar TransmiteComando y las funciones de comando en una sola rutina que reciba el puerto/segmento. Hacer que ReanudaDespacho/Autoriza/AutorizaPm respeten SegmActual. Si no se usa el segmento 2, eliminar el codigo y rechazar INITIALIZE con 2 consoles.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="W2W-08"></a>
#### W2W-08 · 🟠 Alta · robustez · riesgo — GuardarLog(0) en cada excepcion escribe los logs completos a disco; recursion posible entre los guardados

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 1227-1231, 3072-3076, 3545-3577, 479-481, 507-508, 3570-3572
- **Se atiende en:** [E2.4](../PLAN_OPTIMIZACION.md#e24--bitácoras-que-no-bloquean-append-incremental-rotación-y-sin-json-repetido)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Casi todos los except (TransmiteComando1/2, DameEstatus, DameLecturas, DameTotal, Autoriza, CambiaPrecios, ProcesaComandos, Timer1, ActualizaCampoJSON, AddPeticionJSON, etc.) llaman GuardarLog(0). Ese procedimiento hace SaveToFile de ListaLog y de ListaLogPetRes (este ultimo con el JSON completo de cada envio, decenas de MB) a archivos nuevos con marca de tiempo al segundo. Si el adaptador USB-serial se desconecta o el puerto da error, TransmiteComando falla en cada comando y genera ~1 juego de archivos por segundo, bloqueando el hilo principal en cada escritura. Ademas, si falla el SaveToFile de LogDispPetRes, GuardarLogPetRes llama a GuardarLog, que vuelve a llamar a GuardarLogPetRes (recursion hasta desbordar la pila). AgregaLog y AgregaLogPetRes se llaman a si mismos en su except.
- **Evidencia:** TransmiteComando1: 'on e:Exception do begin AgregaLog('Error TransmiteComando1: '+e.Message); GuardarLog(0);' (1228-1231); GuardarLog -> 'GuardarLogPetRes(0);' (3552); GuardarLogPetRes except -> 'GuardarLog(0);' (3572); AgregaLog except -> 'AgregaLog('Error AgregaLog: '+e.Message);' (480).
- **Impacto:** Disco lleno en horas, latencia serial de segundos por cada escritura, posible caida del servicio por desbordamiento de pila.
- **Recomendación:** Quitar GuardarLog de los except y dejar solo AgregaLog. Escribir el log de forma incremental (append a un archivo diario con rotacion por tamano) desde un temporizador, no la lista completa. Limitar la tasa de guardado (p. ej. una vez por minuto como maximo) y romper la recursion con una bandera de 'guardando'. Validar desconectando el adaptador USB durante 10 min y midiendo el disco.
- **Esfuerzo:** M · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="W2W-09"></a>
#### W2W-09 · 🟠 Alta · rendimiento · optimizacion — El log de peticiones guarda el JSON completo de cada envio, concatenado caracter por caracter

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 486-511, 534-545, 3959-3962, 3561-3566
- **Se atiende en:** [E2.4](../PLAN_OPTIMIZACION.md#e24--bitácoras-que-no-bloquean-append-incremental-rotación-y-sin-json-repetido)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Responder registra 'E '+resp con el JSON entero (~330 bytes por posicion) cada vez que Timer1 envia (cada 3 ticks, ~5 por segundo), y ClientSocket1Read registra cada 'R 0|DISPENSERS|NOTHING'. AgregaLogPetRes recorre el texto agregando un caracter a la vez (lin2:=lin2+lin[i]), con O(n) realocaciones por linea, y ListaLogPetRes conserva 10000 lineas: entre 25 y 55 MB de RAM para 16-32 posiciones y solo ~15 minutos de historia. Con Delete(0) sobre 10000 elementos hay un memmove por cada Add.
- **Evidencia:** 'for i:=1 to length(lin) do case lin[i] of ... else lin2:=lin2+lin[i];' (492-501); 'while ListaLogPetRes.Count>10000 do ListaLogPetRes.Delete(0);' (502-503); 'AgregaLogPetRes('E '+resp);' (544).
- **Impacto:** CPU y memoria sostenidas en el hilo principal, que tambien hace el sondeo serial. Archivos de log de decenas de MB en cada GuardarLog y historia util muy corta.
- **Recomendación:** No registrar el JSON completo: registrar solo los cambios (Estatus/importe por posicion) o un resumen, y siempre las Peticiones. Para los caracteres de control usar StringReplace o un buffer preasignado (SetLength + indice). Reemplazar las TStringList circulares por un archivo con append o por una cola circular de tamano fijo en bytes.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="W2W-10"></a>
#### W2W-10 · 🟠 Alta · protocolo · bug — LOG/LOGREQ meten resultados sin limite en Peticiones y el texto 'PING' hace que el Bridge descarte el snapshot

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 3732-3782, 3264-3297, 544
- **Se atiende en:** [E4.4](../PLAN_OPTIMIZACION.md#e44--log-y-logreq-acotados)
- **Verificación:** sin verificación independiente
- **Qué pasa:** ObtenerLog y ObtenerLogPetRes concatenan hasta 10000 lineas (O(n^2)) en un solo Resultado. Ese resultado se queda en rootJSON.Peticiones y se re-envia en cada JSON hasta que dos peticiones nuevas lo desplacen. El log de peticiones contiene lineas 'E PING' y 'E {json}'. El Bridge trata como PING cualquier mensaje que contenga 'PING' (AnsiContainsText, UIGASBRIDGE.pas:757) y entonces no procesa el JSON: la respuesta LOGREQ nunca llega a OpenGas (timeout) y todos los snapshots siguientes se ignoran mientras ese Resultado siga en Peticiones (datos obsoletos y auto-kick TRACE del Bridge). Ademas ObtenerLog devuelve r+1 lineas.
- **Evidencia:** 'for i:=i to ListaLogPetRes.Count-1 do log:=log+ListaLogPetRes[i]+'|'; AddPeticionJSON(folio, log);' (3778-3781); 'while petArr.Count >= 2 do petArr.Delete(0);' (3282-3283); Bridge: 'if not AnsiContainsText(respTxt,'PING') then ProcesaRespuestasJSON(respTxt);'.
- **Impacto:** Un comando de diagnostico puede dejar al Bridge sin datos reales durante minutos en una estacion de poco trafico, y genera JSON de varios MB en cada envio (CPU, memoria y socket).
- **Recomendación:** Limitar r (p. ej. 500 lineas y un tope en bytes). Sacar de Peticiones el resultado despues de enviarlo una vez, o enviarlo en un mensaje dedicado. En el Bridge comparar respTxt='PING' exacto (cambio coordinado). Corregir el calculo del indice inicial (Count-r).
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** sí

<a id="W2W-11"></a>
#### W2W-11 · 🟠 Alta · protocolo · bug — Las respuestas al Bridge salen cada 3 ticks de Timer1: con serial degradado superan los 2 s y el watchdog cierra el socket

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 2633-2642, 2959-2960, 1207-1223, 3054-3068
- **Se atiende en:** [E2.1](../PLAN_OPTIMIZACION.md#e21--desacoplar-timer1-sondeo-serial-de-la-conexión-con-el-bridge), [E4.1](../PLAN_OPTIMIZACION.md#e41--responder-al-bridge-en-cuanto-se-procesa-un-comando-y-homologar-la-cadencia)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Los resultados de comandos solo viajan en el JSON que Timer1 envia cuando xTurnoSocket=3, es decir cada tres pasos seriales y no cada X ms. Un paso con una posicion que no responde cuesta ~0.65 s por comando (2 x (300+50) ms) y una lectura final hasta ~2.8 s, asi que tres ticks pueden pasar de 2 s. En ese caso: (1) el Bridge vence TimeoutRespSrv=2 s y responde 'Timeout excedido' a OpenGas aunque el driver si ejecuto el comando; (2) el watchdog de Timer1 ve SecondsBetween(Now,horaAct)>=2, porque el Bridge solo responde cuando el driver envia, y cierra el socket. El Bridge cancela entonces las peticiones pendientes y se reconecta con los Sleep de Timer2.
- **Evidencia:** 'Inc(xTurnoSocket); if xTurnoSocket>3 then xTurnoSocket:=1;' (2640-2642); 'if (conectado) and (xTurnoSocket=3) then Responder(TlkJSON.GenerateText(rootJSON));' (2959-2960); 'if SecondsBetween(Now,horaAct)>=2 then begin conectado:=False; ClientSocket1.Active:=False;' (2633-2635).
- **Impacto:** Perdida de respuestas (TOTALS, RESPCMND, LOG) y reconexiones en cascada justo cuando la linea serial tiene problemas.
- **Recomendación:** Enviar por tiempo (GetTickCount, cada 200-300 ms) y no por conteo de ticks. Enviar de inmediato (o en el siguiente punto de bombeo) cuando AddPeticionJSON agrega un resultado. Medir el watchdog contra el ultimo envio propio (no cerrar si no se ha enviado nada) y subirlo a >=5 s, alineado con TimeoutDatosObsoletos. Probar desconectando una bomba en despacho.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="W2W-12"></a>
#### W2W-12 · 🟠 Alta · concurrencia · riesgo — Reentrada: el bombeo de mensajes dentro de la espera serial ejecuta ClientSocket1Read y Timer2Timer a mitad de un paso

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 1209-1211, 3054-3056, 3951-4064, 807-927, 3481-3512, 3597-3710, 3892-3913
- **Se atiende en:** [E2.5](../PLAN_OPTIMIZACION.md#e25--reentrancia-comandos-del-bridge-durante-una-transacción-serial)
- **Verificación:** sin verificación independiente
- **Qué pasa:** TransmiteComando1/2 espera la respuesta con ServiceThread.ProcessRequests(False) desde el hilo principal. Esa llamada hace PeekMessage/DispatchMessage de la cola del hilo que llama, no del hilo del servicio. Como el socket se activa en Timer2Timer (hilo principal), cualquier mensaje del Bridge se procesa ANIDADO dentro de la transaccion. INITIALIZE (LiberaInicializacion + AgregaPosCarga reinician TPosCarga y MaxPosCarga), HALT (cierra pSerial), RUN (reinicia PosCiclo/NumPaso y envia JSON) o TERMINATE mutan el estado mientras Timer1 esta a medio paso; al regresar, Timer1 escribe Estatus/lecturas calculadas sobre registros ya reinicializados. Con el Bridge caido Timer2 tambien esta habilitado y su Sleep de ~1.5 s corre dentro de la espera serial, lo que provoca timeouts. No hay concurrencia real socket vs timers (certeza alta). Que los eventos de Async Pro tambien se reciban por este bombeo es inferido (certeza media). Si Esperamiliseg (ULIBGRAL, no incluida) bombea mensajes, tambien podria anidar Timer1/ProcesaComandos (no verificable).
- **Evidencia:** 'repeat ServiceThread.ProcessRequests(False); until ( ( bListo ) or ( timerexpired(etTimeOut) ) or ( not pSerial.Open ) );' (1209-1211). El comentario de las lineas 1234-1235 lo reconoce: 'HALT o INITIALIZE pueden llegar mientras se espera respuesta'.
- **Impacto:** Estados inconsistentes despues de INITIALIZE/HALT en caliente, comandos interrumpidos y timeouts seriales durante la reconexion.
- **Recomendación:** No bombear la cola general en la espera: esperar un evento (TEvent que se prende en TriggerAvail) con MsgWaitForMultipleObjects filtrando solo los mensajes del puerto, o mover el sondeo serial a un TThread propio con una cola de comandos. Diferir INITIALIZE/HALT/RUN/TERMINATE a la cola TabCmnd para que Timer1 los aplique entre pasos.
- **Esfuerzo:** L · **Riesgo del cambio:** alto · **Toca contrato:** no

<a id="W2W-13"></a>
#### W2W-13 · 🟠 Alta · protocolo · bug — PAYMENT lo confirma el Bridge, pero FINV lo puede rechazar en silencio y la venta cobrada reaparece como fin de venta

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 2246-2296, 2025, 2147, 2693-2699, 1289-1301, 3530-3543
- **Se atiende en:** [E5.2](../PLAN_OPTIMIZACION.md#e52--confirmación-real-de-prices-authorize-y-payment)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El Bridge confirma PAYMENT a OpenGas de inmediato y FinVenta solo encola 'FINV'. ProcesaComandos rechaza si Estatus no esta en [3,4] o si SwLecturaFinalPendiente; ese rechazo queda en TabCmnd y nadie lo consulta. Escenario plausible: falla la comunicacion justo al cobrar y despues de 3 fallas la posicion pasa a Estatus 0; el FINV se rechaza, SwVentaPagada no se prende, y al volver la comunicacion la bomba sigue In Use sin pistola con importe>0, asi que DameEstatus devuelve otra vez 3. OpenGas ve un fin de venta que ya cobro, y OCC/OCL rechazan presets (requieren estatus [1,5]) hasta un segundo PAYMENT.
- **Evidencia:** 'if (TPosCarga[xpos].Estatus in [3,4]) then begin if TPosCarga[xpos].SwLecturaFinalPendiente then rsp:='Posicion aun tiene lectura final pendiente' else ... SwVentaPagada:=true' / 'else rsp:='Posicion aun no esta en fin de venta';' (2271-2291); DameEstatus: 'if (importe>0.001) and (not SwVentaPagada) then iStatus:=3' (1290-1292).
- **Impacto:** Posicion bloqueada para prepago o venta reportada dos veces tras un cobro; diferencias entre OpenGas y la bomba.
- **Recomendación:** Registrar el PAYMENT como intencion (SwVentaPagada pendiente) aunque la posicion este temporalmente en 0 o con lectura pendiente, y aplicarlo cuando la venta llegue a 3. Opcionalmente cambiar el contrato para que PAYMENT espere el resultado del driver por folio. Probar: desconectar la linea durante el cobro.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** sí

<a id="W2W-06"></a>
#### W2W-06 · 🟡 Media · robustez · bug — TOTAL sin validar limite superior de la posicion y sin respuesta en posiciones sin comunicacion o en emulacion

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 3868-3881, 2367-2380, 2812, 2836-2844
- **Se atiende en:** [E1.7](../PLAN_OPTIMIZACION.md#e17--totales-confiables)
- **Verificación:** sin verificación independiente
- **Qué pasa:** TotalesBomba solo valida xpos>=1. En ProcesaComandos 'with TPosCarga[xpos]' escribe SwLeeTotales[PosActual]:=True con xpos sin validar: con xpos>100 corrompe memoria ($R- en PDISPENSARIOS.cfg) y con xpos 33..100 o no recibida nunca se lee. La lectura del paso 3 exige estatus>0, asi que con la posicion sin comunicacion el TOTAL queda '*' (pendiente) para siempre. En emulacion SwLeeTotales nunca se limpia y TOTAL nunca se contesta. Solo se refresca la manguera PosActual: las demas pueden reportar totales viejos.
- **Evidencia:** 'if xpos<1 then ...' (3876) y luego 'xpos:=StrToIntDef(...,0); with TPosCarga[xpos] do begin ... SwLeeTotales[PosActual]:=True;' (2368-2378); paso 3: 'if (estatus>0)and(not swdeshabil) then' (2812).
- **Impacto:** OpenGas consulta RESPCMND indefinidamente; posible corrupcion de memoria con un parametro malo; totales desactualizados de mangueras sin venta reciente.
- **Recomendación:** Validar xpos con PosicionRecibida y responder error inmediato si no aplica o si SinComunicacion. Marcar SwLeeTotales en todas las mangueras de la posicion y agregar un timeout que responda error. En emulacion responder desde TotalLitros.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="W2W-14"></a>
#### W2W-14 · 🟡 Media · rendimiento · optimizacion — Espera activa en cada transaccion serial: un nucleo al 100% de forma permanente

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 1201-1211, 3046-3056, 1222, 3067
- **Se atiende en:** [E2.5](../PLAN_OPTIMIZACION.md#e25--reentrancia-comandos-del-bridge-durante-una-transacción-serial)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Por cada byte enviado hay un spin 'repeat ProcessCommunications until OutBuffUsed=0'. La espera de la respuesta es un bucle de PeekMessage sin bloqueo (ProcessRequests(False)) hasta bListo o el timeout. Como el driver pasa casi todo el tiempo en transacciones, el proceso consume un nucleo completo. Entre reintentos hay Sleep(50) que congela el hilo principal sin atender mensajes.
- **Evidencia:** 'pSerial.PutChar(DataBlock[i]); repeat pSerial.ProcessCommunications; until ( pSerial.OutBuffUsed=0 );' (1202-1205); 'repeat ServiceThread.ProcessRequests(False); until ...' (1209-1211).
- **Impacto:** CPU alta en el servidor de la estacion (comparte equipo con POS y otros servicios) y peor latencia para los demas procesos.
- **Recomendación:** Enviar el bloque completo con PutString/PutBlock. Esperar con MsgWaitForMultipleObjects(1,[evento],False,restante,QS_ALLINPUT) o WaitForSingleObject sobre un evento prendido en pSerialTriggerAvail. Medir CPU antes y despues.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="W2W-15"></a>
#### W2W-15 · 🟡 Media · robustez · bug — Timer2Timer bloquea ~1.5 s el hilo principal en cada intento de reconexion y su espera nunca puede tener exito

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 3899-3913, 3931, 1235, 3080, 3942-3949
- **Se atiende en:** [E2.2](../PLAN_OPTIMIZACION.md#e22--reconexión-no-bloqueante-y-con-manejo-de-errores)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Timer2Timer hace Sleep(500), Active:=True y espera 101 x Sleep(10) a que conectado sea True. OnConnect se despacha por mensajes en el mismo hilo (WSAAsyncGetHostByName y FD_CONNECT), asi que durante los Sleep no puede llegar: siempre sale por Exit y la conexion se completa al volver al bucle de mensajes. Mientras tanto, TransmiteComando re-habilita Timer1 (estado>0) y el watchdog vuelve a cerrar el socket en cada tick si horaAct esta viejo. Timer1 y Timer2 conviven y Timer2 corre anidado dentro de las esperas seriales.
- **Evidencia:** 'Sleep(500); ClientSocket1.Active := True; for i:=0 to 100 do begin Sleep(10); if conectado then Break; end; if not conectado then Exit;' (3906-3912); 'Timer1.Enabled:=estado>0;' (1235).
- **Impacto:** Con el Bridge caido o reiniciandose, el sondeo serial queda casi detenido (1.5 s bloqueado cada ~1.7 s) y no se atienden ventas en curso.
- **Recomendación:** Quitar los Sleep: Timer2 solo pone Active:=True si no esta conectado ni conectando, y el envio se hace en OnConnect. Usar un estado 'conectando' con timeout por tiempo. No re-habilitar Timer1 en TransmiteComando si conectado=False, o desacoplar el sondeo serial del estado del socket de forma explicita.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="W2W-16"></a>
#### W2W-16 · 🟡 Media · rendimiento · bug — Error de precedencia '(not estatus in [5,9])' que nunca salta el paso 4

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 2919
- **Se atiende en:** [E4.3](../PLAN_OPTIMIZACION.md#e43--ciclo-serial-eficiente)
- **Verificación:** sin verificación independiente
- **Qué pasa:** En Delphi 'not' es unario y tiene mayor precedencia que 'in': la expresion evalua '(not estatus) in [5,9]', un NOT bit a bit del entero que da negativos y nunca pertenece al conjunto. El paso 4 (preset/autorizacion) se visita siempre como un tick aparte, aunque su cuerpo solo actua con estatus=5.
- **Evidencia:** 'if (NumPaso=4) and (not estatus in [5,9]) then NumPaso:=5;' (2919).
- **Impacto:** Un tick perdido (~62 ms) por cada posicion visitada: alarga cada vuelta un 30-50% y retrasa la deteccion de pistola levantada y las respuestas al Bridge (cada 3 ticks).
- **Recomendación:** Cambiar a 'not (estatus in [5,9])'. Revisar con el mismo criterio los demas saltos y medir el tiempo por vuelta en el log.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="W2W-17"></a>
#### W2W-17 · 🟡 Media · protocolo · riesgo — No se valida que la respuesta corresponda a la posicion y al comando enviados

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 1213-1220, 1134-1143, 1278-1283, 1663-1667, 373-391
- **Se atiende en:** [E2.8](../PLAN_OPTIMIZACION.md#e28--recepción-serial-robusta-tramas-bcc-acknak)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Se acepta cualquier trama de 13 bytes con complementos validos. El primer byte de datos de la respuesta repite el ControlByte (p. ej. 0F de 'pos 1 cmd 7') y el segundo el subcomando, pero no se comparan con lo enviado. Si una respuesta tardia (>GtwTimeout) llega despues del Flush del siguiente comando (otra posicion u otro subcomando), se interpreta como propia: estatus de otra bomba, precio interpretado como importe, etc. Si el contenido no es BCD, ExtraeBCD lanza EConvertError (ver hallazgo de DameLecturas).
- **Evidencia:** TransmiteComando1: 'if ( bListo ) then begin if length(sRespuesta)=13 then bOk:=true;' (1217-1219); DameEstatus usa sRespuesta[5] sin revisar sRespuesta[1] (1281).
- **Impacto:** Atribucion de estatus o importes a la posicion equivocada en lineas ruidosas o con reintentos.
- **Recomendación:** En TransmiteComando validar que el byte 1 desempacado sea igual al ControlByte enviado (y el byte 2 al subcomando en los comandos 0F xx). Si no coincide, descartar la trama y seguir esperando hasta el timeout.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="W2W-18"></a>
#### W2W-18 · 🟡 Media · correccion · bug — Lecturas en excepcion: DameLecturas pone la venta en 0 y DameEstatus devuelve un estatus indefinido

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 1800-1805, 2804-2807, 2876-2880, 1290-1301, 2765-2771, 1271-1273, 1421-1427, 1851, 1882, 1891-1892
- **Se atiende en:** [E2.8](../PLAN_OPTIMIZACION.md#e28--recepción-serial-robusta-tramas-bcc-acknak)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Volumen, Precio e Importe se pasan por var desde TPosCarga. En el except de DameLecturas (p. ej. EConvertError de ExtraeBCD con una trama no BCD) se ponen en 0, y el llamador publica igual Volumen/Importe/Precio en el JSON. Con importe=0, DameEstatus clasifica 'In Use sin pistola' como 9 (autorizado) en lugar de 3, y Timer1 dispara la 'desautorizacion' (Detener+Reanudar); el fin de venta puede no detectarse. DameEstatus deja Result sin asignar en el Exit temprano y en el except, asi que devuelve basura como Estatus. DameTotal usa un divisor fijo /100 (ignora DivLitros) y publica 0.001 cuando la lectura es 0.
- **Evidencia:** 'except ... rLitros:=0;rPesos:=0;rPrecio:=0;xposfis:=0;' (1804); 'iStatus:= 0; if not PosicionRecibida(xPosCarga) then Exit;' (1271-1273) sin 'result:='; 'rTotalLitros:=(val1+val2*10000+val3*10000*10000)/100;' (1851).
- **Impacto:** Venta en curso mostrada en 0, posibles acciones erroneas sobre la bomba y estatus aleatorios en condiciones de ruido.
- **Recomendación:** En el except restaurar los valores previos (rLitrosAnt, etc.) y devolver False. Inicializar Result:=0 al inicio de DameEstatus. En DameTotal usar el divisor configurado o documentar el formato fijo del totalizador. Probar inyectando tramas con nibbles A-F.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="W2W-19"></a>
#### W2W-19 · 🟡 Media · correccion · bug — DamePosOrdinal devuelve 4 cuando no encuentra la manguera fisica y compara contra TPosx obsoletos

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 291-300, 1312-1314, 1335, 1384-1386, 1407, 607, 624-630, 1480-1482
- **Se atiende en:** [E1.8](../PLAN_OPTIMIZACION.md#e18--índices-fuera-de-rango-y-carga-de-posiciones-r-)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El while termina con i=4 si no encuentra coincidencia y la condicion 'if i<=4' siempre se cumple, asi que nunca devuelve 0. Ademas recorre TPosx[1..4] aunque NoComb<4, y AgregaPosCarga solo pone NoComb:=0 sin limpiar TComb/TPosx/TMang, por lo que quedan valores de una inicializacion anterior. Una manguera fisica no mapeada (MapeoMangueras o HoseId distinto del grado fisico) deja PosActual/PosMangLev=4: Combustible/Manguera 0 o de otra configuracion, precio leido de TPosx[4] y totales en el indice 4.
- **Evidencia:** 'while (TPosCarga[xPosCarga].TPosx[i]<>xPos)and(i<4) do inc(i); if i<=4 then result:=i else result:=0;' (295-299).
- **Impacto:** Producto o manguera equivocados en la transaccion (facturacion, inventario) y precio/litros calculados con la manguera incorrecta cuando hay un error de mapeo.
- **Recomendación:** Buscar solo en 1..NoComb y devolver 0 si no se encuentra; ante 0, conservar PosActual y registrar el error de mapeo. Limpiar TComb/TPosx/TMang en AgregaPosCarga.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="W2W-20"></a>
#### W2W-20 · 🟡 Media · robustez · bug — AvanzaPosCiclo entra en un bucle infinito si no hay posiciones recibidas en 1..32

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 2968-2989, 659-663, 2941-2946
- **Se atiende en:** [E1.4](../PLAN_OPTIMIZACION.md#e14--sondeo-que-se-congela-livelocks-y-bloqueos-de-la-máquina-de-estados)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El repeat termina solo cuando encuentra una posicion con SwRecibida. Si INITIALIZE no trae Dispensers validos (lista vacia o DispenserId>32: MaxPosCarga se actualiza antes del filtro 1..32) y luego llega RUN, PosCiclo da vueltas sin fin entre 1 y MaxPosCarga y llama EstatusDispensarios en cada vuelta, congelando el hilo principal.
- **Evidencia:** 'repeat inc(PosCiclo); if PosCiclo>MaxPosCarga then begin ... PosCiclo:=1; ... end; PonPuertoPos(PosCiclo); until TPosCarga[PosCiclo].SwRecibida and (...)' (2971-2982).
- **Impacto:** Servicio colgado (sin Bridge, sin logs) por un error de configuracion; requiere matar el proceso.
- **Recomendación:** Limitar el bucle a MaxPosCarga*3 iteraciones. Rechazar en Inicializar/Iniciar si no hay ninguna posicion recibida y no actualizar MaxPosCarga con DispenserId fuera de rango.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="W2W-21"></a>
#### W2W-21 · 🟡 Media · correccion · bug — Indices sin validar con range checking desactivado ($R- en PDISPENSARIOS.cfg)

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 659-663, 690-693, 884-891, 393-399, 1239-1247, 271-277
- **Se atiende en:** [E1.8](../PLAN_OPTIMIZACION.md#e18--índices-fuera-de-rango-y-carga-de-posiciones-r-)
- **Verificación:** sin verificación independiente
- **Qué pasa:** (1) MaxPosCarga toma el DispenserId antes de validar 1..32. Con ids >100, los ciclos 'for xpos:=1 to MaxPosCarga' (EstatusDispensarios, Bloquear, ActivaModoPrepago, AvanzaEmulacion) leen y escriben fuera de TPosCarga[1..100]. (2) LPrecios[productID] (array[1..4]) se asigna con el ProductId de INITIALIZE sin validar: un id 5 o 6 escribe sobre StCiclo/SegmActual/MaxPosCarga y el puntero de EstatusAnterior. (3) inc(NoComb) no tiene tope MCxP=4. (4) PosicionRecibida acepta la posicion 32, pero ControlByte devuelve 0 para xpos>31 y el comando sale a la direccion 0.
- **Evidencia:** 'xpos:=...DispenserId...; if xpos>MaxPosCarga then MaxPosCarga:=xpos; if (xpos in [1..32]) then' (660-663); 'LPrecios[productID]:=productos.Child[i].Field['Price'].Value;' (891); 'if (xpos<=31)and(xcmnd<=7) then result:=xpos*8+xcmnd else result:=0;' (395-398).
- **Impacto:** Corrupcion silenciosa de memoria (AV posteriores, valores globales alterados) por catalogos o configuraciones validas en OpenGas pero fuera de los supuestos del driver.
- **Recomendación:** Validar ProductId en 1..4 (o usar un diccionario), DispenserId en 1..31 (limite real del direccionamiento 2W), NoComb<=MCxP, y responder 'False|...' en INITIALIZE. Considerar compilar con {$R+} en pruebas.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="W2W-22"></a>
#### W2W-22 · 🟡 Media · robustez · bug — EjecutaComando: con la tabla llena accede TabCmnd[201], devuelve folio 0 y las entradas no se liberan al responder

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 981-1021, 3381, 3523, 3538, 3793, 2403-2408
- **Se atiende en:** [E1.5](../PLAN_OPTIMIZACION.md#e15--tabla-de-comandos-tabcmnd-y-respuestas-de-comandos-asíncronos)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El repeat hace inc(ind) y evalua TabCmnd[ind] antes del 'until ... or (ind>200)', asi que con las 200 entradas activas lee y puede escribir TabCmnd[201] (memoria de LPrecios y globales). Las entradas nunca se liberan al responder (SwActivo sigue True); solo se reciclan las que tienen mas de 1 minuto. Con la tabla llena devuelve 0 y AUTHORIZE/STOP/PAYMENT responden 'True|0|' como si hubieran tenido exito. En el except Result queda indefinido.
- **Evidencia:** 'repeat inc(ind); if (TabCmnd[ind].SwActivo)and((now-TabCmnd[ind].hora)>tmMinuto) then ... until (not TabCmnd[ind].SwActivo)or(ind>200);' (987-994); 'AddPeticionJSON(folio,'True|'+IntToStr(EjecutaComando(...))+'|');' (3381).
- **Impacto:** Con rafagas de comandos (TOTALS/RESPCMND por muchas posiciones) hay corrupcion de memoria y autorizaciones reportadas como exitosas que nunca se ejecutan.
- **Recomendación:** Validar ind<=200 antes de indexar, liberar la entrada cuando OpenGas ya leyo la respuesta (o a los 2 min si SwResp), inicializar Result:=0 y responder 'False|Tabla de comandos llena|' si el folio es 0.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="W2W-23"></a>
#### W2W-23 · 🟡 Media · correccion · bug — Un preset con un combustible que no existe en la posicion autoriza todas las mangueras

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 2051-2053, 2167-2169, 2545-2565, 2859-2865, 3369-3372
- **Se atiende en:** [E1.3](../PLAN_OPTIMIZACION.md#e13--presets-montos-decimales-y-validaciones)
- **Verificación:** sin verificación independiente
- **Qué pasa:** PosicionDeCombustible devuelve 0 si el producto no esta en la posicion, y 0 es tambien el valor de 'cualquier manguera' (comb '00'). El paso 4 entonces usa la rama 'PosPreset=0' y llama Autoriza (todas las mangueras). En presets por litros el cliente puede despachar un producto mas caro que el pagado.
- **Evidencia:** 'xcomb:=StrToIntDef(ss,0); xp:=PosicionDeCombustible(xpos,xcomb);' (2052-2053) sin validar xp>0 cuando xcomb>0; paso 4: 'else if (swpreset)and(PosPreset=0) then ... Autoriza(PosCiclo)' (2859-2861).
- **Impacto:** Despacho de un producto distinto al cobrado (diferencias de precio e inventario) por errores de catalogo o de captura en el POS.
- **Recomendación:** Si xcomb>0 y xp=0, responder 'Combustible no existe en la posicion' y no enviar el preset.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="W2W-24"></a>
#### W2W-24 · 🟡 Media · correccion · bug — OCL envia el preset de litros como preset de pesos al recibir el comando

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 2220, 2104-2116, 2853
- **Se atiende en:** [E1.3](../PLAN_OPTIMIZACION.md#e13--presets-montos-decimales-y-validaciones)
- **Verificación:** sin verificación independiente
- **Qué pasa:** En modo serial, OCL llama EnviaPresetPesosBomba(xpos,1,xlitros): tipo 1 = pesos (Ext 21h/39h), es decir, '20 litros' se programa como '$20'. OCC si calcula xtipopre. El preset correcto (TipoPreset=2) se vuelve a enviar en el paso 4 al levantar la pistola. Si la bomba conserva ambos presets, o si el reenvio del paso 4 falla y el preset de pesos queda vigente, la venta se corta en $xlitros. Esta presente desde el primer commit (8ba4373). La certeza sobre la semantica de la bomba es media.
- **Evidencia:** 'if EnviaPresetPesosBomba(xpos,1,xlitros) then begin ... TPosCarga[xpos].TipoPreset:=2;' (2220-2226).
- **Impacto:** Despacho cortado a un monto en pesos igual a los litros solicitados, segun el comportamiento de la bomba; como minimo, el display muestra un preset incorrecto.
- **Recomendación:** Cambiar a EnviaPresetPesosBomba(xpos,2,xlitros). Validar en banco Wayne: OCL 20 L con la pistola ya levantada.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="W2W-25"></a>
#### W2W-25 · 🟡 Media · protocolo · riesgo — Sin delimitacion de mensajes TCP: una lectura se trata como un mensaje y SendText ignora envios parciales

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 3960-3976, 534-545
- **Se atiende en:** [E6.1](../PLAN_OPTIMIZACION.md#e61--framing-y-buffer-por-conexión-en-los-dos-sentidos-y-del-lado-de-opengas)
- **Verificación:** sin verificación independiente
- **Qué pasa:** ClientSocket1Read asume que un ReceiveText es exactamente un mensaje completo. Un INITIALIZE grande fragmentado se procesa a medias (el JSON no parsea y el segundo fragmento llega como un comando con folio basura). Dos respuestas del Bridge concatenadas (posible cuando el driver tiene mas de un envio en vuelo, p. ej. el Responder de Iniciar mas el de Timer1) mezclan parametros ('...|0' + '0|DISPENSERS|NOTHING'). Responder ignora el valor devuelto por SendText: con WSAEWOULDBLOCK o un envio parcial de JSON grandes el mensaje se pierde o llega truncado.
- **Evidencia:** 'mensaje:=Socket.ReceiveText; ... folio:=StrToIntDef(ExtraeElemStrSep(mensaje,1,'|'),0);' (3960-3964); 'socketResponse.SendText(resp);' sin revisar el resultado (538, 542).
- **Impacto:** Comandos perdidos o mal interpretados y snapshots invalidos en el Bridge, sobre todo con JSON grandes (LOG/LOGREQ, muchas posiciones).
- **Recomendación:** Definir un terminador (p. ej. ETX o LF) o un prefijo de longitud en ambos lados y acumular en un buffer hasta tener un mensaje completo. Usar SendBuf en bucle hasta enviar todo o una cola atendida en OnWrite. Requiere desplegar Bridge y driver juntos.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** sí

<a id="W2W-26"></a>
#### W2W-26 · 🟡 Media · protocolo · deuda_tecnica — Peticiones nunca se limpian y cada NOTHING agrega un {Folio:0} que puede desplazar resultados reales

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 3264-3297, 3980-3981
- **Se atiende en:** [E6.2](../PLAN_OPTIMIZACION.md#e62--push-de-comandos-resultados-inmediatos-y-ack)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El Bridge contesta NOTHING a cada mensaje y el driver lo registra como peticion con folio 0. Con un maximo de 2, basta que lleguen dos respuestas antes del siguiente envio (mas de un mensaje en vuelo) para que el resultado de un comando real se descarte sin enviarse, y el Bridge termina con timeout. En estado estable cada JSON lleva dos objetos {0,'True|'} inutiles y el TryPopByFolio(0) del Bridge se ejecuta sin coincidencia.
- **Evidencia:** 'NOTHING_e: AddPeticionJSON(folio, 'True|');' (3980-3981); 'while petArr.Count >= 2 do petArr.Delete(0);' (3282-3283).
- **Impacto:** Respuestas perdidas de forma intermitente y trafico/CPU innecesarios.
- **Recomendación:** No agregar peticion para NOTHING ni para folio 0. Mantener una cola de resultados pendientes de envio (sin tope de 2) y vaciarla al enviar el JSON (o tras N envios). No cambia el formato del contrato.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="W2W-27"></a>
#### W2W-27 · 🟡 Media · robustez · riesgo — Timer2 habilitado en el .dfm corre antes o en paralelo a ServiceExecute; ademas ServiceExecute es fragil ante un ini invalido

- **Ubicación:** `UIGASWAYNE2W.dfm` líneas 45-50
- **Se atiende en:** [E2.3](../PLAN_OPTIMIZACION.md#e23--arranque-y-paro-ordenados-del-servicio)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Timer2 (Enabled por defecto) se crea en Application.CreateForm en el hilo principal y dispara 200 ms despues, independientemente de que ServiceExecute (hilo del servicio) haya creado ListaLog/rootJSON y fijado Host/Port (UIGASWAYNE2W.pas 411-444). Si Active:=True lanza excepcion con Host vacio, AgregaLog encuentra ListaLog=nil y su except se llama a si mismo: recursion hasta desbordar la pila. El Sleep(500) inicial reduce la probabilidad (certeza media). En ServiceExecute, StrToInt sin default (MinutosLog, puerto de ServidorSocket) lanza excepcion; el except usa ListaLog, que puede ser nil, y guarda ListaLog con el nombre LogDispPetRes. El TIniFile nunca se libera.
- **Evidencia:** .dfm: 'object Timer2: TTimer Interval = 200 OnTimer = Timer2Timer' (sin Enabled=False). UIGASWAYNE2W.pas: 'minutosLog:=StrToInt(config.ReadString('CONF','MinutosLog','0'));' (419); except: 'ListaLog.Add(...); ListaLog.SaveToFile(rutaLog+'\LogDispPetRes'...' (450-451).
- **Impacto:** Caida del servicio al arrancar en equipos lentos (arranque en frio) o con un ini mal escrito, sin log util.
- **Recomendación:** Poner Timer2.Enabled=False en el .dfm y habilitarlo al final de ServiceExecute. Crear las listas en el constructor (OnCreate) y usar StrToIntDef/ReadInteger con valores por defecto. Liberar el TIniFile en try/finally y corregir el nombre del archivo.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="W2W-28"></a>
#### W2W-28 · 🟡 Media · concurrencia · riesgo — Detener el servicio no detiene timers ni puertos; GuardarLog cruza hilos y ServiceThread puede ser nil

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 3167-3181, 445-447, 1210, 3055, 3481-3512
- **Se atiende en:** [E0.2](../PLAN_OPTIMIZACION.md#e02--identificar-el-hilo-de-cada-evento-instrumentación), [E2.3](../PLAN_OPTIMIZACION.md#e23--arranque-y-paro-ordenados-del-servicio)
- **Verificación:** sin verificación independiente
- **Qué pasa:** ServiceStop/ServiceShutdown/ServiceDestroy solo llaman GuardarLog(0), en el hilo del servicio y concurrente con el hilo principal que sigue agregando a ListaLog/ListaLogPetRes (TStringList sin proteccion). Timer1 sigue sondeando y controlando bombas hasta que el proceso termina. Cuando TService.Main libera FServiceThread, la llamada ServiceThread.ProcessRequests(False) dentro de TransmiteComando se hace sobre nil (AV + GuardarLog en cada comando). Si el WM_QUIT final cae en el bombeo anidado, se pierde y el proceso puede no terminar (probabilidad baja).
- **Evidencia:** 'procedure ServiceStop(...); begin GuardarLog(0); end;' (3167-3171); 'ServiceThread.ProcessRequests(False);' (1210) llamado desde Timer1 en el hilo principal.
- **Impacto:** Excepciones y escrituras de log al detener, comandos a bombas despues de 'detenido' y riesgo de un proceso zombie que retiene el COM.
- **Recomendación:** En OnStop/OnShutdown: Timer1/Timer2.Enabled:=False, cerrar pSerial/pSerial2 y el socket, y guardar el log. Proteger las listas con TCriticalSection o hacer el guardado solo desde el hilo principal. En las esperas usar un bombeo propio (PeekMessage + Dispatch, reenviando WM_QUIT) en lugar de ServiceThread.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="W2W-29"></a>
#### W2W-29 · 🟡 Media · seguridad · riesgo — Modo emulacion activable desde INITIALIZE genera ventas ficticias publicadas como reales

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 845-846, 849-871, 4302-4333, 4347-4491, 4089-4097, 2650-2655
- **Se atiende en:** [E8.1](../PLAN_OPTIMIZACION.md#e81--autenticación-licencia-y-modo-emulación)
- **Verificación:** sin verificación independiente
- **Qué pasa:** MODOEMULACION=Si en las variables de INITIALIZE (las manda OpenGas) desactiva el puerto serial y, en posiciones no prepago, genera ventas aleatorias ($100-$2,000) con precios de respaldo fijos (24.00/25.80/26.00). Esas ventas pasan solas a inactivo a los 3 s sin PAYMENT. El JSON no tiene ninguna marca que distinga datos emulados. Un error de configuracion en produccion crea transacciones inexistentes y deja las bombas sin control.
- **Evidencia:** 'else if UpperCase(...)='MODOEMULACION' then SwModoEmulacion:=UpperCase(ExtraeElemStrSep(variable,2,'='))='SI';' (845-846); 'EmuConfiguraVenta(xPosCarga, xComb, 1, xImporte, True);' (4324).
- **Impacto:** Transacciones falsas en el POS y la contabilidad, y dispensarios sin control mientras dure la configuracion.
- **Recomendación:** Exigir ademas una bandera local en PDISPENSARIOS.ini (o una directiva de compilacion) para habilitar la emulacion, publicar 'Emulacion':true en el JSON y registrar alertas periodicas. Separar el emulador en una unidad aparte.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="W2W-30"></a>
#### W2W-30 · 🟡 Media · seguridad · riesgo — Login/Token decorativos y validacion de licencia HASP comentada

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 3712-3730, 3605-3633, 433, 72
- **Se atiende en:** [E8.1](../PLAN_OPTIMIZACION.md#e81--autenticación-licencia-y-modo-emulación)
- **Verificación:** sin verificación independiente
- **Qué pasa:** La contrasena esperada es MD5(usuario|yyyy-mm-ddThh:nn): no hay secreto, cualquiera la calcula. El Token resultante no se verifica en ningun comando. La validacion HASP de Iniciar esta comentada completa, aunque se lee 'Licencia' del ini (versionado con una llave en PDISPENSARIOS.ini:4) y se distribuyen las DLL HASP. Date y Now se leen por separado, con riesgo de borde de minuto.
- **Evidencia:** 'if MD5(usuario+'|'+FormatDateTime('yyyy-mm-dd',Date)+'T'+FormatDateTime('hh:nn',Now))<>password then' (3718); bloque '//    if not SwModoEmulacion then begin ... haspObj.CheckKey(...)' (3608-3633).
- **Impacto:** Sin control de acceso real a comandos de bomba (mitigado porque el Bridge escucha en localhost) y sin proteccion de licencia.
- **Recomendación:** Definir si la autenticacion aplica: si si, usar un secreto compartido (HMAC) y exigir el Token en los comandos sensibles; si no, eliminar Login/Token. Decidir el estado de HASP: rehabilitarlo con pruebas o eliminar el codigo y las DLL. Sacar la llave del ini versionado.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** sí

<a id="W2W-31"></a>
#### W2W-31 · 🟡 Media · configuracion · riesgo — Variables de INITIALIZE sin validacion de rango (divisores 0, timeout 0)

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 824-847, 1589, 1628, 1667, 1968-1985, 1208
- **Se atiende en:** [E0.5](../PLAN_OPTIMIZACION.md#e05--configuración-documentada-y-validada-al-arrancar), [E2.7](../PLAN_OPTIMIZACION.md#e27--initialize-idempotente-y-seguro-con-ventas-en-curso)
- **Verificación:** sin verificación independiente
- **Qué pasa:** WTWDIVIMPORTE, WTWDIVLITROS, GTWTIMEOUT, GTWTIEMPOCMND y WTWPOSINIEXT usan StrToIntDef(...,0): un valor mal escrito deja el divisor en 0. Entonces dividefloat da importes y litros 0 y ConvierteBCD(x*0) programa presets de 0, cuyo efecto en la bomba (sin limite o rechazo) es incierto. Con timeout 0 todas las transacciones fallan. Solo GTWINTENTOS tiene Max(1,...).
- **Evidencia:** 'WtwDivImporte:=StrToIntDef(ExtraeElemStrSep(variable,2,'='),0)' (834); 'ConvierteBCD(xValor*WtwDivImporte,6)' (1970).
- **Impacto:** Ventas en cero o presets incorrectos por un error de captura en la configuracion de OpenGas.
- **Recomendación:** Aceptar solo 1/10/100/1000 para los divisores, 50-2000 ms para el timeout y >=1 para WtwPosIniExt. Ante un valor invalido responder 'False|Variable X invalida|' en INITIALIZE y registrar los valores efectivos en el log.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="W2W-32"></a>
#### W2W-32 · 🟡 Media · configuracion · riesgo — Parseo y formato de decimales dependientes del locale del servicio

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 2028-2032, 2150-2154, 2395, 3349-3353, 2383-2385, 1042
- **Se atiende en:** [E8.2](../PLAN_OPTIMIZACION.md#e82--configuración-regional-locale-explícita)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Los montos de OCC/OCL (StrToFloat), CPREC (StrToFloatDef), AutorizarVenta y la respuesta de TOTAL (FormatFloat/FormatoMoneda) usan el DecimalSeparator y ThousandSeparator globales de la cuenta del servicio. uLkJSON si normaliza, pero estos textos no. Con un locale de coma decimal (es-ES y similares) todos los presets responden 'Error en Importe' y TOTAL sale con comas.
- **Evidencia:** 'xImporte:=StrToFLoat(cantidadPreset);' (2028); ninguna asignacion de DecimalSeparator en el archivo.
- **Impacto:** Falla total de presets o datos mal formateados tras un cambio de configuracion regional del servidor.
- **Recomendación:** Fijar DecimalSeparator:='.' y ThousandSeparator:=',' al iniciar el servicio, o usar las versiones con TFormatSettings propias. Probar con el locale es-ES.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="W2W-33"></a>
#### W2W-33 · 🟡 Media · protocolo · bug — BLOCK y SELFSERVICE/FULLSERVICE no tienen efecto visible ni real en modo serial

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 1452-1508, 3388-3479, 3183-3213, 3418-3448, 2689, 2785, 2849
- **Se atiende en:** [E5.4](../PLAN_OPTIMIZACION.md#e54--comandos-homogéneos-entre-marcas)
- **Verificación:** sin verificación independiente
- **Qué pasa:** BLOCK pone SwDesHabil, pero no se envia nada a la bomba y PosCarga[].Estatus conserva el ultimo valor: el '7' (Deshabilitado) solo se arma en xestado dentro de EstatusDispensarios, que no se publica (la cadena 'lin' tampoco se usa). Bloquear durante un despacho suspende el sondeo y la lectura final hasta UNBLOCK. ModoOpera se acepta pero en modo serial no autoriza nada en 'Normal' (Gilbarco si lo hace).
- **Evidencia:** 'else xestado:=xestado+'7';' (1479) y 'lin:=lin+'&'+xmodo;' (1497) sin uso posterior; ModoOpera solo se usa en la emulacion (2262, 2326, 4217, 4362).
- **Impacto:** OpenGas recibe 'True' para operaciones que no se reflejan en el estado y puede asumir bloqueos o modos de servicio inexistentes.
- **Recomendación:** Publicar Estatus 7 para posiciones bloqueadas (coordinar con OpenGas) y seguir sondeando el estatus sin autorizar. Implementar la auto-autorizacion en 'Normal' si el negocio la requiere, o responder 'False|No soportado|'.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** sí

<a id="W2W-34"></a>
#### W2W-34 · 🟡 Media · rendimiento · optimizacion — JSON regenerado completo cada 3 ticks y EstatusDispensarios con trabajo muerto O(N^2)

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 2959-2960, 3915-3918, 1452-1508, 3215-3262
- **Se atiende en:** [E4.2](../PLAN_OPTIMIZACION.md#e42--json-más-barato-generar-menos-redondear-y-buscar-menos)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Se hace TlkJSON.GenerateText de todo rootJSON aunque nada haya cambiado, y despues se registra completo (ver hallazgo del log de peticiones). EstatusDispensarios se ejecuta en cada sondeo de estatus y en cada vuelta: arma una cadena 'lin' con FormatFloat por posicion que nunca se usa, y llama ActualizaCampoJSON dos veces por posicion. Cada llamada hace una busqueda lineal en PosCarga con comparacion Variant y registra 'DispenserId no encontrado' si falta.
- **Evidencia:** 'ss:=ss+'/'+FormatFloat('###0.###',volumen); ... lin:=lin+'#'+ss;' (1485-1489); 'ActualizaCampoJSON(xpos,'Combustible',CombActual); ActualizaCampoJSON(xpos,'Manguera',MangActual);' (1483-1484).
- **Impacto:** CPU innecesaria en el mismo hilo que atiende el serial; crece con el numero de posiciones.
- **Recomendación:** Mantener un indice xpos -> TlkJSONObject (array[1..32]) al construir PosCarga y una bandera 'dirty'. Enviar el JSON solo con cambios, con un minimo de uno cada 1-2 s (por debajo de TimeoutDatosObsoletos=5 s del Bridge) y PING en los demas casos. Eliminar 'lin'/'xmodo'.
- **Esfuerzo:** M · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="W2W-35"></a>
#### W2W-35 · 🟡 Media · rendimiento · optimizacion — Maquina de pasos de un paso por tick con pasos vacios y control con goto

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 2681-2939, 2812, 2849, 2884-2892, 2399, 2625, 2666-2671, 2777-2782, 2897-2899, 2941-2946
- **Se atiende en:** [E4.3](../PLAN_OPTIMIZACION.md#e43--ciclo-serial-eficiente), [E7.4](../PLAN_OPTIMIZACION.md#e74--separar-la-lógica-de-protocolo-serial-de-la-del-servicio-testeable)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Cada paso consume un tick (~62 ms) aunque no haga nada. En posiciones sin comunicacion (PuedeSondear=False) se recorren 3 y 4 sin enviar nada, y el 7 tambien porque CPREC marca TCambioPrecN1 en todas las posiciones y esta solo se limpia en las inactivas que contestan. El paso 6 (ProcesaComandos) solo corre en la ultima posicion. El control usa 'goto L01', que salta dentro de un 'with' desde fuera, y SwPasoBien=False (tras el exit del except del paso 1 o un hueco) hace saltar el estatus de la siguiente posicion e incrementa ContadorAlarma en falso.
- **Evidencia:** 'if not SwPasoBien then begin swespera:=false; inc(ContadorAlarma); goto L01; end;' (2667-2671); 'L01: SwPasoBien:=true; with TPosCarga[PosCiclo] do begin ...' (2897-2899).
- **Impacto:** Vueltas de sondeo mas largas, mas latencia para detectar pistola levantada y fin de venta, y logica dificil de mantener.
- **Recomendación:** Reescribir el ciclo como un bucle por posicion que ejecute en el mismo tick todos los pasos aplicables (o un despachador por prioridad: comandos > despachando > estatus > totales > precios). Quitar el goto y saltar por completo las posiciones con PuedeSondear=False.
- **Esfuerzo:** L · **Riesgo del cambio:** alto · **Toca contrato:** no

<a id="W2W-36"></a>
#### W2W-36 · 🟡 Media · correccion · riesgo — Estado de pago no persistente y fin de venta que se auto-cierra por defecto (finv invertido)

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 634-636, 2784-2803, 1289-1301, 3374-3379, 2728-2738
- **Se atiende en:** [E5.2](../PLAN_OPTIMIZACION.md#e52--confirmación-real-de-prices-authorize-y-payment)
- **Verificación:** sin verificación independiente
- **Qué pasa:** (1) SwVentaPagada/SwTransAbierta viven solo en memoria. Tras un reinicio, SwLeeVenta=True relee la ultima venta de cada bomba con HoraOcc=Now, y si la bomba sigue In Use sin pistola con importe>0 (cobrada pero sin Sale End completado) se reporta como fin de venta (3) una venta ya cobrada: posible duplicado. (2) AutorizarVenta invierte finv: vacio o '1' => EsperaFinVenta=0. Con 0, si la bomba vuelve sola a reposo, el estatus 3 dura solo hasta el siguiente sondeo y pasa a 1 sin PAYMENT, asi que OpenGas podria no verlo. Certeza media: depende de la configuracion de la bomba y de la logica de OpenGas.
- **Evidencia:** 'if finv='0' then finv:='1' else finv:='0';' (3376-3379); 'if (EstatusAnt in [3,4])and(Estatus=1) then begin ... if (EsperaFinVenta=1) and (volumen>0) then Estatus:=3 else EsperaFinVenta:=0;' (2728-2737).
- **Impacto:** Transacciones duplicadas tras un reinicio o ventas no registradas cuando el estado 3 es efimero.
- **Recomendación:** Persistir en disco por posicion el ultimo importe/volumen pagado y compararlo al arrancar. Documentar el significado de finv en el contrato y considerar EsperaFinVenta=1 por defecto, para que una venta solo se cierre con PAYMENT.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** sí

<a id="W2W-37"></a>
#### W2W-37 · 🟡 Media · correccion · riesgo — Un preset excedido detiene el despacho y la posicion puede quedarse en 8 sin detectar el fin de venta

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 2510-2543, 1316-1317, 1322-1328, 2713-2721
- **Se atiende en:** [E1.3](../PLAN_OPTIMIZACION.md#e13--presets-montos-decimales-y-validaciones)
- **Verificación:** sin verificación independiente
- **Qué pasa:** VigilaPresetExcedido llama DetenerDespacho. Con la bomba In Use, sin pistola y tbit4, DameEstatus primero calcula 3 y luego lo sobrescribe con 'if tbit[4] then iStatus:=8'. El fin de venta exige estatus [1,3,5], asi que la venta queda 'Detenida' hasta que OpenGas mande START, y ReanudaDespacho podria reanudar el flujo si el cliente sigue con la pistola. Solo en estado no-In Use + tbit4 el driver reanuda solo y devuelve 3. Certeza media (depende de la secuencia de bits de la bomba).
- **Evidencia:** 'if tbit[4] then iStatus:=8;  // detenida' (1316-1317) despues de la clasificacion 3/1/9; 'if DetenerDespacho(xPosCarga) then AgregaLog('Despacho detenido por preset excedido...' (2534-2535).
- **Impacto:** Posicion detenida con la venta sin cerrar o despacho adicional al reanudar.
- **Recomendación:** Si SwVigilaPreset disparo el paro y la pistola ya esta colgada, tratar 8 como fin de venta (ir a lectura final) y no reanudar. Probar en banco con DetenerPresetExcedido=Si.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="W2W-38"></a>
#### W2W-38 · 🟡 Media · protocolo · bug — No se soportan los comandos de 1 caracter '0'/'1' que el Bridge reenvia

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 3964-3976, 4052-4053
- **Se atiende en:** [E5.4](../PLAN_OPTIMIZACION.md#e54--comandos-homogéneos-entre-marcas)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El Bridge convierte un mensaje '0' o '1' de OpenGas en 'folio|DISPENSERS|0/1' con comando '1' (UIGASBRIDGE.pas:291-292). Wayne y PAM los manejan (abren/cierran el puerto y responden '1'). Wayne 2W busca '0_e'/'1_e' en TMetodos, no encuentra nada y contesta 'False|Comando desconocido|', que el Bridge pasa crudo a OpenGas.
- **Evidencia:** UIGASWAYNE.pas ClientSocket1Read: 'if (Length(comando)=1) and (StrToIntDef(comando,-99) in [0,1]) then ...'; en Wayne 2W no hay rama equivalente antes del 'case metodoEnum of' (3976-4054).
- **Impacto:** Si OpenGas usa 0/1 para pausar o reanudar la comunicacion, con esta marca falla siempre.
- **Recomendación:** Portar la rama de Wayne (Detener/Iniciar logico y respuesta '1') o confirmar con OpenGas que no se usa y documentarlo.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="W2W-44"></a>
#### W2W-44 · 🟡 Media · mantenibilidad · deuda_tecnica — Duplicacion interna masiva por puerto (SegmActual 1/2) y por tipo de preset

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 1277-1420, 1662-1799, 1829-1890, 1133-1166, 2587-2614, 1176-1237, 3021-3082, 736-805, 3096-3165, 2056-2101, 2172-2217
- **Se atiende en:** [E7.3](../PLAN_OPTIMIZACION.md#e73--updispcomandospas-tabcmnd-despacho-y-resultados), [E7.4](../PLAN_OPTIMIZACION.md#e74--separar-la-lógica-de-protocolo-serial-de-la-del-servicio-testeable)
- **Verificación:** sin verificación independiente
- **Qué pasa:** DameEstatus, DameLecturas, DameTotal, LeePrecios, CambiaPrecios, DetenerDespacho, EnviaSaleEnd, EnviaPresetPesosBomba, LeeVolumen y LeeDigitos78 repiten el mismo cuerpo para sRespuesta/TransmiteComando1 y sRespuesta2/TransmiteComando2. TransmiteComando1/2, IniciaPSerial/2 y pSerialTrigger*/pSerial2Trigger* son copias, y los bloques de emulacion de OCC y OCL tambien. Los defectos de ReanudaDespacho/Autoriza (solo puerto 1) y los mensajes de error copiados son consecuencia directa.
- **Evidencia:** DameEstatus: las lineas 1277-1347 y 1349-1420 son identicas salvo el sufijo 2.
- **Impacto:** Cada correccion debe aplicarse dos o tres veces; alto riesgo de divergencia.
- **Recomendación:** Crear 'function Transmite(xPosCarga:integer; const Cmd:string; out Resp:string):boolean' que elija puerto y buffer por segmento y devuelva la trama desempacada y validada. Refactorizar las funciones de comando sobre ella y cubrirlas con pruebas de tramas grabadas.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="W2W-39"></a>
#### W2W-39 · ⚪ Baja · robustez · bug — RUN repetido agrega triggers duplicados y HALT no limpia presets pendientes

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 3637-3647, 3690-3701, 3481-3512
- **Se atiende en:** [E5.4](../PLAN_OPTIMIZACION.md#e54--comandos-homogéneos-entre-marcas)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Iniciar llama AddDataTrigger(#$F0) y AddDataTrigger(#$8A) cada vez, aunque el puerto ya este abierto o el servicio ya este corriendo, y reinicia PosCiclo/NumPaso a mitad de una vuelta. Los handles anteriores nunca se quitan. Detener cierra el puerto pero conserva SwPreset/SwPreset2/ValorPreset, asi que al volver a RUN una pistola levantada se autoriza con un preset de antes del HALT.
- **Evidencia:** 'wTriggerEOT:= pSerial.AddDataTrigger(#$F0,true); wTriggerLF:= pSerial.AddDataTrigger(#$8A,true);' (3646-3647) sin RemoveTrigger ni verificacion de 'detenido'.
- **Impacto:** Agotamiento de triggers de Async Pro tras muchos RUN y autorizaciones inesperadas despues de un HALT.
- **Recomendación:** Responder 'False|Ya iniciado|' si not detenido; quitar los triggers (no se usan) o removerlos en Detener; limpiar los presets pendientes en Detener/Terminar.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="W2W-40"></a>
#### W2W-40 · ⚪ Baja · configuracion · riesgo — Async Pro con Tracing=tlOn y TraceAllHex en el .dfm y Baud por defecto 5700

- **Ubicación:** `UIGASWAYNE2W.dfm` líneas 12-44
- **Se atiende en:** [E0.1](../PLAN_OPTIMIZACION.md#e01--build-reproducible-de-ambos-ejecutables)
- **Verificación:** sin verificación independiente
- **Qué pasa:** pSerial y pSerial2 arrancan con trazado activo (APRO.TRC/APRO.LOG en el directorio actual del servicio, normalmente System32), lo que cuesta memoria y CPU por cada caracter. Solo Detener lo apaga (UIGASWAYNE2W.pas:3492): despues de un HALT/RUN queda apagado, lo cual es inconsistente. Baud=5700 es un valor atipico que solo se corrige si INITIALIZE trae los baudios.
- **Evidencia:** 'Tracing = tlOn TraceName = 'APRO.TRC' TraceAllHex = True LogName = 'APRO.LOG'' (16-19 y 36-39); 'pSerial.Tracing:= tlOff;' en Detener.
- **Impacto:** Sobrecarga y archivos en ubicaciones inesperadas; diagnostico inconsistente.
- **Recomendación:** Poner Tracing=tlOff en el .dfm y habilitarlo por parametro de ini (con TraceName en rutaLog). Usar un Baud por defecto realista (5760/5787 segun la bomba) y validar el que llega en INITIALIZE.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="W2W-41"></a>
#### W2W-41 · ⚪ Baja · memoria_recursos · bug — Fuga del arbol JSON de INITIALIZE y funciones string que no asignan Result en exito

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 821, 897-901, 578-734, 736-805, 3096-3165
- **Se atiende en:** [E2.7](../PLAN_OPTIMIZACION.md#e27--initialize-idempotente-y-seguro-con-ventas-en-curso)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Inicializar crea 'js := TlkJSON.ParseText(...)' y nunca lo libera: se fuga todo el arbol de Consoles/Dispensers/Products en cada INITIALIZE (ahora mas frecuente porque INITIALIZE en caliente reinicializa). AgregaPosCarga, IniciaPSerial e IniciaPSerial2 no asignan Result en el camino exitoso: en Delphi el resultado string hereda el valor de la variable destino y solo funciona porque 'resultado' llega vacio. Si js es nil (JSON invalido) se produce un AV.
- **Evidencia:** 'js := TlkJSON.ParseText(ExtraeElemStrSep(msj,1,'|'));' (821) sin Free; AgregaPosCarga termina sin 'Result:=''' (730-734).
- **Impacto:** Crecimiento lento de memoria y una trampa latente para futuros cambios.
- **Recomendación:** try/finally js.Free; inicializar Result:='' al inicio de las tres funciones; validar js<>nil y responder 'False|JSON invalido|'.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="W2W-42"></a>
#### W2W-42 · ⚪ Baja · observabilidad · deuda_tecnica — Log circular de 10000 lineas cubre pocos minutos y tiene mensajes copiados

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 475-477, 1200, 1214, 2675, 3074, 1946, 3059
- **Se atiende en:** [E2.4](../PLAN_OPTIMIZACION.md#e24--bitácoras-que-no-bloquean-append-incremental-rotación-y-sin-json-repetido), [E7.1](../PLAN_OPTIMIZACION.md#e71--updisplogpas-logger-común)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Cada transaccion escribe dos lineas hex y cada tick una linea 'PosCiclo/NumPaso', asi que ListaLog se renueva cada ~5-10 minutos: un TRACE pedido tras un incidente rara vez lo contiene. Hay mensajes copiados que confunden: 'Error TransmiteComando1' dentro de TransmiteComando2 (3074) y 'Error Autoriza' en AutorizaPm (1946). No hay niveles de log.
- **Evidencia:** 'AgregaLog('PosCiclo: '+IntToStr(PosCiclo)+' - '+'NumPaso: '+IntToStr(NumPaso));' (2675) en cada tick; 'while ListaLog.Count>10000 do ListaLog.Delete(0);' (475-476).
- **Impacto:** Diagnostico deficiente en campo.
- **Recomendación:** Escribir a archivo diario con append y rotacion por tamano, agregar niveles (trama serial solo en nivel debug), corregir los textos copiados y registrar los cambios de estado por posicion.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="W2W-43"></a>
#### W2W-43 · ⚪ Baja · mantenibilidad · deuda_tecnica — Codigo muerto y variables sin uso

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 513-532, 559-576, 1023-1059, 1099-1113, 3005-3019, 3605-3633, 3579-3595, 3892-3895, 434, 441, 60-63, 50, 179, 194, 207, 220, 276-281, 1453
- **Se atiende en:** [E8.3](../PLAN_OPTIMIZACION.md#e83--código-muerto-variables-globales-y-duplicación-interna)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Nunca se invocan: CRC16, GuardaLogComandos (su except hace 'Exception.Create' sin raise, que fuga el objeto), TransaccionPosCarga y ObtenerEstado. Sin efecto: pSerialTriggerData/pSerial2TriggerData (bEndOfText/bLineFeed no se usan). Se crean y no se usan: ListaCmnd y ListaComandos. Sin uso: PreciosInicio, Avanzar, SwCambiaPrecio, SwBring, SwInicio, ls, Isla, MontoPreset (solo se asigna), StrCiclo (solo se arma), las variables locales de IniciaPrecios y la variable json de Timer2Timer. Tambien hay un bloque HASP comentado de 25 lineas.
- **Evidencia:** grep: CRC16/GuardaLogComandos/TransaccionPosCarga/ObtenerEstado solo aparecen en su declaracion e implementacion; 'Exception.Create('GuardaLogComandos: '+e.Message);' (574).
- **Impacto:** Ruido que dificulta auditar y mantener un archivo de 4,500 lineas.
- **Recomendación:** Eliminar el codigo muerto en un commit aislado sin cambio funcional y compilar con hints/warnings activados para detectar mas.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

