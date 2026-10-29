# Hallazgos · BRG · Bridge (UIGASBRIDGE.pas)

> Anexo del [plan de optimización](../PLAN_OPTIMIZACION.md). Código auditado: `IgasDispensarios@26ccfb4`, `IgasDispensariosBridge@99edafd`. Las líneas pueden haber cambiado: ubica las rutinas por su nombre.

## Cómo funciona este módulo

PDISPBRIDGE (UIGASBRIDGE.pas, 904 lineas) es un TService de Delphi 7 que separa a OpenGas (OG) de PDISPENSARIOS (el driver). Tiene dos TServerSocket no bloqueantes. SSocketPDisp escucha en PuertoPDisp (default 1004; el .dfm dice 1002, pero ServiceExecute lo sobreescribe) y ahi se conecta el driver. SSocketOG escucha en PuertoOG (1001): solo se activa cuando llega el primer mensaje del driver y se cierra si OG pide algo mientras el driver lleva 10 s o mas sin hablar.

Con el driver el protocolo es pull. El driver manda 'PING' o el JSON completo (snapshot) cada ~200 ms. En el mismo OnClientRead, el Bridge parsea el JSON (reemplaza rootJSON), empareja Peticiones[].Folio con la cola (TryPopByFolio), contesta a OG y responde al driver una sola vez: con la cabeza de la cola 'folio|DISPENSERS|CMD|params' (si aun no se envio) o con '0|DISPENSERS|NOTHING'. Ningun sentido lleva delimitadores.

OG manda tramas SOH STX payload ETX CRC16 ETB. STATE, STATUS y TRANSACTION se contestan desde el snapshot, con chequeo de obsolescencia de 5 s. PRICES, AUTHORIZE y PAYMENT se confirman 'True|0|' de inmediato y se encolan sin socket. El resto se encola y espera su resultado por folio (1..999, se reinicia al arrancar) durante TimeoutRespSrv (2 s) contados desde el envio.

TimerTimeout (500 ms) vence la cabeza ya enviada. Si el snapshot esta obsoleto y el driver sigue vivo, encola un TRACE automatico (auto-kick). Los logs son dos TStringList en memoria de hasta 10000 lineas que se vuelcan completos a archivo por TRACE, por MinutosLog o por cualquier error.

Modelo de hilos (verificado, certeza alta): TimerTimeout se crea en ServiceExecute (linea 256) y los sockets se activan en ServiceExecute/SSocketPDispClientRead. ScktComp asigna el HWND de forma perezosa en el hilo que activa el socket, y los sockets aceptados se crean en ese mismo hilo. Por lo tanto, todos los eventos del Bridge corren serializados en el hilo del servicio (ProcessRequests, linea 265). El Bridge no tiene carreras de datos; la seccion critica de la cola es redundante. El costo es que cualquier E/S lenta (SaveToFile de decenas de MB) congela a OG, al driver y a los timeouts a la vez.

Los riesgos principales son de protocolo:

- no hay framing en el enlace con el driver ni buffer en el de OG;

- los comandos de venta se confirman a ciegas;

- PING se detecta por subcadena;

- la cola bloquea en la cabeza (1 peticion por viaje);

- confirmaciones con el driver caido y colas sin TTL;

- los folios se reinician;

- la E/S de logs esta dentro de los except.

### Ciclo serial

No aplica: el Bridge no tiene puerto serial. Su unico ciclo propio es TimerTimeout, un TTimer creado en ServiceExecute (lineas 256-259) que corre cada 500 ms en el hilo del servicio. En cada tick:

1) Con TryPopExpired saca de la cabeza de la cola las peticiones ya enviadas con SecondsBetween(Now,HoraEnvio) >= TimeoutRespSrv (default 2 s, minimo forzado 1 s; el timeout efectivo queda entre 2.0 y 2.5 s). A OG le responde 'DISPENSERS|CMD|False|Timeout excedido con Pdispensarios|' solo si la peticion tiene CliSock.

2) Si DatosObsoletos (sin JSON valido en >= TimeoutDatosObsoletos=5 s) y hubo un mensaje del driver hace menos de 10 s, encola un 'DISPENSERS|TRACE|' sin socket como maximo cada AutoKickIntervaloSeg=3 s.

El ritmo del intercambio lo marca el driver: Timer2 cada 200 ms, o en Wayne2W Timer1 de 50 ms con xTurnoSocket=3. El Bridge solo responde a cada lectura. No hay reintentos: una peticion enviada que no recibe respuesta se descarta al vencer, y las peticiones no enviadas no expiran nunca (solo se cancelan si OG manda algo mientras el driver lleva 10 s inactivo, o al detener el servicio).

### Contrato con el Bridge, visto desde este módulo

- **Conexión:** El Bridge actua como servidor. SSocketPDisp es un TServerSocket stNonBlocking en PuertoPDisp (ini [CONF], default 1004). El .dfm dice 1002 pero se sobreescribe en la linea 238. Escucha en todas las interfaces y acepta N conexiones sin autenticacion ni filtro de IP. Solo tiene OnClientRead (no hay OnClientConnect, OnClientDisconnect ni OnClientError) y se activa al arrancar (linea 262). SSocketOG (PuertoOG, default 1001) arranca inactivo (261) y se activa con el primer mensaje del driver (755-756). Se cierra, cortando a todos los clientes OG, cuando OG envia una peticion y el driver lleva 10 s o mas sin hablar (409-412). Los drivers usan TClientSocket hacia ServidorSocket (default 127.0.0.1:1004). Kairos (Marca 7) no usa el Bridge y escucha el mismo puerto 1001.
- **Ciclo de envío:** El driver inicia el intercambio (pull). Envia 'PING' si respJson=False, o TlkJSON.GenerateText(rootJSON) en otro caso: desde Timer2 cada 200 ms, y en Wayne2W en operacion desde Timer1 cuando xTurnoSocket=3. PAM, Wayne y Wayne2W envian ademas JSON extra dentro de ClientSocket1Read/Iniciar. En cada evento OnClientRead el Bridge: 1) actualiza horaAct; 2) registra el texto completo; 3) si no contiene 'PING', lo parsea (snapshot y resultados); 4) responde EXACTAMENTE una vez, con 'folio\|<Peticion>' (la cabeza de la cola si no habia salido; Peticion es 'DISPENSERS\|CMD\|params' tal como llego de OG, sin el '\|' final) o con '0\|DISPENSERS\|NOTHING'. Ningun sentido lleva terminador ni longitud, y el Bridge nunca envia por iniciativa propia. El driver procesa cada respuesta en ClientSocket1Read y deja el resultado en Peticiones (AddPeticionJSON), que viaja en su siguiente envio.
- **PING vs JSON:** La linea 757 usa AnsiContainsText(respTxt,'PING'): busca la subcadena en todo el mensaje sin distinguir mayusculas. Si aparece 'ping' en cualquier parte, el mensaje cuenta como heartbeat: solo actualiza horaAct y recibe respuesta, pero no reemplaza rootJSON, no actualiza horaUltimoDatoReal y no procesa Peticiones. Todo lo demas pasa por TlkJSON.ParseText. Si devuelve nil, se conserva el snapshot anterior. Si devuelve algo, se castea a TlkJSONobject sin verificar el tipo, reemplaza rootJSON y marca horaUltimoDatoReal. ParseText ignora el texto que sobre despues del primer valor, asi que con dos JSON pegados se queda con el mas viejo. Si no llega JSON valido en TimeoutDatosObsoletos (5 s), STATE/STATUS/TRANSACTION responden False con 'Datos obsoletos'.
- **Peticiones:** La cola es TPeticionQueue: FIFO global (TList + seccion critica). AddPeticion asigna un folio 1..999 con un contador en memoria compartido con el auto-kick, que vuelve a 0 al reiniciar. Cada peticion se encola como {Folio, Comando, Peticion, CliSock, Enviada=False}. Solo la cabeza puede enviarse (TryStartNext la marca Enviada y le pone HoraEnvio) y queda en vuelo hasta que ocurra una de tres cosas: a) su folio aparece en Peticiones[] de un JSON posterior (TryPopByFolio exige Enviada; Peticiones se recorre de i=0 a n-1) y se responde a OG 'DISPENSERS\|CMD\|'+Resultado, o el Resultado sin prefijo si Comando='1'; si CliSock=nil, el resultado se descarta; b) vence TimeoutRespSrv; c) CancelarPeticiones. Las peticiones no enviadas no tienen TTL. El driver guarda como maximo 2 resultados en Peticiones (borra el mas viejo) y agrega {Folio:0,Resultado:'True\|'} por cada NOTHING que recibe. Las entradas repetidas o ya atendidas se ignoran en silencio.
- **Reconexión:** El Bridge es pasivo y no detecta desconexiones (no hay OnClientDisconnect). La actividad del driver se mide con horaAct: el ultimo mensaje de cualquier conexion PDisp. Si el driver reconecta, la conexion nueva simplemente empieza a hablar, y la peticion en vuelo que se envio a la conexion vieja vence a los 2 s. El driver se reconecta desde Timer2 (Active False/True con Sleep). Si se reinicia el Bridge se pierden la cola y el snapshot (DatosObsoletos=True hasta el primer JSON) y los folios vuelven a 1, mientras el driver conserva sus 2 ultimos resultados. SSocketOG se reabre en el siguiente mensaje del driver despues de haberse cerrado por inactividad. Auto-kick: con el snapshot obsoleto y actividad en los ultimos 10 s, se encola 'DISPENSERS\|TRACE\|' sin socket cada 3 s; en el driver, cada TRACE vuelca sus logs a disco.
- **Comandos:**
  - STATE: se contesta local desde el snapshot con 'DISPENSERS\|STATE\|True\|<Estado>\|', o False si no hay Estado o los datos estan obsoletos
  - STATUS [pos]: se contesta local. Devuelve la cadena de Estatus ordenada por DispenserId (1 caracter por posicion, huecos='0') o un solo caracter si se pide una posicion
  - TRANSACTION pos: se contesta local con HoraOcc\|Manguera\|Combustible\|Volumen(0.000)\|Precio(0.00)\|Importe(0.00)
  - PRICES, AUTHORIZE, PAYMENT: OG recibe 'True\|0\|' de inmediato y la peticion se encola sin socket; el resultado del driver (incluido el folio de comando de AUTHORIZE) se descarta
  - TRACE: se encola esperando respuesta y ademas el Bridge vuelca sus dos logs completos a disco
  - TOTALS y cualquier otro (INITIALIZE, PARAMETERS, LOGIN, LOGOUT, STOP, START, SELFSERVICE, FULLSERVICE, BLOCK, UNBLOCK, HALT, RUN, SHUTDOWN, TERMINATE, SAVELOGREQ, RESPCMND, LOG, LOGREQ): se pasan tal cual a la cola y esperan su resultado por folio durante TimeoutRespSrv
  - '0'/'1' (mensaje de 1 caracter sin trama): se encola como 'DISPENSERS\|0' o 'DISPENSERS\|1' con Comando='1' y el resultado se reenvia sin prefijo. Solo PAM y Wayne lo implementan
  - Cabecera DISPENSERSX: igual que DISPENSERS pero sin validar CRC; se reenvia al driver con esa misma cabecera
  - Bridge->driver: 'folio\|DISPENSERS\|CMD\|params', o '0\|DISPENSERS\|NOTHING' (el folio 0 esta reservado)
  - Auto-kick interno: 'folio\|DISPENSERS\|TRACE\|' sin socket de OG
- **Campos JSON:**
  - Estado (entero): lo usa STATE
  - PosCarga[] (lista; puede venir en cualquier orden)
  - PosCarga[].DispenserId (entero, identifica la posicion; TRANSACTION lo lee sin nil-check)
  - PosCarga[].Estatus (el Bridge asume 1 caracter, 0-9)
  - PosCarga[].HoraOcc (cadena), Manguera (entero), Combustible (entero), Volumen/Precio/Importe (flotantes): los usa TRANSACTION
  - PosCarga[].Hoses[] {HoseId, ProductId, Total} y TotalesEstimados (Gilbarco): se transmiten ~5 veces por segundo pero el Bridge no los usa
  - Peticiones[] (maximo 2 en el driver): {Folio (entero; 0 para NOTHING), Resultado (cadena 'True\|...' o 'False\|motivo\|')}
- **Desviaciones respecto a otros drivers:**
  - Ningun sentido tiene delimitador de mensaje. El Bridge asume que 1 ReceiveText = 1 mensaje y responde una vez por evento; los drivers asumen lo mismo con las respuestas del Bridge
  - El driver envia 'PING' exacto, pero el Bridge lo detecta por subcadena sin distinguir mayusculas
  - El comentario de IntentaRecuperarPDispensarios (523-539) supone que el driver se queda en PING para siempre. Pero todos los drivers contestan NOTHING con AddPeticionJSON, que pone respJson:=True (UIGASWAYNE2W 3290, 3980-3981), asi que el TRACE automatico es innecesario y vuelca logs en el driver
  - Kairos (legado) responde el resultado real de PRICES/AUTHORIZE/PAYMENT (UIGASKAIROS 533-550); el Bridge responde 'True\|0\|' y pierde el folio de comando que AUTHORIZE devuelve en Wayne2W (3381) para consultarlo con RESPCMND
  - '0'/'1' solo lo implementan UIGASPAM (386-407) y UIGASWAYNE (2781-2803); Wayne2W, Bennett, Gilbarco, HongYang, Team y Triton responden 'False\|Comando desconocido\|'
  - El driver agrega {Folio:0} a Peticiones por cada NOTHING. Eso empuja fuera los resultados reales de la ventana de 2 y hace que cada resultado viaje como maximo en 2 mensajes
  - El folio 1..999 se reinicia con el Bridge mientras el driver conserva sus resultados viejos, y el Bridge empareja primero la entrada mas vieja
  - El Bridge asume Estatus de 1 caracter; Gilbarco y PAM publican su variable interna estatus sin acotarla (no se verifico que nunca pase de 9)
  - Puertos: el .dfm dice 1002, el codigo usa 1004 por defecto y la version inicial usaba 1003; los drivers apuntan a 127.0.0.1:1004
  - Algunos drivers envian JSON fuera del ciclo (PAM 397-398 y 404-405, Wayne2W 3700-3701 en Iniciar, Wayne2W 2960 desde Timer1). Dos envios seguidos generan dos respuestas del Bridge que pueden llegar pegadas al driver
  - LOG/LOGREQ meten lineas completas del log del driver (incluidos 'E PING' y JSON completos) en Peticiones[].Resultado: el JSON resultante es enorme y se descarta por contener 'PING'

### Bloques duplicados con otros módulos

| Rutina | Líneas | Nota |
|---|---|---|
| Bloque de datos obsoletos | UIGASBRIDGE.pas 590-598, 625-633, 708-716 | El mismo if DatosObsoletos con el aviso doble en log, el datosObsoletosAvisados:=True y la respuesta 'False\|Datos obsoletos...' estan copiados en ObtenerEstado, ObtenerEstadoPosiciones y ObtenerTranPosCarga; solo cambia el nombre del comando. |
| Alta de peticion y folio | UIGASBRIDGE.pas 364-379 y 557-568 | inc(folio), el wrap a 999, TPeticion.Create, la asignacion de campos con Enviada=False y HoraEnvio=0, y el Push estan repetidos en AddPeticion y en IntentaRecuperarPDispensarios. |
| Formato de respuesta a OG por peticion | UIGASBRIDGE.pas 427-432, 842-847, 885-890 | 'if Assigned(p.CliSock) then if p.Comando=''1'' then ResponderOG(<sin prefijo>) else ResponderOG(''DISPENSERS\|''+p.Comando+''\|''+...)' se repite en CancelarPeticiones, ProcesaRespuestasJSON y TimerTimeoutTimer. |
| Log doble OG/PDisp | UIGASBRIDGE.pas 422-423, 572-573, 592-593, 627-628, 710-711, 822-823, 878-881 | El mismo mensaje se escribe con AgregaLogOG y con AgregaLogPDisp en siete lugares. |
| Volcado de logs | UIGASBRIDGE.pas 274, 341, 505, 737-743, 861-867 | Se usa ListaLog*.SaveToFile con el mismo patron de nombre, directamente o via GuardaLogOG/GuardaLogPDisp, sin un helper comun ni proteccion contra errores. |
| Recorte de listas de log | UIGASBRIDGE.pas 454-456 y 780-782 | El bucle 'while Count>10000 do Delete(0)' esta duplicado en AgregaLogOG y AgregaLogPDisp. |
| Unidades compartidas copiadas | uLkJSON.pas 1-2626, UVersionModulo.pas 1-131 (en ambos repos) | Son copias identicas en IgasDispensarios e IgasDispensariosBridge, mantenidas a mano. |

## Hallazgos (41)

<a id="BRG-01"></a>
#### BRG-01 · 🔴 Crítica · protocolo · bug — Sin framing Bridge<->PDISPENSARIOS: fragmentos y mensajes pegados rompen snapshot, resultados y parametros de comandos

- **Ubicación:** `UIGASBRIDGE.pas` líneas 745-774 (753, 757-767), 785-814
- **Módulos afectados:** UIGASBRIDGE.pas, UIGASWAYNE2W.pas, UIGASWAYNE.pas, UIGASPAM.pas, UIGASBENNETT.pas, UIGASGILBARCO.pas, UIGASHONGYANG.pas, UIGASTEAM.pas, UIGASTRITON.pas, uLkJSON.pas
- **Se atiende en:** [E0.4](../PLAN_OPTIMIZACION.md#e04--simuladores-de-opengas-y-de-driver--batería-de-pruebas-de-protocolo), [E6.1](../PLAN_OPTIMIZACION.md#e61--framing-y-buffer-por-conexión-en-los-dos-sentidos-y-del-lado-de-opengas)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  SSocketPDispClientRead trata cada Socket.ReceiveText, que lee lo que haya en el buffer (FIONREAD), como un mensaje completo del driver, y responde exactamente una vez por evento. Ningun sentido tiene terminador ni prefijo de longitud.
  (a) JSON fragmentado: pasa siempre si PDisp corre en otro host y el JSON supera el MSS; en loopback, con JSON grandes (LOG/LOGREQ) o bajo carga. ParseText devuelve nil en cada fragmento, asi que se pierden el snapshot y las Peticiones de ese mensaje, y el Bridge manda DOS respuestas al driver por un solo mensaje.
  (b) Dos JSON pegados: ocurre cuando el hilo unico del Bridge estuvo bloqueado (p.ej. en SaveToFile) o cuando el driver envia dos seguidos (PAM 397-398, Wayne2W 3700-3701). uLkJSON.ParseText (2030) parsea el PRIMER objeto e ignora el resto sin error: se instala el snapshot viejo, se descartan los resultados del nuevo y se responde una sola vez.
  (c) Dos respuestas del Bridge que llegan pegadas al driver (por (a), o porque se procesaron dos mensajes del driver por separado) se concatenan sin separador: '12|DISPENSERS|AUTHORIZE|3|1|500' + '0|DISPENSERS|NOTHING' = '12|DISPENSERS|AUTHORIZE|3|1|5000|DISPENSERS|NOTHING'. Wayne2W.AutorizarVenta (UIGASWAYNE2W 3349-3355) toma el elemento 3 como importe, asi que el preset seria de 5000 en vez de 500; si el ultimo parametro es finv, este se altera. En el orden inverso ('0|DISPENSERS|NOTHING12|...') el comando se vuelve 'NOTHING12', el driver responde 'Comando desconocido' y el AUTHORIZE se pierde, aunque OG ya recibio True.
  El caso (c) depende de la temporizacion (que el driver no lea antes de que llegue la segunda respuesta), por lo que su probabilidad es moderada; su impacto es una venta incorrecta.
- **Evidencia:** 753 `respTxt := Socket.ReceiveText;` -> 757-758 parse -> 762 `Socket.SendText(IntToStr(p.Folio)+'|'+p.Peticion)` / 767 `Socket.SendText('0|DISPENSERS|NOTHING')` sin terminador. uLkJSON.pas 2030 `if not js_base(idx, idx, result) then FreeAndNil(result);` no verifica que idx llegue al final del texto. Driver: UIGASWAYNE2W 3951-3963 toma el folio del elemento 1, el comando del 3 y concatena los elementos 4..N como parametros.
- **Impacto:** Se pierden snapshots y resultados: aparecen timeouts, 'datos obsoletos' y auto-kicks. Con respuestas concatenadas en el driver, los parametros de AUTHORIZE pueden corromperse (importe x10, finv invertido) o el comando perderse con True ya confirmado a OG: venta o cobro incorrecto.
- **Recomendación:**
  1) Definir framing en ambos sentidos: terminador #10 (el JSON de uLkJSON no lleva saltos de linea), ETX, o prefijo 'longitud:'.
  2) En el Bridge: un buffer por conexion (Socket.Data apuntando a un objeto TConexionPDisp con un string acumulado) y un bucle que extraiga los mensajes completos y responda una vez por cada uno.
  3) En los drivers: el mismo buffer en ClientSocket1Read.
  4) Migracion: el Bridge acepta ambos formatos; si el texto empieza con '{' o es 'PING' y parsea completo sin terminador, lo trata como legado.
  5) Despues de ParseText, verificar que se consumio todo el texto.
  Validacion: un cliente de prueba que mande el JSON en 2 trozos separados por 50 ms y 2 JSON en un solo send, y un servidor de prueba que mande 2 respuestas juntas al driver.
- **Esfuerzo:** L · **Riesgo del cambio:** alto · **Toca contrato:** sí

<a id="BRG-02"></a>
#### BRG-02 · 🔴 Crítica · correccion · bug — PRICES/AUTHORIZE/PAYMENT se confirman 'True|0|' antes de llegar al driver y el resultado real se descarta

- **Ubicación:** `UIGASBRIDGE.pas` líneas 372-375, 384-389, 839-851, 885-890
- **Módulos afectados:** UIGASBRIDGE.pas, OpenGas (externo), UIGASWAYNE2W.pas
- **Se atiende en:** [E5.2](../PLAN_OPTIMIZACION.md#e52--confirmación-real-de-prices-authorize-y-payment)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  AddPeticion encola los tres comandos con CliSock=nil y responde de inmediato 'DISPENSERS|<CMD>|True|0|' (384-389), cuando la peticion apenas esta en la cola y ni siquiera se envio. Cuando el driver contesta, ProcesaRespuestasJSON la saca de la cola y la libera sin registrar ni avisar nada (842, Assigned(p.CliSock)=False); si vence, TimerTimeoutTimer tampoco avisa (885).
  Asi, OG recibe exito aunque el driver conteste, por ejemplo:
  - 'False|Favor de indicar la cantidad que se va a despachar|' (UIGASWAYNE2W 3358);
  - 'False|Favor de indicar la posicion de carga|' (3365);
  - 'False|No fue posible aplicar comando de cambio de precios|' (3590);
  - una excepcion, un timeout, o aunque el driver nunca llegue a recibir el comando.
  Ademas, el '0' sustituye el folio de comando que el driver devuelve en AUTHORIZE ('True|'+IntToStr(EjecutaComando(...))+'|', 3381). OG podria usar ese folio con RESPCMND (3800-3821) para conocer el resultado real, pero nunca lo recibe.
  El driver legado Kairos responde el resultado real (UIGASKAIROS 533-550). La confirmacion inmediata fue deliberada (commit aa6821c 'agilizar reanudacion'; 01e1868 dejo CliSock=nil).
- **Evidencia:** 372 `if metodoEnum in [PRICES_e, AUTHORIZE_e, PAYMENT_e] then p.CliSock:=nil` ; 386-387 `ResponderOG('DISPENSERS|AUTHORIZE|True|0|', socket)` se ejecuta justo despues de Push, sin ningun envio; 842 `if Assigned(p.CliSock) then ...` sin else ni log.
- **Impacto:** OG da por buena una autorizacion, un cobro o un cambio de precios que el dispensario rechazo o nunca recibio: despachos no autorizados que nadie detecta, precios desalineados, PAYMENT no aplicado. Tampoco se puede consultar el resultado con RESPCMND.
- **Recomendación:**
  1) Hacer la confirmacion inmediata configurable por comando (ini 'ConfirmacionInmediata=PRICES,PAYMENT') y que AUTHORIZE espere por defecto el resultado real (CliSock=socket) con el timeout existente.
  2) Mientras tanto, como minimo:
  - registrar como ALERTA en el log todo resultado False o timeout de un comando fire-and-forget (folio, comando, parametros, resultado);
  - no confirmar True si el driver no esta vivo (ver el hallazgo de inactividad) o si la cola supera N elementos.
  3) Acordar con OpenGas el tiempo maximo de espera que tolera AUTHORIZE.
  Validacion: un driver simulado que conteste False, y otra prueba con el driver desconectado.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** sí

<a id="BRG-03"></a>
#### BRG-03 · 🔴 Crítica · correccion · bug — Con PDISPENSARIOS caido los comandos se confirman y luego se cancelan, o quedan sin TTL y se ejecutan tarde al reconectar

- **Ubicación:** `UIGASBRIDGE.pas` líneas 177-201 (190), 384-389, 409-412, 549-550
- **Módulos afectados:** UIGASBRIDGE.pas
- **Se atiende en:** [E3.1](../PLAN_OPTIMIZACION.md#e31--disponibilidad-puerto-1001-siempre-activo-y-driver-caído-detectado)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  La verificacion de inactividad (SecondsBetween(Now,horaAct)>=10) esta al FINAL de AddPeticion (409-412): despues de encolar y despues de responder True a PRICES/AUTHORIZE/PAYMENT. Luego CancelarPeticiones no avisa a esos comandos, porque su CliSock es nil.
  Entre 0 y 10 s de inactividad las peticiones se encolan sin enviarse, y TryPopExpired solo vence las que tienen Enviada=True (190), asi que no tienen TTL. Si OG deja de enviar (la linea 409 ya no se ejecuta) y el driver reconecta minutos despues, la cola se vacia sobre el driver y este ejecuta un AUTHORIZE, PRICES o PAYMENT viejo. TimerTimeout no revisa la inactividad del driver.
- **Evidencia:** 409-412 `if SecondsBetween(Now, horaAct)>=10 then begin CancelarPeticiones('Pdispensarios sin actividad'); SSocketOG.Active:=False; end;` queda fuera del case y despues de Push/ResponderOG; 190 `if Tmp.Enviada and (Tmp.HoraEnvio > 0) and (SecondsBetween(...) >= TimeoutSeg)`. Los reinicios del driver son un escenario conocido (commit 2e5f568).
- **Impacto:** Autorizaciones falsas durante caidas o reinicios del driver, y ejecucion diferida de autorizaciones o cierres de venta fuera de contexto (una bomba autorizada sin cliente).
- **Recomendación:**
  1) Evaluar si el driver esta vivo ANTES de procesar: conexion PDisp activa y horaAct menor a N s (configurable, p.ej. 3 s). Si no lo esta, responder 'DISPENSERS|<CMD>|False|Pdispensarios no disponible|' sin encolar.
  2) Agregar a TPeticion un TTL desde la hora de encolado (campo HoraAlta, ini TimeoutCola, p.ej. 5 s) y revisarlo en TimerTimeout para todas las peticiones, enviadas o no.
  3) Mover la deteccion de inactividad al timer.
  Validacion: detener el driver, mandar AUTHORIZE desde OG y reconectar a los 60 s.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BRG-04"></a>
#### BRG-04 · 🟠 Alta · protocolo · bug — Deteccion de PING por subcadena sin distinguir mayusculas descarta JSON validos

- **Ubicación:** `UIGASBRIDGE.pas` líneas 757
- **Módulos afectados:** UIGASBRIDGE.pas
- **Se atiende en:** [E3.2](../PLAN_OPTIMIZACION.md#e32--validación-del-snapshot-de-las-peticiones-y-de-los-parámetros)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  Para decidir si un mensaje es heartbeat, el Bridge usa AnsiContainsText(respTxt,'PING'), que busca la subcadena en TODO el texto sin distinguir mayusculas. Cualquier JSON que contenga 'ping' en cualquier valor se descarta completo: no se actualizan rootJSON ni horaUltimoDatoReal y no se procesan sus Peticiones.
  Casos reales:
  - el resultado de LOGREQ incluye lineas de ListaLogPetRes del driver, que registra 'E PING' (UIGASWAYNE2W 544 y 3758-3781), asi que LOGREQ vence siempre si el driver hizo PING recientemente;
  - textos de excepcion o resultados con palabras como 'stopping', 'mapping', 'pumping' o 'shipping';
  - un 'PING' que llega pegado a un JSON.
  Ademas, AnsiContainsText crea dos copias en mayusculas del JSON completo en cada mensaje (unas 5 por segundo).
- **Evidencia:** 757 `if not AnsiContainsText(respTxt,'PING') then ProcesaRespuestasJSON(respTxt);`
- **Impacto:** Resultados perdidos (timeouts hacia OG) y snapshot sin actualizar, lo que dispara 'datos obsoletos' y el auto-kick; LOG/LOGREQ quedan rotos en la practica.
- **Recomendación:** Comparar exacto: `if Trim(respTxt)='PING'`, y tratar como JSON solo lo que empiece con '{'. Con framing (hallazgo 1), hacer la evaluacion por mensaje. Validar con un Resultado que contenga 'Stopping' y con LOGREQ 50.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BRG-05"></a>
#### BRG-05 · 🟠 Alta · protocolo · bug — El lado OpenGas no tiene buffer de tramas: tramas pegadas o partidas se pierden o se procesan como basura

- **Ubicación:** `UIGASBRIDGE.pas` líneas 287, 291-294, 301-318
- **Módulos afectados:** UIGASBRIDGE.pas
- **Se atiende en:** [E6.1](../PLAN_OPTIMIZACION.md#e61--framing-y-buffer-por-conexión-en-los-dos-sentidos-y-del-lado-de-opengas)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  SSocketOGClientRead procesa cada ReceiveText como una sola trama: toma el PRIMER STX y el ULTIMO ETX.
  - Dos tramas que llegan juntas (p.ej. STATE y STATUS consecutivos) dejan el payload 'DISPENSERS|STATE|<ETX>CRC<ETB><SOH><STX>DISPENSERS|STATUS|'. El CRC final no coincide, se responde 'Checksum invalido' y se pierden ambas. Con cabecera DISPENSERSX se procesa la basura como un solo comando y la segunda peticion se pierde sin respuesta.
  - Una trama partida: la primera parte, sin ETX, deja checksum='' y se responde 'Checksum invalido'; la segunda, sin STX, se toma completa como mensaje y se responde 'Comando desconocido'.
  - El atajo de 1 caracter '0'/'1' tambien se dispara con un fragmento de 1 byte.
  Las tramas de OG ya traen delimitadores (SOH/STX/ETX/ETB), asi que se puede corregir sin tocar el contrato.
- **Evidencia:** 301-306: `for i:=1 to Length(mensaje) do if mensaje[i]=#2 then begin mensaje:=Copy(mensaje,i+1,...); Break;`; 307-313: busca #3 desde el final y toma 4 caracteres de checksum.
- **Impacto:** Peticiones de OG rechazadas o sin respuesta cuando OG manda en rafaga o la red fragmenta; OG queda esperando hasta su propio timeout.
- **Recomendación:** Un buffer por conexion OG (Socket.Data) y un extractor en bucle: buscar STX, luego ETX, exigir 4 hex mas ETB, procesar cada trama completa y conservar el residuo. Descartar con log si el buffer pasa de 64 KB sin trama valida. Tratar '0'/'1' solo si el buffer completo es exactamente ese caracter. Prueba: 2 tramas en un send y 1 trama en 2 sends.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="BRG-06"></a>
#### BRG-06 · 🟠 Alta · rendimiento · optimizacion — Cola con bloqueo de cabeza: una peticion por viaje y una respuesta perdida congela toda la cola 2-2.5 s

- **Ubicación:** `UIGASBRIDGE.pas` líneas 120-139, 177-201, 760-764
- **Módulos afectados:** UIGASBRIDGE.pas, todos los drivers (AddPeticionJSON/ClientSocket1Read)
- **Se atiende en:** [E3.4](../PLAN_OPTIMIZACION.md#e34--cola-prioridad-límite-y-deduplicación), [E6.2](../PLAN_OPTIMIZACION.md#e62--push-de-comandos-resultados-inmediatos-y-ack)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  TryStartNext solo entrega FList[0] y solo si no se ha enviado. Mientras la cabeza espera su resultado, cada mensaje del driver recibe 'NOTHING'.
  - El rendimiento maximo es 1 peticion por ida y vuelta del driver (~150-250 ms, mas en drivers con ciclo serial lento): una rafaga de N comandos (p.ej. PRICES por posicion o varios AUTHORIZE) tarda N veces ese tiempo.
  - Si la respuesta de la cabeza se pierde (JSON no parseado por los hallazgos 1, 4 o 37, driver reiniciado, o resultado empujado fuera de la ventana de 2 Peticiones), toda la cola se congela TimeoutRespSrv (2-2.5 s) por cada peticion perdida.
  - Comandos lentos o no criticos (TRACE automatico, LOG, LOGREQ, TOTALS) bloquean a AUTHORIZE y STOP.
  TryPopExpired solo revisa la cabeza: hoy es correcto porque solo la cabeza puede estar enviada, pero ese invariante no esta documentado.
- **Evidencia:** 127-134: `APeticion := TPeticion(FList[0]); if not APeticion.Enviada then ... else APeticion := nil;` ; 188-196 solo revisa FList[0]; 760-767 una peticion o NOTHING por mensaje.
- **Impacto:** Latencia alta para OG en rafagas, y bloqueos de 2 s o mas que alcanzan el timeout propio de OG.
- **Recomendación:**
  Corto plazo, sin cambiar el contrato: prioridad por comando (AUTHORIZE, STOP y PAYMENT antes que TRACE y LOG), timeout por comando y documentar el invariante 'solo la cabeza en vuelo'.
  Mediano plazo, con cambio de contrato: ventana de K peticiones en vuelo (varias por respuesta con delimitador, o una por mensaje sin esperar la anterior) y que el driver devuelva todos sus resultados pendientes, no solo 2.
  Medir antes y despues con las metricas de latencia del hallazgo 31.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** sí

<a id="BRG-07"></a>
#### BRG-07 · 🟠 Alta · robustez · bug — Activar SSocketOG dentro de la lectura del driver: si el puerto OG esta ocupado, el driver nunca recibe respuesta y se vuelca un log por segundo

- **Ubicación:** `UIGASBRIDGE.pas` líneas 755-756, 768-772
- **Módulos afectados:** UIGASBRIDGE.pas
- **Se atiende en:** [E3.1](../PLAN_OPTIMIZACION.md#e31--disponibilidad-puerto-1001-siempre-activo-y-driver-caído-detectado)
- **Verificación:** sin verificación independiente
- **Qué pasa:** En cada mensaje del driver, si SSocketOG no esta activo se ejecuta Active:=True dentro del try general. Si el puerto OG esta ocupado (otro proceso, una instancia vieja del Bridge, o PDISPENSARIOS con Marca 7 Kairos, que escucha en 1001 con su propio ServerSocket), el bind lanza ESocketError en CADA mensaje. Entonces se saltan ProcesaRespuestasJSON y la respuesta al driver, y el except llama a GuardaLogPDisp, que vuelca el log completo a un archivo nombrado por segundo (unos 5 intentos por segundo). El snapshot nunca se actualiza y OG no puede conectarse.
- **Evidencia:** 755-756 `if not SSocketOG.Active then SSocketOG.Active:=True;` ocurre antes de 757-767; 768-772: except -> `GuardaLogPDisp;`.
- **Impacto:** Servicio inutil en silencio (sin snapshot ni peticiones) y el disco se llena de archivos de log.
- **Recomendación:** Activar SSocketOG fuera del flujo de lectura: intentarlo desde TimerTimeout con backoff (p.ej. cada 10 s), con try/except propio y un log solo cuando cambie de estado. Procesar el JSON y responder al driver sin depender de SSocketOG. Validar ocupando el puerto 1001 con otro proceso.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BRG-08"></a>
#### BRG-08 · 🟠 Alta · robustez · bug — Volcados de log sin proteccion dentro de bloques except: rutaLog inexistente o disco lleno encadena excepciones y se pierden respuestas

- **Ubicación:** `UIGASBRIDGE.pas` líneas 236, 273-274, 338-343, 502-506, 737-743, 768-772, 799-804, 853-857, 861-867
- **Módulos afectados:** UIGASBRIDGE.pas
- **Se atiende en:** [E2.4](../PLAN_OPTIMIZACION.md#e24--bitácoras-que-no-bloquean-append-incremental-rotación-y-sin-json-repetido)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  Ningun guardado de log esta protegido, y GuardaLogOG, GuardaLogPDisp y los SaveToFile directos se llaman casi siempre DESDE bloques except. Si rutaLog no existe (default 'C:\OpenGas\Logs', que nunca se crea con ForceDirectories), el disco esta lleno o el archivo esta bloqueado, SaveToFile lanza EFCreateError dentro del except y esa segunda excepcion escapa:
  - en SSocketOGClientRead (341) impide enviar el error a OG (342);
  - en ResponderOG (505) aborta el bucle de ProcesaRespuestasJSON y los demas resultados del mismo JSON no se entregan; despues el except de ProcesaRespuestasJSON (856) y el de SSocketPDispClientRead (771) vuelven a fallar, y el driver no recibe respuesta;
  - en ServiceExecute (273), si ListaLogOG todavia es nil, se produce un AV.
- **Evidencia:** 236 `rutaLog:=config.ReadString('CONF','RutaLog','C:\OpenGas\Logs');` sin ForceDirectories; 505 `ListaLogOG.SaveToFile(...)` dentro de except; 737-743 y 861-867 GuardaLog* sin try.
- **Impacto:** Con una ruta de log invalida o el disco lleno se pierden respuestas a OG y al driver justo cuando hay errores.
- **Recomendación:** ForceDirectories(rutaLog) al arrancar, con la carpeta del exe como respaldo. Un unico procedimiento GuardarLogSeguro con try/except interno que nunca propague. No hacer E/S pesada dentro de un except: marcar una bandera y guardar desde el timer, con un maximo de 1 volcado por minuto. Validar con RutaLog apuntando a una carpeta inexistente.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BRG-09"></a>
#### BRG-09 · 🟠 Alta · seguridad · riesgo — Ambos puertos escuchan en todas las interfaces sin autenticacion: snapshot falsificable y comandos de venta abiertos a la red

- **Ubicación:** `UIGASBRIDGE.pas` líneas 237-238, 261-262, 320-332, 745-767; UIGASBRIDGE.dfm 9-24
- **Módulos afectados:** UIGASBRIDGE.pas, UIGASBRIDGE.dfm, instalador
- **Se atiende en:** [E5.5](../PLAN_OPTIMIZACION.md#e55--seguridad-de-red-del-bridge)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  Los dos TServerSocket escuchan en INADDR_ANY (el TServerSocket de D7 no publica la direccion de bind), sin autenticacion ni lista de IPs. Cualquier equipo de la red puede:
  (a) conectarse al puerto PDisp y enviar un JSON propio: el Bridge lo instala como snapshot y responde STATE/STATUS/TRANSACTION con datos falsos (importe y volumen de la venta). Ademas se lleva las peticiones de la cola, que se entregan a la primera conexion que hable.
  (b) conectarse al puerto OG y mandar AUTHORIZE, PRICES, HALT, SHUTDOWN, TERMINATE o LOGREQ (lectura de logs), usando DISPENSERSX para no calcular el CRC.
  Como no hay OnClientConnect, las conexiones no quedan registradas y un abuso no se detectaria.
- **Evidencia:** El dfm solo define Port y ServerType; no hay OnClientConnect con validacion de RemoteAddress; 329 `if (not chks_valido) and (cabecera <> 'DISPENSERSX')`.
- **Impacto:** Manipulacion de importes reportados (cobro incorrecto), autorizaciones o paros remotos y fuga de logs, en redes de estacion que suelen ser planas.
- **Recomendación:** Claves de ini 'IPsPermitidasPDisp' (default 127.0.0.1) e 'IPsPermitidasOG'. En OnClientConnect validar Socket.RemoteAddress y cerrar con log si no esta permitida. Limitar PDisp a una sola conexion. Deshabilitar DISPENSERSX por configuracion en produccion y agregar una regla de firewall en el instalador. Evaluar el bind a loopback con una clase derivada (TCustomWinSocket.Listen recibe Address); verificarlo en el fuente de ScktComp de D7.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="BRG-10"></a>
#### BRG-10 · 🟠 Alta · robustez · bug — ServiceExecute: un ini invalido o el puerto ocupado detienen el servicio sin error visible ni recuperacion del SCM

- **Ubicación:** `UIGASBRIDGE.pas` líneas 230-277 (235, 239, 251, 262, 271-276)
- **Módulos afectados:** UIGASBRIDGE.pas
- **Se atiende en:** [E2.3](../PLAN_OPTIMIZACION.md#e23--arranque-y-paro-ordenados-del-servicio)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  1) MinutosLog se lee con StrToInt(ReadString(...)) (239). Un valor no numerico lanza EConvertError ANTES de crear ListaLogOG (251); el except (273) usa ListaLogOG=nil y produce un AV dentro del except. La excepcion sale de ServiceExecute, TServiceThread solo la manda al Visor de eventos y el servicio se detiene sin log propio.
  2) Si SSocketPDisp.Active:=True falla (puerto ocupado por una instancia previa que aun se esta cerrando, u otro programa), el except escribe el log y ServiceExecute retorna normal. El servicio queda Detenido con codigo de salida 0, asi que las acciones de recuperacion del SCM ('reiniciar ante error') no se disparan (certeza media-alta sobre la semantica de SvcMgr D7).
  3) Si alguna excepcion escapa de ProcessRequests, el bucle termina sin CancelarPeticiones ni cierre ordenado.
  4) TIniFile nunca se libera (235).
  5) No hay OnStop/OnShutdown que guarden los logs.
- **Evidencia:** 239 `minutosLog:=StrToInt(config.ReadString('CONF','MinutosLog','0'));` antes de 251 `ListaLogOG:=TStringList.Create;`; 273 `ListaLogOG.Add(...)`; no existe config.Free.
- **Impacto:** El Bridge queda caido despues de un reinicio o una mala configuracion y nadie lo nota; todos los dispensarios quedan fuera de linea para OG.
- **Recomendación:** Crear primero las listas de log. Leer todo con ReadInteger y validar rangos. Usar try/finally con config.Free. Reintentar el bind con backoff (p.ej. 10 intentos cada 3 s); si se agotan, LogMessage(..., EVENTLOG_ERROR_TYPE), fijar ErrCode/Win32ErrCode y terminar con error para que el SCM aplique la recuperacion. Envolver el bucle en try/finally para el cierre ordenado y guardar los logs. Validar con un ini corrupto y con el puerto ocupado.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BRG-11"></a>
#### BRG-11 · 🟡 Media · correccion · bug — Folios 1..999 que reinician con el Bridge y emparejamiento del resultado mas viejo

- **Ubicación:** `UIGASBRIDGE.pas` líneas 27, 141-162, 364-366, 557-559, 832-852
- **Módulos afectados:** UIGASBRIDGE.pas
- **Se atiende en:** [E3.3](../PLAN_OPTIMIZACION.md#e33--timeouts-por-comando-en-milisegundos-y-folios-no-repetibles)
- **Verificación:** sin verificación independiente
- **Qué pasa:** folio es un campo que arranca en 0 cada vez que inicia el Bridge y rota entre 1 y 999. El driver no se reinicia con el Bridge y sigue mandando sus 2 ultimos resultados en Peticiones como [viejo, nuevo]. Tras reiniciar el Bridge, el primer comando sale con folio 1 o 2. Si el ultimo resultado del driver antes del reinicio tenia ese folio, al agregar el nuevo el arreglo queda [{1,viejo},{1,nuevo}] (AddPeticionJSON borra el indice 0 y agrega al final, UIGASWAYNE2W 3282-3289). El Bridge recorre desde i=0, empareja el resultado VIEJO y se lo entrega a OG. Lo mismo pasa si el driver agrega dos resultados con el mismo folio (p.ej. True y luego False por una excepcion): gana el primero. La probabilidad es baja, pero el resultado entregado seria de otra operacion.
- **Evidencia:** 364-366 `inc(folio); if folio>999 then folio:=1;` con folio sin persistencia; 832-839 `for i := 0 to jArray.Count - 1 ... TryPopByFolio(folioResp, p)` recorre del mas viejo al mas nuevo.
- **Impacto:** Respuesta equivocada a OG (p.ej. TOTALS o RESPCMND con datos de otra peticion) despues de reiniciar el Bridge.
- **Recomendación:** Iniciar folio con un valor no repetible ((GetTickCount div 1000) mod 999 + 1, o persistirlo en el ini al detener) y ampliar el rango a 1..99999 (los drivers lo leen con StrToIntDef, asi que es compatible). Recorrer Peticiones del final al inicio, el mas reciente primero. Validar reiniciando el Bridge con el driver vivo y mandando un comando enseguida.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BRG-12"></a>
#### BRG-12 · 🟡 Media · robustez · bug — El auto-kick con TRACE se basa en una premisa falsa, vuelca logs en el driver cada 3 s y ocupa la cabeza de la cola

- **Ubicación:** `UIGASBRIDGE.pas` líneas 523-578, 896-897
- **Módulos afectados:** UIGASBRIDGE.pas, drivers (efecto de TRACE)
- **Se atiende en:** [E3.3](../PLAN_OPTIMIZACION.md#e33--timeouts-por-comando-en-milisegundos-y-folios-no-repetibles)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  IntentaRecuperarPDispensarios encola 'DISPENSERS|TRACE|' cada AutoKickIntervaloSeg (3 s) mientras DatosObsoletos sea True y haya actividad en los ultimos 10 s.
  La premisa del comentario (523-539: el driver se queda en PING indefinidamente) no se sostiene con el codigo actual. Todos los drivers contestan NOTHING con AddPeticionJSON(folio,'True|') (UIGASWAYNE2W 3980-3981, UIGASBENNETT 347-348, etc.), y AddPeticionJSON pone respJson:=True (UIGASWAYNE2W 3290); el primer '0|DISPENSERS|NOTHING' ya despierta al driver.
  En cambio, TRACE ejecuta GuardarLog(folio) en el driver, que vuelca ListaLog y ListaLogPetRes completos a dos archivos (UIGASWAYNE2W 3545-3577). Cuando la obsolescencia viene de JSON que llega pero no se puede parsear (hallazgos 1, 4 y 37), el auto-kick no arregla nada:
  - genera 2 archivos en el driver cada ~3 s;
  - ocupa la cabeza de la cola hasta 2 s por intento;
  - consume folios.
  Con TimeoutDatosObsoletos<=0 o AutoKickIntervaloSeg<=0 (ninguno se valida), la frecuencia aumenta.
- **Evidencia:** 561-568 crea una TPeticion con Peticion='DISPENSERS|TRACE|'; 896-897 se llama en cada tick con datos obsoletos; driver: TRACE_e -> GuardarLog(folio) (UIGASWAYNE2W 4043-4044, 3545).
- **Impacto:** Llenado de disco y carga de E/S en el driver (que tambien atiende el serial), y retraso de comandos reales durante fallas de parseo.
- **Recomendación:** Sustituir TRACE por 'DISPENSERS|NOTHING' con folio mayor a 0: todos los drivers lo soportan y no escribe en disco. Agregar backoff exponencial y un maximo de intentos. No hacer el kick si en los ultimos segundos llegaron mensajes no-PING que fallaron al parsear (usar un contador); en ese caso alertar en el log. Validar los parametros con minimos. Prueba: reiniciar el driver y confirmar que no aparecen archivos LogDisp nuevos.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BRG-13"></a>
#### BRG-13 · 🟡 Media · robustez · riesgo — Cerrar SSocketOG dentro del evento de lectura de uno de sus propios clientes

- **Ubicación:** `UIGASBRIDGE.pas` líneas 292, 334, 347, 409-412
- **Módulos afectados:** UIGASBRIDGE.pas, OpenGas (externo)
- **Se atiende en:** [E3.1](../PLAN_OPTIMIZACION.md#e31--disponibilidad-puerto-1001-siempre-activo-y-driver-caído-detectado)
- **Verificación:** sin verificación independiente
- **Qué pasa:** AddPeticion corre dentro de SSocketOGClientRead, es decir, en el evento de un socket cliente de SSocketOG. Cuando detecta inactividad ejecuta SSocketOG.Active:=False, y en ScktComp eso cierra y LIBERA todas las conexiones cliente, incluida la que esta ejecutando el evento. Al regresar del manejador, ScktComp sigue en la pila de un objeto ya liberado: posible use-after-free (certeza media; depende de si ScktComp toca campos despues del evento). Ademas corta a todos los clientes OG y deja el puerto rechazando conexiones hasta que el driver vuelva a hablar. OG solo recibe un motivo explicito en la peticion que disparo el cierre.
- **Evidencia:** 334 `AddPeticion(mensaje,comando,Socket);` desde el evento del cliente -> 411 `SSocketOG.Active:=False;` (TServerWinSocket.Close libera las conexiones).
- **Impacto:** Posibles AV intermitentes durante caidas del driver, y desconexion masiva de OG.
- **Recomendación:** No cerrar el listener desde un evento de cliente: poner una bandera y cerrarlo desde TimerTimeout. Mejor aun, no cerrarlo y responder False 'Pdispensarios no disponible' (hallazgo 3) mientras el driver este inactivo. Si OG usa el cierre como senal, mantenerlo pero diferido y documentado. Validar con FastMM en modo FullDebug deteniendo el driver con OG conectado.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** sí

<a id="BRG-14"></a>
#### BRG-14 · 🟡 Media · correccion · bug — El destino de la respuesta a OG se identifica por puntero de socket: problema ABA y respuestas fuera de orden

- **Ubicación:** `UIGASBRIDGE.pas` líneas 64, 473-495, 427-432, 842-847, 885-890
- **Módulos afectados:** UIGASBRIDGE.pas
- **Se atiende en:** [E3.3](../PLAN_OPTIMIZACION.md#e33--timeouts-por-comando-en-milisegundos-y-folios-no-repetibles)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  La peticion guarda el puntero TCustomWinSocket del cliente OG. ResponderOG verifica que ese puntero siga en Connections[], lo que evita usar un objeto liberado. Pero si el cliente original se desconecto y una conexion NUEVA quedo en la misma direccion de memoria (el administrador de memoria de Delphi reutiliza bloques del mismo tamano), la respuesta tardia (resultado, TIMEOUT o CANCELA) se entrega al cliente equivocado (ABA). Si OG abre una conexion por peticion, esto es plausible.
  Ademas, el protocolo OG no lleva identificador de peticion: en una misma conexion, las respuestas locales (STATE/STATUS) adelantan a las encoladas, y OG no puede distinguir dos peticiones encoladas del mismo comando. El recorrido O(n) de ActiveConnections por respuesta es un costo menor.
- **Evidencia:** 484-489 `if SSocketOG.Socket.Connections[i] = socket then socketValido := True` compara solo direcciones.
- **Impacto:** OG recibe la respuesta de otra peticion (p.ej. un timeout de TOTALS cuando esperaba otra cosa).
- **Recomendación:** Asignar un id incremental por conexion en OnClientConnect (Socket.Data := Pointer(id)), guardarlo en TPeticion y buscar por id en ResponderOG. En OnClientDisconnect, cancelar las peticiones de esa conexion. Documentar que OG debe correlacionar por comando.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BRG-15"></a>
#### BRG-15 · 🟡 Media · memoria_recursos · optimizacion — Log en memoria de alto volumen: JSON completo 5 veces por segundo, Delete(0) O(n) y concatenacion caracter por caracter

- **Ubicación:** `UIGASBRIDGE.pas` líneas 439-457, 754, 761, 766-767, 776-783
- **Módulos afectados:** UIGASBRIDGE.pas
- **Se atiende en:** [E2.4](../PLAN_OPTIMIZACION.md#e24--bitácoras-que-no-bloquean-append-incremental-rotación-y-sin-json-repetido)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Cada mensaje del driver (PING o JSON completo, ~5 por segundo) y cada respuesta se agregan completos a ListaLogPDisp. Con JSON de varios KB y un tope de 10000 lineas, la lista puede ocupar decenas de MB y aun asi cubre solo ~15-30 minutos, porque la mitad de las lineas son 'E 0|DISPENSERS|NOTHING'. Al llegar al tope, cada Add hace un Delete(0) que desplaza 10000 punteros. AgregaLogOG arma la linea caracter por caracter (lin2:=lin2+lin[i]) con realocaciones repetidas. Al guardar, TStringList.SaveToFile crea una segunda copia completa del texto (GetTextStr) en un proceso de 32 bits, todo en el hilo unico del servicio.
- **Evidencia:** 754 `AgregaLogPDisp('R '+respTxt);` para todo mensaje; 780-781 `while ListaLogPDisp.Count>10000 do ListaLogPDisp.Delete(0);`; 444-453 bucle por caracter.
- **Impacto:** Memoria alta, CPU desperdiciada en el unico hilo y un historial util corto.
- **Recomendación:** Reemplazar por un logger con escritura incremental a un archivo diario (append con TFileStream y flush periodico desde el timer) o un buffer circular. No registrar PING/NOTHING uno por uno (usar un contador por minuto). Registrar el JSON solo cuando cambie (comparar longitud o hash) o truncarlo a N caracteres. En AgregaLogOG usar StringReplace. Medir la memoria privada del proceso antes y despues.
- **Esfuerzo:** M · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BRG-16"></a>
#### BRG-16 · 🟡 Media · robustez · riesgo — Archivos de log: volcados completos por segundo, sin rotacion, disparados por cada error y sin guardado al detener

- **Ubicación:** `UIGASBRIDGE.pas` líneas 264-270, 296-299, 341, 505, 687, 737-743, 771, 802, 856, 861-867
- **Módulos afectados:** UIGASBRIDGE.pas
- **Se atiende en:** [E2.4](../PLAN_OPTIMIZACION.md#e24--bitácoras-que-no-bloquean-append-incremental-rotación-y-sin-json-repetido)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  Cada volcado escribe la lista COMPLETA en un archivo nuevo nombrado con FiltraStrNum(FechaHoraToStr(Now)) (presumiblemente con resolucion de segundos; ULIBGRAL no esta en el repo). Volcados consecutivos duplican contenido y no hay rotacion ni borrado.
  Los volcados se disparan por:
  - TRACE de OG;
  - MinutosLog, que solo se evalua al recibir algo de OG (296);
  - CADA error: ObtenerEstadoPosiciones 687, SSocketPDispClientRead 771, ProcesaRespuestasJSON 802/856, ResponderOG 505, SSocketOGClientRead 341.
  Un error repetitivo genera un archivo de decenas de MB por segundo y bloquea el hilo unico mientras escribe. Al detener el servicio (264-270) NO se guarda el log, asi que se pierde el historial previo a cada reinicio. Ademas, cada guardado agrega 2 lineas de cabecera a la lista en memoria (740-741, 864-865).
- **Evidencia:** 742 `ListaLogOG.SaveToFile(rutaLog+'\LogOG'+FiltraStrNum(FechaHoraToStr(Now))+'.txt');`; el bloque 266-270 de cierre no llama a GuardaLog*.
- **Impacto:** El disco se llena con el tiempo, hay pausas de atencion y se pierde justo la evidencia de por que se reinicio el servicio.
- **Recomendación:** Log incremental diario con retencion configurable (MaxDiasLog). Guardar al detener, tras el bucle y en OnShutdown. Limitar los volcados por error a 1 por minuto y evaluar MinutosLog desde el timer. Validar provocando errores repetidos y midiendo la carpeta de logs.
- **Esfuerzo:** M · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BRG-17"></a>
#### BRG-17 · 🟡 Media · correccion · bug — STATUS asume que cada Estatus mide 1 caracter; con valores de 2+ caracteres se desplazan las posiciones

- **Ubicación:** `UIGASBRIDGE.pas` líneas 643-683 (669, 672-676, 680)
- **Módulos afectados:** UIGASBRIDGE.pas
- **Se atiende en:** [E3.2](../PLAN_OPTIMIZACION.md#e32--validación-del-snapshot-de-las-peticiones-y-de-los-parámetros)
- **Verificación:** sin verificación independiente
- **Qué pasa:** ObtenerEstadoPosiciones concatena estadosPorPosicion[i] (Trim(estadoNode.Value)) y, para una posicion, devuelve AEstados[xpos]. Eso asume que cada Estatus mide exactamente 1 caracter. Si algun driver manda un Estatus de 2 o mas caracteres (un numero >=10 o un texto), todas las posiciones siguientes se desplazan y STATUS, completo o por posicion, reporta el estado de otra bomba. Los drivers actuales mandan 0-9, pero Gilbarco y PAM publican su variable interna estatus (UIGASGILBARCO 3000, UIGASPAM 877) sin acotar; no se verifico que nunca pase de 9. Si xpos>maxPos se responde 'False|' sin motivo. maxPos sale del DispenserId recibido sin tope, asi que un id erroneo muy grande provoca un SetLength enorme.
- **Evidencia:** 680 `Result:='DISPENSERS|STATUS|True|'+AEstados[xpos]+'|';` indexa la cadena concatenada en lugar de estadosPorPosicion[xpos].
- **Impacto:** OG ve el estado de otra posicion (p.ej. 'despachando' en la bomba equivocada) y puede autorizar o cerrar la equivocada.
- **Recomendación:** Normalizar cada Estatus a 1 caracter (si Length<>1, usar '0' o un mapeo, con log de advertencia). Responder la posicion con estadosPorPosicion[xpos] directamente. Acotar maxPos (p.ej. 99) y dar motivo en los errores ('False|Posicion no existe|'). Prueba unitaria con PosCarga desordenado, con huecos y con Estatus=10.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BRG-18"></a>
#### BRG-18 · 🟡 Media · correccion · bug — TRANSACTION: Field[...] sin nil-check, sin Break, y FormatFloat dependiente de la configuracion regional

- **Ubicación:** `UIGASBRIDGE.pas` líneas 722-734 (728-730)
- **Módulos afectados:** UIGASBRIDGE.pas
- **Se atiende en:** [E3.2](../PLAN_OPTIMIZACION.md#e32--validación-del-snapshot-de-las-peticiones-y-de-los-parámetros)
- **Verificación:** sin verificación independiente
- **Qué pasa:** ObtenerTranPosCarga accede a posObj.Field['DispenserId'].Value y a HoraOcc, Manguera, Combustible, Volumen, Precio e Importe sin verificar nil. Si un objeto de PosCarga no trae alguno de esos campos (o lo trae null), ocurre un Access Violation o un EVariantError que sube hasta el except de AddPeticion (400-406), y OG recibe 'False|Error interno del Bridge: Access violation at address...' con direcciones internas. No hay Break al encontrar la posicion: si hubiera DispenserId duplicado, gana el ultimo. FormatFloat usa el DecimalSeparator global (configuracion regional de la cuenta del servicio), asi que en un equipo con coma decimal Volumen e Importe saldrian con ',' y romperian el parseo de OG. HoraOcc se concatena sin sanear el caracter '|'.
- **Evidencia:** 728 `if(posObj.Field['DispenserId'].Value=xpos) then` ; 729-730 `FormatFloat('0.000',posObj.Field['Volumen'].Value)` sin TFormatSettings.
- **Impacto:** TRANSACTION falla por completo ante un campo faltante, y en equipos con coma decimal se reportan importes mal formateados.
- **Recomendación:** Usar helpers GetStr/GetInt/GetFloat seguros ante nil, con valor por defecto. Hacer Break al encontrar la posicion. Usar FormatFloat con un TFormatSettings local (DecimalSeparator='.'). Si la posicion no existe, responder 'False|Posicion no encontrada|'. Probar con un JSON sin Importe y con configuracion regional es-ES.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BRG-19"></a>
#### BRG-19 · 🟡 Media · robustez · bug — ProcesaRespuestasJSON: cast duro de la raiz, except muerto y elementos de Peticiones sin validar

- **Ubicación:** `UIGASBRIDGE.pas` líneas 797-814, 832-852 (836-837)
- **Módulos afectados:** UIGASBRIDGE.pas
- **Se atiende en:** [E3.2](../PLAN_OPTIMIZACION.md#e32--validación-del-snapshot-de-las-peticiones-y-de-los-parámetros)
- **Verificación:** sin verificación independiente
- **Qué pasa:** TlkJSONobject(TlkJSON.ParseText(ATexto)) es un cast duro. Si la raiz es un numero, una cadena o una lista, rootJSON queda apuntando a algo que no es un TlkJSONobject, y las llamadas posteriores a rootJSON.Field (propiedad por defecto de TlkJSONobject, con OldGetField no virtual) leen memoria invalida. El except de las lineas 799-805 es practicamente codigo muerto: ParseText atrapa sus propias excepciones y devuelve nil (uLkJSON 2027-2033). El snapshot se reemplaza sin validar una estructura minima (PosCarga como lista, Estado). En el bucle, jItem.Field['Folio'].Value y ['Resultado'].Value se leen sin nil-check: un elemento malformado aborta el procesamiento de los demas resultados y provoca un volcado de log completo (856).
- **Evidencia:** 798 `nuevoJSON := TlkJSONobject(TlkJSON.ParseText(ATexto));` sin `is`; 836 `folioResp := jItem.Field['Folio'].Value;`.
- **Impacto:** Un mensaje inesperado del driver puede dejar el snapshot corrupto o hacer que se pierdan resultados validos del mismo mensaje.
- **Recomendación:** Hacer `if not (nuevo is TlkJSONobject) then begin nuevo.Free; Exit; end;`. Validar los campos minimos antes de reemplazar rootJSON. Usar try/except por elemento con getters seguros ante nil. Llevar un contador de JSON invalidos para observabilidad.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BRG-20"></a>
#### BRG-20 · 🟡 Media · configuracion · riesgo — Parametros del ini sin validacion y constantes criticas fijas en el codigo

- **Ubicación:** `UIGASBRIDGE.pas` líneas 36, 243, 409, 454, 549, 553, 236-245, 257, 365, 558, 780
- **Módulos afectados:** UIGASBRIDGE.pas
- **Se atiende en:** [E0.5](../PLAN_OPTIMIZACION.md#e05--configuración-documentada-y-validada-al-arrancar)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  Solo se valida TimeoutRespSrv (241-242).
  - TimeoutDatosObsoletos<=0 vuelve todo obsoleto: STATE queda en False permanente y el auto-kick no para.
  - AutoKickIntervaloSeg<=0 permite un TRACE por tick (500 ms).
  - No se detectan puertos fuera de rango ni iguales entre si.
  Ademas hay constantes criticas fijas en el codigo: 10 s de inactividad (409, 549), 10000 lineas de log (454, 780), 500 ms del timer (257) y el rango de folio 999 (365, 558). La configuracion efectiva no se registra al arrancar.
- **Evidencia:** 243-245 leen sin clamp; 409 `>=10` y 549 `>= 10` literales.
- **Impacto:** Un error de captura en el ini provoca comportamientos extremos (auto-kick continuo, STATE siempre False) dificiles de diagnosticar.
- **Recomendación:** Una funcion CargaConfig que lea, valide y acote (minimos y maximos) cada clave, nuevas claves para las constantes, y una linea de log con la configuracion efectiva al iniciar.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BRG-21"></a>
#### BRG-21 · 🟡 Media · correccion · riesgo — Umbral de obsolescencia de 5 s demasiado holgado y sin informar la edad del dato

- **Ubicación:** `UIGASBRIDGE.pas` líneas 243, 510-521, 590-598, 625-633, 708-716
- **Módulos afectados:** UIGASBRIDGE.pas
- **Se atiende en:** [E5.1](../PLAN_OPTIMIZACION.md#e51--semántica-única-de-estatus-y-campos-de-venta)
- **Verificación:** sin verificación independiente
- **Qué pasa:** STATE, STATUS y TRANSACTION se responden con el ultimo JSON si este tiene menos de TimeoutDatosObsoletos (default 5 s). El driver publica cada ~200 ms, asi que un snapshot de 4.9 s, unas 25 publicaciones perdidas, todavia se sirve como vigente. Un TRANSACTION consultado justo al terminar la venta puede devolver importe y volumen intermedios si el driver tardo en publicar, y OG no recibe la edad del dato. Al arrancar el texto dice 'hace -1s'. Con TimeoutDatosObsoletos<=0 todo es obsoleto siempre (ver hallazgo de configuracion).
- **Evidencia:** 520 `Result := segundos >= TimeoutDatosObsoletos;` con default 5 (243).
- **Impacto:** Riesgo de registrar en OG datos de venta que no son finales y de reportar estados ya superados.
- **Recomendación:** Medir primero el intervalo real de publicacion por marca (registrar la edad del snapshot en cada TRANSACTION) y despues bajar el default a ~2 s, con un minimo de 1 s. Usar el texto 'sin datos desde el arranque' cuando horaUltimoDatoReal=0. A mediano plazo, pedir a los drivers un numero de secuencia del snapshot.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BRG-22"></a>
#### BRG-22 · 🟡 Media · protocolo · riesgo — Bypass de CRC con DISPENSERSX sin control y comparacion de CRC sensible a mayusculas

- **Ubicación:** `UIGASBRIDGE.pas` líneas 314, 320-332, 459-471
- **Módulos afectados:** UIGASBRIDGE.pas
- **Se atiende en:** [E5.5](../PLAN_OPTIMIZACION.md#e55--seguridad-de-red-del-bridge)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Con la cabecera DISPENSERSX se omite la validacion de CRC para cualquier comando (incluidos AUTHORIZE, PRICES, PAYMENT y SHUTDOWN), sin bandera de configuracion ni registro especial; estaba pensado para pruebas manuales. La comparacion checksum=CRC16(mensaje) distingue mayusculas (CRC16 devuelve el hexadecimal en mayusculas), asi que un OG que envie el hex en minusculas seria rechazado. El CRC se calcula sobre el payload antes de quitar los '|' de los extremos; es correcto si OG hace lo mismo, pero no esta documentado. La respuesta de checksum invalido no dice cual era el CRC esperado, lo que dificulta el diagnostico.
- **Evidencia:** 314 `chks_valido:=checksum=CRC16(mensaje);` ; 329 `if (not chks_valido) and (cabecera <> 'DISPENSERSX')`.
- **Impacto:** Se pueden inyectar tramas corruptas o maliciosas sin deteccion, y hay rechazos falsos por diferencia de mayusculas.
- **Recomendación:** Clave de ini 'PermitirSinCRC' (default 1 por compatibilidad; recomendar 0 en produccion) y registrar en log cada peticion DISPENSERSX. Comparar con SameText. Registrar el CRC recibido y el calculado. Documentar el algoritmo (CRC16Desc de CRCs.pas) en el README.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BRG-23"></a>
#### BRG-23 · 🟡 Media · robustez · bug — Parseo de trama: mensaje vacio provoca AV (mensaje[1]) y el texto de la excepcion se manda a OG con '|'

- **Ubicación:** `UIGASBRIDGE.pas` líneas 287-318, 338-343, 400-406
- **Módulos afectados:** UIGASBRIDGE.pas
- **Se atiende en:** [E3.2](../PLAN_OPTIMIZACION.md#e32--validación-del-snapshot-de-las-peticiones-y-de-los-parámetros)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Si ReceiveText devuelve '' (un FD_READ espurio) o la trama es STX ETX con payload vacio, mensaje queda vacio y mensaje[1] o mensaje[Length(mensaje)] leen fuera de la cadena. Con $R- (PDISPBRIDGE.cfg) no salta ERangeError sino un Access Violation (la cadena vacia es un puntero nil). El except lo atrapa y responde a OG 'DISPENSERS||False|Access violation at address ...|'. Si no hay STX, se procesa el texto completo como payload; SOH y ETB no se validan. Los mensajes de excepcion se mandan tal cual a OG (342, 405): pueden contener '|', romper el parseo de campos y exponer direcciones internas.
- **Evidencia:** 315 `if mensaje[1]='|' then` y 317 `if mensaje[Length(mensaje)]='|' then` sin verificar Length>0; 342 `ResponderOG('DISPENSERS|'+comando+'|False|'+e.Message+'|',Socket);`.
- **Impacto:** Respuestas basura a OG ante mensajes vacios, y campos desalineados en las respuestas de error.
- **Recomendación:** Agregar `if mensaje='' then Exit;` tras extraer el payload. Exigir STX y ETX (con el extractor del hallazgo 5). Sanear e.Message (StringReplace de '|' por '/') y enviar a OG un texto generico con un codigo, dejando el detalle en el log.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BRG-24"></a>
#### BRG-24 · 🟡 Media · protocolo · bug — El mensaje legado '0'/'1' tiene una semantica distinta segun la marca

- **Ubicación:** `UIGASBRIDGE.pas` líneas 291-294, 428-429, 843-844, 886-887
- **Módulos afectados:** UIGASBRIDGE.pas, UIGASWAYNE2W.pas, UIGASBENNETT.pas, UIGASGILBARCO.pas, UIGASHONGYANG.pas, UIGASTEAM.pas, UIGASTRITON.pas
- **Se atiende en:** [E5.4](../PLAN_OPTIMIZACION.md#e54--comandos-homogéneos-entre-marcas)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El mensaje legado de 1 caracter '0'/'1' sirve para abrir o cerrar el puerto serial; Kairos responde '1' sin trama (UIGASKAIROS 431-437). El Bridge lo reenvia como 'folio|DISPENSERS|0'. Solo UIGASPAM (386-407) y UIGASWAYNE (2781-2803) lo implementan: responden '1' y, con '0', cierran el serial y ponen respJson:=False. Wayne 2W, Bennett, Gilbarco, HongYang, Team y Triton responden 'False|Comando desconocido|', que el Bridge reenvia enmarcado con SOH/STX/CRC. Para OG, el mismo mensaje significa cosas distintas segun la marca. Ademas espera en la cola como cualquier otro comando (bloqueo de cabeza).
- **Evidencia:** 292 `AddPeticion('DISPENSERS|'+mensaje,'1',Socket);` ; Wayne2W ClientSocket1Read 3974-4054 no tiene un caso para '0'/'1' y cae en 'Comando desconocido'.
- **Impacto:** OG puede interpretar como fallo el '0'/'1' en la mayoria de las marcas, o creer que el serial se abrio o cerro cuando no paso.
- **Recomendación:** Documentar el comportamiento esperado. Decidir si el Bridge lo contesta localmente (p.ej. '1' si el driver esta vivo) o si se implementa en todos los drivers; mientras tanto, registrar la respuesta en el log. Confirmar con el equipo de OpenGas si todavia se usa.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** sí

<a id="BRG-25"></a>
#### BRG-25 · 🟡 Media · robustez · riesgo — Se aceptan multiples conexiones PDisp que comparten snapshot y cola

- **Ubicación:** `UIGASBRIDGE.pas` líneas 745-774; UIGASBRIDGE.dfm 17-24
- **Módulos afectados:** UIGASBRIDGE.pas
- **Se atiende en:** [E3.1](../PLAN_OPTIMIZACION.md#e31--disponibilidad-puerto-1001-siempre-activo-y-driver-caído-detectado)
- **Verificación:** sin verificación independiente
- **Qué pasa:** SSocketPDisp acepta cualquier numero de conexiones, y todas comparten rootJSON, horaAct y la cola. Si conviven dos instancias (un driver reiniciado mientras la conexion vieja sigue medio abierta y enviando, dos PDISPENSARIOS mal configurados, o un cliente ajeno, ver hallazgo 9), los snapshots se pisan uno al otro y STATUS alterna entre dos realidades. La cabeza de la cola se entrega a la primera conexion que hable, y su resultado puede emparejarse con las Peticiones de la otra. No hay log de conexiones.
- **Evidencia:** No hay OnClientConnect ni limite de conexiones; 812-814 reemplaza rootJSON con el JSON de cualquier conexion.
- **Impacto:** Estados que cambian de forma erratica y peticiones ejecutadas por una instancia equivocada.
- **Recomendación:** Politica de una sola conexion PDisp: en OnClientConnect cerrar las anteriores (o rechazar la nueva), con log. Asociar el snapshot y la peticion en vuelo a una conexion, y reenviar o cancelar la peticion en vuelo si se cierra la conexion que la recibio.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BRG-26"></a>
#### BRG-26 · 🟡 Media · robustez · bug — No se revisa lo que devuelve SendText en sockets no bloqueantes

- **Ubicación:** `UIGASBRIDGE.pas` líneas 498, 501, 762, 767
- **Módulos afectados:** UIGASBRIDGE.pas
- **Se atiende en:** [E6.1](../PLAN_OPTIMIZACION.md#e61--framing-y-buffer-por-conexión-en-los-dos-sentidos-y-del-lado-de-opengas)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Los sockets son no bloqueantes y SendText devuelve los bytes enviados (o falla con WSAEWOULDBLOCK), pero el valor nunca se revisa. En respuestas grandes a OG (resultados LOG/LOGREQ reenviados), o si OG o el driver no leen a tiempo, la trama puede salir truncada sin aviso. La peticion al driver se marca Enviada aunque el envio haya fallado, y entonces vence a los 2 s.
- **Evidencia:** 762 `Socket.SendText(IntToStr(p.Folio)+'|'+p.Peticion);` ignora el resultado; TryStartNext ya marco Enviada=True (129).
- **Impacto:** Tramas truncadas a OG, que fallan el CRC, y peticiones perdidas que bloquean la cola.
- **Recomendación:** Encapsular el envio: revisar el retorno, guardar el remanente en un buffer por conexion y completarlo en OnClientWrite. Si el envio falla, no marcar Enviada (o revertirlo) y registrar en log.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="BRG-27"></a>
#### BRG-27 · 🟡 Media · protocolo · bug — LOG y LOGREQ por el Bridge generan JSON gigantes que se descartan

- **Ubicación:** `UIGASBRIDGE.pas` líneas 757, 785-859, 842-846
- **Módulos afectados:** UIGASBRIDGE.pas, todos los drivers (ObtenerLog/ObtenerLogPetRes)
- **Se atiende en:** [E4.4](../PLAN_OPTIMIZACION.md#e44--log-y-logreq-acotados)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  LOG y LOGREQ se reenvian al driver, que arma el resultado concatenando las ultimas r lineas de su log dentro de Peticiones[].Resultado (UIGASWAYNE2W 3732-3781). Cada linea puede contener un JSON completo 'E {...}' de varios KB, asi que con r de cientos el JSON del driver crece a cientos de KB. Entonces:
  - llega fragmentado (hallazgo 1);
  - puede contener 'PING' (hallazgo 4);
  - se repite en hasta 2 envios consecutivos (la ventana de 2 Peticiones);
  - se registra completo en ListaLogPDisp;
  - se reenvia a OG como una sola trama gigante (hallazgo 26).
  En la practica estos comandos tienden a vencer, y mientras tanto impiden que el snapshot se actualice, lo que dispara la obsolescencia y el auto-kick.
- **Evidencia:** El driver hace `log:=log+ListaLogPetRes[i]+'|'` y despues AddPeticionJSON(folio, log); en el Bridge, 757 y 798 procesan el JSON completo.
- **Impacto:** Las herramientas de diagnostico remoto no funcionan y degradan el servicio cuando se usan.
- **Recomendación:** Acotar r y la longitud de linea en el driver, o que el driver escriba el extracto a un archivo y devuelva la ruta, como hace TRACE. En el Bridge, no registrar esos resultados completos en el log. Coordinarlo con el contrato de framing.
- **Esfuerzo:** M · **Riesgo del cambio:** bajo · **Toca contrato:** sí

<a id="BRG-28"></a>
#### BRG-28 · 🟡 Media · observabilidad · riesgo — Los resultados tardios se descartan en silencio y 'Timeout' no significa 'no ejecutado'

- **Ubicación:** `UIGASBRIDGE.pas` líneas 832-852, 875-894
- **Módulos afectados:** UIGASBRIDGE.pas
- **Se atiende en:** [E0.3](../PLAN_OPTIMIZACION.md#e03--métricas-y-correlación-de-punta-a-punta-en-el-bridge)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Cuando una peticion vence, OG recibe 'False|Timeout excedido...' y la peticion se libera. Si el resultado llega despues, TryPopByFolio no la encuentra y se descarta sin dejar rastro. Pero un timeout no garantiza que el comando no se ejecuto: un STOP, BLOCK, INITIALIZE o PRICES pudo aplicarse en el dispensario, y si OG reintenta se ejecuta dos veces. Lo mismo pasa con los comandos fire-and-forget (hallazgo 2), cuyo resultado nunca se registra.
- **Evidencia:** 839 `if ListaPeticiones.TryPopByFolio(folioResp, p) then` no tiene rama else ni log.
- **Impacto:** Diagnostico imposible de 'OG dice que fallo, pero el dispensario lo hizo'; riesgo de doble ejecucion de comandos no idempotentes.
- **Recomendación:** Guardar los folios vencidos recientes (p.ej. los ultimos 50 con hora) y, si llega su resultado, registrar 'RESULTADO TARDIO folio N cmd X: <resultado>' y sumarlo a una metrica. Documentar para OG que, tras un timeout, debe consultar el estado antes de reintentar comandos no idempotentes.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BRG-29"></a>
#### BRG-29 · 🟡 Media · observabilidad · deuda_tecnica — No hay metricas de cola, latencia, timeouts, parseo ni edad del snapshot

- **Ubicación:** `UIGASBRIDGE.pas` líneas 760-767, 869-902
- **Módulos afectados:** UIGASBRIDGE.pas
- **Se atiende en:** [E0.3](../PLAN_OPTIMIZACION.md#e03--métricas-y-correlación-de-punta-a-punta-en-el-bridge), [E6.3](../PLAN_OPTIMIZACION.md#e63--snapshot-incremental-y-salud)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  No se mide nada de lo siguiente:
  - tamano de la cola y edad de la peticion en vuelo;
  - latencia por comando (de HoraEnvio al resultado);
  - numero de timeouts y cancelaciones;
  - JSON invalidos;
  - edad del snapshot;
  - conexiones activas de OG y PDisp;
  - auto-kicks y resultados tardios.
  Los logs de TIMEOUT no incluyen los parametros de la peticion. Para diagnosticar 'OG dice que no autorizo' hay que leer miles de lineas de PING y NOTHING.
- **Evidencia:** TimerTimeoutTimer solo registra TIMEOUT con folio y comando (878-881); no hay contadores en la clase.
- **Impacto:** Diagnostico lento en campo, y no se puede validar con datos el efecto de las optimizaciones de este plan.
- **Recomendación:** Contadores en memoria y una linea 'STAT' en el log cada 60 s (cola, en vuelo, p50/p95 de latencia por comando, timeouts, parse_err, edad del snapshot, conexiones). Opcionalmente, un comando 'DISPENSERS|BRIDGESTATUS' que conteste el propio Bridge; es aditivo y no rompe el contrato. Un log por peticion con folio, comando, parametros, tiempo en cola, tiempo de respuesta y resultado.
- **Esfuerzo:** M · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BRG-30"></a>
#### BRG-30 · 🟡 Media · build_despliegue · riesgo — Compilacion no reproducible: rutas absolutas, dependencias fuera del repo y .res ignorado

- **Ubicación:** `PDISPBRIDGE.cfg` líneas 36-42 (cfg); .gitignore 1-33; PDISPBRIDGE.dpr 8
- **Módulos afectados:** PDISPBRIDGE.cfg, PDISPBRIDGE.dpr, .gitignore, PDISPBRIDGE.drc
- **Se atiende en:** [E0.1](../PLAN_OPTIMIZACION.md#e01--build-reproducible-de-ambos-ejecutables)
- **Verificación:** sin verificación independiente
- **Qué pasa:** PDISPBRIDGE.cfg contiene rutas absolutas de una maquina de desarrollo (-E"C:\Users\jorge\Dropbox\Proyectos\IgasDispensariosBridge", y -U/-O/-I/-R con 'C:\Imagen Ib Libs\...'). ULIBGRAL, CRCs y RxMemDS no estan en el repo. El .gitignore excluye *.res, pero el .dpr hace {$R *.RES} y UVersionModulo depende del VERSIONINFO del .res para el campo 'Version archivo'; por lo tanto, la version que aparece en los logs depende del .res local de quien compila. El PDISPBRIDGE.drc (artefacto generado con -GD) si esta versionado. Ademas, $R- y $Q- desactivan las verificaciones de rango y overflow.
- **Evidencia:** cfg linea 36 `-E"C:\Users\jorge\Dropbox\..."`; .gitignore `*.res`; PDISPBRIDGE.dpr `{$R *.RES}`; PDISPBRIDGE.drc versionado (commit 4af6278).
- **Impacto:** No se puede reconstruir el binario de produccion desde un clon limpio, y la identificacion de la version en campo no es confiable.
- **Recomendación:** Versionar un .rc con VERSIONINFO compilado con brcc32 dentro de un script build.bat (dcc32 con rutas relativas). Vendorizar las dependencias o documentarlas con version y hash. Agregar *.drc al .gitignore y sacarlo del repo. Considerar $R+ en builds de prueba.
- **Esfuerzo:** M · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BRG-31"></a>
#### BRG-31 · ⚪ Baja · robustez · riesgo — Faltan OnClientError, OnClientConnect y OnClientDisconnect en ambos sockets

- **Ubicación:** `UIGASBRIDGE.pas` líneas 10-18; UIGASBRIDGE.dfm 9-24
- **Módulos afectados:** UIGASBRIDGE.pas, UIGASBRIDGE.dfm
- **Se atiende en:** [E3.1](../PLAN_OPTIMIZACION.md#e31--disponibilidad-puerto-1001-siempre-activo-y-driver-caído-detectado)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Los TServerSocket solo tienen OnClientRead. Sin OnClientError, ScktComp lanza ESocketError ante errores asincronos (p.ej. 10053/10054 cuando el driver u OG se cierran de golpe) dentro del despacho de mensajes. Esas excepciones terminan en Application.HandleException, que en SvcMgr las manda al Visor de eventos (certeza media sobre la ruta exacta), sin dejar registro en el log del Bridge. Sin OnClientConnect ni OnClientDisconnect no queda traza de quien se conecta ni de cuando se cae el driver, y no se limpian las peticiones del cliente que se desconecta.
- **Evidencia:** El .dfm solo asigna OnClientRead en ambos componentes.
- **Impacto:** Ruido en el Visor de eventos y ninguna visibilidad de desconexiones.
- **Recomendación:** Agregar OnClientError (log, ErrorCode:=0 y Socket.Close) y OnClientConnect/OnClientDisconnect (log con RemoteAddress, contadores y cancelacion de peticiones por conexion; ver hallazgos 13 y 24).
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BRG-32"></a>
#### BRG-32 · ⚪ Baja · concurrencia · riesgo — El modelo de hilo unico es correcto pero no esta documentado, y la E/S lenta congela todo

- **Ubicación:** `UIGASBRIDGE.pas` líneas 256-262, 264-265, 755-756
- **Módulos afectados:** UIGASBRIDGE.pas
- **Se atiende en:** [E0.2](../PLAN_OPTIMIZACION.md#e02--identificar-el-hilo-de-cada-evento-instrumentación)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  Esta verificado: TimerTimeout se crea dentro de ServiceExecute (256) y ambos sockets se activan en ServiceExecute (261-262) o dentro de un evento que ya corre en ese hilo (756). ScktComp asigna el HWND del socket de forma perezosa en el hilo que lo activa, y los sockets aceptados se crean en el manejador FD_ACCEPT de ese mismo hilo; ProcessRequests(True) (265) despacha esos mensajes. El Bridge es por tanto de hilo unico (certeza alta) y no hay carreras sobre rootJSON, las listas de log ni folio.
  Riesgos:
  (a) El invariante no esta documentado. Si TimerTimeout se moviera al .dfm (el intento original de d755c6a lo declaro como componente publicado sin instanciarlo), correria en el hilo principal y apareceria la concurrencia; la seccion critica solo protege la TList, no los TPeticion ni rootJSON.
  (b) Cualquier operacion lenta (SaveToFile de decenas de MB, hallazgos 15 y 16) congela al mismo tiempo la atencion a OG, al driver y los timeouts, y favorece los mensajes pegados (hallazgo 1).
- **Evidencia:** 256 `TimerTimeout:=TTimer.Create(Self);` dentro de ServiceExecute; 265 `ServiceThread.ProcessRequests(True);`; el dfm no contiene un TTimer.
- **Impacto:** Bajo hoy; es un riesgo latente ante refactorizaciones y la causa raiz de las pausas por E/S.
- **Recomendación:** Documentar el modelo de hilo unico en el codigo y el README. Agregar Assert(GetCurrentThreadId = FHiloServicio) en los manejadores. Sacar la E/S pesada del hilo o hacerla incremental.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BRG-33"></a>
#### BRG-33 · ⚪ Baja · configuracion · optimizacion — Timeout en segundos enteros con SecondsBetween y timer de 500 ms

- **Ubicación:** `UIGASBRIDGE.pas` líneas 21, 177-201, 240-242, 256-259
- **Módulos afectados:** UIGASBRIDGE.pas
- **Se atiende en:** [E3.3](../PLAN_OPTIMIZACION.md#e33--timeouts-por-comando-en-milisegundos-y-folios-no-repetibles)
- **Verificación:** sin verificación independiente
- **Qué pasa:** TimeoutRespSrv es un entero en segundos (minimo 1), y HoraEnvio es un TDateTime que se compara con SecondsBetween, que trunca y en D7 tiene imprecision de punto flotante, en un timer de 500 ms. El timeout real queda entre T y T+0.5 s, y no se puede ajustar por debajo de 1 s ni por comando.
- **Evidencia:** 191 `SecondsBetween(Now, Tmp.HoraEnvio) >= TimeoutSeg` ; 257 `TimerTimeout.Interval:=500;`.
- **Impacto:** No se pueden afinar latencias (p.ej. AUTHORIZE corto, LOG largo).
- **Recomendación:** Usar GetTickCount (ms) para HoraEnvio y HoraAlta, una clave TimeoutRespSrvMs con default 2000, un timer de 100-250 ms y una tabla de timeouts por comando.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BRG-34"></a>
#### BRG-34 · ⚪ Baja · rendimiento · optimizacion — CRC16 crea un objeto por llamada, sin try/finally, usa Destroy y se calcula dos veces por respuesta

- **Ubicación:** `UIGASBRIDGE.pas` líneas 459-471, 496-498
- **Módulos afectados:** UIGASBRIDGE.pas
- **Se atiende en:** sin item asignado (baja prioridad, ver E8.3)
- **Verificación:** sin verificación independiente
- **Qué pasa:** CRC16 crea y destruye un TCRC en cada llamada, sin try/finally (fuga si CalcBlock lanza) y con Destroy en lugar de Free. ResponderOG lo calcula dos veces por respuesta: una para el log y otra para el envio. @Data[1] sobre una cadena vacia depende de que CalcBlock tolere un puntero nil.
- **Evidencia:** 467-470 `aCrc:=TCRC.Create(CRC16Desc); aCrc.CalcBlock(pin,insize); Result:=...; aCrc.Destroy;` ; 497-498 dos llamadas a CRC16(resp).
- **Impacto:** Menor: CPU y asignaciones evitables en cada respuesta.
- **Recomendación:** Calcularlo una vez en una variable local y reutilizarlo; usar try/finally con Free. Opcionalmente, una funcion CRC16 por tabla sin objetos, verificando resultados identicos contra CRCs.pas con tramas reales.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BRG-35"></a>
#### BRG-35 · ⚪ Baja · build_despliegue · deuda_tecnica — Uses innecesarios (DB, RxMemDS, Graphics, Dialogs, Controls, SyncObjs) enlazan codigo de BDE

- **Ubicación:** `UIGASBRIDGE.pas` líneas 5-7
- **Módulos afectados:** UIGASBRIDGE.pas
- **Se atiende en:** [E0.1](../PLAN_OPTIMIZACION.md#e01--build-reproducible-de-ambos-ejecutables)
- **Verificación:** sin verificación independiente
- **Qué pasa:** La unidad usa Graphics, Controls, Dialogs, DB, RxMemDS, SyncObjs y Messages sin necesitarlos: no hay datasets ni dialogos, y la cola usa TRTLCriticalSection de Windows en lugar de SyncObjs. DB y RxMemDS enlazan codigo de base de datos y BDE (PDISPBRIDGE.drc contiene recursos bdeconst_* y VDBConsts_*) y obligan a tener RxLib en la ruta de compilacion.
- **Evidencia:** 7 `ScktComp, IniFiles, ULIBGRAL, DB, RxMemDS, uLkJSON, CRCs, ExtCtrls, SyncObjs;` ; PDISPBRIDGE.drc lineas 12-30 con bdeconst_*.
- **Impacto:** Un exe mas grande, dependencias de compilacion innecesarias y mas superficie.
- **Recomendación:** Quitar DB, RxMemDS, Graphics, Dialogs, Controls y SyncObjs (y Messages si compila sin ella). Recompilar, comparar el tamano del exe y verificar que el .drc ya no tenga bdeconst.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BRG-36"></a>
#### BRG-36 · ⚪ Baja · mantenibilidad · deuda_tecnica — Codigo muerto y confuso: campo ListaPeticiones en la cola, cmdAnt/horaPeticion, enum fuera de rango

- **Ubicación:** `UIGASBRIDGE.pas` líneas 29, 36, 56, 73, 87, 354, 381-382
- **Módulos afectados:** UIGASBRIDGE.pas
- **Se atiende en:** [E3.2](../PLAN_OPTIMIZACION.md#e32--validación-del-snapshot-de-las-peticiones-y-de-los-parámetros), [E8.3](../PLAN_OPTIMIZACION.md#e83--código-muerto-variables-globales-y-duplicación-interna)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  - TPeticionQueue declara un campo publico ListaPeticiones (73) que nunca se usa y que sombrea a la variable global del mismo nombre (87).
  - cmdAnt y horaPeticion (29, 36, 381-382) son restos del filtro de duplicados que se elimino en 01e1868.
  - TOTALS_e no se usa.
  - Para comandos desconocidos se hace TMetodos(GetEnumValue(...)) con -1 (fuera del rango del enumerado), y 'in [PRICES_e,...]' funciona por casualidad.
  - Todos los campos son publicos.
  - La seccion critica de la cola es redundante, porque todo corre en el hilo del servicio.
- **Evidencia:** 73 `ListaPeticiones : TPeticionQueue;` dentro de la clase; 381-382 se asignan pero nunca se leen.
- **Impacto:** Confunde a quien mantiene el codigo (o a una IA) y vuelve fragil la deteccion de comandos.
- **Recomendación:** Eliminar los campos muertos y pasar el estado a private. Validar `idx := GetEnumValue(...); if idx<0 then (comando passthrough)`. Conservar la seccion critica solo si se planea multihilo, y documentarlo.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BRG-37"></a>
#### BRG-37 · ⚪ Baja · mantenibilidad · deuda_tecnica — Bloques duplicados: obsolescencia, alta de peticion, formato de respuesta a OG y log doble

- **Ubicación:** `UIGASBRIDGE.pas` líneas 590-598, 625-633, 708-716, 364-379, 557-568, 427-432, 842-847, 885-890
- **Módulos afectados:** UIGASBRIDGE.pas
- **Se atiende en:** [E7.2](../PLAN_OPTIMIZACION.md#e72--updispenlacepas-conexión-framing-pingjson-peticiones-y-reconexión)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  - El mismo bloque de 'datos obsoletos' esta copiado en tres funciones.
  - La generacion de folio y la creacion de TPeticion se repiten en AddPeticion y en IntentaRecuperarPDispensarios.
  - El formato de respuesta a OG segun Comando='1' se repite en tres lugares.
  - El mismo mensaje se escribe en ambas listas de log en siete lugares.
  Cualquier cambio de contrato (hallazgos 1-3) tendria que tocar todas las copias.
- **Evidencia:** Ver las lineas citadas; los bloques son textualmente iguales.
- **Impacto:** Alto riesgo de corregir una copia y olvidar otra.
- **Recomendación:** Extraer VerificaObsoleto(cmd, out resp), NuevaPeticion(cmd, peticion, socket): TPeticion, ResponderPeticion(p, resultado) y LogAmbos(msg).
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BRG-38"></a>
#### BRG-38 · ⚪ Baja · rendimiento · optimizacion — STATUS y TRANSACTION recalculan todo sobre el JSON en cada consulta

- **Ubicación:** `UIGASBRIDGE.pas` líneas 608-735, 812-814
- **Módulos afectados:** UIGASBRIDGE.pas
- **Se atiende en:** [E4.2](../PLAN_OPTIMIZACION.md#e42--json-más-barato-generar-menos-redondear-y-buscar-menos)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Cada STATUS recorre PosCarga dos veces, hace busquedas lineales por nombre (OldGetField llama a IndexOfName con conversion a WideString; USE_HASH esta desactivado en uLkJSON linea 165) y concatena la cadena. TRANSACTION hace 8 busquedas por posicion y no se detiene al encontrarla. OG consulta STATUS con frecuencia. Ademas, el JSON completo se parsea 5 veces por segundo, incluidos Hoses y Total, que el Bridge no usa. El costo absoluto es bajo, pero es CPU del unico hilo.
- **Evidencia:** 643-670 dos pasadas con Field['DispenserId'] y Field['Estatus']; 722-734 sin Break.
- **Impacto:** Bajo; el precalculo ademas simplifica la validacion (hallazgos 17 y 18).
- **Recomendación:** Al instalar un snapshot nuevo, precalcular una sola vez la cadena de estados y un arreglo de transacciones por DispenserId (estructuras Delphi simples); STATE, STATUS y TRANSACTION solo leen esa cache.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BRG-39"></a>
#### BRG-39 · ⚪ Baja · configuracion · deuda_tecnica — El puerto del .dfm (1002) no coincide con el default del codigo (1004) y no hay ini de ejemplo

- **Ubicación:** `UIGASBRIDGE.dfm` líneas 17-21 (dfm); UIGASBRIDGE.pas 238
- **Módulos afectados:** UIGASBRIDGE.dfm, UIGASBRIDGE.pas
- **Se atiende en:** [E0.5](../PLAN_OPTIMIZACION.md#e05--configuración-documentada-y-validada-al-arrancar)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El .dfm define Port=1002 para SSocketPDisp, la version inicial usaba 1003 como default y el codigo actual usa 1004 (default de ReadInteger). El valor del .dfm nunca se usa, pero confunde. Los drivers apuntan por defecto a 127.0.0.1:1004. No hay un PDispBridge.ini de ejemplo en el repo ni documentacion de sus claves.
- **Evidencia:** dfm `Port = 1002`; 238 `config.ReadInteger('CONF','PuertoPDisp',1004)`.
- **Impacto:** Errores de configuracion en instalaciones nuevas.
- **Recomendación:** Alinear el .dfm a 1004. Agregar PDispBridge.ini.ejemplo con todas las claves comentadas. Registrar en el log la configuracion efectiva al arrancar.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BRG-40"></a>
#### BRG-40 · ⚪ Baja · mantenibilidad · deuda_tecnica — uLkJSON.pas y UVersionModulo.pas estan duplicados en los dos repos

- **Ubicación:** `uLkJSON.pas` líneas 1-2626 (copia identica en ambos repos); UVersionModulo.pas 1-131
- **Módulos afectados:** uLkJSON.pas, UVersionModulo.pas
- **Se atiende en:** [E0.1](../PLAN_OPTIMIZACION.md#e01--build-reproducible-de-ambos-ejecutables)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Ambas unidades estan copiadas de forma identica en IgasDispensarios e IgasDispensariosBridge (diff sin diferencias). Cualquier correccion, como validar el texto sobrante en ParseText, debe replicarse a mano, y el contrato JSON depende de que las dos copias se comporten igual.
- **Evidencia:** `diff -q` entre ambos repos no reporta diferencias.
- **Impacto:** Riesgo de que las copias diverjan entre productor y consumidor del JSON.
- **Recomendación:** Moverlas a un repo o carpeta comun (submodulo git o ruta compartida en el .cfg), o agregar al build una verificacion que compare sus hashes.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="BRG-41"></a>
#### BRG-41 · ⚪ Baja · mantenibilidad · deuda_tecnica — README de una linea: el protocolo, los puertos y el ini no estan documentados

- **Ubicación:** `README.md` líneas 1
- **Módulos afectados:** README.md
- **Se atiende en:** [E8.4](../PLAN_OPTIMIZACION.md#e84--documentación)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El README tiene una sola linea. El protocolo (tramas de OG, folios, NOTHING, Peticiones, PING, auto-kick, puertos, claves del ini y modelo de hilos) solo se puede deducir leyendo el codigo y los commits. Eso dificulta trabajar los cambios por etapas (tambien con IA) y coordinar los despliegues de ambos lados.
- **Evidencia:** README.md contiene solo '# IgasDispensariosBridge'.
- **Impacto:** Cada cambio requiere volver a investigar el contrato, con alto riesgo de romperlo.
- **Recomendación:** Documentar los contratos OG<->Bridge y Bridge<->driver con ejemplos, diagramas de secuencia y una tabla de comandos (local, encolado, fire-and-forget); las claves del ini con defaults y rangos; y el procedimiento de despliegue coordinado.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

