# Hallazgos · COM · Componentes compartidos y build

> Anexo del [plan de optimización](../PLAN_OPTIMIZACION.md). Código auditado: `IgasDispensarios@26ccfb4`, `IgasDispensariosBridge@99edafd`. Las líneas pueden haber cambiado: ubica las rutinas por su nombre. Kairos (Marca 7) y Triton (Marca 10) quedan fuera de alcance: si el texto los menciona, es solo como contexto.

## Cómo funciona este módulo

Componentes compartidos e infraestructura de build y despliegue de los dos repos: uLkJSON, UVersionModulo, OG_Hasp/hasp_unit, librerías Lb*, .dpr, .cfg, .ini, instalador.bat, .gitignore, DLL y .dfm. Los hallazgos con información sensible están en el anexo privado de seguridad (item E8.5).

## Hallazgos (18)

<a id="COM-01"></a>
#### COM-01 · 🟠 Alta · seguridad — Hallazgo de seguridad reservado

- **Detalle:** reservado. Está en el anexo privado de seguridad, que no se versiona porque los repositorios son públicos.
- **Se atiende en:** [E8.5](../PLAN_OPTIMIZACION.md#e85--hallazgos-de-seguridad-reservados)

<a id="COM-02"></a>
#### COM-02 · 🟡 Media · build_despliegue · riesgo — OG_Hasp en el .dpr exige hasp_windows_delphi.obj, que nunca se versionó y que *.obj ignora; ningún driver lo usa

- **Ubicación:** `IgasDispensarios/PDISPENSARIOS.dpr` líneas 11; hasp_unit.pas 750-774; OG_Hasp.pas 6; .gitignore 9
- **Módulos afectados:** PDISPENSARIOS.dpr, OG_Hasp.pas, hasp_unit.pas, .gitignore
- **Se atiende en:** [E0.1](../PLAN_OPTIMIZACION.md#e01--build-reproducible-de-ambos-ejecutables)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Amplía BEN-42 y E0.1, que solo mencionan CRCs e IdHash. PDISPENSARIOS.dpr:11 enlaza OG_Hasp, que usa hasp_unit, LbCipher y LbString (OG_Hasp.pas:6). hasp_unit.pas:750 tiene {$L hasp_windows_delphi.obj} y declara 23 funciones external (752-774) que se resuelven en ese .obj. El .obj no está en el árbol ni en ningún commit (git log --all -- '*.obj' no devuelve nada) y .gitignore:9 ignora *.obj, así que ni por accidente se versionaría. Ningún driver usa OG_Hasp ni THaspOG: la validación HASP comentada de los drivers usa COM (CreateOleObject('HaspDelphiAdapter.HaspAdapter')). Por eso, aunque se restauren CRCs.pas e IdHash*.pas, un clon limpio no compila: dcc32 se detiene con 'File not found: hasp_windows_delphi.obj', salvo que exista un hasp_unit.dcu viejo en la carpeta de DCU compartida (-N C:\delphi\dcu).
- **Evidencia:** PDISPENSARIOS.dpr:11 "OG_Hasp in 'OG_Hasp.pas',"; hasp_unit.pas:750 "{$L hasp_windows_delphi.obj }"; .gitignore:9 '*.obj'; grep 'OG_Hasp|THaspOG' en UIGAS*.pas: sin resultados; los drivers solo tienen '// haspObj := CreateOleObject(...)' (WAYNE 2524, WAYNE2W 3611, BENNETT 1875, TEAM 1267, PAM 2397, HONGYANG 2355, GILBARCO 617).
- **Impacto:** Solo la máquina del autor compila el exe que va a todas las estaciones. Un parche urgente depende de esa máquina y de DCU binarios de origen desconocido.
- **Recomendación:** Quitar OG_Hasp de PDISPENSARIOS.dpr; con eso sale también hasp_unit, que solo se usa ahí. Si E8.1 decide conservar la ruta nativa de HASP, versionar hasp_windows_delphi.obj con una excepción explícita en .gitignore (!hasp_windows_delphi.obj) y registrar su SHA-256 en docs/DEPENDENCIAS.md. Validar compilando en una VM limpia con el build.bat de E0.1, después de vaciar C:\delphi\dcu.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="COM-03"></a>
#### COM-03 · 🟡 Media · build_despliegue · riesgo — Los dos proyectos se acoplan por una carpeta de DCU compartida: el CRC del protocolo OpenGas sale de un CRCs.dcu sin fuente versionada

- **Ubicación:** `IgasDispensariosBridge/PDISPBRIDGE.cfg` líneas 10, 36, 39-42; PDISPENSARIOS.cfg 10, 35-42; PDISPBRIDGE.dpr 3-6; UIGASBRIDGE.pas 7, 314, 459-471
- **Módulos afectados:** PDISPBRIDGE.cfg, PDISPBRIDGE.dpr, PDISPENSARIOS.cfg, UIGASBRIDGE.pas
- **Se atiende en:** [E0.1](../PLAN_OPTIMIZACION.md#e01--build-reproducible-de-ambos-ejecutables)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Amplía BRG-30 y WAY-45. PDISPENSARIOS.cfg:36 escribe sus DCU en C:\delphi\dcu. PDISPBRIDGE.cfg:39-42 pone C:\Delphi\DCU en primer lugar de -U/-O/-I/-R, mientras escribe sus propios DCU en c:\delphi\ (36). UIGASBRIDGE.pas:7 usa CRCs, ULIBGRAL y RxMemDS, que no están en el repo del Bridge, y PDISPBRIDGE.dpr:3-6 no declara ninguna unidad con 'in', ni siquiera uLkJSON. CRCs.pas existió en IgasDispensarios y se borró en 8230dd7, un commit titulado 'Eliminación de archivos hasp anteriores' aunque CRCs no es de HASP; el Bridge nunca lo tuvo. Por las rutas, lo más probable es que el Bridge enlace el CRCs.dcu que dejó un build de PDISPENSARIOS, o el que haya en \Imagen Ib Libs. Ese archivo define CRC16Desc (Width 16, Polynom $8005, Init 0, RefIn/RefOut True, XorOut 0, o sea CRC-16/ARC): es el checksum de todas las tramas con OpenGas (UIGASBRIDGE 314 y 459-471). Además: los .cfg compilan las mismas unidades compartidas con directivas distintas (-$J+ en PDISPENSARIOS.cfg:10 y -$J- en PDISPBRIDGE.cfg:10); las rutas sin letra de unidad ('\Imagen Ib libs\Libs') dependen de la unidad actual; y el -U de PDISPENSARIOS incluye carpetas de otro sistema (Imagen Ib Vtas, Cxp tres veces, quickrpt), donde cualquier homónimo de ULIBGRAL gana por orden. No pude comprobar qué DCU se enlaza de verdad: lo infiero de las rutas.
- **Evidencia:** PDISPENSARIOS.cfg:36 -N"C:\delphi\dcu"; PDISPBRIDGE.cfg:36 -N"c:\delphi\" y :39 -U"C:\Delphi\DCU;C:\Imagen Ib Libs\Util;..."; git show 8230dd7~1:CRCs.pas, líneas 191-197 (CRC16Desc); git log --all -- CRCs.pas en el repo del Bridge: vacío.
- **Impacto:** Compilar PDISPENSARIOS con otra versión de una librería, o limpiar C:\Delphi\DCU, cambia en silencio el binario del Bridge. Si cambiara el CRC, OpenGas rechazaría todas las tramas. Los builds no se pueden repetir entre máquinas.
- **Recomendación:** 1) Dar a cada proyecto su propia carpeta de salida relativa (-N.\dcu) y no poner la salida del otro en -U. 2) Vendorizar CRCs.pas (YLPL) en una carpeta común o, mejor, reemplazarlo en el Bridge por una función CRC16_ARC de unas 15 líneas, con prueba del valor de control CRC-16/ARC('123456789') = $BB3D. 3) Declarar en el .dpr, con 'in', todas las unidades propias (uLkJSON, CRCs). 4) Unificar las directivas de las unidades compartidas o fijarlas en cada unidad ({$J-}). 5) Quitar del -U las carpetas de otros sistemas y usar rutas relativas o con letra de unidad. Validar con build.bat en una VM limpia, comparando el CRC de 10 tramas reales tomadas de LogOG.
- **Esfuerzo:** M · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="COM-04"></a>
#### COM-04 · 🟡 Media · mantenibilidad · deuda_tecnica — CRCs, Indy, LockBox, RxLib/DB y OG_Hasp solo sostienen código muerto o decorativo: conviene quitarlos en lugar de vendorizarlos

- **Ubicación:** `IgasDispensarios/PDISPENSARIOS.dpr` líneas 8-11; uses 7-8 de UIGASWAYNE, UIGASWAYNE2W, UIGASBENNETT, UIGASTEAM, UIGASPAM, UIGASHONGYANG y UIGASGILBARCO
- **Módulos afectados:** PDISPENSARIOS.dpr, UIGASWAYNE.pas, UIGASWAYNE2W.pas, UIGASBENNETT.pas, UIGASTEAM.pas, UIGASPAM.pas, UIGASHONGYANG.pas, UIGASGILBARCO.pas, Lb*.pas, OG_Hasp.pas, hasp_unit.pas
- **Se atiende en:** [E0.1](../PLAN_OPTIMIZACION.md#e01--build-reproducible-de-ambos-ejecutables)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Amplía E0.1 (pasos 3 y 7, que proponen documentar o vendorizar estas unidades), PAM-40 y PAM-41. Revisé los usos reales. (a) CRCs: los 7 drivers declaran CRC16 (WAYNE 332-344, WAYNE2W 513-532, BENNETT 2521-2533, TEAM 1629-1641, PAM 2777-2789, HONGYANG 436-448, GILBARCO 437-449), pero ninguno la llama; el framing con OpenGas ya lo hace el Bridge. (b) LockBox (LbCipher, LbProc, LbString, LbUtils y los .inc, unas 5.100 líneas): solo la usan Encrypt/Decrypt de BENNETT 2630/2641, PAM 2882/2900 y HONGYANG 2693/2711, que nadie llama, y OG_Hasp, que tampoco se usa. Wayne la declara en uses (UIGASWAYNE.pas:8) sin tener Encrypt. LbUtils no la usa ninguna unidad. (c) Indy IdHash/IdHashMessageDigest: solo calcula el MD5 del LOGIN decorativo (WAYNE 701, WAYNE2W 969, BENNETT 2549, TEAM 3052, PAM 2844, HONGYANG 840, GILBARCO 493), y UVersionModulo ya tiene MD5 por CryptoAPI (37-75). Hoy conviven tres implementaciones de MD5. (d) PAM declara DB y RxMemDS (UIGASPAM.pas:7) sin usarlas: eso obliga a tener RxLib para compilar el exe de todas las marcas y enlaza código de BDE. (e) OG_Hasp/hasp_unit: ver el hallazgo del .obj.
- **Evidencia:** grep -n 'CRC16(' en los 7 drivers, sin contar la declaración: vacío; grep '[^a-zA-Z]Encrypt(|Decrypt(' sin llamadas; grep 'RxMemoryData|TDataSet' en UIGASPAM.pas: vacío; grep LbUtils: solo LbUtils.pas.
- **Impacto:** Cada dependencia muerta es una pieza más que conseguir, versionar y auditar para compilar. Tres de ellas (CRCs, IdHash* y el .obj) ya faltan y bloquean el build limpio.
- **Recomendación:** En un commit sin cambio funcional: quitar CRC16, Encrypt y Decrypt de los drivers, y CRCs, LbCipher y LbString de sus uses. Quitar DB y RxMemDS de UIGASPAM.pas. Quitar OG_Hasp, CRCs, IdHash e IdHashMessageDigest del .dpr. Borrar Lb*.pas/.inc, LockBox.inc, OG_Hasp.pas y hasp_unit.pas si E8.1 descarta la ruta nativa. Si LOGIN se conserva, exponer en una unidad común una función MD5Texto con CryptoAPI (basada en MD5Archivo de UVersionModulo) y eliminar Indy. Compilar con hints activos para confirmar que no queda ninguna referencia. El Bridge sí necesita el CRC (ver el hallazgo de CRC-16/ARC).
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="COM-05"></a>
#### COM-05 · 🟡 Media · observabilidad · riesgo — El ejecutable no se puede ligar a una revisión: .dof y .res fuera del repo, sin tags, y sin el SHA que antes llevaba el .dpr

- **Ubicación:** `IgasDispensarios/UVersionModulo.pas` líneas 77-97, 99-120, 128-129; .gitignore 11, 22, 25; PDISPENSARIOS.dpr 23; PDISPBRIDGE.dpr 8
- **Módulos afectados:** UVersionModulo.pas (ambos repos), PDISPENSARIOS.dpr, PDISPBRIDGE.dpr, .gitignore (ambos repos)
- **Se atiende en:** [E0.1](../PLAN_OPTIMIZACION.md#e01--build-reproducible-de-ambos-ejecutables)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Amplía E0.1 y BRG-30. UVersionModulo registra 'Version archivo' (el VERSIONINFO del .res, 77-97) y el MD5 del exe. Pero el VERSIONINFO viene del .res, que el IDE genera desde el .dof, y ninguno de los dos está versionado: .gitignore ignora *.res (11 y 25) y *.dof (22). El Bridge sí los tenía, y se borraron en a321c8d (2026-07-10); su .dof decía FileVersion=4.2.1.4, AutoIncBuild=0 y EurekaLog 6015. Desde entonces, un build en otra máquina genera un .res nuevo con la versión por defecto, o sin VERSIONINFO, en cuyo caso VersionArchivo devuelve ''. El campo no identifica nada. Ningún repo tiene tags (git tag no devuelve nada). El commit 0b222dc quitó del .dpr la constante version:='e97749735baccfa70a7ae60712eb1d0f3af3b49c', la única liga explícita con un commit, y la sustituyó por el MD5. El MD5 solo sirve si alguien lleva la tabla MD5 -> commit, y esa tabla no existe. El plan (sección 8) cuenta con ese MD5 para las reversas.
- **Evidencia:** git -C IgasDispensariosBridge show --stat a321c8d: PDISPBRIDGE.dof (-628 líneas) y PDISPBRIDGE.res borrados; git show a321c8d~1:PDISPBRIDGE.dof: 'FileVersion=4.2.1.4'; git show 0b222dc -- PDISPENSARIOS.dpr: "-  version:='e97749735baccfa70a7ae60712eb1d0f3af3b49c';"; git tag vacío en ambos repos.
- **Impacto:** Ante una falla en campo o una auditoría (CENAM) no se puede saber qué fuente corresponde al binario instalado, ni reconstruirlo. Las reversas dependen de conservar exes sueltos.
- **Recomendación:** 1) Versionar PDISPENSARIOS.rc y PDISPBRIDGE.rc con VERSIONINFO, y que build.bat inyecte FileVersion y ProductVersion a partir de 'git describe --tags --always --dirty'. 2) Generar en el build un UBuildInfo.inc con const COMMIT_SHA y agregarlo a la línea de InfoVersionModulo. 3) Crear un tag anotado por release en ambos repos y llevar docs/RELEASES.md con fecha, tag, MD5 y SHA-256 de cada exe, el .map archivado y las estaciones donde se instaló. 4) No compilar para producción con el árbol sucio. Validar comparando la línea de InfoVersionModulo de un exe de prueba con git show del tag.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="COM-06"></a>
#### COM-06 · 🟡 Media · robustez · bug — Marca inválida, vacía o ausente: StrToInt sin default y un case sin else dejan un proceso sin servicio y sin log (la Marca 8 no existe)

- **Ubicación:** `IgasDispensarios/PDISPENSARIOS.dpr` líneas 32-33, 35-63, 65
- **Módulos afectados:** PDISPENSARIOS.dpr, PDISPENSARIOS.ini
- **Se atiende en:** [E2.3](../PLAN_OPTIMIZACION.md#e23--arranque-y-paro-ordenados-del-servicio)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El .dpr lee la Marca con StrToInt(config.ReadString('CONF','Marca','0')) (33). Si la clave existe vacía ('Marca=') o con texto, StrToInt lanza EConvertError antes de Application.Run y fuera de todo try. Con /INSTALL el usuario ve el error. Como servicio, la excepción llega al manejador por defecto del RTL, que muestra un MessageBox en la sesión 0 o termina el proceso. El SCM reporta 1053/1067 y ningún log del producto lo registra, porque los logs se crean en el ServiceExecute del driver. Si la clave falta, o vale 0, 8 (la numeración tiene un hueco: 1-7, 9, 10) o cualquier otro número, el case (35-63) no tiene else y no se crea ningún TService. En ese caso /INSTALL recorre cero servicios y, por lo que conozco de SvcMgr de D7, igual muestra 'Service installed successfully'; como servicio, StartServiceCtrlDispatcher recibe una tabla vacía y el proceso termina. Tampoco se libera el TIniFile (32). El fuente de SvcMgr no está en el repo: el comportamiento exacto con cero servicios lo cito de memoria (certeza media).
- **Evidencia:** PDISPENSARIOS.dpr:33 "marca:=StrToInt(config.ReadString('CONF','Marca','0'));"; 35-63 'case marca of' con 1..7, 9 y 10, sin else; 65 'Application.Run;'.
- **Impacto:** Un ini mal editado en sitio deja la estación sin control de dispensarios y sin pistas del motivo. El instalador puede reportar éxito sin haber instalado nada.
- **Recomendación:** Envolver la selección en try/except y usar StrToIntDef(...,-1). Agregar un else que escriba en el Visor de eventos (TEventLogger.Create('PDISPENSARIOS').LogMessage('Marca invalida: '+valor, EVENTLOG_ERROR_TYPE)) y en un archivo de texto junto al exe, y que con /INSTALL muestre el error y salga con código distinto de 0 (Halt(1)). Liberar config en un finally. Declarar las marcas como constantes con nombre y documentar la tabla Marca -> driver en el README y en PDISPENSARIOS.ini.ejemplo (E0.5). Probar /INSTALL y el arranque con Marca vacía, 8, 'abc' y 9.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="COM-07"></a>
#### COM-07 · 🟡 Media · build_despliegue · riesgo — Un solo ejecutable enlaza las 9 marcas: cualquier cambio en un driver cambia el binario, y su MD5, en todas las estaciones

- **Ubicación:** `IgasDispensarios/PDISPENSARIOS.dpr` líneas 13-21, 35-63; UVersionModulo.pas 37-75, 99-120
- **Módulos afectados:** PDISPENSARIOS.dpr, UVersionModulo.pas, todos los drivers
- **Se atiende en:** [E0.1](../PLAN_OPTIMIZACION.md#e01--build-reproducible-de-ambos-ejecutables)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El .dpr enlaza siempre los 9 drivers (13-21) y elige uno en tiempo de ejecución. Para build y release esto implica cuatro cosas. (1) Un cambio en Team cambia el MD5 que UVersionModulo calcula sobre el exe completo (37-75) también para Wayne, Gilbarco y las demás. Si la identificación del software ante CENAM se liga al MD5 o a la versión del exe (el historial tiene commits 'previo a CENAM': 0e02888 y 3b61b09), corregir una marca obliga a reevaluar todas o deja estaciones con un binario distinto del revisado. (2) Un error de compilación o una dependencia de un driver (RxLib por PAM, el .obj de HASP por el .dpr) bloquea el release de todas las marcas. (3) No se puede publicar un parche para una sola marca sin redistribuir, y volver a probar, el código de las otras. (4) Un equipo no puede tener dos marcas (ver el hallazgo de nombres de servicio). Lo de CENAM es una inferencia a partir de los mensajes de commit; no conozco el criterio de certificación.
- **Evidencia:** PDISPENSARIOS.dpr:13-21: UIGASPAM, UIGASBENNETT, UIGASWAYNE, UIGASHONGYANG, UIGASGILBARCO, UIGASKAIROS, UIGASTEAM, UIGASWAYNE2W, UIGASTRITON; git log: 0e02888 'Adecuaciones durante pruebas previas a CENAM', 3b61b09 'Modificación comentarios previo a visita a CENAM'.
- **Impacto:** Cada cambio tiene el mayor radio de impacto posible: más regresión por release y riesgo de que el binario instalado no sea el certificado.
- **Recomendación:** Conservar el .dpr único por compatibilidad, pero agregar builds por marca: {$IFDEF MARCA_xxx} en el uses y en el case, y un build.bat que genere PDISPENSARIOS_<marca>.exe con -DMARCA_xxx. Cada exe compara la Marca del ini con la compilada y, si no coinciden, lo registra y no arranca. Registrar en RELEASES.md el MD5 por marca. Otra opción: un .dpr por marca que comparta las unidades. Validar que los exes por marca pasen la batería de E0.4.
- **Esfuerzo:** M · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="COM-08"></a>
#### COM-08 · 🟡 Media · seguridad — Hallazgo de seguridad reservado

- **Detalle:** reservado. Está en el anexo privado de seguridad, que no se versiona porque los repositorios son públicos.
- **Se atiende en:** [E8.5](../PLAN_OPTIMIZACION.md#e85--hallazgos-de-seguridad-reservados)

<a id="COM-09"></a>
#### COM-09 · 🟡 Media · build_despliegue · riesgo — instalador.bat apunta a la carpeta Dropbox del desarrollador y no instala el Bridge, ni configura la recuperación del servicio, ni crea las carpetas de log

- **Ubicación:** `IgasDispensarios/instalador.bat` líneas 1-2; PDISPENSARIOS.cfg 35; UIGASWAYNE2W.pas 418; UIGASBRIDGE.pas 236
- **Módulos afectados:** instalador.bat, PDISPENSARIOS.cfg, IgasDispensariosBridge (sin instalador)
- **Se atiende en:** [E0.5](../PLAN_OPTIMIZACION.md#e05--configuración-documentada-y-validada-al-arrancar)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Amplía E2E-17 y WAY-18/TEA-29, que piden una regla de firewall y 'sc failure' en el instalador. El instalador completo es 'C:\Users\jorge\Dropbox\Proyectos\IgasDispensarios\PDISPENSARIOS.exe /INSTALL' seguido de PAUSE. Esa ruta es a la vez la carpeta del repo y la salida del compilador (PDISPENSARIOS.cfg:35 -E"C:\Users\jorge\Dropbox\Proyectos\IgasDispensarios"). En la máquina de desarrollo, el servicio corre desde la carpeta sincronizada, lee el PDISPENSARIOS.ini versionado (un ini de prueba editado ahí acaba en un commit, y así parece haber llegado la Licencia al repo) y bloquea el exe mientras corre. En cualquier otra máquina el .bat falla. Faltan: un instalador para el Bridge (su repo no tiene), /SILENT (el MessageBox de SvcMgr exige a alguien frente a la pantalla), la desinstalación, la verificación de privilegios de administrador, 'sc description', 'sc failure' (ningún TService configura recuperación), la creación de RutaLog (C:\ImagenCo en los drivers y C:\OpenGas\Logs en el Bridge; nadie las crea, ver BRG-08), la copia de un ini de plantilla y el orden de arranque.
- **Evidencia:** instalador.bat:1 'C:\Users\jorge\Dropbox\Proyectos\IgasDispensarios\PDISPENSARIOS.exe /INSTALL', :2 'PAUSE'; UIGASWAYNE2W.pas:418 ReadString('CONF','RutaLog','C:\ImagenCo'); UIGASBRIDGE.pas:236 ReadString('CONF','RutaLog','C:\OpenGas\Logs').
- **Impacto:** Cada sitio se instala a mano y de forma distinta. Un servicio que cae no se reinicia solo, y si la carpeta de logs no existe no se escribe ningún log.
- **Recomendación:** Sustituirlo por un instalar.cmd que use %~dp0 como carpeta del exe y que: verifique privilegios con 'net session'; cree las RutaLog; copie PDISPENSARIOS.ini.ejemplo y PDispBridge.ini.ejemplo si no hay ini; ejecute PDISPBRIDGE.exe /INSTALL /SILENT y PDISPENSARIOS.exe /INSTALL /SILENT; configure 'sc failure <svc> reset= 86400 actions= restart/5000/restart/5000/restart/30000' y 'sc description' para ambos servicios; agregue la regla de firewall (E2E-17); y arranque primero el Bridge. Agregar un desinstalar.cmd simétrico. Cambiar -E del .cfg a una carpeta dentro del repo e ignorada (.\bin). Probar en una VM limpia.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="COM-10"></a>
#### COM-10 · 🟡 Media · rendimiento · optimizacion — js_string de uLkJSON es O(escapes × longitud) y strSpecialChars concatena carácter por carácter: parsear un resultado de LOG puede congelar el hilo único del Bridge

- **Ubicación:** `IgasDispensarios/uLkJSON.pas` líneas 1849-1876, 1795-1832, 1542-1547 (copia idéntica en IgasDispensariosBridge/uLkJSON.pas); UIGASBRIDGE.pas 757-758, 798
- **Módulos afectados:** IgasDispensarios/uLkJSON.pas, IgasDispensariosBridge/uLkJSON.pas, UIGASBRIDGE.pas (ProcesaRespuestasJSON)
- **Se atiende en:** [E4.5](../PLAN_OPTIMIZACION.md#e45--ulkjson-y-administrador-de-memoria)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Amplía BRG-27 (E4.4 del plan), que trata el tamaño de LOG/LOGREQ, con la causa que está en la librería. GenerateText escapa '/', '\\' y comillas (1542-1547), así que cada fecha dd/mm/aa y cada ruta C:\... de una línea de log produce escapes. Al parsear, js_string (1849-1876) busca desde widx la primera comilla y, si antes encontró una barra invertida, vuelve a empezar en i+2 (1874). Por cada escape recorre hasta la siguiente comilla, que en un texto de log sin comillas es el final de la cadena: el costo es escapes × longitud. Después, strSpecialChars (1795-1832) arma el resultado carácter por carácter (Result := Result + s[j], 1828). Simulé el algoritmo con un Resultado de LOG de líneas típicas de 78 caracteres: 200 líneas (15,6 KB) cuestan 6,3 millones de comparaciones; 1000 líneas (78 KB), 156 millones; 10.000 líneas (780 KB), unos 15.600 millones, que son decenas de segundos en el hilo único del Bridge. Hoy lo atenúan dos defectos: los mensajes grandes llegan fragmentados y cada fragmento falla rápido (BRG-01), y los que contienen 'PING' se descartan (BRG-18). Corregir el framing (E6.1) y el PING (E3.2) sin corregir esto deja al Bridge expuesto a congelarse.
- **Evidencia:** uLkJSON.pas:1852-1856 'while (widx<=length(txt)) and (j=0) do begin if (i=0) and (txt[widx]=...) then i:=widx; if (j=0) and (txt[widx]=...) then j:=widx; inc(widx); end'; 1874 'widx:=i+2;'; 1828 'Result := Result + s[j];'; simulación (scratchpad/sim/js.py) con LOG de 1000 líneas: 156.096.006 comparaciones en 4001 vueltas.
- **Impacto:** Con LOG o LOGREQ grandes y el framing ya corregido, el Bridge deja de atender a OpenGas de segundos a decenas de segundos, y se disparan 'Datos obsoletos' y timeouts.
- **Recomendación:** Parche local mínimo en uLkJSON, en la copia común o en las dos (BRG-40): reescribir el escaneo de js_string en una sola pasada (saltar el carácter que sigue a cada barra invertida y parar en la primera comilla no escapada) y armar strSpecialChars con un buffer preasignado (SetLength(Result, Length(s)), un índice de escritura y un SetLength final). Opcional: dejar de escapar '/' en GenerateText; es JSON válido y el parser actual lo acepta. Documentar el parche en la cabecera ('v1.07+igas1'). Probar con un JSON de 1 MB y 20.000 escapes (meta: menos de 50 ms) y hacer round-trip de cadenas con comillas, barras, \/ y \uXXXX. Mantener también el tope de E4.4.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="COM-11"></a>
#### COM-11 · 🟡 Media · correccion · riesgo — TlkJSONlist.Delete no conserva el orden y TlkJSONobject.Delete desincroniza el índice: una trampa para cuando se amplíe Peticiones

- **Ubicación:** `IgasDispensarios/uLkJSON.pas` líneas 798-817, 1056-1078, 2451-2494, 163 (copia idéntica en el Bridge); petArr.Delete(0) en WAYNE 2237, WAYNE2W 3283, BENNETT 457, TEAM 552, PAM 582, HONGYANG 2826, GILBARCO 3298
- **Módulos afectados:** IgasDispensarios/uLkJSON.pas, IgasDispensariosBridge/uLkJSON.pas, AddPeticionJSON de los 7 drivers
- **Se atiende en:** [E4.5](../PLAN_OPTIMIZACION.md#e45--ulkjson-y-administrador-de-memoria)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Amplía E2E-23 y W2W-26, que recomiendan subir el tope de Peticiones. TlkJSONcustomlist._Delete (798-817) borra el elemento y pone el ÚLTIMO en su lugar (806-811). Los drivers recortan con 'while petArr.Count >= 2 do petArr.Delete(0)': con 2 elementos el resultado es correcto por casualidad. Con un tope de 8, Delete(0) pone el resultado más nuevo en la posición 0 y el siguiente recorte lo descarta antes que los viejos: se pierden los resultados recientes y el Bridge, que empareja por folio, nunca los recibe. TlkJSONobject.Delete (1056-1078), sin USE_HASH, llama a TlkBalTree.Delete, que resta uno a las claves mayores que el índice borrado (UpdateKeys, 2453-2461 y 2474-2476), mientras _Delete movió el último elemento al hueco. Después de borrar un campo que no es el último, Field['X'] devuelve el valor de otro campo. Hoy nadie llama TlkJSONobject.Delete, así que el problema está latente. Además, {$DEFINE THREADSAFE} (163) solo afecta la tabla del hash: los objetos de uLkJSON no son seguros entre hilos (relevante para BEN-01).
- **Evidencia:** uLkJSON.pas:806-811 'idx := pred(fList.Count); if iIndex<idx then begin fList.Items[iIndex] := fList.Items[idx]; fList.Delete(idx); end'; 2475 'UpdateKeys(froot, fdeleted.key);'; UIGASWAYNE2W.pas:3282-3283 'while petArr.Count >= 2 do petArr.Delete(0);'.
- **Impacto:** Si se sube la capacidad de Peticiones sin cambiar el recorte, se pierden resultados de comandos sin aviso. Un uso futuro de TlkJSONobject.Delete corrompería el snapshot.
- **Recomendación:** Corregir en la copia común: en _Delete usar fList.Delete(iIndex), que desplaza y conserva el orden; en TlkJSONobject.Delete, reconstruir el árbol después de borrar (ht.Clear y un Insert por cada nombre con su índice nuevo). Mientras tanto, en los drivers, recortar armando una lista nueva con los últimos N. Pruebas unitarias: lista de 8, Delete(0) y verificar el orden; objeto {a,b,c,d}, Delete(1) y verificar Field['c'] y Field['d'].
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="COM-12"></a>
#### COM-12 · 🟡 Media · seguridad — Hallazgo de seguridad reservado

- **Detalle:** reservado. Está en el anexo privado de seguridad, que no se versiona porque los repositorios son públicos.
- **Se atiende en:** [E8.5](../PLAN_OPTIMIZACION.md#e85--hallazgos-de-seguridad-reservados)

<a id="COM-13"></a>
#### COM-13 · 🟡 Media · observabilidad · riesgo — Las excepciones no controladas solo llegan al Visor de eventos y sin dirección útil: no hay manejador global ni se archiva el .map

- **Ubicación:** `IgasDispensarios/PDISPENSARIOS.dpr` líneas 29-65; PDISPBRIDGE.dpr 10-14; PDISPENSARIOS.cfg 27; .gitignore 7
- **Módulos afectados:** PDISPENSARIOS.dpr, PDISPBRIDGE.dpr, ServiceExecute de todos los servicios, .gitignore
- **Se atiende en:** [E2.4](../PLAN_OPTIMIZACION.md#e24--bitácoras-que-no-bloquean-append-incremental-rotación-y-sin-json-repetido)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Amplía BEN-19, TEA-14 y WAY-29 (manejadores sin try/except). Ningún .dpr ni unidad asigna Application.OnException ni usa un registrador de excepciones: grep de OnException, HandleException, EurekaLog y madExcept no devuelve nada. El .dof borrado del Bridge tenía configurado EurekaLog 6015, pero la unidad nunca estuvo en el uses. En un servicio de D7, la excepción que escapa de un TTimer, del socket (TCustomWinSocket.WndProc) o del serial la atrapa Forms.Application, y TServiceApplication la manda al Visor de eventos solo con E.Message y con fuente 'PDISPENSARIOS.exe' (certeza media, por el comportamiento de SvcMgr). No llega a LogDisp, que es el log que se revisa. Cuando un log sí trae 'Access violation at address 004xxxxx', no hay forma de traducirlo a una línea de código: el .cfg genera el mapa detallado (-GD, línea 27), pero *.map está ignorado (.gitignore:7) y no se archiva por release.
- **Evidencia:** PDISPENSARIOS.cfg:27 '-GD'; .gitignore:7 '*.map'; git show a321c8d~1:PDISPBRIDGE.dof: 'EurekaLog Version=6015'; ni OnException ni HandleException aparecen en ningún .pas o .dpr de los dos repos.
- **Impacto:** Las fallas intermitentes (por ejemplo, los AV por concurrencia de BEN-01) no dejan rastro en los logs del producto ni se pueden ubicar en el código.
- **Recomendación:** En el ServiceExecute de cada servicio, o en el logger común de E7.1, asignar Forms.Application.OnException a un manejador que escriba en el log del producto E.ClassName, E.Message, ExceptAddr y la dirección relativa a la imagen, y también en el Visor de eventos, con un limitador de frecuencia. Archivar el .map de cada release junto al exe, en el registro de releases (ver el hallazgo de trazabilidad), para traducir direcciones. Opcional: activar JclDebug, o EurekaLog si sigue la licencia. Validar provocando una excepción en un timer de un build de pruebas.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="COM-14"></a>
#### COM-14 · 🟡 Media · pruebas · deuda_tecnica — Sin CI ni pruebas automatizadas; la emulación de Wayne 2W simula el negocio y no las tramas, así que generalizarla no prueba el protocolo serial

- **Ubicación:** `IgasDispensarios/UIGASWAYNE2W.pas` líneas 2649-2656, 2948, 4067-4491, 845-871; .gitignore 21
- **Módulos afectados:** UIGASWAYNE2W.pas, uLkJSON.pas, ambos repos (CI)
- **Se atiende en:** [E0.4](../PLAN_OPTIMIZACION.md#e04--simuladores-de-opengas-y-de-driver--batería-de-pruebas-de-protocolo)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Amplía E0.4 (punto 4, que propone generalizar ModoEmulacion), WAY-45, GIL-47, BEN-43, HYA-37 y PAM-50. Ninguno de los dos repos tiene CI, scripts de build ni grupo de proyectos (.bpg está ignorado, .gitignore:21), ni un solo proyecto de pruebas. La emulación de Wayne 2W (funciones Emu* en 4067-4491 y AvanzaEmulacion en 4347) reemplaza en Timer1Timer al modo serial completo: 2650-2655 hace 'if SwModoEmulacion then ... AvanzaEmulacion; EstatusDispensarios', y el else, que llega hasta 2948, es el modo normal. Nunca pasa por TransmiteComando, DameEstatus, DameLecturas ni la decodificación BCD: en 4280-4493 hay 0 llamadas seriales. Sirve para probar el Bridge y OpenGas, pero no los errores de trama, desborde, BCC o reintento, que es donde está la mayoría de los hallazgos críticos. Delphi 7 no corre en los runners hospedados de GitHub, pero buena parte del código se puede probar sin D7: uLkJSON ya tiene ramas {$IFDEF fpc} para Free Pascal.
- **Evidencia:** find de *.yml o build* en ambos repos: vacío; UIGASWAYNE2W.pas:2650-2655; awk 'NR>=4280 && NR<=4493' | grep -c 'TransmiteComando|DameEstatus|DameLecturas|pSerial' -> 0; .gitignore:21 '*.bpg'.
- **Impacto:** Las correcciones de E1 y E2 solo se pueden validar en banco o en campo, y las regresiones aparecen en estaciones reales.
- **Recomendación:** 1) CI en Linux con GitHub Actions y FPC en modo Delphi: compilar y probar uLkJSON (round-trip, escapes, Delete, profundidad, cadenas de 1 MB) y las funciones puras de trama que se extraigan en E7.4 (BCD, BCC/LRC, CRC-16/ARC). Sumar verificaciones de higiene: hashes iguales de uLkJSON, UVersionModulo y docs entre repos, literales ASCII, ninguna ruta C:\Users en .cfg/.bat y ninguna DLL nueva. 2) Un runner Windows propio con dcc32 de D7 que ejecute build.bat de ambos repos en cada PR. 3) Generalizar la emulación por debajo de la capa serial: una interfaz de transporte (enviar y recibir bytes) con dos implementaciones, TApdComPort y un emulador de bomba por marca que conteste con tramas reales grabadas de LogDisp y permita inyectar NAK, BCC malo, silencios y desbordes. Empezar por Wayne 2W, reutilizando la lógica de ventas de Emu*.
- **Esfuerzo:** L · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="COM-15"></a>
#### COM-15 · ⚪ Baja · correccion · bug — UIGASTEAM.pas está en UTF-8 sin BOM: Delphi 7 compila 'Posición' como 'PosiciÃ³n' y así le llega a OpenGas; no hay .gitattributes

- **Ubicación:** `IgasDispensarios/UIGASTEAM.pas` líneas 2060, 2097, 2989, 2994 (literales); 1782, 1903, 2155, 2179 (comentarios); uLkJSON.pas 1537, 1885
- **Módulos afectados:** UIGASTEAM.pas, uLkJSON.pas, ambos repos (.gitattributes)
- **Se atiende en:** [E8.3](../PLAN_OPTIMIZACION.md#e83--código-muerto-variables-globales-y-duplicación-interna)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Delphi 7 lee los .pas como ANSI (cp1252). UIGASTEAM.pas tiene literales en bytes UTF-8 (C3 B3, C3 A1) en mensajes que salen al Bridge y a OpenGas: 'Importe fuera de rango válido' (2060), 'Combustible no existe en esta posición' (2097), 'Posición no Disponible' (2989) y 'Posición Deshabilitada' (2994). El exe los guarda como 'vÃ¡lido' y 'PosiciÃ³n'. El historial muestra que el archivo ya se había dañado antes: hasta 3b61b09~1 esos literales tenían U+FFFD (EF BF BD, 9 veces), señal de que un editor convirtió el Latin-1 original y perdió las letras; 3b61b09 los 'arregló' pasándolos a UTF-8. Gilbarco y Wayne 2W tienen UTF-8 solo en comentarios. No hay .gitattributes: los archivos están en el índice con LF (git ls-files --eol: i/lf) y dependen del core.autocrlf de cada clon. uLkJSON hace UTF8Encode al generar (1537) y UTF8Decode al parsear (1885). En D7, UTF8Decode devuelve '' cuando encuentra una secuencia inválida, así que un texto ANSI con acentos dentro de un JSON (por ejemplo, un INITIALIZE armado sin UTF-8) se vacía sin error.
- **Evidencia:** grep -nP '[^\x00-\x7F]' UIGASTEAM.pas: 8 líneas; git show 3b61b09 -- UIGASTEAM.pas: el literal pasa de 'Posici<U+FFFD>n no Disponible' a 'Posición no Disponible'; git ls-files --eol: 'i/lf w/lf attr/' en todos los .pas.
- **Impacto:** OpenGas y los operadores reciben textos de error corruptos. Además existe el riesgo de que un editor vuelva a reescribir un archivo completo en otra codificación, con cambios invisibles en el diff.
- **Recomendación:** Dejar los literales de UIGASTEAM.pas en ASCII puro, como en el resto de los drivers ('Posicion no Disponible'). Agregar .gitattributes en ambos repos: '*.pas text eol=crlf working-tree-encoding=CP1252', lo mismo para *.dfm, *.dpr, *.inc, *.cfg, *.ini y *.bat, y '*.dll binary'. Agregar a CI una verificación de literales ASCII y de ausencia de U+FFFD, y un .editorconfig con charset = latin1. Confirmar que OpenGas no compara estos textos.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="COM-16"></a>
#### COM-16 · ⚪ Baja · configuracion · riesgo — Todos los drivers usan el DisplayName 'OpenGas Dispensarios' con un Name distinto por marca: no caben dos marcas en un equipo y cambiar la Marca deja el servicio con el nombre equivocado

- **Ubicación:** `IgasDispensarios/UIGASWAYNE2W.dfm` líneas 1-4 de los .dfm de BENNETT, GILBARCO, HONGYANG, PAM, TEAM (DisplayName en 3), WAYNE y WAYNE2W (DisplayName en 4); PDISPENSARIOS.dpr 35-63
- **Módulos afectados:** UIGASBENNETT.dfm, UIGASGILBARCO.dfm, UIGASHONGYANG.dfm, UIGASPAM.dfm, UIGASTEAM.dfm, UIGASWAYNE.dfm, UIGASWAYNE2W.dfm, PDISPENSARIOS.dpr
- **Se atiende en:** [E0.5](../PLAN_OPTIMIZACION.md#e05--configuración-documentada-y-validada-al-arrancar)
- **Verificación:** sin verificación independiente
- **Qué pasa:** El nombre del servicio en el SCM es el Name del TService (ogcvdispensarios_wayne, ogcvdispensarios_wayne2w, ogcvdispensarios_gilbarco2W, etc.) y el DisplayName es 'OpenGas Dispensarios' en todos los .dfm. Consecuencias: (1) Windows exige un DisplayName único, así que instalar una segunda copia con otra marca, en una estación con dos tipos de dispensario, falla con ERROR_DUPLICATE_SERVICE_NAME (1078); además las dos usarían el mismo puerto del Bridge (BRG-25). (2) Si en sitio se cambia la Marca del ini sin reinstalar, el SCM sigue arrancando el servicio con el nombre anterior. Como es un servicio de proceso propio, Windows no valida el nombre y el driver nuevo corre, pero services.msc, el Visor de eventos y cualquier script 'sc stop ogcvdispensarios_<marca>' quedan desalineados, y /UNINSTALL con el ini nuevo intenta borrar un servicio que no existe y deja el viejo. (3) Ningún .dfm define Description ni Dependencies, y AllowPause queda en True. Sin OnPause, 'Pausar' en services.msc marca el servicio como pausado; en SvcMgr de D7, DoPause suspende el hilo del servicio (certeza media). En Bennett, donde el socket vive en ese hilo, el driver dejaría de atender al Bridge mientras los timers siguen corriendo.
- **Evidencia:** UIGASBENNETT.dfm:1-3 'object ogcvdispensarios_bennett ... DisplayName = 'OpenGas Dispensarios''; lo mismo en los otros .dfm; UIGASBRIDGE.dfm:3 'OpenGas Dispensarios Bridge'; grep de AllowPause, Dependencies y Description en UIGAS*.pas/.dfm: sin resultados.
- **Impacto:** Confusión en soporte y fallas de instalación al cambiar o combinar marcas. Un 'Pausar' accidental deja el servicio en un estado ambiguo.
- **Recomendación:** No cambiar Name, porque rompería las instalaciones existentes. En su lugar: asignar DisplayName := 'OpenGas Dispensarios (<marca>)' en tiempo de ejecución antes de instalar, poner AllowPause=False en los .dfm, y registrar Description y Dependencies (el Bridge) en AfterInstall. Documentar el procedimiento para cambiar de marca: desinstalar con el ini viejo, cambiar la Marca y reinstalar. Si se necesitan varias marcas en un equipo, agregar al ini un sufijo de instancia para Name y DisplayName, con su propio ServidorSocket. Probar en una VM instalando dos marcas.
- **Esfuerzo:** S · **Riesgo del cambio:** medio · **Toca contrato:** no

<a id="COM-17"></a>
#### COM-17 · ⚪ Baja · build_despliegue · deuda_tecnica — .gitignore copiado y divergente: ignora entradas del build (.dof, .bpg, .obj, .res) y repite reglas

- **Ubicación:** `IgasDispensarios/.gitignore` líneas 5, 7, 9, 11, 13, 16, 21-26; IgasDispensariosBridge/.gitignore 7, 11, 20, 21, 24, 27
- **Módulos afectados:** IgasDispensarios/.gitignore, IgasDispensariosBridge/.gitignore, docs/plan-optimizacion (ambos repos)
- **Se atiende en:** [E0.1](../PLAN_OPTIMIZACION.md#e01--build-reproducible-de-ambos-ejecutables)
- **Verificación:** sin verificación independiente
- **Qué pasa:** Amplía BRG-30. Los dos .gitignore son copias que ya divergieron. IgasDispensarios tiene *.drc (16) y el Bridge no, por eso el PDISPBRIDGE.drc de 2025 sigue en su repo. El Bridge repite *.map (7 y 27). Ambos repiten *.res (11/25 en IgasDispensarios y 11/24 en el Bridge), *.dsk y *.tvsconfig. Ignoran archivos que en Delphi 7 son fuente del build: *.dof (opciones y VERSIONINFO del proyecto), *.bpg (el grupo que compilaría los dos proyectos), *.obj (hasp_windows_delphi.obj) y *.res ({$R *.RES}). En cambio, no ignoran salidas locales: APRO.TRC y APRO.LOG (Async Pro los escribe en el directorio actual cuando se depura fuera del SCM), los Log*.txt ni un ini de sitio. Además, docs/plan-optimizacion está duplicado tal cual en los dos repos.
- **Evidencia:** diff IgasDispensarios/.gitignore IgasDispensariosBridge/.gitignore: '< *.drc' y '> *.map'; IgasDispensarios/.gitignore:11 y 25 '*.res', :21 '*.bpg', :22 '*.dof', :9 '*.obj'; cmp de docs/plan-optimizacion/*: 10 archivos iguales.
- **Impacto:** Se pierden archivos necesarios para reconstruir el exe, se cuelan artefactos, y cada repo corrige su .gitignore por separado.
- **Recomendación:** Usar un solo .gitignore común (o una plantilla verificada en CI) que: deje de ignorar *.dof y *.bpg, o los sustituya por .rc y build.bat versionados; agregue excepciones explícitas para los insumos (!*.rc y, si se conserva, !hasp_windows_delphi.obj); agregue *.drc, APRO.TRC, APRO.LOG, Log*.txt y *.ini con '!*.ini.ejemplo'; y elimine los duplicados. Después, git rm --cached PDISPBRIDGE.drc y PDISPENSARIOS.ini (dejando el .ejemplo). Mantener la documentación compartida en un solo repo o en el submódulo común.
- **Esfuerzo:** S · **Riesgo del cambio:** bajo · **Toca contrato:** no

<a id="COM-18"></a>
#### COM-18 · ⚪ Baja · seguridad — Hallazgo de seguridad reservado

- **Detalle:** reservado. Está en el anexo privado de seguridad, que no se versiona porque los repositorios son públicos.
- **Se atiende en:** [E8.5](../PLAN_OPTIMIZACION.md#e85--hallazgos-de-seguridad-reservados)

