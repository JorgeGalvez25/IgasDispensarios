# Hallazgos · E2E · Interacción de punta a punta OpenGas ↔ Bridge ↔ drivers

> Anexo del [plan de optimización](../PLAN_OPTIMIZACION.md). Código auditado: `IgasDispensarios@26ccfb4`, `IgasDispensariosBridge@99edafd`. Las líneas pueden haber cambiado: ubica las rutinas por su nombre.

## Cómo funciona este módulo

El sistema tiene tres piezas. OpenGas es el cliente externo y no está en los repositorios. PDISPBRIDGE corre en un solo hilo: SSocketOG, SSocketPDisp y TimerTimeout se crean o activan en ServiceExecute y se atienden con ProcessRequests. PDISPENSARIOS carga un driver por marca. OpenGas manda tramas SOH STX DISPENSERS|CMD|params ETX CRC16 ETB al puerto 1001. El driver es cliente TCP del puerto 1004: envía 'PING' o el rootJSON completo (Estado, PosCarga[], Peticiones[]) a su propio ritmo. El Bridge contesta cada mensaje con a lo más una petición '<folio>|DISPENSERS|CMD|params' o con '0|DISPENSERS|NOTHING'.

(a) STATUS. El Bridge responde en menos de 1 ms desde el snapshot, sin pasar por el driver. La frescura del dato es la edad del último JSON (como máximo la cadencia T del driver; si pasa de 5 s responde 'Datos obsoletos') más el ciclo serial de la posición.

(b) AUTHORIZE. El Bridge responde 'DISPENSERS|AUTHORIZE|True|0|' en el acto y encola la petición con CliSock=nil. El comando baja en el siguiente envío del driver (entre 0 y T). AutorizarVenta registra OCC/OCL en TabCmnd y devuelve 'True|<FolioCmnd>|', que el Bridge descarta. El preset y la autorización salen al serial cuando el ciclo visita la posición en el estado correcto (en Wayne 2W, NumPaso 4 con estatus 5). STATUS muestra 9 y luego 2 después de otro sondeo y otro envío: de 0.3 a 3 s típicos.

(c) PAYMENT. Es igual que AUTHORIZE pero con 'FINV pos', que ProcesaComandos ejecuta más tarde. El efecto solo se ve en STATUS (de 3 a 1).

(d) TOTALS. Se encola con espera. TotalesBomba registra 'TOTAL pos' y responde 'True|0|0|0|0|0|0|<FolioCmnd>|' en unas 1.5T. Después OpenGas sondea con RESPCMND <FolioCmnd>; cada sondeo cuesta otras 1.5T y responde 'False|*|' mientras no hay dato, hasta que el ciclo lee el totalizador (Wayne 2W: NumPaso 3, con 3 reintentos). En total, de 1 a 6 s. El campo Hoses[].Total del JSON no se usa.

(e) Arranque. El driver empieza con estado -1 y envía PING cada 200 ms con Timer2. El primer mensaje abre el puerto 1001 del Bridge, y la respuesta NOTHING pone respJson en True (menos en Triton). INITIALIZE ('{json}|variables' separadas por CRLF) se atiende de forma síncrona en ClientSocket1Read y responde True en 0.2 a 0.4 s. En 5 drivers STATE sigue en -1 hasta RUN. PARAMETERS responde True. RUN abre el serial, pone estado en 1, enciende Timer1 y apaga Timer2. La secuencia completa tarda de 1 a 1.5 s, más el ritmo de OpenGas.

(f) Reinicio del driver. El Bridge no tiene OnClientDisconnect. La petición en vuelo expira entre 2 y 2.5 s, y STATUS sirve el snapshot viejo hasta 5 s y luego reporta 'obsoleto'. Si pasan 10 s sin tráfico, el siguiente comando de OpenGas cancela la cola y cierra el puerto 1001. Al volver, el driver envía PING, recibe NOTHING y manda un JSON {Estado:-1} sin PosCarga, que el Bridge acepta como fresco. OpenGas tiene que repetir INITIALIZE y RUN (solo PAM tiene modoAuto). TabCmnd y FolioCmnd vuelven a empezar.

(g) Reinicio del Bridge. Todos los drivers apagan Timer1, así que se detiene el sondeo serial. Reintentan con Timer2 bloqueando el hilo principal con Sleep. Al reconectar envían el JSON de inmediato, el snapshot se recupera, el folio vuelve a 1 y la cola se pierde. Triton no se recupera nunca.

(h) Caída del socket. En el driver pasa lo mismo que en (g). En el Bridge la cola se conserva y la petición en vuelo expira; su resultado, que sigue en Peticiones, se ignora si llega tarde. Wayne 2W y Bennett además se desconectan solos si el Bridge no contesta en 2 s.

Latencia y throughput. Solo hay un comando en vuelo a la vez. La latencia es la espera al siguiente envío (entre 0 y T) más T: en promedio 1.5T, como máximo 2T, y T más por cada comando que haya delante en la cola. El throughput máximo es 1/T comandos por segundo:

- Timer2: T=200 ms, 5 cmd/s, latencia media 0.3 s.

- Team: T=750 ms, 1.3 cmd/s, latencia media 1.1 s.

- PAM: T de 0.25 a 0.3 s, 3 a 4 cmd/s.

- Wayne 2W y Gilbarco: 3 ticks más el tiempo serial, de 0.3 a 2 s, de 0.5 a 3 cmd/s. Pueden rebasar el timeout de 2 s.

- HongYang: de 0.05 a 0.1 s, de 10 a 20 cmd/s.

- Bennett, Wayne y Triton: una respuesta por cada respuesta serial, de 0.15 a 0.3 s. Triton no envía nada si el dispensario no responde.

### Ciclo serial

Modelo de hilos. Se dedujo leyendo el código; la certeza de cada punto va entre corchetes.

- [ALTA] Los TTimer de los .dfm se crean en el hilo principal (Application.CreateForm) y sus eventos corren en el bucle Forms.Application.HandleMessage de TServiceApplication.Run. ServiceExecute corre en TServiceThread, y ProcessRequests(True) solo bombea las ventanas de ese hilo.

- [MEDIA-ALTA] ScktComp crea la ventana del socket de forma perezosa, en el hilo que lo activa.

  - Wayne, Wayne 2W, Gilbarco, HongYang, PAM, Team y Triton activan ClientSocket1 en Timer2Timer, en el hilo principal. Ahí no hay concurrencia real, sino reentrancia y bloqueos por Sleep.

  - Bennett (L276) y Kairos (L397) activan el socket en ServiceExecute. El socket queda en el hilo del servicio y los timers en el principal: hay carreras reales.

  - PAM con modoAuto llama a Inicializar e Iniciar desde ServiceExecute, es decir, maneja TTimer desde otro hilo.

- [BAJA-MEDIA] Async Pro parece entregar OnTriggerAvail y OnTriggerData como mensajes al hilo que abrió el puerto. Lo sugiere que Wayne 2W y Gilbarco tengan que bombear mensajes para ver bListo. Hay que confirmarlo registrando GetCurrentThreadId.

- En el Bridge todo corre en el hilo del servicio, así que la sección crítica de la cola sobra.



Ciclo serial por marca:

- Wayne 2W y Gilbarco: Timer1 de 50 ms con la máquina NumPaso 0..7 por posición (precios, estatus, venta final, totales, preset, venta en proceso, comandos, cambio de precio). Cada paso es una transacción síncrona: apaga Timer1 y espera la respuesta llamando ServiceThread.ProcessRequests(False) hasta GtwTimeout (300 ms) por cada uno de los GtwIntentos (2), con GtwTiempoCmnd (50 ms) entre intentos. Wayne 2W no duerme en esa espera y ocupa el 100% de un núcleo. Gilbarco duerme 5 ms.

- HongYang: 15 ms. A (display y estatus por manguera, inactivas por tiempo), N (totales), V (precios), Z (publica estatus), W (cola de comandos). Reabre el puerto cada 6 h.

- Bennett: 150 ms. Envía B00 y procesa en pSerialTriggerAvail y ProcesaLinea, con MaxEsperaRsp=4 ciclos.

- Triton: 150 ms. Envía 'ST' o ejecuta ProcesaComandos.

- PAM, Team y Wayne: 250 ms. Team reinicia su ciclo si pasan 5 s sin respuesta B.

- Kairos: 280 ms.

- Comandos: TabCmnd tiene 200 entradas, que se liberan un minuto después de usarse. Los comandos se ejecutan en ProcesaComandos.

- Sin comunicación: Wayne 2W y Gilbarco esperan 3 fallas de estatus (MaxFallasEstatus) antes de marcar la posición, y la lectura de totales tiene 3 reintentos.



Envío al Bridge:

- Timer2 envía cada 200 ms mientras estado sea menor o igual a 0 o el driver esté desconectado.

- En ejecución:

  - Wayne 2W y Gilbarco: cada tercer tick.

  - HongYang: cada tercer tick; en la práctica, siempre.

  - PAM: cada tick.

  - Team: cada 750 ms.

  - Bennett y Wayne: tras cada ProcesaLinea.

  - Triton: tras cada ETX serial.

- Hay envíos extra con RUN (Wayne 2W y Bennett) y con '0'/'1' (Wayne y PAM).



Vigilancia: Wayne 2W y Bennett cierran el socket y apagan Timer1 si el Bridge no contesta en 2 s (horaAct). Los demás no vigilan al Bridge.

### Contrato con el Bridge, visto desde este módulo

- **Conexión:** Conexión TCP no bloqueante con ScktComp. El driver es cliente (ServidorSocket, por defecto 127.0.0.1:1004) de SSocketPDisp: PuertoPDisp vale 1004 por defecto en el código y 1002 en el .dfm. OpenGas es cliente de SSocketOG (PuertoOG 1001). El Bridge activa ese puerto con el primer mensaje del driver y lo cierra si llega un comando de OpenGas después de 10 s o más sin tráfico del driver. No hay framing ni delimitador: cada ReceiveText se trata como un mensaje completo. No hay autenticación, se escucha en todas las interfaces y se aceptan N conexiones de drivers. Kairos (Marca 7) no usa el Bridge: abre su propio TServerSocket en el Puerto del ini (por defecto 1001).
- **Ciclo de envío:** Mientras el estado es menor o igual a 0, o tras una desconexión, Timer2 envía cada 200 ms: PING si respJson es False y el JSON completo si es True. En ejecución Timer2 se apaga y envía el ciclo serial: Wayne 2W y Gilbarco en cada tercer tick de Timer1 (50 ms más la duración serial); HongYang en cada tercer tick de 15 ms si el texto cambió o si socketResponse está asignado (lo que en la práctica pasa siempre); PAM en cada tick de 250 ms; Team cada 750 ms (MsEnvioJSON); Bennett y Wayne al final de cada ProcesaLinea; Triton después de cada respuesta serial completa (ETX). Hay envíos extra dentro de ClientSocket1Read: RUN en Wayne 2W y Bennett, y '0'/'1' en Wayne y PAM. El driver nunca espera la respuesta del Bridge antes del siguiente envío; cada envío provoca exactamente una respuesta.
- **PING vs JSON:** respJson empieza en False, así que el driver envía 'PING'. Cualquier llamada a AddPeticionJSON lo pone en True, incluida la respuesta a NOTHING con folio 0 (salvo en Triton, que no maneja NOTHING). Desde ahí el driver siempre envía el JSON completo. Solo Wayne y PAM vuelven respJson a False, con el comando '0'. El Bridge distingue los dos casos con AnsiContainsText(respTxt, 'PING'), que busca una subcadena sin distinguir mayúsculas. Un PING solo actualiza horaAct (vida del enlace). Un JSON reemplaza rootJSON y actualiza también horaUltimoDatoReal. Si pasan TimeoutDatosObsoletos (5 s) o más sin JSON, STATE, STATUS y TRANSACTION responden False con 'Datos obsoletos'. En ese caso, si hubo tráfico en los últimos 10 s, el Bridge encola un TRACE cada AutoKickIntervaloSeg (3 s) para forzar que el driver vuelva a enviar JSON.
- **Peticiones:** Del Bridge al driver va '<folio>\|DISPENSERS\|<CMD>\|<p1>\|...\|<pn>'. El folio es cíclico de 1 a 999 y empieza en 1 en cada arranque del Bridge; el folio 0 es '0\|DISPENSERS\|NOTHING'. La petición es el texto original de OpenGas sin SOH, STX, ETX, CRC ni ETB y sin '\|' al inicio ni al final; la cabecera puede ser DISPENSERSX. El comando de un byte llega como '<folio>\|DISPENSERS\|0' o '\|1'. El driver toma el campo 1 como folio, el campo 3 como comando y vuelve a unir con '\|' los campos 4..N como parámetros. Solo hay una petición en vuelo; la siguiente se envía cuando llega el resultado o cuando expira TimeoutRespSrv (2 s por defecto, contados desde el envío con SecondsBetween y un timer de 500 ms, así que el efecto real es de 2.0 a 2.5 s). El driver no responde en línea: agrega {Folio, Resultado} a rootJSON.Peticiones (máximo 2, en orden FIFO) y el resultado viaja en su siguiente envío. Del Bridge a OpenGas va 'DISPENSERS\|<CMD>\|' más el Resultado, o el Resultado solo si el comando es '1'. Va enmarcado en SOH STX ... ETX CRC16 ETB cuando la longitud es mayor que 1. Resultado = 'True\|<datos>\|' o 'False\|<mensaje>\|'. Los comandos asíncronos devuelven un boleto: 'True\|<FolioCmnd>\|'.
- **Reconexión:** En el driver, OnDisconnect pone conectado en False, apaga Timer1 (se detiene el sondeo serial) y enciende Timer2. Timer2Timer activa el socket y espera con Sleep, cosa inútil cuando el socket vive en el mismo hilo. Reintenta en el siguiente tick y, al enviar con estado mayor que 0, vuelve a encender Timer1; Triton no lo hace y queda muerto. Wayne 2W y Bennett además se desconectan solos si pasan 2 s sin respuesta del Bridge. No hay OnError, así que los fallos de conexión terminan como excepciones en el visor de eventos. En el Bridge no hay OnClientConnect, OnClientDisconnect ni OnClientError. La cola sobrevive a la desconexión y la petición en vuelo expira por timeout; los resultados tardíos se ignoran sin registrarse. El puerto de OpenGas se abre con el primer mensaje del driver y se cierra si llega un comando de OpenGas con 10 s o más sin tráfico del driver.
- **Comandos:**
  - STATE, STATUS [pos] y TRANSACTION pos: los responde el Bridge desde el snapshot y nunca llegan al driver. Los manejadores de Team para estos comandos no se alcanzan.
  - PRICES, AUTHORIZE y PAYMENT: el Bridge responde 'True\|0\|' en el acto y los encola con CliSock=nil; descarta el resultado real del driver.
  - INITIALIZE '{json}\|variables(CRLF)', PARAMETERS, RUN, HALT, TERMINATE, SHUTDOWN, LOGIN, LOGOUT, STOP, START, SELFSERVICE, FULLSERVICE, BLOCK, UNBLOCK, TOTALS, TRACE, SAVELOGREQ, RESPCMND folio, LOG n y LOGREQ n: se encolan y esperan el resultado por folio.
  - TRACE: cuando lo envía OpenGas, además guarda los logs del Bridge. El Bridge genera un TRACE interno (auto-kick) si los datos están obsoletos y el driver sigue vivo.
  - NOTHING: relleno del Bridge cuando la cola está vacía (folio 0). Siete drivers lo registran como resultado {0, 'True\|'}; Triton no lo maneja.
  - '0'/'1' (mensaje de un byte de OpenGas): se encola como 'DISPENSERS\|0' o 'DISPENSERS\|1' con Comando='1'. Solo Wayne y PAM lo implementan: pausan o reanudan el sondeo serial.
  - Comandos con boleto: AUTHORIZE, STOP, START, PAYMENT, PRICES y TOTALS solo se registran en TabCmnd. El resultado del dispensario se consulta con RESPCMND <FolioCmnd>, que responde 'True\|<datos>' u 'OK...', o 'False\|*\|' mientras no hay respuesta.
  - LOGIN devuelve un Token MD5 que ningún comando valida.
- **Campos JSON:**
  - Estado (número): -1 sin inicializar, 0 inicializado o detenido, 1 en ejecución. Solo lo usa STATE.
  - PosCarga[] (lista): el orden es libre; el Bridge indexa por DispenserId (desde 87d3f6d).
  - PosCarga[].DispenserId (entero, obligatorio): STATUS ignora el objeto si falta y TRANSACTION lanza una excepción.
  - PosCarga[].Estatus (número de un dígito, de 0 a 9): el contrato implícito usa códigos externos (0 sin comunicación, 1 inactivo, 2 despachando, 3 fin de venta, 5 pistola levantada, 7 deshabilitado, 8 detenido, 9 autorizado), pero 5 drivers publican el código interno.
  - PosCarga[].HoraOcc (cadena 'yyyy-mm-ddThh:nn', con resolución de minuto).
  - PosCarga[].Manguera, PosCarga[].Combustible (enteros).
  - PosCarga[].Volumen (flotante; el Bridge lo formatea 0.000), PosCarga[].Precio y PosCarga[].Importe (flotantes; 0.00).
  - PosCarga[].Hoses[] {HoseId, ProductId, Total}: todos los drivers lo envían y el Bridge no lo lee.
  - Peticiones[] {Folio: entero, Resultado: cadena}: máximo 2 elementos; Folio 0 es el registro que deja NOTHING.
- **Desviaciones respecto a otros drivers:**
  - Estatus: Bennett (L1369), HongYang (L1827) y Team (L1920) publican el código externo, con 7 para bloqueado. Gilbarco (L3000), Wayne 2W (L2775), Wayne (L1018), PAM (L877) y Triton (L1261) publican el código interno crudo.
  - NOTHING: siete drivers registran {Folio:0, 'True\|'}. Triton no tiene NOTHING_e, así que el relleno nunca activa respJson.
  - Comando desconocido: todos responden 'False\|Comando desconocido\|' salvo Triton, que no tiene rama else, no responde nada y provoca un timeout en el Bridge.
  - START no existe en HongYang (lo trata como desconocido) ni en Triton (no responde). STOP no existe en HongYang.
  - '0'/'1': solo Wayne (L2781-2804) y PAM (L386-410) lo implementan; responden Resultado '1' y envían el JSON en el momento. Los demás responden 'Comando desconocido'. Kairos responde '1' sin trama, directo a OpenGas.
  - Envío extra dentro del manejador del socket: Iniciar en Wayne 2W (L3701) y Bennett (L1918); '0'/'1' en Wayne (L2792, L2799) y PAM (L398, L405).
  - Cadencia de envío: Team 750 ms fijos, PAM cada tick, HongYang con un 'solo al cambiar' que no funciona, Triton solo cuando hay respuesta serial, y Wayne 2W y Gilbarco cada tres ticks.
  - Vigilancia de 2 s sobre la respuesta del Bridge: solo Wayne 2W (L2633) y Bennett (L2086).
  - SetEstadoJSON al hacer INITIALIZE: solo Team (L697) y PAM (L2723). Wayne 2W, Wayne, HongYang, Triton y Bennett dejan Estado en -1 hasta RUN.
  - AUTHORIZE: todos devuelven 'True\|<FolioCmnd>\|' salvo Triton, que devuelve 'True\|' (L807) y escribe al serial desde el manejador del socket.
  - PRICES: Triton ejecuta el serial con Sleep(100) por producto dentro de ClientSocket1Read. Los demás lo encolan como CPREC.
  - PARAMETERS: solo Bennett lo interpreta (CounterToPaySale, L2561-2576). Los demás responden 'True\|' sin leerlo.
  - ResultadoComando: Team (L3008), Gilbarco (L956) y Kairos (L911) solo revisan 40 entradas. Los demás revisan 200.
  - ApplyTotalLitrosToJSON: Wayne (L2268) y Gilbarco (L3329) buscan la posición por índice (xpos-1). Wayne 2W, Bennett y Team la buscan por DispenserId.
  - Errores en Responder: Wayne 2W y Bennett cierran el socket y reconectan; HongYang relanza la excepción (L464); los demás solo registran el error.
  - Hilo del socket: Bennett y Kairos atienden el socket en el hilo del servicio; los demás en el hilo principal.
  - Team implementa TRANSACTION y STATUS en el driver (L445-448), pero vía Bridge nunca se ejecutan.
  - Kairos no usa el Bridge: abre su propio servidor en 1001. Para Kairos, DISPENSERSX significa comandos extendidos sin trama (EJECCMND, FLUSTD, FLUMIN, RESPCMND); LOG y LOGREQ salen sin trama; FULLSERVICE deja el modo en 'Prepago'.
  - Algunos resultados no llevan '\|' al final: Triton L811 y Bennett GuardarLog L1966.
  - PAM con modoAuto y jsonInitialize se inicializa y arranca solo al iniciar el servicio (folio 0). Wayne con ReinicioDiario ejecuta Detener, Terminar y Shutdown (folio 0) y termina el servicio.

### Bloques duplicados con otros módulos

| Rutina | Líneas | Nota |
|---|---|---|
| ClientSocket1Read (despacho de comandos que vienen del Bridge) | UIGASWAYNE2W 3951-4064; UIGASBENNETT 320-407; UIGASGILBARCO 3114-3228; UIGASHONGYANG 316-400; UIGASPAM 369-483; UIGASTEAM 391-480; UIGASTRITON 386-488; UIGASWAYNE 2764-2901 | En todas las copias se repite lo mismo: separar folio, comando y parámetros por '\|', GetEnumValue sobre TMetodos, un case con 20 a 27 ramas y la asignación de socketResponse. Divergen en: NOTHING, START y STOP (Triton y HongYang), la rama else (Triton), el comando '0'/'1' (Wayne y PAM), y que en el except PAM agrega un resultado y HongYang relanza la excepción. |
| Timer2Timer (reconexión y envío de PING o JSON) | UIGASWAYNE2W 3892-3933; UIGASBENNETT 575-615; UIGASGILBARCO 3071-3112; UIGASHONGYANG 2025-2059; UIGASPAM 319-353; UIGASTEAM 354-389; UIGASTRITON 330-365; UIGASWAYNE 2917-2952 | Activan el socket, esperan con Sleep, envían PING o el JSON según respJson y alternan entre Timer1 y Timer2. Divergen en: Sleep(500) previo (solo Wayne 2W y Bennett), la condición del finally (Triton está mal) y la condición pSerial.Open (Wayne y PAM). |
| Responder | UIGASWAYNE2W 534-557; UIGASBENNETT 409-436; UIGASGILBARCO 411-430; UIGASHONGYANG 450-467; UIGASPAM 485-502; UIGASTEAM 482-499; UIGASTRITON 367-384; UIGASWAYNE 2954-2971 | Mandan el texto por socketResponse o por ClientSocket1.Socket y lo registran. Ante errores hay tres comportamientos: reconectar, solo registrar o relanzar la excepción. |
| AddPeticionJSON | UIGASWAYNE2W 3264-3297; UIGASBENNETT 438-471; UIGASGILBARCO 3280-3313; UIGASHONGYANG 2807-2840; UIGASPAM 563-596; UIGASTEAM 535-564; UIGASTRITON 281-314; UIGASWAYNE 2218-2251 | Copias casi idénticas: crean Peticiones si no existe, conservan como máximo 2 elementos, agregan {Folio, Resultado} y ponen respJson en True. Team traga las excepciones sin registrarlas. |
| ActualizaCampoJSON / SetEstadoJSON / ApplyTotalLitrosToJSON | ActualizaCampoJSON: UIGASWAYNE2W 3215-3262, UIGASBENNETT 473-518, UIGASGILBARCO 3230-3278, UIGASHONGYANG 2758-2805, UIGASPAM 504-548, UIGASTEAM 501-533, UIGASTRITON 1323-1371, UIGASWAYNE 2169-2216. SetEstadoJSON: UIGASWAYNE2W 3828-3838, UIGASBENNETT 563-573, UIGASGILBARCO 3351-3361, UIGASHONGYANG 2842-2854, UIGASPAM 550-561, UIGASTEAM 566-577, UIGASTRITON 192-202, UIGASWAYNE 2701-2711. ApplyTotalLitrosToJSON: UIGASWAYNE2W 3299-3340, UIGASBENNETT 520-561, UIGASGILBARCO 3315-3349, UIGASTEAM 579-617, UIGASWAYNE 2253-2290 | Son los helpers que mutan el snapshot y difieren en detalles. Unos comprueban que rootJSON no sea nil y otros no. ApplyTotalLitrosToJSON busca la posición por índice en Wayne y Gilbarco y por DispenserId en los demás. Solo Gilbarco avisa cuando falta un campo. |
| AgregaLog / AgregaLogPetRes (sustitución de caracteres de control) | UIGASWAYNE2W 459-511; UIGASGILBARCO 355-409; UIGASHONGYANG 416-434; UIGASTRITON 204-261; UIGASBENNETT 617-655; UIGASKAIROS 593-631; también en PAM, Team, Wayne y en el Bridge (AgregaLogOG 439-457) | El mismo bucle que concatena carácter por carácter y el mismo tope de 10 000 líneas. Wayne 2W tiene un except que se llama a sí mismo (recursión). |
| EjecutaComando / ResultadoComando / RespuestaComando (tabla de comandos asíncronos) | UIGASWAYNE2W 981-1076 y 3800-3826; UIGASBENNETT 1765-1810 y 2117-2140; UIGASGILBARCO 772-960; UIGASTEAM 2234-2265, 3004-3010 y 1343-1365; UIGASKAIROS 846-914; UIGASPAM 2036-2060 y 2488-2581; UIGASHONGYANG 1143-1180 y 2452-2545; UIGASTRITON 819-850 y 993-1040; UIGASWAYNE 885-940 y 2673-2699 | Todas usan TabCmnd[1..200] con Respuesta string[80], el mismo bucle que se sale del arreglo y respuestas que empiezan con 'OK'. ResultadoComando revisa 1..40 en Team, Gilbarco y Kairos, y 1..200 en los demás. |
| Aviso de datos obsoletos en el Bridge | UIGASBRIDGE 590-598, 625-633, 708-716 | El mismo bloque copiado tres veces (STATE, STATUS y TRANSACTION): registra una sola vez y devuelve 'False\|Datos obsoletos...'. |
| Parseo de trama SOH/STX/ETX y CRC16 | UIGASBRIDGE 301-337 y 459-471; UIGASKAIROS 481-519 y 646-660 | Extraen la trama de OpenGas y calculan el CRC16 de la misma forma, con las mismas debilidades ante tramas pegadas. |
| uLkJSON.pas y UVersionModulo.pas | IgasDispensarios/uLkJSON.pas 1-2626 y IgasDispensariosBridge/uLkJSON.pas 1-2626; UVersionModulo.pas 1-131 en ambos repositorios | Copias idénticas (verificado con diff) en los dos repositorios, sin un mecanismo que las mantenga sincronizadas. Conviene un submódulo o una carpeta compartida junto con la futura unidad común de protocolo. |

## Hallazgos (44)

<a id="E2E-01"></a>
#### E2E-01 · 🔴 Crítica · protocolo · bug — Confirmación inmediata falsa de PRICES/AUTHORIZE/PAYMENT (fire-and-forget) y descarte del resultado real

- **Ubicación:** `IgasDispensariosBridge/UIGASBRIDGE.pas` líneas 372-389, 409-412, 415-437, 842-847, 875-890
- **Módulos afectados:** UIGASBRIDGE.pas, UIGASWAYNE2W.pas, UIGASWAYNE.pas, UIGASBENNETT.pas, UIGASGILBARCO.pas, UIGASHONGYANG.pas, UIGASPAM.pas, UIGASTEAM.pas, UIGASTRITON.pas
- **Se atiende en:** [E5.2](../PLAN_OPTIMIZACION.md#e52--confirmación-real-de-prices-authorize-y-payment)
- **Verificación:** sin verificación independiente
- **Qué pasa:** AddPeticion encola PRICES, AUTHORIZE y PAYMENT con CliSock=nil y responde 'DISPENSERS|<CMD>|True|0|' antes de que el comando llegue al driver. Desde ese momento todo fallo es silencioso: (1) si el driver rechaza el comando ('False|Posicion no Existe|', 'False|Favor de indicar la cantidad...|', o 'False|No fue posible aplicar comando de cambio de precios|' cuando EjecutaComando devuelve 0 porque la tabla está llena), ProcesaRespuestasJSON descarta el resultado porque CliSock es nil; (2) TimerTimeoutTimer expira la petición sin avisar a nadie; (3) CancelarPeticiones la borra sin aviso, ya sea porque el driver lleva 10 s o más sin actividad o porque se detuvo el Bridge; (4) un re-INITIALIZE en el driver (LiberaInicializacion) limpia TabCmnd y pierde el OCC, FINV o CPREC que ya se confirmó; (5) se pierde por concatenación TCP (ver el hallazgo de framing). Además, el 'True|0|' sustituye el boleto real 'True|<FolioCmnd>|' que devuelve el driver, así que OpenGas no puede consultar con RESPCMND si el AUTHORIZE o el PAYMENT se aplicaron.
- **Evidencia:** L372-375: 'if metodoEnum in [PRICES_e, AUTHORIZE_e, PAYMENT_e] then p.CliSock:=nil'. L384-389: ResponderOG('DISPENSERS|PRICES|True|0|', socket) y equivalentes. L842: 'if Assigned(p.CliSock) then' no tiene rama else ni registro. L409-412: CancelarPeticiones('Pdispensarios sin actividad') se ejecuta después de haber respondido True. L427: CancelarPeticiones solo notifica si CliSock está asignado. Driver: UIGASWAYNE2W.pas L3381 'AddPeticionJSON(folio,'True|'+IntToStr(EjecutaComando(cmd+...))+'|')' y L3587-3590.
- **Impacto:** Un cambio de precio puede quedar confirmado sin aplicarse en el dispensario: el POS registra el precio nuevo y la bomba sigue vendiendo al anterior, lo que da un cobro incorrecto y un problema fiscal. Un AUTHORIZE confirmado pero no ejecutado deja al cliente de prepago sin despacho. Un PAYMENT confirmado pero no aplicado deja la venta abierta (Wayne 2W mantiene SwTransAbierta y Sale End; Bennett espera FINV), lo que puede bloquear la siguiente venta.
- **Recomendación:** Etapa 3, compatible: conservar el socket (CliSock) solo para registrar; registrar cada fallo de un comando ya confirmado como 'FALLO-POST-CONFIRMACION [folio] cmd: Resultado' y emitir una alerta. Etapa 4: publicar en el JSON, por posición, 'UltimoComando' {Folio, Cmd, Estado: Pendiente|Aplicado|Rechazado, Detalle} y 'PreciosVigentes' leídos del dispensario, para que el Bridge u OpenGas detecten discrepancias. Etapa 5: parámetro de ini ConfirmacionInmediata por comando; con No, responder a OpenGas solo cuando llegue el resultado del driver (con timeout propio) y devolver el FolioCmnd real. Validar con un simulador de driver que responda False, que no responda y que se desconecte justo después de recibir el comando.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** sí

<a id="E2E-02"></a>
#### E2E-02 · 🔴 Crítica · robustez · bug — Triton se queda sin sondeo y sin comunicación para siempre después de cualquier desconexión del Bridge mientras el servicio corre

- **Ubicación:** `IgasDispensarios/UIGASTRITON.pas` líneas 316-328, 330-365
- **Módulos afectados:** UIGASTRITON.pas
- **Se atiende en:** [E1.1](../PLAN_OPTIMIZACION.md#e11--triton-recuperar-el-sondeo-tras-perder-el-bridge-y-atender-nothingstart)
- **Verificación:** sin verificación independiente
- **Qué pasa:** ClientSocket1Disconnect apaga Timer1 y enciende Timer2. Timer2Timer hace ClientSocket1.Active:=True y espera 'conectado' con 101 llamadas a Sleep(10). El socket se activó desde Timer2Timer, en el hilo principal, así que OnConnect se encola en ese mismo hilo y no puede ejecutarse durante el Sleep: el primer intento siempre sale por 'if not conectado then Exit'. Después, el finally ejecuta Timer2.Enabled:=estado<=0, que con estado=1 deja Timer2 apagado. Cuando por fin llega OnConnect, solo pone conectado:=True. Timer1 y Timer2 quedan apagados: no se sondea el dispensario y no se envía JSON, porque Triton solo envía desde pSerialTriggerAvail (L1231) y ya no salen comandos seriales.
- **Evidencia:** L363: 'Timer2.Enabled:=estado<=0;' (los demás drivers usan '(not conectado) or (estado<=0)'). L326-327: 'Timer1.Enabled:=False; Timer2.Enabled:=True;'. L316-320: ClientSocket1Connect solo asigna conectado. L340-344: bucle de espera con Sleep, sin bombear mensajes.
- **Impacto:** Un reinicio del Bridge o una caída breve del socket deja el dispensario Triton sin control hasta que alguien reinicie PDISPENSARIOS: no se autorizan ventas ni se leen fines de venta. OpenGas ve datos obsoletos y a los 10 s el Bridge le cierra el puerto 1001.
- **Recomendación:** Etapa 1: cambiar el finally a 'Timer2.Enabled:=(not conectado) or (estado<=0)', y que el siguiente tick, ya conectado, apague Timer2 y encienda Timer1 como hacen Wayne 2W y Team. Para probarlo: con el driver en RUN, detener y arrancar el servicio Bridge y verificar en LogDisp que el sondeo 'ST' se reanuda y que el Bridge recibe JSON en menos de 2 s.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="E2E-03"></a>
#### E2E-03 · 🟠 Alta · protocolo · bug — TCP sin delimitación de mensajes: la concatenación o la fragmentación corrompen comandos, pierden respuestas y pueden reemplazar el snapshot

- **Ubicación:** `IgasDispensariosBridge/UIGASBRIDGE.pas` líneas 287-318, 745-774, 785-814
- **Módulos afectados:** UIGASBRIDGE.pas, UIGASWAYNE2W.pas, UIGASWAYNE.pas, UIGASBENNETT.pas, UIGASGILBARCO.pas, UIGASHONGYANG.pas, UIGASPAM.pas, UIGASTEAM.pas, UIGASTRITON.pas
- **Se atiende en:** [E6.1](../PLAN_OPTIMIZACION.md#e61--framing-y-buffer-por-conexión-en-los-dos-sentidos-y-del-lado-de-opengas)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  Los dos lados tratan cada ReceiveText como exactamente un mensaje.
  - Del Bridge al driver: las respuestas no llevan terminador. Si llegan dos juntas ('12|DISPENSERS|AUTHORIZE|1|1|100||0' seguido de '0|DISPENSERS|NOTHING'), el driver toma folio 12 y comando AUTHORIZE, y pega el resto a los parámetros. El último parámetro queda como '00', lo que invierte el fin de venta (finv) en AutorizarVenta, y la segunda petición se pierde. Si era un comando con espera, expira a los 2 s; si era de confirmación inmediata, OpenGas ya recibió True. Esto pasa cuando el driver envía dos mensajes seguidos (Iniciar en Wayne 2W L3701 y Bennett L1918; '0'/'1' en PAM L398/L405 y Wayne L2792/L2799) y su hilo principal está ocupado (Sleep, E/S serial). Un INITIALIZE grande también puede llegar partido: falla el parseo y el resto se procesa como un mensaje con folio 0.
  - Del driver al Bridge: dos JSON pegados se parsean como uno, porque TlkJSON.ParseText ignora lo que sobra (uLkJSON L2030), y solo sale una respuesta. Un JSON partido da nil: se conserva el snapshot, pero el Bridge responde igual, con lo que genera una respuesta de más. El segundo fragmento puede parsearse como número o cadena y reemplazar rootJSON (ver el hallazgo de validación).
  - De OpenGas al Bridge: dos tramas pegadas se reducen a una, desde el primer STX hasta el último ETX; el CRC no coincide y se rechazan ambas. Un '0'/'1' pegado a otra trama no se detecta (L291 exige Length=1).
- **Evidencia:** Bridge L753 'respTxt := Socket.ReceiveText'; L762 'Socket.SendText(IntToStr(p.Folio)+'|'+p.Peticion)' sin terminador; L767 'SendText('0|DISPENSERS|NOTHING')'; L301-313 extracción por primer STX y último ETX. Drivers: UIGASWAYNE2W.pas L3960-3974 (ReceiveText; folio en el campo 1, comando en el 3, parámetros en los campos 4..N). El mismo patrón está en Bennett L329-342, Gilbarco L3121-3137, HongYang L324-337, PAM L378-418, Team L399-412, Triton L394-408 y Wayne L2772-2812.
- **Impacto:** Comandos ejecutados con parámetros corruptos, comandos perdidos, timeouts espurios y snapshots inválidos. Son fallas intermitentes y muy difíciles de reproducir.
- **Recomendación:** Etapas 4-5: framing en los dos sentidos, compatible con lo actual. (a) Del Bridge al driver: terminar cada respuesta con ETX (#3), pero solo si el driver anunció que lo soporta (HELLO o 'Proto':2 en el JSON); el driver nuevo acumula en un buffer y extrae mensajes completos. (b) Del driver al Bridge: prefijo con la longitud o terminador ETX, con un buffer acumulador por socket en el Bridge (en Socket.Data). (c) De OpenGas al Bridge: acumular por socket y extraer en bucle las tramas SOH..ETB completas. Probar con un cliente que mande los mensajes partidos byte a byte y otro que los mande pegados.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** sí

<a id="E2E-04"></a>
#### E2E-04 · 🟠 Alta · protocolo · bug — TRANSACTION se responde desde el snapshot sin identidad de venta: hay una ventana en la que Estatus=3 convive con importes que no son finales

- **Ubicación:** `IgasDispensariosBridge/UIGASBRIDGE.pas` líneas 692-735
- **Módulos afectados:** UIGASBRIDGE.pas, UIGASGILBARCO.pas, UIGASPAM.pas, UIGASTRITON.pas, UIGASWAYNE2W.pas, UIGASWAYNE.pas
- **Se atiende en:** [E1.9](../PLAN_OPTIMIZACION.md#e19--coherencia-del-estado-publicado-estatus-fin-de-venta-horaocc-estado), [E5.1](../PLAN_OPTIMIZACION.md#e51--semántica-única-de-estatus-y-campos-de-venta)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El Bridge devuelve HoraOcc, Manguera, Combustible, Volumen, Precio e Importe del objeto PosCarga tal como vinieron en el último JSON. No hay número de venta, ni bandera de lectura final, ni secuencia, y HoraOcc solo tiene resolución de minuto. Wayne 2W (con SwLecturaFinalPendiente, L2772-2775 y L2808-2809) y Wayne (con swcargando, L1015-1018) mantienen Estatus=2 hasta tener la lectura final. Gilbarco, en cambio, publica Estatus=3 en NumPaso 1 (EstatusDispensarios L2615 y luego L3000) y lee la venta final en NumPaso 2 del tick siguiente (SwLeeVenta L2862-2866; DameLecturas L2654-2700). Si el JSON se envía entre esos dos pasos, lo que pasa en uno de cada tres ticks, el snapshot muestra Estatus 3 con el importe de la última lectura en proceso o con el de la venta anterior. PAM y Triton publican el estatus crudo y no se verificó en qué orden leen. La certeza sobre la frecuencia en campo es media, porque depende de cuándo consulta OpenGas; si se confirma, es crítico.
- **Evidencia:** Bridge L728-730 arma la respuesta directamente con posObj.Field[...]. UIGASGILBARCO.pas L2615 'EstatusDispensarios;' en NumPaso 1; L2862-2866 'if NumPaso = 1 then begin SwLeeVenta := true'; L3000 'ActualizaCampoJSON(xpos, 'Estatus', estatus)' sin considerar swcargando, mientras que su propio mapeo de siempre (L2967-2971) reporta 2 si swcargando está activo.
- **Impacto:** OpenGas puede cobrar un importe parcial o el de la venta anterior si consulta TRANSACTION justo al ver Estatus 3.
- **Recomendación:** Etapa 2, sin cambiar el contrato: aplicar en todos los drivers la misma regla de publicar Estatus=3 solo después de actualizar Volumen, Precio, Importe y HoraOcc finales (el patrón SwLecturaFinalPendiente de Wayne 2W). Etapa 4, con campos nuevos: agregar por posición 'VentaId' (contador que sube al empezar a despachar), 'VentaFinal' (booleano) y HoraOcc con segundos. El Bridge solo responde True a TRANSACTION si VentaFinal es true, y opcionalmente agrega VentaId al final de la respuesta. Probar en emulación forzando el envío de JSON en cada tick y verificando que nunca aparezca Estatus 3 con VentaFinal en false.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** sí

<a id="E2E-05"></a>
#### E2E-05 · 🟠 Alta · robustez · bug — El sondeo serial se detiene cuando se pierde o se retrasa el Bridge (acoplamiento más el watchdog de 2 s)

- **Ubicación:** `IgasDispensarios/UIGASWAYNE2W.pas` líneas 2633-2638, 3892-3933, 3942-3949
- **Módulos afectados:** UIGASWAYNE2W.pas, UIGASBENNETT.pas, UIGASGILBARCO.pas, UIGASHONGYANG.pas, UIGASPAM.pas, UIGASTEAM.pas, UIGASTRITON.pas, UIGASWAYNE.pas
- **Se atiende en:** [E2.1](../PLAN_OPTIMIZACION.md#e21--desacoplar-timer1-sondeo-serial-de-la-conexión-con-el-bridge)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Todos los drivers apagan Timer1, que es el ciclo serial, en ClientSocket1Disconnect, y solo lo vuelven a encender cuando Timer2 logra reconectar y enviar. Wayne 2W y Bennett además se desconectan solos si pasan 2 s sin respuesta del Bridge (horaAct). Eso ocurre cuando el Bridge está ocupado guardando un log grande (ver el hallazgo de bitácoras) o cuando la cadencia de envío del propio driver supera 2 s: tres ticks de Timer1 con reintentos seriales de GtwTimeout (300 ms) por GtwIntentos en posiciones que no responden. Mientras tanto no se leen fines de venta, no se vigila el preset excedido (DetenerPresetExcedido), no se manda Sale End y no se aplican cambios de precio. En Wayne 2W y Bennett cada intento de reconexión bloquea el hilo principal 1.5 s (Sleep(500) más 101 veces Sleep(10)).
- **Evidencia:** UIGASWAYNE2W.pas L2633-2638: 'if SecondsBetween(Now,horaAct)>=2 then begin conectado:=False; ClientSocket1.Active:=False; Timer1.Enabled:=False; Timer2.Enabled:=True; end'. L3947: 'Timer1.Enabled:=False' en Disconnect. El mismo patrón está en UIGASBENNETT.pas L316 y L2086-2095, UIGASGILBARCO.pas L3067, UIGASHONGYANG.pas L412, UIGASPAM.pas L365, UIGASTEAM.pas L350, UIGASTRITON.pas L326 y UIGASWAYNE.pas L2913.
- **Impacto:** Un reinicio del Bridge, una pausa de disco o un pico de CPU deja los dispensarios sin supervisión. En Wayne 2W se pierde la protección contra presets excedidos y el cierre de transacciones abiertas. Los ciclos de desconexión y reconexión producen timeouts en cascada en OpenGas.
- **Recomendación:** Etapa 2: separar responsabilidades. Timer1 no debe depender de 'conectado'. Disconnect solo marca conectado:=False y deja a Timer2 reconectando, y el envío de JSON se condiciona a conectado (Wayne 2W y Gilbarco ya lo hacen). El watchdog debe dispararse con al menos max(6 s, 3 veces TimeoutRespSrv) sin respuesta y solo cerrar el socket, sin tocar Timer1. Probar en emulación (ModoEmulacion=Si en Wayne 2W) con ventas en curso: detener el Bridge 60 s y comprobar que el sondeo sigue y que, al volver el Bridge, el snapshot refleja el fin de venta.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="E2E-06"></a>
#### E2E-06 · 🟠 Alta · concurrencia · bug — Bennett y Kairos atienden el socket en el hilo del servicio mientras los timers y el serial corren en el hilo principal: carreras reales sin sincronización

- **Ubicación:** `IgasDispensarios/UIGASBENNETT.pas` líneas 256-302, 320-407, 438-471, 1678-1689, 1902-1918, 2083-2115
- **Módulos afectados:** UIGASBENNETT.pas, UIGASKAIROS.pas, UIGASPAM.pas
- **Se atiende en:** [E0.2](../PLAN_OPTIMIZACION.md#e02--identificar-el-hilo-de-cada-evento-instrumentación), [E2.6](../PLAN_OPTIMIZACION.md#e26--bennett-todo-en-un-solo-hilo)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Modelo de hilos, con certeza alta para TTimer y media-alta para ScktComp (hay que verificarlo): los TTimer del .dfm se crean en el hilo principal y sus eventos corren ahí, y ScktComp crea la ventana del socket en el hilo que lo activa. Bennett activa ClientSocket1 en ServiceExecute (L276, en el hilo de TServiceThread) y Kairos activa ServerSocket1 también en ServiceExecute (UIGASKAIROS.pas L397). Por eso ClientSocket1Read y ServerSocket1ClientRead corren en el hilo del servicio, mientras Timer1Timer, Timer2Timer y ProcesaLinea corren en el principal. En Bennett, AddPeticionJSON hace petArr.Delete(0) desde el hilo del servicio mientras ProcesaLinea, en el hilo principal, recorre rootJSON con TlkJSON.GenerateText. EjecutaComando escribe TabCmnd mientras el ciclo serial lo lee. Los dos hilos escriben ListaLogPetRes, socketResponse, conectado y horaAct, y Timer1Timer cierra (Active:=False) un socket que pertenece al otro hilo. Además, RUN ejecuta 'Timer1.Enabled:=True' desde el hilo del servicio; SetTimer exige que la ventana sea del hilo que lo llama, así que podría fallar con EOutOfResources ('Not enough timers available'). Esto no se pudo confirmar sin ejecutar. PAM con modoAuto (L299-302) también llama Iniciar desde ServiceExecute. En los demás drivers no hay concurrencia real sino reentrancia (ver el hallazgo correspondiente). En el Bridge todo corre en el hilo del servicio.
- **Evidencia:** UIGASBENNETT.pas L276 'ClientSocket1.Active:=True' dentro de ServiceExecute; L1680-1681 'Responder(TlkJSON.GenerateText(rootJSON))' en ProcesaLinea; L456-457 'petArr.Delete(0)'; L1913 'Timer1.Enabled:=True' en Iniciar, llamado desde ClientSocket1Read; L2090 'ClientSocket1.Active:=False' en Timer1Timer. UIGASKAIROS.pas L397 'ServerSocket1.Active:=True'; L421-591 lee TPosCarga y TabCmnd, que Timer1Timer (L1516) modifica.
- **Impacto:** Access violations o JSON corrupto de forma intermitente, comandos perdidos o ejecutados dos veces, un RUN que podría fallar, y un TRANSACTION de Kairos con importe y volumen de momentos distintos.
- **Recomendación:** Etapa 0: registrar GetCurrentThreadId en ServiceExecute, Timer1Timer, Timer2Timer, ClientSocket1Read o ServerSocket1ClientRead, y pSerialTriggerAvail, para confirmar el modelo. Etapa 2: en Bennett quitar ClientSocket1.Active:=True de ServiceExecute y dejar que conecte Timer2Timer, como en los demás drivers. En Kairos activar ServerSocket1 desde el hilo principal (un timer de un solo disparo) o pasar las peticiones al hilo principal con PostMessage. En PAM con modoAuto, diferir Inicializar e Iniciar a un timer del hilo principal. No manipular TTimer desde otro hilo.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="E2E-07"></a>
#### E2E-07 · 🟠 Alta · rendimiento · optimizacion — Cola estrictamente serial con bloqueo por la cabeza: un comando sin respuesta detiene a todos los demás de 2 a 2.5 s, y no hay límite, deduplicación ni prioridades

- **Ubicación:** `IgasDispensariosBridge/UIGASBRIDGE.pas` líneas 120-139, 177-201, 347-413, 869-894
- **Módulos afectados:** UIGASBRIDGE.pas
- **Se atiende en:** [E3.4](../PLAN_OPTIMIZACION.md#e34--cola-prioridad-límite-y-deduplicación), [E6.2](../PLAN_OPTIMIZACION.md#e62--push-de-comandos-resultados-inmediatos-y-ack)
- **Verificación:** sin verificación independiente
- **Qué pasa:** TryStartNext solo mira FList[0] y no envía nada si esa petición ya está marcada Enviada; TryPopExpired solo puede expirar la cabeza. Por eso hay como máximo un comando en vuelo, y el throughput es de un comando por cada envío del driver. Si el driver no contesta un comando (Triton no tiene START ni rama else; cualquier excepción antes de AddPeticionJSON deja la petición sin respuesta), toda la cola espera TimeoutRespSrv (de 2.0 a 2.5 s efectivos). La cola no tiene tamaño máximo ni deduplicación: cuando OpenGas reintenta RESPCMND o TOTALS, las peticiones se acumulan. cmdAnt y horaPeticion (L381-382) se siguen asignando pero ya nadie los lee (la deduplicación de 5 ms se quitó en 01e1868). STOP y AUTHORIZE no tienen prioridad sobre TRACE, LOG o RESPCMND.
- **Evidencia:** L126-134: 'if not APeticion.Enviada then ... else APeticion := nil'. L188-196: TryPopExpired solo considera FList[0]. L379: 'ListaPeticiones.Push(p)' sin límite. L381-382: cmdAnt y horaPeticion no tienen lectores.
- **Impacto:** Con carga (corte de turno con TOTALS y RESPCMND por posición, o un comando no soportado), AUTHORIZE y STOP se retrasan varios segundos. OpenGas puede agotar sus propias esperas y reintentar, lo que hace crecer la cola.
- **Recomendación:** Etapa 3, sin cambiar el contrato: límite de cola configurable (por ejemplo, 50) que responda 'False|Cola llena|'; deduplicar peticiones idénticas aún no enviadas y responder a todos los sockets cuando llegue el resultado; dar prioridad a STOP, AUTHORIZE, PAYMENT y PRICES. Etapa 5, en v2: ventana de N comandos en vuelo emparejados por folio, lo que exige que el driver procese varios comandos por mensaje y que Peticiones tenga más capacidad.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** sí

<a id="E2E-08"></a>
#### E2E-08 · 🟠 Alta · rendimiento · optimizacion — Modelo pull: la latencia de cada comando depende de la cadencia de envío de cada driver (1.5 ciclos en promedio, 2 como máximo) y varía mucho entre marcas

- **Ubicación:** `IgasDispensariosBridge/UIGASBRIDGE.pas` líneas 745-774
- **Módulos afectados:** UIGASBRIDGE.pas, UIGASTEAM.pas, UIGASWAYNE2W.pas, UIGASGILBARCO.pas, UIGASHONGYANG.pas, UIGASPAM.pas, UIGASBENNETT.pas, UIGASWAYNE.pas, UIGASTRITON.pas
- **Se atiende en:** [E4.1](../PLAN_OPTIMIZACION.md#e41--responder-al-bridge-en-cuanto-se-procesa-un-comando-y-homologar-la-cadencia), [E6.2](../PLAN_OPTIMIZACION.md#e62--push-de-comandos-resultados-inmediatos-y-ack)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  El Bridge solo puede entregar un comando como respuesta a un mensaje del driver, y el resultado vuelve en el mensaje siguiente. La latencia es la espera al siguiente envío (entre 0 y T), más T, más el procesamiento: 1.5T en promedio, 2T como máximo, y T más por cada comando que haya delante. Cadencia T por driver:
  - Timer2 (estado menor o igual a 0): 200 ms.
  - Team: 750 ms (MsEnvioJSON).
  - PAM: cada tick de 250 ms.
  - Wayne 2W y Gilbarco: cada tres ticks de 50 ms más el tiempo serial de esos ticks (de 0.3 a 2 s cuando hay posiciones sin respuesta).
  - HongYang: unos 50-100 ms.
  - Bennett, Wayne y Triton: después de cada respuesta serial (de 150 a 300 ms). Triton no envía nada si el dispensario no responde, así que sus comandos nunca se entregan.
  El throughput máximo es 1/T: 5 cmd/s en Timer2, 1.3 en Team, unos 4 en PAM, de 0.5 a 3 en Wayne 2W y Gilbarco, y de 10 a 20 en HongYang.
- **Evidencia:** Bridge L760-767: solo responde dentro de SSocketPDispClientRead. UIGASTEAM.pas L15 'MsEnvioJSON=750' y L2368-2371; UIGASWAYNE2W.pas L2959-2960 'xTurnoSocket=3'; UIGASGILBARCO.pas L2913-2914; UIGASHONGYANG.pas L2007-2013; UIGASPAM.pas L2258; UIGASBENNETT.pas L1680-1681; UIGASWAYNE.pas L1386; UIGASTRITON.pas L1226-1231.
- **Impacto:** AUTHORIZE y STOP tardan de 0.3 a 3 s en llegar al driver, más el ciclo serial hasta que se visita la posición. En Wayne 2W y Gilbarco se puede superar TimeoutRespSrv=2 s y devolver 'Timeout' por comandos que sí se ejecutaron.
- **Recomendación:** Etapa 5, push en v2: el Bridge escribe el comando en el socket del driver en cuanto llega de OpenGas (el socket es bidireccional y ClientSocket1Read ya procesa cualquier mensaje entrante), y el driver responde con una trama RES inmediata, independiente del snapshot. Mientras tanto, en la Etapa 2: igualar la cadencia de todos los drivers a 'si cambió, o cada 250 ms' y enviar en cuanto se procese un comando que no sea NOTHING.
- **Esfuerzo:** L · **Riesgo del cambio:** alto · **Toca contrato:** sí

<a id="E2E-09"></a>
#### E2E-09 · 🟠 Alta · protocolo · bug — Un solo timeout de 2 s, medido en segundos enteros e igual para todos los comandos; los resultados tardíos se descartan sin dejar rastro

- **Ubicación:** `IgasDispensariosBridge/UIGASBRIDGE.pas` líneas 177-201, 240-242, 256-259, 839-851, 869-894
- **Módulos afectados:** UIGASBRIDGE.pas
- **Se atiende en:** [E0.3](../PLAN_OPTIMIZACION.md#e03--métricas-y-correlación-de-punta-a-punta-en-el-bridge), [E3.3](../PLAN_OPTIMIZACION.md#e33--timeouts-por-comando-en-milisegundos-y-folios-no-repetibles)
- **Verificación:** sin verificación independiente
- **Qué pasa:** TimeoutRespSrv (del ini, 2 por defecto) se compara con SecondsBetween, que trunca a segundos, dentro de un timer de 500 ms; el timeout efectivo va de 2.0 a 2.5 s. Es el mismo para INITIALIZE, TOTALS, RESPCMND, LOGREQ (que tiene respuestas grandes) y STOP. No cuenta el tiempo en cola, así que la latencia que ve OpenGas puede ser mucho mayor. Si el resultado llega después de expirar, TryPopByFolio no encuentra el folio y se ignora sin registrarlo. OpenGas ya recibió 'False|Timeout excedido...' aunque el comando se ejecutó (STOP, BLOCK, SELFSERVICE, START), y lo normal es que lo reintente.
- **Evidencia:** L191: 'SecondsBetween(Now, Tmp.HoraEnvio) >= TimeoutSeg'. L257: 'TimerTimeout.Interval:=500'. L839: 'if ListaPeticiones.TryPopByFolio(folioResp, p) then', sin rama else ni registro.
- **Impacto:** Respuestas negativas falsas y reintentos que repiten acciones. Además el diagnóstico es confuso, porque el log no muestra la respuesta tardía.
- **Recomendación:** Etapa 3: usar MilliSecondsBetween y timeouts por comando en el ini (TimeoutINITIALIZE, TimeoutTOTALS, etc., con 2000 ms por defecto). Guardar los últimos 50 folios expirados y registrar 'RESULTADO TARDIO [folio] cmd +Xms: Resultado' cuando aparezca uno. Registrar la latencia de cada petición: encolado, envío y resultado.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="E2E-10"></a>
#### E2E-10 · 🟠 Alta · robustez · riesgo — Un INITIALIZE con el servicio en ejecución reinicia todo el driver: cierra el serial, vacía TabCmnd y pone en cero las ventas del snapshot

- **Ubicación:** `IgasDispensarios/UIGASWAYNE2W.pas` líneas 590-657, 807-819, 903-927
- **Módulos afectados:** UIGASWAYNE2W.pas, UIGASHONGYANG.pas, UIGASTRITON.pas, UIGASBENNETT.pas, UIGASGILBARCO.pas, UIGASPAM.pas, UIGASTEAM.pas, UIGASWAYNE.pas
- **Se atiende en:** [E2.7](../PLAN_OPTIMIZACION.md#e27--initialize-idempotente-y-seguro-con-ventas-en-curso)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Desde 6b4f482, Inicializar llama a LiberaInicializacion siempre que estado sea mayor que -1, incluso con estado=1 y ventas en curso. Eso apaga Timer1, cierra los puertos, marca inactivas las 200 entradas de TabCmnd (con los OCC, OCL, FINV, CPREC y TOTAL pendientes que el Bridge ya confirmó a OpenGas) y deja estado=-1. Luego AgregaPosCarga reinicia TPosCarga (importe, volumen, HoraOcc, SwLecturaFinalPendiente, SwTransAbierta) y vacía PosCarga en el JSON. Un TRANSACTION posterior devuelve importe 0 y HoraOcc '1899-12-30T00:00', y el servicio queda detenido hasta que llegue RUN. El mismo patrón está en HongYang (L568-572, L614-640), Triton (L500-503) y los demás drivers tocados por ese commit.
- **Evidencia:** L816-819: 'if estado>-1 then begin ... LiberaInicializacion; end'. L916-920: 'TabCmnd[i].SwActivo:=False; ... CmndNuevo:=False'. L604-619: 'estatus:=0; ... importe:=0; volumen:=0'. L656-657: 'while posArr.Count>0 do posArr.Delete(0)'.
- **Impacto:** Si OpenGas reenvía INITIALIZE al reconectarse (por ejemplo, tras ver STATE en False por datos obsoletos o tras un reinicio del Bridge), se pierden autorizaciones y pagos ya confirmados y la lectura de la venta en curso. Hay riesgo de una venta sin cobrar o cobrada en cero.
- **Recomendación:** Etapa 2: hacer INITIALIZE idempotente. Calcular un MD5 (la función ya existe) del JSON de configuración; si coincide con el vigente y estado es mayor o igual a 0, responder 'True|' sin reiniciar. Si cambió y hay posiciones con Estatus 2, 3 o 9, o comandos pendientes en TabCmnd, responder 'False|Hay ventas en curso, enviar HALT primero|' o aplicar el cambio en caliente sin borrar las ventas. Registrar cada reinicialización con su motivo.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="E2E-11"></a>
#### E2E-11 · 🟠 Alta · memoria_recursos · optimizacion — Bitácoras con el JSON completo (10 000 líneas en memoria) volcadas de forma síncrona en el único hilo: bloqueos de varios segundos y disco que crece sin control

- **Ubicación:** `IgasDispensariosBridge/UIGASBRIDGE.pas` líneas 296-299, 391-398, 737-743, 754, 776-783, 799-803, 861-867
- **Módulos afectados:** UIGASBRIDGE.pas, UIGASWAYNE2W.pas, UIGASBENNETT.pas, UIGASGILBARCO.pas, UIGASHONGYANG.pas, UIGASPAM.pas, UIGASTEAM.pas, UIGASTRITON.pas, UIGASWAYNE.pas
- **Se atiende en:** [E2.4](../PLAN_OPTIMIZACION.md#e24--bitácoras-que-no-bloquean-append-incremental-rotación-y-sin-json-repetido)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Por cada mensaje del driver, el Bridge agrega 'R ' más el JSON completo a ListaLogPDisp, con tope de 10 000 líneas. Con 16 a 32 posiciones, cada JSON pesa de 4 a 10 KB, así que son de 20 a 100 MB en RAM. GuardaLogPDisp escribe la lista entera con SaveToFile en el único hilo del Bridge, y eso ocurre al cumplirse MinutosLog, con cada TRACE de OpenGas, con cada error de parseo (L802) y con cada excepción de lectura (L771). Mientras escribe, no atiende ni a OpenGas ni al driver, y Wayne 2W y Bennett se desconectan solos a los 2 s por su watchdog. Cada guardado crea un archivo nuevo con fecha y hora y nunca se borran los viejos. En los drivers pasa lo mismo con ListaLogPetRes, que guarda 'E ' más el JSON en cada envío de Responder, y con GuardarLog(0), que se llama en muchos caminos de error del hilo principal, el mismo que hace el sondeo serial.
- **Evidencia:** L754: 'AgregaLogPDisp('R '+respTxt)'. L780-781: 'while ListaLogPDisp.Count>10000 do ListaLogPDisp.Delete(0)'. L866: ListaLogPDisp.SaveToFile de toda la lista. UIGASWAYNE2W.pas L544: 'AgregaLogPetRes('E '+resp)'; L3545-3559: GuardarLog guarda LogDisp y LogDispPetRes.
- **Impacto:** Pausas de varios segundos que provocan timeouts, desconexiones del driver y la suspensión del sondeo; consumo alto de memoria; y, a mediano plazo, disco lleno.
- **Recomendación:** Etapas 1-3: registrar el JSON solo cuando cambie (comparándolo con el anterior) o en forma resumida (longitud, Estado, cadena de estatus, folios de Peticiones). Escribir en modo append a un archivo diario con rotación por tamaño, mediante un hilo escritor (TThread más una cola protegida con TCriticalSection), en vez de SaveToFile de toda la lista. Borrar los archivos con más de N días y no volcar logs más de una vez por minuto en los caminos de error repetitivos.
- **Esfuerzo:** M · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="E2E-12"></a>
#### E2E-12 · 🟠 Alta · correccion · bug — ResultadoComando busca solo en las primeras 40 entradas de TabCmnd y EjecutaComando usa 200: RESPCMND nunca encuentra los resultados que caen de la entrada 41 a la 200

- **Ubicación:** `IgasDispensarios/UIGASTEAM.pas` líneas 2234-2265, 3004-3010
- **Módulos afectados:** UIGASTEAM.pas, UIGASGILBARCO.pas, UIGASKAIROS.pas
- **Se atiende en:** [E1.5](../PLAN_OPTIMIZACION.md#e15--tabla-de-comandos-tabcmnd-y-respuestas-de-comandos-asíncronos)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Cada entrada de TabCmnd sigue activa (SwActivo) hasta que se reutiliza, un minuto después. Si en 60 s llegan más de 40 comandos (AUTHORIZE, PAYMENT, STOP, TOTALS, PRICES...), el siguiente se guarda en la entrada 41 o posterior y su resultado ya no se puede consultar: RESPCMND responde 'False|*|' para siempre. En una estación con mucho movimiento, o en el corte de turno con TOTALS por posición más las ventas, es alcanzable. Además el bucle no hace Break y devuelve la última coincidencia.
- **Evidencia:** UIGASTEAM.pas L3008: 'for i:=1 to 40 do'; L2246: 'until (not TabCmnd[ind].SwActivo)or(ind>200)'. UIGASGILBARCO.pas L956: 'for i := 1 to 40 do'. UIGASKAIROS.pas L911: 'for i:=1 to 40 do'. Wayne 2W lo hace bien (L1067-1071, de 1 a 200 con Break).
- **Impacto:** Totales de corte de turno que nunca llegan a OpenGas, y boletos de AUTHORIZE o PAYMENT imposibles de verificar.
- **Recomendación:** Etapa 1: recorrer de 1 a 200 (High(TabCmnd)) con Break, como en Wayne 2W. Probar generando 60 TOTALS en un minuto con el simulador y consultando el RESPCMND del último.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="E2E-13"></a>
#### E2E-13 · 🟠 Alta · protocolo · bug — Triton no atiende NOTHING, START ni comandos desconocidos: sigue enviando PING y bloquea la cola del Bridge

- **Ubicación:** `IgasDispensarios/UIGASTRITON.pas` líneas 386-488
- **Módulos afectados:** UIGASTRITON.pas
- **Se atiende en:** [E1.1](../PLAN_OPTIMIZACION.md#e11--triton-recuperar-el-sondeo-tras-perder-el-bridge-y-atender-nothingstart)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El case de ClientSocket1Read no tiene NOTHING_e, ni START_e, ni rama else. Hay dos consecuencias. (1) NOTHING no llama a AddPeticionJSON, así que las respuestas de relleno nunca ponen respJson en True y Triton manda PING indefinidamente hasta que llega un comando real. El Bridge marca los datos como obsoletos y depende del TRACE automático, que de paso obliga a Triton a escribir dos archivos de log. (2) START y cualquier comando desconocido no generan resultado: el Bridge espera de 2 a 2.5 s por cada uno con la cola bloqueada y luego responde Timeout.
- **Evidencia:** L412-479: el case solo cubre de INITIALIZE_e a LOGREQ_e, sin NOTHING_e, sin START_e y sin else. Comparar con UIGASWAYNE2W.pas L3980-3981 ('NOTHING_e: AddPeticionJSON(folio, 'True|')') y L4052-4053 ('else ... 'False|Comando desconocido|'').
- **Impacto:** Después de cada arranque o reconexión, STATUS y TRANSACTION responden 'Datos obsoletos' hasta que actúa el TRACE automático. START y los comandos no soportados se convierten en timeouts que retrasan todos los demás.
- **Recomendación:** Etapa 1: agregar NOTHING_e (que basta con poner respJson:=True), START_e (que llame a ReanudarVenta si existe, o responda 'False|No soportado|') y una rama else con 'False|Comando desconocido|'.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="E2E-14"></a>
#### E2E-14 · 🟠 Alta · protocolo · bug — Cada driver le da un significado distinto a Estatus: unos publican el código externo (7=bloqueado) y otros el código interno crudo

- **Ubicación:** `IgasDispensarios/UIGASGILBARCO.pas` líneas 2951-3000
- **Módulos afectados:** UIGASGILBARCO.pas, UIGASWAYNE2W.pas, UIGASWAYNE.pas, UIGASPAM.pas, UIGASTRITON.pas, UIGASBRIDGE.pas
- **Se atiende en:** [E5.1](../PLAN_OPTIMIZACION.md#e51--semántica-única-de-estatus-y-campos-de-venta)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El Bridge arma STATUS concatenando PosCarga[].Estatus y supone un dígito por posición según la tabla externa (0 sin comunicación, 1 inactivo, 2 despachando, 3 fin de venta, 5 pistola levantada, 7 deshabilitado, 8 detenido, 9 autorizado). Bennett (L1369), HongYang (L1827) y Team (L1920) publican el código ya traducido. Gilbarco (L3000), Wayne 2W (L2775), Wayne (L1018), PAM (L877) y Triton (L1261) publican el estatus interno. En consecuencia, una posición bloqueada con BLOCK se sigue reportando como 1 en vez de 7; Wayne 2W reporta 4 donde su propio mapeo de siempre (L1470) daría 3; y Gilbarco reporta 3 con swcargando activo, cuando su mapeo de siempre (L2967-2971) daría 2. La función que traduce (EstatusDispensarios) se sigue calculando pero ya no se publica. Si algún valor tuviera más de un dígito, AEstados[xpos] desalinearía todas las posiciones.
- **Evidencia:** UIGASGILBARCO.pas L2958-2988 calcula xestado con '7' para SwDesHabil, pero L3000 publica 'ActualizaCampoJSON(xpos, 'Estatus', estatus)'. UIGASBENNETT.pas L1369: 'ActualizaCampoJSON(xpos, 'Estatus', Copy(xestado,xpos,1))'. Bridge L669: 'estadosPorPosicion[idPos] := Trim(estadoNode.Value)'; L680: 'AEstados[xpos]'.
- **Impacto:** OpenGas puede intentar autorizar posiciones bloqueadas o mostrar estados que no están en su tabla, y con el mismo OpenGas cada marca se comporta distinto.
- **Recomendación:** Etapa 2: fijar la tabla externa en el contrato y que cada driver publique en Estatus solo el código externo, reutilizando su EstatusDispensarios; para diagnóstico se puede agregar 'EstatusInterno'. Etapa 3: que el Bridge valide el rango de 0 a 9 y registre los valores que estén fuera de la tabla.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="E2E-15"></a>
#### E2E-15 · 🟠 Alta · correccion · bug — Las respuestas de los comandos asíncronos se truncan a 80 caracteres (RegCmnd.Respuesta: string[80]) y los totales de tres mangueras pueden quedar cortados

- **Ubicación:** `IgasDispensarios/UIGASWAYNE2W.pas` líneas 231-239, 2367-2408
- **Módulos afectados:** UIGASWAYNE2W.pas, UIGASGILBARCO.pas, UIGASBENNETT.pas, UIGASTEAM.pas, UIGASPAM.pas, UIGASHONGYANG.pas, UIGASKAIROS.pas, UIGASWAYNE.pas
- **Se atiende en:** [E1.5](../PLAN_OPTIMIZACION.md#e15--tabla-de-comandos-tabcmnd-y-respuestas-de-comandos-asíncronos)
- **Verificación:** sin verificación independiente
- **Qué pasa:** En todos los drivers, TabCmnd guarda la respuesta en un ShortString de 80 bytes y la asignación trunca sin avisar. La respuesta de TOTAL se arma como 'OK'+litros1+'|'+importe1+'|'+litros2+'|'+importe2+'|'+litros3+'|'+importe3, y Gilbarco además agrega un '|' al final. Con totalizadores de 7 dígitos (1234567.890) e importes con separador de miles se pasa de 80 caracteres, y se pierde el final del importe de la tercera manguera, que OpenGas recibe vía RESPCMND como si fuera un dato válido. El formato exacto de FormatoMoneda (en ULIBGRAL) no está en el repositorio, así que la certeza es media.
- **Evidencia:** L238: 'Respuesta :string[80]'. L2383-2385: 'rsp:='OK'+FormatFloat('0.000',ToTalLitros[1])+'|'+FormatoMoneda(...)'. L2408: 'TabCmnd[xcmnd].Respuesta:=rsp'. Igual en UIGASGILBARCO.pas L202 y L2394, UIGASBENNETT.pas L193 y L1646, UIGASTEAM.pas L242 y L2142, UIGASPAM.pas L211 y L1657, UIGASHONGYANG.pas L201 y L2248, UIGASKAIROS.pas L201 y L2452, y UIGASWAYNE.pas L231 y L1798.
- **Impacto:** Totales de corte de turno erróneos sin ninguna señal de error.
- **Recomendación:** Etapa 1: medir primero, registrando en el log cuando length(rsp) supere 80. Después cambiar Respuesta y Comando a string (AnsiString) en RegCmnd, verificando antes que el record no se guarda en binario en ningún lado, o al menos a string[255]. Etapa 4: servir TOTALS desde Hoses[].Total del snapshot, con su hora de lectura.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="E2E-16"></a>
#### E2E-16 · 🟠 Alta · robustez · bug — El Bridge cierra el puerto de OpenGas desde su propio manejador de lectura cuando el driver lleva 10 s sin tráfico, y no reacciona cuando el driver se desconecta

- **Ubicación:** `IgasDispensariosBridge/UIGASBRIDGE.pas` líneas 409-412, 755-756, 230-277
- **Módulos afectados:** UIGASBRIDGE.pas
- **Se atiende en:** [E3.1](../PLAN_OPTIMIZACION.md#e31--disponibilidad-puerto-1001-siempre-activo-y-driver-caído-detectado)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Al final de AddPeticion, incluso para STATE y STATUS que ya se respondieron, si SecondsBetween(Now, horaAct) es de 10 o más se cancelan todas las peticiones y se ejecuta SSocketOG.Active:=False. Eso cierra todas las conexiones de OpenGas, incluida la del socket cuyo OnRead se está ejecutando en ese momento: el objeto se libera dentro de su propio evento, con riesgo de uso de memoria ya liberada en ScktComp (no verificado). El puerto solo se vuelve a abrir cuando el driver envía algo (L755-756), así que OpenGas ni siquiera puede consultar STATE para saber qué pasa. La verificación solo ocurre cuando OpenGas manda algo, y SSocketPDisp no tiene OnClientDisconnect para cancelar o marcar la caída al instante. Un driver vivo que no envía (Triton sin respuestas seriales, o un driver bloqueado en E/S) provoca el mismo cierre.
- **Evidencia:** L409-412: 'if SecondsBetween(Now, horaAct)>=10 then begin CancelarPeticiones('Pdispensarios sin actividad'); SSocketOG.Active:=False; end'. L755-756: 'if not SSocketOG.Active then SSocketOG.Active:=True'. UIGASBRIDGE.dfm L9-22 solo define OnClientRead.
- **Impacto:** OpenGas pierde la conexión y la visibilidad justo cuando más las necesita; entra en reconexiones en bucle; y pueden aparecer access violations intermitentes en el Bridge.
- **Recomendación:** Etapa 3: activar SSocketOG en ServiceExecute y dejarlo siempre abierto. Mover la verificación de actividad a TimerTimeoutTimer. Agregar a SSocketPDisp un OnClientDisconnect que marque driverConectado:=False y responda la petición en vuelo con 'False|Pdispensarios desconectado|'. Responder STATE y STATUS con 'False|Pdispensarios desconectado|' en lugar de cerrar el puerto. Hay que coordinarlo con OpenGas, porque cambia la señal de falla: de una desconexión a una respuesta False.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** sí

<a id="E2E-17"></a>
#### E2E-17 · 🟠 Alta · seguridad · riesgo — Puertos 1001 y 1004 sin autenticación y abiertos en todas las interfaces; DISPENSERSX se salta el checksum; cualquiera puede inyectar comandos o snapshots

- **Ubicación:** `IgasDispensariosBridge/UIGASBRIDGE.pas` líneas 237-238, 319-334, 745-758
- **Módulos afectados:** UIGASBRIDGE.pas
- **Se atiende en:** [E5.5](../PLAN_OPTIMIZACION.md#e55--seguridad-de-red-del-bridge)
- **Verificación:** sin verificación independiente
- **Qué pasa:** TServerSocket escucha en INADDR_ANY. Cualquier equipo de la red puede: (a) conectarse a PuertoOG y mandar 'DISPENSERSX|AUTHORIZE|...' o PRICES sin calcular el CRC; (b) conectarse a PuertoPDisp y mandar un JSON arbitrario, que el Bridge instala como snapshot (con importes falsos en TRANSACTION), o resultados con folios que se responden a OpenGas. LOGIN genera un Token en los drivers, pero ningún comando lo valida: el Token solo se asigna. No se registra la IP remota de ninguna conexión.
- **Evidencia:** L322: 'if (cabecera <> 'DISPENSERS') and (cabecera <> 'DISPENSERSX')'. L329: 'if (not chks_valido) and (cabecera <> 'DISPENSERSX')'. L757-758: ProcesaRespuestasJSON(respTxt) sin validar el origen. UIGASWAYNE2W.pas L3721: 'Token:=MD5(...)', que nunca se compara.
- **Impacto:** Desde la LAN de la estación se pueden autorizar despachos, cambiar precios o falsificar el monto de una transacción.
- **Recomendación:** Etapa 3: en OnClientConnect de los dos servidores rechazar cualquier RemoteAddress que no sea 127.0.0.1 o que no esté en una lista blanca del ini (IPsPermitidasOG, IPsPermitidasPDisp). Agregar en el instalador una regla del firewall de Windows. Registrar la IP de cada conexión. Permitir desactivar DISPENSERSX desde el ini (PermiteSinChecksum=No). Etapa 5: secreto compartido en el HELLO del driver.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="E2E-19"></a>
#### E2E-19 · 🟡 Media · concurrencia · bug — Reentrancia: el ciclo serial bombea mensajes con ProcessRequests(False) y ejecuta comandos del Bridge a mitad de una transacción serial; además la espera consume el 100% de un núcleo

- **Ubicación:** `IgasDispensarios/UIGASWAYNE2W.pas` líneas 1176-1237, 3021-3060, 2624-2966
- **Módulos afectados:** UIGASWAYNE2W.pas, UIGASGILBARCO.pas
- **Se atiende en:** [E2.5](../PLAN_OPTIMIZACION.md#e25--reentrancia-comandos-del-bridge-durante-una-transacción-serial)
- **Verificación:** sin verificación independiente
- **Qué pasa:** TransmiteComando1 y TransmiteComando2 de Wayne 2W, y TransmiteComando de Gilbarco, esperan la respuesta serial llamando a ServiceThread.ProcessRequests(False) desde Timer1Timer, en el hilo principal. Esa llamada despacha todos los mensajes pendientes del hilo, incluidos los del socket. Por eso ClientSocket1Read puede ejecutar INITIALIZE (LiberaInicializacion más AgregaPosCarga), HALT, TERMINATE o RUN (con su Responder) mientras Timer1Timer está dentro de 'with TPosCarga[PosCiclo] do'. Al volver, Timer1Timer sigue escribiendo campos y JSON sobre estructuras ya reiniciadas, y MaxPosCarga y PosCiclo pueden quedar incoherentes. El propio código lo reconoce en el comentario de L1234. En Wayne 2W el bucle de espera no tiene Sleep y consume un núcleo completo durante cada espera (GtwTimeout, 300 ms por defecto).
- **Evidencia:** UIGASWAYNE2W.pas L1209-1211: 'repeat ServiceThread.ProcessRequests(False); until (bListo) or (timerexpired(etTimeOut)) or (not pSerial.Open)'. L1234-1235: comentario '// HALT o INITIALIZE pueden llegar mientras se espera respuesta' seguido de 'Timer1.Enabled:=estado>0'. UIGASGILBARCO.pas L1268-1270: 'Sleep(5); ServiceThread.ProcessRequests(False)'.
- **Impacto:** Estados inconsistentes cuando INITIALIZE o HALT llegan durante el sondeo, y uso alto de CPU que retrasa al Bridge si corre en la misma máquina.
- **Recomendación:** Etapa 2: en ClientSocket1Read, poner en una cola los comandos que alteran el ciclo (INITIALIZE, HALT, RUN, TERMINATE, SHUTDOWN) y aplicarlos al principio de Timer1Timer o de Timer2Timer, que son puntos seguros; o bien usar una bandera EnTransaccionSerial que difiera su ejecución. Reemplazar la espera activa por MsgWaitForMultipleObjects(0, nil, False, 5, QS_ALLINPUT) seguido de ProcessRequests, o al menos agregar Sleep(1).
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="E2E-20"></a>
#### E2E-20 · 🟡 Media · protocolo · riesgo — Entre OpenGas y el Bridge no hay identificador de correlación: llegan respuestas fuera de orden y tardías por el mismo socket

- **Ubicación:** `IgasDispensariosBridge/UIGASBRIDGE.pas` líneas 347-413, 473-508, 842-847, 885-890
- **Módulos afectados:** UIGASBRIDGE.pas
- **Se atiende en:** [E6.2](../PLAN_OPTIMIZACION.md#e62--push-de-comandos-resultados-inmediatos-y-ack)
- **Verificación:** sin verificación independiente
- **Qué pasa:** STATE, STATUS y TRANSACTION se responden al instante; los demás comandos, cuando vuelve el driver, por el mismo socket y sin un id de petición. Si OpenGas manda RESPCMND y luego STATUS, recibe primero la respuesta de STATUS. Con dos peticiones pendientes del mismo comando (por ejemplo, RESPCMND de dos boletos de TOTALS) solo el orden permite asociar cada respuesta, y basta con que el Bridge expire una, o que una respuesta llegue después del timeout propio de OpenGas, para romper esa asociación. El riesgo real depende de cómo empareja OpenGas las respuestas, y eso no se puede verificar en estos repositorios.
- **Evidencia:** L846: 'ResponderOG('DISPENSERS|' + p.Comando + '|' + Resultado, p.CliSock)', donde la respuesta solo lleva el nombre del comando. L358-362: respuestas inmediatas para STATE, STATUS y TRANSACTION.
- **Impacto:** Si OpenGas encola varias consultas, podría asignar totales o resultados a la posición o al boleto equivocados.
- **Recomendación:** Etapa 4: agregar una cabecera opcional y compatible, 'DISPENSERS2|<id>|CMD|...', cuya respuesta repita el id; el Bridge la acepta sin romper DISPENSERS. Mientras tanto, documentar que OpenGas no debe encolar dos comandos del mismo tipo.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** sí

<a id="E2E-21"></a>
#### E2E-21 · 🟡 Media · protocolo · bug — El PING se detecta por subcadena: cualquier JSON que contenga 'ping', sin importar mayúsculas, se descarta como latido

- **Ubicación:** `IgasDispensariosBridge/UIGASBRIDGE.pas` líneas 757-758
- **Módulos afectados:** UIGASBRIDGE.pas
- **Se atiende en:** [E3.2](../PLAN_OPTIMIZACION.md#e32--validación-del-snapshot-de-las-peticiones-y-de-los-parámetros)
- **Verificación:** sin verificación independiente
- **Qué pasa:** AnsiContainsText(respTxt, 'PING') busca la subcadena sin distinguir mayúsculas. El resultado de LOGREQ (ObtenerLogPetRes) contiene líneas 'E PING' del propio log del driver, y palabras como 'Stopping' o 'Mapping' también coinciden. Ese JSON no se procesa: el snapshot se congela y el resultado de LOGREQ nunca se empareja, así que termina en timeout. Como el driver reenvía los dos últimos resultados de Peticiones, los JSON siguientes también se descartan hasta que ese resultado sale de la lista.
- **Evidencia:** L757: 'if not AnsiContainsText(respTxt,'PING') then ProcesaRespuestasJSON(respTxt)'. UIGASWAYNE2W.pas L3916: 'Responder('PING')'; L544 lo registra con 'AgregaLogPetRes('E '+resp)', y LOGREQ (L3758-3782) devuelve ese mismo log.
- **Impacto:** LOGREQ no sirve, y el snapshot se congela de 1 a 3 ciclos (STATUS desactualizado).
- **Recomendación:** Etapa 1: tratar el mensaje como PING solo si Trim(respTxt)='PING' o si no empieza con '{'. Con framing, usar un tipo de mensaje explícito.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="E2E-22"></a>
#### E2E-22 · 🟡 Media · robustez · bug — El Bridge acepta como snapshot cualquier valor JSON y no valida los campos de Peticiones ni de PosCarga

- **Ubicación:** `IgasDispensariosBridge/UIGASBRIDGE.pas` líneas 785-859, 692-735
- **Módulos afectados:** UIGASBRIDGE.pas
- **Se atiende en:** [E3.2](../PLAN_OPTIMIZACION.md#e32--validación-del-snapshot-de-las-peticiones-y-de-los-parámetros)
- **Verificación:** sin verificación independiente
- **Qué pasa:** ParseText devuelve cualquier valor JSON (número, cadena o lista), y el Bridge lo instala como rootJSON haciendo un cast a TlkJSONobject. Basta un fragmento que empiece con dígitos o con comillas (por fragmentación TCP), o texto basura, para reemplazar el último snapshot bueno y además actualizar horaUltimoDatoReal: STATUS y TRANSACTION responden False sin avisar de obsolescencia. En el bucle de Peticiones, un elemento sin 'Folio' o sin 'Resultado' lanza una excepción que aborta el resto de los resultados del mensaje. ObtenerTranPosCarga lee Field['DispenserId'].Value, HoraOcc y los demás campos sin comprobar nil, y la excepción termina como 'Error interno del Bridge'.
- **Evidencia:** L798: 'nuevoJSON := TlkJSONobject(TlkJSON.ParseText(ATexto))'. L807: solo se comprueba nil. L820: 'horaUltimoDatoReal := Now'. L836-837: 'jItem.Field['Folio'].Value' sin verificar. L728: 'posObj.Field['DispenserId'].Value=xpos'.
- **Impacto:** STATUS y TRANSACTION en False de forma intermitente, y resultados perdidos.
- **Recomendación:** Etapa 1: aceptar el snapshot solo si nuevoJSON es TlkJSONobject y tiene 'Estado' y, cuando Estado sea mayor o igual a 0, una lista 'PosCarga'; si no cumple, liberarlo y registrarlo. Procesar cada elemento de Peticiones en su propio try/except. En TRANSACTION validar los campos y responder 'False|Datos incompletos|'.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="E2E-23"></a>
#### E2E-23 · 🟡 Media · protocolo · bug — Peticiones guarda solo 2 resultados, NOTHING ocupa lugares con Folio 0 y los resultados se reenvían sin acuse

- **Ubicación:** `IgasDispensarios/UIGASWAYNE2W.pas` líneas 3264-3297, 3980-3981
- **Módulos afectados:** UIGASWAYNE2W.pas, UIGASWAYNE.pas, UIGASBENNETT.pas, UIGASGILBARCO.pas, UIGASHONGYANG.pas, UIGASPAM.pas, UIGASTEAM.pas, UIGASTRITON.pas, UIGASBRIDGE.pas
- **Se atiende en:** [E6.2](../PLAN_OPTIMIZACION.md#e62--push-de-comandos-resultados-inmediatos-y-ack)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Cuando ya hay dos resultados, AddPeticionJSON borra el más antiguo, y cada respuesta de relleno '0|DISPENSERS|NOTHING' agrega {Folio:0, Resultado:'True|'}. Un resultado solo sobrevive hasta que el driver procesa dos respuestas más. Si entre dos envíos el driver procesa más de una respuesta (por envíos extra en RUN o en '0'/'1', por mensajes pegados o por una reconexión), un resultado puede salir de la lista antes de viajar al Bridge. A la inversa, los resultados se reenvían en cada JSON hasta que los desplaza otro, porque no hay acuse. El Bridge empareja con el primer folio que coincida: tras un reinicio del Bridge el folio vuelve a 1, y un resultado viejo con el mismo folio podría contestar una petición nueva. Esto último es poco probable porque NOTHING desplaza pronto los resultados viejos.
- **Evidencia:** UIGASWAYNE2W.pas L3282-3283: 'while petArr.Count >= 2 do petArr.Delete(0)'. L3980-3981: 'NOTHING_e: AddPeticionJSON(folio, 'True|')' con folio=0. Bridge L839: TryPopByFolio toma la primera coincidencia. Bridge L364-366: folio de 1 a 999, que reinicia en cada arranque.
- **Impacto:** Respuestas perdidas que terminan en timeout y, en casos raros, respuestas cruzadas.
- **Recomendación:** Etapa 2: en todos los drivers, que NOTHING no se registre como resultado (basta con respJson:=True); subir la capacidad a 8 resultados con marca de tiempo y descartar los de más de 10 s. Etapas 4-5: que el Bridge incluya en su respuesta los folios ya recibidos ('ACK:12,13') para que el driver los elimine, y agregar un 'Epoch' (hora de arranque del Bridge) a cada petición que el driver devuelva en el resultado.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** sí

<a id="E2E-24"></a>
#### E2E-24 · 🟡 Media · protocolo · bug — Boletos: AUTHORIZE, STOP, START, PAYMENT y TOTALS solo confirman que el comando quedó encolado (FolioCmnd); el resultado real hay que sondearlo con RESPCMND por el mismo canal lento, y FolioCmnd vuelve a 1 cuando se reinicia el driver

- **Ubicación:** `IgasDispensarios/UIGASWAYNE2W.pas` líneas 981-1021, 1061-1076, 3381, 3523, 3538, 3800-3826, 3868-3890
- **Módulos afectados:** UIGASWAYNE2W.pas, UIGASWAYNE.pas, UIGASBENNETT.pas, UIGASGILBARCO.pas, UIGASHONGYANG.pas, UIGASPAM.pas, UIGASTEAM.pas, UIGASTRITON.pas, UIGASBRIDGE.pas
- **Se atiende en:** [E5.2](../PLAN_OPTIMIZACION.md#e52--confirmación-real-de-prices-authorize-y-payment), [E5.3](../PLAN_OPTIMIZACION.md#e53--totals-y-respcmnd-desde-el-snapshot)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Los comandos que actúan sobre el dispensario solo se registran en TabCmnd y devuelven 'True|<FolioCmnd>|' (TOTALS devuelve 'True|0|0|0|0|0|0|<FolioCmnd>|'). El resultado real, sea el OK o el error del dispensario o los totales, se obtiene con RESPCMND <FolioCmnd>, que es otra petición encolada con su propia latencia de alrededor de 1.5 ciclos y que responde 'False|*|' mientras no hay respuesta. Un TOTALS completo cuesta de 2 a 6 viajes. FolioCmnd es un contador en memoria que vuelve a 1 al reiniciar el driver, así que un RESPCMND de un boleto anterior al reinicio puede devolver el resultado de otro comando con el mismo número. En AUTHORIZE y PAYMENT, además, el Bridge reemplaza el boleto por 0 (ver el hallazgo de confirmación falsa).
- **Evidencia:** L1002-1005: 'inc(FolioCmnd); ... Folio:=FolioCmnd'. L3885: 'AddPeticionJSON(folio, valor+'|0|0|0|0|0|0|'+IntToStr(xfolioCmnd)+'|')'. L1066: 'Result:='*''. L3821: 'AddPeticionJSON(folio, 'False|'+resp+'|')'.
- **Impacto:** Latencia alta en el corte de turno, y posibilidad de recibir los totales de otro comando después de un reinicio del driver.
- **Recomendación:** Etapa 1: inicializar FolioCmnd con un valor que dependa de la hora de arranque, para evitar colisiones. Etapa 4: publicar en el JSON, por posición, 'UltimoComando' y los totales con su hora, para que el Bridge responda RESPCMND y TOTALS desde el snapshot. Etapa 5: que el driver empuje un evento con el resultado asíncrono.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** sí

<a id="E2E-25"></a>
#### E2E-25 · 🟡 Media · rendimiento · optimizacion — Snapshot completo en cada ciclo, con campos que el Bridge no usa (Hoses[].Total) y un reparseo total en el Bridge

- **Ubicación:** `IgasDispensariosBridge/UIGASBRIDGE.pas` líneas 785-825
- **Módulos afectados:** UIGASBRIDGE.pas, UIGASWAYNE2W.pas, UIGASWAYNE.pas, UIGASBENNETT.pas, UIGASGILBARCO.pas, UIGASHONGYANG.pas, UIGASPAM.pas, UIGASTEAM.pas, UIGASTRITON.pas
- **Se atiende en:** [E4.2](../PLAN_OPTIMIZACION.md#e42--json-más-barato-generar-menos-redondear-y-buscar-menos), [E5.3](../PLAN_OPTIMIZACION.md#e53--totals-y-respcmnd-desde-el-snapshot), [E6.3](../PLAN_OPTIMIZACION.md#e63--snapshot-incremental-y-salud)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Cada envío lleva el rootJSON completo: unos 150 bytes por posición más unos 45 por manguera, sin contar los dígitos de doble precisión sin redondear. Son unos 5 KB con 16 posiciones y unos 10 KB con 32. Con cadencias de 1.3 a 20 envíos por segundo según la marca, el Bridge parsea cada mensaje (uLkJSON crea una tabla hash por objeto), reemplaza rootJSON y registra el texto completo, aunque nada haya cambiado. Hoses[].Total viaja siempre pero el Bridge no lo lee: TOTALS sigue el camino lento de comando más RESPCMND.
- **Evidencia:** L798: 'TlkJSON.ParseText(ATexto)'. L812-814: 'rootJSON.Free; rootJSON := nuevoJSON'. El Bridge solo lee Estado, los campos de PosCarga que usan STATUS y TRANSACTION, y Peticiones (L600-735, L828-852). UIGASWAYNE2W.pas L699-703: 'hoseObj.Add('Total', 0)'.
- **Impacto:** CPU y memoria desperdiciadas en los dos procesos, más probabilidad de fragmentación TCP y logs enormes.
- **Recomendación:** Etapa 2: enviar solo si el texto cambió, o cada 1 s como latido (y corregir el intento de HongYang); redondear los flotantes al asignarlos (volumen a 3 decimales, importe a 2). Etapa 4: campo 'Seq' incremental y servir TOTALS desde Hoses[].Total con 'HoraTotales'. Etapa 5: enviar solo los cambios por posición.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** sí

<a id="E2E-26"></a>
#### E2E-26 · 🟡 Media · rendimiento · bug — En HongYang, 'publicar el JSON solo al cambiar' nunca se cumple porque socketResponse se asigna con cada respuesta, incluida NOTHING

- **Ubicación:** `IgasDispensarios/UIGASHONGYANG.pas` líneas 316-400, 2004-2022
- **Módulos afectados:** UIGASHONGYANG.pas
- **Se atiende en:** [E4.1](../PLAN_OPTIMIZACION.md#e41--responder-al-bridge-en-cuanto-se-procesa-un-comando-y-homologar-la-cadencia)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El commit fd48cc2 quiso publicar el JSON 'solo si cambió, si hay una petición en espera o cada 0.5 s'. Pero socketResponse se asigna al final de cada ClientSocket1Read, incluidas las respuestas NOTHING (L390). Como el Bridge responde a cada envío, Assigned(socketResponse) es verdadero en cada turno, y el JSON sale cada tres ticks de 15 ms más el tiempo serial: unas 10 a 20 veces por segundo.
- **Evidencia:** L390: 'socketResponse:=Socket'. L2009: 'if (xjson<>UltimoJSON)or(Assigned(socketResponse))or((Now-HoraUltimoJSON)>=TmSegundo*0.5)'.
- **Impacto:** La carga sobre el Bridge (parseo y log) es de 10 a 40 veces mayor que la de otras marcas.
- **Recomendación:** Etapa 1: usar una bandera PeticionPendiente que se ponga en True solo al procesar un comando distinto de NOTHING, ponerla en lugar de Assigned(socketResponse) y limpiarla después de enviar.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="E2E-27"></a>
#### E2E-27 · 🟡 Media · protocolo · riesgo — La obsolescencia se mide por la llegada de JSON y no por la frescura de los datos; el TRACE automático 'despierta' pausas que eran intencionales

- **Ubicación:** `IgasDispensariosBridge/UIGASBRIDGE.pas` líneas 510-521, 540-578, 820
- **Módulos afectados:** UIGASBRIDGE.pas, UIGASWAYNE.pas, UIGASPAM.pas, UIGASWAYNE2W.pas
- **Se atiende en:** [E5.1](../PLAN_OPTIMIZACION.md#e51--semántica-única-de-estatus-y-campos-de-venta)
- **Verificación:** sin verificación independiente
- **Qué pasa:** horaUltimoDatoReal se actualiza con cualquier JSON bien formado. Pero los drivers siguen mandando JSON (Timer2 cada 200 ms) cuando el sondeo serial está detenido: después de HALT, después del comando '0' de Wayne o PAM (que cierra el puerto) en cuanto el TRACE automático devuelve respJson a True, o mientras Timer1 está apagado por una desconexión. El Bridge toma esos datos por frescos y responde STATUS y TRANSACTION con estatus congelados (por ejemplo, '2' despachando) indefinidamente. Además, el TRACE automático contradice la pausa deliberada del comando '0', que pone respJson en False justamente para mandar solo PING.
- **Evidencia:** Bridge L820: 'horaUltimoDatoReal := Now' con cualquier JSON. UIGASWAYNE.pas L2795-2801: 'pSerial.Open:=False; Timer1.Enabled:=False; ... respJson:=False; Timer2.Enabled:=True'. UIGASWAYNE2W.pas L3499-3503: Detener apaga Timer1, enciende Timer2 y pone estado en 0.
- **Impacto:** OpenGas ve estados de posición viejos como si fueran actuales.
- **Recomendación:** Etapa 4, con campos nuevos: que el driver publique 'Sondeando' (booleano), 'HoraDatos' global y 'UltimaLectura' por posición, y que el Bridge marque la obsolescencia por posición cuando Sondeando sea false o UltimaLectura pase el umbral. Mientras tanto, en el Bridge tratar Estado menor o igual a 0 como 'sin datos en vivo' y responder STATUS con 'False|Servicio detenido|'.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** sí

<a id="E2E-28"></a>
#### E2E-28 · 🟡 Media · robustez · bug — TRACE automático: hace que el driver escriba logs grandes, y los TRACE que no se alcanzan a entregar nunca expiran

- **Ubicación:** `IgasDispensariosBridge/UIGASBRIDGE.pas` líneas 540-578, 869-897, 177-201
- **Módulos afectados:** UIGASBRIDGE.pas, UIGASTRITON.pas
- **Se atiende en:** [E3.3](../PLAN_OPTIMIZACION.md#e33--timeouts-por-comando-en-milisegundos-y-folios-no-repetibles)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Cada TRACE automático encola un TRACE real, y en los drivers TRACE ejecuta GuardarLog, que escribe LogDisp y LogDispPetRes completos (hasta 10 000 líneas cada uno) en el hilo principal y crea archivos nuevos. El límite de frecuencia solo considera el tiempo (3 s), no si ya hay un TRACE pendiente. Además, las peticiones que no se envían nunca expiran (TryPopExpired exige Enviada), así que con el driver mudo entre 5 y 10 s se acumulan TRACE que después bloquean la cabeza de la cola. La causa de fondo, un driver que no pasa de PING, solo existe en Triton y después del comando '0'.
- **Evidencia:** L561-568: 'p.Comando := 'TRACE'; ... ListaPeticiones.Push(p)'. L553: límite solo por tiempo. L190: 'if Tmp.Enviada and ...'. UIGASWAYNE2W.pas L3545-3559: GuardarLog.
- **Impacto:** Pausas en el ciclo serial del driver, disco que crece y cola atascada.
- **Recomendación:** Etapas 1-3: corregir la causa (NOTHING_e en Triton). Sustituir el TRACE por un comando inocuo: NOTHING con un folio mayor que 0 ya pone respJson en True en siete drivers, o se puede crear un 'WAKE'. No encolar si ya hay uno pendiente. Hacer expirar a los N s las peticiones no enviadas, respondiendo 'False|Pdispensarios no disponible|'.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="E2E-29"></a>
#### E2E-29 · 🟡 Media · protocolo · bug — STATE incoherente: tras un INITIALIZE exitoso el snapshot sigue en -1 en 5 drivers, y el Bridge confunde 'datos obsoletos' con el estado del servicio

- **Ubicación:** `IgasDispensarios/UIGASWAYNE2W.pas` líneas 807-901
- **Módulos afectados:** UIGASWAYNE2W.pas, UIGASWAYNE.pas, UIGASHONGYANG.pas, UIGASTRITON.pas, UIGASBENNETT.pas, UIGASBRIDGE.pas
- **Se atiende en:** [E1.9](../PLAN_OPTIMIZACION.md#e19--coherencia-del-estado-publicado-estatus-fin-de-venta-horaocc-estado), [E5.1](../PLAN_OPTIMIZACION.md#e51--semántica-única-de-estatus-y-campos-de-venta)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Wayne 2W (L895), Wayne (L456), HongYang (L606), Triton (L540) y Bennett (L2459) ponen estado:=0 en Inicializar pero no llaman a SetEstadoJSON, así que el JSON sigue con Estado=-1 (el que dejaron LiberaInicializacion o ServiceExecute) hasta RUN. Team (L696-697) y PAM (L2722-2723) sí lo actualizan, y Kairos responde 0 directamente. En el Bridge, STATE responde 'False|Datos obsoletos...' cuando el snapshot tiene más de 5 s; un cliente puede leerlo como servicio caído y reenviar INITIALIZE, que reinicia el driver (ver el hallazgo correspondiente).
- **Evidencia:** L895-896: 'estado:=0; AddPeticionJSON(folio, 'True|')' sin SetEstadoJSON. UIGASTEAM.pas L696-697: 'estado:=0; SetEstadoJSON(estado)'. Bridge L590-597.
- **Impacto:** OpenGas ve -1 después de un INITIALIZE correcto, y puede tomar decisiones de recuperación equivocadas.
- **Recomendación:** Etapa 1: llamar a SetEstadoJSON(estado) en Inicializar de los 5 drivers. Etapas 3-4: que STATE responda siempre el último Estado conocido y añada la antigüedad del dato, o crear un comando HEALTH aparte; documentar los valores -1, 0 y 1.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="E2E-30"></a>
#### E2E-30 · 🟡 Media · robustez · bug — La reconexión del driver bloquea el hilo y no sirve: hace Sleep en el hilo principal esperando un evento que solo puede llegar por ese mismo hilo

- **Ubicación:** `IgasDispensarios/UIGASWAYNE2W.pas` líneas 3892-3933
- **Módulos afectados:** UIGASWAYNE2W.pas, UIGASBENNETT.pas, UIGASGILBARCO.pas, UIGASHONGYANG.pas, UIGASPAM.pas, UIGASTEAM.pas, UIGASTRITON.pas, UIGASWAYNE.pas
- **Se atiende en:** [E2.2](../PLAN_OPTIMIZACION.md#e22--reconexión-no-bloqueante-y-con-manejo-de-errores)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Timer2Timer hace ClientSocket1.Active:=True y espera 'conectado' con hasta 101 llamadas a Sleep(10); Wayne 2W y Bennett además duermen 500 ms antes. En los drivers cuyo socket vive en el hilo principal, OnConnect no puede ejecutarse durante esa espera: cada intento bloquea entre 1 y 1.5 s para nada, y la conexión se reconoce hasta el siguiente tick. Como no hay manejador OnError, cuando el Bridge está caído cada intento fallido lanza una ESocketError desde el WndProc del socket, que termina en Application.HandleException y en el visor de eventos de Windows.
- **Evidencia:** L3906-3912: 'Sleep(500); ClientSocket1.Active := True; for i:=0 to 100 do begin Sleep(10); if conectado then Break; end;'. Igual en UIGASBENNETT.pas L588-594, UIGASGILBARCO.pas L3081-3089, UIGASHONGYANG.pas L2033-2038, UIGASPAM.pas L327-332, UIGASTEAM.pas L362-367, UIGASTRITON.pas L339-344 y UIGASWAYNE.pas L2926-2931. Ningún .dfm asigna OnError a ClientSocket1.
- **Impacto:** El hilo principal se queda congelado mientras el Bridge no está disponible, y el visor de eventos se llena de errores.
- **Recomendación:** Etapa 2: usar una máquina de estados no bloqueante. Si no hay conexión ni intento en curso, hacer Active:=True y salir. OnConnect manda el primer mensaje. OnError registra el fallo, pone ErrorCode:=0 y programa un reintento con espera creciente (1, 2 y 5 s).
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="E2E-31"></a>
#### E2E-31 · 🟡 Media · robustez · bug — Responder maneja los errores de forma distinta en cada driver y no verifica los envíos parciales

- **Ubicación:** `IgasDispensarios/UIGASWAYNE2W.pas` líneas 534-557
- **Módulos afectados:** UIGASWAYNE2W.pas, UIGASBENNETT.pas, UIGASGILBARCO.pas, UIGASHONGYANG.pas, UIGASPAM.pas, UIGASTEAM.pas, UIGASTRITON.pas, UIGASWAYNE.pas
- **Se atiende en:** [E6.1](../PLAN_OPTIMIZACION.md#e61--framing-y-buffer-por-conexión-en-los-dos-sentidos-y-del-lado-de-opengas)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Ante una excepción, Wayne 2W y Bennett cierran el socket y apagan Timer1. Wayne, PAM, Team, Triton y Gilbarco solo la registran y dependen de que ScktComp dispare OnDisconnect. HongYang la relanza (L464), igual que su ClientSocket1Read (L397) y su Timer1Timer (L2001). Ninguno revisa lo que devuelve SendText: en un socket no bloqueante ScktComp puede enviar menos bytes, o ninguno (WSAEWOULDBLOCK), sin lanzar excepción, y el resto del JSON se pierde, lo que llega al Bridge como un mensaje truncado. socketResponse es un TCustomWinSocket que se guarda entre eventos y que solo puede apuntar al único socket cliente: agrega complejidad sin ningún beneficio.
- **Evidencia:** L538: 'socketResponse.SendText(resp)' sin revisar el valor devuelto. UIGASHONGYANG.pas L462-465: 'raise Exception.Create('Error Responder: '+e.Message)'. UIGASPAM.pas L496-500: solo registra.
- **Impacto:** JSON truncados y recuperaciones de comportamiento impredecible.
- **Recomendación:** Etapas 2/6: una unidad común con un método Enviar que haga n:=SendText(s) y, si n es menor que Length(s), guarde el resto en un buffer para completarlo en OnWrite. Ante un error, cerrar y marcar la desconexión de la misma forma en todos los drivers. Quitar socketResponse y usar ClientSocket1.Socket.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="E2E-32"></a>
#### E2E-32 · 🟡 Media · rendimiento · optimizacion — AgregaLog y AgregaLogPetRes copian el texto carácter por carácter (O(n²)) con cada JSON, en el hilo del sondeo serial

- **Ubicación:** `IgasDispensarios/UIGASWAYNE2W.pas` líneas 459-511
- **Módulos afectados:** UIGASWAYNE2W.pas, UIGASGILBARCO.pas, UIGASHONGYANG.pas, UIGASTRITON.pas, UIGASBENNETT.pas, UIGASKAIROS.pas, UIGASPAM.pas, UIGASTEAM.pas, UIGASWAYNE.pas
- **Se atiende en:** [E2.4](../PLAN_OPTIMIZACION.md#e24--bitácoras-que-no-bloquean-append-incremental-rotación-y-sin-json-repetido)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Para sustituir los caracteres de control, AgregaLog y AgregaLogPetRes recorren el texto letra por letra concatenando con lin2:=lin2+lin[i]. Con cada JSON de 5 a 10 KB que se envía o se recibe, eso son miles de realocaciones de cadena en el hilo principal, el mismo que temporiza el serial, varias veces por segundo. El Bridge hace lo mismo en AgregaLogOG (con mensajes pequeños), pero no en AgregaLogPDisp.
- **Evidencia:** L492-501 en Wayne 2W. El mismo patrón está en UIGASGILBARCO.pas L389-405, UIGASHONGYANG.pas L421-430, UIGASTRITON.pas L209-218, UIGASBENNETT.pas L641-651, UIGASKAIROS.pas L617-627, y en PAM, Team y Wayne.
- **Impacto:** Uso de CPU evitable y fluctuaciones en la temporización del protocolo serial.
- **Recomendación:** Etapa 1: si el texto no tiene caracteres por debajo de #32, agregarlo tal cual; si los tiene, usar StringReplace por cada carácter de control o reservar el tamaño con SetLength. Combinarlo con registrar el JSON solo cuando cambie.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="E2E-33"></a>
#### E2E-33 · 🟡 Media · protocolo · deuda_tecnica — El comando '0'/'1' de OpenGas solo está implementado en Wayne y PAM, y sus respuestas tienen formatos distintos

- **Ubicación:** `IgasDispensariosBridge/UIGASBRIDGE.pas` líneas 291-294, 427-431, 843-846, 886-889
- **Módulos afectados:** UIGASBRIDGE.pas, UIGASWAYNE.pas, UIGASPAM.pas, UIGASKAIROS.pas
- **Se atiende en:** [E5.4](../PLAN_OPTIMIZACION.md#e54--comandos-homogéneos-entre-marcas)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El Bridge reenvía el mensaje de un byte '0' o '1' como 'DISPENSERS|0' o 'DISPENSERS|1' con Comando='1', y devuelve el Resultado tal cual. Wayne y PAM lo interpretan: con '1' abren el puerto y reanudan Timer1; con '0' cierran el puerto, detienen Timer1 y ponen respJson en False. Ambos responden Resultado '1', que el Bridge manda sin trama porque mide un byte. Los otros seis drivers responden 'False|Comando desconocido|' con trama, y Kairos responde '1' sin trama directo a OpenGas. Para detectarlo, la lectura TCP tiene que traer exactamente ese byte.
- **Evidencia:** Bridge L291: 'if (Length(mensaje)=1) and (StrToIntDef(mensaje,-99) in [0,1])'. L843-844: 'if p.Comando='1' then ResponderOG(Resultado, p.CliSock)'. UIGASWAYNE.pas L2781-2803. UIGASPAM.pas L386-409.
- **Impacto:** El mismo comando se comporta distinto según la marca, y la pausa con '0' no se sostiene por el TRACE automático.
- **Recomendación:** Etapa 4: documentar que el comando sirve para pausar y reanudar el sondeo, y decidir si se soporta. Implementarlo en la unidad común o responder en todos los drivers 'False|No soportado|'. El Bridge debe responder este comando siempre con trama o siempre sin ella.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** sí

<a id="E2E-34"></a>
#### E2E-34 · 🟡 Media · robustez · bug — Al arrancar, Timer2 ya viene habilitado en el .dfm y puede dispararse antes de que ServiceExecute inicialice Host, Port, las listas y rootJSON; además AgregaLog de Wayne 2W se llama a sí mismo

- **Ubicación:** `IgasDispensarios/UIGASWAYNE2W.pas` líneas 411-457, 459-484
- **Módulos afectados:** UIGASWAYNE2W.pas, UIGASBENNETT.pas, UIGASGILBARCO.pas, UIGASHONGYANG.pas, UIGASPAM.pas, UIGASTEAM.pas, UIGASTRITON.pas, UIGASWAYNE.pas
- **Se atiende en:** [E2.3](../PLAN_OPTIMIZACION.md#e23--arranque-y-paro-ordenados-del-servicio)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Ningún .dfm pone Enabled=False en Timer2, así que queda en True con intervalo de 200 ms. El TTimer se crea en el hilo principal durante Application.CreateForm y empieza a contar antes de que el SCM arranque TServiceThread y se ejecute ServiceExecute. Si el primer tick llega antes (por ejemplo, en un arranque lento del equipo), Timer2Timer usa el Host vacío y el Port=0 del .dfm y, al fallar, llama a AgregaLog con ListaLog todavía en nil. En Wayne 2W, AgregaLog atrapa esa excepción y se llama a sí mismo dentro del except (L478-482): la recursión es infinita y el desbordamiento de pila termina el proceso. Es poco probable que ocurra, porque la ventana es de cientos de milisegundos al arrancar.
- **Evidencia:** UIGASWAYNE2W.dfm L44-50: Timer2 sin Enabled=False. UIGASWAYNE2W.pas L439: 'ListaLog:=TStringList.Create' después de leer el ini. L478-482: 'except on e:Exception do begin AgregaLog('Error AgregaLog: '+e.Message)'.
- **Impacto:** Posible caída del proceso al arrancar.
- **Recomendación:** Etapa 1: poner Timer2.Enabled=False en todos los .dfm y habilitarlo al final de ServiceExecute. Como habilitar un TTimer desde otro hilo puede fallar, hacerlo con PostMessage a una ventana del hilo principal o crear los timers en el hilo del servicio. En AgregaLog no volver a llamar a AgregaLog dentro del except.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="E2E-35"></a>
#### E2E-35 · 🟡 Media · robustez · riesgo — El Bridge acepta cualquier número de conexiones de Pdispensarios, sin identificarlas ni manejar sesiones

- **Ubicación:** `IgasDispensariosBridge/UIGASBRIDGE.pas` líneas 745-774
- **Módulos afectados:** UIGASBRIDGE.pas
- **Se atiende en:** [E3.1](../PLAN_OPTIMIZACION.md#e31--disponibilidad-puerto-1001-siempre-activo-y-driver-caído-detectado), [E6.3](../PLAN_OPTIMIZACION.md#e63--snapshot-incremental-y-salud)
- **Verificación:** sin verificación independiente
- **Qué pasa:** SSocketPDispClientRead responde al socket que envió y reemplaza rootJSON con lo que llegue por cualquier conexión. Dos instancias del driver (un servicio duplicado, una prueba en paralelo, o un reinicio que deja viva la conexión anterior), un cliente de diagnóstico o una conexión ajena alternarían sus snapshots, con un STATUS que oscila, y se repartirían los comandos. No existe un mensaje de presentación con la marca, la versión o el PID del driver.
- **Evidencia:** L760-762: el comando se envía al Socket que acaba de leer. L812-814: rootJSON se reemplaza sin condiciones.
- **Impacto:** Estados que oscilan y comandos que llegan al proceso equivocado.
- **Recomendación:** Etapa 3: aceptar una sola conexión activa; al conectarse otra, cerrar la anterior y registrarlo. Etapa 4: un mensaje HELLO del driver con la marca, la versión (InfoVersionModulo), el PID y 'Proto', que el Bridge registre y exponga en HEALTH.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** sí

<a id="E2E-36"></a>
#### E2E-36 · 🟡 Media · observabilidad · deuda_tecnica — No hay métricas ni correlación de punta a punta: ni latencias, ni timeouts, ni resultados tardíos, ni edad del snapshot

- **Ubicación:** `IgasDispensariosBridge/UIGASBRIDGE.pas` líneas 760-767, 869-894
- **Módulos afectados:** UIGASBRIDGE.pas, UIGASWAYNE2W.pas
- **Se atiende en:** [E0.3](../PLAN_OPTIMIZACION.md#e03--métricas-y-correlación-de-punta-a-punta-en-el-bridge), [E6.3](../PLAN_OPTIMIZACION.md#e63--snapshot-incremental-y-salud)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El Bridge registra el texto crudo, pero no la latencia de cada folio (encolado, envío y resultado), ni contadores de timeouts, cancelaciones, errores de parseo, resultados tardíos o duplicados. El driver no anota el folio del Bridge junto al FolioCmnd interno en el log del ciclo serial, y no existe un comando de salud. Para diagnosticar casos como los de este informe hay que cruzar a mano, por hora, LogOG, LogPDisp, LogDispPetRes y LogDisp.
- **Evidencia:** No existe ningún contador; AgregaLogPDisp solo guarda 'R '/'E ' con el texto.
- **Impacto:** Diagnósticos lentos, y no hay forma de medir si las optimizaciones mejoran algo.
- **Recomendación:** Etapa 0: cada minuto, una línea de resumen en el Bridge (largo de la cola, comandos en vuelo, timeouts, latencia p50 y p95, edad del snapshot, envíos por segundo del driver). En cada respuesta a OpenGas, registrar 'folio cmd t_cola t_driver'. Agregar el comando DISPENSERS|HEALTH con esos datos y las versiones del Bridge y del driver. En el driver, registrar 'BRIDGE folio=N -> FolioCmnd=M' al encolar en TabCmnd.
- **Esfuerzo:** M · **Riesgo del cambio:** bajo · **Toca contrato:** sí

<a id="E2E-37"></a>
#### E2E-37 · 🟡 Media · protocolo · deuda_tecnica — El protocolo es implícito y no tiene versión: propuesta de protocolo v2 compatible hacia atrás

- **Ubicación:** `IgasDispensariosBridge/UIGASBRIDGE.pas` líneas 745-859
- **Módulos afectados:** UIGASBRIDGE.pas, UIGASWAYNE2W.pas, UIGASWAYNE.pas, UIGASBENNETT.pas, UIGASGILBARCO.pas, UIGASHONGYANG.pas, UIGASPAM.pas, UIGASTEAM.pas, UIGASTRITON.pas
- **Se atiende en:** [E0.4](../PLAN_OPTIMIZACION.md#e04--simuladores-de-opengas-y-de-driver--batería-de-pruebas-de-protocolo), [E6.2](../PLAN_OPTIMIZACION.md#e62--push-de-comandos-resultados-inmediatos-y-ack), [E8.4](../PLAN_OPTIMIZACION.md#e84--documentación)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  No hay número de versión ni negociación: el formato está repartido entre 9 drivers y el Bridge, y cualquier cambio obliga a desplegar todo a la vez. Propuesta v2, que conviviría con v1:
  1) Framing: cada mensaje entre driver y Bridge es STX + tipo de 3 letras + '|' + longitud + '|' + payload + ETX + CRC16 (el CRC16 ya existe en los dos lados), y cada socket tiene un buffer acumulador.
  2) Negociación: el driver v2 envía primero HELLO {Proto:2, Marca, Version, PID, Capacidades} y el Bridge v2 contesta HLO {Proto:2, Epoch}. Si el Bridge es v1 responde '0|DISPENSERS|NOTHING' y el driver vuelve a v1. Si el Bridge v2 recibe primero 'PING' o '{', trata la conexión como v1.
  3) Push: el Bridge envía CMD {Id=Epoch-Folio, Cmd, Params, DeadlineMs} en cuanto lo recibe de OpenGas, con hasta N en vuelo. El driver contesta ACK {Id} al recibirlo y RES {Id, Ok, Datos} al terminar: de inmediato los síncronos. AUTHORIZE, PAYMENT y PRICES responden primero RES 'Encolado' con FolioCmnd y después EVT {Id, Aplicado|Rechazado, Detalle} cuando el ciclo serial los ejecuta. El Bridge contesta a OpenGas según la política de cada comando, sin confirmar a ciegas.
  4) Snapshot con secuencia: SNP {Seq, Completo} al conectar y cada 30 s, y DLT {Seq, PosCarga solo con las posiciones cambiadas} cuando algo cambia. Si el Bridge detecta un hueco en Seq, pide RSY.
  5) Heartbeat aparte: HBT cada segundo en los dos sentidos; el watchdog salta a los 3 HBT sin respuesta, y la obsolescencia se decide por UltimaLectura de cada posición.
  6) Idempotencia: el driver guarda los últimos 64 RES por Id y, si recibe un CMD repetido, reenvía el RES sin volver a ejecutar. El Bridge reintenta un CMD sin ACK a los 500 ms con el mismo Id.
  7) OpenGas no está obligado a cambiar; opcionalmente puede usar 'DISPENSERS2|<id>|CMD|...' con id de correlación y los comandos nuevos RESULT y HEALTH.
- **Evidencia:** Ni rootJSON (Estado, PosCarga, Peticiones) ni '<folio>|DISPENSERS|CMD' llevan un campo de versión. uLkJSON.pas y UVersionModulo.pas están copiados idénticos en los dos repositorios, sin un módulo de protocolo compartido.
- **Impacto:** Cada mejora del contrato exige un despliegue sincronizado de alto riesgo en todas las estaciones, y no hay forma controlada de que un Bridge nuevo opere con drivers viejos ni al revés.
- **Recomendación:** Etapa 4: introducir campos v1.1 que un Bridge viejo simplemente ignora: 'Proto':1, 'Seq', 'VentaId', 'VentaFinal', 'UltimaLectura' y 'Sondeando'. Etapa 5: implementar v2 detrás de una bandera del ini (ProtocoloV2=Si) en los dos lados, con la detección automática descrita. Construir simuladores de driver y de OpenGas para pruebas de regresión (fragmentación, concatenación, reconexión, reinicios y comandos lentos) y hacer un piloto por marca, empezando por Wayne 2W, que ya tiene modo emulación.
- **Esfuerzo:** L · **Riesgo del cambio:** alto · **Toca contrato:** sí

<a id="E2E-38"></a>
#### E2E-38 · 🟡 Media · correccion · bug — Con la tabla llena, EjecutaComando lee y puede escribir TabCmnd[201], fuera del arreglo

- **Ubicación:** `IgasDispensarios/UIGASWAYNE2W.pas` líneas 981-1013, 273-274
- **Módulos afectados:** UIGASWAYNE2W.pas, UIGASBENNETT.pas, UIGASGILBARCO.pas, UIGASHONGYANG.pas, UIGASKAIROS.pas, UIGASPAM.pas, UIGASTEAM.pas, UIGASTRITON.pas, UIGASWAYNE.pas
- **Se atiende en:** [E1.5](../PLAN_OPTIMIZACION.md#e15--tabla-de-comandos-tabcmnd-y-respuestas-de-comandos-asíncronos)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El bucle 'repeat inc(ind); if (TabCmnd[ind].SwActivo) and ((now-TabCmnd[ind].hora)>tmMinuto) then TabCmnd[ind].SwActivo:=false ...; until (not TabCmnd[ind].SwActivo) or (ind>200)' evalúa TabCmnd[201], que está fuera de [1..200] y sin verificación de rangos, antes de comprobar ind>200. Incluso puede escribir en la memoria contigua si los bytes leídos parecen un registro activo y viejo; en Wayne 2W la siguiente variable global es LPrecios, que guarda los precios. Solo ocurre con 200 comandos activos dentro de un mismo minuto, pero el resultado sería una corrupción silenciosa.
- **Evidencia:** L987-994; L273-274: 'TabCmnd :array[1..200] of RegCmnd;' seguido de 'LPrecios :array[1..4] of Double;'. El mismo patrón está en UIGASBENNETT.pas L1770-1777, UIGASGILBARCO.pas L776-787, UIGASKAIROS.pas L851-858, UIGASTEAM.pas L2238-2246, y en HongYang, PAM, Triton y Wayne.
- **Impacto:** Posible corrupción de precios u otras variables globales en una situación de saturación.
- **Recomendación:** Etapa 1: reescribir el bucle con 'for ind:=1 to 200 do' y Break cuando la entrada esté libre o vieja, y comprobar después si se encontró. Compilar las pruebas con {$R+}.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="E2E-39"></a>
#### E2E-39 · 🟡 Media · configuracion · bug — El arranque del Bridge y la activación de sus puertos son frágiles

- **Ubicación:** `IgasDispensariosBridge/UIGASBRIDGE.pas` líneas 230-277, 755-756, 768-772
- **Módulos afectados:** UIGASBRIDGE.pas
- **Se atiende en:** [E0.5](../PLAN_OPTIMIZACION.md#e05--configuración-documentada-y-validada-al-arrancar), [E2.3](../PLAN_OPTIMIZACION.md#e23--arranque-y-paro-ordenados-del-servicio), [E3.1](../PLAN_OPTIMIZACION.md#e31--disponibilidad-puerto-1001-siempre-activo-y-driver-caído-detectado)
- **Verificación:** sin verificación independiente
- **Qué pasa:** MinutosLog se lee con StrToInt: un valor no numérico aborta ServiceExecute, y el except usa ListaLogOG cuando todavía es nil. Si el puerto de OpenGas está ocupado (por Kairos u otro servicio en el 1001), SSocketOG.Active:=True falla con cada mensaje del driver dentro de SSocketPDispClientRead. Su except vuelca GuardaLogPDisp completo cada vez, entre 5 y 20 veces por segundo, y no responde al driver, que entonces dispara su watchdog. PuertoPDisp vale 1004 por defecto en el código y 1002 en el .dfm, lo que confunde a soporte.
- **Evidencia:** L239: 'minutosLog:=StrToInt(config.ReadString('CONF','MinutosLog','0'))'. L273: 'ListaLogOG.Add(...)' dentro del except. L755-756. L768-772: el except llama a GuardaLogPDisp. UIGASBRIDGE.dfm L19 'Port = 1002' frente a L238 'ReadInteger('CONF','PuertoPDisp',1004)'.
- **Impacto:** El servicio puede quedar inutilizado por un error de configuración, con disco y CPU saturados.
- **Recomendación:** Etapa 1: leer con ReadInteger y un valor por defecto, y crear las listas antes de leer el ini. Activar SSocketOG en ServiceExecute dentro de un try/except que registre el error una sola vez y reintente cada 30 s desde TimerTimeout. Responder al driver antes de cualquier operación que pueda fallar, o en un finally. Alinear el .dfm a 1004.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="E2E-40"></a>
#### E2E-40 · 🟡 Media · protocolo · deuda_tecnica — Cada driver formatea Resultado a su manera y no todos cubren los mismos comandos

- **Ubicación:** `IgasDispensarios/UIGASTRITON.pas` líneas 759-818
- **Módulos afectados:** UIGASTRITON.pas, UIGASBENNETT.pas, UIGASTEAM.pas, UIGASHONGYANG.pas
- **Se atiende en:** [E1.1](../PLAN_OPTIMIZACION.md#e11--triton-recuperar-el-sondeo-tras-perder-el-bridge-y-atender-nothingstart), [E5.4](../PLAN_OPTIMIZACION.md#e54--comandos-homogéneos-entre-marcas), [E7.3](../PLAN_OPTIMIZACION.md#e73--updispcomandospas-tabcmnd-despacho-y-resultados)
- **Verificación:** sin verificación independiente
- **Qué pasa:** AUTHORIZE devuelve 'True|<FolioCmnd>|' en Wayne, Wayne 2W, Bennett y los demás, pero 'True|' en Triton (L807). Triton además escribe al puerto serial (ComandoConsola) desde el manejador del socket, quizá mientras el ciclo espera otra respuesta, y su PRICES hace Sleep(100) por producto dentro de ClientSocket1Read. Algunos resultados no llevan el '|' final: 'False|Posicion se encuentra deshabilitada' en Triton L811 y GuardarLog en Bennett L1966. Solo Bennett interpreta PARAMETERS (CounterToPaySale, L2561-2576). Team tiene manejadores de TRANSACTION y STATUS (L445-448) que el Bridge nunca le envía. HongYang no implementa STOP ni START y responde 'Comando desconocido'.
- **Evidencia:** Triton L805-807: 'ComandoConsola('AP'+...); AddPeticionJSON(folio, 'True|')'. Triton L774: 'Sleep(100)' dentro de IniciaPrecios. UIGASBENNETT.pas L1966. UIGASTEAM.pas L445-448.
- **Impacto:** OpenGas necesita casos especiales por marca, y en Triton hay riesgo de intercalar tramas seriales.
- **Recomendación:** Etapas 2/6: una tabla de comandos en el contrato con el formato exacto de Resultado por comando ('True|<boleto>|' o 'False|<mensaje>|'), y una función común FormatoResultado que garantice el '|' final. Prohibir E/S serial y Sleep dentro de ClientSocket1Read, y encolar con EjecutaComando como ya hacen Wayne 2W y Team.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="E2E-41"></a>
#### E2E-41 · 🟡 Media · mantenibilidad · deuda_tecnica — El código de protocolo está duplicado en 9 drivers, y las copias ya divergieron

- **Ubicación:** `IgasDispensarios/UIGASWAYNE2W.pas` líneas 534-557, 3215-3297, 3828-3838, 3892-4064
- **Módulos afectados:** UIGASWAYNE2W.pas, UIGASWAYNE.pas, UIGASBENNETT.pas, UIGASGILBARCO.pas, UIGASHONGYANG.pas, UIGASPAM.pas, UIGASTEAM.pas, UIGASTRITON.pas, UIGASKAIROS.pas
- **Se atiende en:** [E7.1](../PLAN_OPTIMIZACION.md#e71--updisplogpas-logger-común), [E7.2](../PLAN_OPTIMIZACION.md#e72--updispenlacepas-conexión-framing-pingjson-peticiones-y-reconexión), [E7.3](../PLAN_OPTIMIZACION.md#e73--updispcomandospas-tabcmnd-despacho-y-resultados)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Cada driver tiene su propia versión de ClientSocket1Read (el despacho de comandos), Timer2Timer (la reconexión), Responder, AddPeticionJSON, ActualizaCampoJSON, SetEstadoJSON, ApplyTotalLitrosToJSON, AgregaLog y AgregaLogPetRes, EjecutaComando, ResultadoComando y RespuestaComando, y GuardarLog, ObtenerLog, Login y Logout. Las copias ya divergieron: falta NOTHING en Triton; ResultadoComando revisa solo 40 entradas en tres drivers; ApplyTotalLitrosToJSON busca la posición por índice en Wayne y Gilbarco y por DispenserId en los demás; SetEstadoJSON en INITIALIZE solo está en Team y PAM; Responder maneja los errores de distinta forma; y el comando '0'/'1' solo existe en dos drivers. Cada corrección de este plan habría que repetirla de 8 a 9 veces.
- **Evidencia:** Ver bloques_duplicados.
- **Impacto:** El costo y el riesgo de cada cambio se multiplican, y aparecen inconsistencias de contrato entre marcas.
- **Recomendación:** Etapa 6: crear UPDispEnlace.pas (una clase TEnlaceBridge con la conexión, el framing, PING/JSON, Peticiones, la reconexión y los logs) y UPDispComandos.pas (TabCmnd, EjecutaComando, ResultadoComando, RespuestaComando y un despacho genérico con callbacks por marca). Migrar los drivers uno por uno, validando cada uno con el simulador.
- **Esfuerzo:** L · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="E2E-42"></a>
#### E2E-42 · ⚪ Baja · configuracion · riesgo — Configuración de puertos y ejemplos inconsistentes

- **Ubicación:** `IgasDispensarios/PDISPENSARIOS.ini` líneas 1-6
- **Módulos afectados:** PDISPENSARIOS.ini, UIGASKAIROS.pas, UIGASBRIDGE.pas
- **Se atiende en:** [E0.5](../PLAN_OPTIMIZACION.md#e05--configuración-documentada-y-validada-al-arrancar), [E8.4](../PLAN_OPTIMIZACION.md#e84--documentación)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El ini de ejemplo trae Marca=5 y Puerto=1001 (que es un parámetro de Kairos) pero no incluye ServidorSocket. Kairos escucha en el 1001, igual que el PuertoOG del Bridge. Los .dfm de los drivers traen Port=0, y el de Gilbarco Host 127.0.0.1 con puerto 8585; solo se corrigen en ServiceExecute.
- **Evidencia:** PDISPENSARIOS.ini: '[CONF] Marca=5 ... Puerto=1001'. UIGASGILBARCO.dfm: 'Port = 8585'. UIGASKAIROS.pas L393.
- **Impacto:** Instalaciones mal configuradas que son difíciles de diagnosticar.
- **Recomendación:** Etapa 1: una plantilla de ini documentada por marca, y una validación al arrancar que registre el host y el puerto efectivos y avise de conflictos con un bind de prueba.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="E2E-43"></a>
#### E2E-43 · ⚪ Baja · mantenibilidad · deuda_tecnica — Campos muertos y bloques triplicados en el Bridge

- **Ubicación:** `IgasDispensariosBridge/UIGASBRIDGE.pas` líneas 36, 73, 381-382, 590-598, 625-633, 708-716
- **Módulos afectados:** UIGASBRIDGE.pas
- **Se atiende en:** [E7.2](../PLAN_OPTIMIZACION.md#e72--updispenlacepas-conexión-framing-pingjson-peticiones-y-reconexión), [E8.3](../PLAN_OPTIMIZACION.md#e83--código-muerto-variables-globales-y-duplicación-interna)
- **Verificación:** sin verificación independiente
- **Qué pasa:** cmdAnt y horaPeticion se asignan y nunca se leen. TPeticionQueue declara un campo ListaPeticiones que no se usa. El bloque que avisa de datos obsoletos aparece tres veces. La sección crítica de la cola no hace falta porque todo corre en el hilo del servicio; no estorba, pero sugiere un modelo de hilos que no existe.
- **Evidencia:** L36: 'cmdAnt:string'; L381-382 lo asignan sin que nadie lo lea. L73: 'ListaPeticiones : TPeticionQueue' dentro de la clase. L590-598, L625-633 y L708-716 son el mismo bloque.
- **Impacto:** Confunde a quien mantiene el código.
- **Recomendación:** Etapa 6: una función común VerificaObsoleto(const cmd): string, eliminar los campos muertos y documentar el modelo de hilos al principio de la unidad.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="E2E-44"></a>
#### E2E-44 · ⚪ Baja · memoria_recursos · bug — El árbol JSON que se parsea en INITIALIZE y en PARAMETERS nunca se libera

- **Ubicación:** `IgasDispensarios/UIGASWAYNE2W.pas` líneas 821
- **Módulos afectados:** UIGASWAYNE2W.pas, UIGASHONGYANG.pas, UIGASBENNETT.pas, UIGASGILBARCO.pas, UIGASPAM.pas, UIGASTEAM.pas, UIGASTRITON.pas, UIGASWAYNE.pas, UIGASKAIROS.pas
- **Se atiende en:** [E2.7](../PLAN_OPTIMIZACION.md#e27--initialize-idempotente-y-seguro-con-ventas-en-curso)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Ni Inicializar (en todos los drivers) ni Parametros (en Bennett) liberan el TlkJSONbase que devuelve ParseText: cada INITIALIZE pierde el árbol de configuración completo.
- **Evidencia:** UIGASWAYNE2W.pas L821: 'js := TlkJSON.ParseText(...)' sin js.Free. UIGASHONGYANG.pas L574. UIGASBENNETT.pas L2566.
- **Impacto:** Una fuga de memoria pequeña por cada INITIALIZE.
- **Recomendación:** Etapa 1: envolverlo en try/finally con js.Free.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="E2E-45"></a>
#### E2E-45 · ⚪ Baja · correccion · bug — TRANSACTION y STATUS dependen de la configuración regional y no cortan la búsqueda

- **Ubicación:** `IgasDispensariosBridge/UIGASBRIDGE.pas` líneas 678-683, 722-734
- **Módulos afectados:** UIGASBRIDGE.pas
- **Se atiende en:** [E3.2](../PLAN_OPTIMIZACION.md#e32--validación-del-snapshot-de-las-peticiones-y-de-los-parámetros)
- **Verificación:** sin verificación independiente
- **Qué pasa:** FormatFloat usa el DecimalSeparator del sistema: en un Windows con coma decimal la respuesta saldría '12,345'. El bucle de TRANSACTION no hace Break, así que si hubiera un DispenserId duplicado (como pasaba antes de 6b4f482) se queda con el último. STATUS con una xpos mayor que maxPos responde 'False|' sin mensaje.
- **Evidencia:** L729-730: 'FormatFloat('0.000', ...)' sin TFormatSettings. L722-734: el bucle continúa después de encontrar la posición. L679-680.
- **Impacto:** Respuestas que OpenGas no puede interpretar en equipos con otra configuración regional.
- **Recomendación:** Etapa 1: usar FormatFloat con un TFormatSettings fijo (DecimalSeparator='.'), hacer Break al encontrar la posición y responder 'False|Posicion no existe|'.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

