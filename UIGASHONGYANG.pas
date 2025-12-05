unit UIGASHONGYANG;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, SvcMgr, Dialogs,
  ExtCtrls, OoMisc, AdPort, ScktComp, IniFiles, ULIBGRAL, uLkJSON, CRCs,
  Variants, IdHashMessageDigest, IdHash, ActiveX, ComObj, LbCipher, LbString,
  Math, DateUtils, TypInfo;

type
  Togcvdispensarios_hongyang = class(TService)
    pSerial: TApdComPort;
    Timer1: TTimer;
    Timer2: TTimer; // Added for JSON/Keepalive loop
    ClientSocket1: TClientSocket; // Changed from ServerSocket to ClientSocket
    procedure ServiceExecute(Sender: TService);
    procedure pSerialTriggerAvail(CP: TObject; Count: Word);
    procedure Timer1Timer(Sender: TObject);
    procedure Timer2Timer(Sender: TObject); // Added
    procedure ClientSocket1Connect(Sender: TObject; Socket: TCustomWinSocket); // Added
    procedure ClientSocket1Disconnect(Sender: TObject; Socket: TCustomWinSocket); // Added
    procedure ClientSocket1Read(Sender: TObject; Socket: TCustomWinSocket); // Changed to Client Read
  private
    ContadorAlarma:integer;
    SegundosFinv:Integer;
    MaxPosiciones:integer;
    FinLinea:boolean;
    LineaBuff,
    LineaProc:string;
    SwAplicaCmnd:Boolean;
    NumPaso:Integer;
    PosicionesLibres:Boolean;
    // New variables for Client/JSON logic
    conectado, respJson:Boolean;
    rootJSON : TlkJSONbase;
    xTurnoSocket:Integer;
    socketResponse : TCustomWinSocket;
  public
    ListaLog:TStringList;
    ListaLogPetRes:TStringList;
    rutaLog:string;
    licencia:string;
    detenido:Boolean;
    estado:Integer;
    ListaCmnd    :TStrings;
    confPos:string;
    modoPreset:Boolean;
    FolioCmnd   :integer;
    ListaComandos:TStringList;
    fechaInicio:TDateTime;
    horaReinicio:TDateTime;
    horaLog:TDateTime;
    minutosLog:Integer;
    version:String;
    function GetServiceController: TServiceController; override;
    procedure AgregaLogPetRes(lin: string);
    function CRC16(Data: AnsiString): AnsiString;
    procedure Responder(resp:string); // Modified signature
    procedure AgregaLog(lin:string);
    function IniciaPSerial(datosPuerto:string):string;
    procedure Inicializar(folio:Integer; msj:string); // Modified signature
    function AgregaPosCarga(posiciones: TlkJSONbase):string;
    procedure Login(folio:Integer; mensaje:string); // Modified
    procedure Logout(folio:Integer); // Modified
    procedure GuardarLogPetRes(folio:Integer=0); // Modified
    function FechaHoraExtToStr(FechaHora:TDateTime):String;
    function MD5(const usuario: string): string;
    function ConvierteBCD(xvalor:real;xlong:integer):string;
    function CalculaBCC(ss:string):char;
    function StrToHexSep(ss:string):string;
    procedure IniciaPrecios(folio:Integer; msj:string); // Modified
    function ExtraeBCD(xstr:string;xini,xfin:integer):real;
    function ComandoA(xaddr,xlado:integer):string;
    function ComandoC(xaddr,xlado:integer):string;    // Modo prepago
    function ComandoD(xaddr,xlado:integer):string;    // Modo Normal
    function ComandoN(xaddr,xlado:integer):string;
    function ComandoU(xaddr,xlado,xprecio:integer):string;
    function ComandoV(xaddr,xlado:integer):string;
    function ComandoS(xaddr,xlado,ximporte:integer):string;
    function ComandoL(xaddr,xlado,xlitros:integer):string;
    procedure ComandoConsola(ss:string);
    function EjecutaComando(xCmnd:string):integer;
    procedure AutorizarVenta(folio:Integer; msj:string); // Modified
    procedure ActivaModoPrepago(folio:Integer; msj:string); // Modified
    procedure DesactivaModoPrepago(folio:Integer; msj:string); // Modified
    procedure FinVenta(folio:Integer; msj:string); // Modified
    procedure ProcesoComandoA(xResp:string);
    procedure ProcesoComandoC(xResp:string);
    procedure ProcesoComandoD(xResp:string);
    procedure ProcesoComandoN(xResp:string);
    procedure ProcesoComandoU(xResp:string);
    procedure ProcesoComandoV(xResp:string);
    procedure ProcesoComandoS(xResp:string);
    procedure ProcesoComandoL(xResp:string);
    procedure ProcesaLineaRec(LineaRsp:string);
   function DameEstatus(xstr:string;var swlocked,swerror:boolean):integer;
   procedure MeteACola(xstr:string);
   procedure SacaDeCola(var xstr:string);
   function HexToBinario(ss:string):string;
   procedure PublicaEstatusDispensarios;
   procedure ProcesaComandosExternos;
   function ValidaCifra(xvalor:real;xenteros,xdecimales:byte):string;
   procedure TransaccionPosCarga(folio:Integer; msj:string); // Modified
   procedure EstadoPosiciones(folio:Integer; msj: string); // Modified
   procedure Detener(folio:Integer); // Modified
   procedure Iniciar(folio:Integer); // Modified
   procedure Shutdown(folio:Integer); // Modified
   procedure Terminar(folio:Integer); // Modified
   function ObtenerEstado: string;
   procedure GuardarLog(folio:Integer=0); // Modified
   procedure RespuestaComando(folio:Integer; msj:string); // Modified
   procedure ObtenerLog(folio:Integer; r:Integer); // Modified
   procedure ObtenerLogPetRes(folio:Integer; r:Integer); // Modified
   function ResultadoComando(xFolio:integer):string;
   procedure TotalesBomba(folio:Integer; msj: string); // Modified
   procedure IniciarPrecios;
   procedure Bloquear(folio:Integer; msj:string); // Modified
   procedure Desbloquear(folio:Integer; msj:string); // Modified
   procedure GuardaLogComandos;
   function Encrypt(data,key3DES:string):string;
   function Decrypt(data,key3DES:string):string;
   function ReiniciarPuerto(forzado:Boolean=True):Boolean;

   // JSON Helper functions from Wayne
   procedure ActualizaCampoJSON(xpos:Integer; campo:string; valor:Variant);
   procedure AddPeticionJSON(const aFolio: Integer; const aResultado : string);
   procedure SetEstadoJSON(const AEstado: Integer);
   procedure ApplyTotalLitrosToJSON(const xpos: Integer; const TotalLitros: array of Real);
  end;

type
     TipoPosCarga = record
       posactual    :integer;
       posactual2   :integer;
       PosManguera  :array [1..3] of integer;
       PosMangueraDisp  :array [1..3] of integer;
       PosEstatus   :array [1..3] of integer;
       TotalLitros:array[1..3] of real;
       SwDesHabilitado :Boolean;
       ModoOpera    :String;
       Combustible   :array [1..3] of integer;
       SwDisponible :Boolean;
      end;

     TipoManguera = record
       address    :integer;
       lado       :integer;
       PosCarga   :integer;
       PosComb    :integer;
       estatus    :integer;
       descestat  :string[20];
       importe,
       volumen,
       importeant,
       volumenant,
       precioant,
       precio     :real;
       preciofisico,
       litrospreset,
       impopreset :real;
       ContInicDesp,
       ContTotErr,
       estatusant :integer;
       Estat_Cons :char;
       Combustible :integer;
       TotalLitros,
       TotalLitrosAnt :real;
       SwDespTot,
       SwDesp:boolean;
       HoraFV,
       Hora:TDateTime;
       SwInicio2,
       SwPreset,
       SwPresetImp,
       SwCargaTotales,
       IniciaCarga,
       SwPrepagoM,
       ActualizarPrecio,
       LeerPrecio,
       SwErrorCmnd,
       swcargando,
       Swfinventa,
       SwVentaValidada,
       swcargapreset,
       SwEnllavado,
       SwActivo    :boolean;
       TipoPago,
       FinVenta,
       ContBrinca,
       ContParo   :integer;
       Boucher    :string[12];
       ModoOpera  :string[8];
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

type
  TMetodos = (
    NOTHING_e, INITIALIZE_e, PARAMETERS_e, LOGIN_e, LOGOUT_e, PRICES_e, AUTHORIZE_e, SELFSERVICE_e, FULLSERVICE_e,
    PAYMENT_e, TRANSACTION_e, STATUS_e, TOTALS_e, HALT_e, RUN_e, SHUTDOWN_e, TERMINATE_e, STATE_e,
    TRACE_e, SAVELOGREQ_e, RESPCMND_e, LOG_e, LOGREQ_e, BLOCK_e, UNBLOCK_e, STOP_e, START_e);


var
  ogcvdispensarios_hongyang: Togcvdispensarios_hongyang;
  TPosCarga :array[1..32] of tipoposcarga;
  TMangueras:array[1..100] of tipomanguera;
  TabCmnd  :array[1..200] of RegCmnd;
  LPrecios  :array[1..4] of Double;
  PreciosInicio:Boolean;
  MaxMangueras:integer;
  Token        :string;
  SwCerrar    :boolean;
  CmndProc        :char;
  MangCiclo,
  MangueraActual  :integer;
  SwDespEmular,
  SwReintentoCmnd,
  swcierrabd,
  SwEsperaCmnd    :boolean;
  SwProcesando    :boolean;
  TimeCmnd,
  TimeResp        :TDateTime;
  LinCmndHJ,
  LinCmnd         :string;
  CharCmnd        :char;
  MangCmnd        :integer;
  TotalTramas,
  TotalErrores    :LongInt;
  TColaCmnd       :array[1..50] of string[50];
  ApCola          :integer;
  LinEstadoGen :string;
  Sw47:boolean;

implementation

uses StrUtils, ConvUtils;

{$R *.DFM}


procedure ServiceController(CtrlCode: DWord); stdcall;
begin
  ogcvdispensarios_hongyang.Controller(CtrlCode);
end;

function Togcvdispensarios_hongyang.GetServiceController: TServiceController;
begin
  Result := ServiceController;
end;

procedure Togcvdispensarios_hongyang.ServiceExecute(Sender: TService);
var
  config:TIniFile;
begin
  try
    config:= TIniFile.Create(ExtractFilePath(ParamStr(0)) +'PDISPENSARIOS.ini');
    rutaLog:=config.ReadString('CONF','RutaLog','C:\ImagenCo');
    // Change: Read Host and Port for ClientSocket
    ClientSocket1.Host:=ExtraeElemStrSep(config.ReadString('CONF','ServidorSocket','127.0.0.1:1004'), 1, ':');
    ClientSocket1.Port:=StrToInt(ExtraeElemStrSep(config.ReadString('CONF','ServidorSocket','127.0.0.1:1004'), 2, ':'));
    
    confPos:=config.ReadString('CONF','ConfPos','');
    modoPreset:=config.ReadString('CONF','ModoPreset','Si')='Si';
    licencia:=config.ReadString('CONF','Licencia','');
    minutosLog:=StrToInt(config.ReadString('CONF','MinutosLog','0'));
    ContadorAlarma:=0;
    ListaCmnd:=TStringList.Create;
    
    // Initialize JSON
    rootJSON:=TlkJSONObject.Create;
    SetEstadoJSON(-1);
    
    detenido:=True;
    estado:=-1;
    SegundosFinv:=30;
    horaLog:=Now;
    ListaLog:=TStringList.Create;
    ListaLogPetRes:=TStringList.Create;
    ListaComandos:=TStringList.Create;
    fechaInicio:=now;
    horaReinicio:=Now;

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
      raise Exception.Create('Error al iniciar servicio: '+e.Message);
    end;
  end;
end;

// Changed from ServerSocket1ClientRead to ClientSocket1Read
procedure Togcvdispensarios_hongyang.ClientSocket1Read(
  Sender: TObject; Socket: TCustomWinSocket);
  var
    mensaje,comando,parametro:string;
    i, folio:Integer;
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
        SELFSERVICE_e:
          ActivaModoPrepago(folio, parametro);
        FULLSERVICE_e:
          DesactivaModoPrepago(folio, parametro);
        PAYMENT_e:
          FinVenta(folio, parametro);
        TRANSACTION_e:
          TransaccionPosCarga(folio, parametro);
        STATUS_e:
          EstadoPosiciones(folio, parametro);
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
        BLOCK_e:
          Bloquear(folio, parametro);
        UNBLOCK_e:
          Desbloquear(folio, parametro);
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
      AgregaLogPetRes('Error: '+e.Message);
      GuardarLogPetRes(0);
      AddPeticionJSON(folio, 'False|'+e.Message+'|');
      raise Exception.Create('ClientSocket1Read: '+e.Message);
    end;
  end;
end;

procedure Togcvdispensarios_hongyang.ClientSocket1Connect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
  conectado:=True;
end;

procedure Togcvdispensarios_hongyang.ClientSocket1Disconnect(
  Sender: TObject; Socket: TCustomWinSocket);
begin
  conectado:=False;
  Timer1.Enabled:=False;
  Timer2.Enabled:=True;
end;

procedure Togcvdispensarios_hongyang.AgregaLogPetRes(lin: string);
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

function Togcvdispensarios_hongyang.CRC16(Data: AnsiString): AnsiString;
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

// Modified to send via ClientSocket
procedure Togcvdispensarios_hongyang.Responder(resp: string);
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
      AgregaLog('Error Responder: '+e.Message);
      raise Exception.Create('Error Responder: '+e.Message);   
    end;
  end;
end;

procedure Togcvdispensarios_hongyang.AgregaLog(lin: string);
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

function Togcvdispensarios_hongyang.IniciaPSerial(
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

procedure Togcvdispensarios_hongyang.Inicializar(folio:Integer; msj: string);
var
  js: TlkJSONBase;
  consolas,dispensarios,productos: TlkJSONbase;
  i,productID: Integer;
  datosPuerto, resultado:string;
begin
  try
    if estado>-1 then begin
      AddPeticionJSON(folio, 'False|El servicio ya habia sido inicializado|');
      Exit;
    end;

    js := TlkJSON.ParseText(ExtraeElemStrSep(msj,1,'|'));
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
    AddPeticionJSON(folio, 'True|');
  except
    on e:Exception do
      AddPeticionJSON(folio, 'False|Excepcion: '+e.Message+'|');
  end;
end;

function Togcvdispensarios_hongyang.AgregaPosCarga(
  posiciones: TlkJSONbase): string;
var i,xpos,j,
    xcomb,xpcomb,
    xaddr,xlado,xmang:integer;
    cPos,cMang:string;
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
    MaxMangueras:=0;
    MaxPosiciones:=0;
    xmang:=0;
    for i:=1 to 32 do with TPosCarga[i] do begin
      posactual:=1;
      posactual2:=1;
      for j:=1 to 3 do begin
        posmanguera[j]:=0;
        posestatus[j]:=0;
      end;
      TPosCarga[i].SwDesHabilitado:=False;
      SwDisponible:=true;
    end;
    for i:=1 to 100 do with TMangueras[i] do begin
      address:=0;
      lado:=0;
      poscarga:=0;
      poscomb:=0;
      estatus:=0;
      estatusant:=0;
      Estat_Cons:=' ';
      SwInicio2:=true;
      IniciaCarga:=false;
      SwPrepagoM:=True;
      SwEnllavado:=false;
      SwPreset:=false;
      ActualizarPrecio:=false;
      LeerPrecio:=false;
      importe:=0;
      importeant:=0;
      impopreset:=0;
      volumen:=0;
      volumenant:=0;
      precio:=0;
      precioant:=0;
      preciofisico:=0;
      TotalLitros:=0;
      TotalLitrosAnt:=0;
      SwCargando:=false;
      ContInicDesp:=0;
      ContTotErr:=0;
      SwFinVenta:=false;
      SwVentaValidada:=false;
      SwErrorCmnd:=false;
      SwCargaPreset:=false;
      SwCargaTotales:=True;
      SwActivo:=false;
      tipopago:=0;
      finventa:=0;
      boucher:='';
      contbrinca:=0;
      contparo:=0;
      HoraFV:=Now;
    end;

    // JSON Initialization
    posArr := TlkJSONlist.Create;

    for i:=0 to posiciones.Count-1 do begin
      xpos:=posiciones.Child[i].Field['DispenserId'].Value;
      if xpos>MaxPosiciones then
        MaxPosiciones:=xpos;
      
      // JSON Object Creation
      posObj := TlkJSONObject.Create;
      posObj.Add('DispenserId', xpos);
      posObj.Add('HoraOcc', FormatDateTime('yyyy-mm-dd',Now)+'T'+FormatDateTime('hh:nn',Now));
      posObj.Add('Manguera', 0);
      posObj.Add('Combustible', 0);
      posObj.Add('Estatus', 0);
      posObj.Add('Importe', 0);
      posObj.Add('Volumen', 0);
      posObj.Add('Precio', 0);

      hosesArr := TlkJSONlist.Create;

      mangueras:=posiciones.Child[i].Field['Hoses'];
      if UpperCase(VarToStr(posiciones.Child[i].Field['OperationMode'].Value))='FULLSERVICE' then
        TPosCarga[xpos].ModoOpera:='Prepago'
      else
        TPosCarga[xpos].ModoOpera:='Prepago';
      for j:=0 to mangueras.Count-1 do begin
        inc(xmang);
        xcomb:=mangueras.Child[j].Field['ProductId'].Value;
        xpcomb:=j+1;
        cPos:=ExtraeElemStrSep(confPos,xpos,';');
        cMang:=ExtraeElemStrSep(cPos,xpcomb,',');
        xaddr:=StrToInt(ExtraeElemStrSep(cMang,1,':'));
        xlado:=StrToInt(ExtraeElemStrSep(cMang,2,':'));
        AgregaLog('Manguera '+IntToStr(xmang)+': Address: '+IntToStr(xaddr)+': Lado: '+IntToStr(xlado));
        if xpcomb in [1..3] then begin
          TPosCarga[xpos].posmanguera[xpcomb]:=xmang;
          TPosCarga[xpos].PosMangueraDisp[xpcomb]:=mangueras.Child[j].Field['HoseId'].Value;
        end;
        if (xmang>MaxMangueras)and(xpos<=32) then
          MaxMangueras:=xmang;
        TPosCarga[xpos].Combustible[xpcomb]:=xcomb;
        with TMangueras[xmang] do begin
          address:=xaddr;
          Lado:=xlado;
          PosCarga:=xpos;
          PosComb:=xpcomb;
          Combustible:=xcomb;
          ActualizarPrecio:=true;
          SwDesp:=false;
          SwDespTot:=false;
          if UpperCase(VarToStr(posiciones.Child[i].Field['OperationMode'].Value))='FULLSERVICE' then
            ModoOpera:='Prepago'
          else
            ModoOpera:='Prepago';
          SwPrepagoM:= (ModoOpera='Prepago');
          ContBrinca:=xmang;
        end;
        
        // JSON Hose Creation
        hoseObj := TlkJSONObject.Create;
        hoseObj.Add('HoseId', TPosCarga[xpos].PosMangueraDisp[xpcomb]);
        hoseObj.Add('ProductId', xcomb);
        hoseObj.Add('Total', 0);
        hosesArr.Add(hoseObj);
      end;
      posObj.Add('Hoses', hosesArr);
      posArr.Add(posObj);
    end;
    
    // Add PosCarga array to rootJSON
    TlkJSONobject(rootJSON).Add('PosCarga', posArr);
    
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';  
  end;
end;

procedure Togcvdispensarios_hongyang.Login(folio: Integer; mensaje: string);
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

procedure Togcvdispensarios_hongyang.Logout(folio: Integer);
begin
  Token:='';
  AddPeticionJSON(folio, 'True|');
end;

procedure Togcvdispensarios_hongyang.GuardarLogPetRes(folio: Integer);
begin
  try
    AgregaLogPetRes('Version: '+version);
    ListaLogPetRes.SaveToFile(rutaLog+'\LogDispPetRes'+FiltraStrNum(FechaHoraToStr(Now))+'.txt');
    if folio>0 then
      AddPeticionJSON(folio, 'True|');
  except
    on e:Exception do begin
      AgregaLog('False|Excepcion: '+e.Message+'|');
      GuardarLog(0);
      if folio>0 then
        AddPeticionJSON(folio, 'False|Excepcion: '+e.Message+'|');
    end;
  end;
end;

function Togcvdispensarios_hongyang.FechaHoraExtToStr(
  FechaHora: TDateTime): String;
begin
  result:=FechaPaq(FechaHora)+' '+FormatDatetime('hh:mm:ss.zzz',FechaHora);
end;

function Togcvdispensarios_hongyang.MD5(const usuario: string): string;
var
  idmd5:TIdHashMessageDigest5;
  hash:T4x4LongWordRecord;
begin
  try
    idmd5 := TIdHashMessageDigest5.Create;
    hash := idmd5.HashValue(usuario);
    Result := idmd5.AsHex(hash);
    Result := AnsiLowerCase(Result);
    idmd5.Destroy;
  except
    on e:Exception do begin
      AgregaLog('MD5: '+e.Message);
      raise Exception.Create('MD5: '+e.Message);      
    end;
  end;
end;

function Togcvdispensarios_hongyang.ConvierteBCD(xvalor: real;
  xlong: integer): string;
var xstr,xres,ss,xaux:string;
    i,nc,nn,num:integer;
begin
  try
    num:=trunc(xvalor*100+0.5);
    xstr:=inttoclavenum(num,xlong);
    nc:=xlong div 2;
    xres:='';
    for i:=1 to nc do begin
      ss:=copy(xstr,xlong-2*i+1,2);
      nn:=StrToIntDef(ss[1],0)*16+StrToIntDef(ss[2],0);
      xres:=xres+char(nn);
    end;
    xaux:=StrToHexSep(xres);
    result:=xres;
  except
    on e:Exception do begin
      AgregaLog('ConvierteBCD: '+e.Message);
      raise Exception.Create('ConvierteBCD: '+e.Message);     
    end;
  end;
end;

function Togcvdispensarios_hongyang.CalculaBCC(ss: string): char;
var i,n,m:integer;
begin
  try
    n:=0;
    for i:=1 to length(ss) do
      n:=n+ord(ss[i]);
    m:=(n)mod(256);
    result:=char(256-m);
  except
    on e:Exception do begin
      AgregaLog('CalculaBCC: '+e.Message);
      raise Exception.Create('CalculaBCC: '+e.Message);    
    end;
  end;
end;

function Togcvdispensarios_hongyang.StrToHexSep(ss: string): string;
var i:integer;
    xaux:string;
begin
  try
    xaux:=inttohex(ord(ss[1]),2);
    for i:=2 to length(ss) do
      xaux:=xaux+' '+inttohex(ord(ss[i]),2);
    result:=xaux;
  except
    on e:Exception do begin
      AgregaLog('StrToHexSep: '+e.Message);
      raise Exception.Create('StrToHexSep: '+e.Message);
    end;
  end;
end;

procedure Togcvdispensarios_hongyang.IniciaPrecios(folio: Integer; msj: string);
var
  i,ii:Integer;
  precioComb:Double;
begin
  try
    for i:=1 to MaxMangueras do begin
      with TMangueras[i] do begin
        precioComb:=StrToFloatDef(ExtraeElemStrSep(msj,Combustible,'|'),-1);
        if precioComb<=0 then
          Continue;
        LPrecios[Combustible]:=precioComb;
        ii:=Trunc(precioComb*100+0.5);
        precio:=precioComb;
        MeteACola('U'+IntToClaveNum(i,2)+inttoclavenum(ii,4));
      end;
    end;
    AddPeticionJSON(folio, 'True|');
  except
    on e:Exception do
      AddPeticionJSON(folio, 'False|Excepcion: '+e.Message+'|');
  end;
end;

function Togcvdispensarios_hongyang.ComandoA(xaddr,xlado:integer):string; // Lee venta o display
// Send  01 06 01 0F 00 00 E9
//       xaddr xlong xlado cmnd
var ss:string;
begin
  ss:=char(xaddr)+char(6)+char(xlado)+char(15)+char(0)+char(0);
  result:=ss+CalculaBCC(ss);
end;

function Togcvdispensarios_hongyang.ComandoC(xaddr,xlado:integer):string; // Enllava
// Send  01 06 01 15 00 00 E9
//       xaddr xlong xlado cmnd
var ss:string;

begin
  ss:=char(xaddr)+char(6)+char(xlado)+char(21)+char(0)+char(0);
  result:=ss+CalculaBCC(ss);
end;

function Togcvdispensarios_hongyang.ComandoD(xaddr,xlado:integer):string; // DesEnllava
// Send  01 06 01 14 00 00 E9
//       xaddr xlong xlado cmnd
var ss:string;
begin
  ss:=char(xaddr)+char(6)+char(xlado)+char(20)+char(0)+char(0);
  result:=ss+CalculaBCC(ss);
end;

function Togcvdispensarios_hongyang.ComandoN(xaddr,xlado:integer):string; // Lee totalizador
// CPU=1   LADO=1
// Send  01 06 01 0E 00 00 EA
//       xaddr xlong xlado cmnd
var ss:string;
begin
  ss:=char(xaddr)+char(6)+char(xlado)+char(14)+char(0)+char(0);
  result:=ss+CalculaBCC(ss);
end;

function Togcvdispensarios_hongyang.ComandoU(xaddr,xlado,xprecio:integer):string; // Cambio de precios
// Precio=10.55   CPU=1  LADO=2
// Send  01 06 02 00 55 10 92
var ss:string;
    xval:real;
begin
  xval:=xprecio/100;
  ss:=char(xaddr)+char(6)+char(xlado)+char(0)+ConvierteBCD(xval,4);
  result:=ss+CalculaBCC(ss);
end;

function Togcvdispensarios_hongyang.ComandoV(xaddr,xlado:integer):string;    // Lee precios
// CPU=1  LADO=1
// Send  01 06 01 0C 00 00 EC
var ss:string;
begin
  ss:=char(xaddr)+char(6)+char(xlado)+char(12)+char(0)+char(0);
  result:=ss+CalculaBCC(ss);
end;

function Togcvdispensarios_hongyang.ComandoS(xaddr,xlado,ximporte:integer):string;    // Prefijar venta en importe
// Importe 10.00
// Send  01 07 02 09 00 10 00 DD
var ss:string;
    xval:real;
begin
  xval:=ximporte/100;
  ss:=char(xaddr)+char(7)+char(xlado)+char(9)+ConvierteBCD(xval,6);
  result:=ss+CalculaBCC(ss);
end;

function Togcvdispensarios_hongyang.ComandoL(xaddr,xlado,xlitros:integer):string; // Prefijado en litros
// Litros 2.00
// Send  01 07 02 0B 00 02 00 E9
var ss:string;
    xval:real;
begin
  xval:=xlitros/100;
  ss:=char(xaddr)+char(7)+char(xlado)+char(11)+ConvierteBCD(xval,6);
  result:=ss+CalculaBCC(ss);
end;

procedure Togcvdispensarios_hongyang.ComandoConsola(ss: string);
var s1,s2:string;
    xmang,xprecio,ximporte,xlitros:integer;
begin
  try
    LinCmnd:=ss;
    MangCmnd:=strtointdef(copy(LinCmnd,2,2),0);
    if (MangCmnd>=1)and(MangCmnd<=MaxMangueras) then begin
      CharCmnd:=LinCmnd[1];
      SwEsperaCmnd:=true;
      TimeCmnd:=Now;
      TimeResp:=Now;
      case Charcmnd of
        'A':begin
              xmang:=strtointdef(copy(LinCmnd,2,2),0);
              if xmang in [1..MaxMangueras] then with TMangueras[xmang] do
                LinCmndHJ:=ComandoA(address,lado);
            end;
        'C':begin
              xmang:=strtointdef(copy(LinCmnd,2,2),0);
              if xmang in [1..MaxMangueras] then with TMangueras[xmang] do
                LinCmndHJ:=ComandoC(address,lado);
            end;
        'D':begin
              xmang:=strtointdef(copy(LinCmnd,2,2),0);
              if xmang in [1..MaxMangueras] then with TMangueras[xmang] do
                LinCmndHJ:=ComandoD(address,lado);
            end;
        'N':begin
              xmang:=strtointdef(copy(LinCmnd,2,2),0);
              if xmang in [1..MaxMangueras] then with TMangueras[xmang] do
                LinCmndHJ:=ComandoN(address,lado);
            end;
        'U':begin
              xmang:=strtointdef(copy(LinCmnd,2,2),0);
              xprecio:=strtointdef(copy(LinCmnd,4,4),0);
              if xmang in [1..MaxMangueras] then with TMangueras[xmang] do
                LinCmndHJ:=ComandoU(address,lado,xprecio);
            end;
        'V':begin
              xmang:=strtointdef(copy(LinCmnd,2,2),0);
              if xmang in [1..MaxMangueras] then with TMangueras[xmang] do
                LinCmndHJ:=ComandoV(address,lado);
            end;
        'S':begin
              xmang:=strtointdef(copy(LinCmnd,2,2),0);
              ximporte:=strtointdef(copy(LinCmnd,4,6),0);
              if xmang in [1..MaxMangueras] then with TMangueras[xmang] do
                LinCmndHJ:=ComandoS(address,lado,ximporte);
            end;
        'L':begin
              xmang:=strtointdef(copy(LinCmnd,2,2),0);
              xlitros:=strtointdef(copy(LinCmnd,4,6),0);
              if xmang in [1..MaxMangueras] then with TMangueras[xmang] do
                LinCmndHJ:=ComandoL(address,lado,xlitros);
            end;
        else exit;
      end;
      Inc(TotalTramas);
      inc(ContadorAlarma);
      if ContadorAlarma>10 then
        LinEstadoGen:=CadenaStr(length(LinEstadoGen),'0');
      Timer1.Enabled:=false;
      try
        try
          s1:=copy(LinCmndHJ,1,1);
          s2:=copy(LinCmndHJ,2,length(LinCmndHJ)-1);
          pSerial.Parity:=pNone;
          pSerial.Parity:=pMark;
          pSerial.RTS:=false;
          if pSerial.Open then
            pSerial.Output:=s1;
          pSerial.Parity:=pNone;
          pSerial.Parity:=pSpace;
          AgregaLog('E '+StrToHexSep(LinCmndHJ)+'  >>'+ss);
          if pSerial.Open then
            pSerial.OutPut:=s2;
          pSerial.Parity:=pSpace;
        except
          on e:Exception do begin
            AgregaLog('Error pSerial.Output: '+e.Message);
            GuardarLog(0);
            raise Exception.Create('Error pSerial.Output: '+e.Message);
          end;
        end;
      finally
        Timer1.Enabled:=true;
      end;
    end;
  except
    on e:Exception do begin
      AgregaLog('Error ComandoConsola: '+e.Message);
      raise Exception.Create('Error ComandoConsola: '+e.Message);
    end;
  end;
end;

function Togcvdispensarios_hongyang.EjecutaComando(xCmnd: string): integer;
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
      SwNuevo:=True;
      Respuesta:='';
    end;
    Result:=FolioCmnd;
  except
    on e:Exception do begin
      AgregaLog('Error EjecutaComando: '+e.Message);
      raise Exception.Create('Error EjecutaComando: '+e.Message);    
    end;
  end;
end;

procedure Togcvdispensarios_hongyang.AutorizarVenta(folio: Integer; msj: string);
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

procedure Togcvdispensarios_hongyang.ActivaModoPrepago(folio: Integer; msj: string);
var
  xpos:Integer;
begin
  try
    xpos:=StrToIntDef(msj,-1);
    AddPeticionJSON(folio, 'True|'+IntToStr(EjecutaComando('AMP '+IntToClaveNum(xpos,2)))+'|');
  except
    on e:Exception do
      AddPeticionJSON(folio, 'False|Excepcion: '+e.Message+'|');
  end;
end;

procedure Togcvdispensarios_hongyang.DesactivaModoPrepago(
  folio: Integer; msj: string);
var
  xpos:Integer;
begin
  try
    xpos:=StrToIntDef(msj,-1);
    AddPeticionJSON(folio, 'True|'+IntToStr(EjecutaComando('DMP '+IntToClaveNum(xpos,2)))+'|');
  except
    on e:Exception do
      AddPeticionJSON(folio, 'False|Excepcion: '+e.Message+'|');
  end;
end;

procedure Togcvdispensarios_hongyang.FinVenta(folio: Integer; msj: string);
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

procedure Togcvdispensarios_hongyang.ProcesoComandoA(xResp:string);
var ss:string;
    ee,xp,ne:integer;
    ximp,xvol,xpre:real;
begin
  try
    with TMangueras[MangCmnd] do begin
      ss:=StrToHexSep(xResp);
      ne:=NoElemStrSep(ss,' ');
      ee:=DameEstatus(ss,SwEnllavado,SwErrorCmnd);
      if SwErrorCmnd then
        exit;
      if ne<9 then
        exit;
      estatusant:=estatus;
      importeant:=importe;
      volumenant:=volumen;
      importe:=ExtraeBCD(ss,3,5);
      volumen:=ExtraeBCD(ss,9,11);
      precio:=LPrecios[Combustible];
      if precio>0.01 then
        precioant:=precio;
      estatus:=ee;
      if (Estatusant=5)and(estatus=5)and(importe<importeant-0.5) then begin       // CAMBIO
        AgregaLog('>>Cambio importe '+inttostr(MangCmnd)+FormatoNumero(importeant,10,2)+FormatoNumero(importe,10,2));
        ximp:=importe;  importe:=importeant;
        xvol:=volumen;  volumen:=volumenant;
        xpre:=precio;   precio:=precioant;
        try
          swdesp:=true;
        finally
          importe:=ximp;
          volumen:=xvol;
          precio:=xpre;
        end;
      end;
      if (estatus=1)and(finventa=1)and(swfinventa) then begin
        if not SwVentaValidada then begin
          estatus:=8;
          if estatusant=5 then
            HoraFV:=Now;
          AgregaLog('>>Estatus 8 en Manguera FINV '+inttostr(MangCmnd));
        end
        else begin
          estatus:=7;
          AgregaLog('>>Estatus 7 en Manguera FINV '+inttostr(MangCmnd));
        end;
      end;
      if (estatus in [7,8])and((now-HoraFV)>10*tmsegundo) then begin
        estatus:=1;
        swfinventa:=false;
        AgregaLog('>>Salio de FINV '+inttostr(MangCmnd));
      end;
      case estatus of
        1:begin  // Inactivo
            descestat:='Inactivo';
            SwPreset:=false;
            Swfinventa:=false;
            ContInicDesp:=0;
            if EstatusAnt<>1 then
              FinVenta:=0;
          end;
        2:descestat:='Autorizado';
        //3:descestat:='Pistola Levantada';
        5:begin                // Despachando
            descestat:='Despachando';
            swcargando:=true;
            swfinventa:=true;
            ContTotErr:=0;
            SwVentaValidada:=false;
            if not SwPreset then begin
              AgregaLog('>>Se inicio venta sin preset');
              SwPreset:=True;
            end;
            if (SwPrepagoM)and(Importe<=0.001) then
              descestat:='Autorizado';
            Inc(ContInicDesp);
          end;
        7,8:descestat:='Fin de Venta';
        9:descestat:='Enllavado';
      end;
      if (Estatus in [1,8])and((swcargando)or(sw47)) then begin
        swcargando:=false;
        swdesptot:=true;
      end;
      if poscomb in [1..3] then with TPosCarga[PosCarga] do begin
        PosEstatus[poscomb]:=estatus;
        if (estatus in [5,7]) and (SwDisponible) then begin
          posactual2:=poscomb;
          AgregaLog('>>Se asigno posicion activa '+IntToStr(posactual2)+' a manguera '+inttostr(MangCmnd)+' de posicion '+IntToStr(PosCarga));
        end;
        posactual:=1;
        for xp:=2 to 3 do
          if posestatus[xp]>posestatus[posactual] then
            posactual:=xp;
      
        // Update JSON here for real-time status
        ActualizaCampoJSON(PosCarga, 'Estatus', estatus);
        ActualizaCampoJSON(PosCarga, 'Importe', importe);
        ActualizaCampoJSON(PosCarga, 'Volumen', volumen);
        ActualizaCampoJSON(PosCarga, 'Precio', precio);
        ActualizaCampoJSON(PosCarga, 'Combustible', Combustible[posactual2]);
        ActualizaCampoJSON(PosCarga, 'Manguera', PosMangueraDisp[posactual2]);
      
      end;
    end;
  except
    on e:Exception do begin
      AgregaLog('Error ProcesoComandoA: '+e.Message);
      raise Exception.Create('Error ProcesoComandoA:'+e.Message); 
    end;
  end;
end;

function Togcvdispensarios_hongyang.DameEstatus(xstr:string;var SwLocked,swerror:boolean):integer;
var xst,ss:string;
    ee:integer;

begin
  try
    sw47:=false;
    ee:=0;
    ss:=ExtraeElemStrSep(xstr,2,' ');
    xst:=HexToBinario(ss);
    if (xst[5]='0')and(xst[2]='0') then       // Inactivo
      ee:=1
    else if (xst[5]='1')and(xst[7]='1') then  // Despachando
      ee:=5
    else if (xst[5]='1')and(xst[2]='1') then  // Despachando
      ee:=5
    else if (xst[5]='0')and(xst[2]='1') then  // Pistola levantada
      ee:=1
    else if (xst[5]='1')and(xst[2]='0') then  // Autorizado
      ee:=2
    else if (xst[4]='1') then                 // Enllavado
      ee:=9;
    swerror:=(xst[3]='1');

    if (ss='06')or(ss='03')or(ss='16')or(ss='46')or(ss[2]='7') then begin     // fin venta                47
      ee:=1;
      if (ss[2]='7') then
        sw47:=true;
    end
    else if (ss='12')or(ss='02') then            // inativo
      ee:=1
    else if (ss='4A')or(ss='4B')or(ss='0A')or(ss='0E')or(ss='1A') then  // despachando            4B
      ee:=5;

    SwLocked:=false;
    if (ss='12')or(ss='16')or(ss='1A')or(ss='52') then  // enllavado
      swlocked:=true;

    result:=ee;
  except
    on e:Exception do begin
      AgregaLog('Error DameEstatus: '+e.Message);
      raise Exception.Create('Error DameEstatus: '+e.Message);  
    end;
  end;
end;

function Togcvdispensarios_hongyang.ExtraeBCD(xstr: string; xini,
  xfin: integer): real;
var i:integer;
    ss:string;
begin
  try
    i:=xfin;
    ss:='';
    while i>=xini do begin
      ss:=ss+ExtraeElemStrSep(xstr,i,' ');
      dec(i);
    end;
    result:=strtoint(ss)/100;
  except
    on e:Exception do begin
      AgregaLog('Error ExtraeBCD: '+e.Message);
      raise Exception.Create('Error ExtraeBCD: '+e.Message);
    end;
  end;
end;

procedure Togcvdispensarios_hongyang.MeteACola(xstr: string);
begin
  try
    if ApCola<50 then begin
      inc(ApCola);
      TColaCmnd[ApCola]:=xstr;
    end;
  except
    on e:Exception do begin
      AgregaLog('Error MeteACola: '+e.Message);
      raise Exception.Create('Error MeteACola: '+e.Message);
    end;
  end;
end;

function Togcvdispensarios_hongyang.HexToBinario(ss: string): string;
  function ConvierteBin(ch:char):string;
  begin
    case ch of
      '0':result:='0000';
      '1':result:='0001';
      '2':result:='0010';
      '3':result:='0011';
      '4':result:='0100';
      '5':result:='0101';
      '6':result:='0110';
      '7':result:='0111';
      '8':result:='1000';
      '9':result:='1001';
      'A':result:='1010';
      'B':result:='1011';
      'C':result:='1100';
      'D':result:='1101';
      'E':result:='1110';
      'F':result:='1111';
    end;
  end;
begin
  try
    result:=ConvierteBin(ss[1])+ConvierteBin(ss[2]);
  except
    on e:Exception do begin
      AgregaLog('Error HexToBinario: '+e.Message);
      raise Exception.Create('Error HexToBinario: '+e.Message);   
    end;
  end;
end;

procedure Togcvdispensarios_hongyang.ProcesoComandoC(xResp: string);
// Receiver  03  07 F6
var ss:string;
    swerr:boolean;
begin
  try
    with TMangueras[MangCmnd] do begin
      ss:=StrToHexSep(xResp);
      DameEstatus(ss,SwEnllavado,SwErr);
      if not SwErr then begin
        //ActualizarPrecio:=false;
        //LeerPrecio:=true;
      end;
    end;
  except
    on e:Exception do begin
      AgregaLog('Error ProcesoComandoC: '+e.Message);
      raise Exception.Create('Error ProcesoComandoC: '+e.Message);   
    end;
  end;
end;

procedure Togcvdispensarios_hongyang.ProcesoComandoD(xResp: string);
// Receiver  03  07 F6
var ss:string;
    swerr:boolean;
begin
  try
    with TMangueras[MangCmnd] do begin
      ss:=StrToHexSep(xResp);
      DameEstatus(ss,SwEnllavado,SwErr);
      if not SwErr then begin
        //ActualizarPrecio:=false;
        //LeerPrecio:=true;
      end;
    end;
  except
    on e:Exception do begin
      AgregaLog('Error ProcesoComandoD: '+e.Message);
      raise Exception.Create('Error ProcesoComandoD: '+e.Message); 
    end;
  end;
end;

procedure Togcvdispensarios_hongyang.ProcesoComandoN(xResp: string);
// Receiver  15  03
//           00 00 00 00 00 00
//           07 03 08 00 00 00   litros
//           14 84 10 00 00 00   importe
//           2E
var ss:string;
    xmang,xpos:integer;
    diflitrostot:real;
begin
  with TMangueras[MangCmnd] do begin
    ss:=StrToHexSep(xResp);
    try
      totallitrosant:=totallitros;
      totallitros:=ExtraeBCD(ss,9,14);
      xpos:=PosCarga;
      for xmang:=1 to MaxMangueras do with TMangueras[xmang] do
        if PosCarga=xpos then
          if PosComb in [1..4] then begin
            TPosCarga[xpos].TotalLitros[PosComb]:=totallitros;
            ApplyTotalLitrosToJSON(xpos,TPosCarga[xpos].TotalLitros);
          end;
      SwCargaTotales:=false;
      if swdesptot then begin
        diflitrostot:=abs(totallitros-totallitrosant);
        if diflitrostot>0.01 then begin // hay venta
          if (abs(diflitrostot-volumen)>0.05)and(ContTotErr<2) then
            AgregaLog('Diferencia Volumen Manguera '+inttostr(MangCmnd)+'  litros: '+FormatoNumero(abs(diflitrostot-volumen),5,2));
          swdesp:=true;
          HoraFV:=Now;
          ActualizaCampoJSON(xpos, 'HoraOcc', FormatDateTime('yyyy-mm-dd',HoraFV)+'T'+FormatDateTime('hh:nn',HoraFV));
          if TMangueras[MangCmnd].SwPrepagoM then
            MeteACola('C'+inttoclavenum(MangCmnd,2));
          if (finventa=1)and(swfinventa) then
            estatus:=7;
          AgregaLog('>>Fin de Venta Manguera '+inttostr(MangCmnd));
          SwVentaValidada:=true;
        end
        else 
          SwFinVenta:=false;
        swdesptot:=false;
      end;
    except
      on e:Exception do begin
        AgregaLog('Error ProcesoComandoN: '+e.Message);
        raise Exception.Create('Error ProcesoComandoN: '+e.Message);
      end;
    end;
  end;
end;

procedure Togcvdispensarios_hongyang.ProcesoComandoU(xResp: string);
// Receiver  03  07 F6
var ss:string;
    swerr:boolean;
begin
  try
    with TMangueras[MangCmnd] do begin
      ss:=StrToHexSep(xResp);
      DameEstatus(ss,SwEnllavado,SwErr);
      if not SwErr then begin
        ActualizarPrecio:=false;
        LeerPrecio:=true;
      end;
    end;
  except
    on e:Exception do begin
      AgregaLog('Error ProcesoComandoU: '+e.Message);
      raise Exception.Create('Error ProcesoComandoU: '+e.Message); 
    end;
  end;
end;

procedure Togcvdispensarios_hongyang.ProcesoComandoV(xResp: string);
// Receiver  07  02 00 00 23 11 C3
// PRICE=11.23
var ss:string;
begin
  with TMangueras[MangCmnd] do begin
    ss:=StrToHexSep(xResp);
    try
      preciofisico:=ExtraeBCD(ss,5,6);
      LeerPrecio:=false;
    except
      AgregaLog('Error ProcesoComandoV: '+xresp);
    end;
  end;
end;

procedure Togcvdispensarios_hongyang.ProcesoComandoS(xResp: string);
// Receiver  03  07 F6
var ss:string;
    swerr:boolean;
begin
  try
    with TMangueras[MangCmnd] do begin
      ss:=StrToHexSep(xResp);
      DameEstatus(ss,SwEnllavado,SwErr);
      if not SwErr then begin
        SwPreset:=true;
        SwPresetImp:=true;
      end;
    end;
  except
    on e:Exception do begin
      AgregaLog('Error ProcesoComandoS: '+e.Message);
      raise Exception.Create('Error ProcesoComandoS: '+e.Message);   
    end;
  end;
end;

procedure Togcvdispensarios_hongyang.ProcesoComandoL(xResp: string);
// Receiver  03  07 F6
var ss:string;
    swerr:boolean;
begin
  try
    with TMangueras[MangCmnd] do begin
      ss:=StrToHexSep(xResp);
      DameEstatus(ss,SwEnllavado,SwErr);
      if not SwErr then begin
        SwPreset:=true;
        SwPresetImp:=false;
      end;
    end;
  except
    on e:Exception do begin
      AgregaLog('Error ProcesoComandoL: '+e.Message);
      raise Exception.Create('Error ProcesoComandoL: '+e.Message); 
    end;
  end;
end;

procedure Togcvdispensarios_hongyang.ProcesaLineaRec(LineaRsp: string);
var xstr,xstr2,xdv,xdv2:string;
begin
  try
    try
      if (minutosLog>0) and (MinutesBetween(Now,horaLog)>=minutosLog) then begin
        horaLog:=Now;
        GuardarLog(0);
      end;
      SwProcesando:=True;
      FinLinea:=false;  LineaProc:='';
      xstr:=StrToHexSep(LineaRsp);
      AgregaLog('R '+xstr);
      xdv:=copy(xstr,length(xstr)-1,2);
      xstr2:=copy(LineaRsp,1,length(LineaRsp)-1);
      xdv2:=StrToHexSep(CalculaBCC(xstr2));
      if xdv<>xdv2 then begin
        Inc(TotalErrores);
        AgregaLog('>> error '+xdv+' '+xdv2);
        if not SwReintentoCmnd then begin
          //SwEsperaCmnd:=true;
          SwReintentoCmnd:=true;
          MeteACola(LinCmnd);
        end;
        exit;
      end;
      case CharCmnd of
        'A':if length(LineaRsp)=12 then
              ProcesoComandoA(LineaRsp)
            else
              ReiniciarPuerto;
        'C':if length(LineaRsp)=3 then
              ProcesoComandoC(LineaRsp)
            else
              ReiniciarPuerto;
        'D':if length(LineaRsp)=3 then
              ProcesoComandoD(LineaRsp)
            else
              ReiniciarPuerto;
        'N':if length(LineaRsp)=21 then
              ProcesoComandoN(LineaRsp)
            else
              ReiniciarPuerto;
        'U':if length(LineaRsp)=3 then
              ProcesoComandoU(LineaRsp)
            else
              ReiniciarPuerto;
        'V':if length(LineaRsp)=7 then
              ProcesoComandoV(LineaRsp)
            else
              ReiniciarPuerto;
        'S':if length(LineaRsp)=3 then
              ProcesoComandoS(LineaRsp)
            else
              ReiniciarPuerto;
        'L':if length(LineaRsp)=3 then
              ProcesoComandoL(LineaRsp)
            else
              ReiniciarPuerto;
      end;
    except
      on e:Exception do begin
        AgregaLog('Error ProcesaLineaRec: '+e.Message);
        raise Exception.Create('Error ProcesaLineaRec: '+e.Message);  
      end;
    end;
  finally
    SwEsperaCmnd:=false;
    SwProcesando:=False;
  end;
end;

procedure Togcvdispensarios_hongyang.pSerialTriggerAvail(CP: TObject;
  Count: Word);
var I:Word;
    C:Char;
    xlong:integer;
begin
  try
    if SwProcesando then Exit;
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
        LineaProc:=LineaProc+C;
        xlong:=ord(LineaProc[1]);
        if length(LineaProc)=xlong then
          FinLinea:=true;
      end;
      if FinLinea then begin
        ProcesaLineaRec(LineaProc);
        SwEsperaCmnd:=false;
      end;
    finally
      TimeResp:=Now;
      Timer1.Enabled:=true;
    end;
  except
    on e:Exception do begin
      AgregaLog('Error pSerialTriggerAvail: '+e.Message);
      raise Exception.Create('Error pSerialTriggerAvail: '+e.Message);  
    end;
  end;
end;

procedure Togcvdispensarios_hongyang.PublicaEstatusDispensarios;
var xpos,xmang:integer;
    lin,xestado,
    xmodo,ss        :string;
begin
  try
    lin:='';xestado:='';xmodo:='';
    PosicionesLibres:=True;
    for xpos:=1 to MaxPosiciones do with TPosCarga[xpos] do begin
      xmang:=PosManguera[PosActual2];
      with TMangueras[xmang] do begin
        xmodo:=xmodo+ModoOpera[1];
        case estatus of
          0:xestado:=xestado+'0'; // Sin Comunicacion
          1:xestado:=xestado+'1'; // Inactivo (Idle)
          5:xestado:=xestado+'2'; // Cargando (In Use)
          7,8:xestado:=xestado+'3'; // Fin de Carga (Used)
          3,4:xestado:=xestado+'5'; // Llamando (Calling)
          2:xestado:=xestado+'9'; // Autorizado
          6:xestado:=xestado+'8'; // Detenido (Stoped)
          else xestado:=xestado+'0';
        end;
        ss:=inttoclavenum(xpos,2)+'/'+inttostr(combustible);
        ss:=ss+'/'+FormatFloat('###0.##',volumen);
        ss:=ss+'/'+FormatFloat('#0.##',precio);
        ss:=ss+'/'+FormatFloat('####0.##',importe);
        lin:=lin+'#'+ss;
        if (SwDisponible) and (estatus<>1) then
          AgregaLog('>>Se ocupo posicion '+inttostr(xpos)+' con manguera '+IntToStr(xmang))
        else if (not SwDisponible) and (estatus=1) then
          AgregaLog('>>Se libero posicion '+inttostr(xpos)+' de manguera '+IntToStr(xmang));
        SwDisponible:=estatus=1;
        if estatus>1 then
          PosicionesLibres:=False;
      end;
    end;
    if lin='' then
      lin:=xestado+'#'
    else
      lin:=xestado+lin;
    lin:=lin+'&'+xmodo;
    LinEstadoGen:=xestado;
  except
    on e:Exception do begin
      AgregaLog('Error PublicaEstatusDispensarios: '+e.Message);
      raise Exception.Create('Error PublicaEstatusDispensarios: '+e.Message);   
    end;
  end;
end;

procedure Togcvdispensarios_hongyang.SacaDeCola(var xstr: string);
var i:integer;
begin
  try
    xstr:='';
    if ApCola>0 then begin
      xstr:=TColaCmnd[1];
      dec(ApCola);
      if ApCola>0 then
        for i:=1 to ApCola do
          TColaCmnd[i]:=TColaCmnd[i+1];
    end;
  except
    on e:Exception do begin
      AgregaLog('Error SacaDeCola: '+e.Message);
      raise Exception.Create('Error SacaDeCola: '+e.Message); 
    end;
  end;
end;

procedure Togcvdispensarios_hongyang.Timer1Timer(Sender: TObject);
label uno;
var xmang:integer;
    swestatus7:boolean;
    xcmnd:string;
begin
  try
    try
      // JSON Load Balancing (from Wayne)
      Inc(xTurnoSocket);
      if xTurnoSocket>3 then
        xTurnoSocket:=1;

      // ENVIO DE COMANDOS
      if not SwEsperaCmnd then begin
        SwReintentoCmnd:=false;
        if HoursBetween(Now, horaReinicio)>=6 then begin
          if ReiniciarPuerto(False) then
            Exit;
        end;
        uno:
        Case CmndProc of
          // LEE DISPLAY Y STATUS
          'A':begin
                if MangCiclo<=MaxMangueras then with TMangueras[MangCiclo] do begin
                  if ContParo<=0 then begin
                    if (ContBrinca<=0)or(Estatus>1)or(SwPreset) then begin
                      if (Estatus=1) and (not modoPreset) then
                        ContBrinca:=4
                      else
                        ContBrinca:=30;
                      ComandoConsola('A'+IntToClavenum(MangCiclo,2));
                      inc(MangCiclo);
                    end
                    else begin
                      dec(ContBrinca);
                      inc(MangCiclo);
                      goto uno;
                    end;
                  end
                  else begin
                    dec(ContParo);
                    inc(MangCiclo);
                    goto uno;
                  end;
                end
                else begin
                  MangCiclo:=1;
                  SwEstatus7:=false;
                  for xmang:=1 to MaxMangueras do
                    if TMangueras[xmang].estatus=7 then
                      SwEstatus7:=true;
                  if SwEstatus7 then begin
                    ProcesaComandosExternos;
                  end;
                  CmndProc:='N';
                end;
              end;
          // LEE TOTALES
          'N':begin
                if MangCiclo<=MaxMangueras then with TMangueras[MangCiclo] do begin
                  if (SwCargaTotales) then begin
                    ComandoConsola('N'+IntToClavenum(MangCiclo,2));
                    inc(MangCiclo);
                  end
                  else begin
                    inc(MangCiclo);
                    goto uno;
                  end;
                end
                else begin
                  MangCiclo:=1;
                  CmndProc:='V';
                end;
              end;
          // LEER PRECIOS
          'V':begin
                if MangCiclo<=MaxMangueras then with TMangueras[MangCiclo] do begin
                  if (LeerPrecio)and(estatus>0) then begin
                    ComandoConsola('V'+IntToClaveNum(MangCiclo,2));
                    inc(MangCiclo);
                  end
                  else begin
                    inc(MangCiclo);
                    goto uno;
                  end;
                end
                else begin
                  MangCiclo:=1;
                  CmndProc:='Z';
                end;
              end;
          // REVISA COMANDOS
          'Z':begin
                PublicaEstatusDispensarios;
                ProcesaComandosExternos;
                MangCiclo:=1;
                CmndProc:='W';
              end;
          // REVISA COMANDOS
          'W':begin
                if ApCola>0 then begin
                  SacaDeCola(xcmnd);
                  ComandoConsola(xcmnd);
                end
                else begin
                  MangCiclo:=1;
                  CmndProc:='A';
                end;
              end;
        end;
      end
      // MANEJO DE ESPERA
      else begin
        if ((Now-TimeResp)>TmSegundo*0.5)and(LineaProc<>'') then begin
          SwEsperaCmnd:=false;
          ProcesaLineaRec(LineaProc);
        end
        else if ((Now-TimeCmnd)>TmSegundo) then begin
          SwEsperaCmnd:=false;
          with TMangueras[MangCmnd] do begin
            estatus:=0;
            descestat:='Sin Comunicacion';
            contparo:=5;
            // JSON update on error
            ActualizaCampoJSON(PosCarga, 'Estatus', 0);
          end;
        end;
      end;
    except
      on e:Exception do begin
        AgregaLog('Error Timer1: '+e.Message);
        raise Exception.Create('Error Timer1: '+e.Message); 
      end;
    end;
  finally
    // Send JSON updates similar to Wayne
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

// Added Timer2 for connection management
procedure Togcvdispensarios_hongyang.Timer2Timer(Sender: TObject);
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

procedure Togcvdispensarios_hongyang.ProcesaComandosExternos;
var swsalir:boolean;
    ss,rsp:string;
    xcmnd,xpos,xcomb,xmang,ximp,i:integer;
    ximporte,xlitros:real;
begin
  try
    // PROCESA COMANDOS EXTERNOS
    SwSalir:=false;
    for xcmnd:=1 to 200 do if (TabCmnd[xcmnd].SwActivo)and(not TabCmnd[xcmnd].SwResp) then begin
      SwAplicaCmnd:=true;
      ss:=ExtraeElemStrSep(TabCmnd[xcmnd].Comando,1,' ');
      AgregaLog(TabCmnd[xcmnd].Comando);
      // CMND: ACTIVA MODO PREPAGO
      if ss='AMP' then begin
        xpos:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,2,' '),0);
        if (xpos in [0..MaxPosiciones]) then begin
          if xpos=0 then begin
            for xpos:=1 to MaxPosiciones do begin
              for i:=1 to MaxMangueras do begin
                //if (TMangueras[i].PosCarga=xpos) then begin
                  MeteACola('C'+inttoclavenum(i,2));
                  TMangueras[i].SwPrepagoM:=true;
                  TMangueras[i].ModoOpera:='Prepago';
                //end;
              end;
            end
          end
          else begin
            for i:=1 to MaxMangueras do begin
              if (TMangueras[i].PosCarga=xpos) then begin
                MeteACola('C'+inttoclavenum(i,2));
                TMangueras[i].SwPrepagoM:=true;
                TMangueras[i].ModoOpera:='Prepago';
              end;
            end;
          end;
          rsp:='OK';
        end
        else SwAplicaCmnd:=false;
      end
      // CMND: DESACTIVA MODO PREPAGO
      else if ss='DMP' then begin
        xpos:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,2,' '),0);
        if (xpos in [0..MaxPosiciones]) then begin
          if xpos=0 then begin
            for xpos:=1 to MaxPosiciones do begin
              for i:=1 to MaxMangueras do begin
                //if (TMangueras[i].PosCarga=xpos) then begin
                  MeteACola('D'+inttoclavenum(i,2));
                  TMangueras[i].SwPrepagoM:=false;
                  TMangueras[i].ModoOpera:='Prepago';
                //end;
              end;
            end;
          end
          else begin
            for i:=1 to MaxMangueras do begin
              if (TMangueras[i].PosCarga=xpos) then begin
                MeteACola('D'+inttoclavenum(i,2));
                TMangueras[i].SwPrepagoM:=false;
                TMangueras[i].ModoOpera:='Prepago';
              end;
            end;
          end;
          rsp:='OK';
        end
        else SwAplicaCmnd:=false;
      end
      // ORDENA CARGA DE COMBUSTIBLE (PESOS)
      else if ss='OCC' then begin
        rsp:='OK';
        xpos:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,2,' '),0);
        xcomb:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,4,' '),0);
        xmang:=0;
        if not TPosCarga[xpos].SwDesHabilitado then begin
          for i:=1 to MaxMangueras do begin
            if (TMangueras[i].PosCarga=xpos) then begin
              if (TMangueras[i].Combustible=xcomb) then
                xmang:=i;
              if (not TMangueras[i].estatus in [1,3]) then begin
                rsp:='Posicion de carga no esta disponible';
                Break;
              end;
            end;
          end;
          if (xmang in [1..MaxMangueras]) then begin
            if (TMangueras[xmang].estatus in [1,3])then begin
              try
                xImporte:=StrToFLoat(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,3,' '));
                rsp:=ValidaCifra(xImporte,4,2);
                if rsp='OK' then
                  if (xImporte<1) then
                    xImporte:=9999;
              except
                xImporte:=0;
                rsp:='Error en Importe';
              end;
              if rsp='OK' then begin
//                TMangueras[xmang].finventa:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,5,' '),0);
                TMangueras[xmang].impopreset:=ximporte;
                ximp:=Trunc(xImporte*100+0.5);

//                if TMangueras[xmang].SwPrepagoM then begin
//                  MeteACola('D'+inttoclavenum(xmang,2));
//                end;

                MeteACola('S'+inttoclavenum(xmang,2)+InttoClaveNum(ximp,6));
                SwSalir:=true;
              end;
            end
            else rsp:='Manguera no esta disponible';
          end
          else rsp:='Manguera no existe';
        end
        else rsp:='Posicion Bloqueada';
      end
      // ORDENA CARGA DE COMBUSTIBLE (LITROS)
      else if ss='OCL' then begin
        rsp:='OK';
        xpos:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,2,' '),0);
        xcomb:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,4,' '),0);
        xmang:=0;
        if not TPosCarga[xpos].SwDesHabilitado then begin
          for i:=1 to MaxMangueras do begin
            if (TMangueras[i].PosCarga=xpos) then begin
              if (TMangueras[i].Combustible=xcomb) then
                xmang:=i;
              if (not TMangueras[i].estatus in [1,3]) then begin
                rsp:='Posicion de carga no esta disponible';
                Break;
              end;
            end;
          end;
          if (xmang in [1..MaxMangueras]) then begin
            if (TMangueras[xmang].estatus in [1,3])then begin
              try
                xLitros:=StrToFLoat(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,3,' '));
                rsp:=ValidaCifra(xLitros,4,2);
                if rsp='OK' then
                  if (xLitros<0.5) then
                    rsp:='Valor minimo permitido: 0.5 lts';
              except
                xLitros:=0;
                rsp:='Error en Valor';
              end;
              if rsp='OK' then begin
//                TMangueras[xmang].finventa:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,5,' '),0);
                TMangueras[xmang].litrospreset:=xlitros;
                ximp:=Trunc(xLitros*100+0.5);

//                if TMangueras[xmang].SwPrepagoM then begin
//                  MeteACola('D'+inttoclavenum(xmang,2));
//                end;

                MeteACola('L'+inttoclavenum(xmang,2)+InttoClaveNum(ximp,6));
                SwSalir:=true;
              end;
            end
            else rsp:='Manguera no esta disponible';
          end
          else rsp:='Manguera no existe';
        end
        else rsp:='Posicion Bloqueada';
      end
      else if ss='TOTAL' then begin
        rsp:='OK';
        xpos:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,2,' '),0);
        SwAplicaCmnd:=False;
        with TPosCarga[xpos] do begin
          if TabCmnd[xcmnd].SwNuevo then begin
            TMangueras[PosManguera[PosActual2]].SwCargaTotales:=True;
            TabCmnd[xcmnd].SwNuevo:=false;
          end
          else begin
            if not TMangueras[PosManguera[PosActual2]].SwCargaTotales then begin
              for i:=1 to MaxMangueras do begin
                if (TMangueras[i].PosCarga=xpos) then
                  TotalLitros[TMangueras[i].PosComb]:=TMangueras[i].TotalLitros;
              end;
              rsp:='OK'+FormatFloat('0.000',ToTalLitros[1])+'|'+FormatoMoneda(ToTalLitros[1]*LPrecios[Combustible[1]])+'|'+
                              FormatFloat('0.000',ToTalLitros[2])+'|'+FormatoMoneda(ToTalLitros[2]*LPrecios[Combustible[2]])+'|'+
                              FormatFloat('0.000',ToTalLitros[3])+'|'+FormatoMoneda(ToTalLitros[3]*LPrecios[Combustible[3]]);
              SwAplicaCmnd:=True;
            end;
          end;
        end;
      end
      else if ss='FINV' then begin
//        xpos:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,2,' '),0);
//        with TPosCarga[xpos] do begin
//          if TMangueras[PosManguera[PosActual2]].estatus in [7,8] then begin
//            TMangueras[PosManguera[PosActual2]].estatus:=1;
            rsp:='OK'
//          end
//          else
//            rsp:='Posicion no esta en fin de venta';
//        end;
      end
      else rsp:='Comando no Soportado o no Existe';
      if SwAplicaCmnd then begin
        TabCmnd[xcmnd].SwResp:=true;
        TabCmnd[xcmnd].Respuesta:=rsp;
        AgregaLog(LlenaStr(TabCmnd[xcmnd].Comando,'I',40,' ')+' Respuesta: '+TabCmnd[xcmnd].Respuesta);
      end;
      if SwSalir then exit;
    end;
  except
    on e:Exception do begin
      AgregaLog('Error ProcesaComandosExternos: '+e.Message);
      raise Exception.Create('Error ProcesaComandosExternos: '+e.Message); 
    end;
  end;
end;

function Togcvdispensarios_hongyang.ValidaCifra(xvalor: real; xenteros,
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
      raise Exception.Create('Error ValidaCifra: '+e.Message);   
    end;
  end;
end;

procedure Togcvdispensarios_hongyang.TransaccionPosCarga(
  folio: Integer; msj: string);
var
  xpos:Integer;
begin
  try
    xpos:=StrToIntDef(msj,-1);
    if xpos<0 then begin
      AddPeticionJSON(folio, 'False|Favor de indicar correctamente la posicion de carga|');
      Exit;
    end;

    if xpos>MaxPosiciones then begin
      AddPeticionJSON(folio, 'False|La posicion de carga no se encuentra registrada|');
      Exit;
    end;

    with TPosCarga[xpos] do with TMangueras[PosManguera[PosActual2]] do
      AddPeticionJSON(folio, 'True|'+FormatDateTime('yyyy-mm-dd',HoraFv)+'T'+FormatDateTime('hh:nn',HoraFv)+'|'+IntToStr(PosMangueraDisp[PosActual2])+'|'+IntToStr(Combustible)+'|'+
              FormatFloat('0.000',volumen)+'|'+FormatFloat('0.00',precio)+'|'+FormatFloat('0.00',importe)+'|');
  except
    on e:Exception do
      AddPeticionJSON(folio, 'False|Excepcion: '+e.Message+'|');
  end;
end;

procedure Togcvdispensarios_hongyang.EstadoPosiciones(folio: Integer; msj: string);
var
  xpos:Integer;
begin
  try
    xpos:=StrToIntDef(msj,-1);
    if xpos<0 then begin
      AddPeticionJSON(folio, 'False|Favor de indicar correctamente la posicion de carga|');
      Exit;
    end;

    if LinEstadoGen='' then begin
      AddPeticionJSON(folio, 'False|Error de comunicacion|');
      Exit;
    end;

    if xpos>0 then
      AddPeticionJSON(folio, 'True|'+LinEstadoGen[xpos]+'|')
    else
      AddPeticionJSON(folio, 'True|'+LinEstadoGen+'|');
  except
    on e:Exception do
      AddPeticionJSON(folio, 'False|Excepcion: '+e.Message+'|');
  end;
end;

procedure Togcvdispensarios_hongyang.Detener(folio: Integer);
begin
  try
    if estado=-1 then begin
      AddPeticionJSON(folio, 'False|El proceso no se ha iniciado aun|');
      Exit;
    end;

    if not detenido then begin
      pSerial.Open:=False;
      Timer1.Enabled:=False;
      Timer2.Enabled:=True; // Enable secondary timer
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

procedure Togcvdispensarios_hongyang.Iniciar(folio: Integer);
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
    CmndProc:='A';
    Timer1.Enabled:=True;
    Timer2.Enabled:=False; // Disable secondary timer
    numPaso:=0;
    if modoPreset then
      EjecutaComando('AMP 00');
    
    SetEstadoJSON(estado);
    AddPeticionJSON(folio, 'True|');
  except
    on e:Exception do
      AddPeticionJSON(folio, 'False|'+e.Message+'|');
  end;
end;

procedure Togcvdispensarios_hongyang.Shutdown(folio: Integer);
begin
  if estado>0 then
    AddPeticionJSON(folio, 'False|El servicio esta en proceso, no fue posible detenerlo|')
  else begin
    AddPeticionJSON(folio, 'True|');
    ServiceThread.Terminate;
  end;
end;

procedure Togcvdispensarios_hongyang.Terminar(folio: Integer);
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

function Togcvdispensarios_hongyang.ObtenerEstado: string;
begin
  Result:='True|'+IntToStr(estado)+'|';
end;

procedure Togcvdispensarios_hongyang.GuardarLog(folio: Integer);
begin
  try
    AgregaLog('Version: '+version);
    if folio=0 then begin // Called internally
      ListaLog.SaveToFile(rutaLog+'\LogDisp'+FiltraStrNum(FechaHoraToStr(Now))+'.txt');
      GuardarLogPetRes(0);
      GuardaLogComandos;
    end
    else begin // Called via socket
      ListaLog.SaveToFile(rutaLog+'\LogDispInicio'+FiltraStrNum(FechaHoraToStr(now))+'.txt');
      AddPeticionJSON(folio, 'True|'+rutaLog+'\LogDisp'+FiltraStrNum(FechaHoraToStr(Now))+'.txt');
    end;
  except
    on e:Exception do
      if folio > 0 then AddPeticionJSON(folio, 'False|Excepcion: '+e.Message+'|');
  end;
end;

procedure Togcvdispensarios_hongyang.RespuestaComando(folio: Integer; msj: string);
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
        resp:=copy(resp,3,Length(resp)-2)+'|'
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

procedure Togcvdispensarios_hongyang.ObtenerLog(folio: Integer; r: Integer);
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

procedure Togcvdispensarios_hongyang.ObtenerLogPetRes(folio: Integer; r: Integer);
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

function Togcvdispensarios_hongyang.ResultadoComando(
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
    on e:Exception do begin
      AgregaLog('Error ResultadoComando: '+e.Message);
      raise Exception.Create('Error ResultadoComando: '+e.Message); 
    end;
  end;
end;

procedure Togcvdispensarios_hongyang.TotalesBomba(folio: Integer; msj: string);
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

procedure Togcvdispensarios_hongyang.IniciarPrecios;
var
  i,ii:Integer;
begin
  try
    for i:=1 to MaxMangueras do begin
      with TMangueras[i] do begin
        ii:=Trunc(LPrecios[Combustible]*100+0.5);
        precio:=LPrecios[Combustible];
        MeteACola('U'+IntToClaveNum(i,2)+inttoclavenum(ii,4));
      end;
    end;
    PreciosInicio:=False;
  except
    on e:Exception do begin
      AgregaLog('Error IniciarPrecios: '+e.Message);
      raise Exception.Create('Error IniciarPrecios: '+e.Message); 
    end;
  end;
end;

procedure Togcvdispensarios_hongyang.Bloquear(folio: Integer; msj: string);
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
        if not ContieneChar(LinEstadoGen,'2') then begin
          for xpos:=1 to MaxPosiciones do begin
            TPosCarga[xpos].SwDesHabilitado:=True;
            if TPosCarga[xpos].ModoOpera='Normal' then
              EjecutaComando('AMP '+IntToClaveNum(xpos,2));
          end;
          AddPeticionJSON(folio, 'True|');       
        end
        else
          AddPeticionJSON(folio, 'False|Existen dispensarios cargando combustible|');
      end
      else if (xpos in [1..MaxPosiciones]) then begin
        if LinEstadoGen[xpos]<>'2' then begin
          TPosCarga[xpos].SwDesHabilitado:=True;
          if TPosCarga[xpos].ModoOpera='Normal' then
            EjecutaComando('AMP '+IntToClaveNum(xpos,2));
          AddPeticionJSON(folio, 'True|');
        end
        else
          AddPeticionJSON(folio, 'False|El dispensario esta cargando combustible|');
      end;
    end
    else AddPeticionJSON(folio, 'False|Posicion no Existe|');
  except
    on e:Exception do
      AddPeticionJSON(folio, 'False|Excepcion: '+e.Message+'|');
  end;
end;

procedure Togcvdispensarios_hongyang.Desbloquear(folio: Integer; msj: string);
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
        for xpos:=1 to MaxPosiciones do begin
          TPosCarga[xpos].SwDesHabilitado:=False;
          if TPosCarga[xpos].ModoOpera='Normal' then
           EjecutaComando('AMP '+IntToClaveNum(xpos,2));
        end;
        AddPeticionJSON(folio, 'True|');
      end
      else if (xpos in [1..MaxPosiciones]) then begin
        TPosCarga[xpos].SwDesHabilitado:=False;
        if TPosCarga[xpos].ModoOpera='Normal' then
          EjecutaComando('AMP '+IntToClaveNum(xpos,2));
        AddPeticionJSON(folio, 'True|');
      end;
    end
    else AddPeticionJSON(folio, 'False|Posicion no Existe|');
  except
    on e:Exception do
      AddPeticionJSON(folio, 'False|Excepcion: '+e.Message+'|');
  end;
end;

procedure Togcvdispensarios_hongyang.GuardaLogComandos;
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
    on e:Exception do begin
      AgregaLog('Error GuardaLogComandos: '+e.Message);
      raise Exception.Create('Error GuardaLogComandos: '+e.Message); 
    end;
  end;
end;

function Togcvdispensarios_hongyang.Encrypt(data, key3DES: string): string;
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
      AgregaLog('Error Encrypt: '+e.Message);
      raise Exception.Create('Error Encrypt: '+e.Message);   
    end;
  end;
end;

function Togcvdispensarios_hongyang.Decrypt(data, key3DES: string): string;
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
      AgregaLog('Error Decrypt: '+e.Message);
      raise Exception.Create('Error Decrypt: '+e.Message);
    end;
  end;
end;

function Togcvdispensarios_hongyang.ReiniciarPuerto(forzado:Boolean):Boolean;
begin
  Result:=False;
  if (PosicionesLibres) or (forzado) then begin
    Timer1.Enabled:=False;
    horaReinicio:=Now;
    Detener(0);
    Sleep(200);
    if modoPreset then begin
      modoPreset:=False;
      Iniciar(0);
      modoPreset:=True;
    end
    else
      Iniciar(0);
    AgregaLog('SE REINICIO PUERTO');
    if forzado then begin
      GuardarLog(0);
      GuardarLogPetRes(0);
      GuardaLogComandos;
    end;
    Result:=True;
    Timer1.Enabled:=True;
  end
  else
    IncMinute(horaReinicio,1);
end;

// HELPER FUNCTIONS FOR JSON (From Wayne Driver)

procedure Togcvdispensarios_hongyang.ActualizaCampoJSON(xpos: Integer;
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

    //AgregaLog('DispenserId no encontrado en PosCarga.');
  except
    on e:Exception do begin
      AgregaLog('Error ActualizaCampoJSON: '+e.Message+'|');
      GuardarLog(0);
    end;
  end;
end;

procedure Togcvdispensarios_hongyang.AddPeticionJSON(const aFolio: Integer;
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

procedure Togcvdispensarios_hongyang.SetEstadoJSON(const AEstado: Integer);
var
  estadoNode: TlkJSONbase;
begin
  if rootJSON = nil then exit;
  
  estadoNode := rootJSON.Field['Estado'];

  if Assigned(estadoNode) then
    estadoNode.Value := AEstado
  else
    TlkJSONObject(rootJSON).Add('Estado', TlkJSONnumber.Generate(AEstado));
end;

procedure Togcvdispensarios_hongyang.ApplyTotalLitrosToJSON(
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

end.
