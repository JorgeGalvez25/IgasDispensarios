# Hallazgos · PAM · Driver PAM 1000 (Marca 4) · UIGASPAM.pas

> Anexo del [plan de optimización](../PLAN_OPTIMIZACION.md). Código auditado: `IgasDispensarios@26ccfb4`, `IgasDispensariosBridge@99edafd`. Las líneas pueden haber cambiado: ubica las rutinas por su nombre.

## Cómo funciona este módulo

UIGASPAM implementa el TService Togcvdispensarios_pam (Marca 4). Controla una consola PAM 1000 (VersionPam1000='3' por defecto, o version anterior) por un TApdComPort y publica su estado al Bridge por un TClientSocket no bloqueante.

Protocolo serial: tramas STX+cmd+ETX+BCC (BCC = XOR de los bytes desde cmd hasta ETX). Las respuestas son STX..ETX+BCC o un ACK/NAK suelto. Comandos usados: B00 (estatus de todas las posiciones), Axx (lectura de venta), @10/Cxx (totales), P/@02 (presets en importe o litros), S (venta libre), E/G/L/R (parar, reanudar, abrir, venta completa), X (mapeo de producto y cambio de precio), T (nivel de precio) y D0 (setup).

La maquina de estados NumPaso 0..4 avanza con cada respuesta (pSerialTriggerAvail -> ProcesaLinea). Timer1 (250 ms) lanza el ciclo y resuelve timeouts. Pasos: 1 = B00, 2 = lecturas A, 3 = totales, 4 = ejecucion de TabCmnd (OCC/OCL/FINV/EFV/DVC/REANUDAR/TOTAL/CPREC).

Los comandos de OpenGas llegan del Bridge como respuesta a cada envio del driver (PING o JSON completo) y se ejecutan en ClientSocket1Read. El resultado va a Peticiones (maximo 2) en el siguiente JSON. Los comandos de despacho solo se encolan en TabCmnd y devuelven un folio que OpenGas consulta con RESPCMND.

Modelo de hilos, verificado contra el codigo. Certeza alta para timers y socket, media para Async Pro:

- Timer1 y Timer2 se crean desde el .dfm en el hilo principal.

- El socket se activa por primera vez en Timer2Timer (hilo principal; ScktComp asigna el HWND de forma perezosa), asi que OnConnect/OnRead/OnDisconnect tambien corren en el hilo principal.

- Async Pro normalmente entrega OnTriggerAvail en el hilo principal.

- Por eso en PAM casi no hay acceso concurrente real a rootJSON/TPosCarga. Los riesgos son reentrancia (EsperaMiliSeg si bombea mensajes) y bloqueo del hilo principal (Sleep en Timer2Timer, EsperaMiliSeg si duerme).

- Excepcion: con modoAuto, ServiceExecute ejecuta Inicializar/Iniciar y abre el puerto en el hilo del servicio mientras Timer2 ya corre en el principal.

Defectos mas graves:

- El sondeo se bloquea para siempre si ListaCmnd queda con algo y no hay comando en vuelo (HALT/RUN).

- Un preset de importe mayor a 9999 se convierte en venta libre.

- La lectura de totales puede quedar en ciclo infinito.

- Un SwError viejo hace reportar como fallido un preset que si se envio.

- Los cambios de precio se confirman OK aunque no se apliquen.

- Hay escrituras fuera de rango y la compilacion usa {$R-}.

- El JSON solo sale una vez por ciclo completo.

- La perdida de comunicacion con la PAM no se refleja en el JSON.

### Ciclo serial

Timers: Timer1 de 250 ms (Enabled=False en el .dfm; se activa en Iniciar, en el comando '1' y desde Timer2Timer). Timer2 de 200 ms (se apaga cuando estado>0 y el puerto esta abierto). Timer1 no es un reloj fijo: pSerialTriggerAvail (789/821) y ComandoConsola (725/736) lo desactivan y reactivan, y eso reinicia el intervalo. Sus ticks solo llegan cuando la linea lleva 250 ms quieta.



Maquina de estados NumPaso:

- 0 = libre. El siguiente tick pone NumPaso:=1 y manda ComandoConsolaBuff('B00') (2248-2252).

- 1 = espera la respuesta 'B'. Si no llega, tras 11 ticks (2.75 s) se reenvia B00 (2240-2246).

- Respuesta 'B' (858-1073): actualiza estatus y Estatus en el JSON. Desde aqui puede salir con exit, dejando NumPaso=1, en cuatro casos: (a) primera vez, setup D06222/D0+SetUpPAM1000 con EsperaMiliSeg(500) x2; (b) nivel de precio 'T'+pos+'1' por posicion (espera otros 2.75 s); (c) mapeo 'X'+pos+prod+manguera por manguera (fuerza ContEspera1:=10 para seguir al siguiente tick); (d) reenvio de preset (codigo muerto). Ademas manda 'L' a posiciones en 6 (cerrada) y 'G' a las detenidas en modo Normal (inalcanzable). Al final escribe Volumen/Precio/Importe de todas las posiciones en el JSON y pasa a NumPaso:=2.

- 2 = recorre posiciones desde PosicionCargaActual y manda 'A'+pos a las que estan en [1,2,3,8] si cambiaron, si estatus>1, o si SwA/swinicio2. Las posiciones en 2/3/8 se leen en cada ciclo. Cada respuesta 'A' continua con la siguiente. Timeout >20 ticks (5.25 s): inyecta '.A00..' y avanza.

- 3 = totales: barre (posicion, slot) SIEMPRE desde (1,1) (1332-1336) y manda '@100'+pos (v3) o 'C'+pos+prod+'1' a las posiciones en [1,3] con SwTotales. Timeout >10 ticks (2.75 s): inyecta '.N00..', que no limpia el flag, y vuelve a pedir lo mismo (posible ciclo infinito).

- 4 = recorre los 200 TabCmnd activos y ejecuta OCC/OCL/FINV/EFV/DVC/REANUDAR/TOTAL/CPREC. Los envios van a ListaCmnd. Pasa a NumPaso:=0 solo si no hay respuesta pendiente. Timeout >3 ticks (1 s): inyecta NAK.

- NumPaso 5 es inalcanzable: en 2201-2202 cualquier valor >4 vuelve a 0.

- Un NAK recibido hace Inc(NumPaso) (815-816), lo que salta al paso siguiente.

- La cola ListaCmnd solo se vacia en ProcesaLinea (1290-1295), uno por respuesta. ComandoConsolaBuff transmite solo si la cola esta vacia y SwEsperaRsp=False. Esto produce el interbloqueo descrito en los hallazgos.



Esperas activas:

- Timer2Timer: for 0..100 Sleep(10), de 1 a 1.6 s por intento de reconexion.

- EsperaMiliSeg (ULIBGRAL, no incluido en el repo) en 974 y 980 (500 ms cada una, setup), 1007 (100 ms por posicion cerrada al inicio), 1429 y 1518 (500 ms por reintento de preset). Si duerme, bloquea el hilo principal (socket, timers y serial); si bombea mensajes, permite reentrar a ProcesaLinea/Timer1Timer/ClientSocket1Read.

- No hay Application.ProcessMessages explicito en el archivo.



Tiempo efectivo por ciclo:

- Estacion en reposo: B00 + respuesta (unos 50-100 ms segun el baud y la latencia de la PAM) + 250 ms hasta el siguiente tick, unos 0.3-0.35 s.

- Estacion con N posiciones despachando o en EOT: se suma una ida y vuelta 'A' por posicion en cada ciclo, mas los totales despues de cada venta, mas los comandos.

- Arranque: 2.75 s por posicion para el nivel de precio 'T', mas 1 s de setup.

- El JSON al Bridge sale una vez por ciclo + 250 ms, no cada 250 ms.



Tramas parciales (784-823):

- Los bytes se acumulan en LineaBuff y se pasan a Linea hasta ETX+1 byte (BCC) o hasta un ACK/NAK.

- Solo se procesa UNA trama por evento; lo que sobra espera al siguiente evento.

- ComandoConsola borra LineaBuff en cada envio (727) pero no Linea, SwBcc ni FinLinea, asi que restos de respuestas tardias se pegan a la siguiente.

- No se resincroniza en STX (ProcesaLinea asume que el byte 1 es STX, 850) y el BCC recibido nunca se valida.

### Contrato con el Bridge, visto desde este módulo

- **Conexión:** TClientSocket ClientSocket1 (.dfm: ctNonBlocking, Port=0) hacia PDISPENSARIOS.ini [CONF] ServidorSocket (default 127.0.0.1:1004). Se lee en ServiceExecute (lineas 275-276, StrToInt sin default). No se activa en ServiceExecute: la primera activacion es ClientSocket1.Active:=True dentro de Timer2Timer (327), que corre en el hilo principal. Por eso ScktComp crea el HWND del socket en el hilo principal y OnConnect/OnRead/OnDisconnect se ejecutan ahi. Es distinto de Bennett, que lo activa en ServiceExecute (UIGASBENNETT.pas 276, hilo del servicio). No hay manejador OnError. Responder (485-502) envia por socketResponse (asignado al final de ClientSocket1Read, 474) o por ClientSocket1.Socket; ambos son el mismo objeto. Registra 'E '+resp aunque SendText no haya enviado nada (desconectado o WSAEWOULDBLOCK).
- **Ciclo de envío:** Timer2 (200 ms, Enabled=True desde el .dfm) trabaja mientras no hay conexion, estado<=0 o el puerto esta cerrado. Envia 'PING' si respJson=False, o TlkJSON.GenerateText(rootJSON) completo. Cuando estado>0 y pSerial.Open, Timer2 se apaga y se enciende Timer1 (340-343, 351). Timer1 (250 ms) envia el JSON completo en el finally de CADA tick (2256-2266), sin revisar conectado, respJson ni si algo cambio. Pero pSerialTriggerAvail (789/821) y ComandoConsola (725/736) hacen Timer1.Enabled:=false/true en cada trama y en cada envio, y eso reinicia el intervalo. Con trafico serial continuo el tick no llega: el JSON sale una vez por ciclo de sondeo completo + 250 ms. Ademas, los comandos de un caracter '0'/'1' contestan de inmediato con el JSON (398, 405). No hay otro punto de envio.
- **PING vs JSON:** respJson empieza en False y Timer2 envia 'PING'. Cualquier mensaje del Bridge que pase por AddPeticionJSON pone respJson:=True (589). Eso incluye la respuesta '0\|DISPENSERS\|NOTHING' al primer PING, que agrega {Folio:0,Resultado:'True\|'} (423-424). Por eso desde el segundo envio Timer2 ya manda JSON, y PAM no necesita el auto-kick TRACE del Bridge para 'despertar'. respJson solo vuelve a False con el comando '0' (406). Timer1 ignora respJson y siempre manda JSON.
- **Peticiones:** AddPeticionJSON (563-596) mantiene en rootJSON.Peticiones un maximo de 2 objetos {Folio,Resultado} y borra el mas viejo al insertar (581-582). Nunca se limpian despues de enviarse, asi que cada resultado se repite en todos los JSON hasta que lo desplaza otro. Todo mensaje del Bridge agrega uno, incluido NOTHING con folio 0. Los comandos de despacho solo encolan en TabCmnd[1..200] mediante EjecutaComando (2036-2068): AUTHORIZE->OCC/OCL, STOP->DVC, START->REANUDAR, PAYMENT->FINV, PRICES->CPREC, TOTALS->TOTAL. Devuelven 'True\|<folioCmnd>\|' ('True\|0\|0\|0\|0\|0\|0\|folio\|' en TOTALS, 2351). El resultado real se obtiene con RESPCMND (2488-2513) una vez que NumPaso=4 lo proceso ('*' = pendiente). Como el Bridge confirma PRICES, AUTHORIZE y PAYMENT de inmediato con folio 0 (UIGASBRIDGE.pas 372-389), OpenGas no puede saber si un preset o un precio fallaron en la PAM. INITIALIZE, BLOCK, HALT, RUN, LOG y demas responden de forma sincrona en el mismo ClientSocket1Read.
- **Reconexión:** OnDisconnect (361-367): conectado:=False, Timer1.Enabled:=False (tambien detiene el sondeo serial) y Timer2.Enabled:=True. Timer2Timer hace ClientSocket1.Active:=True y luego espera activamente con for 0..100 Sleep(10) (1-1.6 s) a que conectado cambie. OnConnect se despacha por mensajes del hilo principal, que es el mismo que esta en Sleep, asi que conectado nunca cambia dentro del bucle: la espera siempre se agota, sale, y el siguiente tick (200 ms) ya ve conectado=True y envia. Si el Bridge esta caido, el error asincrono del connect se lanza como ESocketError dentro del WndProc del socket (no hay OnError) y el intento se repite cada 1.2-1.8 s, bloqueando el hilo principal mas de 80% del tiempo. Al reconectar, Timer2 reactiva Timer1 solo si estado>0 y pSerial.Open.
- **Comandos:**
  - NOTHING -> 'True\|' (agrega Peticion folio 0)
  - INITIALIZE json\|variables -> Inicializar: si ya estaba inicializado reinicia con LiberaInicializacion; configura puerto y PosCarga; variables DECIMALESLITROS/DECIMALESPRECIO/DECIMALESPESOS/SETUPPAM1000/VERSIONPAM1000/VALIDARMANGUERA/AJUSTEPAM; precios LPrecios[ProductId]; en modoAuto guarda jsonInitialize en el ini
  - PARAMETERS -> 'True\|' (no hace nada)
  - LOGIN usuario\|password (MD5 de usuario\|fecha-minuto) / LOGOUT; el Token no se exige en ningun comando
  - PRICES p1\|p2\|.. -> EjecutaComando('CPREC ..'); comandos X00<prod><nivel>00<precio4> para contado y credito
  - AUTHORIZE pos\|comb\|importe\|litros\|finv -> OCL si litros>0, si no OCC con importe; comb vacio='00'
  - STOP pos -> DVC (E<pos>); START pos -> REANUDAR (G<pos>)
  - SELFSERVICE pos -> ModoOpera='Prepago'; FULLSERVICE pos -> tambien 'Prepago' (bug, no cambia nada)
  - BLOCK/UNBLOCK pos (0=todas) -> SwDesHabilitado; sin respuesta si pos esta entre MaxPosCarga+1 y 32
  - PAYMENT pos -> FINV (R<pos> si estatus 3)
  - TOTALS pos -> TOTAL; luego RESPCMND devuelve litros\|importe de 3 productos
  - HALT -> Detener (cierra puerto); RUN -> Iniciar (abre puerto, estado 1); SHUTDOWN -> ServiceThread.Terminate; TERMINATE -> estado -1
  - TRACE -> GuardarLog; SAVELOGREQ -> GuardarLogPetRes; LOG n / LOGREQ n -> ultimas n+1 lineas del log en Resultado
  - RESPCMND folioCmnd -> resultado de TabCmnd
  - '0'/'1' (Bridge los manda como 'folio\|DISPENSERS\|0/1', comando '1') -> cierran o abren el puerto, contestan '1' y envian el JSON de inmediato
  - STATE/STATUS/TRANSACTION y cualquier otro -> 'False\|Comando desconocido\|' (los contesta el Bridge desde el snapshot)
- **Campos JSON:**
  - Estado (entero: -1 no inicializado, 0 inicializado/detenido, 1 corriendo; no cambia con el comando '0')
  - PosCarga[].DispenserId
  - PosCarga[].HoraOcc ('yyyy-mm-ddThh:nn'; Now en cada lectura A final, '1899-12-30T00:00' al inicializar)
  - PosCarga[].Manguera (TMang/HoseId de la ultima venta concluida; 0 si ValidaMang descarta la lectura)
  - PosCarga[].Combustible (CombActual, remapeado por LigueCombustibles)
  - PosCarga[].Estatus (codigo PAM crudo 0,1,2,3,5,6,8,9; sin 7 para bloqueadas)
  - PosCarga[].Volumen / Precio (0 mientras despacha) / Importe (en vivo durante el despacho)
  - PosCarga[].Hoses[].HoseId / ProductId / Total (TotalLitros por slot; el Bridge no lo usa)
  - Peticiones[].Folio / Peticiones[].Resultado (maximo 2, se reenvian en cada JSON)
- **Desviaciones respecto a otros drivers:**
  - Timer1 envia el JSON completo en cada tick sin revisar conectado y sin limitar la frecuencia. Team limita con MsEnvioJSON=750 ms (UIGASTEAM.pas 2366-2370); Gilbarco y Wayne2W exigen conectado y xTurnoSocket=3 (UIGASGILBARCO.pas 2912-2914, UIGASWAYNE2W.pas 2958-2960); HongYang publica solo cuando hay cambios (commit fd48cc2).
  - El socket se activa en Timer2Timer y no en ServiceExecute como Bennett: sus eventos corren en el hilo principal (menos concurrencia que Bennett) y el bucle Sleep(10) de reconexion nunca puede ver conectado=True.
  - Publica Estatus con el codigo crudo de la PAM (877) aunque el propio driver calcula el mapeo historico (6->0, bloqueada->7) en xestado y lo tira (1039-1051). Bennett publica el estado mapeado (UIGASBENNETT.pas 1351-1369).
  - HoraOcc toma Now en cada lectura A final (1199). Wayne, Gilbarco y HongYang publican una hora fija de la venta (UIGASWAYNE.pas 2018, UIGASGILBARCO.pas 2697, UIGASHONGYANG.pas 1578 HoraFV).
  - El flag existe de AgregaPosCarga se reinicia por posicion y no por manguera. Team y Wayne2W ya lo corrigieron (UIGASTEAM.pas 859, UIGASWAYNE2W.pas 685).
  - FULLSERVICE deja ModoOpera='Prepago'. Wayne2W ya lo corrigio a 'Normal' (UIGASWAYNE2W.pas 3432).
  - No detecta perdida de comunicacion por posicion ni global. Gilbarco reporta sin comunicacion tras MaxFallasEstatus=3 (commit 34a7278, UIGASGILBARCO.pas 2585-2600).
  - Un preset de importe mayor a 9999 se convierte en venta libre. Team lo rechaza (UIGASTEAM.pas 2059-2060) y Wayne2W lo convierte a litros (commit 4d45d27).
  - No valida que la posicion este registrada en INITIALIZE (en Bennett lo hace SwRegistrada, commit d9151e4).
  - El comando '0' contesta '1' y no cambia estado ni detenido; PARAMETERS es no-op; TRANSACTION/STATUS/STATE caen a 'Comando desconocido' (igual que en los demas, porque los resuelve el Bridge).

### Bloques duplicados con otros módulos

| Rutina | Líneas | Nota |
|---|---|---|
| AgregaLog / AgregaLogPetRes | 599-617, 619-637 | Las dos son la misma funcion. Identicas a Bennett, HongYang, Kairos y Team; AgregaLogPetRes tambien a Triton y Wayne; Triton y Wayne difieren en unos 16 caracteres en AgregaLog. El Bridge tiene la misma version en AgregaLogOG. Son candidatas a una unidad comun UIGASCOMUN con ring buffer. |
| AddPeticionJSON / SetEstadoJSON / ActualizaCampoJSON / ApplyTotalLitrosToJSON | 563-596, 550-561, 504-548, 2926-2961 | AddPeticionJSON es identica en Bennett, HongYang, Triton, Wayne y Wayne2W (Gilbarco +5 caracteres). SetEstadoJSON es identica en HongYang y Team. ActualizaCampoJSON es casi identica en Bennett; Wayne, Wayne2W, Triton y HongYang agregan el log 'DispenserId no encontrado' y GuardarLog. ApplyTotalLitrosToJSON difiere en 1-12 caracteres en HongYang, Triton, Wayne y Gilbarco; todas comparten la busqueda por indice. |
| Timer2Timer / ClientSocket1Connect / ClientSocket1Disconnect / Responder | 319-353, 355-359, 361-367, 485-502 | Timer2Timer difiere en unos 10-54 caracteres en todos los drivers de Bridge (Wayne y Gilbarco son casi iguales); todos tienen el bucle Sleep(10) x101. Connect y Disconnect son identicos en Team, Triton, Wayne y HongYang. Responder es identico en Team y Triton, y difiere en 5-24 caracteres en Wayne, Gilbarco y HongYang. |
| ClientSocket1Read (despacho de TMetodos) | 369-483 | Misma estructura en todos los drivers de Bridge: folio y comando por ExtraeElemStrSep, ruta '0'/'1', reconstruccion de parametros y case GetEnumValue. La version mas cercana es Wayne (unos 96 caracteres de diferencia); el resto difiere por comandos propios. |
| ServiceExecute / Inicializar / LiberaInicializacion / Terminar | 268-317, 2643-2733, 2735-2758, 2760-2775 | ServiceExecute difiere en unos 28 caracteres con Wayne2W y unos 48 con Gilbarco. Inicializar y LiberaInicializacion comparten esqueleto (modoAuto y jsonInitialize, Consoles/Dispensers/Products, variables por NoElemStrEnter) con variables propias de cada marca. Terminar es identico en Team y difiere en 1 caracter en HongYang y Wayne. |
| IniciaPSerial | 644-712 | Identica en Team; difiere en 1 caracter en Bennett, HongYang, Triton, Wayne y Wayne2W. |
| AgregaPosCarga | 1896-2021 | Mismo patron que Bennett (unos 105 caracteres) y Wayne (unos 162): reinicio de TPosCarga, reutilizacion del nodo PosCarga, Hoses y existe. Comparte el bug de 'existe' por posicion, ya corregido en Team y Wayne2W. |
| Comandos de OpenGas hacia TabCmnd: IniciaPrecios, EjecutaComando, AutorizarVenta, DetenerVenta, ReanudarVenta, FinVenta, TotalesBomba, RespuestaComando, ResultadoComando | 2023-2034, 2036-2068, 2070-2113, 2115-2143, 2269-2282, 2335-2356, 2488-2513, 2567-2581 | AutorizarVenta, DetenerVenta, ReanudarVenta, FinVenta y TotalesBomba son identicas en Bennett y Team, y difieren en 0-2 caracteres en Wayne, Wayne2W, HongYang y Triton. IniciaPrecios y RespuestaComando son identicas en Team. EjecutaComando difiere en unos 2 caracteres en Team y Kairos (con la misma lectura de TabCmnd[201]). ResultadoComando es identica en Bennett. |
| ActivaModoPrepago / DesactivaModoPrepago / Bloquear / Desbloquear | 2145-2193, 2583-2641 | Copias casi identicas en Wayne (1-6 caracteres) y Bennett (7). El bug 'Prepago' en DesactivaModoPrepago se repite en Bennett, Team y Wayne; Wayne2W ya lo corrigio. Bloquear y Desbloquear difieren en unos 12 caracteres en Gilbarco. |
| Detener / Iniciar (HASP comentado) / Shutdown / ObtenerEstado | 2358-2384, 2386-2444, 2446-2454, 2456-2459 | Shutdown es identico en Team y difiere en 0-3 caracteres en los demas. ObtenerEstado es identico en Bennett y Kairos. Iniciar comparte el bloque HASP comentado (2394-2419) con todos los drivers del commit d3bdad5. |
| GuardarLog / GuardarLogPetRes / ObtenerLog / ObtenerLogPetRes / GuardaLogComandos | 2461-2486, 2515-2565, 2862-2880 | ObtenerLog y ObtenerLogPetRes son identicas en Bennett y difieren en 1-8 caracteres en HongYang, Triton, Wayne y Wayne2W (mismo off-by-one). GuardarLogPetRes es identica en Bennett y difiere en unos 3 caracteres en Team. GuardaLogComandos es identica en Bennett y difiere en unos 3 caracteres en Wayne2W (mismo Exception.Create sin raise). |
| Login / Logout / MD5 / Encrypt / Decrypt / CRC16 | 2830-2860, 2882-2916, 2777-2789 | Login, Logout y MD5 son identicas en Bennett y Team; MD5 tambien en Kairos, Triton, Wayne y Wayne2W. CRC16 es identica en Bennett, HongYang y Wayne, y en el Bridge (UIGASBRIDGE.pas 459-471). Encrypt y Decrypt tienen variantes en Bennett y HongYang. |
| NoElemStrEnter / ExtraeElemStrEnter / FechaHoraExtToStr | 2791-2828, 639-642 | Las funciones Enter difieren en 2-7 caracteres en Bennett, Kairos, Team, Wayne y Wayne2W. FechaHoraExtToStr es identica en Bennett y Team (y equivalente en el Bridge). Deberian vivir en ULIBGRAL o en una unidad comun. |
| ValidaCifra / CombustibleEnPosicion / MangueraEnPosicion / PosicionDeCombustible | 1855-1879, 1831-1894 | ValidaCifra es identica en Bennett. CombustibleEnPosicion y PosicionDeCombustible difieren en 0-14 caracteres en Gilbarco, Bennett, Team y Kairos. |
| TransaccionPosCarga / EstadoPosiciones (muertas) | 2284-2333 | TransaccionPosCarga es identica en Kairos y EstadoPosiciones difiere en unos 6 caracteres en Kairos. Son vestigios del protocolo directo; en PAM nadie las llama. |
| ComandoConsola / ComandoConsolaBuff / CalculaBCC / XorChar | 714-738, 2918-2924, 740-782 | ComandoConsola difiere en 1 caracter en Bennett. CalculaBCC difiere en unos 15 caracteres en Bennett. XorChar (XOR bit a bit) solo esta aqui y en Wayne; se puede sustituir por Chr(Ord(a) xor Ord(b)). |
| Bloque TOTAL dentro de ProcesaLinea | 1628-1665 | El mismo formato 'OK'+litros\|pesos de 3 productos y la misma estimacion por volumen estan en Bennett 1646/1655, HongYang 2248, Kairos 2452, Team 2142, Wayne 1798 y Wayne2W 2383. |
| Bloques OCC y OCL (duplicados entre si) | 1395-1483, 1484-1566 | Unas 85 lineas casi identicas dentro del mismo archivo; solo cambia el calculo de SnImporte/SnLitros. Tambien hay variantes en Wayne y Bennett. Conviene una funcion AplicaPreset(xcmnd, esLitros). |
| Envio del JSON en el finally de Timer1Timer | 2256-2266 | Patron compartido con Team (2366-2378, con throttle MsEnvioJSON), Gilbarco (2912-2922) y Wayne2W (2958-2965), estos dos con conectado y xTurnoSocket. PAM es la version sin protecciones. |

## Hallazgos (50)

<a id="PAM-01"></a>
#### PAM-01 · 🔴 Crítica · robustez · bug — El sondeo serial se bloquea para siempre: B00 se encola sin ningun comando en vuelo (HALT/RUN, '0'/'1', timeout en NumPaso=1)

- **Ubicación:** `UIGASPAM.pas` líneas 2240-2252, 2918-2924, 1290-1295, 2358-2373, 2421-2435, 386-408, 1699-1702
- **Se atiende en:** [E1.4](../PLAN_OPTIMIZACION.md#e14--sondeo-que-se-congela-livelocks-y-bloqueos-de-la-máquina-de-estados)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  La cola ListaCmnd solo se vacia en la linea 1290, dentro de ProcesaLinea, y ProcesaLinea solo corre cuando llega una trama o cuando Timer1 inyecta un timeout en NumPaso 2/3/4. ComandoConsolaBuff solo transmite si la cola esta vacia y no hay respuesta pendiente; en otro caso encola.
  
  En NumPaso=1, a los 11 ticks Timer1 pone SwEsperaRsp:=False y llama ComandoConsolaBuff('B00'). Si la cola tenia algo, 'B00' se agrega y no se transmite nada. Como no llega ninguna trama, ProcesaLinea no corre, y cada 2.75 s se repite agregando otro 'B00'.
  
  Como se llega a ese estado:
  - Detener (HALT) cierra el puerto sin limpiar SwEsperaRsp ni ListaCmnd. Si habia un comando en vuelo (en reposo SwEsperaRsp=True alrededor del 30% del tiempo; mas en una estacion ocupada), al RUN Iniciar solo pone numPaso:=0 y el primer B00 se encola.
  - El comando '1' pone SwEsperaRsp:=False pero no limpia ListaCmnd.
  - En operacion normal: se pierde una respuesta en NumPaso=1 cuando el proceso de 'B' dejo comandos encolados ('L' de posiciones cerradas en 949, mapeos), o 'ERROR PASO 5' fuerza NumPaso:=0 con la cola pendiente.
  
  Solo un INITIALIZE (LiberaInicializacion 2748-2749) o reiniciar el servicio lo recupera.
- **Evidencia:** Timer1Timer 2241-2252: 'if ContEspera1>10 then SwEsperaRsp:=False else exit; NumPaso:=1; ss:=''B00''; ... ComandoConsolaBuff(ss);'. ComandoConsolaBuff 2920-2923: 'if (ListaCmnd.Count=0)and(not SwEsperaRsp) then ComandoConsola(ss) else ListaCmnd.Add(ss);'. El unico consumidor de la cola esta en 1290: 'if (ListaCmnd.Count>0)and(not SwEsperaRsp) then ...'. Detener 2367-2371 e Iniciar 2427-2434 no tocan ListaCmnd ni SwEsperaRsp; el comando '1' (390-393) no limpia la cola.
- **Impacto:** La estacion completa deja de sondearse: sin estatus, sin lecturas de venta, sin presets ni cambios de precio. Mientras tanto Timer1 sigue mandando el JSON congelado cada 250 ms, asi que el Bridge no lo marca como obsoleto y OpenGas sigue autorizando ventas que nunca se aplican.
- **Recomendación:**
  1) En Detener, Iniciar, los comandos '0'/'1' y LiberaInicializacion: ListaCmnd.Clear; SwEsperaRsp:=False; LineaBuff:=''; Linea:=''; SwBcc:=False; FinLinea:=False; NumPaso:=0.
  2) Reescribir ComandoConsolaBuff: si not SwEsperaRsp, encolar ss y transmitir la cabeza (ListaCmnd[0]); si hay respuesta pendiente, solo encolar.
  3) En el timeout de NumPaso=1, despachar la cola con esa misma rutina (o limpiarla).
  4) No duplicar 'B00' en la cola y limitar ListaCmnd (p.ej. 50 elementos, con log).
  Prueba en banco: HALT con una lectura 'A' en vuelo y luego RUN; debe verse 'E <STX>B00' en menos de 1 s. Repetir con el cable desconectado durante un ciclo con 2 posiciones en estado 6.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="PAM-02"></a>
#### PAM-02 · 🔴 Crítica · correccion · bug — Un preset de importe mayor a 9999 se convierte en venta libre ('S'+pos)

- **Ubicación:** `UIGASPAM.pas` líneas 1433-1447, 1734-1739, 1800-1805
- **Se atiende en:** [E1.3](../PLAN_OPTIMIZACION.md#e13--presets-montos-decimales-y-validaciones)
- **Verificación:** sin verificación independiente
- **Qué pasa:** En OCC, si el importe solicitado es mayor a 9999 se pone SnImporte:=0, y la validacion ValidaCifra solo corre cuando SnImporte<>0. EnviaPreset y EnviaPreset3 interpretan snimporte=0 como venta libre: mandan 'S'+pos (autorizacion sin limite) con ImportePreset=999. El comando responde OK.
- **Evidencia:** 1440-1441: 'if SnImporte>9999 then SnImporte:=0;'; 1442: 'if SnImporte<>0 then begin ... ValidaCifra'; 1801-1804: 'if (snimporte=0) then begin ss:=''S''+IntToClaveNum(xpos,2); TPosCarga[xpos].ImportePreset:=999;'. Team rechaza el mismo caso (UIGASTEAM.pas 2059-2060: 'Importe fuera de rango valido'). Wayne2W lo convierte a litros (commit 4d45d27).
- **Impacto:** Un prepago de 10,000 pesos o mas (camiones de diesel) deja la bomba sin limite y el cliente puede cargar mas de lo pagado. El POS recibe True de inmediato porque AUTHORIZE es fire-and-forget en el Bridge.
- **Recomendación:** Sustituir 1440-1441 por rsp:='Valor excede maximo permitido (9999.99)' sin enviar nada, o convertir a litros (SnLitros:=SnImporte/LPrecios[comb], OCL) como hace Wayne2W. Tratar como venta libre solo el importe 0 explicito. Prueba: AUTHORIZE 1|1|10000.00|0|0 y luego RESPCMND <folio> debe dar False, y en el log no debe aparecer 'E <STX>S01'.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="PAM-03"></a>
#### PAM-03 · 🔴 Crítica · robustez · bug — Ciclo infinito en la lectura de totales (NumPaso=3) que deja de sondear la estacion entera

- **Ubicación:** `UIGASPAM.pas` líneas 1329-1361, 2212-2218, 1219-1277, 2003, 1183
- **Se atiende en:** [E1.4](../PLAN_OPTIMIZACION.md#e14--sondeo-que-se-congela-livelocks-y-bloqueos-de-la-máquina-de-estados)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  Cada vez que se entra a NumPaso=3, PosicionDispenActual:=0 hace que el barrido empiece otra vez en (posicion 1, slot 1). Se pide el primer slot con SwTotales=True de una posicion en [1,3]. Si la respuesta no limpia ese flag, se vuelve a pedir lo mismo para siempre.
  
  Casos en que el flag no se limpia:
  - Timeout: la inyeccion '.N00..' no limpia nada.
  - Respuesta '@' mas corta que nocomb: se leen lin[37]/lin[66]/lin[95] fuera de la cadena.
  - El grado devuelto no coincide con IntToStr(TComb[i]): productos >= 10, o la manguera esta configurada en OpenGas pero no mapeada en la PAM.
  - Trama corrupta.
  
  Nunca se vuelve a NumPaso 0 (B00) ni a NumPaso 4 (comandos). Solo un NAK escapa, porque incrementa NumPaso. Al inicializar todos los slots arrancan con SwTotales=True (2003), asi que la discrepancia se presenta desde el arranque.
- **Evidencia:** 1332-1336: 'PosicionDispenActual:=0; repeat if PosicionDispenActual=0 then begin PosicionCargaActual:=1; PosicionDispenActual:=1; end'. 1348-1353: 'if (estatus in [1,3]) and (swtotales[PosicionDispenActual]) then begin ... ComandoConsolaBuff(''@10''+''0''+...); exit;'. Timeout en 2214-2217: 'LineaTimer:=''.N00..''; ProcesaLinea;' (la letra 'N' no coincide con ningun case).
- **Impacto:** Mientras persista la condicion no se leen estatus, ventas ni se procesan presets/precios/paros en NINGUNA posicion, y el JSON queda congelado. Un solo slot mal configurado o una posicion que no contesta totales basta para bloquear la estacion.
- **Recomendación:**
  1) Llevar un contador de intentos por (posicion, slot) y, al tercer fallo o timeout, poner SwTotales[i]:=False y registrar 'totales no disponibles'.
  2) Reanudar el barrido desde el ultimo indice en lugar de (1,1).
  3) Limitar el paso 3 a N solicitudes por ciclo y volver siempre a B00.
  4) Validar Length(lin) antes de leer lin[37]/[66]/[95].
  Prueba: configurar en OpenGas una posicion con 3 mangueras cuando la PAM tiene 2 mapeadas; el ciclo B00 debe seguir corriendo.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="PAM-04"></a>
#### PAM-04 · 🟠 Alta · correccion · bug — EnviaPreset3 reporta error con un SwError de la trama ANTERIOR aunque el preset si se envio

- **Ubicación:** `UIGASPAM.pas` líneas 1817-1825, 814-816
- **Se atiende en:** [E1.3](../PLAN_OPTIMIZACION.md#e13--presets-montos-decimales-y-validaciones)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  EnviaPreset3 primero encola o envia el preset y despues revisa SwError. SwError refleja si la ultima trama recibida fue un NAK, no la respuesta a este preset, que todavia no llega.
  
  NumPaso=4 se alcanza justo despues de un NAK (un NAK a una peticion de totales hace Inc(NumPaso) 3->4 y llama ProcesaLinea). En ese caso el preset se manda a la PAM pero el comando queda con 'Error al Activar Posicion de Carga'. Tambien se marca SwAplicaCmnd y SwOCC:=false, asi que no hay seguimiento.
- **Evidencia:** 1817: 'ComandoConsolaBuff(ss);' seguido de 1822-1825: 'if SwError then begin rsp:=''Error al Activar Posicion de Carga''; exit; end;'. SwError se asigna en pSerialTriggerAvail 814: 'SwError:=(lineaTimer=idNak); if SwError then Inc(NumPaso);'.
- **Impacto:** OpenGas (via RESPCMND) cree que el preset fallo mientras la bomba queda autorizada y despacha. Puede cancelar o reembolsar el prepago o reintentar; el reintento encuentra la posicion en 9 y contesta 'Posicion de Carga no Disponible'. Resultado: venta sin cobro o conciliacion incorrecta.
- **Recomendación:** Quitar la revision de SwError en EnviaPreset3. Si se quiere confirmar el preset, guardar el comando enviado (LinCmnd/CharCmnd) y evaluar el ACK/NAK de ESE envio en ProcesaLinea, o confirmar con el estatus 9 en el siguiente B (el flujo SwOCC/ContOCC ya lo hace). Prueba: forzar un NAK a '@10' y enviar AUTHORIZE en el mismo ciclo; RESPCMND debe dar True y la posicion pasar a 9.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="PAM-05"></a>
#### PAM-05 · 🟠 Alta · correccion · bug — PRICES (CPREC) responde OK aunque el precio no se aplique: precio con 3 decimales o >= 100, NAK sin reintento, LPrecios actualizado antes de validar

- **Ubicación:** `UIGASPAM.pas` líneas 1666-1691, 1284-1287
- **Se atiende en:** [E1.6](../PLAN_OPTIMIZACION.md#e16--precios-aplicar-solo-lo-confirmado)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  Por cada precio:
  - Se asigna LPrecios[i] antes de validar.
  - Si ValidaCifra(precio,2,2) falla (3 decimales, p.ej. 23.459, o >= 100.00), el comando X simplemente no se envia y no se reporta nada.
  - Los X se encolan sin comprobar su ACK; un NAK de la PAM en NumPaso 4 solo pone ContEsperaPaso4:=0.
  - Al final rsp='' se convierte en 'OK'.
  - Si llegan mas de 4 precios, i>4 escribe fuera de LPrecios[1..4] (ver el hallazgo de fuera de rango).
  Como el Bridge confirma PRICES de inmediato con folio 0, OpenGas nunca se entera.
- **Evidencia:** 1672-1675: 'LPrecios[i]:=precioComb; if ValidaCifra(precioComb,2,2)=''OK'' then begin if precioComb>=0.01 then begin ComandoConsolaBuff(''X''+''00''+IntToStr(i)+''1''+...'; 1690-1691: 'if rsp='''' then rsp:=''OK'';'. En el Bridge: UIGASBRIDGE.pas 372-385 'if metodoEnum in [PRICES_e, ...] then p.CliSock:=nil ... ResponderOG(''DISPENSERS|PRICES|True|0|'')'.
- **Impacto:** La PAM sigue vendiendo con el precio anterior mientras OpenGas y el calculo de TOTAL (que usa LPrecios) asumen el nuevo: ventas al precio equivocado (riesgo PROFECO) y totales en pesos inconsistentes.
- **Recomendación:**
  1) Validar antes de asignar; redondear a 2 decimales (Trunc(p*100+0.5)) o rechazar con rsp de error explicito.
  2) Limitar i a 1..4 (o al maximo ProductId).
  3) Llevar la cuenta de los X pendientes y marcar error si alguno recibe NAK, con un reintento.
  4) Actualizar LPrecios solo despues del ACK.
  5) Registrar en el log cada precio rechazado.
  Como extension de contrato, que el Bridge espere el folio de PRICES (CliSock real) para propagar el error.
  Prueba: PRICES 23.459|24.10|25.00 debe dar error en RESPCMND y no cambiar LPrecios[1].
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="PAM-06"></a>
#### PAM-06 · 🟠 Alta · correccion · bug — Escrituras y lecturas fuera de rango sin validar en arreglos globales, compiladas con {$R-}

- **Ubicación:** `UIGASPAM.pas` líneas 2719, 1672, 1957-1960, 1991-2001, 1628-1638, 2341-2347, 1183, 1649-1651, 1790-1797, 2041-2048, 1657-1659, 234-238
- **Se atiende en:** [E1.8](../PLAN_OPTIMIZACION.md#e18--índices-fuera-de-rango-y-carga-de-posiciones-r-)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  PDISPENSARIOS.cfg compila con -$R- y -$Q-, asi que ningun indice se verifica. Indices que vienen de datos externos:
  - LPrecios[productID] en INITIALIZE (2719) y LPrecios[i] en CPREC (1672), arreglo 1..4.
  - TPosCarga[xpos] con DispenserId >32 o 0 en AgregaPosCarga (1957-1960).
  - TComb/TCombx/TMang/TPosx[NoComb] con mas de 4 productos distintos (1991-1994).
  - TOTAL con xpos fuera de 1..32: TotalesBomba solo valida xpos<1 (2342) y el bloque TOTAL escribe SwTotales[1..4] y HoraTotales en TPosCarga[xpos] (1632-1660).
  - SwTotales[PosActual] y TotalLitros[PosActual], donde PosActual es la posicion de manguera de la PAM (1..6) y no un slot 1..4 (1183, 1650-1651).
  - xprodauto[xp] con xp=TPosx>6 cuando xcomb=0 (1797).
  - TabCmnd[201], leido y potencialmente escrito, cuando los 200 slots estan ocupados (2043-2048: la condicion lee TabCmnd[ind] antes de probar ind>200).
  - LPrecios[TCombx[3]] con TCombx[3]=0 en posiciones con menos de 3 productos (1657-1659).
  Por el orden de las variables (234-238), LPrecios[5] probablemente cae sobre MaxPosCarga y MaxPosCargaActiva; todos los bucles 'for xpos:=1 to MaxPosCarga' se recorrerian entonces con un limite basura.
- **Evidencia:** 2719: 'LPrecios[productID]:=productos.Child[i].Field[''Price''].Value;' sin rango. 236-238: 'LPrecios :array[1..4] of Double; MaxPosCarga:integer; MaxPosCargaActiva:integer;'. 1632: 'with TPosCarga[xpos] do' con xpos:=strtointdef(...,0) (1630). 2048: 'until (not TabCmnd[ind].SwActivo)or(ind>200);'.
- **Impacto:** Corrupcion silenciosa de memoria: precios y totales equivocados, limites de bucle basura, AV y caida del servicio en condiciones como ProductId>4, cinco precios en PRICES, DispenserId>32, TOTALS de una posicion inexistente o mangueras en las posiciones 5/6 de la PAM.
- **Recomendación:**
  Validar todos los indices externos en la entrada:
  - productID y la posicion i del precio en 1..High(LPrecios).
  - DispenserId en 1..MaximoDePosiciones.
  - NoComb < MCxP (rechazar el INITIALIZE en otro caso).
  - xpos in [1..MaxPosCarga] en TotalesBomba y en el bloque TOTAL.
  - Convertir PosActual a indice de slot antes de usar SwTotales/TotalLitros.
  - En EjecutaComando, probar ind>200 antes de leer TabCmnd[ind].
  Compilar las pruebas con {$R+} para detectar mas casos.
- **Esfuerzo:** M · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="PAM-07"></a>
#### PAM-07 · 🟠 Alta · rendimiento · bug — El JSON al Bridge (y con el los comandos de OpenGas) se atrasa un ciclo completo porque cada trama reinicia Timer1

- **Ubicación:** `UIGASPAM.pas` líneas 784-823, 714-738, 2256-2266
- **Se atiende en:** [E4.1](../PLAN_OPTIMIZACION.md#e41--responder-al-bridge-en-cuanto-se-procesa-un-comando-y-homologar-la-cadencia)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  El unico envio periodico del JSON esta en el finally de Timer1Timer. pSerialTriggerAvail y ComandoConsola hacen Timer1.Enabled:=false y luego true en cada trama recibida y en cada comando enviado. En TTimer eso reinicia el intervalo (KillTimer y SetTimer), asi que con trafico continuo (lecturas A encadenadas, totales, CPREC, mapeos) Timer1 no dispara hasta 250 ms despues de la ultima trama.
  
  El driver solo recibe un comando nuevo del Bridge como respuesta a cada envio. Por eso cada comando tarda hasta un ciclo en entregarse y su resultado otro ciclo en volver. Con varias posiciones despachando, el ciclo supera 1-2 s.
- **Evidencia:** 789 'Timer1.Enabled:=false;' / 821 'Timer1.Enabled:=true;' en pSerialTriggerAvail; 725/736 en ComandoConsola; 2258 'Responder(TlkJSON.GenerateText(rootJSON));' solo en el finally de Timer1Timer. En el Bridge, el timeout se mide desde el envio (UIGASBRIDGE.pas 875-889, TimeoutRespSrv=2 s) y la cola es estrictamente de una peticion en vuelo (TryStartNext 120-139).
- **Impacto:** Con carga, las peticiones que esperan folio (TOTALS, RESPCMND, BLOCK, HALT/RUN, INITIALIZE, LOG) caen en el 'Timeout excedido' del Bridge aunque el driver si las ejecuto. Toda la cola de OpenGas se atrasa y el snapshot envejece.
- **Recomendación:**
  Desacoplar el envio del sondeo:
  1) No tocar Timer1.Enabled en pSerialTriggerAvail ni en ComandoConsola; para evitar reentrada usar un flag de 'procesando'.
  2) Enviar el JSON por tiempo transcurrido (HoraUltJSON y MsEnvioJSON, como Team 2366-2370), llamado tanto desde Timer1 como al terminar ProcesaLinea, o con un TTimer dedicado al socket.
  Medir en el log el intervalo entre 'E {' consecutivos con 8 posiciones despachando; debe quedar en 250-750 ms.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="PAM-08"></a>
#### PAM-08 · 🟠 Alta · robustez · bug — La perdida de comunicacion con la PAM no se refleja en el JSON: Estatus queda congelado

- **Ubicación:** `UIGASPAM.pas` líneas 720-724, 2240-2246, 877, 2309-2333
- **Se atiende en:** [E1.9](../PLAN_OPTIMIZACION.md#e19--coherencia-del-estado-publicado-estatus-fin-de-venta-horaocc-estado)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Si la consola deja de responder (cable, falla de energia, puerto), Timer1 reenvia B00 cada 2.75 s pero nada pone Estatus=0. El unico indicador, ContadorAlarma>10, solo pone en ceros LinEstadoGen, que solo lee EstadoPosiciones, y esa funcion es codigo muerto (el Bridge responde STATUS con el snapshot). Timer1 sigue mandando el JSON con los ultimos estatus cada 250 ms, asi que el Bridge lo considera fresco.
- **Evidencia:** 722-724: 'inc(ContadorAlarma); if ContadorAlarma>10 then LinEstadoGen:=CadenaStr(length(LinEstadoGen),''0'');'. Estatus solo se escribe al procesar 'B' (877). Gilbarco implementa SinComunicacion con MaxFallasEstatus=3 (UIGASGILBARCO.pas 217, 2585-2640).
- **Impacto:** OpenGas ve las bombas en linea e inactivas, autoriza ventas (AUTHORIZE se confirma de inmediato) que nunca se aplican, y no avisa al operador.
- **Recomendación:** Contar los timeouts consecutivos de B00. A partir de 3 (unos 8 s), poner Estatus=0 en todas las posiciones del JSON y opcionalmente un campo o log 'SinComunicacion'; restaurar con la primera respuesta valida. Rechazar con error los OCC/OCL mientras no haya comunicacion. Prueba: desconectar el cable; STATUS debe pasar a '0000' en menos de 10 s.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="PAM-09"></a>
#### PAM-09 · 🟠 Alta · correccion · bug — HoraOcc se publica como Now en cada lectura A final: la hora de la venta se mueve y aparecen ventas fantasma al arrancar

- **Ubicación:** `UIGASPAM.pas` líneas 1199, 1969, 1304-1309
- **Se atiende en:** [E1.9](../PLAN_OPTIMIZACION.md#e19--coherencia-del-estado-publicado-estatus-fin-de-venta-horaocc-estado)
- **Verificación:** sin verificación independiente
- **Qué pasa:** En el bloque 'venta concluida', cada lectura A sobrescribe HoraOcc con la hora actual (resolucion de minuto). Las posiciones en 3 (EOT, esperando PAYMENT) y en 8 se leen en cada ciclo (estatus>1), asi que su HoraOcc avanza minuto a minuto hasta que se cobran. Al inicializar (swinicio2) o tras cada cambio de estatus (SwA) se relee la ultima venta y se publica con hora nueva. El campo HoraOcc del registro nunca se asigna; AgregaPosCarga lo publica como '1899-12-30T00:00'.
- **Evidencia:** 1199: 'ActualizaCampoJSON(xpos, ''HoraOcc'', FormatDateTime(''yyyy-mm-dd'',now)+''T''+FormatDateTime(''hh:nn'',now));' dentro del bloque que se ejecuta en cada lectura A con grado. Otros drivers usan una hora fija de fin de venta: UIGASWAYNE.pas 2018, UIGASGILBARCO.pas 2697, UIGASHONGYANG.pas 1578 (HoraFV).
- **Impacto:** TRANSACTION reporta una hora posterior a la real. Si OpenGas usa HoraOcc o (posicion, HoraOcc) para identificar ventas, puede duplicar o perder transacciones (dos ventas en el mismo minuto, o la venta previa releida al arrancar).
- **Recomendación:** Asignar TPosCarga[xpos].HoraOcc:=Now solo cuando se detecta el fin de una venta nueva (donde se pone swdesp:=true en 1179-1184, o en la transicion 2->1/3) y publicar ese valor. No publicar lecturas de swinicio2 como venta nueva. Agregar segundos al formato solo si OpenGas lo acepta (eso si toca contrato).
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="PAM-10"></a>
#### PAM-10 · 🟠 Alta · correccion · bug — Con ValidarManguera=Si, la primera lectura final pone la venta en ceros y se publica en el JSON

- **Ubicación:** `UIGASPAM.pas` líneas 1152-1164, 1194-1199
- **Se atiende en:** [E1.2](../PLAN_OPTIMIZACION.md#e12--importes-y-volúmenes-de-venta-mal-calculados)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Durante el despacho, MangAnterior:=0 (1096). En la primera lectura final se entra al else: MangAnterior:=manguera; importe:=0; precio:=0; volumen:=0. MangActual y CombActual quedan en 0. Aun asi las lineas 1194-1199 publican Volumen/Precio/Importe en 0, Manguera/Combustible en 0 y HoraOcc=Now. La venta correcta solo aparece en la siguiente lectura, si la posicion se vuelve a leer (depende de SwA o estatus>1).
- **Evidencia:** 1158-1163: 'else begin MangAnterior:=MangueraEnPosicion(xpos,PosActual); importe:=0; precio:=0; volumen:=0; end;' y despues, sin condicion, 1194: 'ActualizaCampoJSON(xpos, ''Volumen'', volumen);'.
- **Impacto:** Si OpenGas consulta TRANSACTION o STATE al ver la transicion a 1/3, toma una venta de 0 litros y 0 pesos con hora fresca; hay riesgo de registrar la venta en ceros.
- **Recomendación:** Cuando la lectura no se confirma, no tocar el JSON (salir antes de 1194) y forzar la relectura en el siguiente ciclo (SwA:=true). Mantener la venta anterior en el snapshot hasta confirmar. Probar con VALIDARMANGUERA=SI y una venta corta.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="PAM-11"></a>
#### PAM-11 · 🟠 Alta · protocolo · bug — El BCC de las tramas recibidas nunca se valida

- **Ubicación:** `UIGASPAM.pas` líneas 795-807, 849-853
- **Se atiende en:** [E2.8](../PLAN_OPTIMIZACION.md#e28--recepción-serial-robusta-tramas-bcc-acknak)
- **Verificación:** sin verificación independiente
- **Qué pasa:** pSerialTriggerAvail considera la trama completa en el byte siguiente a ETX, pero no compara ese byte con CalculaBCC del contenido. ProcesaLinea quita STX, ETX y BCC por posicion y parsea los digitos de volumen, importe, precio y totales sin verificar nada. Un digito alterado por ruido (EMI de motores en una estacion) se toma como valido; solo StrToFloat atrapa los caracteres no numericos.
- **Evidencia:** 799-804: 'if SwBcc then FinLinea:=true; if C=idETX then SwBcc:=true;' sin comparar el BCC. 850: 'lin:=copy(lineaTimer,2,length(lineatimer)-3);'. CalculaBCC (740-750) solo se usa al enviar (728).
- **Impacto:** Volumen, importe o totales incorrectos publicados como venta concluida (TRANSACTION) o como totalizador. Los ajustes x10 y AjustePAM pueden enmascarar o empeorar el error.
- **Recomendación:** Al cerrar la trama, calcular CalculaBCC(copy(Linea,2,len-2)) y compararlo con el ultimo byte; si no coincide, registrar 'BCC invalido', descartar y reintentar el mismo comando (o tratarlo como NAK). Agregar un contador de tramas invalidas al log. Prueba: inyectar una trama con un digito alterado desde un emulador serial.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="PAM-12"></a>
#### PAM-12 · 🟠 Alta · robustez · riesgo — Una desconexion del Bridge detiene tambien el sondeo de la PAM: se pierden ventas durante la caida

- **Ubicación:** `UIGASPAM.pas` líneas 361-367, 1171-1184
- **Módulos afectados:** UIGASPAM.pas, UIGASTEAM.pas, UIGASWAYNE.pas, UIGASGILBARCO.pas
- **Se atiende en:** [E2.1](../PLAN_OPTIMIZACION.md#e21--desacoplar-timer1-sondeo-serial-de-la-conexión-con-el-bridge)
- **Verificación:** sin verificación independiente
- **Qué pasa:** ClientSocket1Disconnect hace Timer1.Enabled:=False, y Timer1 es el motor de todo el ciclo serial. Mientras el Bridge esta caido o reiniciando no se lee la PAM. Una venta que empieza y termina en ese tiempo no pasa por estatus 2, asi que SwCargando no se activa, la deteccion EOT (1171-1184) no ocurre y los totales no se piden. Si en ese lapso hay dos ventas en la misma posicion, la primera se pierde porque la PAM solo entrega la ultima. El patron se comparte con Team (346-352), Wayne (2909-2915) y Gilbarco (3064-3069).
- **Evidencia:** 365: 'Timer1.Enabled:=False;' en OnDisconnect; Timer1 se reactiva solo en Timer2Timer al reconectar (340-343).
- **Impacto:** Transacciones perdidas o sin totales cada vez que se reinicia o falla el Bridge (despliegues, caidas); posiciones sin control.
- **Recomendación:** Mantener el sondeo independiente del socket: en OnDisconnect solo poner conectado:=False y activar Timer2 para reconectar, sin apagar Timer1, y hacer que el envio del JSON revise conectado (como Gilbarco o Wayne2W). Al reconectar, publicar el snapshot actual. Probar deteniendo el Bridge 60 s con una venta en curso.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="PAM-13"></a>
#### PAM-13 · 🟡 Media · protocolo · bug — Armado de tramas fragil: una trama por evento, sin resincronizar en STX, y LineaBuff se borra en cada envio

- **Ubicación:** `UIGASPAM.pas` líneas 784-823, 727, 849-853
- **Se atiende en:** [E2.8](../PLAN_OPTIMIZACION.md#e28--recepción-serial-robusta-tramas-bcc-acknak)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  Problemas del armado:
  - Solo se extrae una trama por OnTriggerAvail (while not FinLinea); el resto queda en LineaBuff.
  - ProcesaLinea casi siempre envia el siguiente comando, y ComandoConsola hace LineaBuff:='', con lo que se descarta una segunda trama que llego en el mismo bloque.
  - Linea (la trama parcial), SwBcc y FinLinea no se limpian al enviar ni al inyectar timeouts. Los restos de una respuesta tardia se pegan al inicio de la siguiente.
  - No se busca STX: ProcesaLinea asume que el byte 1 es STX. Un byte de ruido corre el parseo, lin[1] no coincide con ningun case y la respuesta se pierde, con un timeout de 2.75 a 5.25 s.
- **Evidencia:** 795: 'while (not FinLinea)and(Length(LineaBuff)>0) do'; 727: 'LineaBuff:='''';' en ComandoConsola; 850: 'lin:=copy(lineaTimer,2,length(lineatimer)-3);'. Linea solo se limpia en 811.
- **Impacto:** Respuestas perdidas, timeouts frecuentes ante ruido o respuestas tardias, y ciclos mas lentos; en combinacion con otros hallazgos puede llegar a bloquear.
- **Recomendación:**
  Parser incremental:
  1) Descartar los bytes previos a STX (excepto un ACK/NAK suelto).
  2) Procesar en un bucle todas las tramas completas del buffer.
  3) Validar el BCC.
  4) En ComandoConsola y en las inyecciones de timeout limpiar Linea, SwBcc y FinLinea junto con LineaBuff.
  Agregar pruebas unitarias del parser con bloques partidos y concatenados.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="PAM-14"></a>
#### PAM-14 · 🟡 Media · concurrencia · bug — Comandos directos (ComandoConsola) con otro comando en vuelo: colisiones half-duplex y ACK atribuido al comando equivocado

- **Ubicación:** `UIGASPAM.pas` líneas 912, 971-981, 989, 1004-1009, 947-950, 1278-1281
- **Se atiende en:** [E2.5](../PLAN_OPTIMIZACION.md#e25--reentrancia-comandos-del-bridge-durante-una-transacción-serial)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Durante el proceso de 'B' se mezclan ComandoConsolaBuff ('L' para posiciones cerradas en 949) con llamadas directas a ComandoConsola que ignoran SwEsperaRsp y la cola: 'T' de nivel de precio (912), D06222/D0 de setup (973-979), mapeo X (989) y otra 'L' (1006, duplicada respecto a 949). Puede haber dos o tres comandos sin respuesta a la vez en una linea half-duplex, y cada envio borra LineaBuff. Cualquier ACK recibido en NumPaso=1 marca swnivelprec en xPosT (1278-1281) aunque fuera el ACK de una 'L' o de un mapeo.
- **Evidencia:** 912: 'ComandoConsola(''T''+inttoclavenum(xpos,2)+''1'');'; 949: 'ComandoConsolaBuff(''L''+inttoclavenum(xpos,2));' y 1004-1007: 'ss:=''L''+...; ComandoConsola(ss); EsperaMiliSeg(100);'. 1279-1280: 'if xPosT in [1..MaxPosCargaActiva] then TPosCarga[xPosT].swnivelprec:=true;'.
- **Impacto:** Respuestas perdidas o mal atribuidas. Puede quedar el nivel de precio sin aplicar (los presets usan NivelPrec='1') o el mapeo incompleto; aumentan los timeouts al arrancar y con posiciones cerradas.
- **Recomendación:** Usar solo ComandoConsolaBuff, con un comando en vuelo a la vez. Atribuir ACK y NAK segun CharCmnd/LinCmnd del ultimo envio (swnivelprec solo si CharCmnd='T'). Eliminar la 'L' duplicada de 1004-1009 o la de 949. Quitar las EsperaMiliSeg entre comandos de setup y dejar que la respuesta avance la cola.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="PAM-15"></a>
#### PAM-15 · 🟡 Media · concurrencia · riesgo — EsperaMiliSeg dentro de ProcesaLinea: o bloquea el hilo principal o permite reentrar con SnPosCarga/SnImporte compartidos

- **Ubicación:** `UIGASPAM.pas` líneas 974, 980, 1007, 1429, 1518, 1396-1464, 1708-1715
- **Se atiende en:** [E2.5](../PLAN_OPTIMIZACION.md#e25--reentrancia-comandos-del-bridge-durante-una-transacción-serial)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  EsperaMiliSeg (ULIBGRAL, no esta en el repo, asi que no pude verificar su implementacion) se llama dentro del proceso de 'B' (setup 2x500 ms, 100 ms por posicion cerrada) y en cada reintento de OCC/OCL (500 ms).
  - Si duerme: congela el hilo principal, donde corren el socket, los timers y casi seguro los eventos serial.
  - Si bombea mensajes: puede reentrar pSerialTriggerAvail, despues ProcesaLinea con NumPaso 4, y procesar otro OCC. Eso sobrescribe los campos SnPosCarga, SnImporte y SnLitros, que funcionan como parametros implicitos de EnviaPreset (xpos:=SnPosCarga, 1715/1769). Al volver, el OCC externo usaria la posicion del otro comando (1452-1464). Tambien pueden reentrar Timer1Timer (el timer no se desactiva durante su handler) y ClientSocket1Read.
  Team ya elimino esta espera ('Ya no bloqueamos el hilo con EsperaMiliSeg', UIGASTEAM.pas 2193).
- **Evidencia:** 1425-1430: 'if TPosCarga[SnPosCarga].ContOCC=0 then TPosCarga[SnPosCarga].ContOCC:=3 else begin dec(TPosCarga[SnPosCarga].ContOCC); esperamiliseg(500); end;' entre la asignacion de SnPosCarga (1396) y su uso (1452, 1715).
- **Impacto:** En el mejor caso hay latencia y bloqueo del servicio de 0.5 a 1 s por reintento o setup. En el peor (si bombea y hay dos presets en reintento a la vez) el preset se envia a otra posicion u otro importe.
- **Recomendación:** Eliminar EsperaMiliSeg de ProcesaLinea. Para reintentos usar marcas de tiempo (HoraProxReintento por posicion) evaluadas en NumPaso 4. Pasar posicion, importe y litros como parametros a EnviaPreset/EnviaPreset3 en lugar de los campos Sn*. Revisar en ULIBGRAL si EsperaMiliSeg llama ProcessMessages y documentarlo.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="PAM-16"></a>
#### PAM-16 · 🟡 Media · correccion · riesgo — La heuristica x10 corrige el importe hacia volumen*precio y digiVol/digiPrec no tienen else: importes alterados en silencio

- **Ubicación:** `UIGASPAM.pas` líneas 1141-1144, 1119-1124, 1128-1133, 1146-1150, 1172
- **Se atiende en:** [E1.2](../PLAN_OPTIMIZACION.md#e12--importes-y-volúmenes-de-venta-mal-calculados)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Tras leer la venta se aplica 'si 2*vol*precio<importe entonces importe/10' y 'si 2*importe<vol*precio entonces importe*10'. El importe que cobra la PAM se ajusta al volumen y precio leidos. Si DECIMALESLITROS o DECIMALESPRECIO estan mal configurados (la convencion es confusa: digi=1 significa /100), o si el precio sale 0, el importe se divide o multiplica por 10 sin registrar nada. Ademas, si digiVol o digiPrec quedan fuera de 1..3, volumen y precio no se asignan y conservan el valor de la venta anterior, que despues alimenta la heuristica. El umbral de swAvanzoVenta usa IfThen(xcomb=3,80,40): supone que el producto 3 es diesel, y xcomb puede quedar sin inicializar.
- **Evidencia:** 1141-1144: 'if (2*volumen*precio<importe) then importe:=importe/10; if (2*importe<volumen*precio) then importe:=importe*10;'. 1119-1124: 'if digiVol=1 then ... else if digiVol=2 then ... else if digiVol=3 then ...' sin else.
- **Impacto:** Ventas registradas con importe 10 veces menor o mayor y volumen viejo, sin alarma: perdida economica o reclamos.
- **Recomendación:**
  1) Validar DECIMALES* en INITIALIZE (StrToIntDef en 1..3; si no, rechazar con 'False|DecimalesX invalido|').
  2) Sustituir la heuristica por una verificacion que, ante una discrepancia mayor a 2x, registre 'ALERTA importe/volumen/precio inconsistentes' y conserve el valor de la PAM (o lo rechace), sin reescalar.
  3) Parametrizar el umbral de 80/40.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="PAM-17"></a>
#### PAM-17 · 🟡 Media · robustez · bug — Reconexion con espera activa inutil (Sleep 1 s en el hilo principal) y sin OnError

- **Ubicación:** `UIGASPAM.pas` líneas 319-353, 355-367, 29-38 (.dfm)
- **Se atiende en:** [E2.2](../PLAN_OPTIMIZACION.md#e22--reconexión-no-bloqueante-y-con-manejo-de-errores)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  Timer2Timer activa el socket y espera hasta 101x Sleep(10). Como el socket se abre por primera vez en Timer2Timer (hilo principal), su HWND y su OnConnect viven en ese mismo hilo: conectado no puede cambiar durante el Sleep, asi que el bucle siempre se agota (1-1.6 s), bloquea el hilo y sale con Exit. La conexion se ve hasta el siguiente tick.
  Sin OnError, cada connect fallido (Bridge caido) lanza ESocketError dentro del WndProc del socket; SvcMgr probablemente lo manda al Visor de eventos cada 1.2-1.8 s. Ademas ScktComp crea un socket nuevo en cada Open sin cerrar el del connect fallido; esto es una posible fuga de handles, con certeza media.
- **Evidencia:** 327-333: 'ClientSocket1.Active:=True; for i:=0 to 100 do begin Sleep(10); if conectado then Break; end; if not conectado then Exit;'. Ningun driver define OnError (grep sin resultados en .pas/.dfm).
- **Impacto:** Mientras el Bridge esta caido el hilo principal pasa mas del 80% del tiempo dormido (si Timer1 fue reactivado por eventos serial, el sondeo se degrada), se inunda el Visor de eventos y posiblemente se fugan handles.
- **Recomendación:** Eliminar el bucle Sleep: en Timer2Timer solo llamar Active:=True si no hay un intento en curso y salir; enviar desde OnConnect o en el siguiente tick. Agregar ClientSocket1Error con ErrorCode:=0, conectado:=False, Active:=False, log con rate limit y backoff (1, 2, 5 s). Verificar con Process Explorer el conteo de handles con el Bridge detenido 1 hora.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="PAM-18"></a>
#### PAM-18 · 🟡 Media · correccion · bug — FULLSERVICE (DesactivaModoPrepago) deja 'Prepago': no hace nada y responde True

- **Ubicación:** `UIGASPAM.pas` líneas 2170-2193, 1010-1013, 1022-1025
- **Se atiende en:** [E5.4](../PLAN_OPTIMIZACION.md#e54--comandos-homogéneos-entre-marcas)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Es copia de ActivaModoPrepago: asigna ModoOpera:='Prepago' en ambos casos. Como ModoOpera nunca vale 'Normal', las ramas de modo normal son inalcanzables: liberar SwInicio con la pistola levantada (1011) y el 'G' de reanudar automatico en estado 8 (1022-1024). Wayne2W ya lo corrigio (UIGASWAYNE2W.pas 3432 'Normal').
- **Evidencia:** 2183: 'TPosCarga[xpos].ModoOpera:=''Prepago'';' dentro de DesactivaModoPrepago; 2186 igual.
- **Impacto:** OpenGas cree que la posicion paso a servicio completo y la PAM sigue en prepago: despachos que no inician sin preset o comportamiento distinto al configurado.
- **Recomendación:** Asignar 'Normal' en DesactivaModoPrepago. Validar en banco el efecto de las ramas 1010-1013 y 1022-1025 antes de activarlas (el 'G' automatico en estado 8 puede reanudar paros manuales). Responder error si xpos > MaxPosCarga.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="PAM-19"></a>
#### PAM-19 · 🟡 Media · correccion · bug — AgregaPosCarga no reinicia 'existe' por manguera: tras un producto repetido se descartan los productos siguientes

- **Ubicación:** `UIGASPAM.pas` líneas 1964, 1979-2011
- **Se atiende en:** [E1.8](../PLAN_OPTIMIZACION.md#e18--índices-fuera-de-rango-y-carga-de-posiciones-r-)
- **Verificación:** sin verificación independiente
- **Qué pasa:** existe:=false se asigna una vez por posicion, antes del bucle de mangueras. Despues de la primera manguera con un producto ya registrado, existe queda en True y ninguna manguera posterior se agrega (ni TComb, ni mapeo X, ni totales, ni Hoses en el JSON). Ejemplo: mangueras [1:P1, 2:P1, 3:P2], P2 nunca se registra. Team y Wayne2W ya lo corrigieron.
- **Evidencia:** 1964: 'existe:=false;' fuera del 'for j:=0 to mangueras.Count-1' (1979); 1986-1988: 'for k:=1 to NoComb do if TComb[k]=xcomb then existe:=true;'. Compara UIGASTEAM.pas 859 y UIGASWAYNE2W.pas 685, que lo reinician por manguera.
- **Impacto:** Productos sin mapeo, sin totales y con presets rechazados ('Combustible no existe en esta posicion') en dispensarios con mangueras duplicadas.
- **Recomendación:** Mover existe:=false dentro del bucle de mangueras (antes de 1986). Prueba con un INITIALIZE que tenga un producto repetido antes de otro distinto.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="PAM-20"></a>
#### PAM-20 · 🟡 Media · protocolo · bug — Estatus se publica con el codigo crudo de la PAM (6 cerrada, sin 7 bloqueada); el mapeo historico se calcula y se tira

- **Ubicación:** `UIGASPAM.pas` líneas 877, 959-965, 1032-1064
- **Se atiende en:** [E5.1](../PLAN_OPTIMIZACION.md#e51--semántica-única-de-estatus-y-campos-de-venta)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El JSON recibe estatus tal como lo da la PAM (0,1,2,3,5,6,8,9). El propio driver calcula xestado con el mapeo del protocolo historico hacia OpenGas: 6->0 en 959-962, y bloqueada (SwDesHabilitado) -> '7' en 1051. Ese valor solo se guarda en LinEstadoGen, que es codigo muerto. El Bridge arma STATUS concatenando Estatus por posicion (UIGASBRIDGE.pas 669-676), asi que OpenGas recibe '6' y nunca '7'.
- **Evidencia:** 877: 'ActualizaCampoJSON(xpos, ''Estatus'', estatus);'. 1039-1051: 'if not SwDesHabilitado then case estatus of ... else xestado:=xestado+''0''; end else xestado:=xestado+''7'';' y despues 'LinEstadoGen:=xestado;'. Bennett publica el estado mapeado: UIGASBENNETT.pas 1351-1369.
- **Impacto:** OpenGas puede mostrar o tratar mal las posiciones cerradas (6) y no ve las bloqueadas por BLOCK.
- **Recomendación:** Publicar Estatus con el mapeo: 6->0, SwDesHabilitado->7, y cualquier codigo desconocido ->0, igual que xestado. Eliminar el armado de lin/xmodo (ver el hallazgo de rendimiento). Confirmar con OpenGas el catalogo de codigos.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="PAM-21"></a>
#### PAM-21 · 🟡 Media · protocolo · bug — BLOCK/UNBLOCK no responden si la posicion esta entre MaxPosCarga+1 y 32: el Bridge espera 2 s y bloquea su cola

- **Ubicación:** `UIGASPAM.pas` líneas 2583-2641
- **Se atiende en:** [E5.4](../PLAN_OPTIMIZACION.md#e54--comandos-homogéneos-entre-marcas)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Si xpos<=MaximoDePosiciones (32) pero no esta en [1..maxposcarga], ninguna rama llama AddPeticionJSON. El Bridge manda solo una peticion a la vez (TryStartNext, UIGASBRIDGE.pas 120-139), asi que la cola de OpenGas se detiene 2 s (TimeoutRespSrv) y responde timeout. Ademas BLOCK solo impide presets nuevos (EnviaPreset 1716): no detiene una autorizacion vigente y no se refleja en el JSON.
- **Evidencia:** 2595-2605: 'if (xpos<=MaximoDePosiciones) then begin if xpos=0 then ... else if (xpos in [1..maxposcarga]) then begin ... AddPeticionJSON(folio, ''True|''); end; end else AddPeticionJSON(folio, ''False|Posicion no Existe|'');'.
- **Impacto:** Timeouts y retraso de todas las peticiones encoladas en el Bridge; el operador no sabe que la posicion no existe.
- **Recomendación:** Agregar 'else AddPeticionJSON(folio,''False|Posicion no Existe|'')' en la rama interna, en Bloquear y en Desbloquear. Opcionalmente, en BLOCK con estatus 9 mandar 'E'+pos y publicar Estatus=7.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="PAM-22"></a>
#### PAM-22 · 🟡 Media · robustez · bug — Una excepcion en NumPaso 4 aborta todos los comandos, deja el comando sin respuesta reejecutandose y fuerza NumPaso:=0

- **Ubicación:** `UIGASPAM.pas` líneas 1378-1702
- **Se atiende en:** [E1.5](../PLAN_OPTIMIZACION.md#e15--tabla-de-comandos-tabcmnd-y-respuestas-de-comandos-asíncronos)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  El bucle 'for xcmnd:=1 to 200' esta dentro de un solo try. Una excepcion en un comando tiene tres efectos:
  - Corta el proceso de los comandos siguientes en ese ciclo.
  - Deja el comando con SwResp=False, asi que se reejecuta en cada ciclo (CPREC reenviaria sus X para siempre; un OCC repite su EsperaMiliSeg(500)), porque TabCmnd solo se recicla cuando EjecutaComando barre ese slot.
  - 'ERROR PASO 5' pone NumPaso:=0 aunque haya un comando en vuelo y comandos en ListaCmnd, que es una de las entradas al interbloqueo del hallazgo 1.
  Fuentes reales de excepcion: el AV de ComandoConsola('') (hallazgo siguiente), StrToInt(ExtraeElemStrSep(LigaCombs,1,':')) en 1679 y StrToInt en 1190.
- **Evidencia:** 1699-1702: 'except AgregaLog(''ERROR PASO 5''); NumPaso:=0; end;' sin e.Message ni marca del comando.
- **Impacto:** Presets, paros y precios atrasados o sin respuesta, comandos repetidos a la PAM, y posible bloqueo total del sondeo.
- **Recomendación:** Poner un try/except por comando que marque TabCmnd[xcmnd].SwResp:=true con Respuesta='Error interno: '+e.Message y registrar el mensaje. Poner NumPaso:=0 solo si not SwEsperaRsp y ListaCmnd.Count=0. Usar StrToIntDef en LigaCombs.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="PAM-23"></a>
#### PAM-23 · 🟡 Media · correccion · bug — EnviaPreset (VersionPam1000 distinta de 3), preset en litros con combustible '00' o manguera fuera de 1..4: ss='' y AV en ComandoConsola

- **Ubicación:** `UIGASPAM.pas` líneas 1746-1753, 718-719, 744, 2096-2099
- **Se atiende en:** [E1.3](../PLAN_OPTIMIZACION.md#e13--presets-montos-decimales-y-validaciones)
- **Verificación:** sin verificación independiente
- **Qué pasa:** En el preset por litros, ss solo se asigna si CombustibleEnPosicion(xpos,xp)=xcomb para xp 1..4. AutorizarVenta pone comb='00' cuando viene vacio, y en posiciones de 2 productos que suman 5 se fuerza xcomb:=0 (1455-1457). PosicionDeCombustible(xpos,0) devuelve 99 y deja pasar la validacion. Con ss vacio, ComandoConsolaBuff('') llega a ComandoConsola, que lee LinCmnd[1] sobre una cadena vacia (puntero nil) y provoca un AV. El preset no se envia y entra al ciclo de reintentos de la excepcion de NumPaso 4. Solo afecta a la version distinta de 3; EnviaPreset3 maneja xcomb=0 con xprodauto.
- **Evidencia:** 1747-1749: 'for xp:=1 to 4 do if CombustibleEnPosicion(xpos,xp)=xcomb then ss:=''P''+...'; 1753: 'ComandoConsolaBuff(ss);'; 719: 'CharCmnd:=LinCmnd[1];'.
- **Impacto:** Los presets en litros sin producto explicito nunca se aplican en la PAM antigua; aparecen errores repetidos y 500 ms de espera por reintento.
- **Recomendación:** Si xcomb=0, usar la primera manguera o el codigo de 'todos los productos' de la PAM antigua; si ss='' devolver rsp:='Combustible no existe en esta posicion'. En ComandoConsola: 'if ss='''' then exit;'. Probar AUTHORIZE pos||0|20|0 con VERSIONPAM1000=2.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="PAM-24"></a>
#### PAM-24 · 🟡 Media · correccion · bug — Logica de reintento de preset (SwOCC/ContOCC) fragil: cuando levantan la pistola el contador se reinicia y el preset falla sin reintento

- **Ubicación:** `UIGASPAM.pas` líneas 1400-1431, 1489-1520, 917-923, 938-945
- **Se atiende en:** [E1.3](../PLAN_OPTIMIZACION.md#e13--presets-montos-decimales-y-validaciones)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Primer envio: ContOCC:=3 y SwCmndB:=false. En el siguiente B, si la posicion sigue en [1,5] y ContOCC>0, se reenvia (dec y EsperaMiliSeg(500)); si ContOCC<=0, se responde 'Error al aplicar PRESET'. El proceso de 'B' pone ContOcc:=0 en cada transicion a 1 o a 5 (921-922, 942-944). Si el cliente levanta la pistola entre el envio y el siguiente B (transicion 1->5), el contador queda en 0 y el driver reporta error sin reintentar, aunque la PAM pueda aplicar el preset un momento despues. Los bloques OCC (1395-1483) y OCL (1484-1566) son copias de unas 85 lineas.
- **Evidencia:** 938-944: '5:begin ... if (estatusant<>estatus) then begin swautorizada:=false; ... ContOcc:=0; end;'; 1413-1418: 'else if (estatus in [1,5])and(ContOCC<=0) then begin rsp:=''Error al aplicar PRESET''; ...'.
- **Impacto:** Falsos errores de preset en el flujo normal (pagar y luego levantar la pistola); OpenGas puede cancelar una venta que la PAM si autorizo.
- **Recomendación:** Llevar el contador de intentos en el TabCmnd (o en un campo IntentosPreset) y reiniciarlo solo al recibir un comando nuevo. No tocar ContOcc en las transiciones de estatus. Considerar exito si el estatus pasa a 9 o 2. Unificar OCC y OCL en una funcion AplicaPreset(xcmnd, esLitros).
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="PAM-25"></a>
#### PAM-25 · 🟡 Media · protocolo · riesgo — Socket sin delimitacion de mensajes: ReceiveText se toma como un solo comando y los SendText parciales se ignoran

- **Ubicación:** `UIGASPAM.pas` líneas 378-418, 485-502
- **Módulos afectados:** UIGASPAM.pas, UIGASBRIDGE.pas
- **Se atiende en:** [E6.1](../PLAN_OPTIMIZACION.md#e61--framing-y-buffer-por-conexión-en-los-dos-sentidos-y-del-lado-de-opengas)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  Del lado de lectura, ClientSocket1Read procesa Socket.ReceiveText como un mensaje completo, y el Bridge manda 'folio|DISPENSERS|CMD|params' sin terminador (UIGASBRIDGE.pas 762, 767). Si dos respuestas se concatenan ('...|3' seguido de '0|DISPENSERS|NOTHING') o un INITIALIZE grande llega partido, el comando se parsea con parametros basura o se pierde. Por ejemplo DetenerVenta hace StrToIntDef('3' + '0|DISPENSERS|NOTHING') y rechaza el STOP. El riesgo crece si ServidorSocket apunta a otra maquina.
  Del lado de escritura, Responder ignora el valor que devuelve SendText: en no bloqueante, WSAEWOULDBLOCK o un envio parcial truncan el JSON en silencio, y aun asi se registra 'E '+resp.
- **Evidencia:** 378: 'mensaje:=Socket.ReceiveText;'; 382-384: folio y comando por ExtraeElemStrSep. 489/493: 'socketResponse.SendText(resp);' sin revisar el resultado.
- **Impacto:** Comandos perdidos o mal interpretados (timeout en el Bridge), INITIALIZE fallido de forma intermitente y JSON truncados que el Bridge no puede parsear.
- **Recomendación:** Acordar con el Bridge un delimitador (p.ej. #10 o ETX) o un prefijo de longitud en ambos sentidos. Acumular en un buffer por socket y procesar solo mensajes completos. Revisar el retorno de SendText: guardar el pendiente y reenviarlo en OnWrite. Desplegar driver y Bridge de forma coordinada.
- **Esfuerzo:** M · **Riesgo del cambio:** alto · **Toca contrato:** sí

<a id="PAM-26"></a>
#### PAM-26 · 🟡 Media · rendimiento · riesgo — LOG/LOGREQ sin limite: hasta 10000 lineas metidas en rootJSON, reenviadas cada 250 ms y crecimiento recursivo del log

- **Ubicación:** `UIGASPAM.pas` líneas 2515-2565, 495, 2461-2486
- **Se atiende en:** [E4.4](../PLAN_OPTIMIZACION.md#e44--log-y-logreq-acotados)
- **Verificación:** sin verificación independiente
- **Qué pasa:** ObtenerLog y ObtenerLogPetRes concatenan, sin limite, las ultimas r+1 lineas (off-by-one) en un solo string con 'res:=res+...' (costo cuadratico) y lo meten en Peticiones. Ese Resultado viaja en cada JSON hasta que otras dos peticiones lo desplazan, y cada envio se registra completo en ListaLogPetRes ('E '+json). El siguiente LOGREQ devuelve lineas que contienen LOGREQ anteriores, asi que el tamano crece de forma geometrica con usos repetidos. Ademas GuardarLog devuelve un nombre de archivo calculado con un segundo Now (2465 frente a 2468), que puede no coincidir con el archivo real.
- **Evidencia:** 2530-2536: 'i:=ListaLog.Count-(r+1); if i<1 then i:=0; res:=''True|''; for i:=i to ListaLog.Count-1 do res:=res+ListaLog[i]+''|'';'. 495: 'AgregaLogPetRes(''E ''+resp);'.
- **Impacto:** Picos de CPU y memoria de decenas de MB en el hilo principal (que tambien atiende el serial), JSON enormes hacia el Bridge y posibles timeouts y bloqueos durante un diagnostico.
- **Recomendación:** Limitar r (p.ej. a 200) y el tamano total (p.ej. 64 KB); armar con TStringList.Text o con SetLength previo; corregir a r lineas. No registrar en ListaLogPetRes los JSON que contienen resultados de LOG. Calcular el nombre de archivo una sola vez.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="PAM-27"></a>
#### PAM-27 · 🟡 Media · protocolo · bug — La respuesta de LOGREQ contiene 'PING' y el Bridge descarta el JSON completo: LOGREQ nunca se contesta y el snapshot envejece

- **Ubicación:** `UIGASPAM.pas` líneas 2541-2565, 495
- **Módulos afectados:** UIGASPAM.pas, UIGASBRIDGE.pas
- **Se atiende en:** [E4.4](../PLAN_OPTIMIZACION.md#e44--log-y-logreq-acotados)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El Bridge trata como PING cualquier mensaje que contenga el texto 'PING' (AnsiContainsText) y no lo parsea. ListaLogPetRes tiene lineas 'E PING' de los envios de Timer2 (al arrancar, tras HALT o tras el comando '0'). Un LOGREQ devuelve esas lineas dentro de Peticiones, y mientras ese resultado viaje en los JSON el Bridge no actualiza el snapshot ni empareja folios. LOGREQ termina en timeout y STATE/STATUS/TRANSACTION pueden responder 'Datos obsoletos'.
- **Evidencia:** UIGASBRIDGE.pas 757: 'if not AnsiContainsText(respTxt,''PING'') then ProcesaRespuestasJSON(respTxt);'. 2561-2562: 'res:=res+ListaLogPetRes[i]+''|'';' incluye lineas con 'E PING'.
- **Impacto:** El diagnostico remoto (LOGREQ) falla justo cuando se necesita y el snapshot se degrada temporalmente.
- **Recomendación:** En el Bridge, comparar respTxt='PING' exacto (Trim). En el driver, mientras eso se despliega, escapar o sustituir 'PING' en el Resultado de LOG/LOGREQ (p.ej. 'P1NG'). Coordinar el despliegue.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** sí

<a id="PAM-28"></a>
#### PAM-28 · 🟡 Media · rendimiento · optimizacion — Costo de bitacoras: concatenacion caracter a caracter de cada JSON cada 250 ms, Delete(0) O(n) y SaveToFile de decenas de MB

- **Ubicación:** `UIGASPAM.pas` líneas 599-637, 495, 2258, 2461-2486, 310-312
- **Se atiende en:** [E2.4](../PLAN_OPTIMIZACION.md#e24--bitácoras-que-no-bloquean-append-incremental-rotación-y-sin-json-repetido)
- **Verificación:** sin verificación independiente
- **Qué pasa:** AgregaLog y AgregaLogPetRes construyen la linea caracter por caracter (lin2:=lin2+c), con costo potencialmente cuadratico. Se ejecutan con cada JSON enviado (4-17 KB segun el numero de posiciones, hasta 4 por segundo) y cada respuesta del Bridge. ListaLogPetRes guarda hasta 10000 entradas, del orden de 40-170 MB de RAM, y cubre apenas unos 20 minutos de historia. Delete(0) mueve el arreglo de 10000 punteros en cada linea. GuardarLog escribe ambas listas completas; se llama en cada excepcion (Timer2Timer, ClientSocket1Read, AddPeticionJSON, Inicializar...), en TRACE (el Bridge manda TRACE automatico cada 3 s cuando ve datos obsoletos) y cada MinutosLog, con un archivo nuevo por segundo y sin retencion. ServiceExecute guarda ListaLog con el nombre LogDispPetRes (311).
- **Evidencia:** 604-613: 'for i:=1 to length(lin) do case lin[i] of #1:lin2:=lin2+''<SOH>''; ... else lin2:=lin2+lin[i];'; 634-636: 'while ListaLogPetRes.Count>10000 do ListaLogPetRes.Delete(0);'.
- **Impacto:** CPU y memoria altas en el hilo principal (latencia serial), escrituras de disco grandes y frecuentes que pueden llenar el disco y retrasar el ciclo.
- **Recomendación:**
  1) Camino rapido: si la linea no tiene caracteres menores a #32, lin2:=prefijo+lin; si los tiene, usar StringReplace por cada control.
  2) No registrar el JSON completo en cada envio: solo si cambio, o un resumen (tamano y hash), o uno de cada N.
  3) Ring buffer con indice circular en lugar de Delete(0).
  4) Rotar por tamano con limite de archivos y throttle de GuardarLog en excepciones repetidas.
- **Esfuerzo:** M · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="PAM-29"></a>
#### PAM-29 · 🟡 Media · rendimiento · optimizacion — Regeneracion completa del JSON en cada tick, actualizaciones lineales con Variant y armado de cadenas muertas por cada B

- **Ubicación:** `UIGASPAM.pas` líneas 2256-2266, 1031-1064, 504-548, 1194-1199, 2926-2961
- **Se atiende en:** [E4.2](../PLAN_OPTIMIZACION.md#e42--json-más-barato-generar-menos-redondear-y-buscar-menos)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  Costos innecesarios en cada ciclo:
  - TlkJSON.GenerateText serializa todo rootJSON (PosCarga con Hoses[].Total, que el Bridge no usa, y las 2 Peticiones repetidas) en cada tick, haya cambios o no.
  - Cada respuesta B hace 3*MaxPosCarga llamadas a ActualizaCampoJSON (1034-1036), y cada una recorre la lista PosCarga comparando Variants (O(N^2) por ciclo).
  - Cada A final hace 6 llamadas mas.
  - 1052-1063 arma lin/xmodo con FormatFloat por posicion usando un xcomb sin inicializar, y el resultado se descarta.
- **Evidencia:** 1052: 'ss:=inttoclavenum(xpos,2)+''/''+inttostr(xcomb);' (xcomb nunca se asigna en el case 'B'); 'lin' se descarta despues de 1063. 526-527: 'if (posObj.Field[''DispenserId''] <> nil) and (posObj.Field[''DispenserId''].Value = xpos)'.
- **Impacto:** CPU y latencia evitables en el hilo que atiende el serial, y mas trafico al Bridge (y mas log).
- **Recomendación:**
  1) Guardar un arreglo PosObj[1..32] con la referencia TlkJSONObject por DispenserId al inicializar y actualizar directo.
  2) Marcar un flag de cambio (SwCambioJSON) en cada actualizacion y regenerar el texto solo si cambio, reusando la ultima cadena (como HongYang, commit fd48cc2).
  3) Eliminar el armado de lin/xmodo y el primer xestado (959-965).
- **Esfuerzo:** M · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="PAM-30"></a>
#### PAM-30 · 🟡 Media · configuracion · bug — modoAuto: jsonInitialize se guarda en el .ini con CR/LF y sin limite, y TIniFile.ReadString de Delphi 7 trunca a 2047 caracteres

- **Ubicación:** `UIGASPAM.pas` líneas 2658-2661, 284, 299-302, 2693-2694
- **Se atiende en:** [E2.7](../PLAN_OPTIMIZACION.md#e27--initialize-idempotente-y-seguro-con-ventas-en-curso)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Inicializar guarda el msj completo (json|variables). Las variables vienen separadas por CRLF (se separan con NoElemStrEnter). WritePrivateProfileString escribe esos saltos y rompe la seccion, asi que al leer solo se recupera la primera linea. Ademas TIniFile.ReadString en Delphi 7 usa un buffer de 2048 caracteres, y un JSON de configuracion de 8 o mas posiciones lo supera. Tras un reinicio, el autoarranque falla al parsear o pierde DecimalesX/VersionPam1000/ValidarManguera y arranca con los valores por omision. El TIniFile no se libera.
- **Evidencia:** 2659-2660: 'config:= TIniFile.Create(...); config.WriteString(''CONF'',''jsonInitialize'',msj);' (sin Free). 284: 'jsonInitialize:=config.ReadString(''CONF'',''jsonInitialize'','''');'. 2694: 'variable:=ExtraeElemStrEnter(variables,i);'.
- **Impacto:** Con modoAuto, despues de un reinicio el servicio queda sin inicializar, o con escalas de decimales equivocadas (importes y volumenes x10).
- **Recomendación:** Guardar el INITIALIZE en un archivo aparte (jsonInitialize.json, escrito con TStringList.SaveToFile) o codificarlo (Base64), y leerlo con TStringList.LoadFromFile. Liberar el TIniFile con try/finally. Registrar en el log si el autoarranque falla. Probar con un JSON de 16 posiciones y 3 variables.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="PAM-31"></a>
#### PAM-31 · 🟡 Media · correccion · bug — Se mezclan indices de slot y de posicion de manguera en SwTotales y TotalLitros: totales del producto equivocado

- **Ubicación:** `UIGASPAM.pas` líneas 1108-1111, 1183, 1649-1651, 1225-1249, 1338-1352
- **Se atiende en:** [E1.7](../PLAN_OPTIMIZACION.md#e17--totales-confiables)
- **Verificación:** sin verificación independiente
- **Qué pasa:** PosActual es la posicion de manguera de la PAM (PosActual:=TPosx[i], igual a HoseId y usada en xprodauto 1..6). Sin embargo SwTotales y TotalLitros se indexan por slot (1..NoComb) en '@'/'C' y en el barrido del paso 3. En el fin de venta (1183) y en TOTAL (1649-1651) se usa SwTotales[PosActual] y TotalLitros[PosActual]+=volumen. Si las HoseId no son 1..NoComb en orden (p.ej. mangueras 1 y 3, o posiciones 5/6 de la PAM), se marca o suma el slot equivocado, el total del producto real no se refresca, y con PosActual mayor a 4 se escribe sobre TMang dentro del registro.
- **Evidencia:** 1111: 'PosActual:=TPosx[i];'; 1183: 'SwTotales[PosActual]:=True;'; 1650: 'ToTalLitros[PosActual]:=ToTalLitros[PosActual]+volumen;' frente a 1226: 'SwTotales[i]:=false; TotalLitros[i]:=...' con i = slot.
- **Impacto:** Totalizadores incorrectos en TOTALS (cortes y conciliacion) y la manguera reportada en Manguera puede corromperse.
- **Recomendación:** Guardar SlotActual (i) junto con PosActual al identificar el grado (1109-1111) y usar SlotActual para SwTotales y TotalLitros. Probar con una posicion configurada con HoseId 1 y 3.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="PAM-32"></a>
#### PAM-32 · 🟡 Media · protocolo · bug — TOTAL solo reporta 3 productos, estima importes con el precio vigente, sintetiza litros y formatea segun el locale

- **Ubicación:** `UIGASPAM.pas` líneas 1628-1665, 2351
- **Módulos afectados:** UIGASPAM.pas, OpenGas
- **Se atiende en:** [E1.7](../PLAN_OPTIMIZACION.md#e17--totales-confiables)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  Problemas de la respuesta TOTAL:
  - Arma 'OK'+litros|pesos para los productos 1..3; un 4o producto (MCxP=4) nunca se reporta.
  - Los pesos son litros * LPrecios actual, no el totalizador monetario de la PAM; tras un cambio de precio todo el historico se revaloriza.
  - Si no llega la lectura en 3 s, 'estima' el total sumando el volumen de la ultima venta (1650), asi que los valores pueden no venir de la PAM.
  - FormatFloat y FormatoMoneda dependen de DecimalSeparator y ThousandSeparator del sistema.
  - LPrecios[TCombx[3]] con TCombx[3]=0 lee fuera de rango.
  - Con nocomb=0, swAllTotals queda sin inicializar (1641-1647).
  El formato es comun a los demas drivers.
- **Evidencia:** 1657-1659: 'rsp:=''OK''+FormatFloat(''0.000'',ToTalLitros[1])+''|''+FormatoMoneda(ToTalLitros[1]*LPrecios[TCombx[1]])+''|''+ ... ToTalLitros[3]...'.
- **Impacto:** Cortes y totales incompletos o incorrectos en estaciones de 4 productos o tras cambios de precio, y riesgo de parseo con otro locale.
- **Recomendación:** Parsear y devolver el totalizador monetario de la respuesta '@' (bloques de 29 caracteres) si la PAM lo trae. Indicar en el log cuando el total es estimado. Usar un TFormatSettings fijo ('.' y sin miles). Agregar el 4o producto acordandolo con OpenGas (toca contrato) e inicializar swAllTotals:=True.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** sí

<a id="PAM-33"></a>
#### PAM-33 · 🟡 Media · protocolo · bug — Con SetUpPAM1000 vacio se envia 'D06222' y enseguida un 'D0' sin parametros

- **Ubicación:** `UIGASPAM.pas` líneas 969-982
- **Se atiende en:** [E8.3](../PLAN_OPTIMIZACION.md#e83--código-muerto-variables-globales-y-duplicación-interna)
- **Verificación:** sin verificación independiente
- **Qué pasa:** En la primera respuesta B (SwComandoB=false) con VersionPam1000='3': si SetUpPAM1000='' manda 'D06222'; despues de EsperaMiliSeg(500), como ''<>'.', manda tambien 'D0'+''. Probablemente faltaba un else: valor vacio = default, '.' = nada, otro valor = 'D0'+valor. Ambos se mandan con ComandoConsola directo, sin esperar la respuesta del primero. SetUpPAM1000 no se reinicia en Inicializar (conserva el valor del INITIALIZE anterior) y SwComandoB no se reinicia en RUN, asi que el setup no se reenvia si la PAM se reinicio.
- **Evidencia:** 972-976: 'if SetUpPAM1000='''' then ComandoConsola(''D06222''); Esperamiliseg(500); if SetUpPAM1000<>''.'' then ComandoConsola(''D0''+SetUpPAM1000);'.
- **Impacto:** Comando de setup mal formado en cada arranque, con un efecto desconocido sobre la configuracion de la PAM 1000.
- **Recomendación:** 'if SetUpPAM1000='''' then Buff(''D06222'') else if SetUpPAM1000<>''.'' then Buff(''D0''+SetUpPAM1000)'. Reiniciar SetUpPAM1000:='' en Inicializar y SwComandoB:=false en Iniciar. Confirmar el significado de D0 en el manual de la PAM 1000.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="PAM-34"></a>
#### PAM-34 · 🟡 Media · rendimiento · optimizacion — Arranque lento: 2.75 s por posicion para el nivel de precio 'T' sin sondeo ni comandos

- **Ubicación:** `UIGASPAM.pas` líneas 909-915, 2240-2246, 987-993
- **Se atiende en:** [E4.3](../PLAN_OPTIMIZACION.md#e43--ciclo-serial-eficiente)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Por cada posicion en 1 sin swnivelprec, el proceso de B manda 'T' y sale con NumPaso=1 y ContEspera1=0. Timer1 espera 11 ticks (2.75 s) antes del siguiente B00. El mapeo X, en cambio, usa ContEspera1:=10 para seguir en el siguiente tick. En ese lapso no se hacen lecturas A ni se ejecutan comandos: con 16 posiciones son unos 44 s despues de cada INITIALIZE o RUN en que no se aplican presets. Despues de 'exit' esta la linea muerta 'SwAPlicaMapa:=false' (914). Si una posicion nunca hace ACK del T, se reintenta en cada ciclo.
- **Evidencia:** 912-914: 'ComandoConsola(''T''+...); exit; SwAPlicaMapa:=false;'; 2241-2245: 'inc(ContEspera1); if ContEspera1>10 then SwEsperaRsp:=False else exit;'.
- **Impacto:** Presets y lecturas retrasados hasta decenas de segundos tras cada inicializacion o reinicio.
- **Recomendación:** Encolar los 'T' de todas las posiciones pendientes en ListaCmnd y continuar con el ciclo normal; o poner ContEspera1:=10 como en el mapeo. Limitar los reintentos de T por posicion y registrarlos.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="PAM-35"></a>
#### PAM-35 · 🟡 Media · robustez · bug — Validacion insuficiente de posicion y combustible en comandos: se aceptan huecos sin registrar y comb=0 pasa como 'todos'

- **Ubicación:** `UIGASPAM.pas` líneas 1399, 1488, 1571, 1597, 1607, 1622, 1881-1894, 1641-1647
- **Se atiende en:** [E8.3](../PLAN_OPTIMIZACION.md#e83--código-muerto-variables-globales-y-duplicación-interna)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Los comandos validan 'xpos in [1..MaxPosCarga]' pero no que la posicion exista en el INITIALIZE (huecos con NoComb=0). Bennett ya lo corrige con SwRegistrada (commit d9151e4). PosicionDeCombustible devuelve 99 para xcomb=0; con NoComb=0, EnviaPreset3 manda '@02...' con xprodauto='000000' a una posicion inexistente. DVC y REANUDAR responden OK aunque la posicion sea invalida o no este en el estado esperado (1604-1627). AutorizarVenta no valida que posCarga sea numerico y combustible. Con nocomb=0 swAllTotals queda sin inicializar.
- **Evidencia:** 1892: 'else result:=99;' en PosicionDeCombustible; 1605-1607: 'rsp:=''OK''; xpos:=strtointdef(...); if xpos in [1..MaxPosCarga] then ...' sin else de error.
- **Impacto:** Comandos enviados a posiciones inexistentes, respuestas OK engañosas y totales con valores indeterminados.
- **Recomendación:** Agregar SwRegistrada en AgregaPosCarga y exigirla en todos los comandos y en TOTAL. Devolver error explicito en DVC y REANUDAR cuando xpos sea invalido o el estatus no aplique. Validar en AutorizarVenta con StrToIntDef.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="PAM-36"></a>
#### PAM-36 · 🟡 Media · robustez · bug — Comandos '0'/'1': abren o cierran el puerto sin actualizar estado/detenido/Estado, sin validar la inicializacion y sin limpiar el estado serial

- **Ubicación:** `UIGASPAM.pas` líneas 386-410
- **Se atiende en:** [E5.4](../PLAN_OPTIMIZACION.md#e54--comandos-homogéneos-entre-marcas)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El '0' cierra el puerto y apaga Timer1, pero estado sigue en 1 y detenido en False: STATE reporta 'corriendo' con el puerto cerrado. El '1' abre el puerto aunque estado=-1 (puerto con la configuracion por omision; la excepcion contesta False). No limpia ListaCmnd, Linea ni SwBcc (ver hallazgo 1). Ambos contestan '1' y hacen un Responder(JSON) inmediato que se suma al de Timer1.
- **Evidencia:** 400-408: 'if pSerial.Open then pSerial.Open:=False; Timer1.Enabled:=False; AddPeticionJSON(folio,''1''); Responder(...); respJson:=False; Timer2.Enabled:=True;' sin tocar estado.
- **Impacto:** Estado inconsistente hacia OpenGas y posible bloqueo del sondeo al reabrir.
- **Recomendación:** Reutilizar Detener e Iniciar (con la limpieza del hallazgo 1) para '0' y '1', validar estado>-1 antes de abrir y contestar '0' o un error cuando no aplique, acordandolo con OpenGas.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="PAM-37"></a>
#### PAM-37 · 🟡 Media · concurrencia · riesgo — ComandoConsola y pSerialTriggerAvail reactivan Timer1 aunque el servicio este detenido o desconectado

- **Ubicación:** `UIGASPAM.pas` líneas 735-737, 820-822, 2367-2369, 365
- **Se atiende en:** [E2.3](../PLAN_OPTIMIZACION.md#e23--arranque-y-paro-ordenados-del-servicio)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Los finally de ComandoConsola y pSerialTriggerAvail hacen Timer1.Enabled:=true sin condicion. Si hay una respuesta serial en vuelo cuando el Bridge se desconecta (365), o un evento de disparador pendiente al hacer HALT (2367-2368), Timer1 vuelve a funcionar fuera de su estado. Entonces sondea y manda el JSON a un socket desconectado (SendText devuelve 0 sin error y se registra 'E ...' 4 veces por segundo). En la PAM detenida llama OutBuffFree con el puerto cerrado (730), y la propiedad AutoOpen de Async Pro (que no se fija en el .dfm) podria incluso reabrir el puerto; esto ultimo con certeza media.
- **Evidencia:** 736: 'finally Timer1.Enabled:=true; end;'; 821 igual; 730: 'if pSerial.OutBuffFree >= Length(S1) then' antes de revisar pSerial.Open (732).
- **Impacto:** Sondeo o reapertura del puerto despues de HALT, inundacion del log y comportamiento distinto al ordenado por OpenGas.
- **Recomendación:** Usar un flag de estado (SwCorriendo:=estado>0 and pSerial.Open and not detenido) y reactivar Timer1 solo si es verdadero. Mejor aun, dejar de alternar Timer1 (ver el hallazgo de Timer1). Fijar AutoOpen:=False en el .dfm. Revisar pSerial.Open antes de OutBuffFree.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="PAM-38"></a>
#### PAM-38 · ⚪ Baja · robustez · bug — ServiceExecute: StrToInt antes de crear las listas, el handler usa ListaLog nil, y Timer2 corre antes de la inicializacion

- **Ubicación:** `UIGASPAM.pas` líneas 268-317, 23-28 (.dfm), 344-348
- **Se atiende en:** [E2.3](../PLAN_OPTIMIZACION.md#e23--arranque-y-paro-ordenados-del-servicio)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  ClientSocket1.Port:=StrToInt(...) (276) y minutosLog:=StrToInt(...) (282) se ejecutan antes de crear ListaLog (291). Con ServidorSocket sin ':' o MinutosLog no numerico, el except (310) hace ListaLog.Add con ListaLog=nil, el AV escapa y el servicio muere con un mensaje engañoso.
  Timer2 esta Enabled desde el .dfm (hilo principal) y puede disparar antes de que ServiceExecute cree rootJSON, ListaLog y el Host del socket; su except llama AgregaLog con ListaLog=nil.
  En modoAuto, Inicializar e Iniciar (299-302) corren en el hilo del servicio y abren el puerto ahi, al mismo tiempo que Timer2 en el principal: esa es la unica concurrencia real del modulo. El TIniFile no se libera.
- **Evidencia:** 273-293: orden de lecturas antes de 'ListaLog:=TStringList.Create;'; 310: 'ListaLog.Add(''Error al iniciar servicio: ''+e.Message);'.
- **Impacto:** El servicio no arranca por configuracion invalida sin un error claro, hay AV esporadicos al iniciar y una posible carrera en modoAuto.
- **Recomendación:** Crear las listas y rootJSON en el OnCreate del modulo o al inicio de ServiceExecute; usar StrToIntDef o ReadInteger; dejar Timer2.Enabled=False en el .dfm y activarlo al final de ServiceExecute; en modoAuto, ejecutar Inicializar e Iniciar desde el primer tick de Timer2 (hilo principal). Liberar config con try/finally.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="PAM-39"></a>
#### PAM-39 · ⚪ Baja · robustez · bug — SHUTDOWN llama ServiceThread.Terminate pero el hilo del servicio sigue bloqueado en GetMessage

- **Ubicación:** `UIGASPAM.pas` líneas 2446-2454, 304-305
- **Se atiende en:** [E2.3](../PLAN_OPTIMIZACION.md#e23--arranque-y-paro-ordenados-del-servicio)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Shutdown se ejecuta en el hilo principal (evento de socket). TThread.Terminate solo pone FTerminated. ServiceExecute esta dentro de ProcessRequests(True), que bloquea en GetMessage del hilo del servicio, y en PAM ninguna ventana vive en ese hilo, asi que no llegan mensajes hasta que el SCM mande un control. El servicio responde True pero no se detiene. Certeza media; depende de la implementacion de SvcMgr en D7.
- **Evidencia:** 2452: 'ServiceThread.Terminate;'; 304-305: 'while not Terminated do ServiceThread.ProcessRequests(True);'.
- **Impacto:** SHUTDOWN desde OpenGas no detiene el servicio de forma fiable.
- **Recomendación:** Despues de Terminate, hacer PostThreadMessage(ServiceThread.ThreadID, WM_NULL, 0, 0), o usar ProcessRequests(False) con Sleep corto; o mejor, pedir el paro via SCM (Controller/ServiceThread.Terminate y Status).
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="PAM-40"></a>
#### PAM-40 · ⚪ Baja · seguridad · riesgo — LOGIN sin secreto (MD5 de usuario|fecha-minuto), Token no se exige, Decrypt registra la llave y la validacion HASP esta comentada

- **Ubicación:** `UIGASPAM.pas` líneas 2830-2860, 2882-2916, 2394-2419, 277, 281
- **Se atiende en:** [E8.1](../PLAN_OPTIMIZACION.md#e81--autenticación-licencia-y-modo-emulación)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  Problemas de seguridad:
  - El 'password' valido es MD5(usuario+'|'+yyyy-mm-ddThh:nn): cualquiera lo puede calcular, y falla si los relojes difieren por un minuto.
  - El Token resultante no se valida en ningun comando.
  - Encrypt y Decrypt (3DES) son codigo muerto, y Decrypt escribe la llave y el dato en ambos logs si hay error.
  - La verificacion HASP de Iniciar esta comentada (commit d3bdad5); GSentinelKey y licencia se leen dos veces de la misma clave y no se usan, asi que el producto corre sin licencia.
- **Evidencia:** 2836: 'if MD5(usuario+''|''+FormatDateTime(''yyyy-mm-dd'',Date)+''T''+FormatDateTime(''hh:nn'',Now))<>password then'; 2894: 'AgregaLog(''Decrypt: ''+e.Message+'' Data: ''+data+''3DES: ''+key3DES);'.
- **Impacto:** Una autenticacion que da falsa sensacion de seguridad y una exposicion potencial de llaves si se reactiva el cifrado; licenciamiento no aplicado.
- **Recomendación:** Documentar que la autenticacion la resuelve el Bridge (o eliminar LOGIN del driver), quitar Encrypt/Decrypt y LbCipher si no se usan, nunca registrar llaves, y decidir explicitamente (con un flag de ini) si HASP se valida, en lugar de dejarlo comentado.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="PAM-41"></a>
#### PAM-41 · ⚪ Baja · mantenibilidad · deuda_tecnica — Codigo muerto o inalcanzable abundante (ReautorizaPam fijo, NumPaso 5, finventa/EFV, consultas locales, CRC16, unidades sin uso)

- **Ubicación:** `UIGASPAM.pas` líneas 297, 897-904, 1014-1021, 1610-1613, 1728-1731, 1754-1757, 1782-1785, 1818-1821, 1201-1207, 1594-1602, 2228-2235, 1282-1287, 2284-2333, 2456-2459, 2777-2789, 2862-2880, 879-890, 29-57
- **Se atiende en:** [E8.3](../PLAN_OPTIMIZACION.md#e83--código-muerto-variables-globales-y-duplicación-interna)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  Elementos que no hacen nada o nunca se ejecutan:
  - ReautorizaPam:='No' esta fijo (297), asi que todas las ramas de 'Reenvia' y CmndOcc son inalcanzables. Si se activaran, saldrian a mitad del barrido de B (exit en 902/1019) y reenviarian un CmndOcc vacio (AV en ComandoConsola).
  - NumPaso 5 nunca se asigna.
  - finventa (EFV/OCC param 5) solo alimenta un bloque comentado (1201-1207).
  - TransaccionPosCarga, EstadoPosiciones, ObtenerEstado, CRC16 y GuardaLogComandos no se llaman (GuardaLogComandos ademas crea un Exception sin lanzarlo, 2877).
  - SwActivo y ContDA (un contador global compartido por todas las posiciones) no se leen fuera de su bloque.
  - swautorizando nunca vale True.
  - Hay campos sin uso: UltimoStatus, SwEspera, swcierrabd, ModoAutorizaPam, ContadorTotPos, ContadorTot, confPos, ContEsperaRsp.
  - Unidades sin uso: DB, RxMemDS, ComObj (solo para HASP), LbCipher/LbString (solo Encrypt).
- **Evidencia:** 297: 'ReautorizaPam:=''No'';' y ninguna otra asignacion; 2201-2202: 'if NumPaso>4 then NumPaso:=0;' antes del bloque 'if NumPaso=5' (2228).
- **Impacto:** Dificulta el mantenimiento y las auditorias (p.ej. CENAM), arrastra dependencias externas (RxMemDS, LbCipher) y esconde defectos que reaparecerian al reactivarlo.
- **Recomendación:** Eliminar las ramas muertas, o mover las que tengan valor (reautorizacion) detras de una opcion de ini probada. Quitar las unidades sin uso del uses y compilar para confirmar. Hacerlo en un commit separado y sin cambios de comportamiento.
- **Esfuerzo:** M · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="PAM-42"></a>
#### PAM-42 · ⚪ Baja · mantenibilidad · deuda_tecnica — Variables duplicadas entre campo y global, estado de preset pasado como parametro implicito y socketResponse redundante

- **Ubicación:** `UIGASPAM.pas` líneas 74-77, 244-248, 40-41, 1396-1397, 1708-1715, 474, 488-491
- **Se atiende en:** [E8.3](../PLAN_OPTIMIZACION.md#e83--código-muerto-variables-globales-y-duplicación-interna)
- **Verificación:** sin verificación independiente
- **Qué pasa:** ListaCmnd, LinCmnd, CharCmnd y SwEsperaRsp estan declarados como campos publicos (74-77) y tambien como globales de unidad (244-247). Dentro de los metodos el campo oculta a la global, asi que las globales nunca se usan y confunden. SwComandoB, LinEstadoGen, Token, TPosCarga y TabCmnd son globales de unidad. SnPosCarga, SnImporte y SnLitros son campos que funcionan como parametros implicitos de EnviaPreset y EnviaPreset3. socketResponse siempre es ClientSocket1.Socket.
- **Evidencia:** 74: 'ListaCmnd :TStrings;' (campo) y 244: 'ListaCmnd :TStrings;' (global); 1715: 'xpos:=SnPosCarga;'.
- **Impacto:** Riesgo de errores al modificar el codigo y mas exposicion a reentrancia.
- **Recomendación:** Eliminar las globales duplicadas, pasar pos/importe/litros como parametros, mover TPosCarga y TabCmnd a campos de la clase y quitar socketResponse (usar ClientSocket1.Socket).
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="PAM-43"></a>
#### PAM-43 · ⚪ Baja · memoria_recursos · bug — Fugas de objetos (arbol JSON de INITIALIZE, TIniFile, posObj/hosesArr) y funciones sin Result:='' en exito

- **Ubicación:** `UIGASPAM.pas` líneas 2666, 273, 2659, 1967-2013, 2785-2788, 2849-2853, 2877, 644-712, 1896-2021
- **Se atiende en:** [E2.7](../PLAN_OPTIMIZACION.md#e27--initialize-idempotente-y-seguro-con-ventas-en-curso)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  Recursos que no se liberan:
  - js := TlkJSON.ParseText(json) en Inicializar nunca se libera: se pierde el arbol completo de configuracion en cada INITIALIZE, y ahora tambien en cada reinicializacion.
  - TIniFile en ServiceExecute y en Inicializar no se libera.
  - Si AgregaPosCarga lanza una excepcion a mitad (p.ej. StrToInt de MapCombs en 1982), posObj y hosesArr ya creados no se agregan ni se liberan.
  - MD5 y CRC16 hacen Destroy sin try/finally.
  - GuardaLogComandos hace Exception.Create sin raise (2877): fuga y error tragado.
  IniciaPSerial y AgregaPosCarga no asignan Result en exito; funcionan porque Delphi pasa la variable del llamador (resultado='') como Result oculto.
- **Evidencia:** 2666: 'js := TlkJSON.ParseText(json);' sin js.Free en ningun camino; 2877: 'Exception.Create(''GuardaLogComandos: ''+e.Message);'.
- **Impacto:** La memoria crece con cada INITIALIZE; hay riesgo latente si se reutiliza el resultado de las funciones.
- **Recomendación:** try/finally js.Free en Inicializar; try/finally para TIniFile, MD5 y CRC16; crear posObj y hosesArr y agregarlos al padre de inmediato (el padre los libera). Poner Result:='' al inicio de IniciaPSerial y AgregaPosCarga. Cambiar 2877 por raise o por un log.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="PAM-44"></a>
#### PAM-44 · ⚪ Baja · configuracion · deuda_tecnica — Tiempos, limites y semantica fijos en el codigo, y StrToInt sin default en variables de INITIALIZE y en el ini

- **Ubicación:** `UIGASPAM.pas` líneas 12, 218-223, 2196-2235, 1172, 1426, 1733, 1787, 973, 2687-2700, 1982, 1190, 1679
- **Se atiende en:** [E0.5](../PLAN_OPTIMIZACION.md#e05--configuración-documentada-y-validada-al-arrancar)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  Valores fijos en el codigo:
  - MCxP=4 y 32 posiciones.
  - Timeouts MaxEspera2=20, MaxEspera3=10, 3 y 11 ticks; intervalos de 200 y 250 ms en el .dfm.
  - 3 reintentos de preset; NivelPrec='1' (contado) para todos los presets.
  - Setup por omision 'D06222'.
  - Umbral 80/40 pesos con el producto 3 supuesto diesel.
  - La convencion DECIMALES*=1 significa 2 decimales (confusa).
  DECIMALESLITROS, DECIMALESPRECIO y DECIMALESPESOS, MapeoCombustibles y LigueCombustibles se convierten con StrToInt: un valor mal escrito aborta el INITIALIZE o el comando con un mensaje generico.
- **Evidencia:** 2696: 'digiVol:=StrToInt(ExtraeElemStrSep(variable,2,''=''))'; 1172: 'IfThen(xcomb=3,80,40)'; 1733: 'NivelPrec:=''1'';'.
- **Impacto:** Ajustar por sitio requiere recompilar y la configuracion es propensa a errores.
- **Recomendación:** Mover tiempos y reintentos a variables de INITIALIZE o del ini con valores por omision; documentar la convencion DECIMALES* (o cambiarla a 'numero de decimales' con compatibilidad); usar StrToIntDef con validacion de rango y mensajes especificos.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="PAM-45"></a>
#### PAM-45 · ⚪ Baja · correccion · bug — FINV tiene una rama imposible; DVC y REANUDAR responden OK sin validar

- **Ubicación:** `UIGASPAM.pas` líneas 1568-1592, 1604-1627
- **Se atiende en:** [E5.4](../PLAN_OPTIMIZACION.md#e54--comandos-homogéneos-entre-marcas)
- **Verificación:** sin verificación independiente
- **Qué pasa:** En FINV, dentro de 'if Estatus=3', el else pregunta 'swcargando and Estatus=1', que nunca es verdadero, asi que siempre responde 'Posicion no esta despachando' cuando SwCargando sigue en True (p.ej. si no hubo lectura A tras el despacho). Entonces nunca se manda 'R' y la posicion queda en EOT. DVC y PARAR responden OK aunque la posicion no este en [2,9] o no exista; REANUDAR igual.
- **Evidencia:** 1574-1584: 'if (not TPosCarga[xpos].swcargando) then ... else begin if (TPosCarga[xpos].swcargando)and(TPosCarga[xpos].Estatus=1) then ...'.
- **Impacto:** Cobros (PAYMENT) que no liberan la posicion en casos borde, y paros reportados como exitosos sin efecto.
- **Recomendación:** En FINV con Estatus=3, enviar 'R' sin depender de swcargando (o forzar primero una lectura A). En DVC y REANUDAR, devolver error si la posicion es invalida o el estatus no aplica.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="PAM-46"></a>
#### PAM-46 · ⚪ Baja · configuracion · riesgo — Parseo de cantidades dependiente del DecimalSeparator del sistema y truncamiento de importes con 5 decimales

- **Ubicación:** `UIGASPAM.pas` líneas 1433-1438, 1523, 2076-2082, 1669
- **Se atiende en:** [E8.2](../PLAN_OPTIMIZACION.md#e82--configuración-regional-locale-explícita)
- **Verificación:** sin verificación independiente
- **Qué pasa:** StrToFloat y StrToFloatDef sobre los importes y litros de OpenGas (con '.') dependen del DecimalSeparator de la cuenta del servicio; con ',' fallan ('Error en Importe') o AutorizarVenta responde 'Favor de indicar la cantidad'. Con 5 decimales, el importe se recorta a 2 quitando 3 caracteres (trunca: 150.99999 -> 150.99). Importes con 3 o 4 decimales se rechazan por ValidaCifra.
- **Evidencia:** 1435-1436: 'if (Length(decImporteStr)=5) then SnImporte:=StrToFloat(copy(SnImporteStr,1,length(SnImporteStr)-3))'.
- **Impacto:** Presets rechazados si el servidor tiene otra configuracion regional, y diferencias de centavos.
- **Recomendación:** Usar un TFormatSettings fijo con DecimalSeparator='.' (o reemplazar ',' por '.' y usar Val), y redondear a 2 decimales (Round(x*100)/100) en lugar de cortar caracteres.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="PAM-47"></a>
#### PAM-47 · ⚪ Baja · observabilidad · deuda_tecnica — Excepciones tragadas o registradas sin mensaje ni contexto

- **Ubicación:** `UIGASPAM.pas` líneas 1209-1210, 1215-1217, 1257-1259, 1274-1276, 1322-1325, 1371-1374, 1699-1701, 2253-2255, 1704-1705
- **Se atiende en:** [E2.4](../PLAN_OPTIMIZACION.md#e24--bitácoras-que-no-bloquean-append-incremental-rotación-y-sin-json-repetido)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El bloque de venta concluida termina en 'except end;' vacio (1209-1210): un StrToFloat fallido deja la venta a medio actualizar sin rastro. Los demas handlers registran textos fijos ('ERROR EN COMANDO A', 'ERROR PASO 2/3/5', 'ERROR TIMER1') sin e.Message, sin la trama y sin la posicion. El 'finally end;' de ProcesaLinea es vacio.
- **Evidencia:** 1209-1210: 'except end;'; 1216: 'AgregaLog(''ERROR EN COMANDO A'');'.
- **Impacto:** Diagnostico dificil de fallas en campo, justo en la ruta que calcula las ventas.
- **Recomendación:** En todos los except usar 'on e:Exception do AgregaLog(Format(''Error %s pos=%d trama=%s: %s'',[...]))'; no tragar excepciones en el parseo de la venta y marcar la lectura como invalida.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="PAM-48"></a>
#### PAM-48 · ⚪ Baja · correccion · bug — ApplyTotalLitrosToJSON localiza la posicion por indice (xpos-1) y no por DispenserId

- **Ubicación:** `UIGASPAM.pas` líneas 2926-2961
- **Se atiende en:** [E1.8](../PLAN_OPTIMIZACION.md#e18--índices-fuera-de-rango-y-carga-de-posiciones-r-)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Supone que PosCarga[] esta ordenado y es contiguo desde 1. Con huecos (p.ej. IDs 1,2,5,6) o con un orden distinto en el INITIALIZE, los totales se escriben en Hoses de otra posicion o se descartan. ActualizaCampoJSON si busca por DispenserId, y el Bridge advierte que PosCarga puede llegar en cualquier orden (UIGASBRIDGE.pas 639-640). Hoy el Bridge no consume Hoses[].Total, asi que el impacto es solo de diagnostico.
- **Evidencia:** 2941-2945: 'posIndex0 := xpos - 1; ... posObj := TlkJSONobject(posCargaList.Child[posIndex0]);'.
- **Impacto:** Totales por manguera publicados en la posicion equivocada si alguien empieza a consumirlos.
- **Recomendación:** Buscar por DispenserId (o usar el arreglo PosObj[1..32] propuesto) y emparejar Hoses por ProductId o HoseId en lugar de por indice.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="PAM-49"></a>
#### PAM-49 · ⚪ Baja · protocolo · optimizacion — Peticiones nunca se limpian y NOTHING agrega {Folio:0}: resultados repetidos en cada JSON y desplazamiento de resultados reales

- **Ubicación:** `UIGASPAM.pas` líneas 563-596, 423-424
- **Módulos afectados:** UIGASPAM.pas, UIGASBRIDGE.pas
- **Se atiende en:** [E6.2](../PLAN_OPTIMIZACION.md#e62--push-de-comandos-resultados-inmediatos-y-ack)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Cada JSON reenvia las 2 ultimas Peticiones, aunque el Bridge ya las haya emparejado, y el Bridge hace TryPopByFolio en cada envio. Cada respuesta NOTHING del Bridge (4 por segundo en reposo) agrega {Folio:0,'True|'}, que el Bridge descarta, y desplaza resultados reales. Con la cola estricta del Bridge el riesgo de perder un resultado es bajo; hay costo de ancho de banda y de log, y no hay un acuse de recibo explicito.
- **Evidencia:** 581-582: 'while petArr.Count >= 2 do petArr.Delete(0);'; 424: 'AddPeticionJSON(folio, ''True|'');' para NOTHING.
- **Impacto:** JSON mas grandes, mas log, y un riesgo residual de perder un resultado si el driver hace varios envios sin respuesta.
- **Recomendación:** No agregar una peticion para NOTHING (solo poner respJson:=True). A mas largo plazo, que el Bridge devuelva la lista de folios recibidos (ack) y el driver borre esas Peticiones.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** sí

<a id="PAM-50"></a>
#### PAM-50 · ⚪ Baja · pruebas · deuda_tecnica — Sin pruebas automatizadas ni modo emulacion para el parser y la maquina de estados de PAM

- **Ubicación:** `UIGASPAM.pas` líneas 784-1706
- **Se atiende en:** [E0.4](../PLAN_OPTIMIZACION.md#e04--simuladores-de-opengas-y-de-driver--batería-de-pruebas-de-protocolo), [E7.4](../PLAN_OPTIMIZACION.md#e74--separar-la-lógica-de-protocolo-serial-de-la-del-servicio-testeable)
- **Verificación:** sin verificación independiente
- **Qué pasa:** ProcesaLinea (unas 880 lineas) mezcla parseo de tramas, reglas de negocio de presets y totales, y efectos de E/S, y no tiene pruebas. A diferencia de otros drivers (el commit 8ba4373 agrego 'ventas aleatorias al modo emulacion'), PAM no tiene modo emulacion, asi que cada correccion se valida solo en sitio o en banco.
- **Evidencia:** No hay referencias a emulacion en UIGASPAM.pas (grep 'Emulacion' sin resultados) y ninguna unidad de pruebas en el repositorio.
- **Impacto:** Alto riesgo de regresion al corregir los hallazgos anteriores.
- **Recomendación:** Extraer funciones puras: ParseRespuestaA(lin, digi*) -> registro; ParseTotales(lin, nocomb); ArmaPreset(...); ArmaTrama/ValidaBCC. Cubrirlas con DUnit usando tramas capturadas de los logs reales (LogDisp*.txt). Agregar un emulador de PAM por puerto virtual (com0com) para probar los escenarios de timeout, NAK y HALT/RUN.
- **Esfuerzo:** L · **Riesgo del cambio:** bajo · **Toca contrato:** no

