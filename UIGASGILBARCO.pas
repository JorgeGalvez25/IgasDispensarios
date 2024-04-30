unit UIGASGILBARCO;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, SvcMgr, Dialogs,
  ExtCtrls, OoMisc, AdPort, ScktComp, IniFiles, ActiveX, ComObj, ULIBGRAL, CRCs,
  IdHashMessageDigest, IdHash, uLkJSON;

const
      MCxP=4;
      ValorX='9573';
      ValorOn='93715';
      ValorOff='92476';  

type
  Togcvdispensarios_gilbarco2W = class(TService)
    ServerSocket1: TServerSocket;
    pSerial: TApdComPort;
    Timer1: TTimer;
    procedure ServiceExecute(Sender: TService);
    procedure ServerSocket1ClientRead(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure Timer1Timer(Sender: TObject);
    procedure pSerialTriggerData(CP: TObject; TriggerHandle: Word);
    procedure pSerialTriggerAvail(CP: TObject; Count: Word);
  private
    { Private declarations }
    NumPaso         :integer;
    iBytesEsperados : integer;
    bListo, bEndOfText, bLineFeed : boolean;
    wTriggerEOT, wTriggerLF : word;
    srespuesta : string;
    etTimeOut : EventTimer;
    PosCiclo,ls,
    ContadorAlarma,
    ContLeeVenta:Integer;
    SwAplicaCmnd,
    SwEspera,
    SwPasoBien:boolean;
    Transmitiendo:Boolean;
    HoraEspera:TDateTime;
    Buffer:TList;
    function  TransmiteComando(iComando, xNPos: integer; sDataBlock: string) : boolean;
    procedure  TransmiteComandoEsp(sDataBlock: string);
    function  DataControlWordValue(chDataControlWord : char; iLongitud : integer) : longint;
  public
    ListaLog:TStringList;
    ListaLogPetRes:TStringList;
    rutaLog:string;
    confPos:string;
    licencia:string;
    detenido:Boolean;
    estado:Integer;
  // CONTROL TRAFICO COMANDOS
    ListaCmnd    :TStrings;  
    LinCmnd      :string;
    CharCmnd     :char;
    SwEsperaRsp  :boolean;
    ContEsperaRsp:integer;
    FolioCmnd   :integer;
    ContadorTotPos,
    ContadorTot :Integer;
    DecimalesGilbarco :Integer;
    DigGilbarco :Integer;

    GtwDivPresetLts,        // Divisor preset litros           **
    GtwDivPresetPesos,      // Divisor preset pesos            **

    GtwDivPrecio,           // Divisor precio para lecturas y cambio de precios       **
    GtwDivImporte,          // Divisor importe para lecturas y ventas                 **
    GtwDivLitros,           // Divisor litros para ventas                             **

    GtwDivTotLts,           // Divisor totales litros     **
    GtwDivTotImporte,       // Divisor totales pesos      **

    GtwTimeOut,             // Timeout miliseg
    GtwTiempoCmnd :integer; // Tiempo entre comandos miliseg

    horaLog:TDateTime;
    minutosLog:Integer;
    version:String;

    function GetServiceController: TServiceController; override;
    procedure AgregaLog(lin:string);
    procedure AgregaLogPetRes(lin: string);
    procedure Responder(socket:TCustomWinSocket;resp:string);
    function FechaHoraExtToStr(FechaHora:TDateTime):String;
    function CRC16(Data: string): string;
    function GuardarLog:string;
    function GuardarLogPetRes:string;
    function Login(mensaje: string): string;
    function Logout: string;
    function MD5(const usuario: string): string;
    function Bloquear(msj: string): string;
    function Desbloquear(msj: string): string;
    function Detener: string;
    function Iniciar: string;
    function Shutdown: string;
    function ObtenerEstado: string;
    function AutorizarVenta(msj: string): string;
    function DetenerVenta(msj: string): string;
    function ReanudarVenta(msj: string): string;
    function EjecutaComando(xCmnd:string):integer;
    function RespuestaComando(msj: string): string;
    function ResultadoComando(xFolio:integer):string;
    function ObtenerLog(r: Integer): string;
    function ObtenerLogPetRes(r: Integer): string;
    function ActivaModoPrepago(msj:string): string;
    function DesactivaModoPrepago(msj:string): string;
    function FinVenta(msj: string): string;
    function TransaccionPosCarga(msj: string): string;
    function EstadoPosiciones(msj: string): string;
    function TotalesBomba(msj: string): string;
    function Terminar: string;
    function IniciaPrecios(msj:string):string;
    function IniciaPSerial(datosPuerto:string): string;
    function AgregaPosCarga(posiciones: TlkJSONbase): string;
    function Inicializar(msj: string): string;
    function NoElemStrEnter(xstr:string):word;
    function ExtraeElemStrEnter(xstr:string;ind:word):string;
    function ValidaCifra(xvalor:real;xenteros,xdecimales:byte):string;

    function CombustibleEnPosicion(xpos,xpc:integer):integer;
    function PosicionDeCombustible(xpos,xcomb:integer):integer;
    function  CambiaPrecio6(xNPos, xNMang, xNPrec : integer; rPrecio : real) : boolean;
    function  CambiaPrecio8(xNPos, xNMang, xNPrec : integer; rPrecio : real) : boolean;
    function  DameTotales6(xNPos : integer; var rTotalizadorLitros1, rTotalizadorPesos1, rTotalizadorLitros2, rTotalizadorPesos2, rTotalizadorLitros3, rTotalizadorPesos3 : real) : boolean;
    function  DameTotales8(xNPos : integer; var rTotalizadorLitros1, rTotalizadorPesos1, rTotalizadorLitros2, rTotalizadorPesos2, rTotalizadorLitros3, rTotalizadorPesos3 : real) : boolean;
    function  DameLecturas6(xNPos : integer; var xNMang : integer; var rLitros, rPrecio, rPesos : real) : boolean;
    function  DameLecturas8(xNPos : integer; var xNMang : integer; var rLitros, rPrecio, rPesos : real) : boolean;
    function  DameVentaProceso6(xNPos : integer; var rPesos : real) : boolean;
    function  DameVentaProceso8(xNPos : integer; var rPesos : real) : boolean;
    function  EnviaPresetBomba6(xNPos, xNMang, xNPrec: integer; rPesos, rLitros: real) : boolean;
    function  EnviaPresetBomba8(xNPos, xNMang, xNPrec: integer; rPesos, rLitros: real) : boolean;
    function  DameEstatus(PosCarga:integer) : integer;
    function  Autoriza(PosCarga: integer) : boolean;
    function  DetenerDespacho(xNPos : integer) : boolean;
    function  ReanudaDespacho(PosCarga: integer) : boolean;
    function  PonNivelPrecio(xNPos, xNPrec : integer) : boolean;
    function EnviaPresetFlu(xpos:integer;xsube:boolean):boolean;
    procedure EstatusDispensarios;
    procedure ProcesaComandos;
    procedure AvanzaPosCiclo;
    procedure DespliegaMemo4(lin:string);
    procedure EjecutaBuffer;
    { Public declarations }
  end;

type
     tiposcarga = record
       SwDesHabil   :boolean;
       DigitosGilbarco,
       DivImporte,
       DivLitros,
       estatus,
       estatusant   :integer;
       importe,
       volumen,
       precio       :real;
       Isla,
       PosActual    :integer; // Posicion del combustible en proceso: 1..NoComb
       NoComb       :integer; // Cuantos combustibles hay en la posicion
       TComb        :array[1..MCxP] of integer; // Claves de los combustibles
       TPosx        :array[1..MCxP] of integer;
       TMang        :array[1..MCxP] of integer;
       TotalLitros  :array[1..MCxP] of real;

       TCambioPrecN1:array[1..MCxP] of boolean;
       TCambioPrecN2:array[1..MCxP] of boolean;
       TNuevoPrec   :array[1..MCxP] of real;

       MontoPreset    :string;
       ImportePreset  :real;

       swprec,
       swcargando     :boolean;
       ModoOpera      :string[8];
       TipoPago       :integer;
       EsperaFinVenta :integer;

       SwFinVenta,
       SwLeeVenta,
       SwTotales,
       SwNivelPrecio,
       SwCambiaPrecio,
       SwPreset       :boolean;
       HoraNivelPrecio:TDateTime;

       FallosEstat    :integer;
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

  type
    TBuffer = class
    private
      comando, parametro: string;
      Socket: TCustomWinSocket;
    public
      constructor Create(cmd,param:string;skt:TCustomWinSocket);
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
  ogcvdispensarios_gilbarco2W: Togcvdispensarios_gilbarco2W;
  key:OleVariant;
  claveCre,key3DES:string;
  Token:string;
  PreciosInicio:Boolean;
  MaxPosCarga:integer;
  TPosCarga:array[1..32] of tiposcarga;
  TabCmnd  :array[1..200] of RegCmnd;
  LPrecios :array[1..4] of Double;
  TAdicf        :array[1..32,1..3] of integer;
  Tagx        :array[1..3] of integer;
  EstatusAct,EstatusAnt  :string;
  Licencia3Ok  :Boolean;

implementation

uses TypInfo, StrUtils, Variants, DateUtils;

{$R *.DFM}

constructor TBuffer.Create(cmd,param:string;skt:TCustomWinSocket);
begin
  inherited Create;
  comando := cmd;
  parametro := param;
  Socket:=skt;
end;

function BcdToInt(xBCD : string) : integer;   // Convierte un BCD a Integer
var xValor, xMult, i : integer;
begin
   xValor:= 0;
   xMult:= 1;
   for i:= 1 to length(xBCD)do begin
      xValor:= xValor + (ord(xBCD[i]) and $0F)*xMult;
      xMult:= xMult*10;
   end;
   result:= xValor;
end;

function BcdToStr(xValor : string) : string;    // Convierte BCD a String
var xBCD : string;
    i : integer;
begin
   xBCD:= '';
   for i:= length(xValor) downto 1 do try
      xBCD:= xBCD + char($E0 + strtoint(xValor[i]));
   except
      xBCD:= '';
   end;
   result:= xBCD;
end;

function DLChar(s : string) : char;    // Longitud de String en Character
var iDL : integer;
begin
   iDL:= ( length(s) + 2 ) xor $FF + 1;
   result:= char($E0 + iDL and $0F);
end;

function LoNibbleChar(ch : char): byte;
begin
   result:= ord(ch) and $0F;
end;

function HiNibbleChar(ch : char): byte;
begin
   result:= ( ord(ch) shr 4) and $0F;
end;


function LrcCheckChar(s : string) : char;
var iLRC, i : integer;
begin
   iLRC:= 0;
   for i:= 1 to length(s) do iLRC:= iLRC + ord(s[i]) and $0F;
   iLRC:= iLRC xor $F + 1;
   result:= char($E0 + iLRC and $F);
end;

procedure ServiceController(CtrlCode: DWord); stdcall;
begin
  ogcvdispensarios_gilbarco2W.Controller(CtrlCode);
end;

function Togcvdispensarios_gilbarco2W.GetServiceController: TServiceController;
begin
  Result := ServiceController;
end;

procedure Togcvdispensarios_gilbarco2W.ServiceExecute(Sender: TService);
var
  config:TIniFile;
  lic:string;
  razonSocial,licAdic:String;
  esLicTemporal:Boolean;
  fechaVenceLic:TDateTime;
begin
  try
    config:= TIniFile.Create(ExtractFilePath(ParamStr(0)) +'PDISPENSARIOS.ini');
    rutaLog:=config.ReadString('CONF','RutaLog','C:\ImagenCo');
    ServerSocket1.Port:=config.ReadInteger('CONF','Puerto',1001);
    licencia:=config.ReadString('CONF','Licencia','');
    minutosLog:=StrToInt(config.ReadString('CONF','MinutosLog','0'));
    ListaCmnd:=TStringList.Create;
    ServerSocket1.Active:=True;
    detenido:=True;
    estado:=-1;
    horaLog:=Now;
    ListaLog:=TStringList.Create;
    ListaLogPetRes:=TStringList.Create;
    Buffer:=TList.Create;

    CoInitialize(nil);
    Key:=CreateOleObject('HaspDelphiAdapter.HaspAdapter');
    lic:=Key.GetKeyData(ExtractFilePath(ParamStr(0)),licencia);

    if UpperCase(ExtraeElemStrSep(lic,1,'|'))='FALSE' then begin
      ListaLog.Add('Error al validad licencia: '+Key.StatusMessage);
      ListaLog.SaveToFile(rutaLog+'\LogDispPetRes'+FiltraStrNum(FechaHoraToStr(Now))+'.txt');
      ServiceThread.Terminate;
      Exit;
    end
    else begin
      claveCre:=ExtraeElemStrSep(lic,2,'|');
      key3DES:=ExtraeElemStrSep(lic,3,'|');
    end;

    while not Terminated do
      ServiceThread.ProcessRequests(True);
    ServerSocket1.Active := False;
    CoUninitialize;        
  except
    on e:exception do begin
      ListaLog.Add('Error al iniciar servicio: '+e.Message);
      ListaLog.SaveToFile(rutaLog+'\LogDispPetRes'+FiltraStrNum(FechaHoraToStr(Now))+'.txt');
    end;
  end;
end;

procedure Togcvdispensarios_gilbarco2W.ServerSocket1ClientRead(
  Sender: TObject; Socket: TCustomWinSocket);
  var
    mensaje,comando,checksum,parametro:string;
    i:Integer;
    chks_valido:Boolean;
    metodoEnum:TMetodos;
    objBuffer:TBuffer;
begin
  try
    mensaje:=Socket.ReceiveText;
    AgregaLogPetRes('R '+mensaje);
    for i:=1 to Length(mensaje) do begin
      if mensaje[i]=#2 then begin
        mensaje:=Copy(mensaje,i+1,Length(mensaje));
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

      if (Transmitiendo) and (UpperCase(comando)='AUTHORIZE') then begin
        Responder(Socket,'DISPENSERS|'+comando+'|False|Comandos en proceso, favor de reintentar|');
        Exit;
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
      if (claveCre<>'') and (key3DES<>'') then
        AgregaLogPetRes('Error ServerSocket1ClientRead: '+e.Message+'//Clave CRE: '+claveCre+'//Terminacion de Key 3DES: '+copy(key3DES,Length(key3DES)-3,4))
      else
        AgregaLogPetRes('Error ServerSocket1ClientRead: '+e.Message);
      GuardarLog;
      Responder(Socket,'DISPENSERS|'+comando+'|False|'+e.Message+'|');
    end;
  end;
end;

procedure Togcvdispensarios_gilbarco2W.AgregaLog(lin: string);
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

procedure Togcvdispensarios_gilbarco2W.AgregaLogPetRes(lin: string);
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

procedure Togcvdispensarios_gilbarco2W.Responder(socket: TCustomWinSocket;
  resp: string);
begin
  socket.SendText(#1#2+resp+#3+CRC16(resp)+#23);
  AgregaLogPetRes('E '+#1#2+resp+#3+CRC16(resp)+#23);
end;

function Togcvdispensarios_gilbarco2W.FechaHoraExtToStr(
  FechaHora: TDateTime): String;
begin
  result:=FechaPaq(FechaHora)+' '+FormatDatetime('hh:mm:ss.zzz',FechaHora);
end;

function Togcvdispensarios_gilbarco2W.CRC16(Data: string): string;
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

function Togcvdispensarios_gilbarco2W.GuardarLog: string;
begin
  try
    AgregaLog('Version: '+version);
    ListaLog.SaveToFile(rutaLog+'\LogDisp'+FiltraStrNum(FechaHoraToStr(Now))+'.txt');
    GuardarLogPetRes;
    Result:='True|'+rutaLog+'\LogDisp'+FiltraStrNum(FechaHoraToStr(Now))+'.txt|';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_gilbarco2W.GuardarLogPetRes: string;
begin
  try
    AgregaLogPetRes('Version: '+version);
    ListaLogPetRes.SaveToFile(rutaLog+'\LogDispPetRes'+FiltraStrNum(FechaHoraToStr(Now))+'.txt');
    Result:='True|';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_gilbarco2W.Login(mensaje: string): string;
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

function Togcvdispensarios_gilbarco2W.Logout: string;
begin
  Token:='';
  Result:='True|';
end;

function Togcvdispensarios_gilbarco2W.MD5(const usuario: string): string;
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

function Togcvdispensarios_gilbarco2W.Bloquear(msj: string): string;
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
          TPosCarga[xpos].SwDesHabil:=True;
        Result:='True|';
      end
      else if (xpos in [1..maxposcarga]) then begin
        TPosCarga[xpos].SwDesHabil:=True;
        Result:='True|';
      end;
    end
    else Result:='False|Posicion no Existe|';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_gilbarco2W.Desbloquear(msj: string): string;
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
          TPosCarga[xpos].SwDesHabil:=False;
        Result:='True|';
      end
      else if (xpos in [1..maxposcarga]) then begin
        TPosCarga[xpos].SwDesHabil:=False;
        Result:='True|';
      end;
    end
    else Result:='False|Posicion no Existe|';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_gilbarco2W.Detener: string;
begin
  try
    if estado=-1 then begin
      Result:='False|El proceso no se ha iniciado aun|';
      Exit;
    end;

    if not detenido then begin
      pSerial.Open:=False;
      pSerial.Tracing:= tlOff;
      pSerial.Open:= false;
      pSerial.DTR:= false;
      pSerial.RTS:= false;
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

function Togcvdispensarios_gilbarco2W.Iniciar: string;
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

    wTriggerEOT:= pSerial.AddDataTrigger(#$F0,true);
    wTriggerLF:= pSerial.AddDataTrigger(#$8A,true);

    detenido:=False;
    estado:=1;
    numPaso:=0;
    SwPasoBien:=true;
    PosCiclo:=1;
    swespera:=False;
    Timer1.Enabled:=True;
    Result:='True|';
  except
    on e:Exception do
      Result:='False|'+e.Message+'|';
  end;
end;

function Togcvdispensarios_gilbarco2W.ObtenerEstado: string;
begin
  Result:='True|'+IntToStr(estado)+'|';
end;

function Togcvdispensarios_gilbarco2W.Shutdown: string;
begin
  if estado>0 then
    Result:='False|El servicio esta en proceso, no fue posible detenerlo|'
  else begin
    ServiceThread.Terminate;
    Result:='True|';
  end;
end;

function Togcvdispensarios_gilbarco2W.AutorizarVenta(msj: string): string;
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

function Togcvdispensarios_gilbarco2W.DetenerVenta(msj: string): string;
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

function Togcvdispensarios_gilbarco2W.ReanudarVenta(msj: string): string;
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

function Togcvdispensarios_gilbarco2W.EjecutaComando(xCmnd: string): integer;
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

function Togcvdispensarios_gilbarco2W.RespuestaComando(msj: string): string;
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

function Togcvdispensarios_gilbarco2W.ResultadoComando(
  xFolio: integer): string;
var i:integer;
begin
  Result:='*';
  for i:=1 to 40 do
    if (TabCmnd[i].folio=xfolio)and(TabCmnd[i].SwResp) then
      result:=TabCmnd[i].Respuesta;
end;

function Togcvdispensarios_gilbarco2W.ObtenerLog(r: Integer): string;
var
  i:Integer;
begin
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
end;

function Togcvdispensarios_gilbarco2W.ObtenerLogPetRes(r: Integer): string;
var
  i:Integer;
begin
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
end;

function Togcvdispensarios_gilbarco2W.ActivaModoPrepago(msj: string): string;
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

function Togcvdispensarios_gilbarco2W.DesactivaModoPrepago(
  msj: string): string;
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

function Togcvdispensarios_gilbarco2W.FinVenta(msj: string): string;
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

function Togcvdispensarios_gilbarco2W.TransaccionPosCarga(
  msj: string): string;
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

function Togcvdispensarios_gilbarco2W.EstadoPosiciones(msj: string): string;
var
  xpos:Integer;
begin
  try
    xpos:=StrToIntDef(msj,-1);
    if xpos<0 then begin
      Result:='False|Favor de indicar correctamente la posicion de carga|';
      Exit;
    end;

    if EstatusAct='' then begin
      Result:='False|Error de comunicacion|';
      Exit;
    end;    

    if xpos>0 then
      Result:='True|'+EstatusAct[xpos]+'|'
    else
      Result:='True|'+EstatusAct+'|';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_gilbarco2W.TotalesBomba(msj: string): string;
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

function Togcvdispensarios_gilbarco2W.Terminar: string;
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

function Togcvdispensarios_gilbarco2W.CombustibleEnPosicion(xpos,
  xpc: integer): integer;
var i:integer;
begin
  with TPosCarga[xpos] do begin
    result:=0;
    for i:=1 to NoComb do begin
      if TPosx[i]=xpc then
        result:=TComb[i];
    end;
  end;
end;

function Togcvdispensarios_gilbarco2W.PosicionDeCombustible(xpos,
  xcomb: integer): integer;
var i:integer;
begin
  with TPosCarga[xpos] do begin
    result:=0;
    if xcomb>0 then begin
      for i:=1 to NoComb do begin
        if TComb[i]=xcomb then
          result:=TPosx[i];
      end;
    end;
  end;
end;

function Togcvdispensarios_gilbarco2W.CambiaPrecio6(xNPos, xNMang,
  xNPrec: integer; rPrecio: real): boolean;
var sPriceLevel, sDataBlock : string;
begin
  if ( xNPrec=1 ) then
     sPriceLevel:= #$F4
  else
     sPriceLevel:= #$F5;
  sDataBlock:= sPriceLevel + #$F6 + chr($E0 + xNMang - 1) + #$F7 + BcdToStr(format('%4.4d',[round(rPrecio*GtwDivPrecio)])) + #$FB;
  sDataBlock:= #$FF + DLChar(sDataBlock) + sDataBlock;
  sDataBlock:= sDataBlock + LrcCheckChar(sDataBlock) + #$F0;
  result:= ( TransmiteComando($20,xNPos,sDataBlock) );
end;

function Togcvdispensarios_gilbarco2W.CambiaPrecio8(xNPos, xNMang,
  xNPrec: integer; rPrecio: real): boolean;
var sPriceLevel, sDataBlock : string;
begin
  if ( xNPrec=1 ) then
     sPriceLevel:= #$F4
  else
     sPriceLevel:= #$F5;
  sDataBlock:= sPriceLevel + #$F6 + chr($E0 + xNMang - 1) + #$F7 + BcdToStr(format('%6.6d',[round(rPrecio*GtwDivPrecio)])) + #$FB;
  sDataBlock:= #$FF + DLChar(sDataBlock) + sDataBlock;
  sDataBlock:= sDataBlock + LrcCheckChar(sDataBlock) + #$F0;
  result:= ( TransmiteComando($20,xNPos,sDataBlock) );
end;

function Togcvdispensarios_gilbarco2W.IniciaPrecios(msj: string): string;
var
  ss:string;
  precioComb:Double;
  xpos,i:Integer;
begin
  try
    if EjecutaComando('CPREC '+msj)>0 then
      Result:='True|'
    else
      Result:='False|No fue posible aplicar comando de cambio de precios|';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_gilbarco2W.TransmiteComando(iComando,
  xNPos: integer; sDataBlock: string): boolean;
var iMaxIntentos, iNoIntento, i , xpos: integer;
    chComando : char;
    sw2,
    bOk : boolean;
begin
  try
    try
      Timer1.Enabled:=False;
      xpos:=xNPos;
      sw2:=false;
      if ( iComando in [$10,$30,$F0] ) then begin
         bOk:= true;
         iMaxIntentos:= 0;
      end
      else begin
        bOk:= false;
        if ( iComando in [$00,$20] ) then begin
          iMaxIntentos:= 2;
          iBytesEsperados:= 1;
          if ( iComando in [$20] ) then begin
            sw2:=true;
            Transmitiendo:=True;
          end;
        end
        else begin
          iMaxIntentos:= 2;
          if TPosCarga[xpos].DigitosGilbarco=6 then begin
            if ( iComando=$40 ) then
               iBytesEsperados:= 33
            else if ( iComando=$50 ) then
               iBytesEsperados:= 184
            else if ( iComando=$60 ) then
               iBytesEsperados:= 6;
          end
          else begin
            if ( iComando=$40 ) then
               iBytesEsperados:= 39
            else if ( iComando=$50 ) then
               iBytesEsperados:= 256
            else if ( iComando=$60 ) then
               iBytesEsperados:= 8;
          end;
        end;
      end;
      if ( xNPos=16 ) then xNPos:= 0;
      chComando:= char(iComando + xNPos);
      iNoIntento:= 0;
      repeat
        inc(iNoIntento);
        bListo:= false;
        bEndOfText:= false;
        bLineFeed:= false;
        sRespuesta:= '';
        pSerial.FlushInBuffer;
        pSerial.FlushOutBuffer;
        AgregaLog('E '+chComando+' - '+IntToHex(iComando,1)+'.'+IntToStr(xNPos));
        pSerial.PutChar(chComando);
        repeat
           pSerial.ProcessCommunications;
        until ( pSerial.OutBuffUsed=0 );
        if ( not bOk ) then begin
          if sw2 then
            newtimer(etTimeOut,MSecs2Ticks(GtwTimeout))
          else
            newtimer(etTimeOut,MSecs2Ticks(GtwTimeout));
          repeat
             Sleep(5);
          until ( ( bListo ) or ( timerexpired(etTimeOut) ) );
          AgregaLog('sRespuesta1 Length: '+IntToStr(length(sRespuesta)));
          if ( bListo ) then begin
            ls:=length(sRespuesta);
            if TPosCarga[xpos].DigitosGilbarco=6 then begin
              if ( iComando=$00 ) then
                 bOk:= ( ( LoNibbleChar(sRespuesta[1])=xNPos ) and ( HiNibbleChar(sRespuesta[1])<>$0 ) )
              else if ( iComando=$20 ) then begin
                 bOk:= ( ( LoNibbleChar(sRespuesta[1])=xNPos ) and ( HiNibbleChar(sRespuesta[1])=$D ) );
              end
              else if ( iComando=$40 ) then begin
                bOk:= ( length(sRespuesta)>31 );
              end
              else if ( iComando=$50 ) then begin
                bOk:= ( ( ( length(sRespuesta) - 4) mod 30)=0 );
              end
              else if ( iComando=$60 ) then begin
                 bOk:= ( length(sRespuesta)=6 );
              end
              else
                 bOk:= false;
            end
            else begin
              if ( iComando=$00 ) then
                 bOk:= ( ( LoNibbleChar(sRespuesta[1])=xNPos ) and ( HiNibbleChar(sRespuesta[1])<>$0 ) )
              else if ( iComando=$20 ) then begin
                 bOk:= ( ( LoNibbleChar(sRespuesta[1])=xNPos ) and ( HiNibbleChar(sRespuesta[1])=$D ) );
              end
              else if ( iComando=$40 ) then begin
                bOk:= ( length(sRespuesta)>37 );
              end
              else if ( iComando=$50 ) then begin
                bOk:= ( ( ( length(sRespuesta) - 4) mod 42)=0 );
              end
              else if ( iComando=$60 ) then begin
                bOk:= ( length(sRespuesta)=8 );
              end
              else
                 bOk:= false;
            end;
          end;
          if ( not bOk ) then begin
            if  ( iNoIntento<iMaxIntentos ) then sleep(GtwTiempoCmnd);
          end
          else if ( iComando=$20 ) then begin
            sleep(10);
            bListo:= false;
            bEndOfText:= false;
            bLineFeed:= false;
            sRespuesta:= '';
            pSerial.FlushInBuffer;
            pSerial.FlushOutBuffer;
            AgregaLog('sDataBlock: '+sDataBlock);
            for i:= 1 to length ( sDataBlock ) do begin
               pSerial.PutChar(sDataBlock[i]);
               repeat
                  pSerial.ProcessCommunications;
               until ( pSerial.OutBuffUsed=0 );
            end;
            sleep(GtwTiempoCmnd);
            chComando:= char($00 + xNPos);
            AgregaLog('E '+chComando+' - '+IntToHex($00,1)+'.'+IntToStr(xNPos));
            pSerial.PutChar(chComando);
            repeat
               pSerial.ProcessCommunications;
            until ( pSerial.OutBuffUsed=0 );
            newtimer(etTimeOut,MSecs2Ticks(GtwTimeout));
            repeat
               Sleep(5);
            until ( ( bListo ) or ( timerexpired(etTimeOut) ) );        // FALLA
            Transmitiendo:=False;
            AgregaLog('sRespuesta2 Length: '+IntToStr(length(sRespuesta)));
            if length(sRespuesta)>0 then
              bOk:= ( LoNibbleChar(sRespuesta[1])=xNPos )
            else
              bOk:=False;
          end;
        end;
      until ( ( bOk ) or ( iNoIntento>=iMaxIntentos ) );
      result:= bOk;
    except
      on e:Exception do begin
        AgregaLog('Error TransmiteComando: '+e.Message);
        raise Exception.Create('Error TransmiteComando');
      end;
    end;
  finally
    Transmitiendo:=False;
    Timer1.Enabled:=True;
  end;
end;

function Togcvdispensarios_gilbarco2W.DataControlWordValue(
  chDataControlWord: char; iLongitud: integer): longint;
var xValor : longint;
    iPosicion : integer;
begin
   iPosicion:= pos(chDataControlWord,sRespuesta);
   if ( ( iPosicion=0 ) or ( ( iPosicion + 1 + iLongitud )>length(sRespuesta) ) ) then
      xValor:= 0
   else
      xValor:= BcdToInt(copy(sRespuesta,iPosicion + 1,iLongitud));
   result:= xValor;
end;

function Togcvdispensarios_gilbarco2W.DameTotales6(xNPos: integer;
  var rTotalizadorLitros1, rTotalizadorPesos1, rTotalizadorLitros2,
  rTotalizadorPesos2, rTotalizadorLitros3,
  rTotalizadorPesos3: real): boolean;
var xNMang : integer;
    bOk : boolean;
begin
  rTotalizadorLitros1:= 0;
  rTotalizadorPesos1:= 0;
  rTotalizadorLitros2:= 0;
  rTotalizadorPesos2:= 0;
  rTotalizadorLitros3:= 0;
  rTotalizadorPesos3:= 0;
  bOk:= ( ( TransmiteComando($50,xNPos,'') ) and ( length(sRespuesta)>=34 ) );
  AgregaLog(IfThen(bOk,'Totales correctos','Totales incorrectos'));
  if ( bOk ) then begin
    delete(sRespuesta,1,1);
    while ( length(sRespuesta)>30 ) do begin
      xNMang:= ( LoNibbleChar(sRespuesta[2]) ) + 1;
      AgregaLog('MangTot: '+IntToStr(xNMang));
      case ( xNMang ) of
        1 : begin
               rTotalizadorLitros1:= DataControlWordValue(#$F9,8)/GtwDivTotLts;
               if rTotalizadorLitros1=0 then
                 rTotalizadorLitros1:=0.01;
               rTotalizadorPesos1:= DataControlWordValue(#$FA,8)/GtwDivTotImporte;
               AgregaLog('TotLts1: '+FloatToStr(rTotalizadorLitros1));
               AgregaLog('TotImp1: '+FloatToStr(rTotalizadorPesos1));
            end;
        2 : begin
               rTotalizadorLitros2:= DataControlWordValue(#$F9,8)/GtwDivTotLts;
               if rTotalizadorLitros2=0 then
                 rTotalizadorLitros2:=0.01;
               rTotalizadorPesos2:= DataControlWordValue(#$FA,8)/GtwDivTotImporte;
               AgregaLog('TotLts2: '+FloatToStr(rTotalizadorLitros2));
               AgregaLog('TotImp2: '+FloatToStr(rTotalizadorPesos2));
            end;
        3 : begin
               rTotalizadorLitros3:= DataControlWordValue(#$F9,8)/GtwDivTotLts;
               if rTotalizadorLitros3=0 then
                 rTotalizadorLitros3:=0.01;
               rTotalizadorPesos3:= DataControlWordValue(#$FA,8)/GtwDivTotImporte;
               AgregaLog('TotLts3: '+FloatToStr(rTotalizadorLitros3));
               AgregaLog('TotImp3: '+FloatToStr(rTotalizadorPesos3));
            end;
      end;
      delete(sRespuesta,1,30);
    end;
  end;
  result:= bOk;
end;

function Togcvdispensarios_gilbarco2W.DameTotales8(xNPos: integer;
  var rTotalizadorLitros1, rTotalizadorPesos1, rTotalizadorLitros2,
  rTotalizadorPesos2, rTotalizadorLitros3,
  rTotalizadorPesos3: real): boolean;
var xNMang : integer;
    bOk : boolean;
begin
  rTotalizadorLitros1:= 0;
  rTotalizadorPesos1:= 0;
  rTotalizadorLitros2:= 0;
  rTotalizadorPesos2:= 0;
  rTotalizadorLitros3:= 0;
  rTotalizadorPesos3:= 0;
  bOk:= ( ( TransmiteComando($50,xNPos,'') ) and ( length(sRespuesta)>=46 ) );
  if ( bOk ) then begin
    delete(sRespuesta,1,1);
    while ( length(sRespuesta)>30 ) do begin
      xNMang:= ( LoNibbleChar(sRespuesta[2]) ) + 1;
      case ( xNMang ) of
        1 : begin
               rTotalizadorLitros1:= DataControlWordValue(#$F9,12)/GtwDivTotLts;
               rTotalizadorPesos1:= DataControlWordValue(#$FA,12)/GtwDivTotImporte;
            end;
        2 : begin
               rTotalizadorLitros2:= DataControlWordValue(#$F9,12)/GtwDivTotLts;
               rTotalizadorPesos2:= DataControlWordValue(#$FA,12)/GtwDivTotImporte;
            end;
        3 : begin
               rTotalizadorLitros3:= DataControlWordValue(#$F9,12)/GtwDivTotLts;
               rTotalizadorPesos3:= DataControlWordValue(#$FA,12)/GtwDivTotImporte;
            end;
      end;
      delete(sRespuesta,1,42);
    end;
  end;
  result:= bOk;
end;

function Togcvdispensarios_gilbarco2W.DameLecturas6(xNPos: integer;
  var xNMang: integer; var rLitros, rPrecio, rPesos: real): boolean;
var bOk : boolean;
begin
  try
    bOk:= ( ( TransmiteComando($40,xNPos,'') ) and ( length(sRespuesta)>=33 ) );
    if bOk then
      AgregaLog('Lecturas correctas');
    if ( bOk ) then begin
      xNMang:= DataControlWordValue(#$F6,1) + 1;
      AgregaLog('Manguera recibida: '+IntToStr(xNMang));
      rPrecio:= DataControlWordValue(#$F7,4);
      rLitros:= DataControlWordValue(#$F9,6);
      rPesos:= DataControlWordValue(#$FA,6);
      rPrecio:= rPrecio/GtwDivPrecio;
      rLitros:= rLitros/TPosCarga[PosCiclo].DivLitros;
      rPesos:= rPesos/TPosCarga[PosCiclo].DivImporte;
    end;
    result:= bOk;
  except
    on e:Exception do
      AgregaLog('Error DameLecturas6:'+e.Message);
  end;
end;

function Togcvdispensarios_gilbarco2W.DameLecturas8(xNPos: integer;
  var xNMang: integer; var rLitros, rPrecio, rPesos: real): boolean;
var bOk : boolean;
begin
  bOk:= ( ( TransmiteComando($40,xNPos,'') ) and ( length(sRespuesta)>=39 ) );
  if ( bOk ) then begin
    xNMang:= DataControlWordValue(#$F6,1) + 1;
    rPrecio:= DataControlWordValue(#$F7,6);
    rLitros:= DataControlWordValue(#$F9,8);
    rPesos:= DataControlWordValue(#$FA,8);
    rPrecio:= rPrecio/GtwDivPrecio;
    rLitros:= rLitros/TPosCarga[PosCiclo].DivLitros;
    rPesos:= rPesos/TPosCarga[PosCiclo].DivImporte;
  end;
  result:= bOk;
end;

function Togcvdispensarios_gilbarco2W.DameVentaProceso6(xNPos: integer;
  var rPesos: real): boolean;
var bOk : boolean;
begin
   bOk:= ( ( TransmiteComando($60,xNPos,'') ) and ( length(sRespuesta)>=6 ) );
   if ( bOk ) then
     rPesos:= BcdToInt(copy(sRespuesta,1,6))/TPosCarga[PosCiclo].DivImporte;
   result:= bOk;
end;

function Togcvdispensarios_gilbarco2W.DameVentaProceso8(xNPos: integer;
  var rPesos: real): boolean;
var bOk : boolean;
begin
   bOk:= ( ( TransmiteComando($60,xNPos,'') ) and ( length(sRespuesta)>=8 ) );
   if ( bOk ) then rPesos:= BcdToInt(copy(sRespuesta,1,8))/TPosCarga[PosCiclo].DivImporte;
   result:= bOk;
end;

function Togcvdispensarios_gilbarco2W.EnviaPresetBomba6(xNPos, xNMang,
  xNPrec: integer; rPesos, rLitros: real): boolean;
var sGrade, sPriceLevel, sPresetType, sAmount, sDataBlock : string;
begin
  if ( xNMang=0 ) then
     sGrade:= ''
  else
     sGrade:= #$F6 + char($E0 + xNMang - 1);
  if ( xNPrec=1 ) then
     sPriceLevel:= #$F4
  else
     sPriceLevel:= #$F5;
  if ( rLitros>0 ) then begin
     sPresetType:= #$F1;
     sAmount:= format('%5.5d',[round(rLitros*GtwDivPresetLts)]);
  end
  else begin
     sPresetType:= #$F2;
     sAmount:= format('%6.6d',[round(rPesos*GtwDivPresetPesos)]);
  end;
  sDataBlock:=  sPresetType + sPriceLevel + sGrade + #$F8 + BcdToStr(sAmount) + #$FB;
  sDataBlock:= #$FF + DLChar(sDataBlock) + sDataBlock;
  sDataBlock:= sDataBlock + LrcCheckChar(sDataBlock) + #$F0;
  result:= ( TransmiteComando($20,xNPos,sDataBlock) );
end;

function Togcvdispensarios_gilbarco2W.EnviaPresetBomba8(xNPos, xNMang,
  xNPrec: integer; rPesos, rLitros: real): boolean;
var sGrade, sPriceLevel, sPresetType, sAmount, sDataBlock : string;
begin
  if ( xNMang=0 ) then
     sGrade:= ''
  else
     sGrade:= #$F6 + char($E0 + xNMang - 1);
  if ( xNPrec=1 ) then
     sPriceLevel:= #$F4
  else
     sPriceLevel:= #$F5;
  if ( rLitros>0 ) then begin
     sPresetType:= #$F1;
     sAmount:= format('%8.8d',[round(rLitros*GtwDivPresetLts)]);
  end
  else begin
     sPresetType:= #$F2;
     sAmount:= format('%8.8d',[round(rPesos*GtwDivPresetPesos)]);
  end;
  sDataBlock:=  sPresetType + sPriceLevel + sGrade + #$F8 + BcdToStr(sAmount) + #$FB;
  sDataBlock:= #$FF + DLChar(sDataBlock) + sDataBlock;
  sDataBlock:= sDataBlock + LrcCheckChar(sDataBlock) + #$F0;
  result:= ( TransmiteComando($20,xNPos,sDataBlock) );
end;

procedure Togcvdispensarios_gilbarco2W.TransmiteComandoEsp(
  sDataBlock: string);
var 
    i:integer;
begin
  sleep(10);
  pSerial.FlushInBuffer;
  pSerial.FlushOutBuffer;
  for i:= 1 to length ( sDataBlock ) do begin
    pSerial.PutChar(sDataBlock[i]);
    repeat
       pSerial.ProcessCommunications;
    until ( pSerial.OutBuffUsed=0 );
  end;
  sleep(GtwTiempoCmnd);
  newtimer(etTimeOut,MSecs2Ticks(GtwTimeout));
  repeat
    ServiceThread.ProcessRequests(True);
  until ( ( bListo ) or ( timerexpired(etTimeOut) ) );        // FALLA
end;

function Togcvdispensarios_gilbarco2W.AgregaPosCarga(
  posiciones: TlkJSONbase): string;
var i,j,k,xisla,xpos,xcomb,xnum:integer;
  dataPos:string;
  existe:boolean;
  mangueras:TlkJSONbase;
  cPos,cMang:string;
begin
  try
    if not detenido then begin
      Result:='False|Es necesario detener el proceso antes de inicializar las posiciones de carga|';
      Exit;
    end;

    MaxPosCarga:=0;
    for i:=1 to 32 do with TPosCarga[i] do begin
      DigitosGilbarco:=6;
      for j:=1 to 3 do
        TAdicf[i,j]:=0;
      DivImporte:=GtwDivImporte;
      DivLitros:=GtwDivLitros;
      estatus:=-1;
      estatusant:=-1;
      NoComb:=0;
      SwPreset:=false;
      importe:=0;
      volumen:=0;
      precio:=0;
      tipopago:=0;
      Esperafinventa:=0;
      SwCargando:=false;
      for j:=1 to MCxP do begin
        TotalLitros[j]:=0;
        TCambioPrecN1[j]:=false;
        TCambioPrecN2[j]:=false;
        TNuevoPrec[j]:=0;
      end;
      SwDeshabil:=false;
      SwTotales:=true;
      SwLeeVenta:=true;
      SwFinVenta:=false;
      SwNivelPrecio:=true;
      SwCambiaPrecio:=false;
      SwPreset:=false;
      Fallosestat:=0;
      HoraNivelPrecio:=Now;
    end;

    for i:=0 to posiciones.Count-1 do begin
      xpos:=posiciones.Child[i].Field['DispenserId'].Value;
      if xpos>MaxPosCarga then
        MaxPosCarga:=xpos;
      with TPosCarga[xpos] do begin
        SwPrec:=false;
        existe:=false;
        ModoOpera:='Prepago';

        if (DecimalesGilbarco=100) or (DecimalesGilbarco=1000) then begin
          DivImporte:=DecimalesGilbarco;
          DivLitros:=DecimalesGilbarco;
        end;

        if DigGilbarco=8 then
          DigitosGilbarco:=8;

        AgregaLog('DigitosGilbarco='+IntToStr(DigitosGilbarco));

        mangueras:=posiciones.Child[i].Field['Hoses'];
        for j:=0 to mangueras.Count-1 do begin
          xcomb:=mangueras.Child[j].Field['ProductId'].Value;
          for k:=1 to NoComb do
            if TComb[k]=xcomb then
              existe:=true;

          if not existe then begin
            inc(NoComb);
            TComb[NoComb]:=xcomb;
            TMang[NoComb]:=mangueras.Child[j].Field['HoseId'].Value;
            if TMang[NoComb]>0 then begin
              TPosx[NoComb]:=TMang[NoComb];
              DespliegaMemo4('>>NoComb '+inttostr(NoComb)+'    Comb '+inttostr(xcomb)+'    xPos '+inttostr(TPosx[NoComb]));
            end
            else if NoComb<=2 then
              TPosx[NoComb]:=NoComb
            else
              TPosx[NoComb]:=1;
          end;
        end;
      end;
    end;
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_gilbarco2W.IniciaPSerial(
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

    pSerial.TraceAllHex:= true;
    pSerial.TraceName:= 'c:\OGTrace.txt';
    pSerial.Tracing:= tlOn;
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_gilbarco2W.Inicializar(msj: string): string;
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

    js := TlkJSON.ParseText(json);
    consolas := js.Field['Consoles'];

    datosPuerto:=VarToStr(consolas.Child[0].Field['Connection'].Value);

    Result:=IniciaPSerial(datosPuerto);

    if Result<>'' then
      Exit;

    dispensarios := js.Field['Dispensers'];

    DecimalesGilbarco:=2;
    DigGilbarco:=6;
    GtwDivPresetLts:=100;
    GtwDivPresetPesos:=100;
    GtwDivPrecio:=100;
    GtwDivImporte:=100;
    GtwDivLitros:=100;
    GtwDivTotLts:=100;
    GtwDivTotImporte:=100;
    GtwTimeout:=1000;
    GtwTiempoCmnd:=100;

    for i:=1 to NoElemStrEnter(variables) do begin
      variable:=ExtraeElemStrEnter(variables,i);
      if UpperCase(ExtraeElemStrSep(variable,1,'='))='DECIMALESGILBARCO' then
        DecimalesGilbarco:=StrToInt(ExtraeElemStrSep(variable,2,'='))
      else if UpperCase(ExtraeElemStrSep(variable,1,'='))='DIGITOSGILBARCO' then
        DigGilbarco:=StrToInt(ExtraeElemStrSep(variable,2,'='))
      else if UpperCase(ExtraeElemStrSep(variable,1,'='))='GTWDIVPRESETLTS' then
        GtwDivPresetLts:=StrToIntDef(ExtraeElemStrSep(variable,2,'='),100)
      else if UpperCase(ExtraeElemStrSep(variable,1,'='))='GTWDIVPRESETPESOS' then
        GtwDivPresetPesos:=StrToIntDef(ExtraeElemStrSep(variable,2,'='),100)
      else if UpperCase(ExtraeElemStrSep(variable,1,'='))='GTWDIVPRECIO' then
        GtwDivPrecio:=StrToIntDef(ExtraeElemStrSep(variable,2,'='),100)
      else if UpperCase(ExtraeElemStrSep(variable,1,'='))='GTWDIVIMPORTE' then
        GtwDivImporte:=StrToIntDef(ExtraeElemStrSep(variable,2,'='),100)
      else if UpperCase(ExtraeElemStrSep(variable,1,'='))='GTWDIVLITROS' then
        GtwDivLitros:=StrToIntDef(ExtraeElemStrSep(variable,2,'='),100)
      else if UpperCase(ExtraeElemStrSep(variable,1,'='))='GTWDIVTOTLTS' then
        GtwDivTotLts:=StrToIntDef(ExtraeElemStrSep(variable,2,'='),100)
      else if UpperCase(ExtraeElemStrSep(variable,1,'='))='GTWDIVTOTIMPORTE' then
        GtwDivTotImporte:=StrToIntDef(ExtraeElemStrSep(variable,2,'='),100)
      else if UpperCase(ExtraeElemStrSep(variable,1,'='))='GTWTIMEOUT' then
        GtwTimeout:=StrToIntDef(ExtraeElemStrSep(variable,2,'='),1000)
      else if UpperCase(ExtraeElemStrSep(variable,1,'='))='GTWTIEMPOCMND' then
        GtwTiempoCmnd:=StrToIntDef(ExtraeElemStrSep(variable,2,'='),100);
    end;

    Result:=AgregaPosCarga(dispensarios);

    if Result<>'' then
      Exit;

    productos := js.Field['Products'];

    for i:=0 to productos.Count-1 do begin
      productID:=productos.Child[i].Field['ProductId'].Value;
      if productos.Child[i].Field['Price'].Value<0 then begin
        Result:='False|El precio '+IntToStr(productID)+' es incorrecto|';
        Exit;
      end;
      LPrecios[productID]:=productos.Child[i].Field['Price'].Value;
    end;

    PreciosInicio:=False;
    estado:=0;
    Result:='True|';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;


function Togcvdispensarios_gilbarco2W.NoElemStrEnter(xstr: string): word;
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

function Togcvdispensarios_gilbarco2W.ExtraeElemStrEnter(xstr: string;
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

procedure Togcvdispensarios_gilbarco2W.ProcesaComandos;
var ss,rsp,ss2,precios       :string;
    xcmnd,xpos,xcomb,i,xc,
    xp,xfolio                :integer;
    ximporte,xlitros  :real;
    precioComb:Double;
begin
  try
    if (minutosLog>0) and (MinutesBetween(Now,horaLog)>=minutosLog) then begin
      horaLog:=Now;
      GuardarLog;
    end;
    // Checa Comandos
    for xcmnd:=1 to 200 do begin
      if (TabCmnd[xcmnd].SwActivo)and(not TabCmnd[xcmnd].SwResp) then begin
        SwAplicaCmnd:=true;
        ss:=ExtraeElemStrSep(TabCmnd[xcmnd].Comando,1,' ');
        AgregaLog(TabCmnd[xcmnd].Comando);
        // ORDENA CARGA DE COMBUSTIBLE
        if ss='OCC' then begin
          xpos:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,2,' '),0);
          rsp:='OK';
          if (xpos in [1..MaxPosCarga]) then begin
            if (TPosCarga[xpos].estatus in [1,5]) then begin
              try
                xImporte:=StrToFLoat(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,3,' '));
                xLitros:=0;
                if TPosCarga[xPos].DigitosGilbarco=8 then
                  rsp:=ValidaCifra(xImporte,6,2)
                else
                  rsp:=ValidaCifra(xImporte,4,2);
                if rsp='OK' then
                  if (xImporte<0.50) then
                    ximporte:=0;
                TPosCarga[xpos].MontoPreset:='$ '+FormatoMoneda(xImporte);
              except
                rsp:='Error en Importe';
              end;
              if rsp='OK' then begin
                TPosCarga[xpos].tipopago:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,5,' '),0);
                if rsp='OK' then begin
                  if (TPosCarga[xpos].estatus in [1,5,9]) then begin
                    ss:=ExtraeElemStrSep(TabCmnd[xcmnd].Comando,4,' ');
                    xcomb:=StrToIntDef(ss,0);
                    xp:=PosicionDeCombustible(xpos,xcomb);
                    TPosCarga[xpos].Esperafinventa:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,6,' '),0);
                    // Preset Pesos
                    if TPosCarga[xPos].DigitosGilbarco=6 then begin
                      if ximporte>0 then begin
                        if EnviaPresetBomba6(xpos,xp,1,ximporte,0) then
                        begin
                          if Autoriza(xpos) then begin
                            TPosCarga[xpos].SwPreset:=true;
                          end
                          else rsp:='No se pudo autorizar';
                        end
                        else rsp:='No se pudo prefijar';
                      end
                      else begin
                        if Autoriza(xpos) then begin
                          TPosCarga[xpos].SwPreset:=true;
                        end
                        else rsp:='No se pudo autorizar';
                      end;
                    end
                    else begin
                      if ximporte>0 then begin
                        if EnviaPresetBomba8(xpos,xp,1,ximporte,0) then
                        begin
                          if Autoriza(xpos) then begin
                            TPosCarga[xpos].SwPreset:=true;
                          end
                          else rsp:='No se pudo autorizar';
                        end
                        else rsp:='No se pudo prefijar';
                      end
                      else begin
                        if Autoriza(xpos) then begin
                          TPosCarga[xpos].SwPreset:=true;
                        end
                        else rsp:='No se pudo autorizar';
                      end;
                    end;
                    // Fin
                  end
                  else rsp:='Posicion de Carga no Disponible';
                end;
              end;
            end
            else rsp:='Posicion de Carga no Disponible';
          end
          else rsp:='Posicion de Carga no Existe';
        end
        else if ss='OCL' then begin
          xpos:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,2,' '),0);
          rsp:='OK';
          if (xpos in [1..MaxPosCarga]) then begin
            if (TPosCarga[xpos].estatus in [1,5]) then begin
              try
                xLitros:=StrToFLoat(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,3,' '));
                xImporte:=0;
                rsp:=ValidaCifra(xLitros,3,2);
                if rsp='OK' then
                  if (xLitros<0.10) then
                    xLitros:=999;
                TPosCarga[xpos].MontoPreset:=FormatoMoneda(xLitros)+' lts';
              except
                rsp:='Error en Litros';
              end;
              if rsp='OK' then begin
                TPosCarga[xpos].tipopago:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,5,' '),0);
                if rsp='OK' then begin
                  if (TPosCarga[xpos].estatus in [1,5,9]) then begin
                    ss:=ExtraeElemStrSep(TabCmnd[xcmnd].Comando,4,' ');
                    xcomb:=StrToIntDef(ss,0);
                    xp:=PosicionDeCombustible(xpos,xcomb);
                    TPosCarga[xpos].Esperafinventa:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,6,' '),0);
                    // Preset Litros
                    if TPosCarga[xPos].DigitosGilbarco=6 then begin
                      if EnviaPresetBomba6(xpos,xp,1,0,xlitros) then begin
                        if Autoriza(xpos) then begin
                          TPosCarga[xpos].SwPreset:=true;
                        end
                        else rsp:='No se pudo autorizar';
                      end
                      else rsp:='No se pudo prefijar';
                    end
                    else begin
                      if EnviaPresetBomba8(xpos,xp,1,0,xlitros) then begin
                        if Autoriza(xpos) then begin
                          TPosCarga[xpos].SwPreset:=true;
                        end
                        else rsp:='No se pudo autorizar';
                      end
                      else rsp:='No se pudo prefijar';
                    end;
                    // Fin
                  end
                  else rsp:='Posicion de Carga no Disponible';
                end;
              end;
            end
            else rsp:='Posicion de Carga no Disponible';
          end
          else rsp:='Posicion de Carga no Existe';

        end
        // ORDENA FIN DE VENTA
        else if ss='FINV' then begin
          xpos:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,2,' '),0);
          rsp:='OK';
          if (xpos in [1..MaxPosCarga]) then begin
            TPosCarga[xpos].tipopago:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,3,' '),0);
            if (TPosCarga[xpos].Estatus in [3,4]) then begin // EOT
              if (not TPosCarga[xpos].swcargando) then
                TPosCarga[xpos].esperafinventa:=0
              else begin
                if (TPosCarga[xpos].swcargando)and(TPosCarga[xpos].Estatus=1) then begin
                  TPosCarga[xpos].swcargando:=false;
                  TPosCarga[xpos].esperafinventa:=0;
                  rsp:='OK';
                end
                else rsp:='Posicion no esta despachando';
              end;
            end
            else  // EOT
              rsp:='Posicion aun no esta en fin de venta';
          end
          else rsp:='Posicion de Carga no Existe';

        end
        // CMND: DESAUTORIZA VENTA DE COMBUSTIBLE
        else if (ss='DVC') then begin
          rsp:='OK';
          xpos:=strtointdef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,2,' '),0);
          if xpos in [1..MaxPosCarga] then begin
            if (TPosCarga[xpos].estatus in [2,9]) then begin
              if DetenerDespacho(xpos) then begin
              end;
            end;
          end;
        end
        else if (ss='REANUDAR') then begin
          rsp:='OK';
          xpos:=strtointdef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,2,' '),0);
          if xpos in [1..MaxPosCarga] then begin
            if (TPosCarga[xpos].estatus in [8]) then begin
              if ReanudaDespacho(xpos) then begin
              end;
            end;
          end;
        end
        else if (ss='TOTAL') then begin
          xpos:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,2,' '),0);;
          rsp:='OK';
          with TPosCarga[xpos] do begin
            if TabCmnd[xcmnd].SwNuevo then begin
              swtotales:=True;
              TabCmnd[xcmnd].SwNuevo:=false;
            end;
            if not swtotales then begin
              rsp:='OK'+FormatFloat('0.000',ToTalLitros[1])+'|'+FormatoMoneda(ToTalLitros[1]*LPrecios[TComb[1]])+'|'+
                              FormatFloat('0.000',ToTalLitros[2])+'|'+FormatoMoneda(ToTalLitros[2]*LPrecios[TComb[2]])+'|'+
                              FormatFloat('0.000',ToTalLitros[3])+'|'+FormatoMoneda(ToTalLitros[3]*LPrecios[TComb[3]])+'|';
              SwAplicaCmnd:=True;
            end
            else
              SwAplicaCmnd:=False;
          end;
        end
        else if (ss='CPREC') then begin
          precios:=ExtraeElemStrSep(TabCmnd[xcmnd].Comando,2,' ');
          for xpos:=1 to MaxPosCarga do begin
            with TPosCarga[xpos] do if xpos<=MaximoDePosiciones then begin
              for i:=1 to NoComb do begin
                precioComb:=StrToFloatDef(ExtraeElemStrSep(precios,TComb[i],'|'),-1);
                if precioComb=-1 then begin
                  rsp:='El precio '+IntToStr(i)+' es incorrecto|';
                  Exit;
                end;
                if precioComb<=0 then
                  Continue;
                LPrecios[TComb[i]]:=precioComb;
                AgregaLog('E> Cambio de precios: '+inttoclavenum(xpos,2));
                AgregaLog('PrecioComb: '+FloatToStr(precioComb));
                if TPosCarga[xpos].DigitosGilbarco=6 then begin
                  if CambiaPrecio6(xpos,TMang[i],1,precioComb) then begin
                    Sleep(200);
                    if not CambiaPrecio6(xpos,i,2,precioComb) then
                      rsp:='Error en cambio de precios';
                  end
                  else
                    rsp:='Error en cambio de precios';
                end
                else begin
                  if CambiaPrecio8(xpos,TMang[i],1,precioComb) then begin
                    Sleep(200);
                    if not CambiaPrecio8(xpos,i,2,precioComb) then
                      rsp:='Error en cambio de precios';
                  end
                  else
                    rsp:='Error en cambio de precios';
                end;
              end;
            end;
          end;
        end
        else rsp:='Comando no Soportado o no Existe';
        TabCmnd[xcmnd].SwNuevo:=false;
        if SwAplicaCmnd then begin
          if rsp='' then
            rsp:='OK';
          TabCmnd[xcmnd].SwResp:=true;
          TabCmnd[xcmnd].Respuesta:=rsp;
          AgregaLog(LlenaStr(TabCmnd[xcmnd].Comando,'I',40,' ')+' Respuesta: '+TabCmnd[xcmnd].Respuesta);
        end;
      end;
    end;
  except
  end;
end;

function Togcvdispensarios_gilbarco2W.ValidaCifra(xvalor: real; xenteros,
  xdecimales: byte): string;
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

function Togcvdispensarios_gilbarco2W.Autoriza(PosCarga: integer): boolean;
begin
   result:= ( TransmiteComando($10,PosCarga,'') );
end;

function Togcvdispensarios_gilbarco2W.DetenerDespacho(
  xNPos: integer): boolean;
begin
   result:= ( TransmiteComando($30,xNPos,'') );
end;

function Togcvdispensarios_gilbarco2W.ReanudaDespacho(
  PosCarga: integer): boolean;
begin
   result:= ( TransmiteComando($10,PosCarga,'') );
end;

function Togcvdispensarios_gilbarco2W.PonNivelPrecio(xNPos,
  xNPrec: integer): boolean;
var sPriceLevel, sDataBlock : string;
begin
   if ( xNPrec=1 ) then
      sPriceLevel:= #$F4
   else
      sPriceLevel:= #$F5;
   sDataBlock:= sPriceLevel + #$FB;
   sDataBlock:= #$FF + DLChar(sDataBlock) + sDataBlock;
   sDataBlock:= sDataBlock + LrcCheckChar(sDataBlock) + #$F0;
   result:= ( TransmiteComando($20,xNPos,sDataBlock) );
end;

function Togcvdispensarios_gilbarco2W.EnviaPresetFlu(xpos: integer;
  xsube: boolean): boolean;
var ximporte:real;
begin
  result:=true;
  try
    if xsube then
      ximporte:=StrToIntDef(Valorx+inttostr(tagx[1]),0)/100
    else
      ximporte:=StrToIntDef(Valorx+'0',0)/100;
    AgregaLog('Preset Posicion '+inttoclavenum(xpos,2)+' $'+FormatoMoneda(ximporte));
    if TPosCarga[xPos].DigitosGilbarco=6 then begin
      if EnviaPresetBomba6(xpos,1,1,ximporte,0) then
      begin
        if Autoriza(xpos) then begin
          TPosCarga[xpos].SwPreset:=true;
        end
        else result:=false;
      end
      else result:=false;
    end
    else begin
      if EnviaPresetBomba8(xpos,1,1,ximporte,0) then
      begin
        if Autoriza(xpos) then begin
          TPosCarga[xpos].SwPreset:=true;
        end
        else result:=false;
      end
      else result:=false;
    end;
  except
    result:=false;
  end;
end;

procedure Togcvdispensarios_gilbarco2W.Timer1Timer(Sender: TObject);
label L01;
var xvolumen,n1,n2,n3:real;
    xcomb,xpos,xp,xgrade,i,xsuma:integer;
    xtotallitros:array[1..4] of real;
begin
  if ContadorAlarma>=10 then begin
    if ContadorAlarma=10 then
      AgregaLog('Error Comunicacion Dispensarios');
  end;
  
  if (swespera)and((now-horaespera)>3*tmsegundo) then
    swespera:=false;
  if not SwEspera then begin
    if not SwPasoBien then begin
      swespera:=false;
      inc(ContadorAlarma);
      goto L01;
    end;
    SwPasoBien:=false;
    SwEspera:=true;
    HoraEspera:=Now;
    if PosCiclo in [1..MaxPosCarga] then with TPosCarga[PosCiclo] do begin
      try
        case NumPaso of
          0:if (estatus=1)and(SwNivelPrecio) then begin     // NIVEL DE PRECIOS
              if (Now>=HoraNivelPrecio) then begin
                if not swdeshabil then begin   // no polea los que estan deshabilitados
                  AgregaLog('E> Pon Nivel Precio: '+inttoclavenum(PosCiclo,2));
                  if PonNivelPrecio(PosCiclo,1) then begin
                    swnivelprecio:=false;
                  end;
                end;
              end;
            end;
          1:begin                           // ESTATUS
              try
                if not swdeshabil then begin   // no polea los que estan deshabilitados
                  EstatusAnt:=Estatus;
                  Estatus:=DameEstatus(PosCiclo);    // Aqui bota cuando no hay posicion activa
                  EstatusDispensarios;
                  ContadorAlarma:=0;
                  if (Estatusant=0)and(estatus=1) then begin
                    SwNivelPrecio:=true;
                    HoraNivelPrecio:=Now+5*TMSegundo;
                    Swleeventa:=true;
                    SwTotales:=true;
                  end;
                  if (EstatusAnt in [3,4])and(Estatus=1) then begin // Termina Venta
                    swcargando:=false;
                    if EsperaFinVenta=1 then
                      Estatus:=4
                    else
                      SwTotales:=true;
                  end;
                end;
              except
                DespliegaMemo4('Error Estatus Pos: '+inttostr(PosCiclo));
                AvanzaPosCiclo;
                NumPaso:=1;
                exit;
              end;
            end;
          2:if (swleeventa)and(estatus>0) then begin       // LEE VENTA TERMINADA
              if not swdeshabil then begin   // no polea los que estan deshabilitados
                if TPosCarga[PosCiclo].DigitosGilbarco=6 then begin
                  AgregaLog('E> FIN DE VENTA(6): '+inttoclavenum(PosCiclo,2));
                  if DameLecturas6(PosCiclo,PosActual,
                                               Volumen,Precio,Importe) then
                  begin
                    HoraOcc:=Now;
                    xvolumen:=ajustafloat(dividefloat(importe,precio),3);
                    if abs(volumen-xvolumen)>0.5 then
                      volumen:=xvolumen;
                    AgregaLog('R> '+FormatFloat('###,##0.00',Volumen)+' / '+FormatFloat('###,##0.00',precio)+' / '+FormatFloat('###,##0.00',importe));
                    swleeventa:=false;
                  end;
                end
                else begin
                  AgregaLog('E> FIN DE VENTA(8): '+inttoclavenum(PosCiclo,2));
                  if DameLecturas8(PosCiclo,PosActual,
                                               Volumen,Precio,Importe) then
                  begin
                    HoraOcc:=Now;
                    xvolumen:=ajustafloat(dividefloat(importe,precio),3);
                    if abs(volumen-xvolumen)>0.5 then
                      volumen:=xvolumen;
                    AgregaLog('R> '+FormatFloat('###,##0.00',Volumen)+' / '+FormatFloat('###,##0.00',precio)+' / '+FormatFloat('###,##0.00',importe));
                    swleeventa:=false;
                  end;
                end;
              end;
            end;
          3:if (swtotales)and(estatus>0) then begin        // LEE TOTALES
              if not swdeshabil then begin   // no polea los que estan deshabilitados
                if DigitosGilbarco=6 then begin
                  AgregaLog('E> Lee Totales(6): '+inttoclavenum(PosCiclo,2));
                  if DameTotales6(PosCiclo,
                                          xTotalLitros[1],n1,
                                          xTotalLitros[2],n2,
                                          xTotalLitros[3],n3)then
                  begin
                    for i:=1 to nocomb do begin
                      xcomb:=Tcomb[i];
                      xp:=PosicionDeCombustible(PosCiclo,xcomb);
                      if xp>0 then begin
                        TotalLitros[xp]:=xTotalLitros[xp];
                      end;
                    end;
                    AgregaLog('R> '+FormatFloat('###,###,##0.00',TotalLitros[1])+' / '+FormatFloat('###,###,##0.00',TotalLitros[2])+' / '+FormatFloat('###,###,##0.00',TotalLitros[3]));
                    SwTotales:=false;
                  end;
                end
                else begin
                  AgregaLog('E> Lee Totales(8): '+inttoclavenum(PosCiclo,2));
                  if DameTotales8(PosCiclo,
                                          xTotalLitros[1],n1,
                                          xTotalLitros[2],n2,
                                          xTotalLitros[3],n3)then
                  begin
                    for i:=1 to nocomb do begin
                      xcomb:=Tcomb[i];
                      xp:=PosicionDeCombustible(PosCiclo,xcomb);
                      if xp>0 then begin
                        TotalLitros[xp]:=xTotalLitros[xp];
                      end;
                    end;
                    AgregaLog('R> '+FormatFloat('###,###,##0.00',TotalLitros[1])+' / '+FormatFloat('###,###,##0.00',TotalLitros[2])+' / '+FormatFloat('###,###,##0.00',TotalLitros[3]));
                    SwTotales:=false;
                  end;
                end;
              end;
            end;
          4:if (estatus=5)and(ModoOpera='Normal') then begin // AUTORIZA TANQUE LLENO
              if not swdeshabil then begin   // no polea los que estan deshabilitados
                AgregaLog('E> Autoriza: '+inttoclavenum(PosCiclo,2));
                Autoriza(PosCiclo);
              end;
            end;
          5:if estatus=2 then begin                 // LEE VENTA PROCESO
              if not swdeshabil then begin   // no polea los que estan deshabilitados
                if TPosCarga[PosCiclo].DigitosGilbarco=6 then begin
                  AgregaLog('E> Lee Venta Proc(6): '+inttoclavenum(PosCiclo,2));
                  if DameVentaProceso6(PosCiclo,Importe) then begin
                    volumen:=0;
                    precio:=0;
                    AgregaLog('R> '+FormatFloat('###,##0.00',importe));
                  end;
                end
                else begin
                  AgregaLog('E> Lee Venta Proc(8): '+inttoclavenum(PosCiclo,2));
                  if DameVentaProceso8(PosCiclo,Importe) then begin
                    volumen:=0;
                    precio:=0;
                    AgregaLog('R> '+FormatFloat('###,##0.00',importe));
                  end;
                end;
              end;
            end;
          6:ProcesaComandos;
          7:begin          // CAMBIA PRECIO
              if not swdeshabil then begin   // no polea los que estan deshabilitados
                for xp:=1 to NoComb do begin
                  if Estatus=1 then begin
                    if TCambioPrecN1[xp] then begin
                      if TPosCarga[PosCiclo].DigitosGilbarco=6 then begin
                        AgregaLog('E> Cambia Precio(6): '+inttoclavenum(PosCiclo,2)+' - '+inttoclavenum(xp,2));
                        if CambiaPrecio6(PosCiclo,xp,1,TNuevoPrec[xp]) then begin
                          TCambioPrecN1[xp]:=false;
                        end;
                      end
                      else begin
                        AgregaLog('E> Cambia Precio(8): '+inttoclavenum(PosCiclo,2)+' - '+inttoclavenum(xp,2));
                        if CambiaPrecio8(PosCiclo,xp,1,TNuevoPrec[xp]) then begin
                          TCambioPrecN1[xp]:=false;
                        end;
                      end;
                    end
                    else if TCambioPrecN2[xp] then begin
                      if TPosCarga[PosCiclo].DigitosGilbarco=6 then begin
                        AgregaLog('E> Cambia Precio(6): '+inttoclavenum(PosCiclo,2)+' - '+inttoclavenum(xp,2));
                        if CambiaPrecio6(PosCiclo,xp,1,TNuevoPrec[xp]) then begin
                          TCambioPrecN2[xp]:=false;
                        end;
                      end
                      else begin
                        AgregaLog('E> Cambia Precio(8): '+inttoclavenum(PosCiclo,2)+' - '+inttoclavenum(xp,2));
                        if CambiaPrecio8(PosCiclo,xp,1,TNuevoPrec[xp]) then begin
                          TCambioPrecN2[xp]:=false;
                        end;
                      end;
                    end;
                  end;
                end;
              end;
            end;
        end;
      finally
        swespera:=false;
      end;
L01:
      SwPasoBien:=true;
      with TPosCarga[PosCiclo] do begin
        case estatus of
          2:swcargando:=true;
          3:if NumPaso=1 then begin
              SwLeeVenta:=true;
              ContLeeVenta:=0;
              if estatusant<>3 then
                swfinventa:=true;
            end;
        end;

        inc(NumPaso);
        if (NumPaso=2)and(not SwLeeVenta) then
          NumPaso:=3;
        if (NumPaso=3) then begin
          if (swleeventa)and(contleeventa<3) then begin
            NumPaso:=2;
            inc(contleeventa);
          end
          else if (not SwTotales) then
            NumPaso:=4;
        end;
        if (NumPaso=4)and(estatus<>5) then
          NumPaso:=5;
        if (NumPaso=5)and(estatus<>2) then
          NumPaso:=6;

        //
        if NumPaso>=8 then begin
          AvanzaPosCiclo;
          NumPaso:=1;
          if SwNivelPrecio then
            NumPaso:=0;
        end;
      end;
    end
    else posciclo:=1;
  end;
end;

function Togcvdispensarios_gilbarco2W.DameEstatus(
  PosCarga: integer): integer;
var iStatus : integer;
begin
   iStatus:= 0;
   if ( ( TransmiteComando($00,PosCarga,'') ) and ( length(sRespuesta)>=1 ) ) then case ( HiNibbleChar(sRespuesta[1]) ) of
       $6,$E  : iStatus:= 1;
       $9,$1  : iStatus:= 2;
     $A,$B,$3 : iStatus:= 3;
        $0    : iStatus:= 0;
        $7    : iStatus:= 5;
       $C,$F  : iStatus:= 8;
        $8    : iStatus:= 9;
   end;
   result:= iStatus;
end;

procedure Togcvdispensarios_gilbarco2W.EstatusDispensarios;
var ss,lin,xestado,xmodo:string;
    xpos,xcomb:integer;
begin
  lin:='';xestado:='';xmodo:='';
  for xpos:=1 to MaxPosCarga do with TPosCarga[xpos] do begin
    xmodo:=xmodo+ModoOpera[1];
    if not SwDesHabil then begin
      case estatus of
        0:xestado:=xestado+'0'; // Sin Comunicaciï¿½n
        1:xestado:=xestado+'1'; // Inactivo (Idle)
        2:xestado:=xestado+'2'; // Cargando (In Use)
        3,4:if not swcargando then
            xestado:=xestado+'3' // Fin de Carga (Used)
          else
            xestado:=xestado+'2';
        5:xestado:=xestado+'5'; // Llamando (Calling) Pistola Levantada
        9:xestado:=xestado+'9'; // Autorizado
        8:xestado:=xestado+'8'; // Detenido (Stoped)
        else xestado:=xestado+'0';
      end;
    end
    else xestado:=xestado+'7'; // Deshabilitado
    xcomb:=CombustibleEnPosicion(xpos,PosActual);
    CombActual:=xcomb;
    MangActual:=TMang[NoComb];
    ss:=inttoclavenum(xpos,2)+'/'+inttostr(xcomb);
    ss:=ss+'/'+FormatFloat('###0.##',volumen);
    ss:=ss+'/'+FormatFloat('#0.##',precio);
    ss:=ss+'/'+FormatFloat('####0.##',importe);
    lin:=lin+'#'+ss;
  end;
  EstatusAct:=xestado;
  if lin='' then
    lin:=xestado+'#'
  else
    lin:=xestado+lin;
  lin:=lin+'&'+xmodo;
  if (EstatusAct<>EstatusAnt) then begin
    AgregaLog('Estatus Disp: '+EstatusAct);
    EstatusAnt:=EstatusAct;
  end;
end;

procedure Togcvdispensarios_gilbarco2W.AvanzaPosCiclo;
begin
  inc(PosCiclo);
  if PosCiclo>MaxPosCarga then begin
    EstatusDispensarios;
    PosCiclo:=1;
  end;
end;

procedure Togcvdispensarios_gilbarco2W.pSerialTriggerData(CP: TObject;
  TriggerHandle: Word);
begin
   if ( TriggerHandle=wTriggerEOT ) then
      bEndOfText:= true
   else
      bLineFeed:= true;
end;

procedure Togcvdispensarios_gilbarco2W.pSerialTriggerAvail(CP: TObject;
  Count: Word);
var i : integer;
begin
   for i:=1 to Count do sRespuesta:= sRespuesta + pSerial.GetChar;
   i:= length(sRespuesta);
   if ( ( i>=iBytesEsperados ) or ( bEndOfText )  or ( bLineFeed ) ) then
      bListo:= true
   else
      newtimer(etTimeOut,MSecs2Ticks(GtwTimeout));
end;

procedure Togcvdispensarios_gilbarco2W.DespliegaMemo4(lin: string);
begin
  AgregaLog('>> '+lin);
end;

procedure Togcvdispensarios_gilbarco2W.EjecutaBuffer;
var
  objBuffer:TBuffer;
  metodoEnum:TMetodos;
begin
  try
    if Buffer.Count=0 then
      Exit;
    AgregaLog('Ejecutó buffer');
    objBuffer:=Buffer[0];
    with objBuffer do begin
      AgregaLog('Comando buffer:'+comando);
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
          Socket.SendText(Key.Encrypt(ExtractFilePath(ParamStr(0)), key3DES, 'DISPENSERS|LOG|'+ObtenerLog(StrToIntDef(parametro, 0))));
        LOGREQ_e:
          Socket.SendText(Key.Encrypt(ExtractFilePath(ParamStr(0)), key3DES, 'DISPENSERS|LOGREQ|'+ObtenerLogPetRes(StrToIntDef(parametro, 0))));
      else
        Responder(Socket, 'DISPENSERS|'+comando+'|False|Comando desconocido|');
      end;
    end;

    Buffer.Delete(0);
  except
    on e:Exception do begin
      if (claveCre<>'') and (key3DES<>'') then
        AgregaLogPetRes('Error EjecutaBuffer: '+e.Message+'//Clave CRE: '+claveCre+'//Terminacion de Key 3DES: '+copy(key3DES,Length(key3DES)-3,4))
      else
        AgregaLogPetRes('Error EjecutaBuffer: '+e.Message);
      GuardarLogPetRes;
      Responder(objBuffer.Socket,'DISPENSERS|'+objBuffer.comando+'|False|'+e.Message+'|');
    end;
  end;
end;

end.
