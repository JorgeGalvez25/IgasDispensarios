unit UIGASPAM;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, SvcMgr, Dialogs, Math,
  ExtCtrls, OoMisc, AdPort, ScktComp, IniFiles, ULIBGRAL, DB, RxMemDS, uLkJSON,
  Variants, CRCs, IdHashMessageDigest, IdHash, ActiveX, ComObj, LbCipher, LbString,
  TypInfo, StrUtils, DateUtils;

const
      MCxP=4;

type
  Togcvdispensarios_pam = class(TService)
    pSerial: TApdComPort;
    Timer1: TTimer;
    ClientSocket1: TClientSocket;
    Timer2: TTimer;
    procedure ServiceExecute(Sender: TService);
    procedure pSerialTriggerAvail(CP: TObject; Count: Word);
    procedure Timer1Timer(Sender: TObject);
    procedure Timer2Timer(Sender: TObject);
    procedure ClientSocket1Connect(Sender: TObject; Socket: TCustomWinSocket);
    procedure ClientSocket1Disconnect(Sender: TObject; Socket: TCustomWinSocket);
    procedure ClientSocket1Read(Sender: TObject; Socket: TCustomWinSocket);
  private
    { Private declarations }
    ContadorAlarma:integer;
    LineaBuff,
    LineaTimer,
    Linea:string;
    SwEspera,
    SwBcc,
    swcierrabd,
    FinLinea:boolean;
    UltimoStatus:string;
    MapCombs:string;
    LigaCombs:string;
    SnPosCarga:integer;
    SnImporte,SnLitros:real;
    SwError,SwMapOff  :boolean;
    ContEspera1,
    ContEsperaPaso2,
    ContEsperaPaso3,
    ContEsperaPaso4,
    ContEsperaPaso5,
    NumPaso,
    ModoAutorizaPam,
    PrecioCombActual,
    PosicionDispenActual,
    PosicionCargaActual:integer;
    xPosT:Integer;
    ReautorizaPam,
    VersionPam1000,SetUpPAM1000:string;
    AjustePAM:Boolean;
    ValidaMang:Boolean;
    
    // JSON and Socket Control
    xTurnoSocket:Integer;
    conectado, respJson:Boolean;
    rootJSON : TlkJSONbase;
    socketResponse : TCustomWinSocket;

  public
    ListaLog:TStringList;
    ListaLogPetRes:TStringList;
    rutaLog:string;
    confPos:string;
    licencia:string;
    detenido:Boolean;
    estado:Integer;
    digiVol,digiPrec,digiImp:Integer;
  // CONTROL TRAFICO COMANDOS
    ListaCmnd    :TStrings;
    LinCmnd      :string;
    CharCmnd     :char;
    SwEsperaRsp  :boolean;
    ContEsperaRsp:integer;
    FolioCmnd   :integer;
    ContadorTotPos,
    ContadorTot :Integer;
    ListaComandos:TStringList;
    horaLog:TDateTime;
    minutosLog:Integer;
    version:string;
    function GetServiceController: TServiceController; override;
    procedure AgregaLog(lin:string);
    procedure AgregaLogPetRes(lin: string);
    procedure Responder(resp:string);
    function FechaHoraExtToStr(FechaHora:TDateTime):String;
    function IniciaPSerial(datosPuerto:string): string;
    procedure ComandoConsola(ss:string);
    procedure ComandoConsolaBuff(ss:string);
    function CalculaBCC(ss:string):char;
    function CRC16(Data: string): string;
    function XorChar(c1,c2:char):char;
    procedure ProcesaLinea;
    procedure EnviaPreset(var rsp:string;xcomb:integer);
    procedure EnviaPreset3(var rsp:string;xcomb:integer);
    function CombustibleEnPosicion(xpos,xposcarga:integer):integer;
    function MangueraEnPosicion(xpos,xposcarga:integer):integer;
    function ValidaCifra(xvalor:real;xenteros,xdecimales:byte):string;
    function PosicionDeCombustible(xpos,xcomb:integer):integer;
    
    // Commands refactored for JSON/Socket
    function AgregaPosCarga(posiciones: TlkJSONbase): string;
    procedure IniciaPrecios(folio:Integer; msj: string);
    procedure AutorizarVenta(folio:Integer; msj: string);
    procedure DetenerVenta(folio:Integer; msj: string);
    procedure ReanudarVenta(folio:Integer; msj: string);
    procedure ActivaModoPrepago(folio:Integer; msj:string);
    procedure DesactivaModoPrepago(folio:Integer; msj:string);
    function EjecutaComando(xCmnd:string):integer;
    procedure FinVenta(folio:Integer; msj: string);
    function TransaccionPosCarga(msj: string): string;
    function EstadoPosiciones(msj: string): string;
    procedure TotalesBomba(folio:Integer; msj: string);
    procedure Detener(folio:Integer);
    procedure Iniciar(folio:Integer);
    procedure Shutdown(folio:Integer);
    function ObtenerEstado: string;
    procedure GuardarLog(folio:Integer);
    procedure GuardarLogPetRes(folio:Integer);
    procedure RespuestaComando(folio:Integer; msj: string);
    procedure ObtenerLog(folio:Integer; r: Integer);
    procedure ObtenerLogPetRes(folio:Integer; r: Integer);
    function ResultadoComando(xFolio:integer):string;
    procedure Bloquear(folio:Integer; msj: string);
    procedure Desbloquear(folio:Integer; msj: string);
    procedure Inicializar(folio:Integer; msj: string);
    procedure Terminar(folio:Integer);
    function NoElemStrEnter(xstr:string):word;
    function ExtraeElemStrEnter(xstr:string;ind:word):string;
    procedure Login(folio:Integer; mensaje: string);
    procedure Logout(folio:Integer);
    function MD5(const usuario: string): string;
    procedure GuardaLogComandos;
    function Encrypt(data,key3DES:string):string;
    function Decrypt(data,key3DES:string):string;
    
    // JSON Helpers
    procedure ActualizaCampoJSON(xpos:Integer; campo:string; valor:Variant);
    procedure AddPeticionJSON(const aFolio: Integer; const aResultado : string);
    procedure SetEstadoJSON(const AEstado: Integer);
    
    { Public declarations }
  end;

type
     tiposcarga = record
       estatus  :integer;
       descestat:string[20];
       importe,
       importeant,
       volumen,
       precio   :real;
       //Isla,
       PosActual:integer; // Posicion del combustible en proceso: 1..NoComb
       estatusant:integer;
       NoComb   :integer; // Cuantos combustibles hay en la posicion
       TComb    :array[1..MCxP] of integer; // Claves de los combustibles
       TCombx    :array[1..MCxP] of integer;
       TPosx      :array[1..MCxP] of integer;
       TDiga    :array[1..MCxP] of integer;
       TDigvol    :array[1..MCxP] of integer;
       //TDigit    :integer;
       TMapa    :array[1..MCxP] of string[6];
       SwMapea    :array[1..MCxP] of boolean;
       //TotalLitrosAnt:array[1..MCxP] of real;
       TotalLitros:array[1..MCxP] of real;
       SwTotales:array[1..MCxP] of boolean;
       TMang    :array[1..MCxP] of integer;
       SwDesp,swprec:boolean;
       SwA:boolean;
       Hora:TDateTime;
       SwInicio:boolean;
       SwInicio2:boolean;
       SwPreset:boolean;
       MontoPreset:string;
       ImportePreset:real;
       Mensaje:string[30];
       swnivelprec,
       swautorizada,
       swautorizando,
       swcargando:boolean;
       swAvanzoVenta:boolean;
       SwActivo,
       SwOCC,SwCmndB,
       SwPidiendoTotales,
       SwDesHabilitado:boolean;
       ModoOpera:string[8];
       TipoPago:integer;
       ContOcc,
       FinVenta:integer;
       HoraOcc:TDateTime;
       CmndOcc:string[25];
       CombActual:Integer;
       MangActual:Integer;
       MangAnterior:Integer;
       HoraTotales:TDateTime;
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
      MaximoDePosiciones = 32;
      NivelPrecioContado='1';
      NivelPrecioCredito='2';
      MaxEsperaRsp=5;
      MaxEspera2=20;
      MaxEspera3=10;

type TMetodos = (NOTHING_e, INITIALIZE_e, PARAMETERS_e, LOGIN_e, LOGOUT_e,
             PRICES_e, AUTHORIZE_e, STOP_e, START_e, SELFSERVICE_e, FULLSERVICE_e,
             BLOCK_e, UNBLOCK_e, PAYMENT_e, TRANSACTION_e, STATUS_e, TOTALS_e, HALT_e,
             RUN_e, SHUTDOWN_e, TERMINATE_e, STATE_e, TRACE_e, SAVELOGREQ_e, RESPCMND_e,
             LOG_e, LOGREQ_e);


var
  ogcvdispensarios_pam: Togcvdispensarios_pam;
  TPosCarga:array[1..32] of tiposcarga;
  TabCmnd  :array[1..200] of RegCmnd;
  LPrecios :array[1..4] of Double;
  MaxPosCarga:integer;
  MaxPosCargaActiva:integer;
  ContDA     :integer;
  SwAplicaCmnd,
  PreciosInicio,
  SwCerrar    :boolean;
  // CONTROL TRAFICO COMANDOS
  ListaCmnd     :TStrings;
  LinCmnd       :string;
  CharCmnd      :char;
  SwEsperaRsp,
  SwComandoB    :boolean;
  LinEstadoGen  :string;
  Token        :string;

implementation

{$R *.DFM}

procedure ServiceController(CtrlCode: DWord); stdcall;
begin
  ogcvdispensarios_pam.Controller(CtrlCode);
end;

function Togcvdispensarios_pam.GetServiceController: TServiceController;
begin
  Result := ServiceController;
end;

procedure Togcvdispensarios_pam.ServiceExecute(Sender: TService);
var
  config:TIniFile;
begin
  try
    config:= TIniFile.Create(ExtractFilePath(ParamStr(0)) +'PDISPENSARIOS.ini');
    rutaLog:=config.ReadString('CONF','RutaLog','C:\ImagenCo');
    ClientSocket1.Host:=ExtraeElemStrSep(config.ReadString('CONF','ServidorSocket','127.0.0.1:1004'), 1, ':');
    ClientSocket1.Port:=StrToInt(ExtraeElemStrSep(config.ReadString('CONF','ServidorSocket','127.0.0.1:1004'), 2, ':'));
    licencia:=config.ReadString('CONF','Licencia','');
    SwMapOff:=Mayusculas(config.ReadString('CONF','MapOff',''))='SI';
    MapCombs:=config.ReadString('CONF','MapeoCombustibles','');
    LigaCombs:=config.ReadString('CONF','LigueCombustibles','');
    minutosLog:=StrToInt(config.ReadString('CONF','MinutosLog','0'));
    
    ListaCmnd:=TStringList.Create;
    detenido:=True;
    estado:=-1;
    SwComandoB:=false;
    horaLog:=Now;
    ListaLog:=TStringList.Create;
    ListaLogPetRes:=TStringList.Create;
    ListaComandos:=TStringList.Create;
    rootJSON:=TlkJSONObject.Create;
    SetEstadoJSON(estado);

    ReautorizaPam:='No';

    while not Terminated do
      ServiceThread.ProcessRequests(True);
    ClientSocket1.Active := False;
  except
    on e:exception do begin
      ListaLog.Add('Error al iniciar servicio: '+e.Message);
      ListaLog.SaveToFile(rutaLog+'\LogDispPetRes'+FiltraStrNum(FechaHoraToStr(Now))+'.txt');
      GuardarLog(0);
      if ListaLogPetRes.Count>0 then
        GuardarLogPetRes(0);      
    end;
  end;
end;

procedure Togcvdispensarios_pam.Timer2Timer(Sender: TObject);
var
  i:Integer;
begin
  try
    try
      Timer2.Enabled:=False;
      if not conectado then begin
        ClientSocket1.Active:=True;
        for i:=0 to 100 do begin
          Sleep(10);
          if conectado then Break;
        end;
        if not conectado then Exit;
      end;

      if not respJson then
        Responder('PING')
      else
        Responder(TlkJSON.GenerateText(rootJSON));

      if estado>0 then begin
        Timer2.Enabled:=False;
        Timer1.Enabled:=True;
      end;
    except
      on e:Exception do begin
        AgregaLog('Error Timer2Timer: '+e.Message);
        GuardarLog(0);
      end;
    end;
  finally
    Timer2.Enabled := estado<=0;
  end;
end;

procedure Togcvdispensarios_pam.ClientSocket1Connect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
  conectado:=True;
end;

procedure Togcvdispensarios_pam.ClientSocket1Disconnect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
  conectado:=False;
  Timer1.Enabled:=False;
  Timer2.Enabled:=True;
end;

procedure Togcvdispensarios_pam.ClientSocket1Read(Sender: TObject;
  Socket: TCustomWinSocket);
  var
    mensaje,comando,checksum,parametro:string;
    i,folio:Integer;
    chks_valido:Boolean;
    metodoEnum:TMetodos;
begin
  try
    mensaje:=Socket.ReceiveText;
    if mensaje<>'' then begin
      AgregaLogPetRes('R '+mensaje);

      folio:=StrToIntDef(ExtraeElemStrSep(mensaje,1,'|'),0);

      // Wayne style message parsing: Folio|Target|Command|Params
      if UpperCase(ExtraeElemStrSep(mensaje,2,'|'))<>'DISPENSERS' then begin
        AddPeticionJSON(folio, 'False|Este servicio solo procesa solicitudes de dispensarios|');
        Exit;
      end;

      comando:=UpperCase(ExtraeElemStrSep(mensaje,3,'|'));

      if NoElemStrSep(mensaje,'|')>3 then begin
        for i:=4 to NoElemStrSep(mensaje,'|') do
          parametro:=parametro+ExtraeElemStrSep(mensaje,i,'|')+'|';

        if parametro[Length(parametro)]='|' then
          Delete(parametro,Length(parametro),1);
      end;

      metodoEnum := TMetodos(GetEnumValue(TypeInfo(TMetodos), comando+'_e'));

      case metodoEnum of
        NOTHING_e:
          AddPeticionJSON(folio, 'True|');
        INITIALIZE_e:
          Inicializar(folio, parametro);
        PARAMETERS_e:
          AddPeticionJSON(folio, 'True|');
        LOGIN_e:
          Login(folio, parametro);
        LOGOUT_e:
          Logout(folio);
        PRICES_e:
          IniciaPrecios(folio, parametro);
        AUTHORIZE_e:
          AutorizarVenta(folio, parametro);
        STOP_e:
          DetenerVenta(folio, parametro);
        START_e:
          ReanudarVenta(folio, parametro);
        SELFSERVICE_e:
          ActivaModoPrepago(folio, parametro);
        FULLSERVICE_e:
          DesactivaModoPrepago(folio, parametro);
        BLOCK_e:
          Bloquear(folio, parametro);
        UNBLOCK_e:
          Desbloquear(folio, parametro);
        PAYMENT_e:
          FinVenta(folio, parametro);
        TRANSACTION_e:
          AddPeticionJSON(folio, TransaccionPosCarga(parametro));
        STATUS_e:
          AddPeticionJSON(folio, EstadoPosiciones(parametro));
        TOTALS_e:
          TotalesBomba(folio, parametro);
        HALT_e:
          Detener(folio);
        RUN_e:
          Iniciar(folio);
        SHUTDOWN_e:
          Shutdown(folio);
        TERMINATE_e:
          Terminar(folio);
        STATE_e:
          AddPeticionJSON(folio, ObtenerEstado);
        TRACE_e:
          GuardarLog(folio);
        SAVELOGREQ_e:
          GuardarLogPetRes(folio);
        RESPCMND_e:
          RespuestaComando(folio, parametro);
        LOG_e:
          ObtenerLog(folio, StrToIntDef(parametro, 0));
        LOGREQ_e:
          ObtenerLogPetRes(folio, StrToIntDef(parametro, 0));
      else
        AddPeticionJSON(folio, 'False|Comando desconocido|');
      end;
      socketResponse:=Socket;
    end;
  except
    on e:Exception do begin
      AgregaLogPetRes('Error ClientSocket1Read: '+e.Message);
      GuardarLog(0);
      AddPeticionJSON(folio, 'False|'+e.Message+'|');
    end;
  end;
end;

procedure Togcvdispensarios_pam.Responder(resp: string);
begin
  try
    if Assigned(socketResponse) then begin
      socketResponse.SendText(resp);
      socketResponse:=nil;
    end
    else
      ClientSocket1.Socket.SendText(resp);

    AgregaLogPetRes('E '+resp);
  except
    on e:Exception do begin
      AgregaLogPetRes('False|Excepcion: '+e.Message+'|');
      GuardarLogPetRes(0);
    end;
  end;
end;

// Helper to update JSON fields
procedure Togcvdispensarios_pam.ActualizaCampoJSON(xpos: Integer;
  campo: string; valor: Variant);
var
  posArr : TlkJSONlist;
  posObj : TlkJSONObject;
  field  : TlkJSONbase;
  i      : Integer;
begin
  try
    if rootJSON = nil then
      AgregaLog('rootJSON is nulo');

    posArr := TlkJSONlist(rootJSON.Field['PosCarga']);
    if posArr = nil then
      AgregaLog('No se encontro "PosCarga" en rootJSON.');

    for i := 0 to posArr.Count - 1 do
    begin
      posObj := TlkJSONObject(posArr.Child[i]);
      if posObj = nil then
        Continue;

      if (posObj.Field['DispenserId'] <> nil) and
         (posObj.Field['DispenserId'].Value = xpos) then
      begin
        // Found the dispenser by ID
      end
      else if (posObj.Field['DispenserId'] = nil) and (i + 1 = xpos) then
      begin
        // Fallback by index
      end
      else
        Continue;

      field := posObj.Field[campo];

      if field <> nil then
        field.Value := valor;

      Exit;
    end;
  except
    on e:Exception do begin
      AgregaLog('Error ActualizaCampoJSON: '+e.Message+'|');
    end;
  end;
end;

procedure Togcvdispensarios_pam.SetEstadoJSON(const AEstado: Integer);
var
  estadoNode: TlkJSONbase;
begin
  if rootJSON = nil then Exit;
  estadoNode := rootJSON.Field['Estado'];

  if Assigned(estadoNode) then
    estadoNode.Value := AEstado
  else
    TlkJSONObject(rootJSON).Add('Estado', TlkJSONnumber.Generate(AEstado));
end;

procedure Togcvdispensarios_pam.AddPeticionJSON(const aFolio: Integer;
  const aResultado: string);
var
  petArr : TlkJSONlist;
  petObj : TlkJSONObject;
begin
  try
    if rootJSON = nil then
      AgregaLog('rootObj es nulo');

    petArr := TlkJSONlist(rootJSON.Field['Peticiones']);

    if petArr = nil then
    begin
      petArr := TlkJSONlist.Create;
      TlkJSONobject(rootJSON).Add('Peticiones', petArr);
    end;

    while petArr.Count >= 2 do
      petArr.Delete(0);

    petObj := TlkJSONObject.Create;
    petObj.Add('Folio',     aFolio);
    petObj.Add('Resultado', aResultado);

    petArr.Add(petObj);
    respJson:=True;
  except
    on e:Exception do begin
      AgregaLog('Error AddPeticionJSON: '+e.Message+'|');
      GuardarLog(0);
    end;
  end;
end;


procedure Togcvdispensarios_pam.AgregaLog(lin: string);
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
  while ListaLog.Count>10000 do
    ListaLog.Delete(0);
  ListaLog.Add(lin2);
end;

procedure Togcvdispensarios_pam.AgregaLogPetRes(lin: string);
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

function Togcvdispensarios_pam.FechaHoraExtToStr(FechaHora: TDateTime): String;
begin
  result:=FechaPaq(FechaHora)+' '+FormatDatetime('hh:mm:ss.zzz',FechaHora);
end;

function Togcvdispensarios_pam.IniciaPSerial(datosPuerto: string): string;
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

procedure Togcvdispensarios_pam.ComandoConsola(ss: string);
var s1:string;
    cc:char;
begin
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
end;

function Togcvdispensarios_pam.CalculaBCC(ss: string): char;
var xc,cc:char;
    i:integer;
begin
  xc:=ss[1];
  for i:=2 to length(ss) do begin
    cc:=ss[i];
    xc:=XorChar(xc,cc);
  end;
  result:=xc;
end;

function Togcvdispensarios_pam.XorChar(c1, c2: char): char;
var bits1,bits2,bits3:array[0..7] of boolean;
    nn,n1,n2,i,nr:byte;
begin
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
end;

procedure Togcvdispensarios_pam.pSerialTriggerAvail(CP: TObject; Count: Word);
var I:Word;
    C:Char;
begin
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
      if (C=idACK)or(c=idNAK) then
        FinLinea:=true;
    end;
    if FinLinea then begin
      LineaTimer:=Linea;
      AgregaLog('R '+LineaTimer);
      Linea:='';
      SwBcc:=false;
      FinLinea:=false;
      SwError:=(lineaTimer=idNak);
      if SwError then
        Inc(NumPaso);
      ProcesaLinea;
      LineaTimer:='';
    end;
  finally
    Timer1.Enabled:=true;
  end;
end;

procedure Togcvdispensarios_pam.ProcesaLinea;
label uno;
var lin,ss,rsp,
    xestado,xmodo,precios:string;
    simp,sval,spre:string[20];
    i,xpos,xcmnd,combx,
    XMANG,XCTE,XVEHI,
    xcomb,xp,xc,xfolio:integer;
    xgrade:char;
    precioComb,
    ximporte:real;
    xvol,ximp:real;
    swerr,SwAplicaMapa,swAllTotals:boolean;
    SnImporteStr,SnLitrosStr,decImporteStr:String;
begin
  try
    if (minutosLog>0) and (MinutesBetween(Now,horaLog)>=minutosLog) then begin
      horaLog:=Now;
      GuardarLog(0);
    end;
    
    // Timer2 handles socket/JSON updates, but we also ensure turn rotation here if needed
    Inc(xTurnoSocket);
    if xTurnoSocket>3 then xTurnoSocket:=1;

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
    case lin[1] of
     'B':begin // pide estatus de todas las bombas
           try
             SwAplicaMapa:=true;
             ContEspera1:=0;
             ss:=copy(lin,4,length(lin)-3);
             MaxPosCargaActiva:=length(ss);
             xestado:='';
             if MaxPosCargaActiva>MaxPosCarga then
               MaxPosCargaActiva:=MaxPosCarga;
             for xpos:=1 to MaxPosCargaActiva do begin
               with TPosCarga[xpos] do begin
                 SwAutorizando:=false;
                 SwCmndB:=true;
                 if estatusant<>estatus then
                   SwA:=true; //CAMBIO
                 estatusant:=estatus;
                 estatus:=StrToIntDef(ss[xpos],0);
                 
                 // Update JSON status
                 ActualizaCampoJSON(xpos, 'Estatus', estatus);

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
                 case estatus of
                   0:begin
                       descestat:='---';  // OFFLINE
                       swautorizada:=false;
                     end;
                   1:begin              // IDLE
                       if (estatusant in [9,2]) then begin
                         if (now-TPosCarga[xpos].HoraOcc)<=60*tmsegundo then begin
                           AgregaLog('Reenvia: '+TPosCarga[xpos].CmndOcc);
                           ComandoConsolaBuff(TPosCarga[xpos].CmndOcc);
                           TPosCarga[xpos].HoraOcc:=now-1000*tmsegundo;
                           exit;
                         end;
                       end;
                       if swprec then
                         swprec:=false;
                       swautorizada:=false;
                       descestat:='Inactivo';
                       if SwComandoB then begin
                         if not swnivelprec then begin
                           xPosT:=xpos;
                           ComandoConsola('T'+inttoclavenum(xpos,2)+'1'); // NIVEL DE PRECIOS: CASH
                           exit;
                           SwAPlicaMapa:=false;
                         end;
                       end;
                       if (estatusant<>estatus) then begin
                         FinVenta:=0;
                         TipoPago:=0;
                         //SwArosMag:=false;
                         SwOcc:=false;
                         ContOcc:=0;
                       end;
                     end;
                   2:begin              // BUSY
                       descestat:='Despachando';
                       //IniciaCarga:=true;
                       SwCargando:=true;
                       SwDesp:=False;
                       SwPidiendoTotales:=False;
                     end;
                   3:begin
                       descestat:='Fin de Venta';       // EOT
                       TPosCarga[xpos].HoraOcc:=now-1000*tmsegundo;
                     end;
                   5:begin
                       descestat:='Pistola Levantada';  // CALL
                       if (estatusant<>estatus) then begin
                         swautorizada:=false;
                         FinVenta:=0;
                         TipoPago:=0;
                         //SwArosMag:=false;
                         SwOcc:=false;
                         ContOcc:=0;
                       end;
                     end;
                   6:begin
                       descestat:='Cerrada';            // CLOSED
                       ComandoConsolaBuff('L'+inttoclavenum(xpos,2));
                     end;
                   8:begin
                       descestat:='Detenida';           // STOP
                     end;
                   9:begin
                       descestat:='Autorizada';         // AUTHORIZED
                       swautorizada:=true;
                     end;
                 end;
                 case estatus of
                   0,6:begin
                       xestado:=xestado+'0';
                     end;
                   2:xestado:=xestado+'2';
                   else xestado:=xestado+'1';
                 end;
               end;
             end;

             if not SwComandoB then begin
               SwComandoB:=true;
               if VersionPam1000='3' then begin
                 if SetUpPAM1000='' then
                   ComandoConsola('D06222'); // D05233
                 Esperamiliseg(500);
                 if SetUpPAM1000<>'.' then
                   ComandoConsola('D0'+SetUpPAM1000);
               end
               else if SetUpPAM1000<>'' then
                 ComandoConsola('D0'+SetUpPAM1000);
               EsperaMiliSeg(500);
               exit;
             end;
             if (swcomandob) then begin
               // MAPEA LOS PRODUCTOS
               if SwAplicaMapa then begin
                 for xpos:=1 to MaxPosCargaActiva do with TPosCarga[xpos] do begin
                   for i:=1 to MCxP do if SwMapea[i] then begin
                     if TMapa[i]<>'' then
                       ComandoConsola(TMapa[i]);
                     SwMapea[i]:=false;
                     ContEspera1:=10;
                     exit;
                   end;
                 end;
               end
               else begin
                 ContEspera1:=10;
                 exit;
               end;
               // Checa las posiciones que estan en fin de ventas
               for xpos:=1 to MaxPosCargaActiva do begin
                 with TPosCarga[xpos] do begin
                   case Estatus of
                     6:if SwInicio then begin
                         ss:='L'+IntToClaveNum(xpos,2); // OPEN PUMP
                         ComandoConsola(ss);
                         EsperaMiliSeg(100);
                         SwInicio:=false;
                       end;
                     5:if (not SwDesHabilitado)and(not swautorizada) then begin
                         if (ModoOpera='Normal') then
                           SwInicio:=false;
                       end
                       else if (swautorizada)and(ReautorizaPam='Si') then begin
                         if (now-TPosCarga[xpos].HoraOcc)<=60*tmsegundo then begin
                           AgregaLog('Reenvia: '+TPosCarga[xpos].CmndOcc);
                           ComandoConsolaBuff(TPosCarga[xpos].CmndOcc);
                           TPosCarga[xpos].HoraOcc:=now-1000*tmsegundo;
                           exit;
                         end;
                       end;
                     8:if (ModoOpera='Normal') then begin
                         ss:='G'+IntToClaveNum(xpos,2); // RESTART
                         ComandoConsolaBuff(ss);
                       end;
                   end;
                 end;
               end;
             end;

             // GUARDA VALORES DE DISPENSARIOS CARGANDO
             lin:='';xestado:='';xmodo:='';
             for xpos:=1 to MaxPosCarga do with TPosCarga[xpos] do begin
               ActualizaCampoJSON(xpos, 'Volumen', volumen);
               ActualizaCampoJSON(xpos, 'Precio', precio);
               ActualizaCampoJSON(xpos, 'Importe', importe);
               
               xmodo:=xmodo+ModoOpera[1];
               if not SwDesHabilitado then begin
                 case estatus of
                   0:xestado:=xestado+'0'; // Sin Comunicacion
                   1:xestado:=xestado+'1'; // Inactivo (Idle)
                   2:xestado:=xestado+'2'; // Cargando (In Use)
                   3:xestado:=xestado+'3'; // Fin de Carga (Used)
                   5:xestado:=xestado+'5'; // Llamando (Calling) Pistola Levantada
                   9:xestado:=xestado+'9'; // Autorizado
                   8:xestado:=xestado+'8'; // Detenido (Stoped)
                   else xestado:=xestado+'0';
                 end;
               end
               else xestado:=xestado+'7'; // Deshabilitado
               ss:=inttoclavenum(xpos,2)+'/'+inttostr(xcomb);
               ss:=ss+'/'+FormatFloat('###0.##',volumen);
               ss:=ss+'/'+FormatFloat('#0.##',precio);
               ss:=ss+'/'+FormatFloat('####0.##',importe);
               lin:=lin+'#'+ss;
               //end;
             end;
             if lin='' then
               lin:=xestado+'#'
             else
               lin:=xestado+lin;
             lin:=lin+'&'+xmodo;
             LinEstadoGen:=xestado;
             // FIN

             NumPaso:=2;
             PosicionCargaActual:=0;
           except
             NumPaso:=2;
             PosicionCargaActual:=0;
           end;
         end;
     'A':begin // RECIBE LECTURA DE BOMBA
           try
             xpos:=StrToIntDef(copy(lin,2,2),0);
             if (xpos in [1..maxposcarga]) then begin
               ContEsperaPaso2:=0;
               with TPosCarga[xpos] do begin
                 Mensaje:='';
                 if lin[4]='0' then begin // POSICION ESTA CARGANDO
                   swinicio2:=false;
                   importeant:=importe;
                   simp:=copy(lin,14,8);
                   if digiImp=1 then
                     importe:=StrToFloat(simp)/100
                   else if digiImp=2 then
                     importe:=StrToFloat(simp)/1000
                   else
                     importe:=StrToFloat(simp)/10000;
                   volumen:=0;
                   precio:=0;
                   CombActual:=0;
                   PosActual:=0;
                   MangActual:=0;
                   MangAnterior:=0;
                   if not swAvanzoVenta then
                     swAvanzoVenta:=importe>0;
                 end
                 else if lin[4]='\' then begin // POSICION NO MAPEADA
                   for i:=1 to nocomb do
                     SwMapea[i]:=true;
                   Mensaje:='No Mapeada';
                 end
                 else begin // VENTA CONCLUIDA
                   xGrade:=lin[4];
                   AgregaLog('xGrade: '+xgrade);
                   PosActual:=0;
                   for i:=1 to MCxP do
                     if xGrade=IntToStr(TComb[i]) then
                       PosActual:=TPosx[i];
                   if (PosActual=0) then begin   // Perdio el mapeo
                     for i:=1 to nocomb do
                       SwMapea[i]:=true;
                   end
                   else begin
                     try
                       swinicio2:=false;
                       if digiVol=1 then
                         volumen:=StrToFloat(copy(lin,6,8))/100
                       else if digiVol=2 then
                         volumen:=StrToFloat(copy(lin,6,8))/1000
                       else if digiVol=3 then
                         volumen:=StrToFloat(copy(lin,6,8))/10000;
                       simp:=copy(lin,14,8);
                       spre:=copy(lin,22,5);

                       if digiPrec=1 then
                         precio:=StrToFloat(spre)/100
                       else if digiPrec=2 then
                         precio:=StrToFloat(spre)/1000
                       else if digiPrec=3 then
                         precio:=StrToFloat(spre)/10000;

                       if digiImp=1 then
                         importe:=StrToFloat(simp)/100
                       else if digiImp=2 then
                         importe:=StrToFloat(simp)/1000
                       else importe:=StrToFloat(simp)/10000;

                       if (2*volumen*precio<importe) then
                         importe:=importe/10;
                       if (2*importe<volumen*precio) then
                         importe:=importe*10;

                       if AjustePAM then begin
                         ximporte:=AjustaFloat(volumen*precio,2);
                         if abs(importe-ximporte)>=0.015 then
                           importe:=ximporte;
                       end;

                       if ValidaMang then begin
                         if (MangAnterior>0) and (MangAnterior=MangueraEnPosicion(xpos,PosActual)) then begin
                           MangActual:=MangueraEnPosicion(xpos,PosActual);
                           xcomb:=CombustibleEnPosicion(xpos,PosActual);
                           CombActual:=CombustibleEnPosicion(xpos,PosActual);
                         end
                         else begin
                           MangAnterior:=MangueraEnPosicion(xpos,PosActual);
                           importe:=0;
                           precio:=0;
                           volumen:=0;
                         end;
                       end
                       else begin
                         MangActual:=MangueraEnPosicion(xpos,PosActual);
                         xcomb:=CombustibleEnPosicion(xpos,PosActual);
                         CombActual:=CombustibleEnPosicion(xpos,PosActual);
                       end;

                       if (not swAvanzoVenta) and (SwCargando) then begin
                         swAvanzoVenta:=(importe<>importeant) and (SwCargando) and (importe>0) and ((importeant>0) or (importe-importeant<IfThen(xcomb=3,80,40)));
                         AgregaLog(ifthen(swAvanzoVenta,'swAvanzoVenta','NOT')+' Estatus='+IntToStr(Estatus)+' ImporteAnt: '+FloatToStr(importeant)+' Importe: '+FloatToStr(importe));
                       end;

                       if estatus<>2 then
                         SwCargando:=false;

                       if (swAvanzoVenta) and (Estatus in [1,3,5,9]) and (MangActual>0) then begin// EOT
                         swAvanzoVenta:=False;
                         swdesp:=true;
                         SwPidiendoTotales:=True;
                         SwTotales[PosActual]:=True;
                       end;
                       
                       importeant:=importe;

                       if LigaCombs<>'' then begin
                         if ExtraeElemStrSep(LigaCombs,1,':')=IntToStr(CombActual) then
                           CombActual:=StrToInt(ExtraeElemStrSep(LigaCombs,2,':'));
                       end;
                       
                       // JSON Updates
                       ActualizaCampoJSON(xpos, 'Volumen', volumen);
                       ActualizaCampoJSON(xpos, 'Precio', precio);
                       ActualizaCampoJSON(xpos, 'Importe', importe);
                       ActualizaCampoJSON(xpos, 'Combustible', CombActual);
                       ActualizaCampoJSON(xpos, 'Manguera', MangActual);
                       ActualizaCampoJSON(xpos, 'HoraOcc', FormatDateTime('yyyy-mm-dd',now)+'T'+FormatDateTime('hh:nn',now));

                       if (TPosCarga[xpos].finventa=0) then begin
                         if Estatus=3 then begin // EOTS
                           TPosCarga[xpos].finventa:=0;
  //                         ss:='R'+IntToClaveNum(xpos,2); // VENTA COMPLETA
  //                         ComandoConsola(ss);
  //                         EsperaMiliSeg(100);
                         end;
                       end;
                     except
                     end;
                   end;
                 end;
               end;
             end;
           except
             AgregaLog('ERROR EN COMANDO A');
           end
         end;
     '@':begin // RECIBE TOTAL DE LA POSICION
           try
             xpos:=StrToIntDef(copy(lin,5,2),0);
             if (xpos in [1..maxposcarga]) then begin
               with TPosCarga[xpos] do begin
                 xgrade:=lin[8];
                 for i:=1 to nocomb do if IntToStr(TComb[i])=xgrade then begin
                   SwTotales[i]:=false;
                   TotalLitros[i]:=StrToFloat(copy(lin,9,10))/100;
                 end;
                 if nocomb=1 then begin
                   for i:=1 to 4 do
                     SwTotales[i]:=false;
                 end
                 else if nocomb>=2 then begin
                   xgrade:=lin[37];
                   for i:=1 to nocomb do if IntToStr(TComb[i])=xgrade then begin
                     SwTotales[i]:=false;
                     TotalLitros[i]:=StrToFloat(copy(lin,38,10))/100;
                   end;
                   if nocomb>=3 then begin
                     xgrade:=lin[66];
                     for i:=1 to nocomb do if IntToStr(TComb[i])=xgrade then begin
                       SwTotales[i]:=false;
                       TotalLitros[i]:=StrToFloat(copy(lin,67,10))/100;
                     end;
                     if nocomb=4 then begin
                       xgrade:=lin[95];
                       for i:=1 to nocomb do if IntToStr(TComb[i])=xgrade then begin
                         SwTotales[i]:=false;
                         TotalLitros[i]:=StrToFloat(copy(lin,96,10))/100;
                       end;
                     end;
                   end;
                 end;
               end;
             end;
           except
             AgregaLog('ERROR EN COMANDO @');
           end
         end;
     'C':begin // RECIBE TOTAL DE UNA PISTOLA
           try
             xpos:=StrToIntDef(copy(lin,2,2),0);
             if (xpos in [1..maxposcarga]) then begin
               xgrade:=lin[4];
               with TPosCarga[xpos] do begin
                 for i:=1 to nocomb do if IntToStr(TComb[i])=xgrade then begin
                   SwTotales[i]:=false;
                   TotalLitros[i]:=StrToFloat(copy(lin,6,10))/100;
                 end;
               end;
             end;
           except
             AgregaLog('ERROR EN COMANDO C');
           end
         end;
   idAck:if NumPaso=1 then begin
           if xPosT in [1..MaxPosCargaActiva] then
             TPosCarga[xPosT].swnivelprec:=true;
         end
         else if NumPaso=5 then
           ContEsperaPaso5:=0;
   idNak:if NumPaso=4 then  // ERROR EN CAMBIO DE PRECIOS
           ContEsperaPaso4:=0
         else if NumPaso=5 then
           ContEsperaPaso5:=0;
    end;

    if (ListaCmnd.Count>0)and(not SwEsperaRsp) then begin
      ss:=ListaCmnd[0];
      ListaCmnd.Delete(0);
      ComandoConsola(ss);
      exit;
    end;  

    // checa lecturas de dispensarios
    if NumPaso=2 then begin
      try
        if PosicionCargaActual<MaxPosCargaActiva then begin
          repeat
            Inc(PosicionCargaActual);
            with TPosCarga[PosicionCargaActual] do if NoComb>0 then begin
              if (estatus<>estatusant)or(estatus>1) or (((SwA)or(swinicio2))and(estatus>0)) then begin //CAMBIO
                if (estatus in [1,2,3,8]) then begin
                  SwA:=false;
                  ComandoConsolaBuff('A'+IntToClaveNum(PosicionCargaActual,2));
                  exit;
                end;
              end;
            end;
          until (PosicionCargaActual>=MaxPosCargaActiva);
          if not SwEsperaRsp then begin
            NumPaso:=3;
            PosicionCargaActual:=0;
          end;
        end
        else if not SwEsperaRsp then begin
          NumPaso:=3;
          PosicionCargaActual:=0;
        end;
      except
        AgregaLog('ERROR PASO 2');
        NumPaso:=3;
        PosicionCargaActual:=0;
      end;
    end;
    // Lee Totales
    if NumPaso=3 then begin // TOTALES
      try
        if PosicionCargaActual<=MaxPosCarga then begin
          PosicionDispenActual:=0;
          repeat
            if PosicionDispenActual=0 then begin
              PosicionCargaActual:=1;
              PosicionDispenActual:=1;
            end
            else if PosicionDispenActual<TPosCarga[PosicionCargaActual].NoComb then
              inc(PosicionDispenActual)
            else begin
              Inc(PosicionCargaActual);
              PosicionDispenActual:=1;
            end;
            if PosicionCargaActual<=MaxPosCarga then begin
              if PosicionCargaActual<1 then
                PosicionCargaActual:=1;
              with TPosCarga[PosicionCargaActual] do begin
                if (estatus in [1,3]) and (swtotales[PosicionDispenActual]) then begin
                  if VersionPam1000='3' then
                    ComandoConsolaBuff('@10'+'0'+IntToClaveNum(PosicionCargaActual,2))
                  else
                    ComandoConsolaBuff('C'+IntToClaveNum(PosicionCargaActual,2)+IntToStr(TComb[PosicionDispenActual])+'1');
                  exit;
                end;
              end;
            end
            else if not SwEsperaRsp then begin
              NumPaso:=4;
              PrecioCombActual:=0;
            end;
          until (PosicionCargaActual>MaxPosCarga);
          if not SwEsperaRsp then begin
            NumPaso:=4;
            PrecioCombActual:=0;
          end;
        end
        else if not SwEsperaRsp then begin
          NumPaso:=4;
          PrecioCombActual:=0;
        end;
      except
        AgregaLog('ERROR PASO 3');
        NumPaso:=4;
        PrecioCombActual:=0;
      end;
    end;

    if (NumPaso=4) then begin
      try
        // Checa Comandos
        for xcmnd:=1 to 200 do if (TabCmnd[xcmnd].SwActivo)and(not TabCmnd[xcmnd].SwResp) then begin
          SwAplicaCmnd:=true;
          ss:=ExtraeElemStrSep(TabCmnd[xcmnd].Comando,1,' ');
          AgregaLog(TabCmnd[xcmnd].Comando);
          // CMND: PARO TOTAL
          if ss='PAROTOTAL' then begin
            rsp:='OK';
            ComandoConsolaBuff('E00');
          end
          // CMND: RESET PAM
          else if ss='RESET' then begin
            rsp:='OK';
          end
          // ORDENA CARGA DE COMBUSTIBLE
          else if ss='OCC' then begin
            SnPosCarga:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,2,' '),0);
            xpos:=SnPosCarga;
            rsp:='OK';
            if (SnPosCarga in [1..MaxPosCarga]) then begin
              if (TPosCarga[SnPosCarga].estatus in [1,5])or(TPosCarga[SnPosCarga].SwOCC) then begin
                if not TPosCarga[SnPosCarga].swautorizando then begin
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
                      SnImporteStr:=ExtraeElemStrSep(TabCmnd[xcmnd].Comando,3,' ');
                      decImporteStr:=ExtraeElemStrSep(SnImporteStr,2,'.');
                      if (Length(decImporteStr)=5) then
                        SnImporte:=StrToFloat(copy(SnImporteStr,1,length(SnImporteStr)-3))
                      else
                        SnImporte:=StrToFLoat(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,3,' '));
                      SnLitros:=0;
                      if SnImporte>9999 then
                        SnImporte:=0;
                      if SnImporte<>0 then begin
                        if VersionPam1000='3' then
                          rsp:=ValidaCifra(SnImporte,4,2)
                        else
                          rsp:=ValidaCifra(SnImporte,3,2);
                      end;
                    except
                      rsp:='Error en Importe';
                    end;
                    if rsp='OK' then begin
                      if (TPosCarga[SnPosCarga].estatus in [1,5,9]) then begin
                        ss:=ExtraeElemStrSep(TabCmnd[xcmnd].Comando,4,' ');
                        xcomb:=StrToIntDef(ss,0);
                        if TPosCarga[SnPosCarga].NoComb=2 then
                          if (TPosCarga[SnPosCarga].TComb[1]+TPosCarga[SnPosCarga].TComb[2]=5) then
                            xcomb:=0;
                        xp:=PosicionDeCombustible(xpos,xcomb);
                        if xp>0 then begin
                          TPosCarga[SnPosCarga].finventa:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,5,' '),0);
                          if VersionPam1000='3' then
                            EnviaPreset3(rsp,xcomb)
                          else
                            EnviaPreset(rsp,xcomb);
                        end
                        else rsp:='Combustible no existe en esta posicion';
                      end
                      else begin
                        rsp:='Posicion de Carga no Disponible';
                      end;
                    end;
                  end;
                  if (not SwAplicaCmnd)and(rsp<>'OK') then
                     SwAplicaCmnd:=true;
                end
                else swaplicacmnd:=false;
              end
              else rsp:='Posicion de Carga no Disponible';
              if SwAplicaCmnd then
                TPosCarga[SnPosCarga].SwOCC:=false;
            end
            else rsp:='Posicion de Carga no Existe';
          end
          else if ss='OCL' then begin
            SnPosCarga:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,2,' '),0);
            xpos:=SnPosCarga;
            rsp:='OK';
            if (SnPosCarga in [1..MaxPosCarga]) then begin
              if (TPosCarga[SnPosCarga].estatus in [1,5])or(TPosCarga[SnPosCarga].SwOCC) then begin
                if not TPosCarga[SnPosCarga].swautorizando then begin
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
                      if VersionPam1000='3' then
                        rsp:=ValidaCifra(SnLitros,4,2)
                      else
                        rsp:=ValidaCifra(SnLitros,3,2);
                      if rsp='OK' then
                        if (SnLitros<0.10) then
                          rsp:='Minimo permitido: 0.10 lts'
                    except
                      rsp:='Error en Litros';
                    end;
                    if rsp='OK' then begin
                      if (TPosCarga[SnPosCarga].estatus in [1,5,9]) then begin
                        ss:=ExtraeElemStrSep(TabCmnd[xcmnd].Comando,4,' ');
                        xcomb:=StrToIntDef(ss,0);
                        if TPosCarga[SnPosCarga].NoComb=2 then
                          if (TPosCarga[SnPosCarga].TComb[1]+TPosCarga[SnPosCarga].TComb[2]=5) then
                            xcomb:=0;
                        xp:=PosicionDeCombustible(xpos,xcomb);
                        if xp>0 then begin
                          TPosCarga[SnPosCarga].finventa:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,5,' '),0);
                          if VersionPam1000='3' then
                            EnviaPreset3(rsp,xcomb)
                          else
                            EnviaPreset(rsp,xcomb);
                        end
                        else rsp:='Combustible no existe en esta posicion';
                      end
                      else begin
                        rsp:='Posicion de Carga no Disponible';
                      end;
                    end;
                  end;
                  if (not SwAplicaCmnd)and(rsp<>'OK') then
                     SwAplicaCmnd:=true;
                end
                else swaplicacmnd:=false;
              end
              else rsp:='Posicion de Carga no Disponible';
              if SwAplicaCmnd then
                TPosCarga[SnPosCarga].SwOCC:=false;
            end
            else rsp:='Posicion de Carga no Existe';
          end
          // ORDENA FIN DE VENTA
          else if ss='FINV' then begin
            xpos:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,2,' '),0);
            rsp:='OK';
            if (xpos in [1..MaxPosCarga]) then begin
              TPosCarga[xpos].tipopago:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,3,' '),0);
              if (TPosCarga[xpos].Estatus=3) then begin // EOT
                if (not TPosCarga[xpos].swcargando) then begin
                  TPosCarga[xpos].finventa:=0;
                  ss:='R'+IntToClaveNum(xpos,2); // VENTA COMPLETA
                  ComandoConsolaBuff(ss);
                end
                else begin
                  if (TPosCarga[xpos].swcargando)and(TPosCarga[xpos].Estatus=1) then begin
                    TPosCarga[xpos].swcargando:=false;
                    rsp:='OK';
                  end
                  else rsp:='Posicion no esta despachando';
                end;
              end
              else begin // EOT
                rsp:='Posicion aun no esta en fin de venta';
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
          // CMND: DESAUTORIZA VENTA DE COMBUSTIBLE
          else if (ss='DVC')or(ss='PARAR') then begin
            rsp:='OK';
            xpos:=strtointdef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,2,' '),0);
            if xpos in [1..MaxPosCarga] then begin
              if (TPosCarga[xpos].estatus in [2,9]) then begin
                ComandoConsolaBuff('E'+IntToClaveNum(xpos,2));
                if ReautorizaPam='Si' then begin
                  TPosCarga[xpos].CmndOcc:='';
                  TPosCarga[xpos].HoraOcc:=now-1000*tmsegundo;
                end;
                if TPosCarga[xpos].estatus=9 then
                  TPosCarga[xpos].tipopago:=0;
              end;
            end;
          end
          else if (ss='REANUDAR') then begin
            rsp:='OK';
            xpos:=strtointdef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,2,' '),0);
            if xpos in [1..MaxPosCarga] then begin
              if (TPosCarga[xpos].estatus in [2,8]) then begin
                ComandoConsolaBuff('G'+IntToClaveNum(xpos,2));
              end;
            end;
          end
          else if (ss='TOTAL') then begin
            rsp:='OK';
            xpos:=strtointdef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,2,' '),0);
            SwAplicaCmnd:=False;
            with TPosCarga[xpos] do begin
              if (TabCmnd[xcmnd].SwNuevo) and (not SwPidiendoTotales) and (SecondsBetween(Now,HoraTotales)>10) then begin
                AgregaLog('TOTALES EN TODAS LAS MANGUERAS');
                SwTotales[1]:=true;
                SwTotales[2]:=true;
                SwTotales[3]:=true;
                SwTotales[4]:=true;
              end
              else begin
                for i:=1 to nocomb do begin
                  swAllTotals:=True;
                  if SwTotales[i] then begin
                    swAllTotals:=False;
                    Break;
                  end;
                end;

                if (SwPidiendoTotales) and (SwTotales[PosActual]) and (SwDesp) and (SecondsBetween(Now,TabCmnd[xcmnd].hora)>=3) and (not swAllTotals) then begin
                  ToTalLitros[PosActual]:=ToTalLitros[PosActual]+volumen;
                  SwTotales[PosActual]:=False;
                  swAllTotals:=True;
                  SwDesp:=False;
                end;

                if swAllTotals then begin
                  rsp:='OK'+FormatFloat('0.000',ToTalLitros[1])+'|'+FormatoMoneda(ToTalLitros[1]*LPrecios[TCombx[1]])+'|'+
                                  FormatFloat('0.000',ToTalLitros[2])+'|'+FormatoMoneda(ToTalLitros[2]*LPrecios[TCombx[2]])+'|'+
                                  FormatFloat('0.000',ToTalLitros[3])+'|'+FormatoMoneda(ToTalLitros[3]*LPrecios[TCombx[3]])+'|';
                  HoraTotales:=Now;
                  SwAplicaCmnd:=True;
                end;
              end;
            end;
          end
          else if (ss='CPREC') then begin
            precios:=ExtraeElemStrSep(TabCmnd[xcmnd].Comando,2,' ');
            for i:=1 to NoElemStrSep(precios,'|') do begin
              precioComb:=StrToFloatDef(ExtraeElemStrSep(precios,i,'|'),-1);
              if precioComb<=0 then
                Continue;
              LPrecios[i]:=precioComb;
              if ValidaCifra(precioComb,2,2)='OK' then begin
                if precioComb>=0.01 then begin
                  ComandoConsolaBuff('X'+'00'+IntToStr(i)+'1'+'00'+IntToClaveNum(Trunc(precioComb*100+0.5),4)); // contado
                  ComandoConsolaBuff('X'+'00'+IntToStr(i)+'2'+'00'+IntToClaveNum(Trunc(precioComb*100+0.5),4)); // credito
                  if LigaCombs<>'' then begin
                    if i=StrToIntDef(ExtraeElemStrSep(LigaCombs,2,':'),0) then begin
                      combx:=StrToInt(ExtraeElemStrSep(LigaCombs,1,':'));
                      ComandoConsolaBuff('X'+'00'+IntToStr(combx)+'1'+'00'+IntToClaveNum(Trunc(precioComb*100+0.5),4)); // contado
                      ComandoConsolaBuff('X'+'00'+IntToStr(combx)+'2'+'00'+IntToClaveNum(Trunc(precioComb*100+0.5),4)); // credito
                    end;
                  end;
                end;
              end;
            end;
          end;
          TabCmnd[xcmnd].SwNuevo:=false;
          if SwAplicaCmnd then begin
            if rsp='' then
              rsp:='OK';
            TabCmnd[xcmnd].SwResp:=true;
            TabCmnd[xcmnd].Respuesta:=rsp;
            AgregaLog(LlenaStr(TabCmnd[xcmnd].Comando,'I',40,' ')+' Respuesta: '+TabCmnd[xcmnd].Respuesta);
          end;
        end;
        if not SwEsperaRsp then
          NumPaso:=0;
      except
        AgregaLog('ERROR PASO 5');
        NumPaso:=0;
      end;
    end;
  finally
    // Ensure we trigger socket response if on proper cycle
    try
      if xTurnoSocket=3 then
        Responder(TlkJSON.GenerateText(rootJSON));
    except
      on e:Exception do begin
        AgregaLog('Excepcion Timer1Timer Socket: '+e.Message);
        Timer1.Enabled:=False;
        Timer2.Enabled:=True;
      end;
    end;
  end;
end;

procedure Togcvdispensarios_pam.EnviaPreset(var rsp:string;xcomb:integer);
var xpos,xp:integer;
    ss,NivelPrec:string;
    swlitros:boolean;
begin
  swlitros:=SnLitros>0.01;
  rsp:='OK';
  xpos:=SnPosCarga;
  if TPosCarga[xpos].SwDesHabilitado then begin
    rsp:='Posicion Bloqueada';
    exit;
  end;
  if not (TPosCarga[xpos].estatus in [1,5,9]) then begin
    rsp:='Posicion no Disponible';
    exit;
  end;
  if TPosCarga[xpos].estatus=9 then begin
    ComandoConsolaBuff('E'+IntToClaveNum(xpos,2));
    if ReautorizaPam='Si' then begin
      TPosCarga[xpos].CmndOcc:='';
      TPosCarga[xpos].HoraOcc:=now-1000*tmsegundo;
    end;
  end;
  NivelPrec:='1';
  if not swlitros then begin // PRESET IMPORTE
    if (snimporte=0) then begin
      ss:='S'+IntToClaveNum(xpos,2);
      TPosCarga[xpos].ImportePreset:=999;
      TPosCarga[xpos].MontoPreset:='$ '+FormatoMoneda(999);
    end
    else begin
      ss:='P'+IntToClaveNum(xpos,2)+'0'+NivelPrec+'000'+FiltraStrNum(FormatFloat('000.00',snimporte))+'0';
      TPosCarga[xpos].ImportePreset:=SnImporte;
      TPosCarga[xpos].MontoPreset:='$ '+FormatoMoneda(SnImporte);
    end;
  end
  else begin // PRESET LITROS
    for xp:=1 to 4 do
      if CombustibleEnPosicion(xpos,xp)=xcomb then
        ss:='P'+IntToClaveNum(xpos,2)+'1'+NivelPrec+'00'+FiltraStrNum(FormatFloat('000.00',snlitros))+'0'+inttostr(xp);
    TPosCarga[xpos].ImportePreset:=SnLitros;
    TPosCarga[xpos].MontoPreset:=FormatoMoneda(SnLitros)+' lts';
  end;
  ComandoConsolaBuff(ss);
  if ReautorizaPam='Si' then begin
    TPosCarga[xpos].CmndOcc:=ss;
    TPosCarga[xpos].HoraOcc:=now;
  end;
  TPosCarga[xpos].SwPreset:=true;
  TPosCarga[xpos].ImportePreset:=SnImporte;
end;

procedure Togcvdispensarios_pam.EnviaPreset3(var rsp:string;xcomb:integer);
var xpos,xc,xp:integer;
    ss,xprodauto,NivelPrec:string;
    swlitros:boolean;
begin
  swlitros:=SnLitros>0.01;
  rsp:='OK';
  xpos:=SnPosCarga;
  if TPosCarga[xpos].SwDesHabilitado then begin
    rsp:='Posicion Deshabilitada';
    exit;
  end;
  if not (TPosCarga[xpos].estatus in [1,5,9]) then begin
    rsp:='Posicion no Disponible';
    exit;
  end;
  if TPosCarga[xpos].estatus=9 then begin
    ComandoConsolaBuff('E'+IntToClaveNum(xpos,2));
    if ReautorizaPam='Si' then begin
      TPosCarga[xpos].CmndOcc:='';
      TPosCarga[xpos].HoraOcc:=now-1000*tmsegundo;
    end;
  end;
  NivelPrec:='1';
  xprodauto:='000000';
  with TPosCarga[xpos] do begin
    for xc:=1 to NoComb do if xc in [1..4] then begin
      xp:=TPosx[xc];
      if xcomb>0 then begin // un producto
        if TComb[xc]=xcomb then
          if xp in [1..6] then
            xprodauto[xp]:='1';
      end
      else xprodauto[xp]:='1';
    end;
  end;
  if not swlitros then begin // PRESET EN IMPORTE
    if (snimporte=0) then begin
      ss:='S'+IntToClaveNum(xpos,2);
      TPosCarga[xpos].ImportePreset:=999;
      TPosCarga[xpos].MontoPreset:='$ '+FormatoMoneda(999);
    end
    else begin
      ss:='@02'+'0'+IntToClaveNum(xpos,2)+'0'+NivelPrec+FiltraStrNum(FormatFloat('0000.00',snimporte))+xprodauto;
      TPosCarga[xpos].ImportePreset:=SnImporte;
      TPosCarga[xpos].MontoPreset:='$ '+FormatoMoneda(SnImporte);
    end;
  end
  else begin // PRESET EN LITROS
    ss:='@02'+'0'+IntToClaveNum(xpos,2)+'1'+NivelPrec+FiltraStrNum(FormatFloat('0000.00',snlitros))+xprodauto;
    TPosCarga[xpos].ImportePreset:=SnLitros;
    TPosCarga[xpos].MontoPreset:=FormatoMoneda(SnLitros)+' lts';
  end;
  ComandoConsolaBuff(ss);
  if ReautorizaPam='Si' then begin
    TPosCarga[xpos].CmndOcc:=ss;
    TPosCarga[xpos].HoraOcc:=now;
  end;
  if SwError then begin
    rsp:='Error al Activar Posicion de Carga';
    exit;
  end;
  TPosCarga[xpos].SwPreset:=true;
  if not swlitros then
    AgregaLog('Importe Preset: '+Floattostr(SnImporte));
end;

function Togcvdispensarios_pam.CombustibleEnPosicion(xpos,xposcarga:integer):integer;
var i:integer;
begin
  with TPosCarga[xpos] do begin
    result:=0;
    for i:=1 to NoComb do begin
      if TPosx[i]=xposcarga then
        result:=TComb[i];
    end;
  end;
end;

function Togcvdispensarios_pam.MangueraEnPosicion(xpos,xposcarga:integer):integer;
var i:integer;
begin
  with TPosCarga[xpos] do begin
    result:=0;
    for i:=1 to NoComb do begin
      if TPosx[i]=xposcarga then
        result:=TMang[i];
    end;
  end;
end;

function Togcvdispensarios_pam.ValidaCifra(xvalor:real;xenteros,xdecimales:byte):string;
var xmax,xaux:real;
    i:integer;
begin
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
end;

function Togcvdispensarios_pam.PosicionDeCombustible(xpos,xcomb:integer):integer;
var i:integer;
begin
  with TPosCarga[xpos] do begin
    result:=0;
    if xcomb>0 then begin
      for i:=1 to NoComb do begin
        if TCombx[i]=xcomb then
          result:=TPosx[i];
      end;
    end
    else result:=99;
  end;
end;

function Togcvdispensarios_pam.AgregaPosCarga(posiciones: TlkJSONbase): string;
var
  i,j,k,xpos,xcomb,conPosicion:integer;
  existe:boolean;
  mangueras:TlkJSONbase;
  
  posArr  : TlkJSONlist;
  posObj      : TlkJSONObject;
  hosesArr    : TlkJSONlist;
  hoseObj     : TlkJSONObject;
begin
  try
    if not detenido then begin
      Result:='False|Es necesario detener el proceso antes de inicializar las posiciones de carga|';
      Exit;
    end;

    MaxPosCarga:=0;
    for i:=1 to 32 do with TPosCarga[i] do begin
      estatus:=-1;
      estatusant:=-1;
      NoComb:=0;
      SwInicio:=true;
      SwInicio2:=true;
      SwPreset:=false;
      Mensaje:='';
      importe:=0;
      volumen:=0;
      precio:=0;
      tipopago:=0;
      finventa:=0;
      Swnivelprec:=SwMapOff;
      SwCargando:=false;
      SwAutorizada:=false;
      SwAutorizando:=false;
      SwPidiendoTotales:=False;
      for j:=1 to MCxP do begin
        TotalLitros[j]:=0;
        swmapea[j]:=false;
        TMapa[j]:='';
      end;
      SwActivo:=false;
      SwDeshabilitado:=false;
      //SwArosMag:=false;
      //SwArosMag_stop:=false;
      SwOCC:=false;
      ContOcc:=0;
      HoraTotales:=0;
    end;

    // Build the initial JSON structure for state reporting
    posArr := TlkJSONlist.Create;

    for i:=0 to posiciones.Count-1 do begin
      xpos:=posiciones.Child[i].Field['DispenserId'].Value;
      if xpos>MaxPosCarga then
        MaxPosCarga:=xpos;
      with TPosCarga[xpos] do begin
        SwDesp:=false;
        SwA:=false;
        swprec:=false;
        existe:=false;
        ModoOpera:='Prepago';

        // Create JSON node for this dispenser
        posObj := TlkJSONObject.Create;
        posObj.Add('DispenserId', xpos);
        posObj.Add('HoraOcc', FormatDateTime('yyyy-mm-dd',HoraOcc)+'T'+FormatDateTime('hh:nn',HoraOcc));
        posObj.Add('Manguera', 0);
        posObj.Add('Combustible', 0);
        posObj.Add('Estatus', 0);
        posObj.Add('Importe', 0);
        posObj.Add('Volumen', 0);
        posObj.Add('Precio', 0);
        hosesArr := TlkJSONlist.Create;

        mangueras:=posiciones.Child[i].Field['Hoses'];
        for j:=0 to mangueras.Count-1 do begin
          conPosicion:=mangueras.Child[j].Field['HoseId'].Value;
          if MapCombs<>'' then
            xcomb:=StrToInt(ExtraeElemStrSep(ExtraeElemStrSep(MapCombs,xpos,';'),conPosicion,','))
          else
            xcomb:=mangueras.Child[j].Field['ProductId'].Value;

          for k:=1 to NoComb do
            if TComb[k]=xcomb then
              existe:=true;

          if not existe then begin
            inc(NoComb);
            TComb[NoComb]:=xcomb;
            TCombx[NoComb]:=mangueras.Child[j].Field['ProductId'].Value;
            TMang[NoComb]:=conPosicion;
            if conPosicion>0 then
              TPosx[NoComb]:=conPosicion
            else if NoComb<=2 then
              TPosx[NoComb]:=NoComb
            else
              TPosx[NoComb]:=1;
            TMapa[NoComb]:='X'+IntToClaveNum(xpos,2)+IntToStr(xcomb)+IntToStr(conPosicion);
            SwMapea[NoComb]:=not SwMapOff;
            SwTotales[NoComb]:=true;
            
            // Add Hose to JSON
            hoseObj := TlkJSONObject.Create;
            hoseObj.Add('HoseId',TMang[NoComb]);
            hoseObj.Add('ProductId', xcomb);
            hoseObj.Add('Total', 0);
            hosesArr.Add(hoseObj);
          end;
        end;
        posObj.Add('Hoses', hosesArr);
        posArr.Add(posObj);
      end;
    end;
    TlkJSONobject(rootJSON).Add('PosCarga', posArr);
    
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

procedure Togcvdispensarios_pam.IniciaPrecios(folio:Integer; msj: string);
begin
  try
    if EjecutaComando('CPREC '+msj)>0 then
      AddPeticionJSON(folio, 'True|')
    else
      AddPeticionJSON(folio, 'False|No fue posible aplicar comando de cambio de precios|');
  except
    on e:Exception do
      AddPeticionJSON(folio, 'False|Excepcion: '+e.Message+'|');
  end;
end;

function Togcvdispensarios_pam.EjecutaComando(xCmnd:string):integer;
var ind:integer;
begin
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
end;

procedure Togcvdispensarios_pam.AutorizarVenta(folio:Integer; msj: string);
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
      AddPeticionJSON(folio, 'False|Favor de indicar la cantidad que se va a despachar|');
      Exit;
    end;

    posCarga:=ExtraeElemStrSep(msj,1,'|');

    if posCarga='' then begin
      AddPeticionJSON(folio, 'False|Favor de indicar la posicion de carga|');
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

    AddPeticionJSON(folio, 'True|'+IntToStr(EjecutaComando(cmd+' '+posCarga+' '+cantidad+' '+comb+' '+finv))+'|');
  except
    on e:Exception do
      AddPeticionJSON(folio, 'False|Excepcion: '+e.Message+'|');
  end;
end;

procedure Togcvdispensarios_pam.DetenerVenta(folio:Integer; msj: string);
begin
  try
    if StrToIntDef(msj,-1)=-1 then begin
      AddPeticionJSON(folio, 'False|Favor de indicar correctamente la posicion de carga|');
      Exit;
    end;

    AddPeticionJSON(folio, 'True|'+IntToStr(EjecutaComando('DVC '+msj))+'|');
  except
    on e:Exception do
      AddPeticionJSON(folio, 'False|Excepcion: '+e.Message+'|');
  end;
end;

procedure Togcvdispensarios_pam.ReanudarVenta(folio:Integer; msj: string);
begin
  try
    if StrToIntDef(msj,-1)=-1 then begin
      AddPeticionJSON(folio, 'False|Favor de indicar correctamente la posicion de carga|');
      Exit;
    end;

    AddPeticionJSON(folio, 'True|'+IntToStr(EjecutaComando('REANUDAR '+msj))+'|');
  except
    on e:Exception do
      AddPeticionJSON(folio, 'False|Excepcion: '+e.Message+'|');
  end;
end;

procedure Togcvdispensarios_pam.ActivaModoPrepago(folio:Integer; msj: string);
var
  xpos:Integer;
begin
  try
    xpos:=StrToIntDef(msj,-1);
    if xpos=-1 then begin
      AddPeticionJSON(folio, 'False|Favor de indicar correctamente la posicion de carga|');
      Exit;
    end;

    if xpos=0 then begin
      for xpos:=1 to MaxPosCarga do
        TPosCarga[xpos].ModoOpera:='Prepago';
    end
    else if (xpos in [1..maxposcarga]) then
      TPosCarga[xpos].ModoOpera:='Prepago';

    AddPeticionJSON(folio, 'True|');
  except
    on e:Exception do
      AddPeticionJSON(folio, 'False|Excepcion: '+e.Message+'|');
  end;
end;

procedure Togcvdispensarios_pam.DesactivaModoPrepago(folio:Integer; msj: string);
var
  xpos:Integer;
begin
  try
    xpos:=StrToIntDef(msj,-1);
    if xpos=-1 then begin
      AddPeticionJSON(folio, 'False|Favor de indicar correctamente la posicion de carga|');
      Exit;
    end;

    if xpos=0 then begin
      for xpos:=1 to MaxPosCarga do
        TPosCarga[xpos].ModoOpera:='Prepago';
    end
    else if (xpos in [1..maxposcarga]) then
      TPosCarga[xpos].ModoOpera:='Prepago';

    AddPeticionJSON(folio, 'True|');
  except
    on e:Exception do
      AddPeticionJSON(folio, 'False|Excepcion: '+e.Message+'|');
  end;
end;

procedure Togcvdispensarios_pam.Timer1Timer(Sender: TObject);
var ss:string;
//    i:integer;
begin
  try
    if NumPaso>4 then
      NumPaso:=0;  
    if NumPaso>1 then begin
      if NumPaso=2 then begin // si esta en espera de respuesta ACK
        inc(ContEsperaPaso2);     // espera hasta 5 ciclos
        if ContEsperaPaso2>MaxEspera2 then begin
          ContEsperaPaso2:=0;
          LineaTimer:='.A00..';  // de lo contrario provoca un NAK para que continue
          ProcesaLinea;       // el proceso con la siguiente solicitud
        end;
      end;
      if NumPaso=3 then begin // si esta en espera de respuesta ACK
        inc(ContEsperaPaso3);     // espera hasta 5 ciclos
        if ContEsperaPaso3>MaxEspera3 then begin
          ContEsperaPaso3:=0;
          LineaTimer:='.N00..';  // de lo contrario provoca un NAK para que continue
          ProcesaLinea;       // el proceso con la siguiente solicitud
        end;
      end;
      if NumPaso=4 then begin // si esta en espera de respuesta ACK
        inc(ContEsperaPaso4);     // espera hasta 5 ciclos
        if ContEsperaPaso4>3 then begin
          ContEsperaPaso4:=0;
          LineaTimer:=idNak;  // de lo contrario provoca un NAK para que continue
          ProcesaLinea;       // el proceso con la siguiente solicitud
        end;
      end;
      if NumPaso=5 then begin
        inc(ContEsperaPaso5);     // espera hasta 5 ciclos
        if ContEsperaPaso5>10 then begin
          ContEsperaPaso5:=0;
          LineaTimer:=idNak;  // de lo contrario provoca un NAK para que continue
          ProcesaLinea;       // el proceso con la siguiente solicitud
        end;
      end;
      exit;
    end;

    // Espera en el paso 0 hasta que reciba respuesta
    if NumPaso=1 then begin
      inc(ContEspera1);
      if ContEspera1>10 then
        SwEsperaRsp:=False
      else
        exit;
    end;

    NumPaso:=1;
    ss:='B00';

    ContEspera1:=0;
    ComandoConsolaBuff(ss);
  except
    AgregaLog('ERROR TIMER1');
  end;
end;

procedure Togcvdispensarios_pam.FinVenta(folio:Integer; msj: string);
begin
  try
    if StrToIntDef(msj,-1)=-1 then begin
      AddPeticionJSON(folio, 'False|Favor de indicar correctamente la posicion de carga|');
      Exit;
    end;

    AddPeticionJSON(folio, 'True|'+IntToStr(EjecutaComando('FINV '+msj))+'|');
  except
    on e:Exception do
      AddPeticionJSON(folio, 'False|Excepcion: '+e.Message+'|');
  end;
end;

function Togcvdispensarios_pam.TransaccionPosCarga(msj: string): string;
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

function Togcvdispensarios_pam.EstadoPosiciones(msj: string): string;
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

procedure Togcvdispensarios_pam.TotalesBomba(folio:Integer; msj: string);
var
  xpos,xfolioCmnd:Integer;
  valor:string;
begin
  try
    xpos:=StrToIntDef(msj,-1);
    if xpos<1 then begin
      AddPeticionJSON(folio, 'False|Favor de indicar correctamente la posicion de carga|');
      Exit;
    end;

    xfolioCmnd:=EjecutaComando('TOTAL'+' '+IntToStr(xpos));

    valor:=IfThen(xfolioCmnd>0, 'True', 'False');

    AddPeticionJSON(folio, valor+'|0|0|0|0|0|0|'+IntToStr(xfolioCmnd)+'|');
  except
    on e:Exception do
      AddPeticionJSON(folio, 'False|Excepcion: '+e.Message+'|');
  end;
end;

procedure Togcvdispensarios_pam.Detener(folio:Integer);
begin
  try
    if estado=-1 then begin
      AddPeticionJSON(folio, 'False|El proceso no se ha iniciado aun|');
      Exit;
    end;

    if not detenido then begin
      pSerial.Open:=False;
      Timer1.Enabled:=False;
      Timer2.Enabled:=True;
      detenido:=True;
      estado:=0;
      SetEstadoJSON(estado);
      AddPeticionJSON(folio, 'True|');
    end
    else
      AddPeticionJSON(folio, 'False|El proceso ya habia sido detenido|');
  except
    on e:Exception do begin
      AgregaLog('Error Detener: '+e.Message);
      GuardarLog(0);
      AddPeticionJSON(folio, 'False|'+e.Message+'|');
    end;
  end;
end;

procedure Togcvdispensarios_pam.Iniciar(folio:Integer);
begin
  try
    if (not pSerial.Open) then begin
      if (estado=-1) then begin
        AddPeticionJSON(folio, 'False|No se han recibido los parametros de inicializacion|');
        Exit;
      end
      else if detenido then
        pSerial.Open:=True;
    end;

    detenido:=False;
    estado:=1;
    Timer1.Enabled:=True;
    Timer2.Enabled:=False;
    numPaso:=0;
    SetEstadoJSON(estado);
    
    AddPeticionJSON(folio, 'True|');
  except
    on e:Exception do begin
      AgregaLog('Error Iniciar: '+e.Message);
      AddPeticionJSON(folio, 'False|'+e.Message+'|');
    end;
  end;
end;

procedure Togcvdispensarios_pam.Shutdown(folio:Integer);
begin
  if estado>0 then
    AddPeticionJSON(folio, 'False|El servicio esta en proceso, no fue posible detenerlo|')
  else begin
    AddPeticionJSON(folio, 'True|');
    ServiceThread.Terminate;
  end;
end;

function Togcvdispensarios_pam.ObtenerEstado: string;
begin
  Result:='True|'+IntToStr(estado)+'|';
end;

procedure Togcvdispensarios_pam.GuardarLog(folio:Integer);
begin
  try
    AgregaLog('Version: '+version);
    ListaLog.SaveToFile(rutaLog+'\LogDisp'+FiltraStrNum(FechaHoraToStr(Now))+'.txt');
    GuardarLogPetRes(0);
    if folio > 0 then
      AddPeticionJSON(folio, 'True|'+rutaLog+'\LogDisp'+FiltraStrNum(FechaHoraToStr(Now))+'.txt|');
  except
    on e:Exception do if folio > 0 then
      AddPeticionJSON(folio, 'False|Excepcion: '+e.Message+'|');
  end;
end;

procedure Togcvdispensarios_pam.GuardarLogPetRes(folio:Integer);
begin
  try
    AgregaLogPetRes('Version: '+version);
    ListaLogPetRes.SaveToFile(rutaLog+'\LogDispPetRes'+FiltraStrNum(FechaHoraToStr(Now))+'.txt');
    if folio > 0 then
      AddPeticionJSON(folio, 'True|');
  except
    on e:Exception do if folio > 0 then
      AddPeticionJSON(folio, 'False|Excepcion: '+e.Message+'|');
  end;
end;

procedure Togcvdispensarios_pam.RespuestaComando(folio:Integer; msj: string);
var
  resp:string;
begin
  try
    if StrToIntDef(msj,-1)=-1 then begin
      AddPeticionJSON(folio, 'False|Favor de indicar correctamente el numero de folio de comando|');
      Exit;
    end;

    resp:=ResultadoComando(StrToInt(msj));

    if (UpperCase(Copy(resp,1,2))='OK') then begin
      if Length(resp)>2 then
        resp:=copy(resp,3,Length(resp)-2)
      else
        resp:='';
      AddPeticionJSON(folio, 'True|'+resp);
    end
    else
      AddPeticionJSON(folio, 'False|'+resp+'|');
  except
    on e:Exception do
      AddPeticionJSON(folio, 'False|Excepcion: '+e.Message+'|');
  end;
end;

procedure Togcvdispensarios_pam.ObtenerLog(folio:Integer; r: Integer);
var
  i:Integer;
  res:string;
begin
  if r=0 then begin
    AddPeticionJSON(folio, 'False|No se indico el numero de registros|');
    Exit;
  end;

  if ListaLog.Count<1 then begin
    AddPeticionJSON(folio, 'False|No hay registros en el log|');
    Exit;
  end;

  i:=ListaLog.Count-(r+1);
  if i<1 then i:=0;

  res:='True|';

  for i:=i to ListaLog.Count-1 do
    res:=res+ListaLog[i]+'|';
    
  AddPeticionJSON(folio, res);
end;

procedure Togcvdispensarios_pam.ObtenerLogPetRes(folio:Integer; r: Integer);
var
  i:Integer;
  res:string;
begin
  if r=0 then begin
    AddPeticionJSON(folio, 'False|No se indico el numero de registros|');
    Exit;
  end;

  if ListaLogPetRes.Count<1 then begin
    AddPeticionJSON(folio, 'False|No hay registros en el log de peticiones|');
    Exit;
  end;

  i:=ListaLogPetRes.Count-(r+1);
  if i<1 then i:=0;

  res:='True|';

  for i:=i to ListaLogPetRes.Count-1 do
    res:=res+ListaLogPetRes[i]+'|';
    
  AddPeticionJSON(folio, res);
end;

function Togcvdispensarios_pam.ResultadoComando(xFolio:integer):string;
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
      AgregaLog('Excepcion ResultadoComando: '+e.Message);
  end;
end;

procedure Togcvdispensarios_pam.Bloquear(folio:Integer; msj: string);
var
  xpos:Integer;
begin
  try
    xpos:=StrToIntDef(msj,-1);

    if xpos<0 then begin
      AddPeticionJSON(folio, 'False|Favor de indicar correctamente la posicion de carga|');
      Exit;
    end;

    if (xpos<=MaximoDePosiciones) then begin
      if xpos=0 then begin
        for xpos:=1 to MaxPosCarga do
          TPosCarga[xpos].SwDesHabilitado:=True;
        AddPeticionJSON(folio, 'True|');
      end
      else if (xpos in [1..maxposcarga]) then begin
        TPosCarga[xpos].SwDesHabilitado:=True;
        AddPeticionJSON(folio, 'True|');
      end;
    end
    else AddPeticionJSON(folio, 'False|Posicion no Existe|');
  except
    on e:Exception do
      AddPeticionJSON(folio, 'False|Excepcion: '+e.Message+'|');
  end;
end;

procedure Togcvdispensarios_pam.Desbloquear(folio:Integer; msj: string);
var
  xpos:Integer;
begin
  try
    xpos:=StrToIntDef(msj,-1);

    if xpos<0 then begin
      AddPeticionJSON(folio, 'False|Favor de indicar correctamente la posicion de carga|');
      Exit;
    end;

    if (xpos<=MaximoDePosiciones) then begin
      if xpos=0 then begin
        for xpos:=1 to MaxPosCarga do
          TPosCarga[xpos].SwDesHabilitado:=False;
        AddPeticionJSON(folio, 'True|');
      end
      else if (xpos in [1..maxposcarga]) then begin
        TPosCarga[xpos].SwDesHabilitado:=False;
        AddPeticionJSON(folio, 'True|');
      end;
    end
    else AddPeticionJSON(folio, 'False|Posicion no Existe|');
  except
    on e:Exception do
      AddPeticionJSON(folio, 'False|Excepcion: '+e.Message+'|');
  end;
end;

procedure Togcvdispensarios_pam.Inicializar(folio:Integer; msj: string);
var
  js: TlkJSONBase;
  consolas,dispensarios,productos: TlkJSONbase;
  i,productID: Integer;
  datosPuerto,json,variables,variable,resultado:string;
begin
  try
    if estado>-1 then begin
      AddPeticionJSON(folio, 'False|El servicio ya habia sido inicializado|');
      Exit;
    end;

    // Use parameters from Wayne style parsing if applicable, or parse raw msj
    // Assuming msj is JSON|Variables
    json:=ExtraeElemStrSep(msj,1,'|');
    variables:=ExtraeElemStrSep(msj,2,'|');

    js := TlkJSON.ParseText(json);
    consolas := js.Field['Consoles'];

    datosPuerto:=VarToStr(consolas.Child[0].Field['Connection'].Value);

    resultado:=IniciaPSerial(datosPuerto);

    if resultado<>'' then begin
      AddPeticionJSON(folio, resultado);
      Exit;
    end;

    dispensarios := js.Field['Dispensers'];

    resultado:=AgregaPosCarga(dispensarios);

    if resultado<>'' then begin
      AddPeticionJSON(folio, resultado);
      Exit;
    end;

    digiVol:=2;
    digiPrec:=1;
    digiImp:=2;
    VersionPam1000:='3';
    ValidaMang:=False;
    AjustePAM:=False;
    for i:=1 to NoElemStrEnter(variables) do begin
      variable:=ExtraeElemStrEnter(variables,i);
      if UpperCase(ExtraeElemStrSep(variable,1,'='))='DECIMALESLITROS' then
        digiVol:=StrToInt(ExtraeElemStrSep(variable,2,'='))
      else if UpperCase(ExtraeElemStrSep(variable,1,'='))='DECIMALESPRECIO' then
        digiPrec:=StrToInt(ExtraeElemStrSep(variable,2,'='))
      else if UpperCase(ExtraeElemStrSep(variable,1,'='))='DECIMALESPESOS' then
        digiImp:=StrToInt(ExtraeElemStrSep(variable,2,'='))
      else if UpperCase(ExtraeElemStrSep(variable,1,'='))='SETUPPAM1000' then
        SetUpPAM1000:=ExtraeElemStrSep(variable,2,'=')
      else if UpperCase(ExtraeElemStrSep(variable,1,'='))='VERSIONPAM1000' then
        VersionPam1000:=ExtraeElemStrSep(variable,2,'=')
      else if UpperCase(ExtraeElemStrSep(variable,1,'='))='VALIDARMANGUERA' then
        ValidaMang:=UpperCase(ExtraeElemStrSep(variable,2,'='))='SI'
      else if UpperCase(ExtraeElemStrSep(variable,1,'='))='AJUSTEPAM' then
        AjustePAM:=Trim(UpperCase(ExtraeElemStrSep(variable,2,'=')))='SI';
    end;

    productos := js.Field['Products'];

    for i:=0 to productos.Count-1 do begin
      productID:=productos.Child[i].Field['ProductId'].Value;
      if productos.Child[i].Field['Price'].Value<0 then begin
        AddPeticionJSON(folio, 'False|El precio '+IntToStr(productID)+' es incorrecto|');
        Exit;
      end;
      LPrecios[productID]:=productos.Child[i].Field['Price'].Value;    
    end;
    PreciosInicio:=False;
    estado:=0;
    SetEstadoJSON(estado);
    AddPeticionJSON(folio, 'True|');
  except
    on e:Exception do begin
      AgregaLog('Error Inicializar: '+e.Message);
      GuardarLog(0);
      AddPeticionJSON(folio, 'False|Excepcion: '+e.Message+'|');
    end;
  end;
end;

procedure Togcvdispensarios_pam.Terminar(folio:Integer);
begin
  if estado>0 then
    AddPeticionJSON(folio, 'False|El servicio no esta detenido, no es posible terminar la comunicacion|')
  else begin
    Timer1.Enabled:=False;
    pSerial.Open:=False;
    LPrecios[1]:=0;
    LPrecios[2]:=0;
    LPrecios[3]:=0;
    LPrecios[4]:=0;
    estado:=-1;
    SetEstadoJSON(estado);
    AddPeticionJSON(folio, 'True|');
  end;
end;

function Togcvdispensarios_pam.CRC16(Data: AnsiString): AnsiString;
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

function Togcvdispensarios_pam.NoElemStrEnter(xstr:string):word;
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

function Togcvdispensarios_pam.ExtraeElemStrEnter(xstr:string;ind:word):string;
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

procedure Togcvdispensarios_pam.Login(folio:Integer; mensaje: string);
var
  usuario,password:string;
begin
  usuario:=ExtraeElemStrSep(mensaje,1,'|');
  password:=ExtraeElemStrSep(mensaje,2,'|');
  if MD5(usuario+'|'+FormatDateTime('yyyy-mm-dd',Date)+'T'+FormatDateTime('hh:nn',Now))<>password then
    AddPeticionJSON(folio, 'False|Password invalido|')
  else begin
    Token:=MD5(usuario+'|'+FormatDateTime('yyyy-mm-dd',Date)+'T'+FormatDateTime('hh:nn',Now));
    AddPeticionJSON(folio, 'True|'+Token+'|');
  end;
end;

function Togcvdispensarios_pam.MD5(const usuario: string): string;
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

procedure Togcvdispensarios_pam.Logout(folio:Integer);
begin
  Token:='';
  AddPeticionJSON(folio, 'True|');
end;

procedure Togcvdispensarios_pam.GuardaLogComandos;
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

function Togcvdispensarios_pam.Decrypt(data, key3DES: string): string;
var
  key128 : TKey128;
  dataOut : string;
begin
  try
    GenerateMD5Key(key128, Key3DES);
    TripleDESEncryptString(data,dataOut,key128,false);
    dataOut := UTF8Decode(dataOut);
    Result := dataOut;
  except
    on e:Exception do begin
      AgregaLog('Decrypt: '+e.Message+' Data: '+data+'3DES: '+key3DES);
      AgregaLogPetRes('Decrypt: '+e.Message+' Data: '+data+'3DES: '+key3DES);
    end;
  end;
end;

function Togcvdispensarios_pam.Encrypt(data, key3DES: string): string;
var
  key128 : TKey128;
  dataIn,dataOut : string;
begin
  try
    dataIn := UTF8Encode(data);
    GenerateMD5Key(key128, Key3DES);
    TripleDESEncryptString(dataIn,dataOut,key128,true);
    Result := dataOut;
  except
    on e:Exception do begin
      AgregaLog('Encrypt: '+e.Message);
      AgregaLogPetRes('Encrypt: '+e.Message);
    end;
  end;
end;

procedure Togcvdispensarios_pam.ComandoConsolaBuff(ss: string);
begin
  if (ListaCmnd.Count=0)and(not SwEsperaRsp) then
    ComandoConsola(ss)
  else
    ListaCmnd.Add(ss);
end;

end.
