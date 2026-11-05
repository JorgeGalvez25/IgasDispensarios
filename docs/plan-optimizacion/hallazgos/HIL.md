# Hallazgos · HIL · Modelo de hilos

> Anexo del [plan de optimización](../PLAN_OPTIMIZACION.md). Código auditado: `IgasDispensarios@26ccfb4`, `IgasDispensariosBridge@99edafd`. Las líneas pueden haber cambiado: ubica las rutinas por su nombre. Kairos (Marca 7) y Triton (Marca 10) quedan fuera de alcance: si el texto los menciona, es solo como contexto.

## Cómo funciona este módulo

Las fuentes de la VCL de Delphi 7 y de Async Pro no están en el entorno. El análisis se basa en lo que sé de SvcMgr, ExtCtrls y ScktComp de D7, contrastado con el comportamiento que el propio código deja ver.

1) Hilos de PDISPENSARIOS:

   - Hilo principal: el .dpr llama Application.CreateForm y TServiceApplication.Run, que queda en 'while not Forms.Application.Terminated do HandleMessage' hasta que TServiceStartThread.DoTerminate publica WM_QUIT.

   - TServiceStartThread: está bloqueado en StartServiceCtrlDispatcher y reenvía los controles del SCM con PostThreadMessage(CM_SERVICE_CONTROL_CODE).

   - TServiceThread: ejecuta ServiceExecute con 'while not Terminated do ProcessRequests(True)', es decir GetMessage/DispatchMessage. OnStop y OnShutdown corren aquí.

   - Hilos internos de Async Pro.

2) Timer1 y Timer2 del .dfm: TTimer.Create hace AllocateHWnd dentro de CreateForm, así que su ventana y sus WM_TIMER son del hilo principal. Timer2 queda armado (SetTimer) al cargar el .dfm, antes de que el SCM llame ServiceExecute. Certeza alta. Ningún driver en alcance crea timers en código.

3) TClientSocket: GetHandle es perezoso y FHandle no se libera al cerrar. Por eso el primer hilo que activa el socket fija para siempre el hilo de OnConnect, OnRead y OnDisconnect, aunque Timer2 lo reconecte después.

   - Wayne, Team, PAM, Hong Yang, Gilbarco y Wayne 2W lo activan solo en Timer2Timer, en el hilo principal.

   - Bennett lo activa en ServiceExecute (L276), en el hilo del servicio.

   - Excepción: 'Active:=False' llama Disconnect, que dispara OnDisconnect en el hilo que llama. Por eso el 'ClientSocket1.Active:=False' que sigue al bucle de ServiceExecute ejecuta OnDisconnect en el hilo del servicio en los 7 drivers. Certeza alta.

4) Async Pro: OnTriggerAvail y OnTriggerData llegan al hilo principal sincronizados (Synchronize, WM_NULL a Application.Handle y CheckSynchronize). Certeza media-alta, pendiente de confirmar con E0.2. Evidencia: las esperas de Wayne 2W y Gilbarco tienen que bombear la cola principal (ProcessRequests(False)) para que bListo cambie, y ProcessCommunications solo se usa para ceder CPU.

5) Arranque y paro:

   - Solo Wayne y Wayne 2W tienen OnStop/OnShutdown (hilo del servicio); su OnDestroy corre en el principal al finalizar.

   - Team tiene ServiceStop, pero no está conectado.

   - PAM con modoAuto=SI ejecuta Inicializar e Iniciar en el hilo del servicio.

6) Resultado:

   - Hay concurrencia real en estado estable solo en Bennett (BEN-01, E2E-06).

   - En los demás drivers todo el trabajo es del hilo principal. El riesgo es la reentrancia por bombeo anidado: ProcessRequests(False) en Wayne 2W y Gilbarco, y EsperaMiliSeg, que sí bombea según el arreglo 37cab32 de Team. A eso se suman carreras acotadas al arranque, al paro, a modoAuto y a SHUTDOWN.

   - Ningún EsperaMiliSeg ni ProcessMessages corre en el hilo del servicio.

   - CoInitialize/CoUninitialize están balanceados con try/finally: Bennett 1870/1924 en el hilo del servicio y Hong Yang 2350/2405 en el principal, donde ComObj ya inicializó COM. No hay hallazgo.

7) Bridge: un solo hilo, verificado.

   - SSocketPDisp se activa en ServiceExecute y SSocketOG dentro de SSocketPDispClientRead, en el mismo hilo.

   - Los clientes aceptados heredan la ventana del listener, y TimerTimeout se crea en ServiceExecute.

   - El hilo principal solo espera WM_QUIT. La sección crítica de TPeticionQueue sobra (BRG-32).

8) Modelo objetivo: el hilo principal es dueño de todo el estado del driver (socket, timers, Async Pro, rootJSON, TPosCarga, TabCmnd, logs).

   - ServiceExecute solo lee la configuración, crea las estructuras y manda WM_ARRANCA a una ventana del módulo creada en OnCreate. Después supervisa un latido.

   - Los comandos del Bridge se encolan y se aplican en puntos seguros, sin bombeo anidado.

   - El paro se pide por mensaje y se espera con timeout; si el hilo principal no responde, ExitProcess.

   - Descarto una TCriticalSection global sobre rootJSON: no evita la reentrancia, porque todo ocurre en el mismo hilo.

   - Orden de migración: E0.2, utilidades y .dfm, paro y latido, reentrancia por driver, y Bennett al final (primero quitar las esperas, después mover el socket).

## Hallazgos (9)

<a id="HIL-01"></a>
#### HIL-01 · 🟠 Alta · concurrencia · bug — PAM modoAuto: Iniciar corre en el hilo del servicio y apaga Timer2 antes de conectar; el driver puede no conectarse nunca al Bridge

- **Ubicación:** `UIGASPAM.pas` líneas 299-302, 2386-2444 (2427, 2432-2433), 319-353 (327, 351), 2256-2266, 485-502 (493), 361-367; UIGASPAM.dfm 23-28
- **Módulos afectados:** UIGASPAM
- **Se atiende en:** [E2.6](../PLAN_OPTIMIZACION.md#e26--bennett-y-pam-todo-en-un-solo-hilo)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  Amplía PAM-38, que solo menciona una 'posible carrera en modoAuto'.
  
  Qué pasa:
  - Con modoAuto=SI y jsonInitialize en el ini, ServiceExecute (hilo del servicio) llama Inicializar(0,...) e Iniciar(0) antes de entrar al bucle (299-302).
  - Iniciar abre pSerial (2427) y hace 'Timer1.Enabled:=True; Timer2.Enabled:=False' (2432-2433) sin revisar 'conectado'.
  - Timer2 es el único que ejecuta ClientSocket1.Active:=True (327). Quedó armado en el hilo principal desde Application.CreateForm (.dfm 23-28, Interval 200, Enabled por omisión).
  
  Cuándo se queda apagado: el KillTimer cruzado de Iniciar deja a Timer2 apagado sin haber conectado en dos casos:
  - (a) Llega antes del primer disparo de Timer2. Ocurre unos 200 ms después de CreateForm, y el arranque por el SCM, la lectura del ini, el parseo de jsonInitialize y la apertura del COM suelen tardar menos.
  - (b) Llega entre dos reintentos cuando el Bridge todavía no levanta, por ejemplo al arrancar el equipo. Cada ciclo de Timer2Timer dura unos 1.2 s y deja un hueco de unos 0.2 s.
  
  Por qué nadie lo reactiva:
  - El finally de Timer2Timer (351) ya no se ejecuta.
  - ClientSocket1Disconnect (361-367) no se dispara, porque nunca hubo conexión.
  - Timer1Timer, en su finally (2256-2266), llama Responder. Con el socket cerrado, Responder hace ClientSocket1.Socket.SendText (493), y en ScktComp SendBuf sale con 0 cuando 'not FConnected', sin lanzar excepción. Así, el except que vuelve a armar Timer2 (2262-2263) nunca corre.
  
  Si Iniciar cae mientras Timer2Timer está dentro de su Sleep, el finally lo vuelve a armar y no pasa nada. Por eso es una carrera de arranque, no una falla sistemática.
  
  En el mismo arranque, AddPeticionJSON(0,...) de Iniciar modifica rootJSON en el hilo del servicio mientras Timer2Timer puede estar en GenerateText.
  
  Certeza media-alta. Depende de que KillTimer sobre la ventana de otro hilo del mismo proceso funcione, que es lo normal según el verificador de E2E-06.
- **Evidencia:**
  - 299-302: 'if (modoAuto) and (jsonInitialize<>'''') then begin Inicializar(0,jsonInitialize); Iniciar(0); end;', ejecutado en ServiceExecute antes de 'while not Terminated'.
  - 2432-2433: 'Timer1.Enabled:=True; Timer2.Enabled:=False;'.
  - 327: única llamada a 'ClientSocket1.Active:=True'.
  - grep 'Timer2.Enabled:=True' en UIGASPAM da solo: 366 (Disconnect), 407 (comando '0'), 2263 (except de Timer1Timer), 2369 (Detener) y 2757 (LiberaInicializacion).
  - 485-495: Responder hace 'ClientSocket1.Socket.SendText(resp); AgregaLogPetRes(''E ''+resp)'. Registra el envío aunque no haya conexión.
- **Impacto:** Después de reiniciar el servicio o el equipo con modoAuto, el driver sigue sondeando la PAM pero no se conecta al Bridge. OpenGas recibe 'Datos obsoletos' o False en STATE, STATUS y TRANSACTION, y ningún AUTHORIZE ni PAYMENT llega a las bombas hasta volver a reiniciar el servicio. El LogDispPetRes muestra líneas 'E {json}' cada 250 ms que en realidad no salieron, lo que confunde el diagnóstico.
- **Recomendación:**
  1) No llamar Inicializar ni Iniciar desde ServiceExecute. En modoAuto, levantar una bandera y ejecutarlos en el primer tick de Timer2, en el hilo principal.
  2) En Iniciar, no apagar Timer2 si no hay conexión: 'Timer2.Enabled := not conectado'.
  3) En Timer1Timer, si 'not conectado' y 'not Timer2.Enabled', volver a armar Timer2. Y que Responder no registre 'E' cuando SendText devuelve 0.
  
  Validación: modoAuto=SI con 30 reinicios del servicio con el Bridge arriba y 30 con el Bridge arrancando 10 s después. En todos, LogPDisp del Bridge debe mostrar la conexión en menos de 3 s.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="HIL-02"></a>
#### HIL-02 · 🟠 Alta · concurrencia · bug — Amplía W2W-12: Timer1Timer se reentra dentro de EsperaMiliseg porque TransmiteComando vuelve a armar Timer1 (50 ms); un ProcesaComandos anidado puede ejecutar dos veces un AUTHORIZE

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 1185, 1233-1236, 3030, 3078-3081, 2117, 2219, 2589-2607, 2767-2770, 1144, 1161, 1324, 2658-2659, 2664-2673, 2883, 2012, 2407, 1012, 2025, 2050; UIGASWAYNE2W.dfm 25-31; UIGASTEAM.pas 1516, 1526
- **Módulos afectados:** UIGASWAYNE2W
- **Se atiende en:** [E2.5](../PLAN_OPTIMIZACION.md#e25--reentrancia-comandos-del-bridge-durante-una-transacción-serial)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  Amplía W2W-12 y E2E-19, que dejaron como 'no verificable' que EsperaMiliseg anidara Timer1 y ProcesaComandos.
  
  El mecanismo:
  - TransmiteComando1/2 apagan Timer1 al entrar (1185, 3030) y lo vuelven a encender en su finally con 'Timer1.Enabled:=estado>0' (1235, 3080).
  - Timer1Timer no se apaga a sí mismo, y su intervalo es de 50 ms (.dfm 27).
  - Hay EsperaMiliseg(50/300) con Timer1 activo en LeePrecios (1144/1161), DameEstatus (1324), ProcesaComandos antes de EnviaPresetPesosBomba (2117/2219), CambiaPrecios entre el precio N1 y el N2 de la misma manguera (2589-2607) y en 'Desautoriza', entre DetenerDespacho y ReanudaDespacho (2767-2770).
  
  Evidencia de que EsperaMiliSeg (ULIBGRAL) bombea mensajes: el commit 37cab32 de Team agregó 'Timer1.Enabled:=false; // evita que el timer mande otro comando durante la espera' antes de esperamiliseg(500) (UIGASTEAM 1516, 1526). Con un Sleep, ese timer no podría dispararse. Por lo tanto, dentro de cada espera entra un WM_TIMER y corre un Timer1Timer anidado.
  
  La guarda SwEspera (2664-2673) no lo detiene por tres razones:
  - (a) 'if CmndNuevo then ProcesaComandos' (2658-2659) está antes de la guarda.
  - (b) Cuando el Timer1Timer externo está en el ProcesaComandos del inicio del tick, SwEspera sigue en False. El anidado ejecuta un paso completo y, si le toca NumPaso=6, llama ProcesaComandos (2883).
  - (c) Si el paso externo dura más de 3 s, las líneas 2664-2665 limpian SwEspera.
  
  Por qué se duplica el comando: ProcesaComandos pone CmndNuevo:=False al entrar (2012) y solo marca SwResp al final (2407). El ProcesaComandos anidado vuelve a encontrar el mismo OCC/OCL activo y sin respuesta, y lo ejecuta. Al regresar, el externo lo ejecuta otra vez con el estatus que había validado antes (2025, 2050).
  
  En 2117 el anidamiento es casi seguro: el timer periódico vence dentro de los 50 ms. La doble ejecución requiere además que el anidado caiga en NumPaso=6 (una vez por vuelta del ciclo) o que llegue un comando nuevo en el mismo bombeo (EjecutaComando pone CmndNuevo:=True, 1012). Certeza media, porque la implementación de EsperaMiliSeg no está en el repo.
- **Evidencia:**
  - 1233-1236: 'finally ... Timer1.Enabled:=estado>0;'.
  - 2117: 'EsperaMiliseg(50); if EnviaPresetPesosBomba(xpos,xtipopre,xvalorpre) then ...'.
  - 2658-2659: 'if CmndNuevo then ProcesaComandos;', antes de 'if not SwEspera' (2666).
  - 2883: '6:ProcesaComandos;'.
  - 2407: 'TabCmnd[xcmnd].SwResp:=true;', al final.
  - 2589-2593: 'TransmiteComando1(N1) ... Esperamiliseg(50); ... TransmiteComando1(N2)'.
  - 2767-2770: 'Esperamiliseg(300); DetenerDespacho; Esperamiliseg(300); ReanudaDespacho'.
  - UIGASTEAM 1516: comentario 'evita que el timer mande otro comando durante la espera' (commit 37cab32).
- **Impacto:**
  - Un AUTHORIZE puede mandar dos veces el preset y la autorización a la misma bomba. Si el segundo envío falla porque la bomba ya está en 9 o en 2, RESPCMND devuelve 'No se pudo prefijar' para un preset que sí quedó activo, y OpenGas puede reintentar o cancelar en falso.
  - Un AUTHORIZE o un CPREC anidado dentro de CambiaPrecios deja mangueras de una misma posición con precios de listas distintas.
  - Un comando anidado entre DetenerDespacho y ReanudaDespacho actúa sobre una bomba que el paso externo está a punto de reanudar.
  - En cada tick con anidamiento se ejecutan dos pasos del ciclo sobre PosCiclo y NumPaso compartidos.
- **Recomendación:**
  Corto plazo:
  1) Guarda de reentrancia al inicio de Timer1Timer ('if EnTimer1 then Exit; EnTimer1:=True; try ... finally EnTimer1:=False end') y otra en ProcesaComandos.
  2) Marcar el comando como 'en proceso' antes de ejecutarlo (un campo SwEnProceso) y que ProcesaComandos lo salte.
  3) No volver a armar Timer1 en el finally de TransmiteComando1/2, sino solo al final de Timer1Timer; o apagar Timer1 al entrar a Timer1Timer, como hace Wayne (1507).
  
  Mediano plazo (E2.5): reemplazar EsperaMiliseg por pausas sin bombeo o por marcas de tiempo del ciclo.
  
  Validación: con el emulador, registrar la profundidad de Timer1Timer ('Timer1 anidado') y enviar ráfagas de AUTHORIZE a dos posiciones y un PRICES durante un cambio de precios. La profundidad debe ser 0 y cada OCC debe aparecer una sola vez en el log serial.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="HIL-03"></a>
#### HIL-03 · 🟡 Media · robustez · bug — Paro sin orden: OnDisconnect corre en el hilo del servicio y vuelve a armar Timer2, el sondeo sigue tras STOPPED, Gilbarco reabre el COM por un AV con ServiceThread=nil y 5 drivers pierden la bitácora

- **Ubicación:** `UIGASGILBARCO.pas` líneas 342, 3064-3069, 1268-1271 (1270), 1365-1368 (1367), 1379-1397 (1384-1388, 1390, 1396)
- **Módulos afectados:** UIGASWAYNE, UIGASBENNETT, UIGASTEAM, UIGASPAM, UIGASHONGYANG, UIGASGILBARCO, UIGASWAYNE2W
- **Se atiende en:** [E2.3](../PLAN_OPTIMIZACION.md#e23--arranque-y-paro-ordenados-del-servicio)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  Amplía W2W-28, WAY-23, GIL-29 y TEA-23 con la secuencia real del paro en Delphi 7.
  
  1) Del STOP al OnDisconnect: el STOP del SCM llega al hilo del servicio, ProcessRequests ejecuta OnStop (solo existe en Wayne y Wayne 2W) y Terminate, y sale el bucle. Después se ejecuta 'ClientSocket1.Active := False' en el hilo del servicio (Wayne 320, Bennett 292, Team 322, PAM 306, Hong Yang 303, Gilbarco 342, Wayne 2W 447). En ScktComp, Disconnect dispara seDisconnect de forma síncrona en el hilo que llama. Por eso ClientSocket1Disconnect corre en el hilo del servicio y hace 'Timer1.Enabled:=False; Timer2.Enabled:=True' sobre timers del hilo principal (Wayne 2913-2914, Bennett 316-317, Team 350-351, PAM 365-366, Hong Yang 412-413, Gilbarco 3067-3068, Wayne 2W 3947-3948).
  
  2) El hilo principal sigue trabajando:
  - Los finally vuelven a encender Timer1 (Wayne 1911; Gilbarco 1396; Wayne 2W 1235; pSerialTriggerAvail de Team 2769, PAM 821, Hong Yang 1788 y Bennett 982).
  - Timer2, armado desde el otro hilo, vuelve a abrir el socket hacia el Bridge con Sleep de hasta 1-1.5 s.
  - Ningún driver cierra pSerial ni apaga timers: el COM se cierra hasta que se destruye TApdComPort, ya en la finalización.
  
  3) STOPPED antes de que termine el proceso: TService.DoStart hace FreeAndNil(FServiceThread) y reporta STOPPED al terminar el hilo del servicio, no el proceso. El WM_QUIT llega al hilo principal más tarde.
  - En esa ventana, Gilbarco y Wayne 2W llaman ServiceThread.ProcessRequests(False) sobre nil desde el hilo principal (Gilbarco 1270/1367, Wayne 2W 1210/3055), lo que provoca un AV.
  - En Gilbarco, el except de TransmiteComando (1379-1391) cierra el COM, espera 200 ms, lo reabre y llama GuardarLog(0). Lo hace por cada transacción que quede en el tick.
  - Corrección a W2W-28: el WM_QUIT no puede perderse en ese bombeo. FServiceThread ya es nil cuando TServiceStartThread publica WM_QUIT, y la llamada falla antes de PeekMessage.
  
  4) Bitácora perdida: Bennett, Team (ServiceStop 334-338 existe pero el .dfm no lo conecta), PAM, Hong Yang y Gilbarco no tienen OnStop, OnShutdown ni OnDestroy. Con MinutosLog=0 (el valor por omisión), las hasta 10000 líneas en memoria se pierden en cada paro.
  
  5) Bennett: la ventana del socket pertenece al hilo del servicio, y Windows la destruye cuando ese hilo termina. El 'Active:=True' que hace Timer2 después falla, y en cada tick se registra el error y se guarda el log.
- **Evidencia:**
  - Gilbarco 342: 'ClientSocket1.Active := False;' después de 'while not Terminated do ServiceThread.ProcessRequests(True);'.
  - Gilbarco 3067-3068: 'Timer1.Enabled := False; Timer2.Enabled := True;' en ClientSocket1Disconnect.
  - Gilbarco 1268-1271: 'repeat Sleep(5); ServiceThread.ProcessRequests(False); until ...'.
  - Gilbarco 1384-1390: 'if estado > 0 then begin pSerial.Open := False; Sleep(200); pSerial.Open := True; end; GuardarLog(0);'.
  - Wayne 2W 3167-3181: OnStop, OnShutdown y OnDestroy solo hacen GuardarLog(0).
  - UIGASTEAM.dfm: solo 'OnExecute = ServiceExecute'.
- **Impacto:** Paros ruidosos y lentos: el driver se reconecta al Bridge durante el paro, el sondeo serial sigue después de STOPPED, Gilbarco reabre el COM y escribe archivos de log de más, y se pierde la bitácora justo cuando hace falta para diagnosticar el reinicio. Si el hilo principal está ocupado (un CPREC de Gilbarco, una reconexión o un SaveToFile), el proceso sigue vivo con el COM abierto después de que el SCM reporta STOPPED. Un 'Reiniciar' inmediato lanza otro proceso que no puede abrir el puerto.
- **Recomendación:**
  No hacer el apagado en OnStop. El paso 3 de E2.3 ('Conectar OnStop/OnShutdown para apagar timers, cerrar puertos') ejecutado tal cual sería E/S cruzada desde el hilo del servicio.
  
  Pasos:
  1) En OnStop y OnShutdown, solo PostMessage(HWND del módulo creada en OnCreate, WM_DETENER) y WaitForSingleObject(EventoDetenido, 10000).
  2) En el hilo principal, al recibir WM_DETENER: levantar Deteniendo:=True (OnDisconnect no vuelve a armar Timer2 y TransmiteComando sale), Timer1/Timer2.Enabled:=False, ClientSocket1.Active:=False, pSerial.Open:=False, GuardarLog(0) y SetEvent.
  3) Quitar el 'ClientSocket1.Active := False' del final de ServiceExecute.
  4) Quitar ServiceThread.ProcessRequests(False) de TransmiteComando (E2.5), o cambiarlo por un bombeo que no dependa de ServiceThread.
  
  Validación: 50 ciclos de 'sc stop'/'sc start' con tráfico y con un CPREC en curso. El proceso debe terminar en menos de 2 s, sin AV en el log, sin reabrir el COM y con LogDisp guardado en cada paro.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="HIL-04"></a>
#### HIL-04 · 🟡 Media · robustez · riesgo — El hilo del servicio no supervisa al hilo principal: si el sondeo se cuelga, el servicio sigue 'En ejecución', y un STOP deja un proceso zombi con el COM abierto

- **Ubicación:** `UIGASWAYNE2W.pas` líneas 445-446, 2968-2989 (2971-2981)
- **Módulos afectados:** UIGASWAYNE, UIGASBENNETT, UIGASTEAM, UIGASPAM, UIGASHONGYANG, UIGASGILBARCO, UIGASWAYNE2W
- **Se atiende en:** [E2.3](../PLAN_OPTIMIZACION.md#e23--arranque-y-paro-ordenados-del-servicio)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  En los 7 drivers, el hilo del servicio solo ejecuta 'while not Terminated do ServiceThread.ProcessRequests(True)' (Wayne 318-319, Bennett 290-291, Team 320-321, PAM 304-305, Hong Yang 301-302, Gilbarco 340-341, Wayne 2W 445-446). En 6 de ellos no tiene ninguna ventana, así que solo despierta con los controles del SCM. Todo el trabajo (serial, socket, timers, JSON) corre en el hilo principal, y nadie lo supervisa.
  
  Causas posibles de un cuelgue del hilo principal:
  - El bucle sin salida de AvanzaPosCiclo en Wayne 2W (2971-2981, W2W-20) o el equivalente en Gilbarco (3013-3023).
  - Una espera sin timeout.
  - Un interbloqueo con el despachador de Async Pro, que entrega los eventos con Synchronize.
  - Un SaveToFile sobre una ruta de red caída.
  
  Qué pasa entonces:
  - El SCM sigue viendo el servicio 'En ejecución', porque el hilo del servicio responde, y las acciones de recuperación nunca se aplican.
  - Si alguien lo detiene, el hilo del servicio termina, SvcMgr reporta STOPPED y TServiceStartThread publica un WM_QUIT que el hilo principal nunca procesa. El proceso queda vivo, con el COM abierto y la conexión al Bridge.
  - El Bridge solo marca 'datos obsoletos' a los 5 s, y su auto-kick TRACE no sirve porque el driver ya no lee el socket.
  
  No existe latido ni salida forzada.
- **Evidencia:**
  - Wayne 2W 445-446: 'while not Terminated do ServiceThread.ProcessRequests(True);'.
  - 2971-2981: 'repeat inc(PosCiclo); ... until TPosCarga[PosCiclo].SwRecibida and (...)', sin salida si no hay posiciones recibidas.
  - Gilbarco 3013-3023: el mismo patrón.
  - En los 7 drivers no hay ningún GetTickCount ni marca de vida que lea el hilo del servicio.
  - PDISPENSARIOS.dpr 29-66: el proceso solo termina cuando el hilo principal sale de Application.Run.
- **Impacto:** Un cuelgue del sondeo deja la estación sin control hasta que alguien mata el proceso a mano. El 'Reiniciar' desde services.msc parece funcionar, pero el proceso nuevo no puede abrir el COM porque el zombi lo tiene.
- **Recomendación:**
  1) Latido: el hilo principal escribe GetTickCount en una variable compartida (InterlockedExchange) en cada Timer1Timer y Timer2Timer.
  2) El hilo del servicio cambia ProcessRequests(True) por un bucle 'ProcessRequests(False)' con una espera de 1 s que despierte con mensajes (MsgWaitForMultipleObjects con QS_ALLINPUT). Si el latido supera N s (configurable, por ejemplo 30 s con estado>0), registra LogMessage(EVENTLOG_ERROR_TYPE) con PosCiclo y NumPaso y llama ExitProcess(1).
  3) En el paro, si el hilo principal no confirma en 10 s, también ExitProcess.
  4) Configurar en instalador.bat 'sc failure <servicio> reset= 86400 actions= restart/5000'.
  
  Validación: forzar un bucle infinito en modo emulación (Wayne 2W). El servicio debe reiniciarse solo y liberar el COM.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="HIL-05"></a>
#### HIL-05 · 🟡 Media · robustez · bug — Amplía GIL-42/PAM-39 y corrige TEA-29: SHUTDOWN y el watchdog de Team llaman ServiceThread.Terminate desde el hilo principal y el servicio nunca se detiene

- **Ubicación:** `UIGASTEAM.pas` líneas 1316-1324 (1322), 2305-2310, 320-321
- **Módulos afectados:** UIGASTEAM, UIGASWAYNE2W, UIGASHONGYANG
- **Se atiende en:** [E2.3](../PLAN_OPTIMIZACION.md#e23--arranque-y-paro-ordenados-del-servicio)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  Amplía GIL-42 y PAM-39 (y la verificación de WAY-18) a Team, Wayne 2W y Hong Yang, y corrige el impacto descrito en TEA-29.
  
  Shutdown(folio) llama ServiceThread.Terminate (Team 1322, Wayne 2W 3846, Hong Yang 2415) desde ClientSocket1Read, que en estos drivers corre en el hilo principal. En D7, TThread.Terminate solo pone FTerminated:=True y no despierta al hilo. El hilo del servicio está bloqueado en GetMessage dentro de ProcessRequests(True) (Team 320-321, Wayne 2W 445-446, Hong Yang 301-302) y no tiene ventanas propias, así que no despierta hasta que el SCM mande algún control. SHUTDOWN contesta 'True|', pero el servicio sigue 'En ejecución'.
  
  En Team, el watchdog de Timer1Timer (2305-2310) llama Detener(0), Terminar(0) y Shutdown(0) después de cuatro resets. TEA-29 da por hecho que eso apaga el servicio, pero en realidad lo deja vivo:
  - estado queda en -1 y el COM cerrado.
  - Timer2, armado por Detener, sigue mandando JSON con Estado=-1.
  - Los tres AddPeticionJSON(0,...) desplazan de Peticiones resultados reales (solo caben 2).
  
  El SCM no ve ninguna falla, así que ni sus acciones de recuperación ni un vigilante que mire el estado del servicio lo reinician.
- **Evidencia:**
  - Team 1316-1324: 'else begin AddPeticionJSON(folio, ''True|''); ServiceThread.Terminate; end;'.
  - Team 2305-2310: 'if ContB>3 then begin GuardarLog(0); Detener(0); Terminar(0); Shutdown(0); end;'.
  - Wayne 2W 3840-3848 y Hong Yang 2409-2417: el mismo Shutdown.
  - Bucles de espera del hilo del servicio: Team 320-321, Wayne 2W 445-446 y Hong Yang 301-302, todos 'while not Terminated do ServiceThread.ProcessRequests(True);'.
- **Impacto:** OpenGas o el operador creen que el driver se detuvo y no es así. En Team, el driver queda sin inicializar y vivo, sin que el SCM lo note: la estación se queda sin sondeo hasta que OpenGas mande INITIALIZE y RUN, o hasta que alguien reinicie el servicio a mano.
- **Recomendación:**
  1) Cambiar 'ServiceThread.Terminate' por 'Controller(SERVICE_CONTROL_STOP)'. TService.Controller hace PostThreadMessage(ServiceThread.ThreadID, CM_SERVICE_CONTROL_CODE, ...), despierta al hilo y pasa por OnStop. Como mínimo, agregar PostThreadMessage(ServiceThread.ThreadID, WM_NULL, 0, 0) después de Terminate.
  2) Enviar el resultado antes de detener (Responder(TlkJSON.GenerateText(rootJSON))).
  3) En Team, que el watchdog no apague el servicio: registrar la alarma y reintentar. Si se quiere reiniciar, salir con código de error para que el SCM aplique la recuperación.
  
  Validación: SHUTDOWN después de HALT y TERMINATE. El servicio debe pasar a 'Detenido' en menos de 2 s.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="HIL-07"></a>
#### HIL-07 · 🟡 Media · concurrencia · riesgo — Riesgo de migración: mover el socket de Bennett al hilo principal (E2.6) sin quitar antes las EsperaMiliSeg de ProcesaLinea convierte la carrera en reentrancia

- **Ubicación:** `UIGASBENNETT.pas` líneas 276, 921-933 (932), 1398-1445 (1440), 1505-1516 (1514), 1536-1545 (1543), 2470-2501
- **Módulos afectados:** UIGASBENNETT
- **Se atiende en:** [E2.6](../PLAN_OPTIMIZACION.md#e26--bennett-y-pam-todo-en-un-solo-hilo)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  El plan E2.6 propone quitar 'ClientSocket1.Active:=True' de ServiceExecute (276) para que el socket de Bennett viva en el hilo principal.
  
  Hoy, los EsperaMiliSeg de ProcesaLinea (hilo principal) solo pueden anidar Timer1 y pSerialTriggerAvail, porque los mensajes del socket van a la cola del hilo del servicio.
  
  Si se mueve solo el socket, empezará a ejecutarse ClientSocket1Read anidado dentro de:
  - cada EsperaMiliSeg(500) de reintento de OCC/OCL (1440, 1514);
  - el EsperaMiliSeg(300) después del 'F' de OCL (1543).
  
  Esas esperas corren dentro del recorrido de TabCmnd de NumPaso=4 (1398-1545), con SnPosCarga/SnImporte en campos compartidos. Comandos que se colarían a mitad del ciclo:
  - INITIALIZE: LiberaInicializacion (2470-2501) limpia TabCmnd y ListaCmnd y cierra pSerial.
  - HALT.
  - PRICES: IniciaPrecios llama ComandoConsola directo.
  - Un AUTHORIZE nuevo, vía EjecutaComando.
  
  Además, ComandoConsola vuelve a armar Timer1 en su finally (932) justo antes de esas esperas, y EsperaMiliSeg bombea mensajes (evidencia en el commit 37cab32 de Team).
  
  La verificación de E2.6 ('un solo ThreadId') pasaría, pero el defecto pasaría de carrera a reentrancia, la misma que ya se ve en Wayne 2W y Gilbarco (W2W-12, GIL-10).
- **Evidencia:**
  - 1438-1441: 'dec(TPosCarga[SnPosCarga].ContOCC); esperamiliseg(500);' dentro de 'for k:=1 to 200 do' (1398).
  - 1541-1543: 'ComandoConsolaBuff(ss,false); EsperaMiliSeg(300);'.
  - 932: 'finally Timer1.Enabled:=true;' en ComandoConsola.
  - 276: 'ClientSocket1.Active:=True;' en ServiceExecute.
  - PLAN_OPTIMIZACION E2.6, paso 1.
- **Impacto:** Si E2.6 se despliega sola, los AV esporádicos de BEN-01 se cambian por presets aplicados a otra posición o con un monto equivocado, y por recorridos de TabCmnd sobre tablas ya reinicializadas.
- **Recomendación:**
  Hacerlo en este orden:
  1) En Bennett, antes de E2.6 o junto con ella, quitar EsperaMiliSeg de ProcesaLinea (usar una marca HoraProxReintento por posición) y encolar en ClientSocket1Read los comandos que cambian el ciclo (E2.5).
  2) Agregar una guarda EnProcesaLinea que difiera lo que llegue por ClientSocket1Read.
  3) Solo después, mover la activación del socket a Timer2.
  
  Validación: con un simulador de consola Bennett, mandar INITIALIZE y HALT en ráfaga durante reintentos de preset. No debe haber presets cruzados ni AV.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="HIL-09"></a>
#### HIL-09 · 🟡 Media · mantenibilidad · deuda_tecnica — No hay un contrato de afinidad de hilos ni utilidades para cumplirlo: modelo objetivo y migración por etapas

- **Ubicación:** `PDISPENSARIOS.dpr` líneas 29-66; ServiceExecute de cada driver (Wayne 284-330, Bennett 256-302, Team 293-332, PAM 268-317, Hong Yang 270-314, Gilbarco 310-353, Wayne 2W 411-457)
- **Módulos afectados:** UIGASWAYNE, UIGASBENNETT, UIGASTEAM, UIGASPAM, UIGASHONGYANG, UIGASGILBARCO, UIGASWAYNE2W
- **Se atiende en:** [E0.2](../PLAN_OPTIMIZACION.md#e02--identificar-el-hilo-de-cada-evento-instrumentación)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  No hay ninguna regla escrita sobre qué hilo es dueño de cada cosa. Hoy el mismo código corre en hilos distintos según el driver y el momento:
  - Inicializar, Iniciar, Detener, Responder y AddPeticionJSON corren en el hilo del servicio en Bennett (socket) y en PAM con modoAuto, y en el hilo principal en los demás drivers.
  - GuardarLog corre en OnStop (hilo del servicio) y en Timer1 (principal).
  - OnDisconnect corre en el hilo principal o en el del servicio, según quién cierre el socket.
  
  Los hallazgos existentes atacan casos concretos (BEN-01, E2E-06, E2E-19, W2W-12, GIL-10 y las etapas E2.3 a E2.6). Sin un contrato común, cada corrección puede volver a meter el problema; ya pasa con el paso 3 de E2.3, que haría E/S cruzada desde OnStop, y con E2.6 sin E2.5 (ver los hallazgos anteriores).
  
  Tampoco existe una ventana propia del módulo en el hilo principal que reciba mensajes del hilo del servicio. El plan E2.3 propone 'PostMessage a una ventana del hilo principal' sin definir cuál.
- **Evidencia:**
  - PDISPENSARIOS.dpr 30-66: Application.Initialize, CreateForm (hilo principal) y Application.Run.
  - En cada ServiceExecute se mezcla configuración, creación de estructuras y, en Bennett (276) y PAM (299-302), operaciones de E/S.
  - grep de 'CriticalSection', 'Synchronize', 'GetCurrentThreadId' y 'AllocateHWnd' en los 7 drivers: vacío.
- **Impacto:** Las correcciones de concurrencia quedan frágiles y no se pueden verificar con pruebas. Cada driver nuevo o modificado puede volver a abrir carreras de arranque, de paro o de reentrancia.
- **Recomendación:**
  Modelo objetivo: 'el hilo principal es dueño de todo'.
  1) Contrato: rootJSON, TPosCarga, TabCmnd, ListaCmnd, las listas de log, los timers, el socket y pSerial solo se tocan en el hilo principal. El hilo del servicio solo atiende al SCM y el latido.
  2) Unidad común UHilos.pas:
     - FVentana:=Classes.AllocateHWnd(WndProcModulo) en el OnCreate del TService, que corre en el hilo principal porque lo crea CreateForm.
     - EnHiloPrincipal(msg,wp,lp), que hace PostMessage(FVentana,...).
     - AsegurarHiloPrincipal, que registra si GetCurrentThreadId<>MainThreadID. Se llama al inicio de ClientSocket1Read, Timer1Timer, Timer2Timer, pSerialTriggerAvail, Responder y AgregaLog.
  3) Arranque: Timer2.Enabled=False en los .dfm. ServiceExecute lee el ini, crea las listas y rootJSON y hace EnHiloPrincipal(WM_ARRANCA), que habilita Timer2 y, en PAM con modoAuto, inicializa.
  4) Comandos: ClientSocket1Read solo parsea y encola; Timer1 y Timer2 los aplican en puntos seguros. No se bombea la cola dentro de un evento (ni ProcessRequests(False) ni EsperaMiliSeg).
  5) Paro: WM_DETENER y un evento con timeout; si no responde, ExitProcess. Más el latido.
  
  Alternativas:
  - Se descarta como solución principal una TCriticalSection global sobre rootJSON: es reentrante en el mismo hilo, así que no evita la reentrancia, y en Bennett obligaría a mantenerla tomada durante la E/S serial.
  - El snapshot inmutable (GenerateText en el hilo principal y envío del texto) es compatible y sale gratis con este modelo.
  
  Orden de migración:
  1. E0.2: instrumentar los hilos.
  2. UHilos, .dfm y WM_ARRANCA en todos los drivers.
  3. Paro ordenado y latido.
  4. Reentrancia por driver, primero Wayne 2W y Gilbarco.
  5. Bennett al final: quitar las esperas y después mover el socket.
  
  Cada etapa se valida con el log de ThreadId y 50 ciclos de arranque y paro.
- **Esfuerzo:** L · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="HIL-06"></a>
#### HIL-06 · ⚪ Baja · concurrencia · riesgo — Amplía E2E-06: TTimer.Enabled se cambia desde dos hilos; SetEnabled/UpdateTimer no es atómico y puede dejar un timer disparando con Enabled=False

- **Ubicación:** `UIGASBENNETT.pas` líneas 1913-1914, 1938-1939, 2475, 2500, 2508-2509, 747-750 -> 921/932, 316-317, 430-431 (hilo del servicio) vs 581, 603-604, 613, 951, 982, 1685-1686, 2093-2094 (hilo principal)
- **Módulos afectados:** UIGASBENNETT, UIGASPAM, UIGASWAYNE, UIGASTEAM, UIGASHONGYANG, UIGASGILBARCO, UIGASWAYNE2W
- **Se atiende en:** [E2.6](../PLAN_OPTIMIZACION.md#e26--bennett-y-pam-todo-en-un-solo-hilo)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  Amplía E2E-06 y BEN-01. E2E-06 descartó, con razón, que cambiar Timer.Enabled desde otro hilo lance EOutOfResources. Lo que queda es que TTimer no es seguro entre hilos.
  
  Cómo funciona en D7: SetEnabled hace 'if Value<>FEnabled then begin FEnabled:=Value; UpdateTimer end', y UpdateTimer hace KillTimer y luego SetTimer si FEnabled.
  
  Intercalación posible:
  - El hilo A pone FEnabled:=True, hace KillTimer y lee FEnabled=True.
  - El hilo B pone FEnabled:=False, hace KillTimer y no llama SetTimer.
  - El hilo A llama SetTimer.
  
  Resultado: el timer de Windows sigue corriendo con FEnabled=False. A partir de ahí, 'Enabled:=False' no hace nada (Value=FEnabled) hasta que alguien lo ponga en True.
  
  Dónde ocurre en Bennett:
  - Desde el hilo del servicio: Iniciar (1913-1914), Detener (1938-1939), LiberaInicializacion (2475, 2500), Terminar (2508-2509), ComandoConsola vía IniciaPrecios (747-750, 921/932), ClientSocket1Disconnect por cierre remoto (316-317) y el except de Responder (430-431).
  - Desde el hilo principal: en cada trama (ComandoConsola 921/932, pSerialTriggerAvail 951/982), en Timer2Timer (581, 603-604, 613), en ProcesaLinea (1685-1686) y en el watchdog (2093-2094).
  
  También pasa en el paro en los 7 drivers (OnDisconnect en el hilo del servicio) y en PAM con modoAuto (2432-2433).
  
  La ventana es de microsegundos (dos llamadas a win32k): certeza alta en el mecanismo y probabilidad baja por evento.
- **Evidencia:**
  - 1913-1914: 'Timer1.Enabled:=True; Timer2.Enabled:=False;' en Iniciar, llamado desde ClientSocket1Read (hilo del servicio, BEN-01).
  - 951/982: 'Timer1.Enabled:=false' ... 'finally Timer1.Enabled:=true' en pSerialTriggerAvail (hilo principal), en cada evento serial.
  - 613: 'Timer2.Enabled := (not conectado) or (estado<=0);' en Timer2Timer.
- **Impacto:** Es raro, pero no se corrige solo. Puede quedar Timer2 disparando cada 200 ms junto con Timer1, con envíos duplicados al Bridge y 'Timer1.Enabled:=True' fuera de control. O Timer1 puede seguir sondeando después de un HALT, aun si se corrige BEN-28.
- **Recomendación:**
  Regla: los TTimer solo se tocan desde el hilo principal.
  - Mientras se migra, en las rutas del hilo del servicio cambiar 'TimerX.Enabled:=v' por PostMessage(HWND del módulo, WM_TIMERS, id, Ord(v)), atendido en el hilo principal.
  - Centralizar en un helper ActivaTimer(t,v) con 'if GetCurrentThreadId<>MainThreadID then ...registrar...'.
  
  Validación con E0.2: no debe quedar ningún cambio de Enabled registrado fuera de MainThreadID.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="HIL-08"></a>
#### HIL-08 · ⚪ Baja · robustez · bug — Cada evento serial reinicia el periodo de Timer1: con bytes continuos en la línea, el sondeo y los timeouts contados en ticks nunca se disparan

- **Ubicación:** `UIGASBENNETT.pas` líneas 951, 982, 2101-2111; UIGASPAM.pas 789, 821, 2203-2248; UIGASWAYNE.pas 1402, 1440; UIGASTEAM.pas 2391, 2769; UIGASHONGYANG.pas 1768, 1788
- **Módulos afectados:** UIGASBENNETT, UIGASPAM, UIGASWAYNE, UIGASTEAM, UIGASHONGYANG
- **Se atiende en:** [E2.9](../PLAN_OPTIMIZACION.md#e29--tiempos-monotónicos-y-resolución-del-temporizador)
- **Verificación:** sin verificación independiente
- **Qué pasa:**
  Amplía PAM-07, que notó el efecto en la latencia, y BEN-28/PAM-37.
  
  pSerialTriggerAvail apaga Timer1 al entrar y lo vuelve a encender en su finally en Bennett (951/982), PAM (789/821), Wayne (1402/1440), Team (2391/2769) y Hong Yang (1768/1788). En D7, 'Enabled:=False' seguido de 'Enabled:=True' hace KillTimer y SetTimer, así que el periodo vuelve a empezar en cada fragmento recibido.
  
  Si llegan bytes a intervalos menores que Interval (150 ms en Bennett, 250 ms en PAM, Wayne y Team, 15 ms en Hong Yang) sin formar una trama completa, Timer1 no se dispara nunca. Puede pasar por ruido, por un cable dañado o por un equipo que transmite sin que se le pregunte.
  
  Efectos:
  - Todo el ciclo de sondeo depende de Timer1, así que no salen comandos nuevos.
  - En Bennett (ContEsperaRsp, 2101-2111) y en PAM (ContEsperaPaso2..5 y ContEspera1, 2203-2248), el timeout se cuenta en ticks de Timer1, así que tampoco vence y no se simula el NAK que reanuda el ciclo.
  - Team y Hong Yang miden con Now, pero igual dependen de que Timer1 se dispare.
- **Evidencia:**
  - Bennett 949-952: 'ContadorAlarma:=0; Timer1.Enabled:=false; try for I := 1 to Count do ...'.
  - Bennett 981-983: 'finally Timer1.Enabled:=true;'.
  - Bennett 2101-2111: 'inc(ContEsperaRsp); if ContEsperaRsp>MaxEsperaRsp then ... ProcesaLinea;'.
  - El mismo patrón en PAM 789/821 y 2203-2240.
- **Impacto:** Con la línea ruidosa el driver se congela sin reportar pérdida de comunicación: los estatus quedan fijos (ver BEN-04, PAM-08) hasta que el ruido para. El Bridge termina marcando datos obsoletos solo en los drivers que dejan de enviar JSON.
- **Recomendación:**
  No alternar Timer1 en pSerialTriggerAvail ni en ComandoConsola. Usar una guarda de reentrancia (EnSerial) y medir los timeouts con GetTickCount en lugar de contar ticks. Dejar Timer1 siempre activo mientras estado=1.
  
  Validación: inyectar un byte de ruido cada 50 ms con un emulador. El driver debe registrar timeouts y marcar las posiciones sin comunicación.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

