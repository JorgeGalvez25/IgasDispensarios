unit UIGASKAIROS;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, SvcMgr, Dialogs,
  ScktComp, ExtCtrls, OoMisc, AdPort, IniFiles, ActiveX, ComObj, ULIBGRAL, CRCs,
  IdHashMessageDigest, IdHash, uLkJSON;

const
      _poly=$1D;
      ValorX='957.3';  

type
  Togcvdispensarios_kairos = class(TService)
    ServerSocket1: TServerSocket;
    Timer1: TTimer;
    pSerial: TApdComPort;
    procedure ServiceExecute(Sender: TService);
    procedure ServerSocket1ClientRead(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure Timer1Timer(Sender: TObject);
    procedure pSerialTriggerAvail(CP: TObject; Count: Word);
  private
    { Private declarations }
    SwEsperaComando,
    SwPasoBien      :boolean;
    PosCiclo,ls,
    ContLeeVenta,
    ContadorAlarma,
    NumPaso         :integer;
    SwAplicaCmnd,
    SwInicio,
    SwBring,
    SwEspera     :boolean;
    Canales,ConfAdic:String;
    wTriggerEOT, wTriggerLF : word;
    HoraEspera      :TDateTime;
    srespuesta : string;
    iBytesEsperados : integer;
    bListo, bEndOfText, bLineFeed : boolean;
    etTimeOut : EventTimer;  
   function  DataControlWordValue(chDataControlWord : char; iLongitud : integer) : longint;
   function  TransmiteComando(iComando, xNPos: integer; sDataBlock: string) : boolean;
   procedure  TransmiteComandoEsp(sDataBlock: string) ;
  public
    ListaLog:TStringList;
    ListaLogPetRes:TStringList;
    rutaLog:string;
    confPos:string;
    licencia:string;
    detenido:Boolean;
    estado:Integer;
    horaLog:TDateTime;
    minutosLog:Integer;
  // CONTROL TRAFICO COMANDOS
    ListaCmnd    :TStrings;  
    LinCmnd      :string;
    CharCmnd     :char;
    SwEsperaRsp  :boolean;
    FolioCmnd   :integer;
    DecimalesGilbarco :Integer;

    GtwDivPresetLts,        // Divisor preset litros           **
    GtwDivPresetPesos,      // Divisor preset pesos            **

    GtwDivPrecio,           // Divisor precio para lecturas y cambio de precios       **
    GtwDivImporte,          // Divisor importe para lecturas y ventas                 **
    GtwDivLitros,           // Divisor litros para ventas                             **

    GtwDivTotLts,           // Divisor totales litros     **
    GtwDivTotImporte,       // Divisor totales pesos      **

    GtwTimeOut,             // Timeout miliseg
    GtwKairosFrec,
    GtwTiempoCmnd :integer; // Tiempo entre comandos miliseg
    version:String;
    function  PonNivelPrecio(xNPos, xNPrec : integer) : boolean;
    function  DameEstatus(PosCarga:integer) : integer;
    procedure EstatusDispensarios;
    function CombustibleEnPosicion(xpos,xpc:integer):integer;
    function  Autoriza(PosCarga: integer) : boolean;
    procedure MandaFlujoPos(xpos,xvalor:integer);
    function  DetenerDespacho(xNPos : integer) : boolean;
    procedure AvanzaPosCiclo;
    function  DameLecturas6(xNPos : integer; var xNMang : integer; var rLitros, rPrecio, rPesos : real) : boolean;
    function  DameLecturas8(xNPos : integer; var xNMang : integer; var rLitros, rPrecio, rPesos : real) : boolean;
    function  DameTotales6(xNPos : integer; var rTotalizadorLitros1, rTotalizadorPesos1, rTotalizadorLitros2, rTotalizadorPesos2, rTotalizadorLitros3, rTotalizadorPesos3 : real) : boolean;
    function  DameTotales8(xNPos : integer; var rTotalizadorLitros1, rTotalizadorPesos1, rTotalizadorLitros2, rTotalizadorPesos2, rTotalizadorLitros3, rTotalizadorPesos3 : real) : boolean;
    function PosicionDeCombustible(xpos,xcomb:integer):integer;
    function  DameVentaProceso6(xNPos : integer; var rPesos : real) : boolean;
    function  DameVentaProceso8(xNPos : integer; var rPesos : real) : boolean;
    procedure ProcesaComandos;
    function ValidaCifra(xvalor:real;xenteros,xdecimales:byte):string;
    function  CambiaPrecio6(xNPos, xNMang, xNPrec : integer; rPrecio : real) : boolean;
    function  CambiaPrecio8(xNPos, xNMang, xNPrec : integer; rPrecio : real) : boolean;
    function  EnviaPresetBomba6(xNPos, xNMang, xNPrec: integer; rPesos, rLitros: real) : boolean;
    function  EnviaPresetBomba8(xNPos, xNMang, xNPrec: integer; rPesos, rLitros: real) : boolean;
    function  ReanudaDespacho(PosCarga: integer) : boolean;

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
    function AutorizarVenta(msj: string): string;
    function DetenerVenta(msj: string): string;
    function ReanudarVenta(msj: string): string;
    function FluStd(msj: string):string;
    function FluMin:string;    
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
       Canal,
       PosActual    :integer; // Posicion del combustible en proceso: 1..NoComb
       NoComb       :integer; // Cuantos combustibles hay en la posicion
       TComb        :array[1..4] of integer; // Claves de los combustibles
       TPosx        :array[1..4] of integer;
       TMang        :array[1..4] of integer;
       TotalLitros  :array[1..4] of real;

       MontoPreset    :string;
       ImportePreset  :real;

       swprec,
       swestatus0,
       swautoriza,
       swcargando     :boolean;
       ModoOpera      :string[8];
       TipoPago       :integer;
       EsperaFinVenta :integer;

       SwFinVenta,
       SwLeeVenta,
       SwTotales,
       SwNivelPrecio,
       SwCambiaPrecio,
       SwRepitePos,
       //swaux,
       SwPreset       :boolean;
       HoraNivelPrecio:TDateTime;

       StPresetPos,
       StKairosFrec,
       StFluPos,
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

const idSTX = #2;
      idETX = #3;
      idACK = #6;
      idNAK = #21;
      MaximoDePosiciones = 32;

type TMetodos = (NOTHING_e, INITIALIZE_e, PARAMETERS_e, LOGIN_e, LOGOUT_e,
             PRICES_e, AUTHORIZE_e, STOP_e, START_e, SELFSERVICE_e, FULLSERVICE_e,
             BLOCK_e, UNBLOCK_e, PAYMENT_e, TRANSACTION_e, STATUS_e, TOTALS_e, HALT_e,
             RUN_e, SHUTDOWN_e, TERMINATE_e, STATE_e, TRACE_e, SAVELOGREQ_e, RESPCMND_e,
             LOG_e, LOGREQ_e, EJECCMND_e, FLUSTD_e, FLUMIN_e);  

var
  ogcvdispensarios_kairos: Togcvdispensarios_kairos;
  key:OleVariant;
  claveCre,key3DES:string;
  Token:string;
  Licencia3Ok  :Boolean;
  MaxPosCarga:integer;
  SwCerrar    :boolean;
  TabCmnd  :array[1..200] of RegCmnd;
  TPosCarga   :array[1..32] of tiposcarga;
  LPrecios :array[1..4] of Double;
  SwCmndPend  :boolean;
  IdCmndPend,
  PosCmndPend  :integer;
  Tagx        :array[1..3] of integer;
  EstatusAct,EstatusAntx  :string;
  Swflu       :boolean;
  TAdicf        :array[1..32,1..3] of integer;

implementation

uses TypInfo, StrUtils, Variants, DateUtils;

{$R *.DFM}

function crc8(Buffer:String):Cardinal;
var
  i,j: Integer;
begin
  Result:=0;
  for i:=1 to Length(Buffer) do begin
    Result:=Result xor ord(buffer[i]);
    for j:=0 to 7 do begin
      if (Result and $80)<>0 then
        Result:=(Result shl 1) xor _poly
      else
        Result:=Result shl 1;
    end;
  end;
  Result:=Result and $ff;
end;

function EmpacaKairos(xss:string;xpos:integer):string;
var ss:string;
    i:integer;
    ch:char;
begin
  // inserta ESC ($7D)
  if xss='' then begin
    result:=char($FF);
    exit;
  end;


  i:=1;
  repeat
    if (xss[i] in [char($7E),char($7D)]) then begin
      insert(char($7D),xss,i);
      inc(i);
    end;
    inc(i);
  until i>length(xss);


  // fin
  ss:=char(TPosCarga[xpos].Canal)+char(3)+char(1)+char(0)+xss;
  ch:=char(crc8(ss));
  if ch<>char($7E) then
    ss:=ss+ch
  else
    ss:=ss+char($7D)+ch;
  result:=char($7E)+ss+char($7E);
end;

function DesEmpacaKairos(xss:string):string;
var i:integer;
begin
  if length(xss)<7 then begin
    result:=char($FF);
    exit;
  end;
  while (xss[1]<>char($7E))and(length(xss)>7) do
    delete(xss,1,1);
  while (xss[length(xss)]<>char($7E))and(length(xss)>7) do
    delete(xss,length(xss),1);


  if (xss[1]=char($7E))and(xss[length(xss)]=char($7E)) then begin
    // valida EXC ($7D)
    i:=6;
    while (i<=length(xss)-2) do begin
      if (xss[i]=char($7D))and(xss[i+1] in [char($7E),char($7D)]) then begin
        delete(xss,i,1);
        inc(i);
      end;
      inc(i);
    end;
    // fin

    result:=copy(xss,5,length(xss)-6);
  end
  else result:=char($FF);
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
  ogcvdispensarios_kairos.Controller(CtrlCode);
end;

function Togcvdispensarios_kairos.GetServiceController: TServiceController;
begin
  Result := ServiceController;
end;

procedure Togcvdispensarios_kairos.ServiceExecute(Sender: TService);
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

    Canales:=config.ReadString('CONF','Canales','');
    ConfAdic:=config.ReadString('CONF','ConfAdic','');    

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

procedure Togcvdispensarios_kairos.ServerSocket1ClientRead(Sender: TObject;
  Socket: TCustomWinSocket);
  var
    mensaje,comando,checksum,parametro:string;
    i:Integer;
    chks_valido:Boolean;
    metodoEnum:TMetodos;
begin
  mensaje:=Socket.ReceiveText;
  AgregaLogPetRes('R '+mensaje);
  if StrToIntDef(mensaje,-99) in [0,1] then begin
    if Licencia3Ok then begin
      pSerial.Open:=mensaje='1';
      Socket.SendText('1');
    end
    else
      Socket.SendText('False|Licencia CVL7 invalida|');       
    Exit;
  end;
  if UpperCase(ExtraeElemStrSep(mensaje,1,'|'))='DISPENSERSX' then begin
    try
      if NoElemStrSep(mensaje,'|')>=2 then begin

        comando:=UpperCase(ExtraeElemStrSep(mensaje,2,'|'));

        if NoElemStrSep(mensaje,'|')>2 then begin
          for i:=3 to NoElemStrSep(mensaje,'|') do
            parametro:=parametro+ExtraeElemStrSep(mensaje,i,'|')+'|';

          if parametro[Length(parametro)]='|' then
            Delete(parametro,Length(parametro),1);
        end;

        metodoEnum := TMetodos(GetEnumValue(TypeInfo(TMetodos), comando+'_e'));

        case metodoEnum of
          EJECCMND_e:
            Socket.SendText('DISPENSERSX|EJECCMND|True|'+IntToStr(EjecutaComando(parametro))+'|');
          FLUSTD_e:
            Socket.SendText('DISPENSERSX|FLUSTD|'+FluStd(parametro));
          FLUMIN_e:
            Socket.SendText('DISPENSERSX|FLUMIN|'+FluMin);
          RESPCMND_e:
            Socket.SendText('DISPENSERSX|RESPCMND|'+RespuestaComando(parametro));
        else
          Socket.SendText('DISPENSERSX|'+comando+'|False|Comando desconocido|');
        end;
      end
      else
        Socket.SendText('DISPENSERSX|'+mensaje+'|False|Comando desconocido|');
    except
      on e:Exception do begin
        AgregaLogPetRes('Error ServerSocket1ClientRead: '+e.Message);
        GuardarLogPetRes;
        Socket.SendText('DISPENSERSX|'+comando+'|False|'+e.Message+'|');
      end;
    end;
  end
  else begin
    try
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
end;

procedure Togcvdispensarios_kairos.AgregaLog(lin: string);
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

procedure Togcvdispensarios_kairos.AgregaLogPetRes(lin: string);
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

procedure Togcvdispensarios_kairos.Responder(socket: TCustomWinSocket;
  resp: string);
begin
  socket.SendText(#1#2+resp+#3+CRC16(resp)+#23);
  AgregaLogPetRes('E '+#1#2+resp+#3+CRC16(resp)+#23);
end;

function Togcvdispensarios_kairos.FechaHoraExtToStr(
  FechaHora: TDateTime): String;
begin
  result:=FechaPaq(FechaHora)+' '+FormatDatetime('hh:mm:ss.zzz',FechaHora);
end;

function Togcvdispensarios_kairos.CRC16(Data: string): string;
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

function Togcvdispensarios_kairos.Bloquear(msj: string): string;
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

function Togcvdispensarios_kairos.Desbloquear(msj: string): string;
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

function Togcvdispensarios_kairos.Detener: string;
begin
  try
    if estado=-1 then begin
      Result:='False|El proceso no se ha iniciado aun|';
      Exit;
    end;

    if not detenido then begin
      pSerial.Open:=False;
      pSerial.Tracing:= tlOff;
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

function Togcvdispensarios_kairos.GuardarLog: string;
begin
  try
    ListaLog.SaveToFile(rutaLog+'\LogDisp'+FiltraStrNum(FechaHoraToStr(Now))+'.txt');
    GuardarLogPetRes;
    Result:='True|'+rutaLog+'\LogDisp'+FiltraStrNum(FechaHoraToStr(Now))+'.txt|';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_kairos.GuardarLogPetRes: string;
begin
  try
    ListaLogPetRes.SaveToFile(rutaLog+'\LogDispPetRes'+FiltraStrNum(FechaHoraToStr(Now))+'.txt');
    Result:='True|';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_kairos.Iniciar: string;
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
function Togcvdispensarios_kairos.Login(mensaje: string): string;
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

function Togcvdispensarios_kairos.Logout: string;
begin
  Token:='';
  Result:='True|';
end;

function Togcvdispensarios_kairos.MD5(const usuario: string): string;
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

function Togcvdispensarios_kairos.ObtenerEstado: string;
begin
  Result:='True|'+IntToStr(estado)+'|';
end;

function Togcvdispensarios_kairos.Shutdown: string;
begin
  if estado>0 then
    Result:='False|El servicio esta en proceso, no fue posible detenerlo|'
  else begin
    ServiceThread.Terminate;
    Result:='True|';
  end;
end;

function Togcvdispensarios_kairos.EjecutaComando(xCmnd: string): integer;
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

function Togcvdispensarios_kairos.RespuestaComando(msj: string): string;
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

function Togcvdispensarios_kairos.ResultadoComando(xFolio: integer): string;
var i:integer;
begin
  Result:='*';
  for i:=1 to 40 do
    if (TabCmnd[i].folio=xfolio)and(TabCmnd[i].SwResp) then
      result:=TabCmnd[i].Respuesta;
end;

function Togcvdispensarios_kairos.ActivaModoPrepago(msj: string): string;
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

function Togcvdispensarios_kairos.DesactivaModoPrepago(msj: string): string;
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

function Togcvdispensarios_kairos.AgregaPosCarga(
  posiciones: TlkJSONbase): string;
var i,j,k,xpos,xcomb:integer;
    existe:boolean;
    mangueras:TlkJSONbase;    
begin
  try
    if not detenido then begin
      Result:='False|Es necesario detener el proceso antes de inicializar las posiciones de carga|';
      Exit;
    end;

    MaxPosCarga:=0;
    SwCmndPend:=false;
    IdCmndPend:=0;
    Swflu:=false;
    for i:=1 to 32 do with TPosCarga[i] do begin
      DigitosGilbarco:=6;
      StFluPos:=0;
      DivImporte:=DecimalesGilbarco;
      DivLitros:=DecimalesGilbarco;
      estatus:=-1;
      estatusant:=-1;
      NoComb:=0;
      SwPreset:=false;
      StPresetPos:=0;
      importe:=0;
      volumen:=0;
      precio:=0;
      tipopago:=0;
      stkairosfrec:=1;
      Esperafinventa:=0;
      SwCargando:=false;
      SwEstatus0:=false;
      SwAutoriza:=false;
      for j:=1 to 4 do begin
        TotalLitros[j]:=0;
      end;
      SwDeshabil:=false;
      SwTotales:=true;
      SwLeeVenta:=true;
      SwFinVenta:=false;
      SwNivelPrecio:=true;
      SwCambiaPrecio:=false;
      SwRepitePos:=false;
      Fallosestat:=0;
      HoraNivelPrecio:=Now;
    end;

    for i:=0 to posiciones.Count-1 do begin
      xpos:=posiciones.Child[i].Field['DispenserId'].Value;
      if (xpos in [1..32]) then begin
        if xpos>MaxPosCarga then
          MaxPosCarga:=xpos;
        with TPosCarga[xpos] do begin
          Canal:=StrToIntDef(ExtraeElemStrSep(Canales,xpos,';'),0);
          SwPrec:=false;
          existe:=false;
          ModoOpera:='Prepago';

          mangueras:=posiciones.Child[i].Field['Hoses'];
          for j:=0 to mangueras.Count-1 do begin
            xcomb:=mangueras.Child[j].Field['ProductId'].Value;
            for k:=1 to NoComb do
              if TComb[k]=xcomb then
                existe:=true;

            if not existe then begin
              inc(NoComb);
              TComb[NoComb]:=xcomb;
              TPosx[NoComb]:=mangueras.Child[j].Field['HoseId'].Value;;
              TMang[NoComb]:=mangueras.Child[j].Field['HoseId'].Value;;
            end;
          end;
        end;
      end;
    end;
  except
    on e:Exception do
      Result:='False|Excepcion AgregaPosCarga: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_kairos.EstadoPosiciones(msj: string): string;
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

function Togcvdispensarios_kairos.ExtraeElemStrEnter(xstr: string;
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

function Togcvdispensarios_kairos.FinVenta(msj: string): string;
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

function Togcvdispensarios_kairos.Inicializar(msj: string): string;
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
    GtwDivPresetLts:=100;
    GtwDivPresetPesos:=100;
    GtwDivPrecio:=100;
    GtwDivImporte:=100;
    GtwDivLitros:=100;
    GtwDivTotLts:=100;
    GtwDivTotImporte:=100;
    GtwTimeout:=1000;
    GtwTiempoCmnd:=100;
    GtwKairosFrec:=1;

    for i:=1 to NoElemStrEnter(variables) do begin
      variable:=ExtraeElemStrEnter(variables,i);
      if UpperCase(ExtraeElemStrSep(variable,1,'='))='DECIMALESGILBARCO' then
        DecimalesGilbarco:=StrToIntDef(ExtraeElemStrSep(variable,2,'='),2)
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
        GtwTiempoCmnd:=StrToIntDef(ExtraeElemStrSep(variable,2,'='),100)
      else if UpperCase(ExtraeElemStrSep(variable,1,'='))='GTWKAIROSFREC' then
        GtwKairosFrec:=StrToIntDef(ExtraeElemStrSep(variable,2,'='),1);
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

    estado:=0;
    Result:='True|';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_kairos.IniciaPrecios(msj: string): string;
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

function Togcvdispensarios_kairos.IniciaPSerial(
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

    AgregaLog('NoPuerto: '+IntToStr(pSerial.ComNumber));
    GuardarLog;

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
      Result:='False|Excepcion IniciaPSerial: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_kairos.NoElemStrEnter(xstr: string): word;
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

function Togcvdispensarios_kairos.ObtenerLog(r: Integer): string;
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

function Togcvdispensarios_kairos.ObtenerLogPetRes(r: Integer): string;
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

function Togcvdispensarios_kairos.Terminar: string;
begin
  if estado>0 then
    Result:='False|El servicio no esta detenido, no es posible terminar la comunicacion|'
  else begin
    Timer1.Enabled:=False;
    pSerial.Open:=False;
    estado:=-1;
    Result:='True|';
  end;
end;

function Togcvdispensarios_kairos.TotalesBomba(msj: string): string;
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

function Togcvdispensarios_kairos.TransaccionPosCarga(msj: string): string;
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

function Togcvdispensarios_kairos.AutorizarVenta(msj: string): string;
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

function Togcvdispensarios_kairos.DetenerVenta(msj: string): string;
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

function Togcvdispensarios_kairos.ReanudarVenta(msj: string): string;
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

procedure Togcvdispensarios_kairos.Timer1Timer(Sender: TObject);
label L01;
var xvolumen,n1,n2,n3 :real;
    xcomb,xpos,xp,xsuma,
    xgrade,i,xcmnd    :integer;
    xtotallitros      :array[1..4] of real;
    swprec            :boolean;
    rsp               :string;
begin
  if SwEsperaComando then exit;
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
                AgregaLog('E> Pon Nivel Precio: '+inttoclavenum(PosCiclo,2));
                if PonNivelPrecio(PosCiclo,1) then
                  swnivelprecio:=false;
              end;
            end;
          1:begin                           // ESTATUS
              try
                EstatusAnt:=Estatus;
                Estatus:=DameEstatus(PosCiclo);    // Aqui bota cuando no hay posicion activa
                EstatusDispensarios;
                if (Estatusant=0)and(estatus=1) then begin
                  SwNivelPrecio:=true;
                  HoraNivelPrecio:=Now+5*TMSegundo;
                  Swleeventa:=true;
                  SwTotales:=true;
                end;
                if (estatus=0)and(not swestatus0) then begin
                  Estatus:=EstatusAnt;
                  swestatus0:=true;
                end
                else swestatus0:=false;
                ContadorAlarma:=0;
                if (EstatusAnt in [3,4])and(Estatus=1) then begin
                  swcargando:=false;
                  if EsperaFinVenta=1 then
                    Estatus:=4
                  else
                    SwTotales:=true;
                end;
                if SwAutoriza then begin
                  SwAutoriza:=false;
                  SwCmndPend:=false;
                  rsp:='OK';
                  if estatus>0 then begin
                    if Autoriza(PosCiclo) then begin
                      TPosCarga[PosCiclo].SwPreset:=true;
                      sleep(500);
                    end
                    else rsp:='No se puede autorizar, vuelva a intentar';
                  end
                  else begin
                    rsp:='No se puede autorizar, vuelva a intentar';
                  end;
                  xcmnd:=IdCmndPend;
                  TabCmnd[xcmnd].SwNuevo:=false;
                  TabCmnd[xcmnd].SwResp:=true;
                  TabCmnd[xcmnd].Respuesta:=rsp;
                  AgregaLog(LlenaStr(TabCmnd[xcmnd].Comando,'I',40,' ')+' Respuesta: '+rsp);
                end;

              // FLU
                if swcerrar then begin
                  xsuma:=0;
                  for xpos:=1 to MaxPosCarga do
                    xsuma:=xsuma+TPosCarga[xpos].StFluPos;
                  if (xsuma=0) then begin
                    GuardarLog;
                    Detener;
                    Shutdown;
                    Terminar;
                  end;
                end;
                if (Estatus=1)and(StFluPos=1)and(swflu) then begin   // Sube
                  MandaFlujoPos(PosCiclo,TAdicf[PosCiclo,1]);
                  StFluPos:=2;
                end
                else if (StFluPos in [2..9]) then begin
                  if Estatus=9 then begin
                    if DetenerDespacho(PosCiclo) then begin
                    end;
                  end
                  else inc(StFluPos);
                  if StFluPos>5 then
                    StFluPos:=0;
                end;
                if (Estatus=1)and(StFluPos=11) then begin  
                  MandaFlujoPos(PosCiclo,0);
                  StFluPos:=12;
                end
                else if (StFluPos in [12..19]) then begin
                  if Estatus=9 then begin
                    if DetenerDespacho(PosCiclo) then begin
                    end;
                  end
                  else inc(StFluPos);
                  if StFluPos>15 then
                    StFluPos:=0;
                end;
                // FIN FLU
              except
                AvanzaPosCiclo;
                NumPaso:=1;
                exit;
              end;
            end;
          2:if (swleeventa)and(estatus>0) then begin       // LEE VENTA TERMINADA
              if TPosCarga[PosCiclo].DigitosGilbarco=6 then begin
                AgregaLog('E> LEE VENTA(6): '+inttoclavenum(PosCiclo,2));
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
                AgregaLog('E> LEE VENTA(8): '+inttoclavenum(PosCiclo,2));
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
          3:if (swtotales)and(estatus>0) then begin        // LEE TOTALES
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
                      TotalLitros[xp]:=xTotalLitros[i];
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
                      TotalLitros[xp]:=xTotalLitros[i];
                    end;
                  end;
                  AgregaLog('R> '+FormatFloat('###,###,##0.00',TotalLitros[1])+' / '+FormatFloat('###,###,##0.00',TotalLitros[2])+' / '+FormatFloat('###,###,##0.00',TotalLitros[3]));
                  SwTotales:=false;
                end;
              end;
            end;
          4:if (estatus=5)and(ModoOpera='Normal') then begin // AUTORIZA TANQUE LLENO
              AgregaLog('E> Autoriza: '+inttoclavenum(PosCiclo,2));
              if Autoriza(PosCiclo) then begin
                sleep(500);
              end;
            end;
          5:if estatus=2 then begin                 // LEE VENTA PROCESO
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
          6:begin
              ProcesaComandos;
              SwFlu:=true;
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
        if (NumPaso=5) then begin
          if (estatus=2) then begin
            if StKairosFrec>=GtwKairosFrec then
              StKairosFrec:=1
            else begin
              inc(StKairosFrec);
              NumPaso:=6;
            end;
          end
          else NumPaso:=6;
        end;

        if (NumPaso=6) then begin
          if SwCmndPend then begin
            xpos:=PosCmndPend;
            if TPosCarga[xpos].StPresetPos=1 then begin
              PosCiclo:=xpos;
              NumPaso:=1;
              TPosCarga[xpos].StPresetPos:=2;
              exit;
            end
            else if TPosCarga[xpos].StPresetPos=2 then begin
              SwCmndPend:=false;
              PosCiclo:=xpos;
              NumPaso:=1;
              TPosCarga[xpos].StPresetPos:=0;
              exit;
            end;
          end;
        end;
        //
        if NumPaso>=7 then begin
          AvanzaPosCiclo;
          NumPaso:=1;
          if  TPosCarga[PosCiclo].SwNivelPrecio then
            NumPaso:=0;
        end;
      end;
    end
    else posciclo:=1;
  end;
end;

function Togcvdispensarios_kairos.PonNivelPrecio(xNPos,
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

function Togcvdispensarios_kairos.DameEstatus(PosCarga: integer): integer;
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

procedure Togcvdispensarios_kairos.EstatusDispensarios;
var xestado:string;
    xpos,xcomb:integer;
begin
  xestado:='';
  for xpos:=1 to MaxPosCarga do with TPosCarga[xpos] do begin
    if not SwDesHabil then begin
      case estatus of
        0:xestado:=xestado+'0'; // Sin Comunicación
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
  end;
  EstatusAct:=xestado;
  if EstatusAct<>EstatusAntx then begin
    AgregaLog('Estatus Disp: '+EstatusAct);
    EstatusAntx:=EstatusAct;
  end;
end;

function Togcvdispensarios_kairos.CombustibleEnPosicion(xpos,
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

function Togcvdispensarios_kairos.DataControlWordValue(
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

function Togcvdispensarios_kairos.TransmiteComando(iComando, xNPos: integer;
  sDataBlock: string): boolean;
var iMaxIntentos, iNoIntento, i , xpos, long: integer;
    chComando : char;
    bOk : boolean;
    xDataBlock,
    xComando:string;
begin
  try
    SwEsperaComando:=true;
    xpos:=xNPos;
    if ( iComando in [$10,$30,$F0] ) then begin
       bOk:= true;
       iMaxIntentos:= 0;
    end
    else begin
       bOk:= false;
       if ( iComando in [$00,$20] ) then begin
          iMaxIntentos:= 2;
          iBytesEsperados:= 1;
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
    iBytesEsperados:=iBytesEsperados+6;
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
       xComando:=EmpacaKairos(chComando,xnpos);
       for i:= 1 to length ( xComando ) do begin
          pSerial.PutChar(xComando[i]);
          repeat
             pSerial.ProcessCommunications;
          until ( pSerial.OutBuffUsed=0 );
       end;
       if ( not bOk ) then begin
          newtimer(etTimeOut,MSecs2Ticks(GtwTimeout));
          repeat
            Sleep(5);
          until ( ( bListo ) or ( timerexpired(etTimeOut) ) );
          AgregaLog('sRespuesta1 Length: '+IntToStr(length(sRespuesta)));
          if ( bListo ) then begin
             sRespuesta:=DesEmpacaKairos(sRespuesta);
             AgregaLog('sRespuesta: '+sRespuesta);
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
             sleep(50);
             bListo:= false;
             bEndOfText:= false;
             bLineFeed:= false;
             sRespuesta:= '';
             pSerial.FlushInBuffer;
             pSerial.FlushOutBuffer;
             AgregaLog('sDataBlock: '+sDataBlock);
             xDataBlock:=EmpacaKairos(sDataBlock,xnpos);
             long:=length ( xDataBlock );
             for i:= 1 to long do begin
                pSerial.PutChar(xDataBlock[i]);
                repeat
                   pSerial.ProcessCommunications;
                until ( pSerial.OutBuffUsed=0 );
             end;
             sleep(500);
             bOk:=true;
          end;
       end;
    until ( ( bOk ) or ( iNoIntento>=iMaxIntentos ) );
    result:= bOk;
    SwEsperaComando:=false;
  except
    on e:Exception do begin
      SwEsperaComando:=false;
      AgregaLog('Error TransmiteComando: '+e.Message);
    end;
  end;
end;

procedure Togcvdispensarios_kairos.TransmiteComandoEsp(sDataBlock: string);
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
    Sleep(5);
  until ( ( bListo ) or ( timerexpired(etTimeOut) ) );
end;

function Togcvdispensarios_kairos.Autoriza(PosCarga: integer): boolean;
begin
   result:= ( TransmiteComando($10,PosCarga,'') );
end;

procedure Togcvdispensarios_kairos.MandaFlujoPos(xpos, xvalor: integer);
begin
  EjecutaComando('OCC '+inttoclavenum(xpos,2)+' '+Valorx+inttostr(xvalor));
end;

function Togcvdispensarios_kairos.DetenerDespacho(xNPos: integer): boolean;
begin
   result:= ( TransmiteComando($30,xNPos,'') );
end;

procedure Togcvdispensarios_kairos.AvanzaPosCiclo;
begin
  if TPosCarga[PosCiclo].SwRepitePos then begin
    TPosCarga[PosCiclo].SwRepitePos:=false;
    exit;
  end;
  inc(PosCiclo);
  if PosCiclo>MaxPosCarga then begin
    EstatusDispensarios;
    PosCiclo:=1;
  end;
end;

function Togcvdispensarios_kairos.DameLecturas6(xNPos: integer;
  var xNMang: integer; var rLitros, rPrecio, rPesos: real): boolean;
var bOk : boolean;
begin
  bOk:= ( ( TransmiteComando($40,xNPos,'') ) and ( length(sRespuesta)>=33 ) );
  if ( bOk ) then begin
     xNMang:= DataControlWordValue(#$F6,1) + 1;
     rPrecio:= DataControlWordValue(#$F7,4);
     rLitros:= DataControlWordValue(#$F9,6);
     rPesos:= DataControlWordValue(#$FA,6);
     rPrecio:= rPrecio/GtwDivPrecio;
     rLitros:= rLitros/TPosCarga[PosCiclo].DivLitros;
     rPesos:= rPesos/TPosCarga[PosCiclo].DivImporte;
  end;
  result:= bOk;
end;

function Togcvdispensarios_kairos.DameLecturas8(xNPos: integer;
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

function Togcvdispensarios_kairos.DameTotales6(xNPos: integer;
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
  if ( bOk ) then begin
    delete(sRespuesta,1,1);
    while ( length(sRespuesta)>30 ) do begin
       xNMang:= ( LoNibbleChar(sRespuesta[2]) ) + 1;
       case ( xNMang ) of
          1 : begin
                 rTotalizadorLitros1:= DataControlWordValue(#$F9,8)/GtwDivTotLts;
                 rTotalizadorPesos1:= DataControlWordValue(#$FA,8)/GtwDivTotImporte;
              end;
          2 : begin
                 rTotalizadorLitros2:= DataControlWordValue(#$F9,8)/GtwDivTotLts;
                 rTotalizadorPesos2:= DataControlWordValue(#$FA,8)/GtwDivTotImporte;
              end;
          3 : begin
                 rTotalizadorLitros3:= DataControlWordValue(#$F9,8)/GtwDivTotLts;
                 rTotalizadorPesos3:= DataControlWordValue(#$FA,8)/GtwDivTotImporte;
              end;
       end;
       delete(sRespuesta,1,30);
    end;
  end;
  result:= bOk;
end;

function Togcvdispensarios_kairos.DameTotales8(xNPos: integer;
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

function Togcvdispensarios_kairos.PosicionDeCombustible(xpos,
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

function Togcvdispensarios_kairos.DameVentaProceso6(xNPos: integer;
  var rPesos: real): boolean;
var bOk : boolean;
begin
   bOk:= ( ( TransmiteComando($60,xNPos,'') ) and ( length(sRespuesta)>=6 ) );
   if ( bOk ) then rPesos:= BcdToInt(copy(sRespuesta,1,6))/TPosCarga[PosCiclo].DivImporte;
   result:= bOk;
end;

function Togcvdispensarios_kairos.DameVentaProceso8(xNPos: integer;
  var rPesos: real): boolean;
var bOk : boolean;
begin
   bOk:= ( ( TransmiteComando($60,xNPos,'') ) and ( length(sRespuesta)>=8 ) );
   if ( bOk ) then rPesos:= BcdToInt(copy(sRespuesta,1,8))/TPosCarga[PosCiclo].DivImporte;
   result:= bOk;
end;

procedure Togcvdispensarios_kairos.ProcesaComandos;
var ss,rsp,ss2,precios     :string;
    xcmnd,xpos,xcomb,xcanal,
    xp,xfolio,i,xc,suma           :integer;
    ximporte,xlitros  :real;
    precioComb:Double;
begin
  try
    if (minutosLog>0) and (MinutesBetween(Now,horaLog)>=minutosLog) then begin
      horaLog:=Now;
      GuardarLog;
    end;  
    // Checa Comandos
    for xcmnd:=1 to 40 do begin
      if (TabCmnd[xcmnd].SwActivo)and(not TabCmnd[xcmnd].SwResp) then begin
        SwAplicaCmnd:=true;
        ss:=ExtraeElemStrSep(TabCmnd[xcmnd].Comando,1,' ');
        AgregaLog(TabCmnd[xcmnd].Comando);
        // CMND: FLU ON
        if ss='FLUSTD' then begin
          rsp:='OK';
          xpos:=1;xcanal:=-1;
          repeat
            if xcanal<>TPosCarga[xPos].Canal then begin
              TPosCarga[xPos].StFluPos:=1;
              xcanal:=TPosCarga[xPos].Canal;
            end;
            inc(xpos);
          until (xpos>MaxPosCarga);
        end
        // CMND: FLU OFF
        else if ss='FLUMIN' then begin
          SwAplicaCmnd:=False;
          if TabCmnd[xcmnd].SwNuevo then begin
            xpos:=1;xcanal:=-1;
            repeat
              if xcanal<>TPosCarga[xPos].Canal then begin
                TPosCarga[xPos].StFluPos:=11;
                xcanal:=TPosCarga[xPos].Canal;
              end;
              inc(xpos);
            until (xpos>MaxPosCarga);
          end
          else begin
            xpos:=1;suma:=0;
            repeat
              suma:=suma+TPosCarga[xPos].StFluPos;
              inc(xpos);
            until (xpos>MaxPosCarga);
            if suma=0 then begin
              rsp:='OK';
              SwAplicaCmnd:=True;
            end;
          end;
        end
        // ORDENA CARGA DE COMBUSTIBLE
        else if ss='OCC' then begin
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
                    rsp:='Minimo permitido: $0.50';
              except
                rsp:='Error en Importe';
              end;
              if rsp='OK' then begin
                if rsp='OK' then begin
                  if (TPosCarga[xpos].estatus in [1,5,9]) then begin
                    ss:=ExtraeElemStrSep(TabCmnd[xcmnd].Comando,4,' ');
                    xcomb:=StrToIntDef(ss,0);
                    xp:=PosicionDeCombustible(xpos,xcomb);
                    TPosCarga[xpos].Esperafinventa:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,5,' '),0);
                    // Preset Pesos
                    if TPosCarga[xPos].DigitosGilbarco=6 then begin
                      if EnviaPresetBomba6(xpos,xp,1,ximporte,0) then
                      begin
                        TPosCarga[xPos].swautoriza:=true;
                        TPosCarga[xPos].StPresetPos:=1;
                        SwCmndPend:=true;
                        PosCmndPend:=xpos;
                      end
                      else rsp:='No se pudo prefijar';
                    end
                    else begin
                      if EnviaPresetBomba8(xpos,xp,1,ximporte,0) then
                      begin
                        TPosCarga[xPos].swautoriza:=true;
                        TPosCarga[xPos].StPresetPos:=1;
                        SwCmndPend:=true;
                        PosCmndPend:=xpos;
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
                    rsp:='Minimo permitido: 0.10 lts';
              except
                rsp:='Error en Litros';
              end;
              if rsp='OK' then begin
                if rsp='OK' then begin
                  if (TPosCarga[xpos].estatus in [1,5,9]) then begin
                    ss:=ExtraeElemStrSep(TabCmnd[xcmnd].Comando,4,' ');
                    xcomb:=StrToIntDef(ss,0);
                    xp:=PosicionDeCombustible(xpos,xcomb);
                    TPosCarga[xpos].Esperafinventa:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,5,' '),0);
                    // Preset Litros
                    if TPosCarga[xPos].DigitosGilbarco=6 then begin
                      if EnviaPresetBomba6(xpos,xp,1,0,xlitros) then begin
                        TPosCarga[xPos].swautoriza:=true;
                        TPosCarga[xPos].StPresetPos:=1;
                        SwCmndPend:=true;
                        PosCmndPend:=xpos;
                      end
                      else rsp:='No se pudo prefijar';
                    end
                    else begin
                      if EnviaPresetBomba8(xpos,xp,1,0,xlitros) then begin
                        TPosCarga[xPos].swautoriza:=true;
                        TPosCarga[xPos].StPresetPos:=1;
                        SwCmndPend:=true;
                        PosCmndPend:=xpos;
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
              rsp:='Posicion aún no esta en fin de venta';
          end
          else rsp:='Posicion de Carga no Existe';

        end
        // ORDENA ESPERA FIN DE VENTA
        else if ss='EFV' then begin
          xpos:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,2,' '),0);
          rsp:='OK';
          if (xpos in [1..MaxPosCarga]) then
            if (TPosCarga[xpos].Estatus in [2,9]) then
              TPosCarga[xpos].Esperafinventa:=1
            else rsp:='Posicion debe estar Autorizada o Despachando'
          else rsp:='Posicion de Carga no Existe';
        end
        // CMND: DESAUTORIZA VENTA DE COMBUSTIBLE
        else if (ss='DVC')or(ss='PARAR') then begin
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
        if not SwCmndPend then begin
          TabCmnd[xcmnd].SwNuevo:=false;
          if SwAplicaCmnd then begin
            if rsp='' then
              rsp:='OK';
            TabCmnd[xcmnd].SwResp:=true;
            TabCmnd[xcmnd].Respuesta:=rsp;
            AgregaLog(LlenaStr(TabCmnd[xcmnd].Comando,'I',40,' ')+' Respuesta: '+TabCmnd[xcmnd].Respuesta);
          end;
        end
        else begin
          IdCmndPend:=xcmnd;
          exit;
        end;
      end;
    end;
  except
  end;
end;

function Togcvdispensarios_kairos.CambiaPrecio6(xNPos, xNMang,
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

function Togcvdispensarios_kairos.CambiaPrecio8(xNPos, xNMang,
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

function Togcvdispensarios_kairos.FluMin: string;
begin
  if Licencia3Ok then begin
    try
      Result:='True|'+IntToStr(EjecutaComando('FLUMIN'));
    except
      on e:Exception do
        Result:='False|Error FLUMIN: '+e.Message;
    end;
  end
  else
    Result:='False|Licencia CVL7 invalida';
end;

function Togcvdispensarios_kairos.FluStd(msj: string): string;
var
  i,xpos:Integer;
  mangueras:string;
  config:TIniFile;  
begin
  if Licencia3Ok then begin
    try
      AgregaLog('Mensaje adic: '+msj);

      config:= TIniFile.Create(ExtractFilePath(ParamStr(0)) +'PDISPENSARIOS.ini');
      config.WriteString('CONF','ConfAdic',msj);
      config:=nil;

      for i:=1 to NoElemStrSep(msj,';') do begin
        xpos:=StrToInt(ExtraeElemStrSep(ExtraeElemStrSep(msj,i,';'),1,':'));
        TAdicf[xpos,1]:=trunc(StrToFloatDef(ExtraeElemStrSep(mangueras,1,','),0)*10+0.5);
        TAdicf[xpos,2]:=trunc(StrToFloatDef(ExtraeElemStrSep(mangueras,2,','),0)*10+0.5);
        TAdicf[xpos,3]:=trunc(StrToFloatDef(ExtraeElemStrSep(mangueras,3,','),0)*10+0.5);
        AgregaLog('Flu1: '+FloatToStr(TAdicf[xpos,1])+', Flu2: '+FloatToStr(TAdicf[xpos,2])+', Flu3: '+FloatToStr(TAdicf[xpos,3]));
      end;

      Result:='True|'+IntToStr(EjecutaComando('FLUSTD'))+'|';
    except
      on e:Exception do
        Result:='False|Error FLUSTD: '+e.Message+'|';
    end;
  end
  else
    Result:='False|Licencia CVL7 invalida|';
end;

function Togcvdispensarios_kairos.ValidaCifra(xvalor: real; xenteros,
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

function Togcvdispensarios_kairos.EnviaPresetBomba6(xNPos, xNMang,
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
  sDataBlock:= sPresetType + sPriceLevel + sGrade + #$F8 + BcdToStr(sAmount) + #$FB;
  sDataBlock:= #$FF + DLChar(sDataBlock) + sDataBlock;
  sDataBlock:= sDataBlock + LrcCheckChar(sDataBlock) + #$F0;
  result:= ( TransmiteComando($20,xNPos,sDataBlock) );
end;

function Togcvdispensarios_kairos.EnviaPresetBomba8(xNPos, xNMang,
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
  sDataBlock:= sPresetType + sPriceLevel + sGrade + #$F8 + BcdToStr(sAmount) + #$FB;
  sDataBlock:= #$FF + DLChar(sDataBlock) + sDataBlock;
  sDataBlock:= sDataBlock + LrcCheckChar(sDataBlock) + #$F0;
  result:= ( TransmiteComando($20,xNPos,sDataBlock) );
end;

function Togcvdispensarios_kairos.ReanudaDespacho(
  PosCarga: integer): boolean;
begin
  result:= ( TransmiteComando($10,PosCarga,'') );
end;

procedure Togcvdispensarios_kairos.pSerialTriggerAvail(CP: TObject;
  Count: Word);
var i : integer;
    c,cx:char;
begin
   c:=' ';cx:=' ';
   for i:=1 to Count do begin
     cx:=c;
     c:=pSerial.GetChar;
     sRespuesta:= sRespuesta + c;
   end;
   i:= length(sRespuesta);
   if (i>4)and(ord(c)=$7E)and(ord(cx)<>$7D) then
     bEndOfText:=true;
   if ( ( i>=iBytesEsperados ) or ( bEndOfText )  or ( bLineFeed ) ) then
      bListo:= true
   else
      newtimer(etTimeOut,MSecs2Ticks(GtwTimeout));
end;

end.
