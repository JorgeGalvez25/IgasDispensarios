unit UIGASTEAM;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, SvcMgr, Dialogs,
  ExtCtrls, OoMisc, AdPort, ScktComp, IniFiles, ActiveX, ComObj,
  ULIBGRAL, TypInfo, uLkJSON, CRCs, Variants, IdHashMessageDigest, IdHash;

Const MaxEsperaRsp=2;
      MCxP=4;

type
  Togcvdispensarios_team = class(TService)
    ServerSocket1: TServerSocket;
    pSerial: TApdComPort;
    Timer1: TTimer;
    procedure ServerSocket1ClientRead(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure ServiceExecute(Sender: TService);
    procedure Timer1Timer(Sender: TObject);
    procedure pSerialTriggerAvail(CP: TObject; Count: Word);
  private
    { Private declarations }
    SwAplicaCmnd:Boolean;   
    LineaBuff,
    LineaTimer,
    Linea:string;
    SwEspera,
    SwComandoB,
    FinLinea:boolean;
    ContCmndU,
    ContEspera,
    ContEsperaPaso2,
    NumPaso,
    PosCiclo,
    PosicionActual:integer;
    UltimoStatus:string;
    SnPosCarga:integer;
    SnImporte,SnLitros:real;    
    ConfTeam:String;
    TresDecimTotTeam:String;
    Con_DigitoAjuste:Integer;
    CodigoTeam:String;
  public
    ListaLog:TStringList;
    ListaLogPetRes:TStringList;
    rutaLog:string;
    licencia:string;
    detenido:Boolean;
    estado:Integer;
    horaLog:TDateTime;
    minutosLog:Integer;
  // CONTROL TRAFICO COMANDOS
    ListaCmnd    :TStrings;
    FolioCmnd   :integer;
    CheckSumB:Boolean;
    version:String;
    function GetServiceController: TServiceController; override;
    procedure AgregaLog(lin:string);
    procedure AgregaLogPetRes(lin: string);
    procedure Responder(socket:TCustomWinSocket;resp:string);
    function FechaHoraExtToStr(FechaHora:TDateTime):String;
    function IniciaPSerial(datosPuerto:string): string;
    procedure ComandoConsola(ss:string);
    procedure ComandoConsolaBuff(ss:string;swinicio:boolean);
    function CombustibleEnPosicion(xpos,xposcarga:integer):integer;
    function CRC16(Data: string): string;
    procedure ProcesaLinea(checksum:boolean);
    function AutorizarVenta(msj: string): string;
    function DetenerVenta(msj: string): string;
    function ReanudarVenta(msj: string): string;
    function ActivaModoPrepago(msj:string): string;
    function DesactivaModoPrepago(msj:string): string;
    function EjecutaComando(xCmnd:string):integer;
    function FinVenta(msj: string): string;
    function RespuestaComando(msj: string): string;
    function GuardarLog:string;
    function GuardarLogPetRes:string;
    function AgregaPosCarga(posiciones: TlkJSONbase): string;
    function Inicializar(msj: string): string;
    function Login(mensaje: string): string;
    function Logout: string;
    function IniciaPrecios(msj: string): string;
    function Bloquear(msj: string): string;
    function Desbloquear(msj: string): string;
    function TransaccionPosCarga(msj: string): string;
    function EstadoPosiciones(msj: string): string;
    function TotalesBomba(msj: string): string;
    function Detener: string;
    function Iniciar: string;
    function Shutdown: string;
    function Terminar: string;
    function ObtenerEstado: string;
    function ObtenerLog(r: Integer): string;
    function ObtenerLogPetRes(r: Integer): string;
    function ComandoB(xdisp,xlado:integer):string;
    function ComandoA(xdisp,xlado,xtipo:integer):string;
    function ComandoS(xdisp,xlado:integer;ximpo:real):string;
    function ComandoL(xdisp,xlado:integer;xlitros:real):string;
    function ComandoU(xdisp:integer; xprec1,xprec2,xprec3:real):string;
    function ComandoC(xdisp:integer):string;
    function ComandoD(xdisp:integer):string;
    function ComandoN(xdisp,xlado,xprod:integer):string;
    function ComandoW(xdisp,xlado,xvalor:integer):string;
    function StrToHexSep(ss:string):string;
    function HexSepToStr(ss:string):string;
    function HexToBinario(ss:string):string;
    function DamePosTeam(ss:string; swlado:boolean):integer;
    function PosicionDeCombustible(xpos,xcomb:integer):integer;
    function ValidaChecksumTeam(LineaTimer:string):boolean;
    procedure EnviaPreset(var rsp:string;xcomb:integer;swpreset:boolean);
    function ResultadoComando(xFolio:integer):string;
    function NoElemStrEnter(xstr:string):word;
    function ExtraeElemStrEnter(xstr:string;ind:word):string;
    function MD5(const usuario: string): string;
    { Public declarations }
  end;

type
     tiposcarga = record
       dispensario:integer;
       lado       :integer;
       estatus    :integer;
       importe,
       volumen,
       precio     :real;
       importepre,
       volumenpre,
       preciopre,
       importenvo,
       volumennvo,
       precionvo :real;
       importeant :real;
       //importex   :real;
       //swerr_vta   :boolean;
       impopreset :real;
       Isla,
       PosActual  :integer; // Posicion del combustible en proceso: 1..NoComb
       PosAutorizada:integer;
       estatusant:integer;
       NoComb     :integer; // Cuantos combustibles hay en la posicion
       TComb      :array[1..MCxP] of integer; // Claves de los combustibles
       TPos       :array[1..MCxP] of integer;
       TDiga      :array[1..MCxP] of integer;
       TMang      :array[1..MCxP] of integer;
       TotalLitros:array[1..MCxP] of real;
       SwDesp:boolean;
       SwA:boolean;
       Hora:TDateTime;
       SwInicio:boolean;
       SwInicio2:boolean;
       SwPreset,
       SwCargaTotales,     
       IniciaCarga,
       SwPrepago:boolean;
       IntentosTotales:byte;
       ActualizarPrecio:Boolean;
       Mensaje:string[30];
       //swactualizar,
       swcargando:boolean;
       swcargapreset:boolean;
       SwActivo,
       SwDesHabilitado:boolean;
       ModoOpera:string[8];
       ContEsperaB,
       ContDesp,
       StCero   :integer;
       TipoPago:integer;
       TipoPagoAnt:integer;
       FinVenta:integer;
       TCodigoTeam,
       Boucher:string[12];
       HoraOcc:TDateTime;

       swarosmag:boolean;
       aros_cont,
       aros_mang,
       aros_cte,
       aros_vehi:integer;
       swarosmag_stop:boolean;

       AuxCmndN       :integer;
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

type TMetodos = (NOTHING_e, INITIALIZE_e, PARAMETERS_e, LOGIN_e, LOGOUT_e,
             PRICES_e, AUTHORIZE_e, STOP_e, START_e, SELFSERVICE_e, FULLSERVICE_e,
             BLOCK_e, UNBLOCK_e, PAYMENT_e, TRANSACTION_e, STATUS_e, TOTALS_e, HALT_e,
             RUN_e, SHUTDOWN_e, TERMINATE_e, STATE_e, TRACE_e, SAVELOGREQ_e, RESPCMND_e,
             LOG_e, LOGREQ_e);

var
  ogcvdispensarios_team: Togcvdispensarios_team;
  TPosCarga:array[1..100] of tiposcarga;
  TabCmnd  :array[1..200] of RegCmnd;
  LPrecios :array[1..4] of Double;
  MaxPosCarga:integer;
  AvanceBar:integer;
  SwSolOk:boolean;
  ContDA,
  StErrSol:integer;
  ruta_db:string;
  // CONTROL TRAFICO COMANDOS
  //ListaAux,
  ListaCmnd    :TStrings;
  LinCmnd      :string;
  CharCmnd     :char;
  SwEsperaRsp  :boolean;
  ContEsperaRsp:integer;

  NumPaso      :integer;
  SwCerrar    :boolean;
  HoraComandoB:Tdatetime;
  HoraRspB:Tdatetime;
  ContB:integer;
  Token        :string;
  Licencia3Ok  :Boolean;
  LinEstadoGen  :string;

implementation

uses StrUtils;

{$R *.DFM}

procedure ServiceController(CtrlCode: DWord); stdcall;
begin
  ogcvdispensarios_team.Controller(CtrlCode);
end;

function Togcvdispensarios_team.GetServiceController: TServiceController;
begin
  Result := ServiceController;
end;

procedure Togcvdispensarios_team.ServiceExecute(Sender: TService);
var
  config:TIniFile;
  lic:string;
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

    ConfTeam:=config.ReadString('CONF','ConfTeam','');

    while not Terminated do
      ServiceThread.ProcessRequests(True);
    ServerSocket1.Active := False;
  except
    on e:exception do begin
      ListaLog.Add('Error al iniciar servicio: '+e.Message);
      ListaLog.SaveToFile(rutaLog+'\LogDispPetRes'+FiltraStrNum(FechaHoraToStr(Now))+'.txt');
      GuardarLog;
      if ListaLogPetRes.Count>0 then
        GuardarLogPetRes;      
    end;
  end;
end;

procedure Togcvdispensarios_team.ServerSocket1ClientRead(Sender: TObject;
  Socket: TCustomWinSocket);
  var
    mensaje,comando,checksum,parametro:string;
    i:Integer;
    chks_valido:Boolean;
    metodoEnum:TMetodos;
begin
  mensaje:=Socket.ReceiveText;
  AgregaLogPetRes('R '+mensaje);
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
      AgregaLogPetRes('Error: '+e.Message);
      GuardarLogPetRes;
      Responder(Socket,'DISPENSERS|'+comando+'|False|'+e.Message+'|');
    end;
  end;
end;

procedure Togcvdispensarios_team.AgregaLog(lin: string);
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

procedure Togcvdispensarios_team.AgregaLogPetRes(lin: string);
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

procedure Togcvdispensarios_team.Responder(socket: TCustomWinSocket; resp: string);
begin
  socket.SendText(#1#2+resp+#3+CRC16(resp)+#23);
  AgregaLogPetRes('E '+#1#2+resp+#3+CRC16(resp)+#23);
end;

function Togcvdispensarios_team.FechaHoraExtToStr(FechaHora: TDateTime): String;
begin
  result:=FechaPaq(FechaHora)+' '+FormatDatetime('hh:mm:ss.zzz',FechaHora);
end;

function Togcvdispensarios_team.IniciaPSerial(datosPuerto: string): string;
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

procedure Togcvdispensarios_team.ComandoConsola(ss: string);
var s1,s2,LinCmd2:string;
    n,i,xpos:integer;
    r1,r2,r3:real;
begin
  LinCmnd:=ss;
  CharCmnd:=LinCmnd[1];
  ContEsperaRsp:=0;
  case CharCmnd of
    'B':begin
          s1:=copy(LinCmnd,2,2);
          xpos:=strtointdef(s1,0);
          if xpos in [1..MaxPosCarga] then with TPosCarga[xpos] do begin
            LinCmd2:=ComandoB(dispensario,lado);
            inc(ContEsperaB);
          end;
          HoraComandoB:=now;
          ContB:=0;
        end;
    'A':begin
          esperamiliseg(100);
          s1:=copy(LinCmnd,2,2);
          xpos:=strtointdef(s1,0);
          s1:=copy(LinCmnd,4,1);
          n:=strtointdef(s1,0);
          if xpos in [1..MaxPosCarga] then with TPosCarga[xpos] do begin
            case n of
              0:LinCmd2:=ComandoA(dispensario,lado,0); // Litros
              1:LinCmd2:=ComandoA(dispensario,lado,1); // Pesos
            end;
          end;
        end;
    'S':begin
          esperamiliseg(500);
          s1:=copy(LinCmnd,2,2);
          xpos:=strtointdef(s1,0);
          s1:=copy(LinCmnd,4,6);
          r1:=strtointdef(s1,0)/100;
          if xpos in [1..MaxPosCarga] then with TPosCarga[xpos] do
            LinCmd2:=ComandoS(dispensario,lado,r1);
        end;
    'L':begin
          esperamiliseg(500);
          s1:=copy(LinCmnd,2,2);
          xpos:=strtointdef(s1,0);
          s1:=copy(LinCmnd,4,6);
          r1:=strtointdef(s1,0)/100;
          if xpos in [1..MaxPosCarga] then with TPosCarga[xpos] do
            LinCmd2:=ComandoL(dispensario,lado,r1);
        end;
    'U':begin  // Cambio Precio
          s1:=copy(LinCmnd,2,2);
          xpos:=strtointdef(s1,0);
          s1:=copy(LinCmnd,4,4);
          r1:=strtointdef(s1,0)/100;
          s1:=copy(LinCmnd,8,4);
          r2:=strtointdef(s1,0)/100;
          s1:=copy(LinCmnd,12,4);
          r3:=strtointdef(s1,0)/100;
          with TPosCarga[xpos] do
            LinCmd2:=ComandoU(dispensario,r1,r2,r3);
        end;
    'C':begin  // Bloquea Dispensario
          s1:=copy(LinCmnd,2,2);
          xpos:=strtointdef(s1,0);
          with TPosCarga[xpos] do
            LinCmd2:=ComandoC(dispensario);
        end;
    'D':begin  // Bloquea Dispensario
          s1:=copy(LinCmnd,2,2);
          xpos:=strtointdef(s1,0);
          with TPosCarga[xpos] do
            LinCmd2:=ComandoD(dispensario);
        end;
    'N':begin
          s1:=copy(LinCmnd,2,2);
          xpos:=strtointdef(s1,0);
          s1:=copy(LinCmnd,4,1);
          TPosCarga[xpos].AuxCmndN:=strtointdef(s1,1);
          if xpos>0 then with TPosCarga[xpos] do
            LinCmd2:=ComandoN(dispensario,lado,TPosCarga[xpos].AuxCmndN);
        end;
    else exit;
  end;
  Timer1.Enabled:=false;
  try
    n:=0;
    for i:=5 to NoElemStrSep(LinCmd2,' ') do begin
      s2:=extraeelemstrsep(LinCmd2,i,' ');
      n:=n+strtointdef(s2,0);
    end;
    LinCmd2:=LinCmd2+' '+inttoclavenum(n,2);

    s1:=HexSepToStr(LinCmd2);
    AgregaLog('E '+StrToHexSep(s1));
    SwEsperaRsp:=true;
    if pSerial.Open then
      pSerial.OutPut:=s1;
    if CharCmnd='U' then
      ContCmndU:=5;
  finally
    Timer1.Enabled:=true;
  end;
end;

procedure Togcvdispensarios_team.ComandoConsolaBuff(ss:string;swinicio:boolean);
begin
  if (ListaCmnd.Count=0)and(not SwEsperaRsp) then
    ComandoConsola(ss)
  else begin
    if swinicio then begin
      ListaCmnd.Insert(0,ss);
    end
    else
      ListaCmnd.Add(ss);
  end;
end;

function Togcvdispensarios_team.CRC16(Data: string): string;
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

procedure Togcvdispensarios_team.ProcesaLinea(checksum: boolean);
label uno;
var lin,ss,ss2,rsp,rsp2,descrsp,xestado,xmodo,
    xdisp2,xmodo2,xestado2,precios:string;
    simp,spre,sval:string[20];
    i,j,xpos,ii,xdisp,xcmnd:integer;
    XMANG,XCTE,XVEHI,
    xp,xpr,xcomb,xfolio:integer;
    xestatus:char;
    ximporte:real;
    xLista:TStrings;
    ximpo,xdif,
    xprecio,
    xvol:real;
    precioComb:Real;
    xprec:array[1..3] of real;
begin
  try
    if LineaTimer='' then
      exit;
    if not checksum then
      exit;
    lin:=LineaTimer;
    LineaTimer:='';
    case lin[1] of
     'B':begin // pide estatus de todas las bombas
           NumPaso:=1;
           ContEspera:=0;
           UltimoStatus:=LineaTimer;
           ss:=copy(lin,4,length(lin)-3);
           for xpos:=1 to MaxPosCarga do begin
             with TPosCarga[xpos] do begin
               PosActual:=StrToIntDef(ss[xpos*2-1],0);
               if PosActual=0 then begin
                 PosActual:=1;
                 for i:=1 to NoComb do begin
                   xcomb:=TComb[i];
                   if abs(precio-LPrecios[xcomb])<0.1 then
                     PosActual:=TPos[i];
                 end;
               end;
               if estatusant<>estatus then begin
                 SwPreset:=false;
                 SwA:=true; //CAMBIO
               end;
               estatusant:=estatus;
               estatus:=StrToIntDef(ss[xpos*2],0);
               if (estatus=0)and(stcero<=3) then begin
                 inc(stcero);
                 estatus:=estatusant;
               end
               else stcero:=0;
               Mensaje:='Pos = '+inttostr(posactual);
               case estatus of
                 1:begin
                     if estatusant<>1 then begin
                       PosAutorizada:=0;
                       FinVenta:=0;
                       TipoPago:=0;
                     end;
                   end;
                 3:begin
                     swcargando:=false;
                   end;
                 5:begin
                     IniciaCarga:=true;
                     if not SwCargando then
                       SwCargaPreset:=true;
                     swcargando:=true;
                     if estatusant<>5 then begin
                       ContDesp:=0;
                       importenvo:=0;
                       volumennvo:=0;
                       precionvo:=0;
                     end;
                   end;
               end;
             end;
           end;
         end;
     'A':begin // pide estatus de una bomba
           NumPaso:=2;
           xpos:=StrToIntDef(copy(lin,2,2),0);
           if (xpos>=1)and(xpos<=MaxPosCarga) then begin
             ContEsperaPaso2:=0;
             with TPosCarga[xpos] do begin
               try
                 importepre:=importenvo;
                 volumenpre:=volumennvo;
                 preciopre:=precionvo;

                 swinicio2:=false;
                 volumen:=StrToFloat(copy(lin,5,6))/100;
                 simp:=copy(lin,11,8);
                 spre:=copy(lin,19,4);
                 importe:=StrToFloat(simp)/100;
                 precio:=StrToFloat(spre)/100;

                 importenvo:=importe;
                 volumennvo:=volumen;
                 precionvo:=precio;
                 
                 if estatus=5 then begin // valida estatus fantasma
                   inc(contdesp);
                   if (contdesp=1)and(abs(importe-importeant)<=0.005) then
                     contdesp:=0;
                 end;

                 if (Estatus in [1,7,8])and(swcargando) then begin
                   if (importenvo<importepre) then begin
                     AgregaLog('FIN DE VENTA CORREGIDO');
                     importe:=importepre;
                     volumen:=volumenpre;
                     precio:=preciopre;
                   end
                   else
                     AgregaLog('FIN DE VENTA');
                   swcargando:=false;
                   swdesp:=true;
                 end;
               
                 if (estatus=8) then
                   finventa:=2;
               except
                 AgregaLog(lin+' '+fechapaq(date)+' '+HoraPaq(time));
               end;
             end;
           end;
         end;
     'S':begin
         end;
     'U':begin
           xpos:=StrToIntDef(copy(lin,2,2),0);
           xprec[1]:=strtointdef(copy(Lin,4,4),0)/100;
           xprec[2]:=strtointdef(copy(Lin,8,4),0)/100;
           xprec[3]:=strtointdef(copy(Lin,12,4),0)/100;
           xdisp:=TPosCarga[xpos].dispensario;
           for xpos:=1 to MaxPosCarga do with TPosCarga[xpos] do if dispensario=xdisp then begin
             ActualizarPrecio:=false;
           end;
         end;
     'N':begin // totales de la bomba
           NumPaso:=3;
           xpos:=StrToIntDef(copy(lin,2,2),0);
           ii:=StrToIntDef(copy(lin,4,1),1);
           if (xpos>=1)and(xpos<=MaxPosCarga) then begin
             with TPosCarga[xpos] do begin
               ss:=copy(lin,5,12);
               if NoComb=1 then
                 ii:=1;
               if TresDecimTotTeam='Si' then
                 TotalLitros[ii]:=StrToFloat(ss)/1000
               else
                 TotalLitros[ii]:=StrToFloat(ss)/100;
             end;
           end;
         end;
    end;
    if (ListaCmnd.Count>0)and(not SwEsperaRsp) then begin
      ss:=ListaCmnd[0];
      ListaCmnd.Delete(0);
      ComandoConsola(ss);
      Esperamiliseg(200);
      exit;
    end
    else begin
      inc(NumPaso);
      PosicionActual:=0;
    end;
    // checa lecturas de dispensarios
    if NumPaso=2 then begin
      if PosicionActual<MaxPosCarga then begin
        repeat
          Inc(PosicionActual);
          with TPosCarga[PosicionActual] do if NoComb>0 then begin
            if (estatus<>estatusant)or(estatus>=5)or(SwA)or(swinicio2)or(swcargando) then begin
              SwA:=false;
              //SwActualizar:=true;
              ComandoConsolaBuff('A'+IntToClaveNum(PosicionActual,2)+'1',false); // pesos
              Esperamiliseg(200);
            end;
          end;
        until (PosicionActual>=MaxPosCarga);
      end;
      NumPaso:=3;
      PosicionActual:=0;
    end;
    // Lee Totales
    if NumPaso=3 then begin
      // GUARDA VALORES DE DISPENSARIOS CARGANDO
      try
        xestado2:='';xdisp2:='';xmodo2:='';

        lin:='';xestado:='';xmodo:='';
        for xpos:=1 to MaxPosCarga do with TPosCarga[xpos] do begin
          xmodo:=xmodo+ModoOpera[1];
          if not SwDesHabilitado then begin
            case estatus of
              0:xestado:=xestado+'0'; // Sin Comunicación
              1:xestado:=xestado+'1'; // Inactivo (Idle)
              5,8:xestado:=xestado+'2'; // Cargando (In Use)
              7:if not swcargando then
                  xestado:=xestado+'3' // Fin de Carga (Used)
                else
                  xestado:=xestado+'2';
              3,4:xestado:=xestado+'5'; // Llamando (Calling)
              2:xestado:=xestado+'9'; // Autorizado
              6:xestado:=xestado+'8'; // Detenido (Stoped)
              else xestado:=xestado+'0';
            end;
          end
          else xestado:=xestado+'7'; // Deshabilitado
          xcomb:=CombustibleEnPosicion(xpos,PosActual);
          ss:=inttoclavenum(xpos,2)+'/'+inttostr(xcomb);
          ss:=ss+'/'+FormatFloat('###0.##',volumen);
          ss:=ss+'/'+FormatFloat('#0.##',precio);
          ss:=ss+'/'+FormatFloat('####0.##',importe);
          lin:=lin+'#'+ss;
        end;
        if lin='' then
          lin:=xestado+xestado2+'#'
        else
          lin:=xestado+xestado2+lin;
        lin:=lin+xdisp2+'&'+xmodo+xmodo2;
        LinEstadoGen:=xestado;
      except
        on e:exception do
          AgregaLog('Error NumPaso=3: '+e.Message);
      end;
      // FIN

      if PosicionActual<MaxPosCarga then begin
        repeat
          Inc(PosicionActual);
          with TPosCarga[PosicionActual] do if NoComb>0 then begin
            if swcargatotales then begin
              for i:=1 to NoComb do begin
                if NoComb>1 then
                  ComandoConsolaBuff('N'+IntToClaveNum(PosicionActual,2)+inttostr(i),false) // Totales
                else // diesel
                  ComandoConsolaBuff('N'+IntToClaveNum(PosicionActual,2)+inttostr(3),false); // Totales
                Esperamiliseg(200);
              end;
              swcargatotales:=false;
            end;
          end;
        until (PosicionActual>=MaxPosCarga);
      end;
      NumPaso:=4;
      PosicionActual:=0;
    end;
    if (NumPaso=4) then begin
      // Checa Comandos
      for xcmnd:=1 to 40 do if (TabCmnd[xcmnd].SwActivo)and(not TabCmnd[xcmnd].SwResp) then begin
        SwAplicaCmnd:=true;
        ss:=ExtraeElemStrSep(TabCmnd[xcmnd].Comando,1,' ');
        AgregaLog(TabCmnd[xcmnd].Comando);
        // CMND: CERRAR CONSOLA
        if ss='CERRAR' then begin
          rsp:='OK';
          SwCerrar:=true;
        end
        // CMND: ACTIVA MODO PREPAGO
        else if ss='AMP' then begin
          xpos:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,2,' '),0);
          if (xpos in [0..MaxPosCarga]) then begin
            if xpos=0 then begin
              for xpos:=1 to MaxPosCarga do begin
                ComandoConsolaBuff('C'+inttoclavenum(xpos,2),false);
                Esperamiliseg(200);
              end;
            end
            else begin
              ComandoConsolaBuff('C'+inttoclavenum(xpos,2),false);
              Esperamiliseg(200);
              rsp:='OK';
            end;
          end
          else SwAplicaCmnd:=false;
        end
        // CMND: DESACTIVA MODO PREPAGO
        else if ss='DMP' then begin
          xpos:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,2,' '),0);
          if (xpos in [0..MaxPosCarga]) then begin
            if xpos=0 then begin
              for xpos:=1 to MaxPosCarga do
                ComandoConsolaBuff('D'+inttoclavenum(xpos,2),false);
            end
            else begin
              ComandoConsolaBuff('D'+inttoclavenum(xpos,2),false);
              rsp:='OK';
            end;
          end
          else SwAplicaCmnd:=false;
        end
        // ORDENA CARGA DE COMBUSTIBLE           OCC 1 10 1 1 1
        else if ss='OCC' then begin
          SnPosCarga:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,2,' '),0);
          rsp:='OK';
          if (SnPosCarga in [1..MaxPosCarga]) then begin
            try
              SnLitros:=0;
              SnImporte:=StrToFLoat(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,3,' '));
              if (SnImporte<1)or(SnImporte>9999) then
                rsp:='Importe fuera de rango válido: de 1.00 a 9999.00';
            except
              rsp:='Error en Importe';
            end;
            if rsp='OK' then begin
              xcomb:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,4,' '),0);
              xp:=PosicionDeCombustible(SnPosCarga,xcomb);
              if xp>0 then begin
                TPosCarga[SnPosCarga].tipopago:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,5,' '),0);
                TPosCarga[SnPosCarga].finventa:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,6,' '),0);
                TPosCarga[SnPosCarga].boucher:=ExtraeElemStrSep(TabCmnd[xcmnd].Comando,7,' ');
                EnviaPreset(rsp,xcomb,false);
              end;
            end;
          end;
        end
        // ORDENA CARGA DE COMBUSTIBLE LITROS
        else if ss='OCL' then begin
          SnPosCarga:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,2,' '),0);
          rsp:='OK';
          if (SnPosCarga in [1..MaxPosCarga]) then begin
            try
              SnLitros:=StrToFLoat(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,3,' '));
              SnImporte:=0;
            except
              rsp:='Error en Litros';
            end;
            if rsp='OK' then begin
              xcomb:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,4,' '),0);
              xp:=PosicionDeCombustible(SnPosCarga,xcomb);
              if xp>0 then begin
                TPosCarga[SnPosCarga].tipopago:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,5,' '),0);
                TPosCarga[SnPosCarga].finventa:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,6,' '),0);
                TPosCarga[SnPosCarga].boucher:=ExtraeElemStrSep(TabCmnd[xcmnd].Comando,7,' ');
                EnviaPreset(rsp,xcomb,false);
              end
              else rsp:='Combustible no existe en esta posición';
            end;
          end;
        end
        // ORDENA FIN DE VENTA
        else if ss='FINV' then begin
          xpos:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,2,' '),0);
          rsp:='OK';
          if (xpos in [1..MaxPosCarga]) then with TPosCarga[xpos] do begin
            TipoPago:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,3,' '),0);
            if (not SwCargando)and(Estatus in [1,7]) then begin // EOT
              finventa:=0;
              SwCargaTotales:=true;
            end
            else
              rsp:='Posicion no esta en fin de venta';
          end
          else rsp:='Posicion de Carga no Existe';
        end
        else if (ss='TOTAL') then begin
          xpos:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,2,' '),0);;
          rsp:='OK';
          with TPosCarga[xpos] do begin
            if TabCmnd[xcmnd].SwNuevo then begin
              SwCargaTotales:=True;
              TabCmnd[xcmnd].SwNuevo:=false;
            end;
            if not SwCargaTotales then begin
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
          for xpos:=1 to MaxPosCarga do with TPosCarga[xpos] do begin
            xcomb:=CombustibleEnPosicion(xpos,1);
            precioComb:=StrToFloatDef(ExtraeElemStrSep(precios,xcomb,'|'),-1);
            LPrecios[xcomb]:=precioComb;
            ii:=Trunc(precioComb*100+0.5);
            ss:='U'+IntToClaveNum(xpos,2)+inttoclavenum(ii,4);
            if NoComb=1 then begin
              ss:=ss+inttoclavenum(ii,4)+inttoclavenum(ii,4);
            end
            else if NoComb=2 then begin
              xcomb:=CombustibleEnPosicion(xpos,2);
              precioComb:=StrToFloatDef(ExtraeElemStrSep(precios,xcomb,'|'),-1);
              LPrecios[xcomb]:=precioComb;
              ii:=Trunc(precioComb*100+0.5);
              ss:=ss+inttoclavenum(ii,4)+'0000';
            end
            else begin
              xcomb:=CombustibleEnPosicion(xpos,2);
              precioComb:=StrToFloatDef(ExtraeElemStrSep(precios,xcomb,'|'),-1);
              LPrecios[xcomb]:=precioComb;
              ii:=Trunc(precioComb*100+0.5);
              ss:=ss+inttoclavenum(ii,4);
              xcomb:=CombustibleEnPosicion(xpos,3);
              precioComb:=StrToFloatDef(ExtraeElemStrSep(precios,xcomb,'|'),-1);
              LPrecios[xcomb]:=precioComb;
              ii:=Trunc(precioComb*100+0.5);
              ss:=ss+inttoclavenum(ii,4);
            end;
            ComandoConsolaBuff(ss, False);
            EsperaMiliSeg(300);
          end;
        end;
        if rsp='' then
          rsp:='OK';
        if SwAplicaCmnd then begin
          TabCmnd[xcmnd].SwResp:=true;
          TabCmnd[xcmnd].Respuesta:=rsp;
          AgregaLog(LlenaStr(TabCmnd[xcmnd].Comando,'I',40,' ')+' Respuesta: '+TabCmnd[xcmnd].Respuesta);
        end;
      end;

      NumPaso:=1;
    end;
  except
    on e:exception do
      AgregaLog('Error ProcesaLinea: '+e.Message);
  end;
end;

function Togcvdispensarios_team.ActivaModoPrepago(msj: string): string;
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
      for xpos:=1 to MaxPosCarga do begin
        TPosCarga[xpos].ModoOpera:='Prepago';
        EjecutaComando('AMP '+IntToStr(xpos));
      end;
    end
    else if (xpos in [1..maxposcarga]) then begin
      TPosCarga[xpos].ModoOpera:='Prepago';
      EjecutaComando('AMP '+IntToStr(xpos));
    end;

    Result:='True|';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_team.DesactivaModoPrepago(msj: string): string;
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
      for xpos:=1 to MaxPosCarga do begin
        TPosCarga[xpos].ModoOpera:='Prepago';
        EjecutaComando('DMP '+IntToStr(xpos));
      end;
    end
    else if (xpos in [1..maxposcarga]) then begin
      TPosCarga[xpos].ModoOpera:='Prepago';
      EjecutaComando('DMP '+IntToStr(xpos));
    end;

    Result:='True|';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_team.AutorizarVenta(msj: string): string;
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


function Togcvdispensarios_team.DetenerVenta(msj: string): string;
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

function Togcvdispensarios_team.EjecutaComando(xCmnd: string): integer;
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

function Togcvdispensarios_team.FinVenta(msj: string): string;
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

function Togcvdispensarios_team.ReanudarVenta(msj: string): string;
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

function Togcvdispensarios_team.RespuestaComando(msj: string): string;
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

function Togcvdispensarios_team.GuardarLog: string;
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

function Togcvdispensarios_team.GuardarLogPetRes: string;
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

function Togcvdispensarios_team.AgregaPosCarga(posiciones: TlkJSONbase): string;
var i,j,k,xpos,xcomb:Integer;
    existe:boolean;
    mangueras:TlkJSONbase;
    cPos:string;
begin
  try
    if not detenido then begin
      Result:='False|Es necesario detener el proceso antes de inicializar las posiciones de carga|';
      Exit;
    end;

    MaxPosCarga:=0;
    for i:=1 to 100 do with TPosCarga[i] do begin
      dispensario:=0;
      lado:=0;
      estatus:=0;
      estatusant:=0;
      posactual:=0;
      NoComb:=0;
      SwInicio:=true;
      SwInicio2:=true;
      IniciaCarga:=false;
      SwPrepago:=false;
      SwPreset:=false;
      ActualizarPrecio:=false;
      Mensaje:='';
      importe:=0;
      impopreset:=0;
      volumen:=0;
      precio:=0;
      importepre:=0;
      volumenpre:=0;
      preciopre:=0;
      importeant:=0;
      importenvo:=0;
      for j:=1 to MCxP do
        TotalLitros[j]:=0;
      SwCargando:=false;
      SwCargaPreset:=false;
      SwCargaTotales:=true;
      IntentosTotales:=0;
      PosAutorizada:=0;
      SwDeshabilitado:=false;
      SwArosMag:=false;
      SwArosMag_stop:=false;
      SwActivo:=false;
      ContEsperaB:=0;
      ContDesp:=0;
      StCero:=0;
      tipopago:=0;
      tipopagoant:=0;
      finventa:=0;
      TCodigoTeam:='';
      boucher:='';
    end;

    for i:=0 to posiciones.Count-1 do begin
      xpos:=posiciones.Child[i].Field['DispenserId'].Value;
      if xpos>MaxPosCarga then
        MaxPosCarga:=xpos;
      with TPosCarga[xpos] do begin
        ActualizarPrecio:=false;
        SwDesp:=false;
        SwA:=false;
        ModoOpera:='Prepago';
        mangueras:=posiciones.Child[i].Field['Hoses'];
        for j:=0 to mangueras.Count-1 do begin
          if ConfTeam<>'' then
            cPos:=ExtraeElemStrSep(ConfTeam,xpos,';')
          else begin
            Result:='Favor de configurar los lados de los dispensarios Team';
            Exit;
          end;
          Dispensario:=StrToInt(ExtraeElemStrSep(cPos,1,':'));
          Lado:=StrToInt(ExtraeElemStrSep(cPos,2,':'));
          xcomb:=mangueras.Child[j].Field['ProductId'].Value;
          existe:=false;
          for k:=1 to NoComb do
            if TComb[k]=xcomb then
              existe:=true;
          if not existe then begin
            inc(NoComb);
            TComb[NoComb]:=xcomb;
            if mangueras.Child[j].Field['HoseId'].Value>0 then
              TPos[NoComb]:=mangueras.Child[j].Field['HoseId'].Value
            else if NoComb<=MCxP then
              TPos[NoComb]:=NoComb
            else
              TPos[NoComb]:=1;
            TDiga[TPos[NoComb]]:=Con_DigitoAjuste;
            TMang[NoComb]:=mangueras.Child[j].Field['HoseId'].Value;
          end;
        end;
      end;
    end;
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_team.Inicializar(msj: string): string;
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

    Result:=AgregaPosCarga(dispensarios);

    if Result<>'' then
      Exit;

    Con_DigitoAjuste:=0;
    TresDecimTotTeam:='No';
    CodigoTeam:='00000000';
    for i:=1 to NoElemStrEnter(variables) do begin
      if UpperCase(ExtraeElemStrSep(variable,1,'='))='CONDIGITOAJUSTE' then
        Con_DigitoAjuste:=StrToInt(ExtraeElemStrSep(variable,2,'='))
      else if UpperCase(ExtraeElemStrSep(variable,1,'='))='TRESDECIMTOTTEAM' then
        TresDecimTotTeam:=ExtraeElemStrSep(variable,2,'=')
      else if UpperCase(ExtraeElemStrSep(variable,1,'='))='CODIGOTEAM' then
        CodigoTeam:=ExtraeElemStrSep(variable,2,'=');
    end;

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

function Togcvdispensarios_team.Login(mensaje: string): string;
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

function Togcvdispensarios_team.Logout: string;
begin
  Token:='';
  Result:='True|';
end;

function Togcvdispensarios_team.IniciaPrecios(msj: string): string;
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

function Togcvdispensarios_team.Bloquear(msj: string): string;
var
  xpos:Integer;
begin
  try
    xpos:=StrToIntDef(msj,-1);

    if xpos<0 then begin
      Result:='False|Favor de indicar correctamente la posicion de carga|';
      Exit;
    end;

    if (xpos<=MaxPosCarga) then begin
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

function Togcvdispensarios_team.Desbloquear(msj: string): string;
var
  xpos:Integer;
begin
  try
    xpos:=StrToIntDef(msj,-1);

    if xpos<0 then begin
      Result:='False|Favor de indicar correctamente la posicion de carga|';
      Exit;
    end;

    if (xpos<=MaxPosCarga) then begin
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

function Togcvdispensarios_team.TransaccionPosCarga(msj: string): string;
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
      Result:='True|'+FormatDateTime('yyyy-mm-dd',HoraOcc)+'T'+FormatDateTime('hh:nn',HoraOcc)+'|'+IntToStr(TMang[PosActual])+'|'+IntToStr(CombustibleEnPosicion(xpos,PosActual))+'|'+
              FormatFloat('0.000',volumen)+'|'+FormatFloat('0.00',precio)+'|'+FormatFloat('0.00',importe)+'|';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_team.CombustibleEnPosicion(xpos,
  xposcarga: integer): integer;
var i:integer;
begin
  with TPosCarga[xpos] do begin
    result:=TComb[1];
    for i:=1 to NoComb do begin
      if TPos[i]=xposcarga then
        result:=TComb[i];
    end;
  end;
end;

function Togcvdispensarios_team.EstadoPosiciones(msj: string): string;
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

function Togcvdispensarios_team.TotalesBomba(msj: string): string;
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

function Togcvdispensarios_team.Detener: string;
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

function Togcvdispensarios_team.Iniciar: string;
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

    detenido:=False;
    estado:=1;
    Timer1.Enabled:=True;
    numPaso:=0;

    ActivaModoPrepago('0');

    Result:='True|';
  except
    on e:Exception do
      Result:='False|'+e.Message+'|';
  end;
end;

function Togcvdispensarios_team.Shutdown: string;
begin
  if estado>0 then
    Result:='False|El servicio esta en proceso, no fue posible detenerlo|'
  else begin
    ServiceThread.Terminate;
    Result:='True|';
  end;
end;

function Togcvdispensarios_team.ObtenerEstado: string;
begin
  Result:='True|'+IntToStr(estado)+'|';
end;

function Togcvdispensarios_team.Terminar: string;
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

function Togcvdispensarios_team.ObtenerLog(r: Integer): string;
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

function Togcvdispensarios_team.ObtenerLogPetRes(r: Integer): string;
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

procedure Togcvdispensarios_team.Timer1Timer(Sender: TObject);
var xpos:integer;
    ss:string;
begin
  try
    if (now-HoraComandoB>5*TmSegundo)or(now-HoraRspB>5*TmSegundo) then begin
      AgregaLog('Reset');
      ListaCmnd.Clear;
      ContCmndU:=0;
      SwComandoB:=true;
      SwEsperaRsp:=false;
      HoraComandoB:=now;
      HoraRspB:=now;
      inc(contB);
      pSerial.Open:=false;
      EsperaMiliSeg(500);
      pSerial.Open:=true;
      if ContB>3 then begin
        GuardarLog;
        Detener;
        Terminar;
        Shutdown;
      end;
    end;
    if ContCmndU>0 then begin
      Dec(ContCmndU);
      exit;
    end;
    if SwComandoB then begin
      ComandoConsolaBuff('B'+IntToClavenum(PosCiclo,2),true);
      inc(PosCiclo);
      if PosCiclo>MaxPosCarga then begin
        PosCiclo:=1;
        LineaTimer:='B00';
        CheckSumB:=true;
        for xpos:=1 to MaxPosCarga do
          with TPosCarga[xpos] do begin
            if ContEsperaB>=3 then
              estatus:=0;
            if posactual>=10 then
              posactual:=(posactual)mod(10);
            LineaTimer:=LineaTimer+inttostr(PosActual)+inttostr(estatus);
          end;
        AgregaLog(LineaTimer);
        SwComandoB:=false;
        ProcesaLinea(CheckSumB);
      end;
      exit;
    end;
    if SwEsperaRsp then begin
      inc(ContEsperaRsp);
      if ContEsperaRsp>MaxEsperaRsp then
        SwEsperaRsp:=false;
    end;
    if not SwEsperaRsp then begin
      ContEsperaRsp:=0;
      if (ListaCmnd.Count>0) then begin
        ss:=ListaCmnd[0];
        ListaCmnd.Delete(0);
        ComandoConsola(ss);
        exit;
      end
      else SwComandoB:=true;
    end;
  except
  end;
end;


procedure Togcvdispensarios_team.pSerialTriggerAvail(CP: TObject; Count: Word);
var I,xpos,xcomb:Word;
    C:Char;
    ss,s1:string;
    csok:boolean;
begin
  ContEsperaRsp:=0;
  Timer1.Enabled:=false;
  try
    SwEsperaRsp:=false;
    for I := 1 to Count do begin
      C:=pSerial.GetChar;
      LineaBuff:=LineaBuff+C;
    end;
    while (not FinLinea)and(Length(LineaBuff)>0) do begin
      c:=LineaBuff[1];
      ss:=limpiastr(StrToHexSep(c));
      if (ss[1]='A')or(ss[1]='E') then // INICIA UN COMANDO
        linea:='';
      delete(LineaBuff,1,1);
      Linea:=Linea+C;
      LineaTimer:=StrToHexSep(Linea);
      if (copy(LineaTimer,1,2)='A3')and(noelemstrsep(LineaTimer,' ')=9) then
        FinLinea:=true
      else if (copy(LineaTimer,1,2)='A1')and(noelemstrsep(LineaTimer,' ')=11) then
        FinLinea:=true
      else if (copy(LineaTimer,1,2)='A5')and(noelemstrsep(LineaTimer,' ')=11) then
        FinLinea:=true
      else if (copy(LineaTimer,1,2)='A6')and(noelemstrsep(LineaTimer,' ')=12) then
        FinLinea:=true
      else if (copy(LineaTimer,1,2)='A0')and(noelemstrsep(LineaTimer,' ')=6) then
        FinLinea:=true
      else if (copy(LineaTimer,1,2)='A9')and(noelemstrsep(LineaTimer,' ')=12) then
        FinLinea:=true
      else if (copy(LineaTimer,1,2)='E0')and(noelemstrsep(LineaTimer,' ')=6) then
        FinLinea:=true;
    end;
    if FinLinea then begin
      LineaTimer:=StrToHexSep(Linea);
      csok:=ValidaChecksumTeam(LineaTimer);
      if not csok then
        LineaTimer:=LineaTimer+' Error Checksum';
      AgregaLog('R '+LineaTimer);
      FinLinea:=false;
      // A3 03 00 05 02 00 01 00 03
      if copy(LineaTimer,1,2)='A3' then begin  // Comando B
        if not csok then
          checksumb:=false;
        HoraRspB:=now;
        xpos:=DamePosTeam(LineaTimer,true);
        with TPosCarga[xpos] do begin
          ContEsperaB:=0;

          // Estatus del dispensario
          if csok then begin
            ss:=ExtraeElemStrSep(LineaTimer,6,' ');
            s1:=HexToBinario(ss);
            AgregaLog('R Binario: '+s1);
            case s1[2] of // bit 6
              '0':ModoOpera:='Normal';
              '1':ModoOpera:='Prepago';
            end;
            case s1[7] of  // bit 1
              '0':begin
                    estatus:=1; // Inactivo
                    if s1[3]='1' then  // bit 5
                      estatus:=2; // Autorizado
                  end;
              '1':estatus:=5; // Despachando
            end;
            if s1[8]='1' then // bit 0
              estatus:=9;
            if (estatus=1)and(finventa=1) then
              estatus:=8;
            if (estatus=1)and(finventa=2) then
              estatus:=7;

            // Producto: solo cuando està ocupado
            ss:=ExtraeElemStrSep(LineaTimer,7,' ');
            if strtointdef(ss[2],0)>0 then
              posactual:=strtointdef(ss[2],0);
          end;
        end;

      end
      else if copy(LineaTimer,1,2)='A1' then begin // COMANDO A
        xpos:=DamePosTeam(LineaTimer,true);
        with TPosCarga[xpos] do begin
          s1:=ExtraeElemStrSep(LineaTimer,6,' ');
          if s1='00' then begin // litros
            ss:=ExtraeElemStrSep(LineaTimer,7,' ')
               +ExtraeElemStrSep(LineaTimer,8,' ')
               +ExtraeElemStrSep(LineaTimer,9,' ')
               +ExtraeElemStrSep(LineaTimer,10,' ');
            try
              if (ss<>'FFFFFFFF')and(ss<>'88888888') then
                volumen:=strtoint(ss)/100
              else begin
                volumen:=0;
                importe:=0;
              end;
            except
              volumen:=0;
            end;
            // ComandoConsolaBuff('A'+inttoclavenum(xpos,2)+'1',true);
          end
          else if s1='01' then begin // pesos
            try
              ss:=ExtraeElemStrSep(LineaTimer,7,' ')
                 +ExtraeElemStrSep(LineaTimer,8,' ')
                 +ExtraeElemStrSep(LineaTimer,9,' ')
                 +ExtraeElemStrSep(LineaTimer,10,' ');
              if (ss<>'FFFFFFFF')and(ss<>'88888888') then begin
                importe:=strtoint(ss)/100;
                xcomb:=CombustibleEnPosicion(xpos,posactual);
                precio:=lprecios[xcomb];
                //if volumen=0 then
                volumen:=AjustaFloat(dividefloat(importe,precio),2);
                LineaTimer:='A'+inttoclavenum(xpos,2)+'0'
                             +FormatFloat('000000',volumen*100)
                             +FormatFloat('00000000',importe*100)
                             +FormatFloat('0000',precio*100);
                AgregaLog(LineaTimer);
                ProcesaLinea(csok);
              end
              else begin
                importe:=0;
                volumen:=0;
              end;
            except
              importe:=0;
            end;
          end;
          HoraOcc:=now;
        end
      end
      else if copy(LineaTimer,1,2)='A5' then begin // COMANDO S
        xpos:=DamePosTeam(LineaTimer,true);
        ss:=ExtraeElemStrSep(LineaTimer,6,' ');
        if ss='09' then
          LineaTimer:='L'+inttoclavenum(xpos,2)+'0'
        else
          LineaTimer:='S'+inttoclavenum(xpos,2)+'0';
        AgregaLog(LineaTimer);
        ProcesaLinea(csok);
      end
      else if copy(LineaTimer,1,2)='A6' then begin // COMANDO U
        xpos:=DamePosTeam(LineaTimer,false);
        LineaTimer:='U'+inttoclavenum(xpos,2)
                    +ExtraeElemStrSep(LineaTimer,6,' ')+ExtraeElemStrSep(LineaTimer,7,' ')
                    +ExtraeElemStrSep(LineaTimer,8,' ')+ExtraeElemStrSep(LineaTimer,9,' ')
                    +ExtraeElemStrSep(LineaTimer,10,' ')+ExtraeElemStrSep(LineaTimer,11,' ');
        AgregaLog(LineaTimer);
        ProcesaLinea(csok);
      end
      else if copy(LineaTimer,1,2)='A9' then begin // COMANDO N
        xpos:=DamePosTeam(LineaTimer,true);
        LineaTimer:='N'+inttoclavenum(xpos,2)+inttostr(TPosCarga[xpos].AuxCmndN)
                    +ExtraeElemStrSep(LineaTimer,6,' ')+ExtraeElemStrSep(LineaTimer,7,' ')
                    +ExtraeElemStrSep(LineaTimer,8,' ')+ExtraeElemStrSep(LineaTimer,9,' ')
                    +ExtraeElemStrSep(LineaTimer,10,' ')+ExtraeElemStrSep(LineaTimer,11,' ');
        AgregaLog(LineaTimer);
        ProcesaLinea(csok);
      end;
      Linea:='';
      SwEspera:=false;
    end
    else SwEspera:=true;
  finally
    Timer1.Enabled:=true;
  end;
end;

function Togcvdispensarios_team.ComandoA(xdisp, xlado, xtipo: integer): string; // Leer display
begin
  result:='A1 '+inttoclavenum(xdisp,2)+' 00 03 '+inttoclavenum(xlado,2)+' '+inttoclavenum(xtipo,2);
end;

function Togcvdispensarios_team.ComandoB(xdisp, xlado: integer): string;   // Leer estatus de bomba
begin
  result:='A3 '+inttoclavenum(xdisp,2)+' 00 02 '+inttoclavenum(xlado,2);
end;

function Togcvdispensarios_team.ComandoC(xdisp: integer): string; // Bloquea
var ss:string;
begin
  ss:='A0 '+inttoclavenum(xdisp,2)+' 00 02 ';
  ss:=ss+'06';
  result:=ss;
end;

function Togcvdispensarios_team.ComandoD(xdisp: integer): string; // Desbloquea
var ss:string;
begin
  ss:='A0 '+inttoclavenum(xdisp,2)+' 00 02 ';
  ss:=ss+'09';
  result:=ss;
end;

function Togcvdispensarios_team.ComandoL(xdisp, xlado: integer; // Presetear
  xlitros: real): string;
var ss,ss2:string;
    ii:integer;
begin
  ss:='A5 '+inttoclavenum(xdisp,2)+' 00 07 '+inttoclavenum(xlado,2)+' 09';
  ii:=trunc(xlitros*1000+0.5); ss2:=inttoclavenum(ii,8);
  result:=ss+' '+copy(ss2,1,2)+' '+copy(ss2,3,2)+' '+copy(ss2,5,2)+' '+copy(ss2,7,2);
end;

function Togcvdispensarios_team.ComandoN(xdisp, xlado, xprod: integer): string;  // Totales
begin
  result:='A9 '+inttoclavenum(xdisp,2)+' 00 03 '+inttoclavenum(xlado,2)+' '+inttoclavenum(xprod,2);
end;

function Togcvdispensarios_team.ComandoS(xdisp, xlado: integer; ximpo: real): string; // Presetear
var ss,ss2:string;
    ii:integer;
begin
  ss:='A5 '+inttoclavenum(xdisp,2)+' 00 07 '+inttoclavenum(xlado,2)+' 06';
  ii:=trunc(ximpo*100+0.5); ss2:=inttoclavenum(ii,8);
  result:=ss+' '+copy(ss2,1,2)+' '+copy(ss2,3,2)+' '+copy(ss2,5,2)+' '+copy(ss2,7,2);
end;

function Togcvdispensarios_team.ComandoU(xdisp: integer; xprec1, xprec2,
  xprec3: real): string;  // Cambio precios
var ss,ss2:string;
    ii:integer;
begin
  ss:='A6 '+inttoclavenum(xdisp,2)+' 00 08 ';
  ss:=ss+'06';
  ii:=trunc(xprec1*100+0.5); ss2:=inttoclavenum(ii,4);
  ss:=ss+' '+copy(ss2,1,2)+' '+copy(ss2,3,2);
  ii:=trunc(xprec2*100+0.5); ss2:=inttoclavenum(ii,4);
  ss:=ss+' '+copy(ss2,1,2)+' '+copy(ss2,3,2);
  ii:=trunc(xprec3*100+0.5); ss2:=inttoclavenum(ii,4);
  ss:=ss+' '+copy(ss2,1,2)+' '+copy(ss2,3,2);
  result:=ss;
end;

function Togcvdispensarios_team.ComandoW(xdisp, xlado, xvalor: integer): string;
//  E0 04 00 06 05 03 26 11 14 59
//  E0 04 00 06 05 14 11 26 03 59
var ss:string;
    xcodigoteam:string;
    i:integer;
begin
  ss:='E0 '+inttoclavenum(xdisp,2)+' 00 06 '+inttoclavenum(xvalor,2)+' '+inttoclavenum(xlado,2);
  //   E0      DD                    00 06          %%                           LL
  if length(CodigoTeam)=8 then
    xcodigoteam:=copy(CodigoTeam,2,6)
  else if length(CodigoTeam)=6 then
    xcodigoteam:=CodigoTeam
  else
    xcodigoteam:='000000';
  for i:=1 to 3 do
    ss:=ss+' '+copy(xCodigoTeam,i*2-1,2);
  result:=ss;
end;

function Togcvdispensarios_team.DamePosTeam(ss: string; swlado: boolean): integer;
var xdisp,xlado,xpos:integer;
    sd,sl:string;
begin
  result:=0;
  sd:=extraeelemstrsep(ss,2,' ');
  xdisp:=strtointdef(sd,0);
  if swlado then begin
    sl:=extraeelemstrsep(ss,5,' ');
    xlado:=strtointdef(sl,0);
  end
  else xlado:=0;
  xpos:=1;
  while xpos<=MaxPosCarga do with TPosCarga[xpos] do begin
    if (dispensario=xdisp)and((not swlado)or(xlado=lado)) then begin
      result:=xpos;
      exit;
    end;
    inc(xpos);
  end;
end;

function Togcvdispensarios_team.HexSepToStr(ss: string): string;
var i,ne:integer;
    st,xaux:string;
begin
  xaux:='';
  ne:=NoElemStrSep(ss,' ');
  for i:=1 to ne do begin
    st:=ExtraeElemStrSep(ss,i,' ');
    xaux:=xaux+HexToStr(st);
  end;
  result:=xaux;
end;

function Togcvdispensarios_team.HexToBinario(ss: string): string;
var nn,n1,n2:byte;
  function ConvierteBin(nn:byte):string;
  begin
    case nn of
      0:result:='0000';
      1:result:='0001';
      2:result:='0010';
      3:result:='0011';
      4:result:='0100';
      5:result:='0101';
      6:result:='0110';
      7:result:='0111';
      8:result:='1000';
      9:result:='1001';
    end;
  end;
begin
  nn:=strtointdef(ss,0);
  n1:=(nn)div(10);
  n2:=(nn)mod(10);
  result:=ConvierteBin(n1)+ConvierteBin(n2);
end;

function Togcvdispensarios_team.PosicionDeCombustible(xpos, xcomb: integer): integer;
var i:integer;
begin
  with TPosCarga[xpos] do begin
    result:=0;
    if xcomb>0 then begin
      for i:=1 to NoComb do begin
        if TComb[i]=xcomb then
          result:=TComb[i];
      end;
    end
    else result:=1;
  end;
end;

function Togcvdispensarios_team.StrToHexSep(ss: string): string;
var i:integer;
    xaux:string;
begin
  xaux:=inttohex(ord(ss[1]),2);
  for i:=2 to length(ss) do
    xaux:=xaux+' '+inttohex(ord(ss[i]),2);
  result:=xaux;
end;

function Togcvdispensarios_team.ValidaChecksumTeam(LineaTimer: string): boolean;
var cs,i,ne,val,tot:integer;
    ss:string;
begin
  result:=false;
  ne:=noelemstrsep(LineaTimer,' ');
  ss:=ExtraeElemStrSep(LineaTimer,ne,' ');
  cs:=StrToIntDef(ss,0);
  tot:=0;
  for i:=5 to ne-1 do begin
    ss:=ExtraeElemStrSep(LineaTimer,i,' ');
    val:=StrToIntDef(ss,0);
    tot:=tot+val;
  end;
  tot:=tot mod 100;
  result:=(tot=cs);
end;

procedure Togcvdispensarios_team.EnviaPreset(var rsp: string; xcomb: integer;
  swpreset: boolean);
var xpos:integer;
    ss:string;
begin
  rsp:='OK';
  xpos:=SnPosCarga;
  if not (TPosCarga[xpos].estatus=1) then begin
    rsp:='Posición no Disponible';
    exit;
  end;
  if TPosCarga[xpos].SwDesHabilitado then begin
    rsp:='Posición Deshabilitada';
    exit;
  end;
  if SnLitros>=0.5 then
    ss:='L'+IntToClaveNum(xpos,2)+FiltraStrNum(FormatFloat('0000.00',SnLitros))
  else
    ss:='S'+IntToClaveNum(xpos,2)+FiltraStrNum(FormatFloat('0000.00',SnImporte));
  ComandoConsolaBuff(ss,false);
end;

function Togcvdispensarios_team.ResultadoComando(xFolio: integer): string;
var i:integer;
begin
  Result:='*';
  for i:=1 to 40 do
    if (TabCmnd[i].folio=xfolio)and(TabCmnd[i].SwResp) then
      result:=TabCmnd[i].Respuesta;
end;

function Togcvdispensarios_team.ExtraeElemStrEnter(xstr: string; ind: word): string;
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

function Togcvdispensarios_team.NoElemStrEnter(xstr: string): word;
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

function Togcvdispensarios_team.MD5(const usuario: string): string;
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

end.
