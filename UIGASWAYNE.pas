unit UIGASWAYNE;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, SvcMgr, Dialogs,
  IniFiles, ScktComp, ULIBGRAL, uLkJSON, CRCs, Variants, ExtCtrls, OoMisc,
  AdPort, IdHashMessageDigest, IdHash, ActiveX, ComObj, LbCipher, LbString;

type
  Togcvdispensarios_wayne = class(TService)
    ServerSocket1: TServerSocket;
    pSerial: TApdComPort;
    Timer1: TTimer;
    procedure ServiceExecute(Sender: TService);
    procedure ServerSocket1ClientRead(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure pSerialTriggerAvail(CP: TObject; Count: Word);
    procedure Timer1Timer(Sender: TObject);
    procedure ServiceDestroy(Sender: TObject);
    procedure ServiceShutdown(Sender: TService);
    procedure ServiceStop(Sender: TService; var Stopped: Boolean);
  private
    { Private declarations }
    LineaBuff,
    WayneFusion,
    MapeoFusion,
    AjusteWayne,
    AjusteWayne2,
    AjusteWayne3,
    WayneAjusteImporte,
    InicializaWayne,
    TierLavelWayne,
    ModoPrecioWayne,
    WayneValidaImporteDespacho:string;
    Con_Precio,
    Con_DigitoAjuste,
    DigitoAjusteVol,
    DigitoAjustePreset:Integer;
    SwComandoN,
    FinLinea:Boolean;
    LineaTimer,
    UltimaLineaTimer,
    SoportaSeleccionProducto,
    Linea:string;
    ContEspera,
    ContEsperaN,
    ContEsperaPaso2,
    ContEsperaPaso5,
    ContEsperaPaso6,
    StEsperaPaso3,
    ContEsperaPaso3,
    ContPaso3,NumPaso,
    PosProceso,
    PosicionDispenActual,
    PrecioCombActual,
    ContPrecioFisico,
    ContPrecioCambio,
    PrecioFisicoProc,
    PrecioCambioProc,
    PosicionCargaActual,
    PosicionCargaActual2,
    ContadorAlarma,
    ContadorTot,
    ContadorTotPos,
    DecimalesPresetWayne,
    DecimalesPresetWayneLitros,
    SnPosCarga              :integer;
    SwReinicio,SwBcc:Boolean;
    SnImporte,
    SnLitros                :real;    
    MapCombs:string;
    function CRC16(Data: string): string;
  public
    { Public declarations }
    ListaLog:TStringList;
    ListaLogPetRes:TStringList;
    ListaCmnd :TStrings;
    rutaLog:string;
    confPos:string;
    licencia:string;
    detenido:Boolean;
    estado:Integer;
    LinCmnd      :string;
    CharCmnd     :char;
    SwEsperaRsp  :boolean;
    ContEsperaRsp:integer;
    FolioCmnd   :integer;
    horaLog:TDateTime;
    horaInicio:TDateTime;
    horaDespacho:TDateTime;
    minutosLog:Integer;
    ListaComandos:TStringList;
    version:string;
    reinicioDiario:Boolean;
    function GetServiceController: TServiceController; override;
    procedure AgregaLogPetRes(lin: string);
    procedure Responder(socket:TCustomWinSocket;resp:string);
    function Inicializar(msj: string): string;
    function IniciaPSerial(datosPuerto:string): string;
    function AgregaPosCarga(posiciones: TlkJSONbase): string;
    function IniciaPrecios(msj: string): string;
    function Login(mensaje: string): string;
    function Logout: string;
    function MD5(const usuario: string): string;
    function ValidaCifra(xvalor:real;xenteros,xdecimales:byte):string;
    function FechaHoraExtToStr(FechaHora:TDateTime):String;
    procedure ComandoConsola(ss:string);
    function CalculaBCC(ss:string):char;
    procedure IniciarPrecios;
    procedure AgregaLog(lin:string);
    function XorChar(c1,c2:char):char;
    function EjecutaComando(xCmnd:string):integer;
    function AutorizarVenta(msj: string): string;
    function DetenerVenta(msj: string): string;
    function ReanudarVenta(msj: string): string;
    function ActivaModoPrepago(msj:string): string;
    function DesactivaModoPrepago(msj:string): string;
    function Bloquear(msj: string): string;
    function Desbloquear(msj: string): string;
    function FinVenta(msj: string): string;
    function TransaccionPosCarga(msj: string): string;
    function EstadoPosiciones(msj: string): string;
    function TotalesBomba(msj: string): string;
    function Detener: string;
    function Iniciar: string;
    function Shutdown: string;
    function Terminar: string;
    function ObtenerEstado: string;
    function GuardarLog:string;
    function GuardarLogPetRes:string;
    function RespuestaComando(msj: string): string;
    function ObtenerLog(r: Integer): string;
    function ObtenerLogPetRes(r: Integer): string;
    function ResultadoComando(xFolio:integer):string;
    procedure ProcesaLinea;
    procedure MapeaPosicion(xpos:integer);
    function CombustibleEnPosicion(xpos,xposcarga:integer):integer;
    function PosicionDeCombustible(xpos,xcomb:integer):integer;
    procedure EnviaPreset(xcomb:integer;var rsp:string);
    function MangueraEnPosicion(xpos,xposcarga:integer):integer;
    procedure GuardaLogComandos;
    function NoElemStrEnter(xstr:string):word;
    function ExtraeElemStrEnter(xstr:string;ind:word):string;
    procedure ComandoConsolaBuff(ss:string);
  end;

type
     tiposcarga = record
       estatus  :integer;
       descestat:string[20];
       importe,
       importeant,
       volumen,
       precio   :real;
       isla,
       PosDispActual:integer;
       estatusrsp,
       estatusant:integer;
       NoComb   :integer;
       TComb    :array[1..4] of integer;
       TCombx    :array[1..4] of integer;
       TPos     :array[1..4] of integer;
       TPrec    :array[1..4] of integer;
       TDiga    :array[1..4] of integer;
       TDigvol  :array[1..4] of integer;
       TDigpreset:array[1..4] of integer;
       TMang     :array[1..4] of integer;
       TotalLitros:array[1..4] of real;
       TotalLtsAnt:array[1..4] of real;
       SwCargaTotales:array[1..4] of boolean;
       RefrescaEnllavados,
       SwDesp,SwPrec,
       SwCargaLectura,
       SwMapea,
       Sw3virtual,
       SwCargando,
       swAvanzoVenta,
       SwActivo,
       SwParado,
       SwDesHabilitado,
       SwOCC,SwCmndB,
       SwPidiendoTotales,
       SwFINV             :boolean;
       Mensaje :string[12];
       ValorMapeo :string[10];
       ModoOpera:string[8];
       Mapa     :string[4];

       ContDetenido:integer;
       ContOcc,
       TipoPago,
       FinVenta:integer;

       Hora,
       HoraSw3  :TDateTime;

       swarosmag:boolean;
       aros_vehi:integer;
       swarosmag_stop:boolean;
       importe_aros:real;
       HoraOcc:TDateTime;
       CombActual:Integer;
       MangActual:Integer;

     end;

     RegCmnd = record
       SwActivo   :boolean;
       folio      :integer;
       hora       :TDateTime;
       Comando    :string[80];
       SwResp,
       SwNuevo    :boolean;
       Respuesta  :string[80];
     end;        

const idSTX = #2;
      idETX = #3;
      idACK = #6;
      idNAK = #21;
      MaxEspera2=20;
      MaxEspera31=10;
      MaxEspera3=20;      
      MaximoDePosiciones = 32;

type TMetodos = (NOTHING_e, INITIALIZE_e, PARAMETERS_e,
                 LOGIN_e, LOGOUT_e, PRICES_e, AUTHORIZE_e,
                 STOP_e, START_e, SELFSERVICE_e, FULLSERVICE_e,
                 BLOCK_e, UNBLOCK_e, PAYMENT_e, TRANSACTION_e,
                 STATUS_e, TOTALS_e, HALT_e, RUN_e, SHUTDOWN_e,
                 TERMINATE_e, STATE_e, TRACE_e, SAVELOGREQ_e,
                 RESPCMND_e, LOG_e, LOGREQ_e);



var
  ogcvdispensarios_wayne: Togcvdispensarios_wayne;
  SwComandoB    :boolean;
  TPrecio:array[1..9] of real;
  TPosCarga:array[1..32] of tiposcarga;
  LPrecios :array[1..4] of Double;
  MaxPosCarga:integer;
  ContDA    :integer;
  SwAplicaCmnd,
  PreciosInicio,
  SwCerrar    :boolean;
  ListaCmnd    :TStrings;
  Token        :string;
  TabCmnd  :array[1..200] of RegCmnd;
  LinEstadoGen  :string;

implementation

uses StrUtils, TypInfo, DateUtils, Math;

{$R *.DFM}

procedure ServiceController(CtrlCode: DWord); stdcall;
begin
  ogcvdispensarios_wayne.Controller(CtrlCode);
end;

function Togcvdispensarios_wayne.GetServiceController: TServiceController;
begin
  Result := ServiceController;
end;

procedure Togcvdispensarios_wayne.ServiceExecute(Sender: TService);
var
  config:TIniFile;
  lic:string;
begin
  try
    ListaLog:=TStringList.Create;
    ListaLogPetRes:=TStringList.Create;  
    config:= TIniFile.Create(ExtractFilePath(ParamStr(0)) +'PDISPENSARIOS.ini');
    rutaLog:=config.ReadString('CONF','RutaLog','C:\ImagenCo');
    ServerSocket1.Port:=config.ReadInteger('CONF','Puerto',8585);
    licencia:=config.ReadString('CONF','Licencia','');
    minutosLog:=StrToInt(config.ReadString('CONF','MinutosLog','0'));
    reinicioDiario:=UpperCase(config.ReadString('CONF','ReinicioDiario','No'))='SI';
    MapCombs:=config.ReadString('CONF','MapeoCombustibles','');
    ListaCmnd:=TStringList.Create;
    ServerSocket1.Active:=True;
    detenido:=True;
    SwComandoN:=false;
    SwReinicio:=False;
    estado:=-1;
    SwComandoB:=false;
    horaLog:=Now;
    horaInicio:=Now;

    while not Terminated do
      ServiceThread.ProcessRequests(True);
    ServerSocket1.Active := False;
  except
    on e:exception do begin
      ListaLogPetRes.Add('Error al iniciar servicio: '+e.Message);
      ListaLogPetRes.SaveToFile(rutaLog+'\LogDispPetRes'+FiltraStrNum(FechaHoraToStr(Now))+'.txt');
      GuardarLog;
      if ListaLogPetRes.Count>0 then
        GuardarLogPetRes;
    end;
  end;
end;

procedure Togcvdispensarios_wayne.ServerSocket1ClientRead(Sender: TObject;
  Socket: TCustomWinSocket);
  var
    mensaje,comando,checksum,parametro:string;
    i:Integer;
    chks_valido:Boolean;
    metodoEnum:TMetodos;
begin
  try
    mensaje:=Socket.ReceiveText;
    if mensaje='' then Exit;
    if (Length(mensaje)=1) and (StrToIntDef(mensaje,-99) in [0,1]) then begin
      pSerial.Open:=mensaje='1';
      Socket.SendText('1');
      Exit;
    end;
    AgregaLogPetRes('R '+mensaje);
    for i:=1 to Length(mensaje) do begin
      if mensaje[i]=#2 then begin
        mensaje:=Copy(mensaje,i+1,Length(mensaje)-i);
        Break;
      end;
    end;
    for i:=Length(mensaje) downto 1 do begin              
      if mensaje[i]=#3 then begin
        checksum:=Copy(mensaje,i+1,4);
        mensaje:=Copy(mensaje,1,i-1);
        Break;
      end;
    end;
    chks_valido:=checksum=CRC16(mensaje);
    if mensaje[1]='|' then
      Delete(mensaje,1,1);
    if mensaje[Length(mensaje)]='|' then
      Delete(mensaje,Length(mensaje),1);
    if NoElemStrSep(mensaje,'|')>=2 then begin
      if UpperCase(ExtraeElemStrSep(mensaje,1,'|'))<>'DISPENSERS' then begin
        Responder(Socket,'DISPENSERS|False|Este servicio solo procesa solicitudes de dispensarios|');
        Exit;
      end;

      comando:=UpperCase(ExtraeElemStrSep(mensaje,2,'|'));

      if not chks_valido then begin
        Responder(Socket,'DISPENSERS|'+comando+'|False|Checksum invalido|');
        Exit;
      end;

      if NoElemStrSep(mensaje,'|')>2 then begin
        for i:=3 to NoElemStrSep(mensaje,'|') do
          parametro:=parametro+ExtraeElemStrSep(mensaje,i,'|')+'|';

        if parametro[Length(parametro)]='|' then
          Delete(parametro,Length(parametro),1);
      end;

      metodoEnum := TMetodos(GetEnumValue(TypeInfo(TMetodos), comando+'_e'));

      case metodoEnum of
        NOTHING_e:
          Responder(Socket, 'DISPENSERS|NOTHING|True|');
        INITIALIZE_e:
          Responder(Socket, 'DISPENSERS|INITIALIZE|'+Inicializar(parametro));
        PARAMETERS_e:
          Responder(Socket, 'DISPENSERS|PARAMETERS|True|');
        LOGIN_e:
          Responder(Socket, 'DISPENSERS|LOGIN|'+Login(parametro));
        LOGOUT_e:
          Responder(Socket, 'DISPENSERS|LOGOUT|'+Logout);
        PRICES_e:
          Responder(Socket, 'DISPENSERS|PRICES|'+IniciaPrecios(parametro));
        AUTHORIZE_e:
          Responder(Socket, 'DISPENSERS|AUTHORIZE|'+AutorizarVenta(parametro));
        STOP_e:
          Responder(Socket, 'DISPENSERS|STOP|'+DetenerVenta(parametro));
        START_e:
          Responder(Socket, 'DISPENSERS|START|'+ReanudarVenta(parametro));
        SELFSERVICE_e:
          Responder(Socket, 'DISPENSERS|SELFSERVICE|'+ActivaModoPrepago(parametro));
        FULLSERVICE_e:
          Responder(Socket, 'DISPENSERS|FULLSERVICE|'+DesactivaModoPrepago(parametro));
        BLOCK_e:
          Responder(Socket, 'DISPENSERS|BLOCK|'+Bloquear(parametro));
        UNBLOCK_e:
          Responder(Socket, 'DISPENSERS|UNBLOCK|'+Desbloquear(parametro));
        PAYMENT_e:
          Responder(Socket, 'DISPENSERS|PAYMENT|'+FinVenta(parametro));
        TRANSACTION_e:
          Responder(Socket, 'DISPENSERS|TRANSACTION|'+TransaccionPosCarga(parametro));
        STATUS_e:
          Responder(Socket, 'DISPENSERS|STATUS|'+EstadoPosiciones(parametro));
        TOTALS_e:
          Responder(Socket, 'DISPENSERS|TOTALS|'+TotalesBomba(parametro));
        HALT_e:
          Responder(Socket, 'DISPENSERS|HALT|'+Detener);
        RUN_e:
          Responder(Socket, 'DISPENSERS|RUN|'+Iniciar);
        SHUTDOWN_e:
          Responder(Socket, 'DISPENSERS|SHUTDOWN|'+Shutdown);
        TERMINATE_e:
          Responder(Socket, 'DISPENSERS|TERMINATE|'+Terminar);
        STATE_e:
          Responder(Socket, 'DISPENSERS|STATE|'+ObtenerEstado);
        TRACE_e:
          Responder(Socket, 'DISPENSERS|TRACE|'+GuardarLog);
        SAVELOGREQ_e:
          Responder(Socket, 'DISPENSERS|SAVELOGREQ|'+GuardarLogPetRes);
        RESPCMND_e:
          Responder(Socket, 'DISPENSERS|RESPCMND|'+RespuestaComando(parametro));
        LOG_e:
          Socket.SendText('DISPENSERS|LOG|'+ObtenerLog(StrToIntDef(parametro, 0)));
        LOGREQ_e:
          Socket.SendText('DISPENSERS|LOGREQ|'+ObtenerLogPetRes(StrToIntDef(parametro, 0)));
      else
        Responder(Socket, 'DISPENSERS|'+comando+'|False|Comando desconocido|');
      end;
    end
    else
      Responder(Socket,'DISPENSERS|'+mensaje+'|False|Comando desconocido|');
  except
    on e:Exception do begin
      AgregaLogPetRes('Error: '+e.Message);
      GuardarLogPetRes;
      Responder(Socket,'DISPENSERS|'+comando+'|False|'+e.Message+'|');
    end;
  end;
end;

function Togcvdispensarios_wayne.CRC16(Data: AnsiString): AnsiString;
var
  aCrc:TCRC;
  pin : Pointer;
  insize:Cardinal;
begin
  insize:=Length(Data);
  pin:=@Data[1];
  aCrc:=TCRC.Create(CRC16Desc);
  aCrc.CalcBlock(pin,insize);
  Result:=UpperCase(IntToHex(aCrc.Finish,4));
  aCrc.Destroy;
end;

procedure Togcvdispensarios_wayne.AgregaLogPetRes(lin: string);
var lin2:string;
    i:integer;
begin
  lin2:=FechaHoraExtToStr(now)+' ';
  for i:=1 to length(lin) do
    case lin[i] of
      #1:lin2:=lin2+'<SOH>';
      #2:lin2:=lin2+'<STX>';
      #3:lin2:=lin2+'<ETX>';
      #6:lin2:=lin2+'<ACK>';
      #21:lin2:=lin2+'<NAK>';
      #23:lin2:=lin2+'<ETB>';
      else lin2:=lin2+lin[i];
    end;  
  while ListaLogPetRes.Count>10000 do
    ListaLogPetRes.Delete(0);
  ListaLogPetRes.Add(lin2);
end;

procedure Togcvdispensarios_wayne.Responder(socket: TCustomWinSocket;
  resp: string);
begin
  socket.SendText(#1#2+resp+#3+CRC16(resp)+#23);
  AgregaLogPetRes('E '+#1#2+resp+#3+CRC16(resp)+#23);
end;

function Togcvdispensarios_wayne.Inicializar(msj: string): string;
var
  js: TlkJSONBase;
  consolas,dispensarios,productos: TlkJSONbase;
  i,productID: Integer;
  datosPuerto,json,variables,variable:string;
begin
  try
    if estado>-1 then begin
      Result:='False|El servicio ya habia sido inicializado|';
      Exit;
    end;

    json:=ExtraeElemStrSep(msj,1,'|');
    variables:=ExtraeElemStrSep(msj,2,'|');

    WayneFusion:='No';
    MapeoFusion:='No';
    AjusteWayne:='No';
    AjusteWayne2:='No';
    AjusteWayne3:='No';
    WayneAjusteImporte:='No';
    WayneValidaImporteDespacho:='No';
    InicializaWayne:='Si';
    TierLavelWayne:='0';
    ModoPrecioWayne:='1';
    DecimalesPresetWayne:=-1;
    DecimalesPresetWayneLitros:=3;
    Con_DigitoAjuste:=0;
    SoportaSeleccionProducto:='Si';
    for i:=1 to NoElemStrEnter(variables) do begin
      variable:=ExtraeElemStrEnter(variables,i);
      if UpperCase(ExtraeElemStrSep(variable,1,'='))='WAYNEFUSION' then
        WayneFusion:=ExtraeElemStrSep(variable,2,'=')
      else if UpperCase(ExtraeElemStrSep(variable,1,'='))='MAPEOFUSION' then
        MapeoFusion:=ExtraeElemStrSep(variable,2,'=')
      else if UpperCase(ExtraeElemStrSep(variable,1,'='))='AJUSTEWAYNE' then
        AjusteWayne:=ExtraeElemStrSep(variable,2,'=')
      else if UpperCase(ExtraeElemStrSep(variable,1,'='))='AJUSTEWAYNE2' then
        AjusteWayne2:=ExtraeElemStrSep(variable,2,'=')
      else if UpperCase(ExtraeElemStrSep(variable,1,'='))='AJUSTEWAYNE3' then
        AjusteWayne3:=ExtraeElemStrSep(variable,2,'=')
      else if UpperCase(ExtraeElemStrSep(variable,1,'='))='WAYNEAJUSTEIMPORTE' then
        WayneAjusteImporte:=ExtraeElemStrSep(variable,2,'=')
      else if UpperCase(ExtraeElemStrSep(variable,1,'='))='WAYNEVALIDAIMPORTEDESPACHO' then
        WayneValidaImporteDespacho:=ExtraeElemStrSep(variable,2,'=')
      else if UpperCase(ExtraeElemStrSep(variable,1,'='))='INICIALIZAWAYNE' then
        InicializaWayne:=ExtraeElemStrSep(variable,2,'=')
      else if UpperCase(ExtraeElemStrSep(variable,1,'='))='TIERLAVELWAYNE' then
        TierLavelWayne:=ExtraeElemStrSep(variable,2,'=')
      else if UpperCase(ExtraeElemStrSep(variable,1,'='))='MODOPRECIOWAYNE' then
        ModoPrecioWayne:=ExtraeElemStrSep(variable,2,'=')
      else if UpperCase(ExtraeElemStrSep(variable,1,'='))='DECIMALESPRESETWAYNE' then
        DecimalesPresetWayne:=StrToInt(ExtraeElemStrSep(variable,2,'='))
      else if UpperCase(ExtraeElemStrSep(variable,1,'='))='DECIMALESPRESETWAYNELITROS' then
        DecimalesPresetWayneLitros:=StrToInt(ExtraeElemStrSep(variable,2,'='))
      else if UpperCase(ExtraeElemStrSep(variable,1,'='))='CONDIGITOAJUSTE' then
        Con_DigitoAjuste:=StrToInt(ExtraeElemStrSep(variable,2,'='))
      else if UpperCase(ExtraeElemStrSep(variable,1,'='))='SOPORTASELECCIONPRODUCTO' then
        SoportaSeleccionProducto:=ExtraeElemStrSep(variable,2,'=');
    end;

    js := TlkJSON.ParseText(json);
    consolas := js.Field['Consoles'];

    datosPuerto:=VarToStr(consolas.Child[0].Field['Connection'].Value);

    Result:=IniciaPSerial(datosPuerto);

    if Result<>'' then
      Exit;

    dispensarios := js.Field['Dispensers'];

    Result:=AgregaPosCarga(dispensarios);

    if Result<>'' then
      Exit;

    productos := js.Field['Products'];

    PreciosInicio:=False;
    estado:=0;
    Result:='True|';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_wayne.IniciaPSerial(
  datosPuerto: string): string;
var
  puerto:string;
begin
  try
    if pSerial.Open then begin
      Result:='False|El puerto ya se encontraba abierto|';
      Exit;
    end;

    puerto:=ExtraeElemStrSep(datosPuerto,2,',');
    if Length(puerto)>=4 then begin
      if StrToIntDef(Copy(puerto,4,Length(puerto)-3),-99)=-99 then begin
        Result:='False|Favor de indicar un numero de puerto correcto|';
        Exit;
      end
      else
        pSerial.ComNumber:=StrToInt(Copy(puerto,4,Length(puerto)-3));
    end
    else begin
      if StrToIntDef(ExtraeElemStrSep(datosPuerto,2,','),-99)=-99 then begin
        Result:='False|Favor de indicar un numero de puerto correcto|';
        Exit;
      end
      else
        pSerial.ComNumber:=StrToInt(ExtraeElemStrSep(datosPuerto,2,','));
    end;

    if StrToIntDef(ExtraeElemStrSep(datosPuerto,3,','),-99)=-99 then begin
      Result:='False|Favor de indicar los baudios correctos|';
      Exit;
    end
    else
      pSerial.Baud:=StrToInt(ExtraeElemStrSep(datosPuerto,3,','));

    if ExtraeElemStrSep(datosPuerto,4,',')<>'' then begin
      case ExtraeElemStrSep(datosPuerto,4,',')[1] of
        'N':pSerial.Parity:=pNone;
        'E':pSerial.Parity:=pEven;
        'O':pSerial.Parity:=pOdd;
        else begin
          Result:='False|Favor de indicar una paridad correcta [N,E,O]|';
          Exit;
        end;
      end;
    end
    else begin
      Result:='False|Favor de indicar una paridad [N,E,O]|';
      Exit;
    end;

    if StrToIntDef(ExtraeElemStrSep(datosPuerto,5,','),-99)=-99 then begin
      Result:='False|Favor de indicar los bits de datos correctos|';
      Exit;
    end
    else
      pSerial.DataBits:=StrToInt(ExtraeElemStrSep(datosPuerto,5,','));

    if StrToIntDef(ExtraeElemStrSep(datosPuerto,6,','),-99)=-99 then begin
      Result:='False|Favor de indicar los bits de paro correctos|';
      Exit;
    end
    else
      pSerial.StopBits:=StrToInt(ExtraeElemStrSep(datosPuerto,6,','));
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_wayne.AgregaPosCarga(
  posiciones: TlkJSONbase): string;
var
  i,j,k,xpos,xcomb,conPosicion:integer;
  dataPos:string;
  existe:boolean;
  mangueras:TlkJSONbase;
begin
  try
    if not detenido then begin
      Result:='False|Es necesario detener el proceso antes de inicializar las posiciones de carga|';
      Exit;
    end;

    MaxPosCarga:=0;
    for i:=1 to 32 do with TPosCarga[i] do begin
      tag:=1;
      estatus:=-1;
      estatusant:=-1;
      NoComb:=0;
      for j:=1 to 4 do begin
        TotalLitros[j]:=0;
        TotalLtsAnt[j]:=0;
        TDiga[j]:=0;
        TDigPreset[j]:=-1;
      end;
      Importeant:=0;
      Mensaje:='';
      SwCargando:=false;
      Sw3virtual:=false;
      SwCargaLectura:=true;
      SwMapea:=false;
      SwActivo:=false;
      SwParado:=false;
      SwDeshabilitado:=false;
      SwFINV:=false;
      SwOCC:=false;
      ContDetenido:=0;
      ContOcc:=0;
      tipopago:=0;
      finventa:=0;
      SwArosMag:=false;
      SwArosMag_stop:=false;
    end;

    for i:=0 to posiciones.Count-1 do begin
      xpos:=posiciones.Child[i].Field['DispenserId'].Value;
      if (xpos>0)and(xpos>MaxPosCarga) then
        MaxPosCarga:=xpos;
      with TPosCarga[xpos] do begin
        SwDesp:=false;
        SwPrec:=false;
        ModoOpera:='Prepago';
        //Mapa:=Q_BombIbImpreTarjetas.AsString;
        if InicializaWayne='Si' then
          RefrescaEnllavados:=true
        else
          RefrescaEnllavados:=false;
        existe:=false;

        mangueras:=posiciones.Child[i].Field['Hoses'];
        for j:=0 to mangueras.Count-1 do begin
          if MapCombs<>'' then
            xcomb:=StrToInt(ExtraeElemStrSep(ExtraeElemStrSep(MapCombs,xpos,';'),mangueras.Child[j].Field['HoseId'].Value,','))
          else
            xcomb:=mangueras.Child[j].Field['ProductId'].Value;
          conPosicion:=mangueras.Child[j].Field['HoseId'].Value;

          for k:=1 to NoComb do
            if TComb[k]=xcomb then
              existe:=true;
          if not existe then begin
            inc(NoComb);
            TComb[NoComb]:=mangueras.Child[j].Field['ProductId'].Value;;
            TCombx[NoComb]:=xcomb;
            if conPosicion>0 then
              TPos[NoComb]:=conPosicion
            else if NoComb<=4 then
              TPos[NoComb]:=NoComb
            else
              TPos[NoComb]:=1;
            TMang[NoComb]:=conPosicion;
            TPrec[TPos[NoComb]]:=Con_Precio;
            TDiga[1]:=Con_DigitoAjuste;
            TDigvol[TPos[NoComb]]:=DigitoAjusteVol;
            TDigPreset[TPos[NoComb]]:=DigitoAjustePreset;
            SwCargaTotales[NoComb]:=true;
          end;
        end;
      end;
    end;
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_wayne.Login(mensaje: string): string;
var
  usuario,password:string;
begin
  usuario:=ExtraeElemStrSep(mensaje,1,'|');
  password:=ExtraeElemStrSep(mensaje,2,'|');
  if MD5(usuario+'|'+FormatDateTime('yyyy-mm-dd',Date)+'T'+FormatDateTime('hh:nn',Now))<>password then
    Result:='False|Password invalido|'
  else begin
    Token:=MD5(usuario+'|'+FormatDateTime('yyyy-mm-dd',Date)+'T'+FormatDateTime('hh:nn',Now));
    Result:='True|'+Token+'|';
  end;
end;

function Togcvdispensarios_wayne.Logout: string;
begin
  Token:='';
  Result:='True|';
end;

function Togcvdispensarios_wayne.MD5(const usuario: string): string;
var
  idmd5:TIdHashMessageDigest5;
  hash:T4x4LongWordRecord;
begin
  idmd5 := TIdHashMessageDigest5.Create;
  hash := idmd5.HashValue(usuario);
  Result := idmd5.AsHex(hash);
  Result := AnsiLowerCase(Result);
  idmd5.Destroy;
end;

function Togcvdispensarios_wayne.IniciaPrecios(msj: string): string;
var
  ss:string;
  precioComb:Double;
  xpos,i:Integer;
  entro:Boolean;
begin
  try
    for i:=1 to NoElemStrSep(msj,'|') do begin
      precioComb:=StrToFloatDef(ExtraeElemStrSep(msj,i,'|'),-1);
      if precioComb<=0 then
        Continue;
      LPrecios[i]:=precioComb;
      if ValidaCifra(precioComb,2,2)='OK' then begin
        if precioComb>=0.01 then begin
          if WayneFusion='No' then begin
            ComandoConsola('a'+IntToStr(i)+TierLavelWayne+'1'+'0'+IntToClaveNum(Trunc(precioComb*100+0.5),4)); // contado
            EsperaMiliSeg(250);
            ComandoConsola('a'+IntToStr(i)+TierLavelWayne+'0'+'0'+IntToClaveNum(Trunc(precioComb*100+0.5),4)); // credito
            EsperaMiliSeg(250);
          end
          else begin
            ComandoConsola('a'+IntToStr(i)+TierLavelWayne+'1'+'0'+IntToClaveNum(Trunc(precioComb*100+0.5),4)+'0'); // contado
            esperamiliseg(250);
            ComandoConsola('a'+IntToStr(i)+TierLavelWayne+'0'+'0'+IntToClaveNum(Trunc(precioComb*100+0.5),4)+'0');  // credito
            esperamiliseg(250);
          end;
          entro:=True;
        end;
      end;
    end;
    if entro then
      Result:='True|'
    else
      Result:='False|No se encontraron precios validos|';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_wayne.ValidaCifra(xvalor: real; xenteros,
  xdecimales: byte): string;
var xmax,xaux:real;
    i:integer;
begin
  try
    if xvalor<-0.0001 then begin
      result:='Valor negativo no permitido';
      exit;
    end;
    xmax:=1;
    for i:=1 to xenteros do
      xmax:=xmax*10;
    if xvalor>(xmax-0.0000000001) then begin
      result:='Valor excede maximo permitido';
      exit;
    end;
    xaux:=AjustaFloat(xvalor,xdecimales);
    if abs(xaux-xvalor)>0.000000001 then begin
      if xdecimales=0 then
        result:='Solo se permiten valores enteros'
      else
        result:='Numero de decimales excede maximo permitido';
      exit;
    end;
    result:='OK';
  except
    on e:Exception do begin
      AgregaLog('Error ValidaCifra: '+e.Message);
      GuardarLog;
    end;
  end;
end;

function Togcvdispensarios_wayne.FechaHoraExtToStr(
  FechaHora: TDateTime): String;
begin
  result:=FechaPaq(FechaHora)+' '+FormatDatetime('hh:mm:ss.zzz',FechaHora);
end;

procedure Togcvdispensarios_wayne.ComandoConsola(ss: string);
var s1:string;
    cc:char;
begin
  try
    LinCmnd:=ss;
    CharCmnd:=LinCmnd[1];
    SwEsperaRsp:=true;
    ContEsperaRsp:=0;
    inc(ContadorAlarma);
    if ContadorAlarma>10 then
      LinEstadoGen:=CadenaStr(length(LinEstadoGen),'0');
    Timer1.Enabled:=false;
    try
      LineaBuff:='';
      cc:=CalculaBCC(ss+#3);
      s1:=#2+ss+#3+CC;
      if pSerial.OutBuffFree >= Length(S1) then begin
        AgregaLog('E '+s1);
        if pSerial.Open then
          pSerial.PutString(S1);
      end;
    finally
      Timer1.Enabled:=true;
    end;
  except
    on e:Exception do begin
      AgregaLog('Error ComandoConsola: '+e.Message);
      GuardarLog;
    end;
  end;
end;

function Togcvdispensarios_wayne.CalculaBCC(ss: string): char;
var xc,cc:char;
    i:integer;
begin
  try
    xc:=ss[1];
    for i:=2 to length(ss) do begin
      cc:=ss[i];
      xc:=XorChar(xc,cc);
    end;
    result:=xc;
  except
    on e:Exception do begin
      AgregaLog('Error CalculaBCC: '+e.Message);
      GuardarLog;
    end;
  end;
end;

procedure Togcvdispensarios_wayne.AgregaLog(lin: string);
var lin2:string;
    i:integer;
begin
  try
    lin2:=FechaHoraExtToStr(now)+' ';
    for i:=1 to length(lin) do
      case lin[i] of
        #1:lin2:=lin2+'<SOH>';
        #2:lin2:=lin2+'<STX>';
        #3:lin2:=lin2+'<ETX>';
        #6:lin2:=lin2+'<ACK>';
        #21:lin2:=lin2+'<NAK>';
        #23:lin2:=lin2+'<ETB>';
        else lin2:=lin2+lin[i];
      end;
    while ListaLog.Count>10000 do
      ListaLog.Delete(0);
    ListaLog.Add(lin2);
  except
  end;
end;

function Togcvdispensarios_wayne.XorChar(c1, c2: char): char;
var bits1,bits2,bits3:array[0..7] of boolean;
    nn,n1,n2,i,nr:byte;
begin
  try
    n1:=ord(c1);
    n2:=ord(c2);
    nr:=0;
    for i:=0 to 7 do begin
      nn:=n1 mod 2;
      bits1[i]:=(nn=1);
      n1:=n1 div 2;

      nn:=n2 mod 2;
      bits2[i]:=(nn=1);
      n2:=n2 div 2;

      bits3[i]:=bits1[i] xor bits2[i];
      if bits3[i] then
        case i of
          0:nr:=nr+1;
          1:nr:=nr+2;
          2:nr:=nr+4;
          3:nr:=nr+8;
          4:nr:=nr+16;
          5:nr:=nr+32;
          6:nr:=nr+64;
          7:nr:=nr+128;
        end;
    end;
    result:=char(nr);
  except
    on e:Exception do begin
      AgregaLog('Error XorChar: '+e.Message);
      GuardarLog;
    end;
  end;
end;

function Togcvdispensarios_wayne.EjecutaComando(xCmnd: string): integer;
var ind:integer;
begin
  try
    // busca un registro disponible
    ind:=0;
    repeat
      inc(ind);
      if (TabCmnd[ind].SwActivo)and((now-TabCmnd[ind].hora)>tmMinuto) then begin
        TabCmnd[ind].SwActivo:=false;
        TabCmnd[ind].SwResp:=false;
        TabCmnd[ind].SwNuevo:=true;
      end;
    until (not TabCmnd[ind].SwActivo)or(ind>200);
    // Si no lo encuentra se sale
    if ind>200 then begin
      result:=0;
      exit;
    end;
    // envia el comando
    with TabCmnd[ind] do begin
      inc(FolioCmnd);
      if FolioCmnd<=0 then
        FolioCmnd:=1;
      Folio:=FolioCmnd;
      hora:=Now;
      SwActivo:=true;
      Comando:=xCmnd;
      SwResp:=false;
      Respuesta:='';
      TabCmnd[ind].SwNuevo:=true;
    end;
    Result:=FolioCmnd;
  except
    on e:Exception do begin
      AgregaLog('Error EjecutaComando: '+e.Message);
      GuardarLog;
    end;
  end;
end;

function Togcvdispensarios_wayne.AutorizarVenta(msj: string): string;
var
  cmd,cantidad,posCarga,comb,finv:string;
begin
  try

    if StrToFloatDef(ExtraeElemStrSep(msj,4,'|'),0)>0 then begin
      cmd:='OCL';
      cantidad:=ExtraeElemStrSep(msj,4,'|');
    end
    else if StrToFloatDef(ExtraeElemStrSep(msj,3,'|'),-99)<>-99 then begin
      cmd:='OCC';
      cantidad:=ExtraeElemStrSep(msj,3,'|');
    end
    else begin
      Result:='False|Favor de indicar la cantidad que se va a despachar|';
      Exit;
    end;

    posCarga:=ExtraeElemStrSep(msj,1,'|');

    if posCarga='' then begin
      Result:='False|Favor de indicar la posicion de carga|';
      Exit;
    end;

    comb:=ExtraeElemStrSep(msj,2,'|');

    if comb='' then
      comb:='00';

    finv:=ExtraeElemStrSep(msj,5,'|');

    if finv='0' then
      finv:='1'
    else
      finv:='0';

    Result:='True|'+IntToStr(EjecutaComando(cmd+' '+posCarga+' '+cantidad+' '+comb+' '+finv))+'|';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_wayne.DetenerVenta(msj: string): string;
begin
  try
    if StrToIntDef(msj,-1)=-1 then begin
      Result:='False|Favor de indicar correctamente la posicion de carga|';
      Exit;
    end;

    Result:='True|'+IntToStr(EjecutaComando('DVC '+msj))+'|';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_wayne.ReanudarVenta(msj: string): string;
begin
  try
    if StrToIntDef(msj,-1)=-1 then begin
      Result:='False|Favor de indicar correctamente la posicion de carga|';
      Exit;
    end;

    Result:='True|'+IntToStr(EjecutaComando('REANUDAR '+msj))+'|';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_wayne.ActivaModoPrepago(msj: string): string;
var
  xpos:Integer;
begin
  try
    xpos:=StrToIntDef(msj,-1);
    if xpos=-1 then begin
      Result:='False|Favor de indicar correctamente la posicion de carga|';
      Exit;
    end;

    if xpos=0 then begin
      for xpos:=1 to MaxPosCarga do
        TPosCarga[xpos].ModoOpera:='Prepago';
    end
    else if (xpos in [1..maxposcarga]) then
      TPosCarga[xpos].ModoOpera:='Prepago';

    Result:='True|';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_wayne.DesactivaModoPrepago(msj: string): string;
var
  xpos:Integer;
begin
  try
    xpos:=StrToIntDef(msj,-1);
    if xpos=-1 then begin
      Result:='False|Favor de indicar correctamente la posicion de carga|';
      Exit;
    end;

    if xpos=0 then begin
      for xpos:=1 to MaxPosCarga do
        TPosCarga[xpos].ModoOpera:='Prepago';
    end
    else if (xpos in [1..maxposcarga]) then
      TPosCarga[xpos].ModoOpera:='Prepago';

    Result:='True|';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_wayne.Bloquear(msj: string): string;
var
  xpos:Integer;
begin
  try
    xpos:=StrToIntDef(msj,-1);

    if xpos<0 then begin
      Result:='False|Favor de indicar correctamente la posicion de carga|';
      Exit;
    end;

    if (xpos<=MaximoDePosiciones) then begin
      if xpos=0 then begin
        for xpos:=1 to MaxPosCarga do
          TPosCarga[xpos].SwDesHabilitado:=True;
        Result:='True|';
      end
      else if (xpos in [1..maxposcarga]) then begin
        TPosCarga[xpos].SwDesHabilitado:=True;
        Result:='True|';
      end;
    end
    else Result:='False|Posicion no Existe|';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_wayne.Desbloquear(msj: string): string;
var
  xpos:Integer;
begin
  try
    xpos:=StrToIntDef(msj,-1);

    if xpos<0 then begin
      Result:='False|Favor de indicar correctamente la posicion de carga|';
      Exit;
    end;

    if (xpos<=MaximoDePosiciones) then begin
      if xpos=0 then begin
        for xpos:=1 to MaxPosCarga do
          TPosCarga[xpos].SwDesHabilitado:=False;
        Result:='True|';
      end
      else if (xpos in [1..maxposcarga]) then begin
        TPosCarga[xpos].SwDesHabilitado:=False;
        Result:='True|';
      end;
    end
    else Result:='False|Posicion no Existe|';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_wayne.FinVenta(msj: string): string;
begin
  try
    if StrToIntDef(msj,-1)=-1 then begin
      Result:='False|Favor de indicar correctamente la posicion de carga|';
      Exit;
    end;

    Result:='True|'+IntToStr(EjecutaComando('FINV '+msj))+'|';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_wayne.TransaccionPosCarga(msj: string): string;
var
  xpos:Integer;
begin
  try
    xpos:=StrToIntDef(msj,-1);
    if xpos<0 then begin
      Result:='False|Favor de indicar correctamente la posicion de carga|';
      Exit;
    end;

    if xpos>MaxPosCarga then begin
      Result:='False|La posicion de carga no se encuentra registrada|';
      Exit;
    end;

    with TPosCarga[xpos] do
      Result:='True|'+FormatDateTime('yyyy-mm-dd',HoraOcc)+'T'+FormatDateTime('hh:nn',HoraOcc)+'|'+IntToStr(MangActual)+'|'+IntToStr(CombActual)+'|'+
              FormatFloat('0.000',volumen)+'|'+FormatFloat('0.00',precio)+'|'+FormatFloat('0.00',importe)+'|';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_wayne.EstadoPosiciones(msj: string): string;
var
  xpos:Integer;
begin
  try
    xpos:=StrToIntDef(msj,-1);
    if xpos<0 then begin
      Result:='False|Favor de indicar correctamente la posicion de carga|';
      Exit;
    end;

    if LinEstadoGen='' then begin
      Result:='False|Error de comunicacion|';
      Exit;
    end;    

    if xpos>0 then
      Result:='True|'+LinEstadoGen[xpos]+'|'
    else
      Result:='True|'+LinEstadoGen+'|';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_wayne.TotalesBomba(msj: string): string;
var
  xpos,xfolioCmnd:Integer;
  valor:string;
begin
  try
    xpos:=StrToIntDef(msj,-1);
    if xpos<1 then begin
      Result:='False|Favor de indicar correctamente la posicion de carga|';
      Exit;
    end;

    xfolioCmnd:=EjecutaComando('TOTAL'+' '+IntToStr(xpos));

    valor:=IfThen(xfolioCmnd>0, 'True', 'False');

    Result:=valor+'|0|0|0|0|0|0|'+IntToStr(xfolioCmnd)+'|';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_wayne.Detener: string;
begin
  try
    if estado=-1 then begin
      Result:='False|El proceso no se ha iniciado aun|';
      Exit;
    end;

    if not detenido then begin
      pSerial.Open:=False;
      Timer1.Enabled:=False;
      detenido:=True;
      estado:=0;
      Result:='True|';
    end
    else
      Result:='False|El proceso ya habia sido detenido|'
  except
    on e:Exception do
      Result:='False|'+e.Message+'|';
  end;
end;

function Togcvdispensarios_wayne.Iniciar: string;
begin
  try
    if (not pSerial.Open) then begin
      if (estado=-1) then begin
        Result:='False|No se han recibido los parametros de inicializacion|';
        Exit;
      end
      else if detenido then
        pSerial.Open:=True;
    end;

    Sleep(100);
    if (WayneFusion='No')or(MapeoFusion='Si') then begin
      ComandoConsola('N'+inttoclavenum(MaxPosCarga,2)+ModoPrecioWayne);
      esperamiliseg(100);
      ComandoConsola('l1');
      esperamiliseg(100);
    end;

    detenido:=False;
    estado:=1;
    Timer1.Enabled:=True;
    numPaso:=0;
    Result:='True|';
  except
    on e:Exception do
      Result:='False|'+e.Message+'|';
  end;
end;

function Togcvdispensarios_wayne.Shutdown: string;
begin
  if estado>0 then
    Result:='False|El servicio esta en proceso, no fue posible detenerlo|'
  else begin
    ServiceThread.Terminate;
    Result:='True|';
  end;
end;

function Togcvdispensarios_wayne.Terminar: string;
begin
  if estado>0 then
    Result:='False|El servicio no esta detenido, no es posible terminar la comunicacion|'
  else begin
    Timer1.Enabled:=False;
    pSerial.Open:=False;
    LPrecios[1]:=0;
    LPrecios[2]:=0;
    LPrecios[3]:=0;
    LPrecios[4]:=0;
    estado:=-1;
    Result:='True|';
  end;
end;

function Togcvdispensarios_wayne.ObtenerEstado: string;
begin
  Result:='True|'+IntToStr(estado)+'|';
end;

function Togcvdispensarios_wayne.GuardarLog: string;
begin
  try
    horaLog:=Now;
    ListaLog.SaveToFile(rutaLog+'\LogDisp'+FiltraStrNum(FechaHoraToStr(Now))+'.txt');
    GuardarLogPetRes;
    Result:='True|'+rutaLog+'\LogDisp'+FiltraStrNum(FechaHoraToStr(Now))+'.txt|';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_wayne.GuardarLogPetRes: string;
begin
  try
    ListaLogPetRes.SaveToFile(rutaLog+'\LogDispPetRes'+FiltraStrNum(FechaHoraToStr(Now))+'.txt');
    Result:='True|';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_wayne.RespuestaComando(msj: string): string;
var
  resp:string;
begin
  try
    if StrToIntDef(msj,-1)=-1 then begin
      Result:='False|Favor de indicar correctamente el numero de folio de comando|';
      Exit;
    end;

    resp:=ResultadoComando(StrToInt(msj));

    if (UpperCase(Copy(resp,1,2))='OK') then begin
      if Length(resp)>2 then
        resp:=copy(resp,3,Length(resp)-2)
      else
        resp:='';
      Result:='True|'+resp;
    end
    else
      Result:='False|'+resp+'|';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_wayne.ObtenerLog(r: Integer): string;
var
  i:Integer;
begin
  try
    if r=0 then begin
      Result:='False|No se indico el numero de registros|';
      Exit;
    end;

    if ListaLog.Count<1 then begin
      Result:='False|No hay registros en el log|';
      Exit;
    end;

    i:=ListaLog.Count-(r+1);
    if i<1 then i:=0;

    Result:='True|';

    for i:=i to ListaLog.Count-1 do
      Result:=Result+ListaLog[i]+'|';
  except
    on e:Exception do
      Result:='False|'+e.Message;
  end;
end;

function Togcvdispensarios_wayne.ObtenerLogPetRes(r: Integer): string;
var
  i:Integer;
begin
  try
    if r=0 then begin
      Result:='False|No se indico el numero de registros|';
      Exit;
    end;

    if ListaLogPetRes.Count<1 then begin
      Result:='False|No hay registros en el log de peticiones|';
      Exit;
    end;

    i:=ListaLogPetRes.Count-(r+1);
    if i<1 then i:=0;

    Result:='True|';

    for i:=i to ListaLogPetRes.Count-1 do
      Result:=Result+ListaLogPetRes[i]+'|';
  except
    on e:Exception do
      AgregaLog('Excepcion ResultadoComando: '+e.Message);
  end;
end;

function Togcvdispensarios_wayne.ResultadoComando(xFolio: integer): string;
var i:integer;
begin
  try
    Result:='*';
    for i:=1 to 200 do
      if (TabCmnd[i].folio=xfolio)and(TabCmnd[i].SwResp) then begin
        result:=TabCmnd[i].Respuesta;
        Break;
      end;
  except
    on e:Exception do
      Result:='False|'+e.Message;
  end;
end;

procedure Togcvdispensarios_wayne.ProcesaLinea;
var lin,ss,rsp,descrsp,saux,
    xestado,xmodo,rsp2          :string;
    simp,spre,sval              :string[20];
    contstop,contact,
    XMANG,XCTE,XVEHI,
    ndig,i,xpos,xcomb,
    xpos2,npos,xpr,xpda         :integer;
    xLista                      :TStrings;
    SwOk                        :boolean;
    ximporte,xvolumen,
    xprecio,xprec,
    xvalor,ximpo,xvol           :real;
    centavos:Integer;
begin
  try
    if (minutosLog>0) and (MinutesBetween(Now,horaLog)>=minutosLog) then begin
      horaLog:=Now;
      GuardarLog;
    end;    
    saux:=LineaTimer;
    if LineaTimer='' then
      exit;
    SwEsperaRsp:=false;
    if length(LineaTimer)>3 then begin
      lin:=copy(lineaTimer,2,length(lineatimer)-3);
    end
    else
      lin:=LineaTimer;
    LineaTimer:='';
    if lin='' then
      exit;
    if SwComandoN then begin
      if ContEsperaN>0 then
        dec(ContEsperaN)
      else begin
        SwComandoN:=false;
        if (WayneFusion='No')or(MapeoFusion='Si') then begin
          ComandoConsolaBuff('N'+inttoclavenum(MaxPosCarga,2)+ModoPrecioWayne);
        end;
      end;
    end;
    case lin[1] of
     'l':begin
           if lin[2]='1' then
             Timer1.Enabled:=true
           else raise Exception.Create('Error en comunicacion con CONSOLA');
         end;
     'B':begin
           SwComandoB:=true;
           NumPaso:=1; // then begin // pide estatus de todas las bombas
           UltimaLineaTimer:=saux;
           ContEspera:=0;
           ss:=copy(lin,4,length(lin)-3);
           contstop:=0;
           contact:=0;
           if PreciosInicio then
             IniciarPrecios;
           lin:='';xestado:='';xmodo:='';
           for xpos:=1 to length(ss) do if xpos in [1..maxposcarga] then begin
             with TPosCarga[xpos] do begin
               SwCmndB:=true;
               if estatusant<>estatus then begin
                 SwDesp:=false;
                 mensaje:=mensaje+inttostr(estatus);
                 while length(mensaje)>10 do
                   delete(mensaje,1,1);
               end;
               estatusant:=estatus;
               estatus:=StrToIntDef(ss[xpos],0);
               estatusrsp:=estatus;
               if estatus=2 then begin
                 if not swcargando then
                   importeant:=0;
                 swcargando:=true;
                 SwPidiendoTotales:=False;
               end;
               if (estatus=0)and(SwActivo) then begin
                 if (estatusant in [1..10]) then
                   ContDA:=0
                 else
                   inc(ContDA);
                 if ContDA=5 then begin
                   SwActivo:=false;
                 end;
               end
               else if (estatus in [1..10])and(not SwActivo) then begin
                 SwActivo:=true;
               end;
               if TPosCarga[xpos].ModoOpera<>'Normal' then begin
                 if (estatus=1)and(estatusant=2) then begin
                   sw3virtual:=true;
                   horasw3:=now;
                   estatus:=3;
                 end;
                 if (estatus=1)and(sw3virtual) then begin
                   estatus:=3;
                 end;
               end;
               if not (estatus in [2,8]) then
                 swarosmag_stop:=false;
               if SwFINV then begin
                 if estatus=3 then begin
                   ComandoConsolaBuff('R'+IntToClaveNum(xpos,2)+'0');
                 end
                 else SwFinv:=false;
               end;
               case estatus of
                 0:begin
                     if estatusant<>0 then begin
                       for xcomb:=1 to nocomb do
                         AgregaLog('Desconexion de Manguera Pos Carga '+inttostr(xpos)+' / Combustible '+IntToStr(xcomb));
                     end;
                   end;
                 1:begin
                     SwParado:=false;
                     if swprec then
                       swprec:=false;
                     if estatusant<>1 then begin
                       tag:=1;
                       SwArosMag:=false;
                       FinVenta:=0;
                       TipoPago:=0;
                       SwOcc:=false;
                       ContOcc:=0;
                     end;
                     if estatusant=0 then begin
                       for xcomb:=1 to nocomb do
                         AgregaLog('Reconexion de Manguera Pos Carga '+inttostr(xpos)+' / Combustible '+IntToStr(xcomb));
                     end;
                   end;
                 2:SwPidiendoTotales:=False;
                 8:begin
                     if estatusant<>8 then
                       ContDetenido:=0;
                     if (not SwParado) then begin
                       inc(ContDetenido);
                       if ContDetenido<6 then begin
                         if i<3 then
                           ComandoConsolaBuff('G'+inttoclavenum(xpos,2))
                         else
                           ComandoConsolaBuff('R'+inttoclavenum(xpos,2));
                       end;
                     end;
                   end;
                 9:begin
                     swcargando:=false;
                     importeant:=0;
                     if estatusant=2 then begin
                       ss:='E'+IntToClaveNum(xpos,2); // STOP
                       ComandoConsolaBuff(ss);
                     end;
                   end;
               end;
               if estatus in [1,2,3,5,9] then
                 inc(contact)
               else if estatus=8 then
                 inc(contstop);

               if not SwDesHabilitado then begin
                 case estatus of
                   0:xestado:=xestado+'0'; // Sin Comunicacion
                   1:xestado:=xestado+'1'; // Inactivo (Idle)
                   2:xestado:=xestado+'2'; // Cargando (In Use)
                   3:if not swcargando then
                       xestado:=xestado+'3' // Fin de Carga (Used)
                     else
                       xestado:=xestado+'2';
                   5:xestado:=xestado+'5'; // Llamando (Calling)
                   9:xestado:=xestado+'9'; // Autorizado (Calling)
                   8:xestado:=xestado+'8'; // Detenido (Stoped)
                   else xestado:=xestado+'0';
                 end;
               end
               else xestado:=xestado+'7'; // Deshabilitado
               if estatus=2 then
                 horaDespacho:=Now;
             end;
           end;
           LinEstadoGen:=xestado;
           if (contstop>0)and(contact=0) then begin
             if (WayneFusion='No')or(MapeoFusion='Si') then begin
               ComandoConsolaBuff('N'+inttoclavenum(MaxPosCarga,2)+ModoPrecioWayne);
             end;
           end;
           // ENLLAVA O DESENLLAVA DISPENSARIOS
           for xpos:=1 to length(ss) do if xpos in [1..MaxPosCarga] then begin
             with TPosCarga[xpos] do if Estatus=1 then begin
               PosProceso:=xpos;
               if RefrescaEnllavados then begin
                 RefrescaEnllavados:=false;
                 SwReinicio:=true;  // Nuevo
                 if (WayneFusion='No')or(MapeoFusion='Si') then begin
                   ss:='h'+IntToClaveNum(xpos,2)+'00';
                   ComandoConsolaBuff(ss);
                   ss:='k'+IntToClaveNum(xpos,2)+'00';
                   ComandoConsolaBuff(ss);
                   MapeaPosicion(xpos);
                   exit;
                 end;
               end;
             end;
           end;
           SwReinicio:=false;
           NumPaso:=2;
           if PosicionCargaActual>=MaxPosCarga then
             PosicionCargaActual:=0;
         end;
     'A':begin // pide estatus de una bomba
           xpos:=StrToIntDef(copy(lin,2,2),0);
           if xpos in [1..MaxPosCarga] then begin
             ContEsperaPaso2:=0;
             with TPosCarga[xpos] do begin
               try
                 if estatus<>9 then begin
                   xpda:=StrToIntDef(lin[4],0);
                   if (xpda>0)and(xpda<=4) then
                     PosDispActual:=xpda
                   else if PosDispActual=0 then
                     PosDispActual:=1;
                   xvolumen:=StrToFloat(copy(lin,6,8))/1000;
                   simp:=copy(lin,14+Tdiga[1],8);
                   spre:=copy(lin,22+Tdiga[1],5-Tdiga[1]);
                   while length(spre)<5 do
                     spre:=spre+'0';
                   ximporte:=StrToFloat(simp)/1000;
                   if WayneAjusteImporte='Si' then
                     ximporte:=10*ximporte;
                   xprecio:=StrToFloat(spre)/1000;
                   if (2*xvolumen*xprecio<ximporte) then // ajuste por error en digitos
                     ximporte:=ximporte/10;
                   if AjusteWayne='Si' then begin
                     ximporte:=AjustaFloat(xvolumen*xprecio,2);
                     AgregaLog('Calcula importe 1');
                   end
                   else if (AjusteWayne2='Si')and(abs(xvolumen-trunc(xvolumen))<0.0001) then
                     ximporte:=AjustaFloat(xvolumen*xprecio,2)
                   else if (AjusteWayne='No') and (AjusteWayne3='Si') then begin
                     if AjusteWayne3='Si' then begin
                       ximpo:=Trunc(ximporte);
                       centavos:=Round(Frac(ximporte) * 100);
                       if centavos >= 95 then
                         ximporte:=ximpo+1
                       else if centavos <= 5 then
                         ximporte:=ximpo;
                     end;
                     if (importe<(volumen*precio*0.9)) then
                       ximporte:=trunc(volumen*precio*100)/100
                     else begin
                       xvol:=ajustafloat(dividefloat(importe,precio),3);
                       if abs(volumen-xvol)<0.02 then
                         xvolumen:=xvol;
                     end;
                   end
                   else begin
                     if (ximporte<(xvolumen*xprecio*0.9)) then begin
                       ximporte:=trunc(xvolumen*xprecio*100)/100;
                       AgregaLog('Calcula importe 2');
                     end
                     else begin
                       xvolumen:=ajustafloat(dividefloat(ximporte,xprecio),3);
                     end;
                   end;
                   if swcargando then begin
                     if WayneValidaImporteDespacho<>'Si' then begin
                       importe:=ximporte;
                       volumen:=xvolumen;
                       precio:=xprecio;
                     end
                     else if (ximporte>=importeant-0.5) then begin
                       importe:=ximporte;
                       volumen:=xvolumen;
                       precio:=xprecio;
                     end;
                   end
                   else begin
                     importe:=ximporte;
                     volumen:=xvolumen;
                     precio:=xprecio;
                   end;

                   
                   if (not swAvanzoVenta) and (SwCargando) then begin
                     swAvanzoVenta:=(importe<>importeant) and (SwCargando) and (importe>0) and ((importeant>0) or (importe-importeant<IfThen(xcomb=3,80,40)));
                     AgregaLog(ifthen(swAvanzoVenta,'swAvanzoVenta','NOT')+' Estatus='+IntToStr(Estatus)+' ImporteAnt: '+FloatToStr(importeant)+' Importe: '+FloatToStr(importe));
                   end;

                   if estatus<>2 then
                     SwCargando:=false;                   

                   if (swAvanzoVenta) and (Estatus in [1,3,5,9]) then begin// EOT
                     swAvanzoVenta:=False;
                     swdesp:=true;
                     SwPidiendoTotales:=True;
                     SwCargaTotales[PosDispActual]:=True;
                   end;

                   if (TPosCarga[xpos].finventa=0) then begin
                     if (Estatus=3) then begin // FIN DE CARGA
//                       ComandoConsola('R'+inttoclavenum(xpos,2)+'0');
//                       esperamiliseg(100);
                       if sw3virtual then begin
                         sw3virtual:=false;
                         finventa:=0;
                         estatus:=1;
                         estatusant:=1;
                       end;
                     end;
                   end;
                   importeant:=importe;
                   CombActual:=CombustibleEnPosicion(xpos,PosDispActual);
                   MangActual:=MangueraEnPosicion(xpos,PosDispActual);
                 end;
               except
                 if estatus<>2 then
                   SwCargando:=false;
               end;
             end;
           end;
         end;
     'C':begin // TOTALES
           ContEsperaPaso5:=0;
           xpos:=StrToIntDef(copy(lin,2,2),0);
           if xpos in [1..MaxPosCarga] then begin
             i:=StrToIntDef(copy(lin,4,1),0);
             with TPosCarga[xpos] do if (i>0)and(i<=nocomb) then begin
               try
                 for xpr:=1 to nocomb do
                   if TPos[xpr]=i then begin
                     TotalLitros[xpr]:=StrToFloat(copy(lin,6,9))/100;
                     if WayneFusion='Si' then
                       if TDigvol[xpr]=1 then
                         TotalLitros[xpr]:=StrToFloat(copy(lin,6,9))/10;
                     SwCargaTotales[i]:=false;
                   end;
               except
                 on e:Exception do begin
                   AgregaLog('Error ProcesaLineaTotales: '+e.Message);
                   GuardarLog;
                 end;
               end;
             end;
           end;
         end;
    end;
    if (ListaCmnd.Count>0)and(not SwEsperaRsp) then begin
      ss:=ListaCmnd[0];
      ListaCmnd.Delete(0);
      ComandoConsolaBuff(ss);
      exit;
    end;
    if NumPaso=2 then begin  // Checa carga de lecturas
      if PosicionCargaActual<MaxPosCarga then begin
        repeat
          Inc(PosicionCargaActual);
          with TPosCarga[PosicionCargaActual] do if NoComb>0 then begin
            if (estatus<>9)and((estatusant<>estatus)or(estatus in [2,3])or(swcargando)or(SwCargaLectura)) then begin
              SwCargaLectura:=false;
              ComandoConsolaBuff('A'+IntToClaveNum(PosicionCargaActual,2)+'00');
              exit;
            end;
          end;
        until (PosicionCargaActual>=MaxPosCarga);
        for xpos:=1 to MaxPosCarga do with TPosCarga[xpos] do if SwMapea then begin
          SwMapea:=false;
          ComandoConsola(ValorMapeo);
          EsperaMiliSeg(1000);
          exit;
        end;
        NumPaso:=3;StEsperaPaso3:=0; ContPaso3:=0;
      end
      else begin
        NumPaso:=3;StEsperaPaso3:=0; ContPaso3:=0;
      end;
    end;
    if (NumPaso=3) then begin
      NumPaso:=4;
      if PosicionCargaActual2>=MaxPosCarga then
        PosicionCargaActual2:=0;
    end;
    if NumPaso=4 then begin // TOTALES
      if PosicionCargaActual2<=MaxPosCarga then begin
        PosicionCargaActual2:=0;
        repeat
          if PosicionCargaActual2=0 then begin
            PosicionCargaActual2:=1;
            PosicionDispenActual:=1;
          end
          else if PosicionDispenActual<TPosCarga[PosicionCargaActual2].NoComb then
            inc(PosicionDispenActual)
          else begin
            Inc(PosicionCargaActual2);
            PosicionDispenActual:=1;
          end;
          if PosicionCargaActual2<=MaxPosCarga then begin
            if PosicionCargaActual2<1 then
              PosicionCargaActual2:=1;
            with TPosCarga[PosicionCargaActual2] do begin
              if SwCargaTotales[PosicionDispenActual] then begin
                ContEsperaPaso5:=0;
                ComandoConsolaBuff('C'+IntToClaveNum(PosicionCargaActual2,2)+IntToStr(PosicionDispenActual)+'0');
                exit;
              end;
            end;
          end
          else begin
            NumPaso:=5;
            PrecioCombActual:=0;
          end;
        until (PosicionCargaActual2>MaxPosCarga);
        NumPaso:=0;
        PrecioCombActual:=0;
      end
      else begin
        NumPaso:=0;
        PrecioCombActual:=0;
      end;
    end;
  except
    on e:Exception do begin
      AgregaLog('Error ProcesaLinea: '+e.Message);
      GuardarLog;
    end;
  end;
end;

procedure Togcvdispensarios_wayne.pSerialTriggerAvail(CP: TObject;
  Count: Word);
var I:Word;
    C,xbcc:Char;
    xlin:string;
begin
  try
    if ContadorAlarma>=10 then begin
      SwComandoN:=true;
      ContEsperaN:=5;
    end;
    ContadorAlarma:=0;
    Timer1.Enabled:=false;
    try
      for I := 1 to Count do begin
        C:=pSerial.GetChar;
        LineaBuff:=LineaBuff+C;
      end;
      while (not FinLinea)and(Length(LineaBuff)>0) do begin
        c:=LineaBuff[1];
        delete(LineaBuff,1,1);
        Linea:=Linea+C;
        if SwBcc then begin
          FinLinea:=true;
        end;
        if C=idETX then begin
          SwBcc:=true;
        end;
        if (C=idACK)or(c=idNAK) then begin
          FinLinea:=true;
        end;
      end;
      if FinLinea then begin
        LineaTimer:=Linea;
        AgregaLog('R '+LineaTimer);
        Linea:='';
        if length(lineatimer)>3 then begin // valida BCC
          xlin:=copy(lineatimer,2,length(lineatimer)-3);
          xbcc:=lineatimer[length(lineatimer)];
          if xbcc<>CalculaBCC(xlin+#3) then begin
            LineaTimer:=idNak;
          end;
        end;
        SwBcc:=false;
        FinLinea:=false;
        ProcesaLinea;
        LineaTimer:='';
      end;
    finally
      Timer1.Enabled:=true;
    end;
  except
    on e:Exception do begin
      AgregaLog('Error pSerialTriggerAvail: '+e.Message);
      GuardarLog;
    end;
  end;
end;

procedure Togcvdispensarios_wayne.MapeaPosicion(xpos: integer);
var xcomb,xpr:integer;
    ss:string;
begin
  try
    with TPosCarga[xpos] do begin
      SwMapea:=true;
      ss:='g'+IntToClaveNum(xpos,2);
      if length(mapa)=nocomb then begin
        ss:=ss+mapa;
      end
      else begin
        for xpr:=1 to nocomb do
          ss:=ss+IntToStr(CombustibleEnPosicion(xpos,xpr));
      end;
      while length(ss)<10 do
        ss:=ss+'0';
      ValorMapeo:=ss;
    end;
  except
    on e:Exception do begin
      AgregaLog('Error MapeaPosicion: '+e.Message);
      GuardarLog;
    end;
  end;
end;

function Togcvdispensarios_wayne.CombustibleEnPosicion(xpos,
  xposcarga: integer): integer;
var i:integer;
begin
  try
    with TPosCarga[xpos] do begin
      result:=TComb[1];
      for i:=1 to NoComb do begin
        if TPos[i]=xposcarga then
          result:=TComb[i];
      end;
    end;
  except
    on e:Exception do begin
      AgregaLog('Error CombustibleEnPosicion: '+e.Message);
      GuardarLog;
    end;
  end;
end;

procedure Togcvdispensarios_wayne.Timer1Timer(Sender: TObject);
var ss,rsp,str1:string;
    i,xpos,xp,xcomb,xfolio,tag3,
    xcmnd:integer;
    xlimite,
    xprecio:real;
    swok,swerr,swAllTotals:boolean;
begin
  try
    Timer1.Enabled:=False;
    try
      if (reinicioDiario) and (HoursBetween(Now,horaInicio)>=24) and (SecondsBetween(Now,horaDespacho)>=30) then begin
        Detener;
        Terminar;
        Shutdown;
        Exit;
      end;

      if PrecioFisicoProc>0 then begin
        inc(ContPrecioFisico);
        if ContPrecioFisico>20 then
          PrecioFisicoProc:=0;
      end;
      if PrecioCambioProc>0 then begin
        inc(ContPrecioCambio);
        if ContPrecioCambio>20 then
          PrecioCambioProc:=0;
      end;

      if ContadorAlarma>=10 then begin
        if ContadorAlarma=10 then
          AgregaLog('Desconexion de Dispositivo Error Comunicacion Dispensarios');
      end;

      // Checa comandos
      if SwComandoB then begin
        SwComandoB:=false;
        for xcmnd:=1 to 200 do if (TabCmnd[xcmnd].SwActivo and not TabCmnd[xcmnd].SwResp) then begin
          SwAplicaCmnd:=true;
          rsp:='';
          ss:=ExtraeElemStrSep(TabCmnd[xcmnd].Comando,1,' ');
          AgregaLog(TabCmnd[xcmnd].Comando);
          // CMND: CERRAR CONSOLA
          if ss='CERRAR' then begin
            rsp:='OK';
            SwCerrar:=true;
          end
          // ORDENA CARGA DE COMBUSTIBLE
          else if ss='OCC' then begin
            rsp:='OK';
            SnPosCarga:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,2,' '),0);
            xpos:=SnPosCarga;
            if (SnPosCarga in [1..MaxPosCarga]) then begin
              if (TPosCarga[SnPosCarga].estatus in [1,5])or(TPosCarga[SnPosCarga].SwOCC) then begin
                // Valida que se haya aplicado el PRESET
                if TabCmnd[xcmnd].SwNuevo then begin
                  TPosCarga[SnPosCarga].SwOCC:=false;
                  TabCmnd[xcmnd].SwNuevo:=false;
                end;
                Swerr:=false;
                if (TPosCarga[SnPosCarga].SwOCC) then begin
                  if (TPosCarga[SnPosCarga].SwCmndB) then begin
                    if (TPosCarga[SnPosCarga].estatus in [1,5])and(TPosCarga[SnPosCarga].ContOCC>0) then begin
                      TPosCarga[SnPosCarga].SwOCC:=false;
                    end
                    else if (TPosCarga[SnPosCarga].estatus in [1,5])and(TPosCarga[SnPosCarga].ContOCC<=0) then begin
                      rsp:='Error al aplicar PRESET';
                      TPosCarga[SnPosCarga].SwOCC:=false;
                      TPosCarga[SnPosCarga].ContOCC:=0;
                      Swerr:=true;
                    end;
                  end
                  else SwAplicaCmnd:=false;
                end;
                if (TPosCarga[SnPosCarga].estatus in [1,5])and(not TPosCarga[SnPosCarga].SwOCC)and(not swerr) then begin
                  TPosCarga[SnPosCarga].SwOCC:=true;
                  TPosCarga[SnPosCarga].SwCmndB:=false;
                  if TPosCarga[SnPosCarga].ContOCC=0 then
                    TPosCarga[SnPosCarga].ContOCC:=3
                  else begin
                    dec(TPosCarga[SnPosCarga].ContOCC);
                    esperamiliseg(500);
                  end;
                  SwAplicaCmnd:=false;
                  try
                    SnImporte:=StrToFLoat(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,3,' '));
                    rsp:=ValidaCifra(SnImporte,5,2);
                    if rsp='OK' then
                      if (SnImporte<0.01) then
                        SnImporte:=9999;
                  except
                    rsp:='Error en Importe';
                  end;
                  if rsp='OK' then begin
                    xcomb:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,4,' '),0);
                    xp:=PosicionDeCombustible(xpos,xcomb);
                    if xp>0 then begin
                      TPosCarga[SnPosCarga].tipopago:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,5,' '),0);
                      TPosCarga[SnPosCarga].finventa:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,6,' '),0);
                      SnLitros:=0;
                      TPosCarga[SnPosCarga].swarosmag:=false;
                      if rsp='OK' then
                        EnviaPreset(xcomb,rsp);
                    end
                    else rsp:='Combustible no existe en esta posicion';
                  end;
                end;
                if (not SwAplicaCmnd)and(rsp<>'OK') then
                   SwAplicaCmnd:=true;
              end
              else rsp:='Posicion de Carga no Disponible';
              if SwAplicaCmnd then
                TPosCarga[SnPosCarga].SwOCC:=false;
            end
            else rsp:='Posicion de Carga no Existe';
          end
          // ORDENA CARGA DE COMBUSTIBLE LITROS
          else if ss='OCL' then begin
            rsp:='OK';
            SnPosCarga:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,2,' '),0);
            xpos:=SnPosCarga;
            if (SnPosCarga in [1..MaxPosCarga]) then begin
              if (TPosCarga[SnPosCarga].estatus in [1,5])or(TPosCarga[SnPosCarga].SwOCC) then begin
                // Valida que se haya aplicado el PRESET
                if TabCmnd[xcmnd].SwNuevo then begin
                  TPosCarga[SnPosCarga].SwOCC:=false;
                  TabCmnd[xcmnd].SwNuevo:=false;
                end;
                Swerr:=false;
                if (TPosCarga[SnPosCarga].SwOCC) then begin
                  if (TPosCarga[SnPosCarga].SwCmndB) then begin
                    if (TPosCarga[SnPosCarga].estatus in [1,5])and(TPosCarga[SnPosCarga].ContOCC>0) then begin
                      TPosCarga[SnPosCarga].SwOCC:=false;
                    end
                    else if (TPosCarga[SnPosCarga].estatus in [1,5])and(TPosCarga[SnPosCarga].ContOCC<=0) then begin
                      rsp:='Error al aplicar PRESET';
                      TPosCarga[SnPosCarga].SwOCC:=false;
                      TPosCarga[SnPosCarga].ContOCC:=0;
                      Swerr:=true;
                    end;
                  end
                  else SwAplicaCmnd:=false;
                end;
                if (TPosCarga[SnPosCarga].estatus in [1,5])and(not TPosCarga[SnPosCarga].SwOCC)and(not swerr) then begin
                  TPosCarga[SnPosCarga].SwOCC:=true;
                  TPosCarga[SnPosCarga].SwCmndB:=false;
                  if TPosCarga[SnPosCarga].ContOCC=0 then
                    TPosCarga[SnPosCarga].ContOCC:=3
                  else begin
                    dec(TPosCarga[SnPosCarga].ContOCC);
                    esperamiliseg(500);
                  end;
                  SwAplicaCmnd:=false;
                  try
                    SnImporte:=0;
                    SnLitros:=StrToFLoat(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,3,' '));
                    rsp:=ValidaCifra(SnLitros,4,2);
                    if rsp='OK' then
                      if (SnLitros<0.1) then
                        rsp:='Valor minimo permitido: 0.1 lts'
                  except
                    rsp:='Error en Litros';
                  end;
                  if rsp='OK' then begin
                    xcomb:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,4,' '),0);
                    xp:=PosicionDeCombustible(xpos,xcomb);
                    if xp>0 then begin
                      TPosCarga[SnPosCarga].tipopago:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,5,' '),0);
                      TPosCarga[SnPosCarga].finventa:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,6,' '),0);
                      TPosCarga[SnPosCarga].swarosmag:=false;
                      if rsp='OK' then
                        EnviaPreset(xcomb,rsp);
                    end
                    else rsp:='Combustible no existe en esta posicion';
                  end;
                end;
                if (not SwAplicaCmnd)and(rsp<>'OK') then
                   SwAplicaCmnd:=true;
              end
              else rsp:='Posicion de Carga no Disponible';
              if SwAplicaCmnd then
                TPosCarga[SnPosCarga].SwOCC:=false;
            end
            else rsp:='Posicion de Carga no Existe';
          end
          // ORDENA FIN DE VENTA
          else if ss='FINV' then begin
            rsp:='Ok';
            xpos:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,2,' '),0);
            if (xpos in [1..MaxPosCarga]) then begin
              TPosCarga[xpos].tipopago:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,3,' '),0);
              if (TPosCarga[xpos].Estatus=3)or(TPosCarga[xpos].Estatus=1) then begin // EOT
                  TPosCarga[xpos].SwFINV:=true;
                  ComandoConsolaBuff('R'+IntToClaveNum(xpos,2)+'0');
                  if TPosCarga[xpos].sw3virtual then begin
                    TPosCarga[xpos].sw3virtual:=false;
                    TPosCarga[xpos].estatus:=1;
                    TPosCarga[xpos].estatusant:=1;
                    TPosCarga[xpos].finventa:=0;
                  end;
              end
              else begin // EOT
                rsp:='Posicion aun no esta en fin de venta: Estat='+inttostr(TPosCarga[xpos].Estatus);
              end;
            end
            else rsp:='Posicion de Carga no Existe';
          end
          // ORDENA ESPERA FIN DE VENTA
          else if ss='EFV' then begin
            xpos:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,2,' '),0);
            rsp:='OK';
            if (xpos in [1..MaxPosCarga]) then
              if (TPosCarga[xpos].Estatus=2) then
                TPosCarga[xpos].finventa:=1
              else rsp:='Posicion debe estar Despachando'
            else rsp:='Posicion de Carga no Existe';
          end
          else if (ss='DVC')or(ss='PARAR') then begin
            rsp:='OK';
            xpos:=strtointdef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,2,' '),0);
            if xpos in [1..MaxPosCarga] then begin
              if (TPosCarga[xpos].estatus in [2,9]) then begin
                ComandoConsolaBuff('E'+IntToClaveNum(xpos,2));
                TPosCarga[xpos].SwParado:=true;
                if TPosCarga[xpos].estatus=9 then
                  TPosCarga[xpos].tipopago:=0;
              end;
            end;
          end
          else if (ss='REANUDAR') then begin
            rsp:='OK';
            xpos:=strtointdef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,2,' '),0);
            if xpos in [1..MaxPosCarga] then begin
              ComandoConsolaBuff('G'+IntToClaveNum(xpos,2));
              TPosCarga[xpos].SwParado:=false;
            end;
          end
          else if (ss='TOTAL') then begin
            rsp:='OK';
            xpos:=strtointdef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,2,' '),0);
            SwAplicaCmnd:=False;
            with TPosCarga[xpos] do begin
              if (TabCmnd[xcmnd].SwNuevo) and (not SwPidiendoTotales) then begin
                AgregaLog('TOTALES EN TODAS LAS MANGUERAS');
                SwCargaTotales[1]:=true;
                SwCargaTotales[2]:=true;
                SwCargaTotales[3]:=true;
                SwCargaTotales[4]:=true;
              end
              else begin
                for i:=1 to nocomb do begin
                  swAllTotals:=True;
                  if SwCargaTotales[i] then begin
                    swAllTotals:=False;
                    Break;
                  end;
                end;

                if (SwPidiendoTotales) and (SwCargaTotales[PosDispActual]) and (SwDesp) and (SecondsBetween(Now,TabCmnd[xcmnd].hora)>=3) and (not swAllTotals) then begin
                  ToTalLitros[PosDispActual]:=ToTalLitros[PosDispActual]+volumen;
                  SwCargaTotales[PosDispActual]:=False;
                  swAllTotals:=True;
                  SwDesp:=False;
                end;

                if swAllTotals then begin
                  rsp:='OK'+FormatFloat('0.000',ToTalLitros[1])+'|'+FormatoMoneda(ToTalLitros[1]*LPrecios[1])+'|'+
                                  FormatFloat('0.000',ToTalLitros[2])+'|'+FormatoMoneda(ToTalLitros[2]*LPrecios[2])+'|'+
                                  FormatFloat('0.000',ToTalLitros[3])+'|'+FormatoMoneda(ToTalLitros[3]*LPrecios[3])+'|';
                  SwAplicaCmnd:=True;
                end;
              end;
            end;
          end
          else rsp:='Comando no Soportado o no Existe';
          TabCmnd[xcmnd].SwNuevo:=false;
          if SwAplicaCmnd then begin
            TabCmnd[xcmnd].SwResp:=true;
            TabCmnd[xcmnd].Respuesta:=rsp;
            AgregaLog(LlenaStr(TabCmnd[xcmnd].Comando,'I',40,' ')+' Respuesta: '+TabCmnd[xcmnd].Respuesta);
          end;
        end;
      end;

      // Inicia ciclo ------------------
      if NumPaso>1 then begin
        if NumPaso=2 then begin // si esta en espera de respuesta ACK
          inc(ContEsperaPaso2);     // espera hasta 5 ciclos
          if ContEsperaPaso2>MaxEspera2 then begin
            ContEsperaPaso2:=0;
            LineaTimer:='.A00..';  // de lo contrario provoca un NAK para que continue
            ProcesaLinea;       // el proceso con la siguiente solicitud
            exit;
          end;
        end;
        if NumPaso=4 then begin // si esta en espera de respuesta ACK
          inc(ContEsperaPaso5);     // espera hasta 5 ciclos
          if ContEsperaPaso5>5 then begin
            ContEsperaPaso5:=0;
            LineaTimer:='.C00..';  // de lo contrario provoca un NAK para que continue
            ProcesaLinea;       // el proceso con la siguiente solicitud
            exit;
          end;
        end;
        if NumPaso=5 then begin // si esta en espera de respuesta ACK
          inc(ContEsperaPaso6);     // espera hasta 5 ciclos
          if ContEsperaPaso6>3 then begin
            ContEsperaPaso6:=0;
            LineaTimer:='.a00..';  // de lo contrario provoca un NAK para que continue
            ProcesaLinea;       // el proceso con la siguiente solicitud
            exit;
          end;
        end;
        if (NumPaso=3)and(StEsperaPaso3>0) then begin // si esta en espera de respuesta ACK
          inc(ContEsperaPaso3);
          if (ContEsperaPaso3>MaxEspera31)and(StEsperaPaso3=1) then begin
            LineaTimer:='.h1..';
            ProcesaLinea;       // activa la respuesta automatica
            exit;
          end
          else if ContEsperaPaso3>(MaxEspera3+10) then begin
            ContEsperaPaso3:=0;
            StEsperaPaso3:=2;
            LineaTimer:='.s'+IntToClaveNum(PosProceso,2)+'1..';
            ProcesaLinea;       // el proceso con la siguiente solicitud
            exit;
          end;
        end
        else if (NumPaso=3) then begin
          inc(ContEsperaPaso3);
          if (ContEsperaPaso3>MaxEspera31) then begin
            NumPaso:=1;
            ss:='B00';
            ComandoConsolaBuff(ss);
          end;
        end;
        exit;
      end;

      // Espera en el paso 0 hasta que reciba respuesta
      if (NumPaso=1)and(not swreinicio) then begin
        inc(ContEspera);
        if ContEspera<10 then
          exit;
      end;

      NumPaso:=1;
      ContEspera:=0;
      if not SwReinicio then begin
        ss:='B00';
        ComandoConsolaBuff(ss);
      end
      else begin
        SwReinicio:=false;
        LineaTimer:=UltimaLineaTimer;
        ProcesaLinea;
      end;
    except
      on e:Exception do begin
        AgregaLog('Error Timer1Timer: '+e.Message);
        GuardarLog;
      end;
    end;
  finally
    Timer1.Enabled:=True;
  end;
end;

function Togcvdispensarios_wayne.PosicionDeCombustible(xpos,
  xcomb: integer): integer;
var i:integer;
begin
  try
    with TPosCarga[xpos] do begin
      result:=0;
      if xcomb>0 then begin
        for i:=1 to NoComb do begin
          if TComb[i]=xcomb then
            result:=TPos[i];
        end;
      end
      else result:=1;
    end;
  except
    on e:Exception do begin
      AgregaLog('Error PosicionDeCombustible: '+e.Message);
      GuardarLog;
    end;
  end;
end;

procedure Togcvdispensarios_wayne.EnviaPreset(xcomb: integer;
  var rsp: string);
var ss,sval:string;
    i,ndig,xpos,nc:integer;
    swlitros:boolean;
begin
  try
    if SoportaSeleccionProducto<>'Si' then
      xcomb:=0;
    swlitros:=SnLitros>0.01;
    if not (SnPosCarga in [1..MaxPosCarga]) then begin
      rsp:='Posicion de Carga no Existe';
      exit;
    end;
    rsp:='OK';
    xpos:=SnPosCarga;
    if not (TPosCarga[xpos].estatus in [1,5,9]) then begin
      rsp:='Posicion no Disponible';
      exit;
    end;
    if TPosCarga[xpos].SwDesHabilitado then begin
      rsp:='Posicion Deshabilitada';
      exit;
    end;
    if TPosCarga[xpos].estatus=9 then begin
      ComandoConsolaBuff('E'+IntToClaveNum(xpos,2));
    end;
    if SnImporte>=9999 then
      ss:='S'+IntToClaveNum(SnPosCarga,2)+'00'
    else begin
      ss:='P'+IntToClaveNum(SnPosCarga,2);
      if not swlitros then begin // pesos
        TPosCarga[xpos].importe_aros:=SnImporte;
        ss:=ss+'0';
        ss:=ss+'0'; //IntToStr(TPosCarga[SnPosCarga].TPrec[1]);   // 1-contado 0,2-credito
        if DecimalesPresetWayne=0 then
          sval:=FiltraStrNum(FormatFloat('00000000',SnImporte))
        else if DecimalesPresetWayne=1 then
          sval:=FiltraStrNum(FormatFloat('0000000.0',SnImporte))
        else if DecimalesPresetWayne=2 then
          sval:=FiltraStrNum(FormatFloat('000000.00',SnImporte))
        else if DecimalesPresetWayne=3 then
          sval:=FiltraStrNum(FormatFloat('00000.000',SnImporte))
        else begin
          sval:=FiltraStrNum(FormatFloat('000000.00',SnImporte));
          if TPosCarga[SnPosCarga].tdigpreset[1]>=0 then
            ndig:=TPosCarga[SnPosCarga].tdigpreset[1]
          else
            ndig:=TPosCarga[SnPosCarga].tdiga[1];
          if ndig>0 then begin
            sval:=IntToClaveNum(0,ndig)+sval;
            sval:=copy(sval,1,8);
          end;
        end;
        ss:=ss+sval;
      end
      else begin // litros
        ss:=ss+'1';
        ss:=ss+'0'; //IntToStr(TPosCarga[SnPosCarga].TPrec[1]);   // 1-contado 0,2-credito
        case DecimalesPresetWayneLitros of
          1:sval:=FiltraStrNum(FormatFloat('0000000.0',SnLitros)); //saux:='0000000.0';
          2:sval:=FiltraStrNum(FormatFloat('000000.00',SnLitros)); //saux:='000000.00';
          3:sval:=FiltraStrNum(FormatFloat('00000.000',SnLitros)); //saux:='00000.000';
          4:sval:=FiltraStrNum(FormatFloat('0000.0000',SnLitros)); //saux:='0000.0000';
        end;
        ss:=ss+sval;
      end;
      if xcomb>0 then begin
        i:=PosiciondeCombustible(xpos,xcomb);
        if i=0 then
          ss:=ss+'0'
        else
          ss:=ss+inttostr(i);
      end
      else
        ss:=ss+'0';
    end;

    TPosCarga[xpos].HoraOcc:=now;
    ComandoConsolaBuff(ss);
  except
    on e:Exception do begin
      AgregaLog('Error EnviaPreset: '+e.Message);
      GuardarLog;
    end;
  end;
end;

function Togcvdispensarios_wayne.MangueraEnPosicion(xpos,
  xposcarga: integer): integer;
var i:integer;
begin
  try
    with TPosCarga[xpos] do begin
      result:=TComb[1];
      for i:=1 to NoComb do begin
        if TPos[i]=xposcarga then
          result:=TMang[i];
      end;
    end;
  except
    on e:Exception do begin
      AgregaLog('Error MangueraEnPosicion: '+e.Message);
      GuardarLog;
    end;
  end;
end;

procedure Togcvdispensarios_wayne.IniciarPrecios;
var
  xpos,i:Integer;
  ss:String;
begin
  try
    for i:=1 to 4 do begin
      if ValidaCifra(LPrecios[i],2,2)='OK' then begin
        if WayneFusion='No' then begin
          ComandoConsolaBuff('a'+IntToStr(IfThen(i>1,i+1,i))+TierLavelWayne+'1'+'0'+IntToClaveNum(Trunc(LPrecios[i]*100+0.5),4)); // contado
          ComandoConsolaBuff('a'+IntToStr(IfThen(i>1,i+1,i))+TierLavelWayne+'0'+'0'+IntToClaveNum(Trunc(LPrecios[i]*100+0.5),4)); // credito
        end
        else begin
          ComandoConsolaBuff('a'+IntToStr(IfThen(i>1,i+1,i))+TierLavelWayne+'1'+'0'+IntToClaveNum(Trunc(LPrecios[i]*100+0.5),4)+'0'); // contado
          ComandoConsolaBuff('a'+IntToStr(IfThen(i>1,i+1,i))+TierLavelWayne+'0'+'0'+IntToClaveNum(Trunc(LPrecios[i]*100+0.5),4)+'0');  // credito
        end;
      end;
    end;
    PreciosInicio:=False;
  except
    on e:Exception do begin
      AgregaLog('Error IniciarPrecios: '+e.Message);
      GuardarLog;
    end;
  end;
end;

procedure Togcvdispensarios_wayne.GuardaLogComandos;
var
  i:Integer;
begin
  try
    ListaComandos.Clear;
    for i:=1 to 200 do begin
      with TabCmnd[i] do begin
        if SwActivo then
          ListaComandos.Add(FechaHoraExtToStr(hora)+' Folio: '+IntToClaveNum(folio,3)+' Comando: '+Comando);
      end;      
    end;
    ListaComandos.SaveToFile(rutaLog+'\LogDispComandos'+FiltraStrNum(FechaHoraToStr(Now))+'.txt');
  except
    on e:Exception do
      Exception.Create('GuardaLogComandos: '+e.Message);
  end;

end;

function Togcvdispensarios_wayne.ExtraeElemStrEnter(xstr: string;
  ind: word): string;
var i,cont,nc:word;
    ss:string;
begin
  xstr:=xstr+' ';
  cont:=1;ss:='';
  i:=1;nc:=length(xstr);
  while (cont<ind)and(i<nc) do begin
    if (xstr[i]=#13)and(xstr[i+1]=#10) then begin
      inc(i);
      inc(cont);
    end;
    inc(i);
  end;
  while (i<nc) do begin
    if (xstr[i]=#13)and(xstr[i+1]=#10) then
      i:=nc
    else ss:=ss+xstr[i];
    inc(i);
  end;
  result:=limpiastr(ss);
end;

function Togcvdispensarios_wayne.NoElemStrEnter(xstr: string): word;
var i,cont,nc:word;
begin
  xstr:=xstr+' ';
  cont:=1;
  i:=1;nc:=length(xstr);
  while (i<nc) do begin
    if (xstr[i]=#13)and(xstr[i+1]=#10) then begin
      inc(i);
      inc(cont);
    end;
    inc(i);
  end;
  result:=cont;
end;

procedure Togcvdispensarios_wayne.ServiceDestroy(Sender: TObject);
begin
  GuardarLog;
end;

procedure Togcvdispensarios_wayne.ServiceShutdown(Sender: TService);
begin
  GuardarLog;
end;

procedure Togcvdispensarios_wayne.ServiceStop(Sender: TService;
  var Stopped: Boolean);
begin
  GuardarLog;
end;

procedure Togcvdispensarios_wayne.ComandoConsolaBuff(ss: string);
begin
  if (ListaCmnd.Count=0)and(not SwEsperaRsp) then
    ComandoConsola(ss)
  else
    ListaCmnd.Add(ss);
end;

end.
