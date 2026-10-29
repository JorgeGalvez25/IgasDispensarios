# Hallazgos · TEA · Driver Team (Marca 3) · UIGASTEAM.pas

> Anexo del [plan de optimización](../PLAN_OPTIMIZACION.md). Código auditado: `IgasDispensarios@26ccfb4`, `IgasDispensariosBridge@99edafd`. Las líneas pueden haber cambiado: ubica las rutinas por su nombre.

## Cómo funciona este módulo

Togcvdispensarios_team es el TService que maneja dispensarios Team por serial. Usa un TApdComPort pSerial, Timer1 como motor del sondeo, Timer2 para conectarse al Bridge y TClientSocket hacia el Bridge (ServidorSocket, 127.0.0.1:1004 por defecto).

Configuración: ConfTeam (disp:lado por posición) y ProtocoloExtendido vienen del ini. CodigoTeam, TresDecimTotTeam, PausaCmndTeam, CiclosInactivasTeam y ConDigitoAjuste vienen en las variables de INITIALIZE.

Hay dos modos. En el normal se sondea con A3 (bits de estatus), se lee el display con A1 (solo pesos; el volumen se calcula como importe/LPrecios) y los totales con A9. En el extendido (ProtocoloExtendido=Si) se sondea con A4 (código ss, producto, volumen e importe), se bloquea físicamente con A0 modo 15 y se controlan válvulas con A8 (DVC/REANUDAR).

Las respuestas seriales (pSerialTriggerAvail) se arman por longitud y se convierten en 'líneas sintéticas' (B/A/S/U/N). ProcesaLinea las procesa con una máquina de pasos NumPaso 1..4: B, luego A1, luego estatus+A9, luego ProcesaComandos. Los comandos de OpenGas se guardan en TabCmnd (EjecutaComando) y los ejecuta ProcesaComandos, que solo revisa los slots 1..40.

El estado se publica en rootJSON (TlkJSON). Timer1 lo manda completo cada 750 ms; Timer2 cada ~200 ms mientras el servicio no corre. Los resultados viajan en Peticiones[] (máximo 2).

Hilos (verificado): ClientSocket1.Active:=True se ejecuta en Timer2Timer (línea 362), que corre en el hilo principal porque el módulo se crea con Application.CreateForm. Por eso el HWND del socket se crea en el hilo principal y ClientSocket1Read/Connect/Disconnect corren en el mismo hilo que los timers. Certeza alta. Los eventos de Async Pro casi seguro también llegan al hilo principal (certeza media). Conclusión: en Team NO hay concurrencia real socket-contra-timers sobre rootJSON/TPosCarga.

Los riesgos reales son otros: (a) reentrancia por EsperaMiliSeg, que según el comentario de la línea 1516 bombea mensajes; (b) bloqueos del hilo principal (bucle Sleep de 1 s al reconectar, waits de 500 ms, SaveToFile de logs grandes); (c) la carrera de arranque entre Timer2, ya activo desde el DFM, y ServiceExecute, que corre en el hilo del servicio.

Hallazgos más graves: fin de venta falso por finventa=1 sin despacho; volumen final por totalizador sin validar (TotalLitrosInicio en 0 o desfasado); desborde de la línea sintética A con 1000 L o más; corrección de fin de venta que no llega al JSON; comandos en slots 41..200 que nunca se ejecutan; STOP sin efecto en modo normal; cambio de precios sin verificación.

### Ciclo serial

Motor: Timer1. El DFM le da 250 ms; Inicializar lo cambia a Max(15,Min(PausaCmnd,50)), es decir 50 ms con PausaCmnd=50 por defecto. Lo habilitan Iniciar y Timer2 (si estado>0). Además se vuelve a habilitar sin condición en el finally de ComandoConsola (1609-1611) y de pSerialTriggerAvail (2768-2770).



Cada tick de Timer1Timer (2281-2380):

1) Watchdog. Si hay comandos en ListaCmnd o se está esperando un cambio de precio, refresca HoraComandoB y HoraRspB. Si pasan más de 5 s sin enviar B o sin recibir A3/A4 hace 'Reset': vacía ListaCmnd, cierra el COM, EsperaMiliSeg(500), reabre e incrementa ContB. Si ContB>3 llama Detener, Terminar y Shutdown (apaga el servicio). El primer tick después de RUN siempre hace Reset porque HoraComandoB=0.

2) Si Now<HoraFinEsperaU (1250 ms después de cada 'U') sale.

3) Si SwEsperaRsp y han pasado ≤750 ms (MaxEsperaRspMs) desde el envío, sale; si no, da la respuesta por vencida.

4) Pausa mínima de PausaCmnd desde HoraUltRsp.

5) Si SwComandoB: envía UN 'B' (A3, o A4 en extendido) para la siguiente posición que cumpla SondearPosicion. Las posiciones despachando, con lectura final, totales pendientes, SwA o actividad en los últimos 10 s se sondean en cada ciclo; las inactivas o sin comunicación, cada CiclosInactivas=3 ciclos. Al terminar el recorrido arma la línea sintética 'B00'+posactual+estatus (estatus:=0 si ContEsperaB>=3) y llama a ProcesaLinea. NumPaso: 1 B -> 2 encola A1 de pesos (solo modo normal) para posiciones despachando, que cambiaron o con lectura final (esta va al frente) -> 3 arma el estatus de todas las posiciones, actualiza Estatus en el JSON y encola A9 (en extendido solo si EstadoTeam está en 3/6/9/12/15) -> 4 ProcesaComandos -> 1. Si quedan comandos en ListaCmnd no avanza de paso.

6) Si no, saca y envía ListaCmnd[0].

7) Si no, llama ProcesaComandos y arranca un ciclo nuevo.

finally: JSON cada 750 ms.



Envío (ComandoConsola 1482-1612): usa las globales LinCmnd/CharCmnd. Arma la trama hex 'Ax dd 00 len ...' más el checksum (suma BCD del payload mod 100), pone SwEsperaRsp y HoraEnvioCmnd y escribe con pSerial.OutPut. Los presets 'S'/'L' apagan Timer1 y hacen EsperaMiliSeg(500) antes de enviar.



Recepción (pSerialTriggerAvail 2383-2771): concatena carácter por carácter en LineaBuff. El armador acepta un encabezado de $A0 a $EF, el byte de dispensario, un 00 y un byte de longitud BCD dd; la trama está completa con 4+dd bytes. Procesa UNA trama por evento; el resto queda en LineaBuff hasta que lleguen más datos. Linea/LineaBuff no se limpian al vencer el timeout ni hay tope a dd. '66 66' es rechazo; para A9 se reintenta hasta 5 veces. Cualquier respuesta completa limpia SwEsperaRsp y fija HoraUltRsp. Tipos: A3 (bits de estatus; detección de inicio y fin y captura del totalizador inicial), A1 (pesos; volumen=importe/LPrecios; línea sintética 'A' a ProcesaLinea), A5 (preset; 'S'/'L' sin efecto), A6 (precios; 'U', sin verificar), A9 (totales; 'N' usando AuxCmndN del último comando enviado), A4 (ss/producto/volumen/importe; estatus, correcciones y fin de venta), A8 (solo log).



Tiempos efectivos: cada comando cuesta lo que tarde el dispensario más PausaCmnd (≥50 ms, con granularidad de timer de ~50 ms), unos 100-150 ms. Una posición que no responde cuesta 750 ms cada vez que se sondea. Un ciclo con 8 posiciones activas en modo A1 tarda ~1.5-2.5 s (B más A1 por posición). Cada cambio de precio pausa el sondeo 1.25 s por posición (no por dispensario). Cada preset bloquea el hilo 500 ms (o bombea mensajes). No hay esperas con Sleep en el ciclo serial, pero sí EsperaMiliSeg (en ComandoConsola S/L y en el Reset) y un bucle de Sleep de ~1 s en Timer2Timer.

### Contrato con el Bridge, visto desde este módulo

- **Conexión:** TClientSocket ctNonBlocking. Host y puerto salen de PDISPENSARIOS.ini [CONF] ServidorSocket (default '127.0.0.1:1004'; StrToInt sin default, líneas 301-302). El DFM deja Port=0 y Timer2 habilitado (Interval 200), así que Timer2 puede dispararse antes de que ServiceExecute asigne Host/Port. La conexión la abre Timer2Timer (línea 362, hilo principal). OnConnect pone conectado:=True (340-344). OnDisconnect pone conectado:=False, Timer1 deshabilitado y Timer2 habilitado (346-352), así que el sondeo serial se detiene mientras no hay Bridge. No hay manejador OnError: un ESocketError (p.ej. 10061 conexión rechazada) se propaga al manejador global de la aplicación de servicio.
- **Ciclo de envío:** Con el servicio detenido o sin inicializar (estado<=0) o sin conexión, Timer2 cada 200 ms (más ~1 s de espera si no está conectado) manda PING o el JSON completo (370-373), y se rehabilita en el finally (387). Con estado>0, Timer2 cede el control a Timer1 (375-379). Timer1 hace ticks de 15-50 ms y en su finally manda TlkJSON.GenerateText(rootJSON) cuando pasan MsEnvioJSON=750 ms desde el envío anterior (2366-2371). Este envío no está ligado al ciclo serial ni a la llegada de la respuesta del Bridge, y no revisa 'conectado'. El Bridge contesta cada mensaje con un comando 'folio\|DISPENSERS\|CMD\|params' o con '0\|DISPENSERS\|NOTHING'. ClientSocket1Read procesa el comando de forma síncrona y deja el resultado en Peticiones, que sale en el siguiente envío de Timer1 (hasta 750 ms después).
- **PING vs JSON:** PING solo mientras respJson=False, es decir, hasta la primera llamada a AddPeticionJSON. Como el Bridge contesta NOTHING y NOTHING llama a AddPeticionJSON(0,'True\|') (417-418), después del primer intercambio respJson queda True para siempre (559; nunca se regresa a False). A partir de ahí Timer2 y Timer1 mandan siempre el JSON completo. Por eso en Team no aplica el caso de 'PING indefinido' que motivó el auto-kick TRACE del Bridge.
- **Peticiones:** AddPeticionJSON (535-564) crea Peticiones si no existe, borra los primeros elementos hasta dejar 1 y agrega {Folio, Resultado}: siempre hay como máximo 2 resultados. La lista nunca se vacía después de enviarse; un resultado se reenvía en cada JSON hasta que lo desplazan dos AddPeticionJSON posteriores (normalmente dos NOTHING, unos 1.5 s). Cada NOTHING agrega {Folio:0,'True\|'}. Las excepciones se tragan en silencio (560-563). Formato de Resultado: 'True\|...\|' o 'False\|mensaje\|'. Hay una excepción: el mensaje 'Favor de configurar los lados de los dispensarios Team' (853) va sin el prefijo 'False\|'.
- **Reconexión:** Timer2Timer (354-389): si no está conectado ejecuta ClientSocket1.Active:=True y espera en un bucle 'for i:=0 to 100 do begin Sleep(10); if conectado then Break; end'. Como el socket y el timer comparten el hilo principal, OnConnect no puede ejecutarse dentro del bucle. Resultado: se bloquea ~1.01 s, sale con Exit y la conexión se marca hasta el siguiente tick (~200 ms después). No hace Active:=False ni socketResponse:=nil antes de reintentar (Bennett 581-588 y Wayne2W sí lo hacen) y no tiene OnError. Mientras el Bridge está caído: un intento cada ~1.2 s, el hilo principal bloqueado ~80% del tiempo, Timer1 apagado (sin sondeo serial) y una excepción de socket por intento enviada al manejador global (Event Log). También es posible (certeza media, según la implementación de ScktComp de D7) que cada Open sobre un socket fallido deje un handle sin cerrar.
- **Comandos:**
  - NOTHING -> AddPeticionJSON(folio 0,'True\|') (417-418)
  - INITIALIZE json\|variables -> Inicializar: reinicia si estado>-1, lee variables CONDIGITOAJUSTE/TRESDECIMTOTTEAM/CODIGOTEAM/PAUSACMNDTEAM/CICLOSINACTIVASTEAM, IniciaPSerial (Consoles[0].Connection), AgregaPosCarga (ConfTeam), Products->LPrecios[ProductId] sin validar rango (621-703)
  - PARAMETERS -> 'True\|' sin hacer nada (421-422)
  - LOGIN usuario\|md5 -> compara con MD5(usuario\|yyyy-mm-ddThh:nn), devuelve Token que nunca se valida (1037-1049)
  - LOGOUT -> borra Token (1051-1055)
  - PRICES p1\|p2\|p3\|p4 -> CPREC: actualiza LPrecios[1..4] y encola 'U' (A6) por cada posición; responde True si EjecutaComando>0, sin confirmar en la bomba (1057-1068, 2151-2196)
  - AUTHORIZE pos\|comb\|importe\|litros\|finv -> OCL si litros>0, si no OCC con importe; finv '0'->1 (esperar FINV), cualquier otro valor->0; responde 'True\|folioCmnd' antes de enviar el preset (902-937)
  - STOP pos -> DVC: A8 '00' solo con ProtocoloExtendido y despachando; en modo normal no hace nada y responde True (939-951, 1997-2007)
  - START pos -> REANUDAR: A8 '02' solo en extendido y si antes se usó DVC (967-979, 2009-2018)
  - SELFSERVICE pos(0=todas) -> AMP: 'C' = A0 modo 06 (981-1007, 2020-2034)
  - FULLSERVICE pos(0=todas) -> DMP: 'D' = A0 modo 09; pone ModoOpera:='Prepago' por error (1009-1035, 2036-2049)
  - BLOCK pos(0=todas) -> SwDesHabilitado:=True; en extendido BloqueoFisico (A0 modo 15, diferido hasta que la posición quede libre) (1070-1099)
  - UNBLOCK pos(0=todas) -> SwDesHabilitado:=False; en extendido DesbloqueoFisico (A0 con el ModoTeam previo, o 09) (1101-1130)
  - PAYMENT pos -> FINV: finventa:=0 y fuerza A9 si la posición está en 1/7 (953-965, 2102-2118)
  - TRANSACTION pos -> TransaccionPosCarga (1168-1191): código muerto, el Bridge lo contesta desde el snapshot
  - STATUS pos -> EstadoPosiciones con LinEstadoGen[xpos] sin validar rango (1193-1213): código muerto, lo contesta el Bridge
  - STATE -> está en TMetodos pero no en el case: cae en 'False\|Comando desconocido\|' (lo contesta el Bridge)
  - TOTALS pos -> 'True\|0\|0\|0\|0\|0\|0\|folioCmnd\|'; los totales reales se piden con RESPCMND (1215-1231, 2119-2150)
  - RESPCMND folio -> busca en TabCmnd[1..40]: 'True\|vol1\|imp1\|vol2\|imp2\|vol3\|imp3\|' o 'False\|*\|' (1343-1361, 3004-3011)
  - HALT -> Detener: cierra el puerto, Timer1 off, Timer2 on, estado 0; no limpia la cola (1233-1254)
  - RUN -> Iniciar: abre el puerto, estado 1, Timer1 on; validación HASP comentada (1256-1314)
  - SHUTDOWN -> ServiceThread.Terminate si estado<=0 (1316-1324)
  - TERMINATE -> cierra el puerto, LPrecios:=0, estado -1 (1326-1341)
  - TRACE -> GuardarLog: SaveToFile de ambos logs y devuelve la ruta (1363-1374)
  - SAVELOGREQ -> GuardarLogPetRes (1376-1385)
  - LOG n / LOGREQ n -> últimas n+1 líneas concatenadas con '\|' (1387-1409)
  - 'folio\|DISPENSERS\|0' y '1' (mensaje legado de 1 carácter que el Bridge encola con comando '1') -> no se manejan: 'False\|Comando desconocido\|' (PAM y Wayne sí lo manejan)
- **Campos JSON:**
  - Estado (Integer: -1 sin inicializar, 0 detenido, 1 corriendo) - SetEstadoJSON
  - PosCarga[].DispenserId (Integer)
  - PosCarga[].HoraOcc (string 'yyyy-mm-ddThh:nn'; el ':' depende de TimeSeparator) - se actualiza en cada A1 y en A4 cuando cambian volumen o importe
  - PosCarga[].Manguera (TMang[PosActual])
  - PosCarga[].Combustible (CombustibleEnPosicion)
  - PosCarga[].Estatus (0 sin comunicación/9/desconocido, 1 inactivo, 2 cargando (5, 8 o lectura final pendiente), 3 fin de carga (7 sin swcargando), 5 llamando (3,4), 7 deshabilitado (SwDesHabilitado), 8 detenido (6), 9 autorizado (2))
  - PosCarga[].Importe (float, del display)
  - PosCarga[].Volumen (float; en modo A1 = importe/LPrecios, o diferencia de totalizador al cerrar)
  - PosCarga[].Precio (float = LPrecios[comb], no lo lee de la bomba)
  - PosCarga[].Hoses[].HoseId / ProductId / Total (TotalLitros[k], A9 /100 o /1000 según TresDecimTotTeam)
  - Peticiones[].Folio (Integer, incluye entradas con 0 por NOTHING)
  - Peticiones[].Resultado (string 'True\|...\|'/'False\|...\|')
- **Desviaciones respecto a otros drivers:**
  - El JSON se envía por tiempo (750 ms) en el finally de Timer1, sin revisar 'conectado' ni el avance del ciclo. Triton (UIGASTRITON.pas:1231) y Wayne (UIGASWAYNE.pas:1386) lo envían después de cada trama procesada; Wayne2W (UIGASWAYNE2W.pas:2958) por turno y solo si conectado.
  - ProcesaComandos y ResultadoComando recorren solo TabCmnd[1..40] (1981, 3008), mientras EjecutaComando asigna 1..200. Bennett, Wayne, Wayne2W, PAM, HongYang y Triton recorren 200.
  - La reconexión no hace Active:=False/Sleep(500) ni limpia socketResponse en Disconnect, a diferencia de Bennett (311-318, 581-588) y Wayne2W (3899-3906).
  - No maneja el mensaje legado '0'/'1' (pausar/reanudar) que sí atienden PAM (385-407) y Wayne (2781-2803).
  - AddPeticionJSON y ActualizaCampoJSON tragan errores sin registrar nada; las variantes de Bennett y Wayne2W los registran y llaman a GuardarLog.
  - Conserva manejadores locales de TRANSACTION y STATUS que el Bridge nunca reenvía.
  - La conversión finventa=1 -> estatus 8/7 no exige que haya habido despacho. HongYang lo exige con swfinventa (UIGASHONGYANG.pas:1307, 1338) y Wayne2W con volumen>0 (UIGASWAYNE2W.pas:2733).
  - STOP/START solo funcionan con ProtocoloExtendido; en modo normal responden True sin hacer nada.
  - Parte de la configuración va en el ini local (ConfTeam, ProtocoloExtendido) y parte en las variables de INITIALIZE (CodigoTeam, TresDecimTotTeam, PausaCmndTeam, CiclosInactivasTeam, ConDigitoAjuste).
  - El puerto default del driver (1004) coincide con el default del código del Bridge, pero el .dfm del Bridge dice 1002. Si el ini del Bridge no lo fija, no conectan.

### Bloques duplicados con otros módulos

| Rutina | Líneas | Nota |
|---|---|---|
| ServiceController / GetServiceController / ServiceExecute | 283-332 | Plantilla del TService que se repite en todos los drivers: lee PDISPENSARIOS.ini (RutaLog, ServidorSocket, Licencia, MinutosLog), crea ListaCmnd, ListaLog, ListaLogPetRes y rootJSON, y entra al bucle ProcessRequests. Team agrega ConfTeam y ProtocoloExtendido. Mismos defectos que los demás: StrToInt sin default y TIniFile sin liberar. |
| ClientSocket1Connect / ClientSocket1Disconnect | 340-352 | Casi idénticos en Bennett 311-318, Gilbarco 3064-3069, HongYang 408-414, PAM 361-367, Triton 322-328 y Wayne 2909-2915. Bennett además pone socketResponse:=nil. |
| Timer2Timer | 354-389 | Variante del de Bennett 575-610, Wayne2W 3892-3930, PAM 319, Triton 330, Wayne 2917, HongYang 2025 y Gilbarco 3071. Team no hace Active:=False/Sleep(500) ni socketResponse:=nil antes de reconectar. |
| ClientSocket1Read (despachador TMetodos) | 391-480 (enum TMetodos 245-249) | El mismo dispatcher con GetEnumValue sobre TMetodos (enum copiado del Bridge) está en todos los drivers que hablan con el Bridge. Diferencias: Bennett llama Parametros(folio,...) y actualiza horaAct; PAM y Wayne manejan además el comando '0'/'1'; Team conserva TRANSACTION y STATUS. |
| Responder | 482-499 | Idéntico (normalizado) en UIGASWAYNE, UIGASPAM y UIGASTRITON; variantes en Bennett, Wayne2W, HongYang y Kairos (en Kairos recibe el socket). |
| ActualizaCampoJSON | 501-533 | Copia simplificada de la de Wayne2W, que registra errores y tiene un fallback por índice cuando falta DispenserId. En Team se ignoran los errores. |
| AddPeticionJSON | 535-564 | Igual a la de Bennett salvo que Bennett registra 'rootObj es nulo' y llama GuardarLog en la excepción. Misma lógica de 2 peticiones máximo en todos los drivers. |
| SetEstadoJSON | 566-577 | Idéntica (normalizada) a UIGASPAM; variantes menores en los demás. |
| ApplyTotalLitrosToJSON | 579-617 | La misma rutina (TotalLitros en base 0 hacia Hoses[].Total) en todos los drivers, con diferencias de formato. |
| Inicializar / LiberaInicializacion / AgregaPosCarga | 621-900 | Esqueleto común: parsea Consoles, Dispensers y Products, llama IniciaPSerial, crea el nodo PosCarga y los Hoses y carga LPrecios. La reinicialización (6b4f482) se agregó en todos los drivers. Team mapea con ConfTeam disp:lado y TPos/TMang por HoseId. |
| AutorizarVenta / DetenerVenta / FinVenta / ReanudarVenta / ActivaModoPrepago / DesactivaModoPrepago | 902-1035 | Wrappers que traducen a comandos internos OCC/OCL/DVC/FINV/REANUDAR/AMP/DMP vía EjecutaComando. El parseo de AUTHORIZE (con la inversión de finv) es idéntico en Bennett 2069-2074, HongYang 1215-1220, Kairos 1472-1477, PAM 2101-2106 y Wayne 2322. |
| Login / Logout / MD5 | 1037-1055, 3052-3062 | Login y Logout idénticos a Bennett, PAM y HongYang. MD5 idéntico a Bennett, Wayne, Wayne2W, PAM, Triton y Kairos. |
| IniciaPrecios / Bloquear / Desbloquear / TransaccionPosCarga / EstadoPosiciones / TotalesBomba | 1057-1130, 1168-1231 | Mismos manejadores de comando en los demás drivers. TotalesBomba es textualmente igual a Wayne2W, Bennett y Gilbarco ('True\|0\|0\|0\|0\|0\|0\|folio'). Team agrega BloqueoFisico/DesbloqueoFisico. |
| Detener / Iniciar / Shutdown / Terminar / RespuestaComando | 1233-1361 | Shutdown es idéntico en Wayne, Wayne2W, PAM, HongYang y Triton. Terminar es idéntico en Wayne, PAM y HongYang. Iniciar trae el mismo bloque HASP comentado que los demás. |
| GuardarLog / GuardarLogPetRes / ObtenerLog / ObtenerLogPetRes | 1363-1409 | La misma lógica de SaveToFile con nombre por timestamp y de concatenar las últimas n líneas en todos los drivers (variantes por el nombre del módulo de InfoVersionModulo). |
| AgregaLog / AgregaLogPetRes / FechaHoraExtToStr | 1412-1443 | El mismo escape de caracteres de control carácter por carácter y el límite de 10000 líneas en todos los drivers (Wayne2W lo envuelve en try/except). FechaHoraExtToStr es idéntico a Bennett y PAM. |
| IniciaPSerial | 1445-1480 | El mismo parseo de 'Connection' (COMn, baudios, paridad, bits de datos y de paro) en todos los drivers con diferencias menores. |
| EjecutaComando / ResultadoComando / tablas TabCmnd y RegCmnd | 2234-2266, 3004-3011, 235-243, 254 | EjecutaComando es idéntico a PAM y Kairos. ResultadoComando es idéntico a Kairos (1..40); los demás recorren 1..200. |
| ExtraeElemStrEnter / NoElemStrEnter | 3013-3050 | NoElemStrEnter es idéntico en Bennett, Wayne, Wayne2W, PAM y Kairos. ExtraeElemStrEnter es idéntico a PAM. Deberían estar en ULIBGRAL. |
| CRC16 | 1629-1641 | Idéntico a Kairos; en Team no se usa. |
| ComandoConsolaBuff / CombustibleEnPosicion / PosicionDeCombustible / EnviaPreset / StrToHexSep / HexSepToStr / HexToBinario | 1614-1627, 2268-2279, 2933-2946, 2981-3002, 2901-2956 | Patrones comunes a los drivers legados (cola ListaCmnd, búsqueda de combustible por posición, utilerías hex). PosicionDeCombustible devuelve el código de combustible y no el índice; solo se usa como booleano. |
| Records tiposcarga y RegCmnd y globales TPosCarga[1..100] / TabCmnd[1..200] / LPrecios[1..4] | 162-243, 251-275 | Estructura copiada de driver a driver con campos acumulados que ya no se usan (aros_*, swarosmag, Boucher, TCodigoTeam, etc.) y globales heredadas (AvanceBar, SwSolOk, ContDA, StErrSol, ruta_db, Licencia3Ok). |

## Hallazgos (36)

<a id="TEA-01"></a>
#### TEA-01 · 🔴 Crítica · correccion · bug — Fin de venta falso: finventa=1 se convierte en estatus 8/7 aunque no haya habido despacho

- **Ubicación:** `UIGASTEAM.pas` líneas 2065-2071, 2089-2095, 2490-2493, 2505-2510, 2707-2713, 1790-1791, 1906-1909
- **Módulos afectados:** UIGASTEAM.pas
- **Se atiende en:** [E1.2](../PLAN_OPTIMIZACION.md#e12--importes-y-volúmenes-de-venta-mal-calculados)
- **Verificación:** sin verificación independiente
- **Qué pasa:** En OCC/OCL, finventa se fija con el parámetro de AUTHORIZE ANTES de EnviaPreset, y se queda aunque EnviaPreset rechace (estatus<>1, deshabilitada) o aunque la bomba rechace el A5 (66 66) o no conteste (no hay reintento). En modo A3 cualquier sondeo en reposo con finventa=1 da estatus 8. En el siguiente sondeo estatusAnterior=8 cumple '((estatusAnterior in [5,8]) or swcargando) and (estatus in [1,7,8])', se programa la 'lectura final' A1, ProcesaLinea 'A' pone finventa:=2 y el estatus pasa a 7, que se publica como '3'. En modo A4 es inmediato: 'if (estatus=1) and (finventa=1) then estatus:=8; if estatus=8 then begin finventa:=2; estatus:=7; end;' publica '3' en el primer A4 en reposo después del OCC. HongYang (swfinventa, que solo se activa en estatus 5) y Wayne2W (volumen>0) tienen esta guarda; Team no.
- **Evidencia:** ProcesaComandos 2068-2071: 'TPosCarga[SnPosCarga].finventa:=StrToIntDef(...,6...); ... EnviaPreset(rsp,xcomb,false);'. A3 2490: 'if (estatus=1)and(finventa=1) then estatus:=8;' y 2505: 'if ((estatusAnterior in [5,8]) or swcargando) and (estatus in [1,7,8]) then SwLecturaFinalPendiente:=true'. A4 2707-2713. Comparar con UIGASHONGYANG.pas:1307 '(finventa=1)and(swfinventa)' y UIGASWAYNE2W.pas:2733 '(EsperaFinVenta=1) and (volumen>0)'.
- **Impacto:** Si un preset no se aplica (error serial, rechazo o posición ocupada), OpenGas ve 'Fin de carga' sin que haya habido despacho. Lee TRANSACTION del snapshot, que trae el importe y volumen de la venta anterior que sigue en la pantalla, y cierra el ticket prepagado con un monto equivocado o duplica una venta. Además la posición queda en 7 esperando un PAYMENT que no corresponde y bloquea los presets siguientes.
- **Recomendación:** Agregar a tiposcarga una bandera SwHuboDespacho: se pone en True al detectar estatus 5 (A3) o ss 20/21/24 (A4) y se limpia en FINV/OCC. Aplicar 'estatus:=8/7' y la detección de fin solo si SwHuboDespacho. Asignar finventa solo cuando EnviaPreset devuelva 'OK' y revertirlo si el A5 se rechaza (66 66) o vence (guardar la posición del último A5 como ya se hace con PosCmndN). Probar en banco: preset rechazado, A5 sin respuesta y A4/A3 en reposo justo después del OCC.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="TEA-02"></a>
#### TEA-02 · 🔴 Crítica · correccion · bug — Volumen final por totalizador sin validar: TotalLitrosInicio en 0 o desfasado da volúmenes absurdos o acumulados

- **Ubicación:** `UIGASTEAM.pas` líneas 1833-1846, 2498-2503, 2718-2726, 784-792, 1819-1822
- **Módulos afectados:** UIGASTEAM.pas
- **Se atiende en:** [E1.2](../PLAN_OPTIMIZACION.md#e12--importes-y-volúmenes-de-venta-mal-calculados)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Al llegar los A9 después de una venta, si SwTotalInicialVenta y SwDesp están activos, el volumen se sustituye por TotalLitros-TotalLitrosInicio sin ninguna comparación contra el display. Caso 1: AgregaPosCarga deja TotalLitros=0, SwCargaTotales=true y SwEsperandoTotales=false. Si una venta está en curso al arrancar (RUN, reinicio del servicio o INITIALIZE en operación), o empieza antes del primer A9 (en A4 el A9 se difiere hasta que EstadoTeam esté en reposo), TotalLitrosInicio se captura en 0. En A4 la guarda 'SwTotalInicialVenta:=not SwEsperandoTotales' no protege porque SwEsperandoTotales empieza en false. Al cerrar, el volumen reportado es el totalizador absoluto (millones de litros). Caso 2 (A3): si se pierde un A9 después de la venta (timeout o checksum; no hay reintento), SwTotalInicialVenta queda true y en la siguiente venta 'not SwTotalInicialVenta' impide recapturar el inicio: el volumen reportado es la suma de dos ventas. La corrección de eb15e8b solo se aplicó a la ruta A4. Caso 3: con TresDecimTotTeam mal configurado, el volumen sale multiplicado o dividido entre 10.
- **Evidencia:** 1838-1842: 'xdif:=TotalLitros[xpr]-TotalLitrosInicio[xpr]; if xdif>=0 then begin volumen:=AjustaFloat(xdif,3); ... ActualizaCampoJSON(xpos,'Volumen',volumen)'. A3 2498: 'if (estatus=5) and (not swcargando) and (not SwTotalInicialVenta) then ... TotalLitrosInicio[I]:=TotalLitros[I]'. A4 2721: 'SwTotalInicialVenta:=not SwEsperandoTotales;'. AgregaPosCarga 784-791: TotalLitros/TotalLitrosInicio:=0, SwEsperandoTotales:=false.
- **Impacto:** Volumen de la transacción equivocado en el snapshot (y en TRANSACTION hacia OpenGas): desde valores imposibles hasta ventas sumadas. Afecta controles volumétricos, inventarios, facturación por litro y auditorías (CENAM/PROFECO).
- **Recomendación:** Llevar por posición una bandera TotalesVigentes que solo se active cuando se decodifiquen todos los A9 después de la última venta. Capturar TotalLitrosInicio solo si TotalesVigentes, y en la ruta A3 usar la misma guarda que en A4 y reiniciar SwTotalInicialVenta al inicio de cada venta. Antes de sustituir el volumen, exigir |xdif - volumen_display| <= tolerancia (p.ej. max(0.5 L, 2%)); si no se cumple, registrar 'TOTALIZADOR INCONSISTENTE' y dejar el volumen del display. Probar: arrancar con una venta en curso, perder un A9 y cambiar TresDecimTotTeam.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="TEA-03"></a>
#### TEA-03 · 🔴 Crítica · correccion · bug — La línea sintética 'A' usa formatos de ancho fijo que se desbordan con 1000 L o más y corrompen importe, precio y volumen

- **Ubicación:** `UIGASTEAM.pas` líneas 2555-2565, 1746-1760
- **Módulos afectados:** UIGASTEAM.pas
- **Se atiende en:** [E1.2](../PLAN_OPTIMIZACION.md#e12--importes-y-volúmenes-de-venta-mal-calculados)
- **Verificación:** sin verificación independiente
- **Qué pasa:** En modo normal (A1), pSerialTriggerAvail convierte la lectura a un string 'A'+pos+'0'+FormatFloat('000000',volumen*1000)+FormatFloat('00000000',importe*100)+FormatFloat('0000',precio*100), y ProcesaLinea lo vuelve a parsear por posiciones fijas (copy 5,6 / 11,8 / 19,4). Con 1000.000 L o más, el campo de volumen ocupa 7 dígitos y todo se recorre: volumen=1/10, importe=1/10 y precio basura. Un precio de 100.00 o más también recorre el campo. Ese resultado es lo que se escribe en el JSON.
- **Evidencia:** 2560-2563: 'LineaTimer:=''A''+inttoclavenum(xpos,2)+''0''+FormatFloat(''000000'',volumen*1000)+FormatFloat(''00000000'',importe*100)+FormatFloat(''0000'',precio*100)'. 1746-1750: 'volumen:=StrToFloat(copy(lin,5,6))/1000; simp:=copy(lin,11,8); spre:=copy(lin,19,4)'. Ejemplo: 1000 L x 24.50 = '1000000'+'02450000'+'2450', que se lee como volumen 100.000, importe 2450.00 y precio 2.45.
- **Impacto:** Despachos grandes de diesel (tractocamiones, flotillas) se reportan con una décima del importe y del volumen: cobro incorrecto. La corrección por totalizador solo arregla el volumen, no el importe.
- **Recomendación:** No pasar la lectura por un string. Extraer de ProcesaLinea 'A' un procedimiento AplicaLecturaDisplay(xpos, vol, imp, prec) y llamarlo directo desde el manejador A1. Si hay que conservar el string por compatibilidad del log, usar separadores ('A01|vol|imp|prec') y StrToFloat con FormatSettings fijo. Probar con lecturas de 999.999, 1000.000 y 5000 L.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="TEA-04"></a>
#### TEA-04 · 🟠 Alta · correccion · bug — La corrección 'FIN DE VENTA CORREGIDO' de la ruta A1 no actualiza el JSON

- **Ubicación:** `UIGASTEAM.pas` líneas 1752-1760, 1768-1776 (vs 2730-2741)
- **Se atiende en:** [E1.2](../PLAN_OPTIMIZACION.md#e12--importes-y-volúmenes-de-venta-mal-calculados)
- **Verificación:** sin verificación independiente
- **Qué pasa:** ProcesaLinea 'A' escribe primero en el JSON la lectura nueva del display (Volumen, Importe, Precio). Después, si esa lectura final es menor que la anterior (pantalla en ceros o reinicio del display), corrige importe/volumen/precio en TPosCarga, pero ya no vuelve a escribir el JSON. El Bridge contesta TRANSACTION desde el JSON, así que la corrección nunca llega a OpenGas. La ruta A4 sí escribe el JSON después de corregir (2738-2740).
- **Evidencia:** 1757-1759: 'ActualizaCampoJSON(xpos,''Volumen'',volumen); ...Importe...; ...Precio...' y después 1769-1774: 'if (importenvo<importepre) then begin AgregaLog(''FIN DE VENTA CORREGIDO''); importe:=importepre; volumen:=volumenpre; precio:=preciopre; end' sin ActualizaCampoJSON.
- **Impacto:** Justo en el caso que la corrección quería resolver, OpenGas recibe la lectura baja o en ceros: venta reportada en 0 o por debajo de lo despachado.
- **Recomendación:** Después de la corrección, asignar importenvo/volumennvo/precionvo y llamar ActualizaCampoJSON para Volumen, Importe y Precio, igual que en 2735-2740. Mejor aún, centralizar en un solo procedimiento PublicaLectura(xpos). Probar simulando un A1 final en ceros.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="TEA-05"></a>
#### TEA-05 · 🟠 Alta · correccion · bug — ProcesaComandos y ResultadoComando solo revisan TabCmnd[1..40]: los comandos en los slots 41..200 nunca se ejecutan

- **Ubicación:** `UIGASTEAM.pas` líneas 1981, 3008-3010, 2238-2251
- **Se atiende en:** [E1.5](../PLAN_OPTIMIZACION.md#e15--tabla-de-comandos-tabcmnd-y-respuestas-de-comandos-asíncronos)
- **Verificación:** sin verificación independiente
- **Qué pasa:** EjecutaComando busca el primer slot libre en 1..200. Un slot solo se libera cuando, al buscar, se encuentra activo y con más de 1 minuto (tmMinuto); responder no lo libera. Con más de 40 comandos en un minuto (ráfagas de AUTHORIZE/PAYMENT/TOTALS, SELFSERVICE 0 que genera un AMP por posición, cierres de turno), los nuevos caen en el slot 41 o más. ProcesaComandos ('for xcmnd:=1 to 40') nunca los procesa y RESPCMND devuelve '*'. Los demás drivers, salvo Kairos/Gilbarco en ResultadoComando, recorren 200.
- **Evidencia:** 1981: 'for xcmnd:=1 to 40 do if (TabCmnd[xcmnd].SwActivo)and(not TabCmnd[xcmnd].SwResp)'. 3008: 'for i:=1 to 40 do'. 2241-2246: expiración solo dentro del repeat de EjecutaComando. Wayne2W 2014, PAM 1381 y HongYang 2070 usan 1..200.
- **Impacto:** Un AUTHORIZE, PAYMENT o STOP que el Bridge ya confirmó como True a OpenGas no se ejecuta: el cliente prepagado no recibe autorización, la posición se queda en 'fin de venta' o una parada no ocurre. No queda rastro en el log.
- **Recomendación:** Definir una constante MaxCmnd=200 y usarla en ProcesaComandos, ResultadoComando, LiberaInicializacion y EjecutaComando. Liberar el slot (SwActivo:=False) cuando RESPCMND consume la respuesta o con una expiración por antigüedad revisada en ProcesaComandos. Probar inyectando 60 comandos en 30 s.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="TEA-06"></a>
#### TEA-06 · 🟠 Alta · concurrencia · bug — Reentrancia en ComandoConsola durante EsperaMiliSeg(500) con LinCmnd/CharCmnd globales: el preset puede salir a otra posición o con monto 0

- **Ubicación:** `UIGASTEAM.pas` líneas 264-265, 1487-1488, 1515-1534, 1591-1611, 1617-1619, 2303, 2768-2770
- **Se atiende en:** [E2.5](../PLAN_OPTIMIZACION.md#e25--reentrancia-comandos-del-bridge-durante-una-transacción-serial)
- **Verificación:** sin verificación independiente
- **Qué pasa:** ComandoConsola guarda el comando en las variables globales de la unidad LinCmnd y CharCmnd y, para 'S'/'L', apaga Timer1 y llama EsperaMiliSeg(500) ANTES de leer la posición y el monto de LinCmnd. El comentario 'evita que el timer mande otro comando durante la espera' (1516) da a entender que EsperaMiliSeg bombea mensajes (ULIBGRAL no está en el repo; certeza media). En ese caso, durante la espera pueden ejecutarse: (a) pSerialTriggerAvail por una respuesta tardía, que en su finally vuelve a encender Timer1, y luego Timer1Timer manda otro comando; (b) ClientSocket1Read con BLOCK/UNBLOCK en modo extendido, que llama ComandoConsolaBuff y de ahí ComandoConsola directo; (c) ProcesaLinea, ProcesaComandos y EnviaPreset desde la respuesta tardía. Cualquier ComandoConsola anidado sobrescribe LinCmnd, y al regresar el preset se arma con 'copy(LinCmnd,2,2)'/'copy(LinCmnd,4,6)' del comando anidado. El Reset de Timer1Timer (2303) llama EsperaMiliSeg(500) sin apagar Timer1, así que Timer1Timer también puede reentrar con el puerto cerrado. Si EsperaMiliSeg no bombea mensajes, en lugar de reentrancia hay 500 ms de hilo principal bloqueado por cada preset.
- **Evidencia:** 1487-1488: 'LinCmnd:=ss; CharCmnd:=LinCmnd[1];'. 1515-1523: ''S'':begin Timer1.Enabled:=false; esperamiliseg(500); s1:=copy(LinCmnd,2,2); xpos:=strtointdef(s1,0); s1:=copy(LinCmnd,4,6); r1:=strtointdef(s1,0)/100; ... LinCmd2:=ComandoS(dispensario,lado,r1)'. 2768-2770: 'finally Timer1.Enabled:=true;'.
- **Impacto:** Si ocurre, un preset prepagado se envía a otra posición o con importe 0 (posible venta libre) y la posición correcta no se autoriza. Aunque no ocurra, la espera de 500 ms por preset retrasa respuestas y JSON.
- **Recomendación:** Pasar LinCmnd/CharCmnd a variables locales de ComandoConsola. Quitar EsperaMiliSeg: si el Team necesita una pausa antes del A5, modelarla como una marca de tiempo (igual que HoraFinEsperaU) que Timer1Timer respete. Agregar una guarda de reentrancia (FEnProceso) en Timer1Timer, ComandoConsola y pSerialTriggerAvail. Probar con presets seguidos de respuestas tardías inyectadas.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="TEA-07"></a>
#### TEA-07 · 🟠 Alta · protocolo · bug — Cambio de precios sin confirmación: LPrecios se actualiza aunque la bomba no aplique el A6, se envía un 'U' por posición e incluso a posiciones sin mangueras

- **Ubicación:** `UIGASTEAM.pas` líneas 2151-2196, 1535-1546, 1607-1608, 2313-2314, 1800-1809, 2556-2559, 2674-2680, 1057-1068
- **Se atiende en:** [E1.6](../PLAN_OPTIMIZACION.md#e16--precios-aplicar-solo-lo-confirmado)
- **Verificación:** sin verificación independiente
- **Qué pasa:** CPREC sobrescribe LPrecios de inmediato y encola un 'U' para cada posición de 1..MaxPosCarga. Como A6 es por dispensario (sin lado), cada dispensario recibe el cambio dos veces. Las posiciones sin mangueras (NoComb=0, dispensario 0) también reciben un A6 al dispensario 00 y además se lee LPrecios[TComb[1]=0] fuera de rango. Cada 'U' detiene el sondeo 1.25 s (HoraFinEsperaU): con 16 posiciones son unos 20 s sin sondear. La respuesta A6 se decodifica (xprec) pero no se compara con nada; ActualizarPrecio nunca se pone en True. Un rechazo (66 66) o un timeout no se reintenta ni se reporta, e IniciaPrecios responde True (PRICES además es fire-and-forget en el Bridge). Si los lados de un mismo dispensario tienen productos distintos, el último 'U' impone sus precios.
- **Evidencia:** 2156-2159: 'LPrecios[ii] := precioComb' antes de enviar. 2163-2194: un 'U' por posición sin revisar NoComb. 1607-1608: 'HoraFinEsperaU:=IncMilliSecond(Now,MsEsperaCambioPrecio)'. 1800-1808: xprec[] se calcula y solo hace 'ActualizarPrecio:=false'. 2557-2559 (A1): 'precio:=lprecios[xcomb]; volumen:=AjustaFloat(dividefloat(importe,precio),3)'. 2675-2676 (A4): 'precio:=lprecios[xcomb]'.
- **Impacto:** Si una bomba se queda con el precio anterior (rechazo, timeout o despacho en curso), el driver calcula el volumen (A1) y reporta el precio (A4) con el precio nuevo: importe, volumen y precio no cuadran y el volumen reportado es incorrecto hasta que entre la corrección por totalizador (si entra). Además el sondeo se congela varios segundos en cada cambio.
- **Recomendación:** Enviar un 'U' por dispensario distinto y solo para posiciones con NoComb>0. Guardar el precio pendiente por dispensario y aplicarlo a LPrecios o a un precio por posición solo cuando el A6 confirme (comparar xprec con lo enviado); reintentar en rechazo o timeout y registrar el resultado. No enviar A6 a dispensarios que estén despachando: diferirlo hasta que estén libres. Que IniciaPrecios o RESPCMND reflejen el resultado real. Probar con un rechazo simulado y con dos lados de configuración distinta.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="TEA-08"></a>
#### TEA-08 · 🟠 Alta · correccion · bug — STOP/START (DVC/REANUDAR) no hacen nada en modo normal pero responden True

- **Ubicación:** `UIGASTEAM.pas` líneas 1997-2018, 939-951, 967-979
- **Se atiende en:** [E5.4](../PLAN_OPTIMIZACION.md#e54--comandos-homogéneos-entre-marcas)
- **Verificación:** sin verificación independiente
- **Qué pasa:** DVC solo envía A8 '00' si ProtocoloExtendido y la posición está despachando; REANUDAR solo si además se paró antes con DVC. En cualquier otro caso rsp='OK' sin acción. DetenerVenta ya respondió 'True|folio' al Bridge antes de procesar nada, y el Bridge espera respuesta por folio para STOP (no es fire-and-forget), así que OpenGas recibe True.
- **Evidencia:** 2001-2004: 'if ProtocoloExtendido and ((Estatus=5) or swcargando) then begin ComandoConsolaBuff(''V''...''00'',true); SwParado:=true; end;'. Sin else. 946: 'AddPeticionJSON(folio, ''True|''+IntToStr(EjecutaComando(''DVC ''+msj))+''|'');'.
- **Impacto:** El operador o el POS creen que detuvieron un despacho (emergencia, fraude, error de preset) y la bomba sigue despachando. Riesgo operativo y de seguridad.
- **Recomendación:** En modo normal responder 'False|Detener venta no soportado sin ProtocoloExtendido|' o implementar la parada con el comando disponible (p.ej. A0 a un modo que corte el flujo, validándolo con el fabricante). En modo extendido, contestar el resultado real (RESPCMND) después de la respuesta A8. Probar STOP en ambos modos.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="TEA-09"></a>
#### TEA-09 · 🟡 Media · protocolo · bug — Con finventa=0 el estado 'Fin de carga' (3) dura un solo sondeo (A4) o nunca aparece (A3), y puede no llegar al Bridge

- **Ubicación:** `UIGASTEAM.pas` líneas 2742-2745, 2697-2702, 1902-1909, 2366-2371
- **Módulos afectados:** UIGASTEAM.pas, OpenGas
- **Se atiende en:** [E1.9](../PLAN_OPTIMIZACION.md#e19--coherencia-del-estado-publicado-estatus-fin-de-venta-horaocc-estado)
- **Verificación:** sin verificación independiente
- **Qué pasa:** En A4, al cerrar la venta se fuerza 'if estatus=1 then estatus:=7' (commit eb15e8b: 'reporta el fin de carga sin ss=30'). Pero swcargando ya quedó en false, y en el siguiente sondeo ss=3/6/9/12 o 30 dan estatus 1, así que el '3' dura un ciclo. El JSON se envía cada 750 ms, independiente del ciclo, y un ciclo con pocas posiciones activas tarda 100-300 ms: el '3' puede no llegar nunca al snapshot que se envía. En A3 con finventa=0 el estatus pasa de 5 a 1 sin pasar por 7: se publica '2' (lectura final pendiente) y luego '1'. Certeza media sobre el impacto, porque depende de cómo detecta OpenGas el fin en postpago.
- **Evidencia:** 2743-2745: 'if estatus=1 then estatus:=7;' y 2697-2701: '30: begin if swcargando then estatus:=7 else estatus:=1; end;'. 2368: el envío del JSON se decide por 'MilliSecondsBetween(Now,HoraUltJSON)>=MsEnvioJSON'.
- **Impacto:** En ventas postpago o sin espera de pago, OpenGas puede no ver el fin de carga y perder o retrasar la transacción.
- **Recomendación:** Mantener el '3' un tiempo mínimo (p.ej. HoraFinVenta+5 s, configurable) o hasta que llegue PAYMENT/TRANSACTION; o forzar un envío inmediato del JSON al cambiar a 7. Revisar con OpenGas qué transición espera. Probar con finventa=0 en ambos modos.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** sí

<a id="TEA-10"></a>
#### TEA-10 · 🟡 Media · robustez · bug — Timer1 se vuelve a encender sin condición: con el servicio detenido, un BLOCK/UNBLOCK reactiva el sondeo y el watchdog reabre el puerto

- **Ubicación:** `UIGASTEAM.pas` líneas 1609-1611, 2768-2770, 1140-1166, 1240-1250, 2292-2304
- **Se atiende en:** [E2.3](../PLAN_OPTIMIZACION.md#e23--arranque-y-paro-ordenados-del-servicio)
- **Verificación:** sin verificación independiente
- **Qué pasa:** ComandoConsola y pSerialTriggerAvail terminan con 'Timer1.Enabled:=true' sin revisar estado, detenido ni conectado. En modo extendido, BLOCK o UNBLOCK con estado 0, o -1 tras TERMINATE (MaxPosCarga no se reinicia), llaman BloqueoFisico/DesbloqueoFisico, luego ComandoConsolaBuff y ComandoConsola directo, y Timer1 arranca. A los 5 s el watchdog ejecuta 'pSerial.Open:=true': el COM queda abierto y sondeando aunque OpenGas ve STATE 0. Además Timer1 (750 ms) y Timer2 (200 ms) mandan JSON a la vez. HALT ya no puede detenerlo porque 'detenido' sigue en True ('El proceso ya habia sido detenido'). También una trama tardía después de Disconnect reactiva Timer1.
- **Evidencia:** 1609-1611: 'finally Timer1.Enabled:=true; end;'. 1164: DesbloqueoFisico llama ComandoConsolaBuff sin condiciones. 2302-2304: 'pSerial.Open:=false; EsperaMiliSeg(500); pSerial.Open:=true;'. 1240-1250: Detener solo actúa 'if not detenido'.
- **Impacto:** El puerto queda tomado y el dispensario sondeado con el servicio 'detenido' (choca con herramientas de mantenimiento o con otro proceso). Llegan JSON duplicados al Bridge y el estado reportado no es coherente.
- **Recomendación:** En ComandoConsola y pSerialTriggerAvail, restaurar Timer1 solo si (estado=1) and not detenido and conectado (guardar el valor anterior de Enabled y restaurarlo). En Bloquear/Desbloquear con estado<>1, solo marcar la bandera y diferir el A0 al RUN. En el watchdog, no reabrir si detenido. Probar UNBLOCK con el servicio en HALT.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="TEA-11"></a>
#### TEA-11 · 🟡 Media · robustez · riesgo — El sondeo serial depende de la conexión con el Bridge: al desconectarse se apaga Timer1

- **Ubicación:** `UIGASTEAM.pas` líneas 346-352, 375-379
- **Se atiende en:** [E2.1](../PLAN_OPTIMIZACION.md#e21--desacoplar-timer1-sondeo-serial-de-la-conexión-con-el-bridge)
- **Verificación:** sin verificación independiente
- **Qué pasa:** ClientSocket1Disconnect apaga Timer1, que es el único motor del sondeo, de las lecturas finales, de los totales y del watchdog. Mientras el Bridge no está (reinicio, caída), las bombas no se sondean. Si una venta termina y empieza otra durante el corte, la primera se pierde; los fines de venta se detectan tarde. El patrón está copiado en todos los drivers.
- **Evidencia:** 350: 'Timer1.Enabled:=False;'. Timer1 solo vuelve a encenderse en Timer2Timer cuando se reconecta y estado>0 (375-379).
- **Impacto:** Transacciones perdidas o con hora equivocada en cortes del Bridge de varios segundos o minutos.
- **Recomendación:** Separar el sondeo serial del envío al Bridge: Timer1 sigue sondeando y solo se omite Responder cuando not conectado; al reconectar se envía el snapshot actual. Validar reiniciando PDISPBRIDGE durante una venta.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="TEA-12"></a>
#### TEA-12 · 🟡 Media · robustez · bug — La reconexión bloquea el hilo principal ~1 s por intento, nunca ve OnConnect dentro del bucle y no limpia el socket antes de reintentar

- **Ubicación:** `UIGASTEAM.pas` líneas 354-389 (360-368); UIGASTEAM.dfm 23-32
- **Se atiende en:** [E2.2](../PLAN_OPTIMIZACION.md#e22--reconexión-no-bloqueante-y-con-manejo-de-errores)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Timer2Timer activa el socket desde el hilo principal y espera con Sleep(10)x101 a que 'conectado' cambie. Como OnConnect se despacha por mensajes en ese mismo hilo, no puede ocurrir durante el bucle: siempre se bloquea ~1.01 s y sale con Exit. Mientras tanto no se procesan eventos seriales ni timers. No hace 'Active:=False' antes de 'Active:=True' ni pone socketResponse:=nil (Bennett 581-588 y Wayne2W sí). El DFM no tiene OnError: cada conexión rechazada levanta ESocketError en el despachador de mensajes y llega al manejador global de excepciones del servicio (Event Log). Certeza media: según ScktComp de D7, cada Open sobre un socket fallido deja el handle anterior sin cerrar.
- **Evidencia:** 362-367: 'ClientSocket1.Active:=True; for i:=0 to 100 do begin Sleep(10); if conectado then Break; end; if not conectado then Exit;'. DFM: ClientSocket1 sin OnError.
- **Impacto:** Con el Bridge caído, el hilo principal pasa bloqueado ~80% del tiempo, se llena el Event Log y posiblemente se fugan handles. Además, cada reconexión tarda al menos ~1.2 s.
- **Recomendación:** Quitar el bucle de Sleep: llamar Active:=True y salir; enviar el primer mensaje en OnConnect. Agregar OnError con 'ErrorCode:=0; conectado:=False; Socket.Close' y un backoff (1-5 s). Antes de reintentar, Active:=False y socketResponse:=nil. Probar con el Bridge detenido durante 10 minutos, revisando handles en Process Explorer y el Event Log.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="TEA-13"></a>
#### TEA-13 · 🟡 Media · protocolo · bug — Armado de tramas: los fragmentos sobreviven al timeout, no hay tope de longitud y se procesa una sola trama por evento

- **Ubicación:** `UIGASTEAM.pas` líneas 2393-2429, 2316-2320, 2451-2454, 2617
- **Se atiende en:** [E2.8](../PLAN_OPTIMIZACION.md#e28--recepción-serial-robusta-tramas-bcc-acknak)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Linea y LineaBuff solo se limpian al completar una trama. Cuando vence MaxEsperaRspMs, Timer1Timer solo pone SwEsperaRsp:=false, así que un fragmento (byte perdido) se completa con los bytes de la respuesta siguiente. La longitud dd (BCD del 4o byte) no tiene tope: un byte corrupto (p.ej. $99) hace esperar hasta 103 bytes y se traga varias respuestas. El bucle 'while (not FinLinea)...' procesa una trama por evento: si llegan dos juntas (respuesta tardía más la actual), la segunda espera al siguiente evento de datos. Una respuesta tardía se toma como la del comando en curso (SwEsperaRsp:=false, HoraUltRsp) y se manda el siguiente comando antes de tiempo. En A9 el producto se toma de AuxCmndN del ÚLTIMO comando enviado a esa posición, así que una A9 tardía de otro producto se guarda en el TotalLitros equivocado.
- **Evidencia:** 2316-2320: 'if SwEsperaRsp then begin if MilliSecondsBetween(...)<=MaxEsperaRspMs then exit; SwEsperaRsp:=false; end;' sin limpiar Linea. 2423-2426: 'dd:=ByteToNibbleDec(Byte(Linea[4])); esperados:=4+dd;'. 2617: 'N'+...+inttostr(TPosCarga[xpos].AuxCmndN).
- **Impacto:** Respuestas descartadas, comandos desfasados y totales por producto cruzados (afectan TOTAL y el volumen por totalizador) cuando hay ruido en la línea.
- **Recomendación:** Limpiar Linea y LineaBuff al vencer el timeout y antes de cada envío. Validar dd contra el máximo esperado por tipo (A3/A4/A1/A9). Procesar todas las tramas completas dentro de un bucle. Validar que la respuesta coincida con el comando enviado (encabezado, dispensario, lado y, para A9, el producto si la trama lo trae) y descartar las tardías. Probar inyectando tramas truncadas y concatenadas.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="TEA-14"></a>
#### TEA-14 · 🟡 Media · robustez · bug — pSerialTriggerAvail no tiene except y acepta tramas A3 cortas como válidas (AV y reposo falso)

- **Ubicación:** `UIGASTEAM.pas` líneas 2391-2392, 2472-2489, 2515-2517, 2964-2967
- **Se atiende en:** [E2.8](../PLAN_OPTIMIZACION.md#e28--recepción-serial-robusta-tramas-bcc-acknak)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El manejador solo tiene try/finally. ValidaChecksumTeam devuelve True si la trama tiene menos de 5 campos. Con una A3 corta (sin campos 6/7), HexToBinario('') da '00000000', que se interpreta como estatus 1 (reposo): si la posición estaba despachando, se dispara 'venta finalizada'. Luego 'ss[2]' sobre un campo 7 vacío lee un string nil, produce un access violation y la excepción se propaga al despachador de Async Pro sin registrarse en el log.
- **Evidencia:** 2964-2967: 'if ne < 5 then begin result:=true; exit; end;'. 2515-2517: 'ss:=ExtraeElemStrSep(LineaTimer,7,'' ''); if strtointdef(ss[2],0)>0 then'. 2392 'try' ... 2768 'finally' sin except.
- **Impacto:** Posible cierre prematuro de una venta y excepciones no controladas en el hilo de eventos del puerto (pueden dejar Linea sucia y detener el procesamiento de esa trama).
- **Recomendación:** Validar el número mínimo de campos por tipo de trama antes de interpretarla (A3 ≥ 9 campos, A4 ≥ 18). En ValidaChecksumTeam, devolver False si ne<5 salvo para los tipos sin payload que se esperan (A8). Agregar 'except on e:Exception do AgregaLog(...)' que limpie Linea. Probar con tramas A3 de 6 y 7 campos.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="TEA-15"></a>
#### TEA-15 · 🟡 Media · correccion · bug — HALT/RUN no limpian la cola ni TabCmnd: un AUTHORIZE recibido con el driver detenido se ejecuta al hacer RUN

- **Ubicación:** `UIGASTEAM.pas` líneas 1233-1254, 1256-1314, 1981, 2241
- **Se atiende en:** [E1.5](../PLAN_OPTIMIZACION.md#e15--tabla-de-comandos-tabcmnd-y-respuestas-de-comandos-asíncronos)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Detener cierra el puerto, pero no limpia ListaCmnd, TabCmnd, SwEsperaRsp, Linea ni LineaBuff. Iniciar tampoco. Con el servicio detenido, ClientSocket1Read sigue aceptando AUTHORIZE/PAYMENT/TOTALS (EjecutaComando los guarda y el Bridge ya confirmó True), pero ProcesaComandos no corre. Al dar RUN, ProcesaComandos ejecuta esos comandos viejos sin revisar su antigüedad: la expiración solo ocurre dentro de EjecutaComando. Un preset de hace minutos u horas se envía a una posición libre. Además, el primer tick después de RUN siempre hace 'Reset' (cierra y reabre el COM) porque HoraComandoB y HoraRspB valen 0 o tienen el valor de antes de HALT.
- **Evidencia:** Detener 1240-1247 solo hace 'pSerial.Open:=False; Timer1...; detenido:=True; estado:=0'. ProcesaComandos 1981 no revisa TabCmnd[].hora. 2292: 'if (now-HoraComandoB>5*TmSegundo)or(...)'.
- **Impacto:** Autorizaciones fuera de tiempo (despacho sin cliente o doble cobro) y estado de comunicación sucio al reanudar.
- **Recomendación:** En Detener e Iniciar: ListaCmnd.Clear, SwEsperaRsp:=False, Linea/LineaBuff:='' e inicializar HoraComandoB/HoraRspB:=Now. Rechazar en ClientSocket1Read los comandos que requieren estado=1 cuando estado<>1 ('False|Servicio detenido|'). Expirar en ProcesaComandos los comandos con más de N segundos (p.ej. 30 s para OCC/OCL) y responder 'Comando expirado'. Probar AUTHORIZE en HALT seguido de RUN.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="TEA-16"></a>
#### TEA-16 · 🟡 Media · correccion · riesgo — BLOCK oculta las ventas en curso: una posición deshabilitada siempre se reporta '7'

- **Ubicación:** `UIGASTEAM.pas` líneas 1898-1917, 1079-1093, 1119-1124
- **Módulos afectados:** UIGASTEAM.pas, otros drivers
- **Se atiende en:** [E5.1](../PLAN_OPTIMIZACION.md#e51--semántica-única-de-estatus-y-campos-de-venta)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Con SwDesHabilitado, Estatus se publica '7' sin importar estatus ni swcargando. Si se bloquea durante un despacho (en modo normal no hay bloqueo físico y la bomba puede seguir despachando en modo normal), OpenGas no ve '2' ni '3'. Al desbloquear, si finventa=0, la posición ya está en '1' y la venta no se reporta como terminada. El patrón se repite en Bennett 1367, Gilbarco 2985, PAM 1051, Wayne 1122 y Wayne2W 1479.
- **Evidencia:** 1898-1917: 'if not SwDesHabilitado then begin ... end else xestadoPos:=''7'';'.
- **Impacto:** Ventas hechas o terminadas mientras la posición está 'bloqueada' pueden no registrarse en OpenGas.
- **Recomendación:** Publicar '7' solo cuando la posición esté libre (no swcargando, no SwLecturaFinalPendiente, estatus en 1) y mantener 2/3 mientras haya una venta en curso o sin cobrar. En modo normal documentar que BLOCK solo impide presets. Coordinar con OpenGas.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** sí

<a id="TEA-17"></a>
#### TEA-17 · 🟡 Media · correccion · riesgo — Una venta que empieza y termina sin que el driver la vea despachando no se registra

- **Ubicación:** `UIGASTEAM.pas` líneas 2505-2510, 2697-2702, 2728
- **Se atiende en:** [E1.9](../PLAN_OPTIMIZACION.md#e19--coherencia-del-estado-publicado-estatus-fin-de-venta-horaocc-estado)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El fin de venta solo se detecta si antes se vio estatus 5/8 o swcargando. Si se corta la comunicación durante toda la venta (estatus 0 por ContEsperaB>=3 y luego reposo), o la venta es más corta que el intervalo de sondeo de una posición inactiva (cada CiclosInactivas ciclos), al volver A3 reporta reposo o A4 reporta ss=30 o 3/6/9/12 con la pantalla de la venta. Esto se trata como reposo ('30: ... else estatus:=1') y no se genera fin de venta.
- **Evidencia:** 2505: 'if ((estatusAnterior in [5,8]) or swcargando) and (estatus in [1,7,8])'. 2697-2701: ss=30 sin swcargando da estatus 1.
- **Impacto:** Despachos reales (postpago, o con un preset que sí se aplicó) que nunca llegan a OpenGas tras cortes de comunicación.
- **Recomendación:** Comparar el volumen e importe del display (A1/A4) y los totalizadores con la última venta cerrada. Si el display cambió o el totalizador avanzó sin una venta registrada, generar el fin de venta (o al menos un aviso en el log y estatus '3'). En A4 tratar ss=30 sin swcargando como 'fin de venta no observada' cuando el display trae un monto distinto al último registrado.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="TEA-18"></a>
#### TEA-18 · 🟡 Media · correccion · bug — La lógica de transiciones de ProcesaLinea 'B' es código muerto: estatusant siempre es igual a estatus

- **Ubicación:** `UIGASTEAM.pas` líneas 1687-1727
- **Se atiende en:** [E1.9](../PLAN_OPTIMIZACION.md#e19--coherencia-del-estado-publicado-estatus-fin-de-venta-horaocc-estado)
- **Verificación:** sin verificación independiente
- **Qué pasa:** La línea sintética B se arma con TPosCarga.estatus, que A3/A4 ya actualizaron. ProcesaLinea hace 'estatusant:=estatus; estatus:=(el mismo valor)'. Por eso 'if estatusant<>1' (1707) y 'if estatusant<>5' (1721) nunca se cumplen. No se reinician importenvo, volumennvo y precionvo al empezar una venta (importepre del primer A1 queda con la venta anterior) ni PosAutorizada, FinVenta y TipoPago al volver a reposo. ContDesp/importeant (1762-1766), SwCargaPreset e IniciaCarga no tienen efecto.
- **Evidencia:** 1691-1692: 'estatusant:=estatus; estatus:=StrToIntDef(ss[xpos*2],0);' donde ss viene de 2346: 'inttostr(PosActual)+inttostr(estatus)'.
- **Impacto:** Estado residual entre ventas. Si la primera lectura A1 válida de una venta es la final y es menor que la venta anterior, la corrección de 1769 restaura en TPosCarga el monto de la venta anterior (hoy no llega al JSON por el hallazgo de la corrección, pero se activaría al arreglarlo).
- **Recomendación:** Detectar las transiciones en los manejadores A3/A4 (ya tienen estatusAnterior) y reiniciar ahí importenvo/volumennvo/precionvo al entrar a 5 y FinVenta/PosAutorizada al volver a 1 cuando corresponda. Borrar el código muerto de 'B'. Arreglarlo junto con la corrección de la ruta A1.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="TEA-19"></a>
#### TEA-19 · 🟡 Media · rendimiento · optimizacion — Bitácoras caras: JSON completo en cada envío, concatenación carácter por carácter, hasta 10000 líneas en memoria y SaveToFile síncrono

- **Ubicación:** `UIGASTEAM.pas` líneas 1412-1438, 401, 492, 1363-1385, 1660-1663, 383, 477, 460
- **Se atiende en:** [E2.4](../PLAN_OPTIMIZACION.md#e24--bitácoras-que-no-bloquean-append-incremental-rotación-y-sin-json-repetido)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Responder registra 'E '+JSON completo (~5 KB con 16 posiciones) cada 750 ms (200 ms con Timer2) y ClientSocket1Read registra cada respuesta. AgregaLog/AgregaLogPetRes copian la línea carácter por carácter (lin2:=lin2+lin[i]) y, ya llenas, hacen Delete(0) (O(n)). ListaLogPetRes puede tener decenas de MB. GuardarLog se llama desde ProcesaLinea (rotación por MinutosLog), en cada TRACE (incluidos los automáticos del Bridge) y en cada excepción de Timer2Timer y ClientSocket1Read. Cada llamada hace SaveToFile de ambas listas en el hilo principal, a archivos nuevos con timestamp, sin depurar nada.
- **Evidencia:** 1430-1435: bucle 'case lin[i] of ... else lin2:=lin2+lin[i];'. 1436: 'while ListaLogPetRes.Count>10000 do ListaLogPetRes.Delete(0);'. 492: 'AgregaLogPetRes(''E ''+resp);'. 1660-1663: rotación dentro de ProcesaLinea.
- **Impacto:** Picos de cientos de ms bloqueando el hilo principal (respuestas seriales vencidas, JSON tardío y menos margen para el timeout de 2 s del Bridge), memoria alta y disco que se llena con archivos de decenas de MB.
- **Recomendación:** Usar StringReplace o un buffer con SetLength para escapar los caracteres de control. Registrar el JSON solo cuando cambie o en modo debug (o resumido). Usar un buffer circular (array con índice) en lugar de Delete(0). Escribir en append incremental desde un hilo de bitácora o con TFileStream abierto. Implementar retención (borrar archivos de más de N días o más de X MB). Validar midiendo tiempos de Timer1Timer antes y después.
- **Esfuerzo:** M · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="TEA-20"></a>
#### TEA-20 · 🟡 Media · observabilidad · deuda_tecnica — Excepciones tragadas en el ciclo principal y en la actualización del JSON

- **Ubicación:** `UIGASTEAM.pas` líneas 2363-2364, 528-532, 560-563, 1792-1794, 2206-2208
- **Se atiende en:** [E2.4](../PLAN_OPTIMIZACION.md#e24--bitácoras-que-no-bloquean-append-incremental-rotación-y-sin-json-repetido)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Timer1Timer tiene 'except end;' vacío: cualquier error del ciclo (p.ej. pSerial.OutPut o pSerial.Open fallando con el COM desconectado) desaparece sin dejar rastro. ActualizaCampoJSON y AddPeticionJSON ignoran los errores (si falla AddPeticionJSON, el resultado de un comando se pierde y el Bridge lo da por vencido). En ProcesaComandos, una excepción en un comando aborta los demás de esa pasada y el comando se reintenta en cada tick, llenando el log.
- **Evidencia:** 2363-2364: 'except end;'. 560-563: 'except on e:Exception do begin end;'.
- **Impacto:** Fallas de puerto y de JSON imposibles de diagnosticar en campo; resultados de comandos perdidos sin explicación.
- **Recomendación:** Registrar siempre e.ClassName+e.Message (con un limitador de frecuencia para no inundar el log). En ProcesaComandos poner un try/except por comando que marque SwResp con 'Error: ...'. En AddPeticionJSON registrar el error y el folio afectado.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="TEA-21"></a>
#### TEA-21 · 🟡 Media · memoria_recursos · bug — LPrecios[1..4] se indexa con ProductId y TComb sin validar (con $R- corrompe memoria)

- **Ubicación:** `UIGASTEAM.pas` líneas 693, 255-256, 1683, 2142-2144, 2167-2189, 2557, 2675
- **Se atiende en:** [E1.8](../PLAN_OPTIMIZACION.md#e18--índices-fuera-de-rango-y-carga-de-posiciones-r-)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Inicializar escribe 'LPrecios[productID]' con el ProductId que llega en el JSON, sin revisar 1..4. PDISPENSARIOS.cfg compila con -$R- (sin chequeo de rangos). Con ProductId ≥5 se escribe sobre las globales siguientes; por el orden de declaración probablemente es MaxPosCarga, que se calculó justo antes en AgregaPosCarga, y un double como 23.45 deja MaxPosCarga en ~858 millones, con desbordes masivos de TPosCarga. También se lee fuera de rango: LPrecios[TComb[2..3]=0] en la respuesta de TOTAL con NoComb<3, LPrecios[TComb[1]=0] en CPREC para posiciones sin mangueras, y LPrecios[xcomb] con productos >4 en A1/A4/'B'.
- **Evidencia:** 693: 'LPrecios[productID]:=productos.Child[i].Field[''Price''].Value;'. 2142-2144: 'LPrecios[TComb[2]]', 'LPrecios[TComb[3]]'. PDISPENSARIOS.cfg: '-$R-'.
- **Impacto:** Con un catálogo de productos con id ≥5, el servicio queda inestable (AV, sondeo de cientos de millones de posiciones). Con ids 0, se usan precios basura en importes de totales.
- **Recomendación:** Validar ProductId en 1..High(LPrecios) en Inicializar (si no, devolver 'False|ProductId fuera de rango|') o convertir LPrecios en un diccionario o arreglo dinámico. En las lecturas, usar una función PrecioDe(xcomb) que devuelva 0 fuera de rango. Compilar en QA con {$R+}{$Q+} para detectar el resto.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="TEA-22"></a>
#### TEA-22 · 🟡 Media · protocolo · riesgo — TCP sin delimitar y SendText sin revisar: los mensajes grandes o fragmentados se corrompen

- **Ubicación:** `UIGASTEAM.pas` líneas 399-414, 482-499, 1387-1409
- **Módulos afectados:** UIGASTEAM.pas, UIGASBRIDGE.pas, resto de drivers
- **Se atiende en:** [E6.1](../PLAN_OPTIMIZACION.md#e61--framing-y-buffer-por-conexión-en-los-dos-sentidos-y-del-lado-de-opengas)
- **Verificación:** sin verificación independiente
- **Qué pasa:** ClientSocket1Read asume que cada evento trae un mensaje completo y uno solo. Un INITIALIZE grande puede llegar en varios ReceiveText (ParseText falla y la segunda parte se toma como 'Comando desconocido' con folio 0). Responder ignora lo que devuelve SendText en un socket no bloqueante: si el buffer se llena (respuestas de LOG/LOGREQ con miles de líneas, cada una con un JSON incrustado, que pueden ser MB), el JSON llega truncado. El Bridge registra 'Error parseando JSON' y guarda un archivo de log por cada fallo (UIGASBRIDGE.pas:793-803), y como contesta cada lectura, el driver recibe varias respuestas y AddPeticionJSON(0) desplaza el resultado. Además, si un Resultado contiene el texto 'PING' (p.ej. un LOGREQ que incluya las primeras líneas 'E PING'), el Bridge ignora todo el snapshot (AnsiContainsText).
- **Evidencia:** 399: 'mensaje:=Socket.ReceiveText;' y parseo inmediato. 486/490: 'socketResponse.SendText(resp)' sin revisar el resultado. 1407: 'logStr:=logStr+ListaLogPetRes[i]+''|'''.
- **Impacto:** Fallas intermitentes de INITIALIZE, comandos LOG/LOGREQ que nunca responden y snapshots perdidos y logs inflados en el Bridge.
- **Recomendación:** Definir un delimitador de mensaje (p.ej. ETX o #10, o prefijo de longitud) en ambos lados y acumular en un buffer por socket hasta tener el mensaje completo. En Responder, usar SendBuf en bucle o encolar el resto en OnWrite. Limitar LOG/LOGREQ (p.ej. 200 líneas o 64 KB) y escapar o filtrar el JSON incrustado. En el Bridge, detectar PING como mensaje exacto. Hay que desplegar los dos lados al mismo tiempo.
- **Esfuerzo:** M · **Riesgo del cambio:** alto · **Toca contrato:** sí

<a id="TEA-23"></a>
#### TEA-23 · 🟡 Media · configuracion · bug — Arranque frágil: Timer2 activo antes de ServiceExecute, StrToInt sin default antes de crear las listas, ServiceStop no conectado en el DFM

- **Ubicación:** `UIGASTEAM.dfm / UIGASTEAM.pas` líneas DFM 1-8, 33-38; PAS 293-332, 298-311, 325-326, 334-338
- **Se atiende en:** [E2.3](../PLAN_OPTIMIZACION.md#e23--arranque-y-paro-ordenados-del-servicio)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Timer2 está habilitado en el DFM, así que empieza a dispararse en el hilo principal en cuanto Application.CreateForm crea el módulo, posiblemente antes de que ServiceExecute (en el hilo del servicio) asigne Host/Port (el DFM tiene Port=0) y cree ListaLog, ListaCmnd y rootJSON. Puede intentar conectar a :0 y AgregaLog puede fallar con ListaLog=nil. En ServiceExecute, 'StrToInt' de ServidorSocket y MinutosLog se ejecuta antes de crear ListaLog: un valor no numérico manda al except, que usa ListaLog=nil, se produce un AV, ServiceExecute termina y el servicio se detiene sin dejar log. El TIniFile nunca se libera. ServiceStop existe pero el DFM no asigna OnStop, así que al detener el servicio no se guarda el log en memoria.
- **Evidencia:** DFM: 'object Timer2: TTimer Interval = 200' (Enabled por defecto) y solo 'OnExecute = ServiceExecute'. PAS 302: 'StrToInt(ExtraeElemStrSep(...,2,'':''))', 305: 'StrToInt(config.ReadString(''CONF'',''MinutosLog'',''0''))', 311: 'ListaLog:=TStringList.Create'.
- **Impacto:** Fallas al iniciar con errores de configuración comunes y pérdida del log en cada paro del servicio. Hay carreras posibles en los primeros milisegundos.
- **Recomendación:** Poner Timer2.Enabled=False en el DFM y activarlo al final de la inicialización en ServiceExecute. Crear las listas antes de leer el ini. Usar StrToIntDef con valores por defecto. Liberar el TIniFile con try/finally. Asignar OnStop/OnShutdown en el DFM para guardar el log. Probar con MinutosLog=abc y con ServidorSocket sin puerto.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="TEA-24"></a>
#### TEA-24 · 🟡 Media · correccion · bug — Totales: un A9 perdido deja SwEsperandoTotales activo sin reintento; TOTAL calcula el importe con el precio actual

- **Ubicación:** `UIGASTEAM.pas` líneas 1666-1667, 2432-2439, 1946-1956, 2131-2148, 2229-2230
- **Se atiende en:** [E1.7](../PLAN_OPTIMIZACION.md#e17--totales-confiables)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Si un A9 vence o trae checksum malo, ProcesaLinea sale ('if not checksum then exit') sin decrementar TotalesPendientes. SwCargaTotales solo se vuelve a activar con un rechazo 66 66, así que SwEsperandoTotales queda en True hasta el siguiente FINV o TOTAL. Mientras tanto TOTAL no responde (SwAplicaCmnd=False), la posición se sondea en cada ciclo y en A4 el volumen por totalizador de la siguiente venta se desactiva. El 'importe' de TOTAL es TotalLitros por el precio vigente (no un totalizador monetario) y solo incluye 3 mangueras. Con NoComb=1 se pide siempre el producto 3 ('diesel').
- **Evidencia:** 1666-1667: 'if not checksum then exit;'. 2436-2438: reintento solo en 66 66. 2142: 'FormatoMoneda(ToTalLitros[1]*LPrecios[TComb[1]])'. 1953: 'inttostr(3)' para NoComb=1.
- **Impacto:** TOTALS sin respuesta o lentos en cierres de turno. Totales monetarios inexactos después de cambios de precio. Posiciones de un solo producto que no sea el 3 nunca obtienen totales (66 66 repetido).
- **Recomendación:** Llevar un timeout por A9 pendiente (p.ej. 3 s) que vuelva a activar SwCargaTotales con un contador de intentos. Responder TOTAL con error explícito al agotar los intentos. Hacer configurable el número de producto A9 de las posiciones de un solo producto (o usar TPos[1]). Documentar que el importe es calculado.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="TEA-25"></a>
#### TEA-25 · 🟡 Media · protocolo · riesgo — Mapeo de estados incompleto: bloqueo físico (9) se reporta 'sin comunicación', códigos A4 desconocidos se tratan como reposo, y una A3 con checksum malo resetea la detección de falta de comunicación

- **Ubicación:** `UIGASTEAM.pas` líneas 1902-1914, 2476-2489, 2693-2705, 2459, 2468
- **Se atiende en:** [E2.8](../PLAN_OPTIMIZACION.md#e28--recepción-serial-robusta-tramas-bcc-acknak)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El estatus 9 (bit0 en A3, ss 15/55 en A4) se publica '0' (sin comunicación) si no hay SwDesHabilitado; por ejemplo, si el driver reinicia con una bomba que quedó en modo 15, aparece sin comunicación y EnviaPreset la rechaza sin explicación. En A4, 'else estatus:=1' convierte cualquier ss desconocido (errores; ss=10 'llamando' se quitó en 26ccfb4) en reposo y permite presets. En A3, ContEsperaB:=0 y HoraRspB:=now se asignan antes de revisar csok: una posición que solo manda tramas corruptas nunca pasa a '0' y se queda con el último estado.
- **Evidencia:** 1913: 'else xestadoPos:=''0'';' para 9. 2704: 'else estatus:=1;'. 2459/2468: 'HoraRspB:=now; ... ContEsperaB:=0;' antes de 'if csok then'.
- **Impacto:** Diagnóstico confuso en campo, presets enviados en estados no previstos y estados viejos publicados como si fueran vigentes.
- **Recomendación:** Agregar un estatus 'bloqueado físico' que se publique como '7', y registrar en el log los ss desconocidos dejándolos en un estado no apto para presets ('0' o el anterior). Resetear ContEsperaB y HoraRspB solo con tramas válidas.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="TEA-26"></a>
#### TEA-26 · 🟡 Media · rendimiento · optimizacion — Latencia de los resultados: salen en el siguiente envío de 750 ms y cualquier bloqueo del hilo se suma al timeout de 2 s del Bridge

- **Ubicación:** `UIGASTEAM.pas` líneas 2366-2371, 1517, 1527, 2303, 363-366
- **Se atiende en:** [E4.1](../PLAN_OPTIMIZACION.md#e41--responder-al-bridge-en-cuanto-se-procesa-un-comando-y-homologar-la-cadencia)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El resultado de un comando se agrega a Peticiones de inmediato, pero no se envía hasta el siguiente tick de Timer1 que cumpla los 750 ms. A eso se suman los bloqueos del hilo principal: EsperaMiliSeg(500) por preset, Reset con 500 ms, SaveToFile de logs grandes y el bucle de reconexión de ~1 s. El Bridge mide TimeoutRespSrv=2 s con SecondsBetween (truncado) desde que envía el comando, así que el margen real es corto en momentos de carga.
- **Evidencia:** 2368: 'if MilliSecondsBetween(Now,HoraUltJSON)>=MsEnvioJSON then'. MsEnvioJSON=750 (15).
- **Impacto:** Timeouts esporádicos en OpenGas para comandos con respuesta (INITIALIZE, TOTALS, RESPCMND, BLOCK) y una experiencia lenta en POS.
- **Recomendación:** Enviar el JSON en cuanto se llame a AddPeticionJSON con folio>0 (marcar una bandera que Timer1 atienda en el siguiente tick, sin esperar los 750 ms) y eliminar los bloqueos anteriores. Medir en el log del Bridge el tiempo entre el envío y la respuesta.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="TEA-27"></a>
#### TEA-27 · 🟡 Media · correccion · bug — Presets: OCL de menos de 0.5 L se envía como preset de $0, no hay tope de litros, y la respuesta 'OK' sale antes de confirmar el A5

- **Ubicación:** `UIGASTEAM.pas` líneas 2997-3000, 2083-2084, 2073, 2097, 2432-2446, 2199-2201, 1530-1531
- **Se atiende en:** [E1.3](../PLAN_OPTIMIZACION.md#e13--presets-montos-decimales-y-validaciones)
- **Verificación:** sin verificación independiente
- **Qué pasa:** En OCL, SnImporte:=0. Si 0<litros<0.5, EnviaPreset manda 'S' con importe 0 (A5 06 00000000), lo que según el firmware puede ser venta libre o rechazo. OCL no tiene tope y con 10000 L o más el formato '0000.00' produce 7 dígitos que ComandoConsola trunca con copy(…,4,6). OCC con un combustible que no existe en la posición solo registra en el log y responde 'OK' (OCL responde error): es inconsistente. TabCmnd.Respuesta se pone en 'OK' cuando se encola, no cuando la bomba acepta; un rechazo 66 66 del A5 solo se registra.
- **Evidencia:** 2997-3000: 'if SnLitros>=0.5 then ss:=''L''... else ss:=''S''+...FormatFloat(''0000.00'',SnImporte)'. 2073: 'else AgregaLog(''Preset no enviado...'')' con rsp='OK'.
- **Impacto:** Despachos no autorizados correctamente o autorizados sin límite en casos poco comunes. RESPCMND engaña a quien lo consulta.
- **Recomendación:** Validar rangos de OCL (p.ej. 0.5-9999.99 L) y responder error fuera de rango. Responder 'Combustible no existe' también en OCC. Llevar el folio del comando asociado a cada A5 y fijar Respuesta según el ACK, el rechazo o el timeout.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="TEA-28"></a>
#### TEA-28 · ⚪ Baja · robustez · bug — Índices sin validar en otros arreglos (TPosCarga 1..100, TComb/TPos 1..MCxP, TabCmnd 1..200, LinEstadoGen)

- **Ubicación:** `UIGASTEAM.pas` líneas 843, 864-865, 877-878, 1544, 1550, 1556, 1584, 2690, 2239-2246, 1207, 1678, 1692
- **Se atiende en:** [E1.8](../PLAN_OPTIMIZACION.md#e18--índices-fuera-de-rango-y-carga-de-posiciones-r-)
- **Verificación:** sin verificación independiente
- **Qué pasa:** AgregaPosCarga usa TPosCarga[xpos] con el DispenserId sin validar e incrementa NoComb sin tope (TComb[5] pisa TPos[1]). ComandoConsola 'U','C','D','N' no validan xpos; en 'N' se escribe TPosCarga[xpos].AuxCmndN antes del 'if xpos>0'. En A4, TMang[posactual] con posactual=0 al primer sondeo. En EjecutaComando, con la tabla llena, el repeat lee y escribe TabCmnd[201] (justo después de TabCmnd están LPrecios). EstadoPosiciones accede a LinEstadoGen[xpos] sin revisar la longitud. En la línea 'B' se accede a ss[xpos*2] sin revisar la longitud. Todo esto con -$R-.
- **Evidencia:** 1584: 'TPosCarga[xpos].AuxCmndN:=strtointdef(s1,1); PosCmndN:=xpos; if xpos>0 then'. 2239-2246: 'repeat inc(ind); if (TabCmnd[ind].SwActivo)... until (not TabCmnd[ind].SwActivo)or(ind>200);'.
- **Impacto:** Corrupción silenciosa de memoria con configuraciones atípicas o mensajes inesperados.
- **Recomendación:** Validar en AgregaPosCarga 1<=xpos<=100 y NoComb<MCxP (devolver 'False|...'). Revisar el rango en todos los casos de ComandoConsola antes de usar xpos. En EjecutaComando, evaluar 'ind<=200' antes de indexar. Compilar en QA con $R+.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="TEA-29"></a>
#### TEA-29 · ⚪ Baja · robustez · riesgo — El watchdog de Timer1 puede apagar el servicio (Detener/Terminar/Shutdown) y reabre el COM cada 5 s

- **Ubicación:** `UIGASTEAM.pas` líneas 2292-2311
- **Se atiende en:** [E4.3](../PLAN_OPTIMIZACION.md#e43--ciclo-serial-eficiente)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Si pasan 5 s sin B enviado o sin A3/A4 recibido, hace Reset: cierra el COM, espera 500 ms y lo reabre. Si ContB>3 llama GuardarLog, Detener(0), Terminar(0) y Shutdown(0): ServiceThread.Terminate apaga el servicio y instalador.bat no configura recuperación. ContB se reinicia en cada 'B' enviado, así que en la práctica solo se llega ahí si no hay posiciones sondeables (MaxPosCarga=0 o todas con NoComb=0) después de RUN. Con todas las bombas apagadas, abre y cierra el COM cada 5 s indefinidamente.
- **Evidencia:** 2305-2310: 'if ContB>3 then begin GuardarLog(0); Detener(0); Terminar(0); Shutdown(0); end;'.
- **Impacto:** Un INITIALIZE sin dispensarios o con una configuración mal hecha puede apagar el servicio por completo; operaciones innecesarias sobre el COM.
- **Recomendación:** Quitar el Shutdown automático: reportar el estado de falla (p.ej. Estado=2 'sin comunicación') y seguir reintentando con backoff. Validar en Iniciar que haya al menos una posición sondeable. Configurar la recuperación del servicio con 'sc failure'.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="TEA-30"></a>
#### TEA-30 · ⚪ Baja · memoria_recursos · bug — Fugas de memoria (JSON de INITIALIZE, TIniFile) y respuesta de error sin prefijo

- **Ubicación:** `UIGASTEAM.pas` líneas 664, 298, 853-854
- **Se atiende en:** [E2.7](../PLAN_OPTIMIZACION.md#e27--initialize-idempotente-y-seguro-con-ventas-en-curso)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El objeto 'js' de TlkJSON.ParseText en Inicializar nunca se libera (fuga en cada INITIALIZE, de varios KB). El TIniFile de ServiceExecute tampoco. Al salir de AgregaPosCarga con 'Favor de configurar los lados...', posObj y hosesArr quedan sin agregar ni liberar, y el texto va sin 'False|', así que OpenGas recibe 'DISPENSERS|INITIALIZE|Favor...' sin indicador de éxito o error.
- **Evidencia:** 664: 'js := TlkJSON.ParseText(json);' sin Free. 853: 'Result:=''Favor de configurar los lados de los dispensarios Team'';'.
- **Impacto:** Fugas menores acumulables en reinicializaciones y una respuesta ambigua para OpenGas.
- **Recomendación:** Usar try/finally js.Free y config.Free. Anteponer 'False|' y validar ConfTeam antes de crear objetos.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="TEA-31"></a>
#### TEA-31 · ⚪ Baja · protocolo · deuda_tecnica — NOTHING agrega {Folio:0} a Peticiones y los resultados se reenvían hasta ser desplazados

- **Ubicación:** `UIGASTEAM.pas` líneas 417-418, 535-564
- **Módulos afectados:** UIGASTEAM.pas, UIGASBRIDGE.pas
- **Se atiende en:** [E6.2](../PLAN_OPTIMIZACION.md#e62--push-de-comandos-resultados-inmediatos-y-ack)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Cada '0|DISPENSERS|NOTHING' llama AddPeticionJSON(0,'True|'). Peticiones nunca se vacía después de enviarse; la única depuración es dejar los 2 últimos. Los resultados reales viajan varias veces y se desplazan por entradas de folio 0. Si llegan 3 o más respuestas del Bridge entre dos envíos (envíos fragmentados o Timer1 y Timer2 activos a la vez), un resultado puede desplazarse antes de enviarse.
- **Evidencia:** 418: 'AddPeticionJSON(folio, ''True|'');' con folio=0. 551-552: 'while petArr.Count >= 2 do petArr.Delete(0);'.
- **Impacto:** Tráfico y log innecesarios y un riesgo bajo de perder resultados.
- **Recomendación:** No agregar Peticiones para folio 0. Vaciar Peticiones después de un SendText exitoso, o mantener una cola sin tope que se depure cuando el Bridge confirme (requiere un acuse en el contrato). Coordinar con el Bridge.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** sí

<a id="TEA-32"></a>
#### TEA-32 · ⚪ Baja · seguridad · riesgo — Login/Token sin secreto ni verificación; validación HASP comentada

- **Ubicación:** `UIGASTEAM.pas` líneas 1037-1055, 3052-3062, 1264-1292, 304, 310, 67
- **Se atiende en:** [E8.1](../PLAN_OPTIMIZACION.md#e81--autenticación-licencia-y-modo-emulación)
- **Verificación:** sin verificación independiente
- **Qué pasa:** La contraseña esperada es MD5(usuario|yyyy-mm-ddThh:nn), que cualquiera puede calcular, y depende del minuto: falla si el reloj del cliente difiere o si cambia el minuto entre generarla y validarla. El Token nunca se revisa en otros comandos. La validación HASP de Iniciar está comentada, pero se siguen leyendo 'Licencia' y GSentinelKey (dos veces la misma clave) sin usarlos, y las DLL HASP siguen en el repo.
- **Evidencia:** 1043: 'if MD5(usuario+''|''+FormatDateTime(''yyyy-mm-dd'',Date)+''T''+FormatDateTime(''hh:nn'',Now))<>password'. 1264-1292 comentado.
- **Impacto:** Una falsa sensación de control de acceso y licenciamiento sin efecto. El puerto del Bridge está en localhost, lo que limita la exposición.
- **Recomendación:** Documentar que no hay autenticación o implementarla en el Bridge (secreto compartido o HMAC). Borrar el código HASP comentado o reactivarlo por configuración, y quitar las lecturas sin uso.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="TEA-33"></a>
#### TEA-33 · ⚪ Baja · mantenibilidad · deuda_tecnica — Abundante código muerto y declaraciones duplicadas

- **Ubicación:** `UIGASTEAM.pas` líneas 1168-1213, 2862-2877, 1629-1641, 1891-1933, 2339, 2458, 1669-1674, 2532-2547, 873, 877, 1022, 1027, 47, 79, 263, 268, 176-229, 257-274
- **Se atiende en:** [E8.3](../PLAN_OPTIMIZACION.md#e83--código-muerto-variables-globales-y-duplicación-interna)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Código sin efecto: TransaccionPosCarga y EstadoPosiciones (el Bridge contesta TRANSACTION y STATUS); ComandoW y CodigoTeam; CRC16; TDiga/Con_DigitoAjuste, que se guardan y nunca se leen; la cadena lin/xmodo/xdisp2 en NumPaso=3, que se arma con FormatFloat en cada ciclo y se descarta; CheckSumB, que vuelve a True justo antes de usarse (2339) y anula el 'checksumb:=false' de 2458; 'UltimoStatus:=LineaTimer' después de vaciarla; la rama A1 de litros, que nunca se pide (y divide entre 100 en lugar de 1000). Sin uso: TipoPago, boucher, ModoOpera (solo alimenta la cadena descartada), aros_*, swarosmag, TCodigoTeam, impopreset, Isla, TipoPagoAnt, SwPreset, SwCargaPreset, IniciaCarga y las globales AvanceBar, SwSolOk, ContDA, StErrSol, ruta_db, Licencia3Ok y SwCerrar. NumPaso y ListaCmnd están declarados como campo y como global de la unidad (el campo oculta a la global). DesactivaModoPrepago asigna 'Prepago'.
- **Evidencia:** Por ejemplo, 47 'NumPaso' (campo) y 268 'NumPaso :integer;' (global); 79 y 263 'ListaCmnd'; 1934 'LinEstadoGen:=xestado;' (lin no se usa); 2339 'CheckSumB:=true;'.
- **Impacto:** Confusión al mantener (ya provocó defectos como la lógica de transiciones muerta), CPU desperdiciada en cada ciclo y riesgo de 'arreglar' variables que no tienen efecto.
- **Recomendación:** Borrar el código muerto en un commit aparte y sin cambios de comportamiento. Quitar las globales duplicadas. Corregir DesactivaModoPrepago ('Normal'). Revisar con el diff que no cambie la lógica.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="TEA-34"></a>
#### TEA-34 · ⚪ Baja · configuracion · deuda_tecnica — Configuración repartida, sensible a mayúsculas y con constantes de tiempo fijas en el código

- **Ubicación:** `UIGASTEAM.pas` líneas 11-16, 314-315, 644-656, 662, 851-857, 1819, 1952-1953
- **Se atiende en:** [E0.5](../PLAN_OPTIMIZACION.md#e05--configuración-documentada-y-validada-al-arrancar)
- **Verificación:** sin verificación independiente
- **Qué pasa:** ConfTeam y ProtocoloExtendido vienen del ini; los demás parámetros Team vienen en las variables de INITIALIZE. TresDecimTotTeam se compara exactamente con 'Si' ('SI' o 'si' no funcionan). ConfTeam se indexa por posición con StrToInt, así que cualquier hueco o error da una excepción genérica en INITIALIZE. MaxEsperaRspMs, MsEnvioJSON, MsEsperaCambioPrecio y el umbral de 5 s del watchdog están fijos en el código. Timer1.Interval se limita a 50 ms aunque PausaCmnd sea mayor. NoComb=1 asume que el producto es el 3.
- **Evidencia:** 1819: 'if TresDecimTotTeam=''Si'' then'. 856: 'Dispensario:=StrToInt(ExtraeElemStrSep(cPos,1,'':''))'.
- **Impacto:** Errores de configuración en campo difíciles de diagnosticar (p.ej. totales ×10).
- **Recomendación:** Unificar la lectura de configuración (ini con override desde INITIALIZE), comparar con UpperCase, validar ConfTeam con mensajes específicos por posición, sacar los tiempos a parámetros y registrar en el log la configuración efectiva al inicializar.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="TEA-35"></a>
#### TEA-35 · ⚪ Baja · configuracion · riesgo — Conversiones numéricas y de fecha dependen del locale de la cuenta del servicio

- **Ubicación:** `UIGASTEAM.pas` líneas 907, 911, 2057, 2083, 2157, 1185-1186, 2142-2144, 834, 1760, 2669
- **Se atiende en:** [E8.2](../PLAN_OPTIMIZACION.md#e82--configuración-regional-locale-explícita)
- **Verificación:** sin verificación independiente
- **Qué pasa:** StrToFloat y StrToFloatDef de importes, litros y precios recibidos, y FormatFloat de las respuestas TOTAL/TRANSACTION, usan DecimalSeparator. El ':' de FormatDateTime('hh:nn') se cambia por TimeSeparator. uLkJSON sí normaliza el '.', pero los strings de comandos y respuestas no. es-MX usa '.' y ':', pero una cuenta de servicio con otro locale rompe el parseo o produce '24,50'.
- **Evidencia:** 2057: 'SnImporte:=StrToFLoat(ExtraeElemStrSep(...,3,'' ''))'. 2142: 'FormatFloat(''0.000'',ToTalLitros[1])'.
- **Impacto:** Presets rechazados o mal interpretados y totales mal formateados en servidores con otra configuración regional.
- **Recomendación:** Usar un TFormatSettings fijo (DecimalSeparator='.', TimeSeparator=':') en todas las conversiones de protocolo, o fijar DecimalSeparator en ServiceExecute.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="TEA-36"></a>
#### TEA-36 · ⚪ Baja · rendimiento · optimizacion — Trabajo repetido en cada ciclo: JSON completo, búsquedas lineales y parseo con ExtraeElemStrSep

- **Ubicación:** `UIGASTEAM.pas` líneas 373, 2370, 501-533, 1695-1696, 1757-1760, 1920, 2686-2691, 2473-2655, 2972-2976, 1594-1597, 406-408, 2393-2404
- **Se atiende en:** [E4.2](../PLAN_OPTIMIZACION.md#e42--json-más-barato-generar-menos-redondear-y-buscar-menos)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El JSON completo se regenera cada 750 ms (200 ms con Timer2) aunque nada cambie. ActualizaCampoJSON recorre PosCarga y busca el campo por nombre en cada llamada: se llama de 4 a 7 veces por posición por ciclo, O(N²). Cada trama se vuelve a parsear con ExtraeElemStrSep campo por campo (A4: unas 17 extracciones, cada una desde el inicio). LineaBuff se arma carácter por carácter y se consume con Delete(…,1,1). El costo absoluto es bajo con el hardware actual, pero se suma a los bloqueos del hilo principal.
- **Evidencia:** 515-526: un bucle por cada ActualizaCampoJSON. 2648-2655: ocho ExtraeElemStrSep para sVol/sImp.
- **Impacto:** CPU y latencia innecesarias, sobre todo en estaciones con muchas posiciones.
- **Recomendación:** Guardar referencias a los TlkJSONobject de cada posición (arreglo por xpos) al crearlos en AgregaPosCarga. Partir la trama una sola vez en un TStringList o arreglo de bytes. Mandar el JSON solo cuando cambie o haya Peticiones nuevas (manteniendo un heartbeat para DatosObsoletos).
- **Esfuerzo:** M · **Riesgo del cambio:** bajo · **Toca contrato:** no

