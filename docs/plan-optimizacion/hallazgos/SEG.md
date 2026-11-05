# Hallazgos · SEG · Seguridad y licenciamiento

> Anexo del [plan de optimización](../PLAN_OPTIMIZACION.md). Código auditado: `IgasDispensarios@26ccfb4`, `IgasDispensariosBridge@99edafd`. Las líneas pueden haber cambiado: ubica las rutinas por su nombre. Kairos (Marca 7) y Triton (Marca 10) quedan fuera de alcance: si el texto los menciona, es solo como contexto.

## Cómo funciona este módulo

Revisión transversal de seguridad y licenciamiento del Bridge y de los drivers en alcance. Como los repositorios son públicos, el detalle de la mayoría de sus hallazgos está en el anexo privado de seguridad (item E8.5); aquí solo aparecen los que no exponen rutas de ataque.

## Hallazgos (17)

<a id="SEG-01"></a>
#### SEG-01 · 🟡 Media · seguridad — Hallazgo de seguridad reservado

- **Detalle:** reservado. Está en el anexo privado de seguridad, que no se versiona porque los repositorios son públicos.
- **Se atiende en:** [E8.5](../PLAN_OPTIMIZACION.md#e85--hallazgos-de-seguridad-reservados)

<a id="SEG-02"></a>
#### SEG-02 · 🟡 Media · seguridad — Hallazgo de seguridad reservado

- **Detalle:** reservado. Está en el anexo privado de seguridad, que no se versiona porque los repositorios son públicos.
- **Se atiende en:** [E8.5](../PLAN_OPTIMIZACION.md#e85--hallazgos-de-seguridad-reservados)

<a id="SEG-03"></a>
#### SEG-03 · 🟡 Media · seguridad — Hallazgo de seguridad reservado

- **Detalle:** reservado. Está en el anexo privado de seguridad, que no se versiona porque los repositorios son públicos.
- **Se atiende en:** [E8.5](../PLAN_OPTIMIZACION.md#e85--hallazgos-de-seguridad-reservados)

<a id="SEG-04"></a>
#### SEG-04 · 🟡 Media · seguridad — Hallazgo de seguridad reservado

- **Detalle:** reservado. Está en el anexo privado de seguridad, que no se versiona porque los repositorios son públicos.
- **Se atiende en:** [E8.5](../PLAN_OPTIMIZACION.md#e85--hallazgos-de-seguridad-reservados)

<a id="SEG-05"></a>
#### SEG-05 · 🟡 Media · seguridad — Hallazgo de seguridad reservado

- **Detalle:** reservado. Está en el anexo privado de seguridad, que no se versiona porque los repositorios son públicos.
- **Se atiende en:** [E8.5](../PLAN_OPTIMIZACION.md#e85--hallazgos-de-seguridad-reservados)

<a id="SEG-06"></a>
#### SEG-06 · 🟡 Media · seguridad · bug — PRICES no tiene tope superior: en Wayne 2W el precio se envuelve módulo 655.36, y en Hong Yang y Team desborda el campo de 4 dígitos

- **Ubicación:** `IgasDispensarios/UIGASWAYNE2W.pas` líneas 2391-2400 (2396-2397), 2567-2621 (2582-2585), 3579-3590 (3587-3588); UIGASHONGYANG.pas 918-940 (926-932), 1055-1059, 980-988, 859-873; UIGASTEAM.pas 2151-2196 (2157-2159, 2167-2190)
- **Módulos afectados:** UIGASWAYNE2W.pas, UIGASHONGYANG.pas, UIGASTEAM.pas
- **Se atiende en:** [E1.5](../PLAN_OPTIMIZACION.md#e15--precios-aplicar-solo-lo-confirmado)
- **Verificación:** sin verificación independiente
- **Qué pasa:** En Wayne 2W, CPREC solo exige nprec>0 (2396-2397). CambiaPrecios arma el precio en 16 bits: xprecio:=Trunc(p*100+0.01); val1:=xprecio div 256; char(val1) (2582-2585). Un Char() de un entero mayor que 255 se queda con el byte bajo sin error, porque con $R- los typecasts no se verifican. Así, 655.37 se programa como 0.01, y un precio capturado en centavos por error (2450 en lugar de 24.50, es decir, 245000) se programa como 483.92. IniciaPrecios responde 'True|' de inmediato (3587-3588) y el Bridge ya había confirmado el PRICES. En Hong Yang, IniciaPrecios tampoco tiene tope (926-932): 'U'+IntToClaveNum(i,2)+IntToClaveNum(ii,4) con ii>=10000 da 5 dígitos, y al armar el comando se toma copy(LinCmnd,4,4) (1057). Si IntToClaveNum no trunca, 100.00 se programaría como 10.00; ULIBGRAL no está en el repo, así que la certeza es media. LPrecios y TMangueras.precio quedan en 100.00 (ver HYA-11 y HYA-30). En Team, CPREC tampoco tiene tope, y con ii>=10000 la trama 'U' crece un carácter por cada precio (2167-2190), con un efecto que no se puede verificar sin ULIBGRAL. Wayne, PAM y Gilbarco sí validan, con ValidaCifra o con 'Precio incorrecto'.
- **Evidencia:** UIGASWAYNE2W.pas 2582-2585: xprecio:=Trunc(TPosCarga[xPosCarga].TNuevoPrec[xp]*100+0.01); val1:=(xprecio)div(256); val2:=(xprecio)mod(256); stComando:= char(ControlByte(xPosCarga,7))+#1+char(xposfis-1)+char(val2)+char(val1). Cálculo: 245000 div 256 = 957, y char(957) = #189; 189*256+8 = 48392, es decir, 483.92. UIGASHONGYANG.pas 932: MeteACola('U'+IntToClaveNum(i,2)+inttoclavenum(ii,4)); 1057: xprecio:=strtointdef(copy(LinCmnd,4,4),0).
- **Impacto:** La bomba queda programada con un precio distinto, y mucho menor, del que OpenGas cree vigente, así que se vende a precio erróneo. Combinado con la falta de autenticación, es una vía directa de fraude con un PRICES mal formado.
- **Recomendación:** Validar en IniciaPrecios, antes de encolar, cada precio con ValidaCifra(p, enteros, 2) según el formato de la marca: en Wayne 2W, como máximo 655.35 (mejor aún, el máximo real de la bomba); en Hong Yang y Team, como máximo 99.99. Si un precio falla, responder 'False|Precio N fuera de rango|' sin aplicar ninguno. En CambiaPrecios, abortar si xprecio>65535. Agregar una prueba unitaria del armado de la trama con 24.50, 99.99, 100.00, 655.36 y 2450.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="SEG-07"></a>
#### SEG-07 · 🟡 Media · seguridad — Hallazgo de seguridad reservado

- **Detalle:** reservado. Está en el anexo privado de seguridad, que no se versiona porque los repositorios son públicos.
- **Se atiende en:** [E8.5](../PLAN_OPTIMIZACION.md#e85--hallazgos-de-seguridad-reservados)

<a id="SEG-08"></a>
#### SEG-08 · 🟡 Media · seguridad · riesgo — Servicios como LocalSystem, instalados desde una carpeta de usuario, con logs, ini y DLL en rutas que pueden escribir usuarios sin privilegios

- **Ubicación:** `IgasDispensarios/instalador.bat` líneas 1-2; UIGASWAYNE2W.dfm 1-11 y UIGASBRIDGE.dfm 1-8 (sin ServiceStartName); rutaLog por defecto: UIGASWAYNE2W.pas 418, UIGASWAYNE.pas 292, UIGASBENNETT.pas 262, UIGASTEAM.pas 299, UIGASPAM.pas 274, UIGASHONGYANG.pas 276, UIGASGILBARCO.pas 320, UIGASBRIDGE.pas 236; UIGASGILBARCO.pas 1917; PDISPENSARIOS.dpr 32; UIGASBRIDGE.pas 235
- **Módulos afectados:** instalador.bat, UIGASBRIDGE.dfm, UIGASWAYNE.dfm, UIGASWAYNE2W.dfm, UIGASBENNETT.dfm, UIGASTEAM.dfm, UIGASPAM.dfm, UIGASHONGYANG.dfm, UIGASGILBARCO.dfm, UIGASBRIDGE.pas, drivers (rutaLog)
- **Se atiende en:** [E0.5](../PLAN_OPTIMIZACION.md#e05--configuración-documentada-y-validada-al-arrancar)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Ningún .dfm define ServiceStartName, así que /INSTALL registra PDISPENSARIOS y PDISPBRIDGE como LocalSystem. instalador.bat instala el exe desde C:\Users\jorge\Dropbox\Proyectos\IgasDispensarios (la carpeta de un usuario, sincronizada por Dropbox) y no fija ACL. El exe lee su configuración de su propia carpeta (PDISPENSARIOS.ini y PDispBridge.ini) y, si se reactiva HASP, cargaría también de ahí OG.Hasp.dll y hasp_windows_53647.dll. Los logs van por defecto a C:\ImagenCo y C:\OpenGas\Logs (y Gilbarco escribe c:\OGTrace.txt). Con la ACL por defecto de C:\ en Windows, 'Usuarios autentificados' pueden crear carpetas en la raíz y reciben Modificar por herencia en las subcarpetas. Salvo que el instalador de OpenGas ajuste los permisos, cualquier usuario local puede leer o borrar los logs. Si el exe vive fuera de Program Files, también puede reemplazar el exe, el ini o las DLL y ejecutar código como SYSTEM. No se verificó el despliegue real en sitio.
- **Evidencia:** instalador.bat 1: C:\Users\jorge\Dropbox\Proyectos\IgasDispensarios\PDISPENSARIOS.exe /INSTALL. Los .dfm solo tienen DisplayName, OnExecute, etc.; no hay ServiceStartName ni Password. UIGASWAYNE2W.pas 418: rutaLog:=config.ReadString('CONF','RutaLog','C:\ImagenCo'); UIGASBRIDGE.pas 236: 'C:\OpenGas\Logs'; UIGASGILBARCO.pas 1917: pSerial.TraceName := 'c:\OGTrace.txt'.
- **Impacto:** Escalamiento local a SYSTEM en el equipo de la estación, manipulación de la configuración (Marca, ServidorSocket, RutaLog) y lectura de bitácoras con datos comerciales.
- **Recomendación:** Instalar en %ProgramFiles%\OpenGas\..., con ACL de solo lectura para Users. Llevar los logs a %ProgramData%\OpenGas\Logs, con ACL para SYSTEM y Administradores (y lectura para un grupo de soporte). Usar una cuenta de servicio dedicada o 'NT SERVICE\<nombre>' (sc config obj=), con acceso solo al puerto COM y a sus carpetas. Versionar un script de instalación que fije ACL, regla de firewall (E5.5) y 'sc failure'. Prueba: revisar con icacls las carpetas después de instalar e intentar escribir con un usuario estándar.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="SEG-09"></a>
#### SEG-09 · 🟡 Media · seguridad — Hallazgo de seguridad reservado

- **Detalle:** reservado. Está en el anexo privado de seguridad, que no se versiona porque los repositorios son públicos.
- **Se atiende en:** [E8.5](../PLAN_OPTIMIZACION.md#e85--hallazgos-de-seguridad-reservados)

<a id="SEG-10"></a>
#### SEG-10 · 🟡 Media · seguridad — Hallazgo de seguridad reservado

- **Detalle:** reservado. Está en el anexo privado de seguridad, que no se versiona porque los repositorios son públicos.
- **Se atiende en:** [E8.5](../PLAN_OPTIMIZACION.md#e85--hallazgos-de-seguridad-reservados)

<a id="SEG-11"></a>
#### SEG-11 · ⚪ Baja · seguridad — Hallazgo de seguridad reservado

- **Detalle:** reservado. Está en el anexo privado de seguridad, que no se versiona porque los repositorios son públicos.
- **Se atiende en:** [E8.5](../PLAN_OPTIMIZACION.md#e85--hallazgos-de-seguridad-reservados)

<a id="SEG-12"></a>
#### SEG-12 · ⚪ Baja · seguridad — Hallazgo de seguridad reservado

- **Detalle:** reservado. Está en el anexo privado de seguridad, que no se versiona porque los repositorios son públicos.
- **Se atiende en:** [E8.5](../PLAN_OPTIMIZACION.md#e85--hallazgos-de-seguridad-reservados)

<a id="SEG-13"></a>
#### SEG-13 · ⚪ Baja · seguridad · riesgo — Las respuestas a OpenGas exponen rutas absolutas y textos internos de excepción, y la ruta que devuelve TRACE puede no existir

- **Ubicación:** `IgasDispensarios/UIGASWAYNE2W.pas` líneas 3551-3554, 3557, 3593, 3707, 899, 732, 803; ruta en TRACE: UIGASWAYNE.pas 2488, UIGASBENNETT.pas 1966, UIGASTEAM.pas 1370, UIGASPAM.pas 2468, UIGASHONGYANG.pas 2445, UIGASGILBARCO.pas 466; UIGASBRIDGE.pas 846
- **Módulos afectados:** UIGASWAYNE2W.pas, UIGASWAYNE.pas, UIGASBENNETT.pas, UIGASTEAM.pas, UIGASPAM.pas, UIGASHONGYANG.pas, UIGASGILBARCO.pas
- **Se atiende en:** [E2.4](../PLAN_OPTIMIZACION.md#e24--bitácoras-que-no-bloquean-append-incremental-rotación-y-sin-json-repetido)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Amplía BRG-23, que cubre el lado del Bridge, hacia los drivers. En los 7 drivers, TRACE responde 'True|'+rutaLog+'\LogDisp'+FiltraStrNum(FechaHoraToStr(Now))+'.txt|', lo que revela la estructura de carpetas del servidor. Además, el nombre se recalcula con un segundo Now() después de SaveToFile (W2W 3551 contra 3554): si el segundo cambia entre ambas llamadas, la ruta devuelta no corresponde al archivo guardado. Cada driver tiene unos 20 puntos que devuelven 'False|Excepcion: '+e.Message+'|'. Ese texto incluye mensajes de la RTL con el valor recibido (por ejemplo, "'abc' is not a valid integer value"), nombres de clase o mensajes de Async Pro con el número de puerto. Como el Resultado viaja sin sanear, un e.Message con '|' o con caracteres de control rompe el formato de la respuesta, porque el Bridge la envuelve tal cual (846).
- **Evidencia:** UIGASWAYNE2W.pas 3551: ListaLog.SaveToFile(rutaLog+'\LogDisp'+FiltraStrNum(FechaHoraToStr(Now))+'.txt'); 3554: AddPeticionJSON(folio, 'True|'+rutaLog+'\LogDisp'+FiltraStrNum(FechaHoraToStr(Now))+'.txt|'); 3593: AddPeticionJSON(folio, 'False|Excepcion: '+e.Message+'|'). grep -c "e.Message+'|')": de 19 a 22 coincidencias por driver, salvo Gilbarco.
- **Impacto:** Facilita el reconocimiento a quien ya tiene acceso al puerto, y OpenGas puede recibir respuestas mal formadas.
- **Recomendación:** Calcular el nombre del archivo una sola vez y reutilizarlo. Responder a OpenGas con códigos de error estables ('False|E101 Error interno|') y dejar e.Message y la ruta solo en el log, o mantener la ruta si OpenGas la usa. Sanear '|' y los caracteres menores que #32 en todo Resultado, con una función común. Probar un TRACE justo en el cambio de segundo y un INITIALIZE con un número inválido.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="SEG-14"></a>
#### SEG-14 · ⚪ Baja · seguridad — Hallazgo de seguridad reservado

- **Detalle:** reservado. Está en el anexo privado de seguridad, que no se versiona porque los repositorios son públicos.
- **Se atiende en:** [E8.5](../PLAN_OPTIMIZACION.md#e85--hallazgos-de-seguridad-reservados)

<a id="SEG-15"></a>
#### SEG-15 · ⚪ Baja · seguridad · riesgo — No se verifica la integridad ni la firma del ejecutable y sus DLL: el MD5 en el log solo sirve para identificar

- **Ubicación:** `IgasDispensarios/UVersionModulo.pas (copia idéntica en IgasDispensariosBridge)` líneas 37-75, 99-120, 123-129; PDISPENSARIOS.dpr 23; .gitignore 11, 25; DLL en la raíz del repo
- **Módulos afectados:** UVersionModulo.pas (ambos repos), PDISPENSARIOS.dpr, PDISPBRIDGE.dpr, DLL HASP
- **Se atiende en:** [E0.1](../PLAN_OPTIMIZACION.md#e01--build-reproducible-de-ambos-ejecutables)
- **Verificación:** sin verificación independiente
- **Qué pasa:** UVersionModulo calcula al cargar el MD5 del propio exe (MD5Archivo, 37-75; inicialización, 128-129) y lo agrega al log con InfoVersionModulo. Eso ayuda a identificar la versión, pero no protege nada: lo calcula el mismo binario que se querría verificar, usa MD5 y nadie lo compara con un valor esperado. Los .exe no se firman (no hay script de build ni signtool), y el VERSIONINFO depende de un .res que git ignora (BRG-30). De las DLL versionadas, solo hasp_net_windows.dll tiene firma Authenticode; HaspDelphiAdapter.dll, OG.Hasp.dll, apidsp_windows*.dll y hasp_windows_53647.dll no la tienen. Si además se instala desde una carpeta de usuario (ver el hallazgo de LocalSystem), no hay forma de saber si el binario que corre en una estación es el que se liberó.
- **Evidencia:** UVersionModulo.pas 58-62: CryptHashData(...) con CALG_MD5 ($8003, línea 18); 105-116: Result:='Ejecutable: '+archivo+' | Version archivo: '+VersionArchivo(archivo)+...+' | MD5: '+md5. .gitignore 11 y 25: *.res. El directorio de seguridad del PE tiene tamaño 0 en 5 de las 6 DLL.
- **Impacto:** Un exe o una DLL alterados, por error de despliegue o a propósito, no se detectan. En un sistema con relevancia metrológica, eso dificulta demostrar qué versión controló las ventas.
- **Recomendación:** Firmar con Authenticode los exe y las DLL propias durante el build. Publicar el SHA-256 de cada entregable. Al arrancar, validar la firma (WinVerifyTrust) o comparar el SHA-256 con un manifiesto firmado, y registrar el resultado. Cambiar MD5 por SHA-256 en UVersionModulo (CALG_SHA_256 con PROV_RSA_AES). Prueba: modificar un byte del exe y verificar que el log lo marque.
- **Esfuerzo:** M · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="SEG-16"></a>
#### SEG-16 · ⚪ Baja · seguridad — Hallazgo de seguridad reservado

- **Detalle:** reservado. Está en el anexo privado de seguridad, que no se versiona porque los repositorios son públicos.
- **Se atiende en:** [E8.5](../PLAN_OPTIMIZACION.md#e85--hallazgos-de-seguridad-reservados)

<a id="SEG-17"></a>
#### SEG-17 · ⚪ Baja · seguridad — Hallazgo de seguridad reservado

- **Detalle:** reservado. Está en el anexo privado de seguridad, que no se versiona porque los repositorios son públicos.
- **Se atiende en:** [E8.5](../PLAN_OPTIMIZACION.md#e85--hallazgos-de-seguridad-reservados)

