unit UIGASWAYNE2W;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, SvcMgr, Dialogs,
  OoMisc, AdPort, ScktComp, IniFiles, ActiveX, ComObj, Ulibgral, Variants,
  ExtCtrls, CRCs, uLkJSON, IdHashMessageDigest, IdHash;

  const
    MCxP=4;  

type
  Togcvdispensarios_wayne2w = class(TService)
    pSerial: TApdComPort;
    Timer1: TTimer;
    pSerial2: TApdComPort;
    Timer2: TTimer;
    ClientSocket1: TClientSocket;
    procedure ServiceExecute(Sender: TService);
    procedure pSerialTriggerAvail(CP: TObject; Count: Word);
    procedure pSerialTriggerData(CP: TObject; TriggerHandle: Word);
    procedure Timer1Timer(Sender: TObject);
    procedure pSerial2TriggerAvail(CP: TObject; Count: Word);
    procedure ServiceStop(Sender: TService; var Stopped: Boolean);
    procedure ServiceShutdown(Sender: TService);
    procedure ServiceDestroy(Sender: TObject);
    procedure pSerial2TriggerData(CP: TObject; TriggerHandle: Word);
    procedure Timer2Timer(Sender: TObject);
    procedure ClientSocket1Connect(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure ClientSocket1Disconnect(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure ClientSocket1Read(Sender: TObject; Socket: TCustomWinSocket);
  private
    { Private declarations }
    WtwDivImporte:Integer;
    WtwDivLitros:Integer;
    GtwTimeout:Integer;
    GtwTiempoCmnd:Integer;
    WtwPosIniExt:Integer;
    PosCiclo,MangCiclo,
    ls,ContLeeVenta,
    NumPaso         :integer;
    srespuesta : string;
    srespuesta2 : string;
    iBytesEsperados : integer;
    bListo, bListo2,
    bEndOfText, bLineFeed : boolean;
    etTimeOut : EventTimer;
    etTimeOut2 : EventTimer;
    wTriggerEOT, wTriggerLF : word;
    SwAplicaCmnd,
    SwInicio,
    SwBring,
    SwEspera      :boolean;
    CmndNuevo     :Boolean;
    ContadorAlarma:Integer;
    HoraEspera, HoraArranque  :TDateTime;
    SwPasoBien :boolean;
    conectado, respJson:Boolean;
    rootJSON : TlkJSONbase;
    socketResponse : TCustomWinSocket;
    function  TransmiteComando1(DataBlock:string):boolean;
    function  TransmiteComando2(DataBlock:string):boolean;
  public
    ListaLog:TStringList;
    ListaLogPetRes:TStringList;
    ListaComandos:TStringList;
    rutaLog:string;
    detenido:Boolean;
    estado:Integer;
    mapeoMangueras:String;
    xTurnoSocket:Integer;
    version:String;
    ListaCmnd    :TStrings;
    FolioCmnd   :integer;
    horaLog:TDateTime;
    minutosLog:Integer;
    function GetServiceController: TServiceController; override;
    procedure Responder(resp:string);
    procedure AgregaLog(lin:string);
    procedure AgregaLogPetRes(lin: string);
    function CRC16(Data: AnsiString): AnsiString;
    procedure GuardaLogComandos;
    function AgregaPosCarga(posiciones: TlkJSONbase):string;
    function IniciaPSerial(datosPuerto:string):string;
    function IniciaPSerial2(datosPuerto:string):string;
    procedure Inicializar(folio:Integer; msj: string);
    function NoElemStrEnter(xstr:string):word;
    function ExtraeElemStrEnter(xstr:string;ind:word):string;
    function MD5(const usuario: string): string;
    function EjecutaComando(xCmnd:string):integer;
    function TransaccionPosCarga(msj: string): string;
    function ObtenerEstado: string;
    function ResultadoComando(xFolio:integer):string;
    function  LeePrecios(xPosCarga : integer): boolean;
    function  DameEstatus(xPosCarga:integer) : integer;
    function  ReanudaDespacho(xPosCarga: integer) : boolean;
    function  DetenerDespacho(xPosCarga : integer) : boolean;
    procedure EstatusDispensarios;
    function  DameLecturas(xPosCarga : integer; var rLitros, rPrecio, rPesos : real) : boolean;
    function  DameTotal(xPosCarga,xPos : integer; var rTotalLitros: real) : boolean;
    function  Autoriza(xPosCarga: integer) : boolean;
    function  AutorizaPm(xPosCarga,xPm: integer) : boolean;
    function  EnviaPresetPesosBomba(xPosCarga,xTipoPreset: integer; xValor: real) : boolean;
    procedure ProcesaComandos;
    function ValidaCifra(xvalor:real;xenteros,xdecimales:byte):string;
    function PosicionDeCombustible(xpos,xcomb:integer):integer;
    function  CambiaPrecios(xPosCarga : integer): boolean;
    procedure AvanzaPosCiclo;
    procedure PonPuertoPos(xpos:integer);
    procedure Bloquear(folio:Integer; msj: string);
    procedure Desbloquear(folio:Integer; msj: string);
    procedure Detener(folio:Integer);
    procedure Iniciar(folio:Integer);
    procedure Shutdown(folio:Integer);
    procedure AutorizarVenta(folio:Integer; msj: string);
    procedure DetenerVenta(folio:Integer; msj: string);
    procedure ReanudarVenta(folio:Integer; msj: string);
    procedure RespuestaComando(folio:Integer; msj: string);
    procedure ObtenerLog(folio:Integer; r: Integer);
    procedure ObtenerLogPetRes(folio:Integer; r: Integer);
    procedure ActivaModoPrepago(folio:Integer; msj:string);
    procedure DesactivaModoPrepago(folio:Integer; msj:string);
    procedure FinVenta(folio:Integer; msj: string);
    procedure Terminar(folio:Integer);
    procedure IniciaPrecios(folio:Integer; msj:string);
    procedure GuardarLog(folio:Integer);
    procedure GuardarLogPetRes(folio:Integer);
    procedure TotalesBomba(folio:Integer; msj: string);
    procedure Login(folio:Integer; mensaje:string);
    procedure Logout(folio:Integer);
    procedure ActualizaCampoJSON(xpos:Integer; campo:string; valor:Variant);
    procedure AddPeticionJSON(const aFolio: Integer; const aResultado : string);
    procedure ApplyTotalLitrosToJSON(const xpos: Integer; const TotalLitros: array of Real);
    procedure SetEstadoJSON(const AEstado: Integer);
    { Public declarations }
  end;

type
     tiposcarga = record
       SwDesHabil   :boolean;
       DivImporte,
       DivLitros,
       estatus,
       estatusant   :integer;
       importe,
       volumen,
       precio       :real;
       Isla,
       xCiclo,
       PosActual    :integer; // Posicion del combustible en proceso: 1..NoComb
       NoComb       :integer; // Cuantos combustibles hay en la posicion
       TComb        :array[1..MCxP] of integer; // Claves de los combustibles
       TPosx        :array[1..MCxP] of integer;
       TPrecio      :array[1..MCxP] of real;
       TMang        :array[1..MCxP] of integer;
       TotalLitros  :array[1..MCxP] of real;
       SwLeeTotales :array[1..MCxP] of boolean;

       TCambioPrecN1:boolean;
       TNuevoPrec   :array[1..MCxP] of real;

       MontoPreset    :string;

       swprec,
       swdesp,
       swcargando     :boolean;
       ModoOpera      :string[8];
       EsperaFinVenta :integer;

       SwStatusFV,
       SwLeeVenta,
       SwLeePrecios,
       SwCambiaPrecio,
       SwPreset2,
       SwPreset       :boolean;
       TipoPreset,
       PosPreset      :integer;
       ValorPreset    :real;
       PosMangLev     :integer;
       MangActual:Integer;
       CombActual:Integer;
       HoraOcc:TDateTime;
       Avanzar:Integer;
       SinComunicacion: Boolean;
       HoraDesconexion: TDateTime;
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
  TMetodos = (
    NOTHING_e, INITIALIZE_e,PARAMETERS_e,
    LOGIN_e, LOGOUT_e,PRICES_e,
    AUTHORIZE_e,STOP_e, START_e, SELFSERVICE_e,
    FULLSERVICE_e, BLOCK_e, UNBLOCK_e,
    PAYMENT_e, TRANSACTION_e, STATUS_e,
    TOTALS_e, HALT_e, RUN_e, SHUTDOWN_e,
    TERMINATE_e, STATE_e, TRACE_e,
    SAVELOGREQ_e, RESPCMND_e, LOG_e, LOGREQ_e);

var
  ogcvdispensarios_wayne2w: Togcvdispensarios_wayne2w;
  TPosCarga:array[1..100] of tiposcarga;
  TabCmnd  :array[1..200] of RegCmnd;
  LPrecios  :array[1..4] of Double;
  StCiclo,
  SegmActual,
  MaxPosCarga:integer;
  EstatusAnterior,
  StrCiclo,
  EstatusActual  :string;
  PreciosInicio :Boolean;
  Token        :string;

implementation

uses
  TypInfo, StrUtils, Math, DateUtils;

{$R *.DFM}

function DamePosOrdinal(xPosCarga,xPos:integer):integer;
var i:integer;
begin
  i:=1;
  while (TPosCarga[xPosCarga].TPosx[i]<>xPos)and(i<4) do
    inc(i);
  if i<=4 then
    result:=i
  else result:=0;
end;

function LeeTotalPosCiclo(xPos:integer; var xmang:integer):boolean;
begin
  with TPosCarga[xPos] do begin
    xMang:=NoComb;
    while (not SwLeeTotales[xMang])and(xMang>0) do
      dec(xMang);
    result:=xMang>0;
  end;
end;

function ExtraeBCD(xstr:string;xini,xfin:integer):real;
var i:integer;
    ss:string;
begin
  i:=xfin;
  ss:='';
  while i>=xini do begin
    ss:=ss+ExtraeElemStrSep(xstr,i,' ');
    dec(i);
  end;
  result:=strtoint(ss);
end;

function ConvierteBCD(xvalor:real;xlong:integer):string;
var xstr,xres,ss:string;
    i,nc,nn,num:integer;
begin
  num:=trunc(xvalor+0.5);
  xstr:=inttoclavenum(num,xlong);
  nc:=xlong div 2;
  xres:='';
  for i:=1 to nc do begin
    ss:=copy(xstr,xlong-2*i+1,2);
    nn:=StrToIntDef(ss[1],0)*16+StrToIntDef(ss[2],0);
    xres:=xres+char(nn);
  end;
  result:=xres;
end;


function EmpacaWayne(xss:string):string;
var ss2:string;
    long,i:integer;
begin
  long:=length(xss);
  if not (long in [1,5]) then begin
    result:='';
    exit;
  end;
  ss2:='';
  for i:=1 to long do begin
    ss2:=ss2+xss[i]+char(255-ord(xss[i]));
  end;
  result:=#0#0+ss2+#255;
end;

function DesEmpacaWayne(xss:string):string;
var long:integer;
begin
  result:='';
  long:=length(xss);
  if long=13 then
    if (xss[1]=#0)and(xss[2]=#0)and(xss[13]=#255) then
      result:=xss[3]+xss[5]+xss[7]+xss[9]+xss[11];
end;

function ControlByte(xpos,xcmnd:integer):integer;
begin
  if (xpos<=31)and(xcmnd<=7) then
    result:=xpos*8+xcmnd
  else
    result:=0;
end;

procedure ServiceController(CtrlCode: DWord); stdcall;
begin
  ogcvdispensarios_wayne2w.Controller(CtrlCode);
end;

function Togcvdispensarios_wayne2w.GetServiceController: TServiceController;
begin
  Result := ServiceController;
end;

procedure Togcvdispensarios_wayne2w.ServiceExecute(Sender: TService);
var
  config:TIniFile;
begin
  try
    config:= TIniFile.Create(ExtractFilePath(ParamStr(0)) +'PDISPENSARIOS.ini');
    rutaLog:=config.ReadString('CONF','RutaLog','C:\ImagenCo');
    minutosLog:=StrToInt(config.ReadString('CONF','MinutosLog','0'));
    ClientSocket1.Host:=ExtraeElemStrSep(config.ReadString('CONF','ServidorSocket','127.0.0.1:1004'), 1, ':');
    ClientSocket1.Port:=StrToInt(ExtraeElemStrSep(config.ReadString('CONF','ServidorSocket','127.0.0.1:1004'), 2, ':'));
    mapeoMangueras:=config.ReadString('CONF','MapeoMangueras','');
    ListaCmnd:=TStringList.Create;
    detenido:=True;
    estado:=-1;
    horaLog:=Now;
    HoraArranque:=Now;
    ListaLog:=TStringList.Create;
    ListaLogPetRes:=TStringList.Create;
    ListaComandos:=TStringList.Create;
    rootJSON:=TlkJSONObject.Create;
    SetEstadoJSON(estado);

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

procedure Togcvdispensarios_wayne2w.AgregaLog(lin: string);
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
    on e:Exception do begin
      AgregaLog('Error AgregaLog: '+e.Message);
      GuardarLog(0);
    end;
  end;
end;

procedure Togcvdispensarios_wayne2w.AgregaLogPetRes(lin: string);
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
    while ListaLogPetRes.Count>10000 do
      ListaLogPetRes.Delete(0);
    ListaLogPetRes.Add(lin2);
  except
    on e:Exception do begin
      AgregaLog('Error AgregaLogPetRes: '+e.Message);
      GuardarLog(0);
    end;
  end;
end;

function Togcvdispensarios_wayne2w.CRC16(Data: AnsiString): AnsiString;
var
  aCrc:TCRC;
  pin : Pointer;
  insize:Cardinal;
begin
  try
    insize:=Length(Data);
    pin:=@Data[1];
    aCrc:=TCRC.Create(CRC16Desc);
    aCrc.CalcBlock(pin,insize);
    Result:=UpperCase(IntToHex(aCrc.Finish,4));
    aCrc.Destroy;
  except
    on e:Exception do begin
      AgregaLog('Error CRC16: '+e.Message);
      GuardarLog(0);
    end;
  end;
end;

procedure Togcvdispensarios_wayne2w.Responder(resp: string);
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

procedure Togcvdispensarios_wayne2w.GuardaLogComandos;
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
    ListaComandos.SaveToFile(rutaLog+'\LogDispComandos'+FiltraStrNum(FechaHoraExtToStr(Now))+'.txt');
  except
    on e:Exception do
      Exception.Create('GuardaLogComandos: '+e.Message);
  end;
end;

function Togcvdispensarios_wayne2w.AgregaPosCarga(
  posiciones: TlkJSONbase): string;
var
  i,j,k,xpos,xcomb,xc:integer;
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
    EstatusAnterior:='';
    MaxPosCarga:=0;
    xc:=0;
    for i:=1 to 32 do with TPosCarga[i] do begin
      xCiclo:=xc;
      inc(xc);
      if xc>2 then
        xc:=0;
      DivImporte:=WtwDivImporte;
      DivLitros:=WtwDivLitros;
      estatus:=0;
      estatusant:=0;
      HoraOcc:=0;
      NoComb:=0;
      SwPreset:=false;
      SwPreset2:=false;
      PosPreset:=0;
      TipoPreset:=0;
      ValorPreset:=0;
      PosMangLev:=0;
      importe:=0;
      volumen:=0;
      precio:=0;
      PosActual:=1;
      Esperafinventa:=0;
      Avanzar:=Random(3);
      SwCargando:=false;
      swdesp:=false;
      for j:=1 to MCxP do begin
        TotalLitros[j]:=0;
        TNuevoPrec[j]:=0;
        SwLeeTotales[j]:=true;
        TPrecio[j]:=0;
      end;
      SwDeshabil:=false;
      SwLeeVenta:=true;
      SwStatusFV:=false;
      SwCambiaPrecio:=false;
      SwLeePrecios:=true;
    end;

    posArr := TlkJSONlist.Create;

    for i:=0 to posiciones.Count-1 do begin
      xpos:=posiciones.Child[i].Field['DispenserId'].Value;
      if xpos>MaxPosCarga then
        MaxPosCarga:=xpos;
      if (xpos in [1..32]) then begin
        with TPosCarga[xpos] do begin
          ModoOpera:='Prepago';

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
            existe:=false;
            xcomb:=mangueras.Child[j].Field['ProductId'].Value;
            for k:=1 to NoComb do
              if TComb[k]=xcomb then
                existe:=true;
            if not existe then begin
              inc(NoComb);
              TComb[NoComb]:=xcomb;
              TMang[NoComb]:=mangueras.Child[j].Field['HoseId'].Value;
              if mapeoMangueras<>'' then
                TPosx[NoComb]:=StrToInt(ExtraeElemStrSep(ExtraeElemStrSep(mapeoMangueras,xpos,';'),TMang[NoComb],','))
              else
                TPosx[NoComb]:=mangueras.Child[j].Field['HoseId'].Value;

              hoseObj := TlkJSONObject.Create;
              hoseObj.Add('HoseId',TMang[NoComb]);
              hoseObj.Add('ProductId', xcomb);
              hoseObj.Add('Total', 0);
              hosesArr.Add(hoseObj);
            end;
          end;
          posObj.Add('Hoses', hosesArr);
        end;
        posArr.Add(posObj);
      end;
    end;
    TlkJSONobject(rootJSON).Add('PosCarga',   posArr);
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_wayne2w.IniciaPSerial(
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

procedure Togcvdispensarios_wayne2w.Inicializar(folio:Integer; msj: string);
var
  js: TlkJSONBase;
  consolas,dispensarios,productos: TlkJSONbase;
  i,productID: Integer;
  datosPuerto, variables, variable, resultado:string;
begin
  try
    if estado>-1 then begin
      resultado:='False|El servicio ya habia sido inicializado|';
      AddPeticionJSON(folio, resultado);
      Exit;
    end;

    js := TlkJSON.ParseText(ExtraeElemStrSep(msj,1,'|'));
    variables:=ExtraeElemStrSep(msj,2,'|');

    WtwDivImporte:=100;
    WtwDivLitros:=100;
    GtwTimeout:=1000;
    GtwTiempoCmnd:=1000;
    WtwPosIniExt:=999;
    for i:=1 to NoElemStrEnter(variables) do begin
      variable:=ExtraeElemStrEnter(variables,i);
      if UpperCase(ExtraeElemStrSep(variable,1,'='))='WTWDIVIMPORTE' then
        WtwDivImporte:=StrToIntDef(ExtraeElemStrSep(variable,2,'='),0)
      else if UpperCase(ExtraeElemStrSep(variable,1,'='))='WTWDIVLITROS' then
        WtwDivLitros:=StrToIntDef(ExtraeElemStrSep(variable,2,'='),0)
      else if UpperCase(ExtraeElemStrSep(variable,1,'='))='GTWTIMEOUT' then
        GtwTimeout:=StrToIntDef(ExtraeElemStrSep(variable,2,'='),0)
      else if UpperCase(ExtraeElemStrSep(variable,1,'='))='GTWTIEMPOCMND' then
        GtwTiempoCmnd:=StrToIntDef(ExtraeElemStrSep(variable,2,'='),0)
      else if UpperCase(ExtraeElemStrSep(variable,1,'='))='WTWPOSINIEXT' then
        WtwPosIniExt:=StrToIntDef(ExtraeElemStrSep(variable,2,'='),0);
    end;

    consolas := js.Field['Consoles'];

    for i:=0 to consolas.Count-1 do begin
      datosPuerto:=VarToStr(consolas.Child[i].Field['Connection'].Value);

      if (i>0) and (WtwPosIniExt>0) then
        resultado:=IniciaPSerial2(datosPuerto)
      else
        resultado:=IniciaPSerial(datosPuerto);

      if resultado<>'' then begin
        AddPeticionJSON(folio, resultado);
        Exit;
      end;
    end;

    dispensarios := js.Field['Dispensers'];

    resultado:=AgregaPosCarga(dispensarios);

    if resultado<>'' then begin
      AddPeticionJSON(folio, resultado);
      Exit;
    end;

    productos := js.Field['Products'];

    for i:=0 to productos.Count-1 do begin
      productID:=productos.Child[i].Field['ProductId'].Value;
      if productos.Child[i].Field['Price'].Value<0 then begin
        resultado:='False|El precio '+IntToStr(productID)+' es incorrecto|';
        AddPeticionJSON(folio, resultado);
        Exit;
      end;
      LPrecios[productID]:=productos.Child[i].Field['Price'].Value;    
    end;
    PreciosInicio:=False;
    SegmActual:=1;
    estado:=0;
    AddPeticionJSON(folio, 'True|');
  except
    on e:Exception do
      AddPeticionJSON(folio, 'False|Excepcion: '+e.Message+'|');
  end;
end;

function Togcvdispensarios_wayne2w.ExtraeElemStrEnter(xstr: string;
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

function Togcvdispensarios_wayne2w.NoElemStrEnter(xstr: string): word;
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

function Togcvdispensarios_wayne2w.MD5(const usuario: string): string;
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

function Togcvdispensarios_wayne2w.EjecutaComando(xCmnd: string): integer;
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
      CmndNuevo:=True;
    end;
    Result:=FolioCmnd;
  except
    on e:Exception do begin
      AgregaLog('Error EjecutaComando: '+e.Message);
      GuardarLog(0);
    end;
  end;
end;

function Togcvdispensarios_wayne2w.TransaccionPosCarga(
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

function Togcvdispensarios_wayne2w.ObtenerEstado: string;
begin
  try
    Result:='True|'+IntToStr(estado)+'|';
  except
    on e:Exception do begin
      AgregaLog('Error ObtenerEstado: '+e.Message);
      GuardarLog(0);
    end;
  end;
end;

function Togcvdispensarios_wayne2w.ResultadoComando(
  xFolio: integer): string;
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

procedure Togcvdispensarios_wayne2w.pSerialTriggerAvail(CP: TObject;
  Count: Word);
var i : integer;
begin
  try
    for i:=1 to Count do begin
      sRespuesta:= sRespuesta + pSerial.GetChar;
    end;
    i:= length(sRespuesta);
    if ( ( i>=iBytesEsperados ) ) then //or ( bEndOfText )  or ( bLineFeed ) ) then
       bListo:= true
    else
       newtimer(etTimeOut,MSecs2Ticks(GtwTimeout));
  except
    on e:Exception do begin
      AgregaLog('Error pSerialTriggerAvail: '+e.Message);
      GuardarLog(0);
    end;
  end;
end;

procedure Togcvdispensarios_wayne2w.pSerialTriggerData(CP: TObject;
  TriggerHandle: Word);
begin
  try
    if ( TriggerHandle=wTriggerEOT ) then
       bEndOfText:= true
    else
       bLineFeed:= true;
  except
    on e:Exception do begin
      AgregaLog('Error pSerialTriggerData: '+e.Message);
      GuardarLog(0);
    end;
  end;
end;

function Togcvdispensarios_wayne2w.LeePrecios(xPosCarga: integer): boolean;
var DataBlock,
    sse,ss,ss1,
    stComando   :string;
    xp,xcomb,xposfis:integer;
    val1,val2:integer;
    xprecio:real;
begin
  try
    PonPuertoPos(xPosCarga);
    result:=false;
    for xp:=1 to TPosCarga[xPosCarga].nocomb do begin
      xposfis:=TPosCarga[xPosCarga].TPosx[xp];
      stComando:= char(ControlByte(xPosCarga,7))+#0+char(xposfis-1)+#0+#0;         //   0F 00 00 F2 03
      sse:=StrToHexSep(stComando);
      DataBlock:=EmpacaWayne(stComando);
      if SegmActual=1 then begin
        if ( ( TransmiteComando1(DataBlock) ) and ( length(sRespuesta)=13 ) ) then begin
          ss:=StrToHexSep(DesempacaWayne(sRespuesta));
          ss1:=ExtraeElemStrSep(ss,5,' ');
          Val1:=HexToInt(ss1);
          ss1:=ExtraeElemStrSep(ss,4,' ');
          Val2:=HexToInt(ss1);
          xprecio:=256*val1+val2;
          TPosCarga[xPosCarga].TPrecio[xp]:=dividefloat(xprecio,100);
          Esperamiliseg(50);
          if xp=TPosCarga[xPosCarga].nocomb then
            result:=true;
        end;
      end
      else begin
        if ( ( TransmiteComando2(DataBlock) ) and ( length(sRespuesta2)=13 ) ) then begin
          ss:=StrToHexSep(DesempacaWayne(sRespuesta2));
          ss1:=ExtraeElemStrSep(ss,5,' ');
          Val1:=HexToInt(ss1);
          ss1:=ExtraeElemStrSep(ss,4,' ');
          Val2:=HexToInt(ss1);
          xprecio:=256*val1+val2;
          TPosCarga[xPosCarga].TPrecio[xp]:=dividefloat(xprecio,100);
          Esperamiliseg(50);
          if xp=TPosCarga[xPosCarga].nocomb then
            result:=true;
        end;
      end;
    end;
  except
    on e:Exception do begin
      AgregaLog('Error LeePrecios: '+e.Message);
      GuardarLog(0);
    end;
  end;
end;

function Togcvdispensarios_wayne2w.TransmiteComando1(
  DataBlock: string): boolean;
var ss:string;
    iMaxIntentos,i,
    iNoIntento    :integer;
    bOk           :boolean;
begin
  try
    Timer1.Enabled:=False;
    try
      iMaxIntentos:=2;
      iBytesEsperados:=13;
      iNoIntento:= 0;
      bOk:=false;
      repeat
         inc(iNoIntento);
         bListo:= false;
         bEndOfText:= false;
         bLineFeed:= false;
         sRespuesta:= '';
         pSerial.FlushInBuffer;
         pSerial.FlushOutBuffer;
         ss:=StrToHexSep(DataBlock);
         AgregaLog('E  '+ss);
         for i:= 1 to length ( DataBlock ) do begin
            pSerial.PutChar(DataBlock[i]);
            repeat
               pSerial.ProcessCommunications;
            until ( pSerial.OutBuffUsed=0 );
         end;
         if ( not bOk ) then begin
            newtimer(etTimeOut,MSecs2Ticks(GtwTimeout));
            repeat
               ServiceThread.ProcessRequests(False);
            until ( ( bListo ) or ( timerexpired(etTimeOut) ) );
            AgregaLog('sRespuesta Length: '+IntToStr(length(sRespuesta)));
            if ( bListo ) then begin
              if length(sRespuesta)=13 then begin
                bOk:=true;
                AgregaLog('R  '+StrToHexSep(sRespuesta));
              end;
            end;
            if ( not bOk ) then begin
               if  ( iNoIntento<iMaxIntentos ) then sleep(GtwTiempoCmnd);
            end;
         end;
      until ( ( bOk ) or ( iNoIntento>=iMaxIntentos ) );
      result:= bOk;
    except
      on e:Exception do begin
        AgregaLog('Error TransmiteComando1: '+e.Message);
        GuardarLog(0);
      end;
    end;
  finally
    Timer1.Enabled:=True;
  end;
end;

function Togcvdispensarios_wayne2w.DameEstatus(
  xPosCarga: integer): integer;
var iStatus,i,xposact : integer;
    StrBin,DataBlock:string;
    chComando:char;
    tbit:array[0..7] of boolean;
begin
  try
    PonPuertoPos(xPosCarga);
    iStatus:= 0;
    chComando:= char(ControlByte(xPosCarga,1));     // Comando 1
    DataBlock:=EmpacaWayne(chComando);
    if SegmActual=1 then begin
      if ( ( TransmiteComando1(DataBlock) ) and ( length(sRespuesta)=13 ) ) then begin
        sRespuesta:=DesempacaWayne(sRespuesta);
        StrBin:=ByteToBin(ord(sRespuesta[5]));
        for i:=0 to 7 do
          tbit[i]:=(strbin[8-i]='1');
        if tbit[7] then begin
          iStatus:=2;     // despachando
          TPosCarga[xPosCarga].SwPreset:=false;
          TPosCarga[xPosCarga].SwPreset2:=false;
          if (tbit[0])and(tbit[1])and(tbit[2]) then begin
            if (tposcarga[xposcarga].importe>0.001) then begin
              iStatus:=3;        // fin venta
            end
            else begin
              istatus:=9;        // autorizado
            end;
          end
          else begin
            xposact:=0;
            if tbit[0] then
              xposact:=1;
            if tbit[1] then
              inc(xposact,2);
            if tbit[2] then
              inc(xposact,4);
            inc(xposact,1);
            i:=DamePosOrdinal(xPosCarga,xposact);
            if i in [1..4] then
              TPosCarga[xPosCarga].PosActual:=i;
          end;
          if tbit[4] then
            iStatus:=8;  // detenida
        end
        else if tbit[3] then begin
          iStatus:=9;     // autorizado
        end
        else if tbit[4] then begin
          iStatus:=8;     // detenida y ya en fin de venta
          esperamiliseg(50);
          if ReanudaDespacho(xPosCarga) then begin
            iStatus:=3;
          end;
        end
        else if (not tbit[0])or(not tbit[1])or(not tbit[2]) then begin
          iStatus:=5;     // pistola levantada
          i:=0;
          if tbit[0] then i:=1;
          if tbit[1] then i:=i+2;
          if tbit[2] then i:=i+4;
          TPosCarga[xPosCarga].PosMangLev:=DamePosOrdinal(xPosCarga,i+1);
        end
        else begin
          iStatus:=1;    // inactivo
          if (TPosCarga[xPosCarga].SwStatusFV) then begin
            iStatus:=3;
          end
          else if (TPosCarga[xPosCarga].SwPreset2) then
            iStatus:=9;
        end;
      end;
    end
    else begin
      if ( ( TransmiteComando2(DataBlock) ) and ( length(sRespuesta2)=13 ) ) then begin
        sRespuesta2:=DesempacaWayne(sRespuesta2);
        StrBin:=ByteToBin(ord(sRespuesta2[5]));
        for i:=0 to 7 do
          tbit[i]:=(strbin[8-i]='1');
        if tbit[7] then begin
          iStatus:=2;     // despachando
          TPosCarga[xPosCarga].SwPreset:=false;
          TPosCarga[xPosCarga].SwPreset2:=false;
          if (tbit[0])and(tbit[1])and(tbit[2]) then begin
            if (tposcarga[xposcarga].importe>0.001) then begin
              iStatus:=3;        // fin venta
            end
            else begin
              istatus:=9;        // autorizado
            end;
          end
          else begin
            xposact:=0;
            if tbit[0] then
              xposact:=1;
            if tbit[1] then
              inc(xposact,2);
            if tbit[2] then
              inc(xposact,4);
            inc(xposact,1);
            i:=DamePosOrdinal(xPosCarga,xposact);
            if i in [1..4] then
              TPosCarga[xPosCarga].PosActual:=i;
          end;
          if tbit[4] then
            iStatus:=8;  // detenida
        end
        else if tbit[3] then begin
          iStatus:=9;     // autorizado
        end
        else if tbit[4] then begin
          iStatus:=8;     // detenida y ya en fin de venta
          esperamiliseg(50);
          if ReanudaDespacho(xPosCarga) then begin
            iStatus:=3;
          end;
        end
        else if (not tbit[0])or(not tbit[1])or(not tbit[2]) then begin
          iStatus:=5;     // pistola levantada
          i:=0;
          if tbit[0] then i:=1;
          if tbit[1] then i:=i+2;
          if tbit[2] then i:=i+4;
          TPosCarga[xPosCarga].PosMangLev:=DamePosOrdinal(xPosCarga,i+1);
        end
        else begin
          iStatus:=1;    // inactivo
          if (TPosCarga[xPosCarga].SwStatusFV) then begin
            iStatus:=3;
          end
          else if (TPosCarga[xPosCarga].SwPreset2) then
            iStatus:=9;
        end;
      end;
    end;
    result:= iStatus;
  except
    on e:Exception do begin
      AgregaLog('Error DameEstatus: '+e.Message);
      GuardarLog(0);
    end;
  end;
end;

function Togcvdispensarios_wayne2w.ReanudaDespacho(
  xPosCarga: integer): boolean;
var DataBlock,
    stComando :string;
begin
  try
    PonPuertoPos(xPosCarga);
    result:=false;
    stComando:= char(ControlByte(xPosCarga,0))+char(9*16+7)+#0+#0+#0;
    DataBlock:=EmpacaWayne(stComando);
    if ( ( TransmiteComando1(DataBlock) ) and ( length(sRespuesta)=13 ) ) then
      result:=true;
  except
    on e:Exception do begin
      AgregaLog('Error ReanudaDespacho: '+e.Message);
      GuardarLog(0);
    end;
  end;
end;

procedure Togcvdispensarios_wayne2w.EstatusDispensarios;
var ss,lin,xestado,xmodo,scmnd:string;
    xpos,xcomb:integer;
begin
  try
    lin:='';xestado:='';xmodo:='';
    for xpos:=1 to MaxPosCarga do with TPosCarga[xpos] do begin
      xmodo:=xmodo+ModoOpera[1];
      if not SwDesHabil then begin
        case estatus of
          0:xestado:=xestado+'0'; // Sin Comunicaci�n
          1:xestado:=xestado+'1'; // Inactivo (Idle)
          2:xestado:=xestado+'2'; // Despachando (In Use)
          3,4:xestado:=xestado+'3';
          5:xestado:=xestado+'5'; // Llamando (Calling) Pistola Levantada
          9:xestado:=xestado+'9'; // Autorizado
          8:xestado:=xestado+'8'; // Detenido (Stoped)
          else
            xestado:=xestado+'0';
        end;
      end
      else xestado:=xestado+'7'; // Deshabilitado
      xcomb:=TComb[PosActual];//CombustibleEnPosicion(xpos,PosActual);
      CombActual:=xcomb;
      MangActual:=TMang[PosActual];
      ActualizaCampoJSON(xpos,'Combustible',CombActual);
      ActualizaCampoJSON(xpos,'Manguera',MangActual);
      ss:=inttoclavenum(xpos,2)+'/'+inttostr(xcomb);
      ss:=ss+'/'+FormatFloat('###0.###',volumen);
      ss:=ss+'/'+FormatFloat('#0.##',precio);
      ss:=ss+'/'+FormatFloat('####0.##',importe);
      lin:=lin+'#'+ss;
      //end;
    end;
    EstatusActual:=xestado;
    if lin='' then
      lin:=xestado+'#'
    else
      lin:=xestado+lin;
    lin:=lin+'&'+xmodo;
    if EstatusActual<>EstatusAnterior then begin
      AgregaLog('Estatus Disp: '+EstatusActual);
      EstatusAnterior:=EstatusActual;
    end;
  except
    on e:Exception do begin
      AgregaLog('Error EstatusDispensarios: '+e.Message);
      GuardarLog(0);
    end;
  end;
end;

function Togcvdispensarios_wayne2w.DetenerDespacho(
  xPosCarga: integer): boolean;
var DataBlock,
    stComando :string;
begin
  try
    PonPuertoPos(xPosCarga);
    result:=false;
    stComando:= char(ControlByte(xPosCarga,0))+char(10*16+7)+#0+#0+#0;
    DataBlock:=EmpacaWayne(stComando);
    if SegmActual=1 then begin
      if ( ( TransmiteComando1(DataBlock) ) and ( length(sRespuesta)=13 ) ) then
        result:=true;
    end
    else begin
      if ( ( TransmiteComando2(DataBlock) ) and ( length(sRespuesta2)=13 ) ) then
        result:=true;
    end;
  except
    on e:Exception do begin
      AgregaLog('Error DetenerDespacho: '+e.Message);
      GuardarLog(0);
    end;
  end;
end;

function Togcvdispensarios_wayne2w.DameLecturas(xPosCarga: integer;
  var rLitros, rPrecio, rPesos: real): boolean;
var DataBlock,ss,ss1,
    stComando :string;
    xposact,xposfis:integer;
    val1,val2:integer;
    rLitrosAnt, rPrecioAnt, rPesosAnt: real;
begin
  try
    PonPuertoPos(xPosCarga);
    result:=false;
    rLitrosAnt:=rLitros;rPrecioAnt:=rPrecio;rPesosAnt:=rPesos;
    xposact:=TPosCarga[xposcarga].PosActual;
    if xposact in [1..4] then
      xposfis:=TPosCarga[xposcarga].TPosx[xposact];
    // leo importe
    stComando:= char(ControlByte(xPosCarga,7))+#42+#0+#0+#0;
    DataBlock:=EmpacaWayne(stComando);
    if SegmActual=1 then begin
      if ( ( TransmiteComando1(DataBlock) ) and ( length(sRespuesta)=13 ) ) then begin
        ss:=StrToHexSep(DesempacaWayne(sRespuesta));
        rPesos:=dividefloat(ExtraeBCD(ss,3,5),TPoscarga[xPosCarga].DivImporte);
        if xposfis in [1..7] then begin
          // leo precio
          stComando:= char(ControlByte(xPosCarga,7))+#0+char(xposfis-1)+#0+#0;         //   0F 00 00 F2 03
          DataBlock:=EmpacaWayne(stComando);
          if ( ( TransmiteComando1(DataBlock) ) and ( length(sRespuesta)=13 ) ) then begin
            ss:=StrToHexSep(DesempacaWayne(sRespuesta));
            ss1:=ExtraeElemStrSep(ss,5,' ');
            Val1:=HexToInt(ss1);
            ss1:=ExtraeElemStrSep(ss,4,' ');
            Val2:=HexToInt(ss1);
            rprecio:=256*val1+val2;
            rprecio:=dividefloat(rprecio,100);
            if TPoscarga[xPosCarga].DivLitros=1000 then
              rLitros:=ajustafloat(dividefloat(rPesos,rPrecio),3)
            else
              rLitros:=ajustafloat(dividefloat(rPesos,rPrecio),2);
            result:=true;
          end
          else begin
            AgregaLog('Se evitaron ceros');
            rLitros:=rLitrosAnt;
            rPrecio:=rPrecioAnt;
            rPesos:=rPesosAnt;
          end;
        end
        else begin
          // leo volumen
          stComando:= char(ControlByte(xPosCarga,7))+#38+#0+#0+#0;         // 0F 26 00 00 00
          DataBlock:=EmpacaWayne(stComando);
          if ( ( TransmiteComando1(DataBlock) ) and ( length(sRespuesta)=13 ) ) then begin
            ss:=StrToHexSep(DesempacaWayne(sRespuesta));
            rlitros:=dividefloat(ExtraeBCD(ss,3,5),TPoscarga[xPosCarga].DivLitros);
            rPrecio:=ajustafloat(dividefloat(rPesos,rLitros),2);
            result:=true;
          end
          else begin
            AgregaLog('Se evitaron ceros');
            rLitros:=rLitrosAnt;
            rPrecio:=rPrecioAnt;
            rPesos:=rPesosAnt;
          end;
        end;
      end;
    end
    else begin
      if ( ( TransmiteComando2(DataBlock) ) and ( length(sRespuesta2)=13 ) ) then begin
        ss:=StrToHexSep(DesempacaWayne(sRespuesta2));
        rPesos:=dividefloat(ExtraeBCD(ss,3,5),TPoscarga[xPosCarga].DivImporte);
        if xposfis in [1..7] then begin
          // leo precio
          stComando:= char(ControlByte(xPosCarga,7))+#0+char(xposfis-1)+#0+#0;         //   0F 00 00 F2 03
          DataBlock:=EmpacaWayne(stComando);
          if ( ( TransmiteComando2(DataBlock) ) and ( length(sRespuesta2)=13 ) ) then begin
            ss:=StrToHexSep(DesempacaWayne(sRespuesta2));
            ss1:=ExtraeElemStrSep(ss,5,' ');
            Val1:=HexToInt(ss1);
            ss1:=ExtraeElemStrSep(ss,4,' ');
            Val2:=HexToInt(ss1);
            rprecio:=256*val1+val2;
            rprecio:=dividefloat(rprecio,100);
            if TPoscarga[xPosCarga].DivLitros=1000 then
              rLitros:=ajustafloat(dividefloat(rPesos,rPrecio),3)
            else
              rLitros:=ajustafloat(dividefloat(rPesos,rPrecio),2);
            result:=true;
          end
          else begin
            AgregaLog('Se evitaron ceros');
            rLitros:=rLitrosAnt;
            rPrecio:=rPrecioAnt;
            rPesos:=rPesosAnt;
          end;
        end
        else begin
          // leo volumen
          stComando:= char(ControlByte(xPosCarga,7))+#38+#0+#0+#0;         // 0F 26 00 00 00
          DataBlock:=EmpacaWayne(stComando);
          if ( ( TransmiteComando2(DataBlock) ) and ( length(sRespuesta2)=13 ) ) then begin
            ss:=StrToHexSep(DesempacaWayne(sRespuesta2));
            rlitros:=dividefloat(ExtraeBCD(ss,3,5),TPoscarga[xPosCarga].DivLitros);
            rPrecio:=ajustafloat(dividefloat(rPesos,rLitros),2);
            result:=true;
          end
          else begin
            AgregaLog('Se evitaron ceros');
            rLitros:=rLitrosAnt;
            rPrecio:=rPrecioAnt;
            rPesos:=rPesosAnt;
          end;
        end;
      end;
    end;
  except
    on e:Exception do begin
      AgregaLog('Error DameLecturas: '+e.Message);
      GuardarLog(0);
      rLitros:=0;rPesos:=0;rPrecio:=0;xposfis:=0;
    end;
  end;
end;

function Togcvdispensarios_wayne2w.DameTotal(xPosCarga, xPos: integer;
  var rTotalLitros: real): boolean;
var DataBlock,ss,
    stComando :string;
    val1,val2,val3:real;
    chmang:char;
    xposfis:integer;
begin
  try
    PonPuertoPos(xPosCarga);
    result:=false;
    rTotalLitros:=0;
    if xpos in [1..4] then begin
      xposfis:=TPosCarga[xposcarga].TPosx[xpos];
      chmang:=char(47+xposfis);
      // leo parte 1
      stComando:= char(ControlByte(xPosCarga,7))+#4+chmang+#0+#0;
      DataBlock:=EmpacaWayne(stComando);
      if SegmActual=1 then begin
        if ( ( TransmiteComando1(DataBlock) ) and ( length(sRespuesta)=13 ) ) then begin
          ss:=StrToHexSep(DesempacaWayne(sRespuesta));
          val1:=ExtraeBCD(ss,4,5);
          // leo parte2
          stComando:= char(ControlByte(xPosCarga,7))+#2+chmang+#0+#0;
          DataBlock:=EmpacaWayne(stComando);
          if ( ( TransmiteComando1(DataBlock) ) and ( length(sRespuesta)=13 ) ) then begin
            ss:=StrToHexSep(DesempacaWayne(sRespuesta));
            val2:=ExtraeBCD(ss,4,5);
            // leo parte2
            stComando:= char(ControlByte(xPosCarga,7))+#22+chmang+#0+#0;
            DataBlock:=EmpacaWayne(stComando);
            if ( ( TransmiteComando1(DataBlock) ) and ( length(sRespuesta)=13 ) ) then begin
              ss:=StrToHexSep(DesempacaWayne(sRespuesta));
              val3:=ExtraeBCD(ss,4,5);
              rTotalLitros:=(val1+val2*10000+val3*10000*10000)/100;
              result:=true;
            end;
          end;
        end;
      end
      else begin
        if ( ( TransmiteComando2(DataBlock) ) and ( length(sRespuesta2)=13 ) ) then begin
          ss:=StrToHexSep(DesempacaWayne(sRespuesta2));
          val1:=ExtraeBCD(ss,4,5);
          // leo parte2
          stComando:= char(ControlByte(xPosCarga,7))+#2+chmang+#0+#0;
          DataBlock:=EmpacaWayne(stComando);
          if ( ( TransmiteComando2(DataBlock) ) and ( length(sRespuesta2)=13 ) ) then begin
            ss:=StrToHexSep(DesempacaWayne(sRespuesta2));
            val2:=ExtraeBCD(ss,4,5);
            // leo parte2
            stComando:= char(ControlByte(xPosCarga,7))+#22+chmang+#0+#0;
            DataBlock:=EmpacaWayne(stComando);
            if ( ( TransmiteComando2(DataBlock) ) and ( length(sRespuesta2)=13 ) ) then begin
              ss:=StrToHexSep(DesempacaWayne(sRespuesta2));
              val3:=ExtraeBCD(ss,4,5);
              rTotalLitros:=(val1+val2*10000+val3*10000*10000)/100;
              result:=true;
            end;
          end;
        end;
      end;
      if rTotalLitros<=0 then
        rTotalLitros:=0.001
    end;
  except
    on e:Exception do begin
      AgregaLog('Error DameTotal: '+e.Message);
      GuardarLog(0);
    end;
  end;
end;

function Togcvdispensarios_wayne2w.Autoriza(xPosCarga: integer): boolean;
var DataBlock,
    stComando :string;
begin
  try
    PonPuertoPos(xPosCarga);
    result:=false;
    stComando:= char(ControlByte(xPosCarga,0))+char(8*16+15)+char(0)+#0+#0;         // 08 8F 00 00 00
    DataBlock:=EmpacaWayne(stComando);
    if ( ( TransmiteComando1(DataBlock) ) and ( length(sRespuesta)=13 ) ) then
      result:=true;
  except
    on e:Exception do begin
      AgregaLog('Error Autoriza: '+e.Message);
      GuardarLog(0);
    end;
  end;
end;

function Togcvdispensarios_wayne2w.AutorizaPm(xPosCarga,
  xPm: integer): boolean;
var DataBlock,
    stComando :string;
    xposfis:integer;
begin
  try
    PonPuertoPos(xPosCarga);
    result:=false;
    if xpm in [0..4] then begin
      if xpm=0 then
        xposfis:=15
      else
        xposfis:=TPosCarga[xposcarga].TPosx[xpm];
      stComando:= char(ControlByte(xPosCarga,0))+char(128+8+xposfis-1)+char(0)+#0+#0;         // 08 8F 00 00 00
      DataBlock:=EmpacaWayne(stComando);
      if ( ( TransmiteComando1(DataBlock) ) and ( length(sRespuesta)=13 ) ) then
        result:=true;
    end;
  except
    on e:Exception do begin
      AgregaLog('Error Autoriza: '+e.Message);
      GuardarLog(0);
    end;
  end;
end;

function Togcvdispensarios_wayne2w.EnviaPresetPesosBomba(xPosCarga,
  xTipoPreset: integer; xValor: real): boolean;
var DataBlock,
    stComando :string;
begin
  try
    PonPuertoPos(xPosCarga);
    result:=false;
    if xTipoPreset=1 then begin  // Pesos
      stComando:= char(ControlByte(xPosCarga,7))+#33+ConvierteBCD(xValor*WtwDivImporte,6);
      DataBlock:=EmpacaWayne(stComando);
      if SegmActual=1 then begin
        if ( ( TransmiteComando1(DataBlock) ) and ( length(sRespuesta)=13 ) ) then
          result:=true;
      end
      else begin
        if ( ( TransmiteComando2(DataBlock) ) and ( length(sRespuesta2)=13 ) ) then
          result:=true;
      end;
    end
    else if xTipoPreset=2 then begin  // Litros
      stComando:= char(ControlByte(xPosCarga,7))+#35+ConvierteBCD(xValor*WtwDivLitros,6);
      DataBlock:=EmpacaWayne(stComando);
      if SegmActual=1 then begin
        if ( ( TransmiteComando1(DataBlock) ) and ( length(sRespuesta)=13 ) ) then
          result:=true;
      end
      else begin
        if ( ( TransmiteComando2(DataBlock) ) and ( length(srespuesta2)=13 ) ) then
          result:=true;
      end;
    end;
  except
    on e:Exception do begin
      AgregaLog('Error EnviaPresetPesosBomba: '+e.Message);
      GuardarLog(0);
    end;
  end;
end;

procedure Togcvdispensarios_wayne2w.ProcesaComandos;
var ss,rsp,scmnd,precios      :string;
    xcmnd,xpos,xcomb,
    xp,xfolio,i               :integer;
    ximporte,xlitros,nprec  :real;
begin
  try
    CmndNuevo:=False;
    // Checa Comandos
    for xcmnd:=1 to 200 do begin
      if (TabCmnd[xcmnd].SwActivo)and(not TabCmnd[xcmnd].SwResp) then begin
        SwAplicaCmnd:=true;
        scmnd:=TabCmnd[xcmnd].Comando;
        ss:=ExtraeElemStrSep(scmnd,1,' ');
        AgregaLog(scmnd);
        // ORDENA CARGA DE COMBUSTIBLE
        if ss='OCC' then begin
          xpos:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,2,' '),0);
          rsp:='OK';
          if (xpos in [1..MaxPosCarga]) then begin
            if (TPosCarga[xpos].estatus in [1,5]) then begin
              try
                xImporte:=StrToFLoat(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,3,' '));
                rsp:=ValidaCifra(xImporte,4,2);
                if rsp='OK' then
                  if (xImporte<=0) then
                    xImporte:=9999;
                TPosCarga[xpos].MontoPreset:='$ '+FormatoMoneda(xImporte);
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
                    EsperaMiliseg(50);
                    if EnviaPresetPesosBomba(xpos,1,ximporte) then begin
                      TPosCarga[xpos].HoraOcc:=now;
                      TPosCarga[xpos].SwPreset:=true;
                      TPosCarga[xpos].SwPreset2:=true;
                      TPosCarga[xpos].PosPreset:=xp;
                      TPosCarga[xpos].TipoPreset:=1;
                      TPosCarga[xpos].ValorPreset:=ximporte;
                    end
                    else rsp:='No se pudo prefijar';
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
                rsp:=ValidaCifra(xLitros,3,2);
                if rsp='OK' then
                  if (xLitros<0.10) then
                    xLitros:=999;
                TPosCarga[xpos].MontoPreset:=FormatoMoneda(xLitros)+' lts';
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
                    EsperaMiliseg(50);
                    if EnviaPresetPesosBomba(xpos,1,xlitros) then begin
                      TPosCarga[xpos].HoraOcc:=now;
                      TPosCarga[xpos].SwPreset:=true;
                      TPosCarga[xpos].SwPreset2:=true;
                      TPosCarga[xpos].PosPreset:=xp;
                      TPosCarga[xpos].TipoPreset:=2;
                      TPosCarga[xpos].ValorPreset:=xlitros;
                    end
                    else rsp:='No se pudo prefijar';
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
          xpos:=strtointdef(ExtraeElemStrSep(scmnd,2,' '),0);
          if xpos in [1..MaxPosCarga] then begin
            if (TPosCarga[xpos].estatus=2) then begin // despachando
              if DetenerDespacho(xpos) then begin
              end;
            end
            else if (TPosCarga[xpos].estatus=9) then begin // autorizado
              if EnviaPresetPesosBomba(xpos,1,9999.99) then begin
                TPosCarga[xpos].SwPreset:=false;
                TPosCarga[xpos].SwPreset2:=false;
              end;
            end;
          end;
        end
        else if (ss='TOTAL') then begin
          xpos:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,2,' '),0);
          rsp:='OK';
          with TPosCarga[xpos] do begin
            SwAplicaCmnd:=False;
            if TabCmnd[xcmnd].SwNuevo then begin
              SwLeeTotales[PosActual]:=True;
              TabCmnd[xcmnd].SwNuevo:=false;
            end
            else begin
              if not LeeTotalPosCiclo(xpos,MangCiclo) then begin
                rsp:='OK'+FormatFloat('0.000',ToTalLitros[1])+'|'+FormatoMoneda(ToTalLitros[1]*LPrecios[TComb[1]])+'|'+
                                FormatFloat('0.000',ToTalLitros[2])+'|'+FormatoMoneda(ToTalLitros[2]*LPrecios[TComb[2]])+'|'+
                                FormatFloat('0.000',ToTalLitros[3])+'|'+FormatoMoneda(ToTalLitros[3]*LPrecios[TComb[3]]);
                SwAplicaCmnd:=True;
              end;
            end;
          end;
        end
        else if (ss='CPREC') then begin
          precios:=ExtraeElemStrSep(TabCmnd[xcmnd].Comando,2,' ');
          for xpos:=1 to MaxPosCarga do with TPosCarga[xpos] do begin
            for i:=1 to NoElemStrSep(precios,'|') do begin
              nprec:=StrToFloatDef(ExtraeElemStrSep(precios,i,'|'),-1);
              for xp:=1 to NoComb do if (i=TComb[xp]) and (nprec>0) then
                TNuevoPrec[xp]:=nprec;
            end;
            TCambioPrecN1:=true;
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
    on e:Exception do begin
      AgregaLog('Error ProcesaComandos: '+e.Message);
      GuardarLog(0);
    end;
  end;
end;

function Togcvdispensarios_wayne2w.ValidaCifra(xvalor: real; xenteros,
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
      GuardarLog(0);
    end;
  end;
end;

function Togcvdispensarios_wayne2w.PosicionDeCombustible(xpos,
  xcomb: integer): integer;
var i:integer;
begin
  try
    with TPosCarga[xpos] do begin
      result:=0;
      if xcomb>0 then begin
        for i:=1 to NoComb do begin
          if TComb[i]=xcomb then
            result:=i;
        end;
      end;
    end;
  except
    on e:Exception do begin
      AgregaLog('Error PosicionDeCombustible: '+e.Message);
      GuardarLog(0);
    end;
  end;
end;

function Togcvdispensarios_wayne2w.CambiaPrecios(
  xPosCarga: integer): boolean;
var DataBlock,
    stComando   :string;
    xp,xposfis:integer;
    val1,val2:integer;
    xprecio:integer;
begin
  try
    PonPuertoPos(xPosCarga);
    result:=false;
    for xp:=1 to TPosCarga[xPosCarga].nocomb do begin
      xposfis:=TPosCarga[xPosCarga].TPosx[xp];
      xprecio:=Trunc(TPosCarga[xPosCarga].TNuevoPrec[xp]*100+0.01);
      val1:=(xprecio)div(256);
      val2:=(xprecio)mod(256);
      stComando:= char(ControlByte(xPosCarga,7))+#1+char(xposfis-1)+char(val2)+char(val1);
      DataBlock:=EmpacaWayne(stComando);
      if SegmActual=1 then begin
        if ( ( TransmiteComando1(DataBlock) ) and ( length(sRespuesta)=13 ) ) then begin
          Esperamiliseg(50);
          stComando:= char(ControlByte(xPosCarga,7))+#1+char(16+xposfis-1)+char(val2)+char(val1);
          DataBlock:=EmpacaWayne(stComando);
          if ( ( TransmiteComando1(DataBlock) ) and ( length(sRespuesta)=13 ) ) then begin
            Esperamiliseg(50);
            if xp=TPosCarga[xPosCarga].nocomb then
              result:=true;
          end
          else exit;
        end
        else exit;
      end
      else begin
        if ( ( TransmiteComando2(DataBlock) ) and ( length(sRespuesta2)=13 ) ) then begin
          Esperamiliseg(50);
          stComando:= char(ControlByte(xPosCarga,7))+#1+char(16+xposfis-1)+char(val2)+char(val1);
          DataBlock:=EmpacaWayne(stComando);
          if ( ( TransmiteComando2(DataBlock) ) and ( length(sRespuesta2)=13 ) ) then begin
            Esperamiliseg(50);
            if xp=TPosCarga[xPosCarga].nocomb then
              result:=true;
          end
          else exit;
        end
        else exit;
      end;
    end;
  except
    on e:Exception do begin
      AgregaLog('Error CambiaPrecios: '+e.Message);
      GuardarLog(0);
    end;
  end;
end;

procedure Togcvdispensarios_wayne2w.Timer1Timer(Sender: TObject);
label L01;
var xvolumen,n1,n2,n3:real;
    xcomb,xpos,xp,xgrade,i,j:integer;
    xtotallitros:real;
begin
  try
    try
      Inc(xTurnoSocket);
      if xTurnoSocket>3 then
        xTurnoSocket:=1;

      if (minutosLog>0) and (MinutesBetween(Now,horaLog)>=minutosLog) then begin
        horaLog:=Now;
        GuardarLog(0);
      end;
      if CmndNuevo then
        ProcesaComandos;
      if ContadorAlarma>=10 then begin
        if ContadorAlarma=10 then
          AgregaLog('Desconexion de Dispositivo - Error Comunicacion Dispensarios');
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
        AgregaLog('PosCiclo: '+IntToStr(PosCiclo)+' - '+'NumPaso: '+IntToStr(NumPaso));
        if PosCiclo in [1..MaxPosCarga] then with TPosCarga[PosCiclo] do begin
          StrCiclo:=StrCiclo+inttostr(PosCiclo);
          while length(StrCiclo)>20 do
            delete(StrCiclo,1,1);
          try
            case NumPaso of
              0:if SwLeePrecios then begin
                  if LeePrecios(PosCiclo) then
                    SwLeePrecios:=false;
                end;
              1:if (stciclo=xciclo)or(Estatus>1) then begin                           // ESTATUS
                  try
                    if (not swdeshabil) and ((not SinComunicacion) or (SecondsBetween(Now, HoraDesconexion) >= RandomRange(55, 65))) then begin   // no polea los que estan deshabilitados
                      EstatusAnt:=Estatus;
                      Estatus:=DameEstatus(PosCiclo);    // Aqui bota cuando no hay posicion activa
                      ContadorAlarma:=0;
                      if estatus=2 then
                        swdesp:=true;
                      if (swdesp)and(estatus in [1,3,5]) then begin
                        AgregaLog('Detecto Fin Venta: '+inttostr(PosCiclo));
                        swdesp:=false;
                        SwStatusFV:=true;
                        Estatus:=3;
                      end;
                      if (Estatusant=0)and(estatus=1) then begin
                        Swleeventa:=true;
                        for j:=1 to TPosCarga[PosCiclo].NoComb do
                          SwLeeTotales[j]:=true;
                        SinComunicacion := False;
                      end;
                      if (EstatusAnt in [3,4])and(Estatus=1) then begin
                        swcargando:=false;
                        if (EsperaFinVenta=1) and (volumen>0) then
                          Estatus:=4
                        else
                          EsperaFinVenta:=0;
                      end;
                      if (estatusant = 0) and (estatus = 0) then
                      begin
                        SinComunicacion := True;
                        HoraDesconexion := Now;
                      end;
                      EstatusDispensarios;
                      if (((Estatusant=2) or (Estatusant=3)) and (Estatus=9)) then begin // Desautoriza
                        AgregaLog('Desautorizo posicion: '+inttostr(PosCiclo));
                        Esperamiliseg(300);
                        DetenerDespacho(PosCiclo);
                        Esperamiliseg(300);
                        ReanudaDespacho(PosCiclo);
                      end;
                      ActualizaCampoJSON(PosCiclo,'Estatus',estatus);
                    end;
                  except
                    AgregaLog('Error Estatus Pos: '+inttostr(PosCiclo));
                    AvanzaPosCiclo;
                    NumPaso:=1;
                    exit;
                  end;
                end;
              2:if (swleeventa)and(estatus>0) then begin       // LEE VENTA TERMINADA
                  if not swdeshabil then begin   // no polea los que estan deshabilitados
                    AgregaLog('E> FIN DE VENTA: '+inttoclavenum(PosCiclo,2));
                    if DameLecturas(PosCiclo,Volumen,Precio,Importe) then begin
                      swleeventa:=false;
                      SwStatusFV:=false;
                      HoraOcc:=Now;
                      xvolumen:=ajustafloat(dividefloat(importe,precio),3);
                      if abs(volumen-xvolumen)>0.5 then
                        volumen:=xvolumen;
                      AgregaLog('R> '+FormatFloat('###,##0.00',Volumen)+' / '+FormatFloat('###,##0.00',precio)+' / '+FormatFloat('###,##0.00',importe));
                    end;
                    ActualizaCampoJSON(PosCiclo,'HoraOcc',FormatDateTime('yyyy-mm-dd',HoraOcc)+'T'+FormatDateTime('hh:nn',HoraOcc));
                    ActualizaCampoJSON(PosCiclo,'Volumen',Volumen);
                    ActualizaCampoJSON(PosCiclo,'Precio',precio);
                    ActualizaCampoJSON(PosCiclo,'Importe',importe);
                  end;
                end;
              3:if (estatus>0)and(not swdeshabil) then begin        // LEE TOTALES
                  if LeeTotalPosCiclo(PosCiclo,MangCiclo) then begin
                    AgregaLog('E> Lee Totales: '+inttoclavenum(PosCiclo,2)+' MangCiclo:'+IntToStr(MangCiclo)+' NoComb:'+IntToStr(TPosCarga[PosCiclo].NoComb));
                    if DameTotal(PosCiclo,MangCiclo,xTotalLitros)then
                    begin
                      TotalLitros[MangCiclo]:=xTotalLitros;
                      ApplyTotalLitrosToJSON(PosCiclo,TotalLitros);
                      AgregaLog('R> '+FormatFloat('###,###,##0.00',xTotalLitros));
                      SwLeeTotales[MangCiclo]:=false;
                    end;
                  end;
                end;
              4:if (estatus=5)and(not swdeshabil)  then begin
                  if (ModoOpera='Normal') then begin // AUTORIZA VENTA tanque lleno
                    AgregaLog('E> Autoriza: '+inttoclavenum(PosCiclo,2));
                    if not swpreset then begin
                      if Autoriza(PosCiclo) then ;
                    end
                    else if (swpreset)and(PosPreset=PosMangLev) then begin
                      if EnviaPresetPesosBomba(PosCiclo,TipoPreset,ValorPreset) then
                        if AutorizaPm(PosCiclo,PosPreset) then begin
                          swpreset2:=true;
                        end;
                    end
                    else if (swpreset)and(PosPreset=0) then begin
                      if EnviaPresetPesosBomba(PosCiclo,TipoPreset,ValorPreset) then
                        if Autoriza(PosCiclo) then begin
                          swpreset2:=true;
                        end;
                    end;
                  end
                  else begin // AUTORIZA PREPAGO
                    AgregaLog('E> Autoriza Prepago: '+inttoclavenum(PosCiclo,2));
                    if (SwPreset)and(PosPreset=PosMangLev) then begin
                      if EnviaPresetPesosBomba(PosCiclo,TipoPreset,ValorPreset) then
                        if AutorizaPm(PosCiclo,PosPreset) then begin
                          swpreset2:=true;
                        end;
                    end
                    else if (swpreset)and(PosPreset=0) then begin
                      if EnviaPresetPesosBomba(PosCiclo,TipoPreset,ValorPreset) then
                        if Autoriza(PosCiclo) then begin
                          swpreset2:=true;
                        end;
                    end;
                  end
                end;
              5:if estatus in [2,8] then begin                 // LEE VENTA PROCESO
                  if not swdeshabil then begin   // no polea los que estan deshabilitados
                    AgregaLog('E> Lee Venta Proc: '+inttoclavenum(PosCiclo,2));
                    if DameLecturas(PosCiclo,Volumen,Precio,Importe) then begin
                    end;
                    ActualizaCampoJSON(PosCiclo,'Volumen',volumen);
                    ActualizaCampoJSON(PosCiclo,'Importe',importe);
                    ActualizaCampoJSON(PosCiclo,'Precio',precio);
                  end;
                end;
              6:ProcesaComandos;
              7:begin          // CAMBIA PRECIO
                  if not swdeshabil then begin   // no polea los que estan deshabilitados
                    if (TCambioPrecN1) and (estatus=1) then begin
                      AgregaLog('E> Cambia Precio: '+inttoclavenum(PosCiclo,2));
                      if CambiaPrecios(PosCiclo) then
                        TCambioPrecN1:=false;
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
              else if (not LeeTotalPosCiclo(PosCiclo,MangCiclo)) then
                NumPaso:=4;
            end;
            if (NumPaso=4) and (not estatus in [5,9]) then
              NumPaso:=5;
            if (NumPaso=5) and (estatus<>2) and (estatus<>8) then  // no esta ni estaba despachando
              NumPaso:=6;
            if (NumPaso=6) and (PosCiclo<MaxPosCarga) then
              NumPaso:=7;
            if (NumPaso=7) then begin
              swprec:=TPosCarga[PosCiclo].TCambioPrecN1;
              if not swprec then
                NumPaso:=8;
            end;


            if NumPaso>=8 then begin
              AvanzaPosCiclo;
              if TPosCarga[PosCiclo].SwLeePrecios then
                NumPaso:=0
              else
                NumPaso:=1;
            end;
          end;
        end
        else posciclo:=1;
      end;
    except
      on e:Exception do begin
        AgregaLog('Error Timer1: '+e.Message);
        GuardarLog(0);
        inc(NumPaso);
        AvanzaPosCiclo;
      end;
    end;
  finally
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

procedure Togcvdispensarios_wayne2w.AvanzaPosCiclo;
begin
  try
    repeat
      inc(PosCiclo);
      if PosCiclo>MaxPosCarga then begin
        EstatusDispensarios;
        PosCiclo:=1;
        inc(StCiclo);
        if StCiclo>2 then
          StCiclo:=0;
      end;
      PonPuertoPos(PosCiclo);
    until (stciclo=TPosCarga[PosCiclo].xCiclo)or(TPosCarga[PosCiclo].Estatus>1);
  except
    on e:Exception do begin
      AgregaLog('Error AvanzaPosCiclo: '+e.Message);
      GuardarLog(0);
    end;
  end;
end;

procedure Togcvdispensarios_wayne2w.pSerial2TriggerAvail(CP: TObject;
  Count: Word);
var i : integer;  
begin
   for i:=1 to Count do begin
     sRespuesta2:= sRespuesta2 + pSerial2.GetChar;
   end;
   i:= length(sRespuesta2);
   if ( ( i>=iBytesEsperados ) ) then
      bListo2:= true
   else
      newtimer(etTimeOut2,MSecs2Ticks(GtwTimeout));
end;

procedure Togcvdispensarios_wayne2w.pSerial2TriggerData(CP: TObject;
  TriggerHandle: Word);
begin
  try
    if ( TriggerHandle=wTriggerEOT ) then
       bEndOfText:= true
    else
       bLineFeed:= true;
  except
    on e:Exception do begin
      AgregaLog('Error pSerialTriggerData: '+e.Message);
      GuardarLog(0);
    end;
  end;
end;

function Togcvdispensarios_wayne2w.TransmiteComando2(
  DataBlock: string): boolean;
var ss:string;
    iMaxIntentos,i,
    iNoIntento    :integer;
    bOk           :boolean;
begin
  try
    Timer1.Enabled:=False;
    try
      iMaxIntentos:=2;
      iBytesEsperados:=13;
      iNoIntento:= 0;
      bOk:=false;
      repeat
         inc(iNoIntento);
         bListo2:= false;
         bEndOfText:= false;
         bLineFeed:= false;
         sRespuesta2:= '';
         pSerial2.FlushInBuffer;
         pSerial2.FlushOutBuffer;
         ss:=StrToHexSep(DataBlock);
         AgregaLog('E  '+ss);
         for i:= 1 to length ( DataBlock ) do begin
            pSerial2.PutChar(DataBlock[i]);
            repeat
               pSerial2.ProcessCommunications;
            until ( pSerial2.OutBuffUsed=0 );
         end;
         if ( not bOk ) then begin
            newtimer(etTimeOut2,MSecs2Ticks(GtwTimeout));
            repeat
               ServiceThread.ProcessRequests(False);
            until ( ( bListo2 ) or ( timerexpired(etTimeOut2) ) );
            AgregaLog('sRespuesta2 Length: '+IntToStr(length(sRespuesta2)));
            if ( bListo2 ) then begin
              if length(sRespuesta2)=13 then begin
                bOk:=true;
                AgregaLog('R  '+StrToHexSep(sRespuesta2));
              end;
            end;
            if ( not bOk ) then begin
               if  ( iNoIntento<iMaxIntentos ) then sleep(GtwTiempoCmnd);
            end;
         end;
      until ( ( bOk ) or ( iNoIntento>=iMaxIntentos ) );
      result:= bOk;
    except
      on e:Exception do begin
        AgregaLog('Error TransmiteComando1: '+e.Message);
        GuardarLog(0);
      end;
    end;
  finally
    Timer1.Enabled:=True;
  end;
end;

procedure Togcvdispensarios_wayne2w.PonPuertoPos(xpos: integer);
begin
  if MaxPosCarga>=WtwPosIniExt then begin
    if (xpos>=WtwPosIniExt) then begin // Parte Extendida
      SegmActual:=2;
    end
    else begin
      SegmActual:=1;
    end;
  end;
end;

function Togcvdispensarios_wayne2w.IniciaPSerial2(
  datosPuerto: string): string;
var
  puerto:string;
begin
  try
    if pSerial2.Open then begin
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
        pSerial2.ComNumber:=StrToInt(Copy(puerto,4,Length(puerto)-3));
    end
    else begin
      if StrToIntDef(ExtraeElemStrSep(datosPuerto,2,','),-99)=-99 then begin
        Result:='False|Favor de indicar un numero de puerto correcto|';
        Exit;
      end
      else
        pSerial2.ComNumber:=StrToInt(ExtraeElemStrSep(datosPuerto,2,','));
    end;

    if StrToIntDef(ExtraeElemStrSep(datosPuerto,3,','),-99)=-99 then begin
      Result:='False|Favor de indicar los baudios correctos|';
      Exit;
    end
    else
      pSerial2.Baud:=StrToInt(ExtraeElemStrSep(datosPuerto,3,','));

    if ExtraeElemStrSep(datosPuerto,4,',')<>'' then begin
      case ExtraeElemStrSep(datosPuerto,4,',')[1] of
        'N':pSerial2.Parity:=pNone;
        'E':pSerial2.Parity:=pEven;
        'O':pSerial2.Parity:=pOdd;
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
      pSerial2.DataBits:=StrToInt(ExtraeElemStrSep(datosPuerto,5,','));

    if StrToIntDef(ExtraeElemStrSep(datosPuerto,6,','),-99)=-99 then begin
      Result:='False|Favor de indicar los bits de paro correctos|';
      Exit;
    end
    else
      pSerial2.StopBits:=StrToInt(ExtraeElemStrSep(datosPuerto,6,','));
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

procedure Togcvdispensarios_wayne2w.ServiceStop(Sender: TService;
  var Stopped: Boolean);
begin
  GuardarLog(0);
end;

procedure Togcvdispensarios_wayne2w.ServiceShutdown(Sender: TService);
begin
  GuardarLog(0);
end;

procedure Togcvdispensarios_wayne2w.ServiceDestroy(Sender: TObject);
begin
  GuardarLog(0);
end;

procedure Togcvdispensarios_wayne2w.ActivaModoPrepago(folio: Integer;
  msj: string);
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

procedure Togcvdispensarios_wayne2w.ActualizaCampoJSON(xpos: Integer;
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
      end
      else if (posObj.Field['DispenserId'] = nil) and (i + 1 = xpos) then
      begin
      end
      else
        Continue;

      field := posObj.Field[campo];

      if field <> nil then
        field.Value := valor;

      Exit;
    end;

    AgregaLog('DispenserId no encontrado en PosCarga.');
  except
    on e:Exception do begin
      AgregaLog('Error ActualizaCampoJSON: '+e.Message+'|');
      GuardarLog(0);
    end;
  end;
end;

procedure Togcvdispensarios_wayne2w.AddPeticionJSON(const aFolio: Integer;
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

procedure Togcvdispensarios_wayne2w.ApplyTotalLitrosToJSON(
  const xpos: Integer; const TotalLitros: array of Real);
var
  posCargaList : TlkJSONlist;
  hosesList    : TlkJSONlist;
  posObj       : TlkJSONobject;
  hoseObj      : TlkJSONobject;
  totalNode    : TlkJSONbase;
  hoseIdx      : Integer;
  posIndex0    : Integer;
begin
  posCargaList := rootJSON.Field['PosCarga'] as TlkJSONlist;
  if posCargaList = nil then
    Exit;

  posIndex0 := xpos - 1;
  if (posIndex0 < 0) or (posIndex0 >= posCargaList.Count) then
    Exit;

  posObj   := TlkJSONobject(posCargaList.Child[posIndex0]);
  hosesList := posObj.Field['Hoses'] as TlkJSONlist;
  if hosesList = nil then
    Exit;

  for hoseIdx := 0 to hosesList.Count - 1 do
  begin
    if hoseIdx > High(TotalLitros) then
      Break;

    hoseObj := TlkJSONobject(hosesList.Child[hoseIdx]);

    totalNode := hoseObj.Field['Total'];
    if totalNode <> nil then
      totalNode.Value := TotalLitros[hoseIdx];
  end;
end;

procedure Togcvdispensarios_wayne2w.AutorizarVenta(folio: Integer;
  msj: string);
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
      AddPeticionJSON(folio,'False|Favor de indicar la cantidad que se va a despachar|');
      Exit;
    end;

    posCarga:=ExtraeElemStrSep(msj,1,'|');

    if posCarga='' then begin
      AddPeticionJSON(folio,'False|Favor de indicar la posicion de carga|');
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

    AddPeticionJSON(folio,'True|'+IntToStr(EjecutaComando(cmd+' '+posCarga+' '+cantidad+' '+comb+' '+finv))+'|');
  except
    on e:Exception do
      AddPeticionJSON(folio, 'False|Excepcion: '+e.Message+'|');
  end;
end;

procedure Togcvdispensarios_wayne2w.Bloquear(folio: Integer; msj: string);
var
  xpos:Integer;
begin
  try
    xpos:=StrToIntDef(msj,-1);

    if xpos<0 then begin
      AddPeticionJSON(folio, 'False|Favor de indicar correctamente la posicion de carga|');
      Exit;
    end;

    if (xpos<=MaxPosCarga) then begin
      if xpos=0 then begin
        for xpos:=1 to MaxPosCarga do
          TPosCarga[xpos].SwDesHabil:=True;
        AddPeticionJSON(folio, 'True|');
      end
      else if (xpos in [1..maxposcarga]) then begin
        TPosCarga[xpos].SwDesHabil:=True;
        AddPeticionJSON(folio, 'True|');
      end;
    end
    else AddPeticionJSON(folio, 'False|Posicion no Existe|');
  except
    on e:Exception do
      AddPeticionJSON(folio, 'False|Excepcion: '+e.Message+'|');
  end;
end;

procedure Togcvdispensarios_wayne2w.DesactivaModoPrepago(folio: Integer;
  msj: string);
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

procedure Togcvdispensarios_wayne2w.Desbloquear(folio: Integer;
  msj: string);
var
  xpos:Integer;
begin
  try
    xpos:=StrToIntDef(msj,-1);

    if xpos<0 then begin
      AddPeticionJSON(folio, 'False|Favor de indicar correctamente la posicion de carga|');
      Exit;
    end;

    if (xpos<=MaxPosCarga) then begin
      if xpos=0 then begin
        for xpos:=1 to MaxPosCarga do
          TPosCarga[xpos].SwDesHabil:=False;
        AddPeticionJSON(folio, 'True|');
      end
      else if (xpos in [1..maxposcarga]) then begin
        TPosCarga[xpos].SwDesHabil:=False;
        AddPeticionJSON(folio, 'True|');
      end;
    end
    else AddPeticionJSON(folio, 'False|Posicion no Existe|');
  except
    on e:Exception do
      AddPeticionJSON(folio, 'False|Excepcion: '+e.Message+'|');
  end;
end;

procedure Togcvdispensarios_wayne2w.Detener(folio: Integer);
begin
  try
    if estado=-1 then begin
      AddPeticionJSON(folio, 'False|El proceso no se ha iniciado aun|');
      Exit;
    end;

    if not detenido then begin
      pSerial.Open:=False;
      pSerial.Tracing:= tlOff;
      pSerial.Open:= false;
      pSerial.DTR:= false;
      pSerial.RTS:= false;
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
    on e:Exception do
      AddPeticionJSON(folio, 'False|'+e.Message+'|');
  end;
end;

procedure Togcvdispensarios_wayne2w.DetenerVenta(folio: Integer;
  msj: string);
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

procedure Togcvdispensarios_wayne2w.FinVenta(folio: Integer; msj: string);
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

procedure Togcvdispensarios_wayne2w.GuardarLog(folio: Integer);
begin
  try
    horaLog:=Now;
    AgregaLog('Version: '+version);
    AgregaLog('Fecha y hora de arranque: '+FechaHoraExtToStr(HoraArranque));
    ListaLog.SaveToFile(rutaLog+'\LogDisp'+FiltraStrNum(FechaHoraToStr(Now))+'.txt');
    GuardarLogPetRes(0);
    if folio>0 then
      AddPeticionJSON(folio, 'True|'+rutaLog+'\LogDisp'+FiltraStrNum(FechaHoraToStr(Now))+'.txt|');
  except
    on e:Exception do if folio>0 then
      AddPeticionJSON(folio, 'False|Excepcion: '+e.Message+'|');
  end;
end;

procedure Togcvdispensarios_wayne2w.GuardarLogPetRes(folio: Integer);
begin
  try
    AgregaLogPetRes('Version: '+version);
    AgregaLogPetRes('Fecha y hora de arranque: '+FechaHoraExtToStr(HoraArranque));
    ListaLogPetRes.SaveToFile(rutaLog+'\LogDispPetRes'+FiltraStrNum(FechaHoraToStr(Now))+'.txt');
    if folio>0 then
      AddPeticionJSON(folio,'True|');
  except
    on e:Exception do begin
      AgregaLog('False|Excepcion: '+e.Message+'|');
      GuardarLog(0);
      if folio>0 then
        AddPeticionJSON(folio, 'False|Excepcion: '+e.Message+'|');
    end;
  end;
end;

procedure Togcvdispensarios_wayne2w.IniciaPrecios(folio: Integer;
  msj: string);
var
  ss:string;
  precioComb:Double;
  xpos,i:Integer;
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

procedure Togcvdispensarios_wayne2w.Iniciar(folio: Integer);
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

    wTriggerEOT:= pSerial.AddDataTrigger(#$F0,true);
    wTriggerLF:= pSerial.AddDataTrigger(#$8A,true);

    detenido:=False;
    estado:=1;
    numPaso:=0;
    SwPasoBien:=true;
    PosCiclo:=1;
    swespera:=False;
    StCiclo:=0;
    Timer1.Enabled:=True;
    Timer2.Enabled:=False;
    SetEstadoJSON(estado);
    AddPeticionJSON(folio, 'True|');
  except
    on e:Exception do begin
      AgregaLog('Excepcion Iniciar: '+e.Message+'|');
      GuardarLog(0);
      if folio>0 then
        AddPeticionJSON(folio, 'False|Excepcion: '+e.Message+'|');
    end;
  end;
end;

procedure Togcvdispensarios_wayne2w.Login(folio: Integer; mensaje: string);
var
  usuario,password:string;
begin
  usuario:=ExtraeElemStrSep(mensaje,1,'|');
  password:=ExtraeElemStrSep(mensaje,2,'|');
  if MD5(usuario+'|'+FormatDateTime('yyyy-mm-dd',Date)+'T'+FormatDateTime('hh:nn',Now))<>password then
    AddPeticionJSON(folio, 'False|Password invalido|')
  else begin
    Token:=MD5(usuario+'|'+FormatDateTime('yyyy-mm-dd',Date)+'T'+FormatDateTime('hh:nn',Now));
    AddPeticionJSON(folio, 'True|'+Token+'|')
  end;
end;

procedure Togcvdispensarios_wayne2w.Logout(folio: Integer);
begin
  Token:='';
  AddPeticionJSON(folio, 'True|')
end;

procedure Togcvdispensarios_wayne2w.ObtenerLog(folio, r: Integer);
var
  i:Integer;
  log:string;
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

  log:='True|';

  for i:=i to ListaLog.Count-1 do
    log:=log+ListaLog[i]+'|';

  AddPeticionJSON(folio, log);
end;

procedure Togcvdispensarios_wayne2w.ObtenerLogPetRes(folio, r: Integer);
var
  i:Integer;
  log:string;
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

  log:='True|';

  for i:=i to ListaLogPetRes.Count-1 do
    log:=log+ListaLogPetRes[i]+'|';

  AddPeticionJSON(folio, log);
end;

procedure Togcvdispensarios_wayne2w.ReanudarVenta(folio: Integer;
  msj: string);
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

procedure Togcvdispensarios_wayne2w.RespuestaComando(folio: Integer;
  msj: string);
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

procedure Togcvdispensarios_wayne2w.SetEstadoJSON(const AEstado: Integer);
var
  estadoNode: TlkJSONbase;
begin
  estadoNode := rootJSON.Field['Estado'];

  if Assigned(estadoNode) then
    estadoNode.Value := AEstado
  else
    TlkJSONObject(rootJSON).Add('Estado', TlkJSONnumber.Generate(AEstado));
end;

procedure Togcvdispensarios_wayne2w.Shutdown(folio: Integer);
begin
  if estado>0 then
    AddPeticionJSON(folio, 'False|El servicio esta en proceso, no fue posible detenerlo|')
  else begin
    AddPeticionJSON(folio, 'True|');
    ServiceThread.Terminate;
  end;
end;

procedure Togcvdispensarios_wayne2w.Terminar(folio: Integer);
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

procedure Togcvdispensarios_wayne2w.TotalesBomba(folio: Integer;
  msj: string);
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

    AddPeticionJSON(folio, valor+'|0|0|0|0|0|0|'+IntToStr(xfolioCmnd)+'|')
  except
    on e:Exception do
      AddPeticionJSON(folio, 'False|Excepcion: '+e.Message+'|');
  end;
end;

procedure Togcvdispensarios_wayne2w.Timer2Timer(Sender: TObject);
var
  i:Integer;
  json:String;
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

procedure Togcvdispensarios_wayne2w.ClientSocket1Connect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
  conectado:=True;
end;

procedure Togcvdispensarios_wayne2w.ClientSocket1Disconnect(
  Sender: TObject; Socket: TCustomWinSocket);
begin
  conectado:=False;
  Timer1.Enabled:=False;
  Timer2.Enabled:=True;
end;

procedure Togcvdispensarios_wayne2w.ClientSocket1Read(Sender: TObject;
  Socket: TCustomWinSocket);
  var
    mensaje,comando,parametro:string;
    i,folio:Integer;
    metodoEnum:TMetodos;
begin
  try
    mensaje:=Socket.ReceiveText;
    if mensaje<>'' then begin
      AgregaLogPetRes('R '+mensaje);

      folio:=StrToIntDef(ExtraeElemStrSep(mensaje,1,'|'),0);

      comando:=UpperCase(ExtraeElemStrSep(mensaje,3,'|'));

      if NoElemStrSep(mensaje,'|')>3 then begin
        for i:=4 to NoElemStrSep(mensaje,'|') do
          parametro:=parametro+ExtraeElemStrSep(mensaje,i,'|')+'|';

        if parametro[Length(parametro)]='|' then
          Delete(parametro,Length(parametro),1);
      end;

      metodoEnum := TMetodos(GetEnumValue(TypeInfo(TMetodos), comando+'_e'));

      case metodoEnum of

        INITIALIZE_e:
          Inicializar(folio,parametro);

        PARAMETERS_e:
          AddPeticionJSON(folio, 'True|');

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

        LOGIN_e:
          Login(folio,parametro);

        LOGOUT_e:
          Logout(folio);

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
      end;
      socketResponse:=Socket;
    end;
  except
    on e:Exception do begin
      AgregaLogPetRes('Error ClientSocket1Read: '+e.Message);
      GuardarLog(0);
    end;
  end;
end;

end.
