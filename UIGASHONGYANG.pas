unit UIGASHONGYANG;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, SvcMgr, Dialogs,
  ExtCtrls, OoMisc, AdPort, ScktComp, IniFiles, ULIBGRAL, uLkJSON, CRCs,
  Variants, IdHashMessageDigest, IdHash, ActiveX, ComObj;

type
  Togcvdispensarios_hongyang = class(TService)
    ServerSocket1: TServerSocket;
    pSerial: TApdComPort;
    Timer1: TTimer;
    procedure ServiceExecute(Sender: TService);
    procedure ServerSocket1ClientRead(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure pSerialTriggerAvail(CP: TObject; Count: Word);
    procedure Timer1Timer(Sender: TObject);
  private
    ContadorAlarma:integer;
    SegundosFinv:Integer;
    MaxPosiciones:integer;
    FinLinea:boolean;
    LineaBuff,
    LineaProc:string;
    SwAplicaCmnd:Boolean;
    NumPaso:Integer;
  public
    ListaLog:TStringList;
    ListaLogPetRes:TStringList;
    rutaLog:string;
    licencia:string;
    detenido:Boolean;
    estado:Integer;
    ListaCmnd    :TStrings;
    confPos:string;
    FolioCmnd   :integer;
    function GetServiceController: TServiceController; override;
    procedure AgregaLogPetRes(lin: string);
    function CRC16(Data: AnsiString): AnsiString;
    procedure Responder(socket:TCustomWinSocket;resp:string);
    procedure AgregaLog(lin:string);
    function IniciaPSerial(datosPuerto:string):string;
    function Inicializar(json:string): string;
    function AgregaPosCarga(posiciones: TlkJSONbase):string;
    function Login(mensaje:string): string;
    function Logout: string;
    function GuardarLogPetRes: string;
    function FechaHoraExtToStr(FechaHora:TDateTime):String;
    function MD5(const usuario: string): string;
    function ConvierteBCD(xvalor:real;xlong:integer):string;
    function CalculaBCC(ss:string):char;
    function StrToHexSep(ss:string):string;
    function  IniciaPrecios(msj:string):string;
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
    function AutorizarVenta(msj:string): string;
    function ActivaModoPrepago(msj:string): string;
    function DesactivaModoPrepago(msj:string): string;
    function FinVenta(msj:string): string;
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
   function TransaccionPosCarga(msj:string): string;
   function EstadoPosiciones(msj: string):string;
   function Detener: string;
   function Iniciar: string;
   function Shutdown:string;
   function Terminar:string;
   function ObtenerEstado: string;
   function GuardarLog: string;
   function RespuestaComando(msj:string): string;
   function ObtenerLog(r:Integer): string;
   function ObtenerLogPetRes(r:Integer): string;
   function ResultadoComando(xFolio:integer):string;
   function TotalesBomba(msj: string): string;
   procedure IniciarPrecios;
   function Bloquear(msj:string): string;
   function Desbloquear(msj:string): string;
  end;

type
     TipoPosCarga = record
       posactual    :integer;
       posactual2   :integer;
       PosManguera  :array [1..3] of integer;
       PosEstatus   :array [1..3] of integer;
       TotalLitros:array[1..3] of real;
       SwDesHabilitado :Boolean;
       ModoOpera    :String;
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

var
  ogcvdispensarios_hongyang: Togcvdispensarios_hongyang;
  TPosCarga :array[1..32] of tipoposcarga;
  TMangueras:array[1..100] of tipomanguera;
  TabCmnd  :array[1..40] of RegCmnd;
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
  TimeCmnd,
  TimeResp        :TDateTime;  // Momento de envio de comando, es para medir la espera
  LinCmndHJ,
  LinCmnd         :string;
  CharCmnd        :char;
  MangCmnd        :integer;
  TotalTramas,
  TotalErrores    :LongInt;
  TColaCmnd       :array[1..50] of string[50];
  ApCola          :integer;
  LinEstadoGen :string;
  key:OleVariant;
  claveCre,key3DES:string;

implementation

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
  lic:string;
begin
  try
    config:= TIniFile.Create(ExtractFilePath(ParamStr(0)) +'PDISPENSARIOS.ini');
    rutaLog:=config.ReadString('CONF','RutaLog','C:\ImagenCo');
    ServerSocket1.Port:=config.ReadInteger('CONF','Puerto',8585);
    confPos:=config.ReadString('CONF','ConfPos','');
    licencia:=config.ReadString('CONF','Licencia','');
    ContadorAlarma:=0;
    ListaCmnd:=TStringList.Create;
    ServerSocket1.Active:=True;
    detenido:=True;
    estado:=-1;
    SegundosFinv:=30;
    ListaLog:=TStringList.Create;
    ListaLogPetRes:=TStringList.Create;

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
    FreeAndNil(Key);
  except
    on e:exception do begin
      ListaLog.Add('Error al iniciar servicio: '+e.Message);
      ListaLog.SaveToFile(rutaLog+'\LogDispPetRes'+FiltraStrNum(FechaHoraToStr(Now))+'.txt');
    end;
  end;
end;

procedure Togcvdispensarios_hongyang.ServerSocket1ClientRead(
  Sender: TObject; Socket: TCustomWinSocket);
  var
    mensaje,comando,checksum,parametro:string;
    i:Integer;
    chks_valido:Boolean;
begin
  try
    mensaje:=Key.Decrypt(ExtractFilePath(ParamStr(0)),key3DES,Socket.ReceiveText);
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

      if comando='NOTHING' then
        Responder(Socket,'DISPENSERS|NOTHING|True|')
      else if comando='INITIALIZE' then
        Responder(Socket,'DISPENSERS|INITIALIZE|'+Inicializar(parametro))
      else if comando='LOGIN' then
        Responder(Socket,'DISPENSERS|LOGIN|'+Login(parametro))
      else if comando='LOGOUT' then
        Responder(Socket,'DISPENSERS|LOGOUT|'+Logout)
      else if comando='PRICES' then
        Responder(Socket,'DISPENSERS|PRICES|'+IniciaPrecios(parametro))
      else if comando='AUTHORIZE' then
        Responder(Socket,'DISPENSERS|AUTHORIZE|'+AutorizarVenta(parametro))
      else if comando='SELFSERVICE' then
        Responder(Socket,'DISPENSERS|SELFSERVICE|'+ActivaModoPrepago(parametro))
      else if comando='FULLSERVICE' then
        Responder(Socket,'DISPENSERS|FULLSERVICE|'+DesactivaModoPrepago(parametro))
      else if comando='PAYMENT' then
        Responder(Socket,'DISPENSERS|PAYMENT|'+FinVenta(parametro))
      else if comando='TRANSACTION' then
        Responder(Socket,'DISPENSERS|TRANSACTION|'+TransaccionPosCarga(parametro))
      else if comando='STATUS' then
        Responder(Socket,'DISPENSERS|STATUS|'+EstadoPosiciones(parametro))
      else if comando='TOTALS' then
        Responder(Socket,'DISPENSERS|TOTALS|'+TotalesBomba(parametro))
      else if comando='HALT' then
        Responder(Socket,'DISPENSERS|HALT|'+Detener)
      else if comando='RUN' then
        Responder(Socket,'DISPENSERS|RUN|'+Iniciar)
      else if comando='SHUTDOWN' then
        Responder(Socket,'DISPENSERS|SHUTDOWN|'+Shutdown)
      else if comando='TERMINATE' then
        Responder(Socket,'DISPENSERS|TERMINATE|'+Terminar)
      else if comando='STATE' then
        Responder(Socket,'DISPENSERS|STATE|'+ObtenerEstado)
      else if comando='TRACE' then
        Responder(Socket,'DISPENSERS|TRACE|'+GuardarLog)
      else if comando='SAVELOGREQ' then
        Responder(Socket,'DISPENSERS|SAVELOGREQ|'+GuardarLogPetRes)
      else if comando='RESPCMND' then
        Responder(Socket,'DISPENSERS|RESPCMND|'+RespuestaComando(parametro))
      else if comando='LOG' then
        Socket.SendText(Key.Encrypt(ExtractFilePath(ParamStr(0)),key3DES,'DISPENSERS|LOG|'+ObtenerLog(StrToIntDef(parametro,0))))
      else if comando='LOGREQ' then
        Socket.SendText(Key.Encrypt(ExtractFilePath(ParamStr(0)),key3DES,'DISPENSERS|LOGREQ|'+ObtenerLogPetRes(StrToIntDef(parametro,0))))
      else if comando='PAYMENT' then
        Responder(Socket,'DISPENSERS|PAYMENT|'+FinVenta(parametro))
      else if comando='BLOCK' then
        Responder(Socket,'DISPENSERS|BLOCK|'+Bloquear(parametro))
      else if comando='UNBLOCK' then
        Responder(Socket,'DISPENSERS|UNBLOCK|'+Desbloquear(parametro))
      else
        Responder(Socket,'DISPENSERS|'+comando+'|False|Comando desconocido|');
    end
    else
      Responder(Socket,'DISPENSERS|'+mensaje+'|False|Comando desconocido|');
  except
    on e:Exception do begin
      if (claveCre<>'') and (key3DES<>'') then
        AgregaLogPetRes('Error: '+e.Message+'//Clave CRE: '+claveCre+'//Terminacion de Key 3DES: '+copy(key3DES,Length(key3DES)-3,4))
      else
        AgregaLogPetRes('Error: '+e.Message);
      GuardarLogPetRes;
      Responder(Socket,'DISPENSERS|'+comando+'|False|'+e.Message+'|');
    end;
  end;
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
end;

procedure Togcvdispensarios_hongyang.Responder(socket: TCustomWinSocket;
  resp: string);
begin
  socket.SendText(Key.Encrypt(ExtractFilePath(ParamStr(0)),key3DES,#1#2+resp+#3+CRC16(resp)+#23));
  AgregaLogPetRes('E '+#1#2+resp+#3+CRC16(resp)+#23);
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

function Togcvdispensarios_hongyang.Inicializar(json: string): string;
var
  js: TlkJSONBase;
  consolas,dispensarios,productos: TlkJSONbase;
  i,productID: Integer;
  datosPuerto:string;
begin
  try
    if estado>-1 then begin
      Result:='False|El servicio ya habia sido inicializado|';
      Exit;
    end;

    js := TlkJSON.ParseText(ExtraeElemStrSep(json,1,'|'));
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

    for i:=0 to productos.Count-1 do begin
      productID:=productos.Child[i].Field['ProductId'].Value;
      if productos.Child[i].Field['Price'].Value<0 then begin
        Result:='False|El precio '+IntToStr(productID)+' es incorrecto|';
        Exit;
      end;
      LPrecios[productID]:=productos.Child[i].Field['Price'].Value;    
    end;
    PreciosInicio:=true;
    estado:=0;
    Result:='True|';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_hongyang.AgregaPosCarga(
  posiciones: TlkJSONbase): string;
var i,xpos,j,
    xcomb,xpcomb,
    xaddr,xlado,xmang:integer;
    cPos,cMang:string;
    mangueras:TlkJSONbase;
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
      SwPrepagoM:=false;
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
      SwCargaTotales:=true;
      SwActivo:=false;
      tipopago:=0;
      finventa:=0;
      boucher:='';
      contbrinca:=0;
      contparo:=0;
    end;

    for i:=0 to posiciones.Count-1 do begin
      xpos:=posiciones.Child[i].Field['DispenserId'].Value;
      if xpos>MaxPosiciones then
        MaxPosiciones:=xpos;
      mangueras:=posiciones.Child[i].Field['Hoses'];
      if UpperCase(VarToStr(posiciones.Child[i].Field['OperationMode'].Value))='FULLSERVICE' then
        TPosCarga[xpos].ModoOpera:='Normal'
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
        if xpcomb in [1..3] then
          TPosCarga[xpos].posmanguera[xpcomb]:=xmang;
        if (xmang>MaxMangueras)and(xpos<=32) then
          MaxMangueras:=xmang;
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
            ModoOpera:='Normal'
          else
            ModoOpera:='Prepago';
          SwPrepagoM:= (ModoOpera='Prepago');
        end;
      end;
    end;
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';  
  end;
end;

function Togcvdispensarios_hongyang.Login(mensaje: string): string;
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

function Togcvdispensarios_hongyang.Logout: string;
begin
  Token:='';
  Result:='True|';
end;

function Togcvdispensarios_hongyang.GuardarLogPetRes: string;
begin
  try
    ListaLogPetRes.SaveToFile(rutaLog+'\LogDispPetRes'+FiltraStrNum(FechaHoraToStr(Now))+'.txt');
    Result:='True|';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
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
  idmd5 := TIdHashMessageDigest5.Create;
  hash := idmd5.HashValue(usuario);
  Result := idmd5.AsHex(hash);
  Result := AnsiLowerCase(Result);
end;

function Togcvdispensarios_hongyang.ConvierteBCD(xvalor: real;
  xlong: integer): string;
var xstr,xres,ss,xaux:string;
    i,nc,nn,num:integer;
begin
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
end;

function Togcvdispensarios_hongyang.CalculaBCC(ss: string): char;
var i,n,m:integer;
begin
  n:=0;
  for i:=1 to length(ss) do
    n:=n+ord(ss[i]);
  m:=(n)mod(256);
  result:=char(256-m);
end;

function Togcvdispensarios_hongyang.StrToHexSep(ss: string): string;
var i:integer;
    xaux:string;
begin
  xaux:=inttohex(ord(ss[1]),2);
  for i:=2 to length(ss) do
    xaux:=xaux+' '+inttohex(ord(ss[i]),2);
  result:=xaux;
end;

function Togcvdispensarios_hongyang.IniciaPrecios(msj: string): string;
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
    Result:='True|';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
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
(*
25/Sep/2019 06:41:35.794 E 01 06 01 15 00 00 E3  >>C01
25/Sep/2019 06:41:36.216 E 02 06 01 15 00 00 E2  >>C02
25/Sep/2019 06:41:36.638 E 03 06 01 15 00 00 E1  >>C03
25/Sep/2019 06:41:37.062 E 01 06 02 15 00 00 E2  >>C04
25/Sep/2019 06:41:37.484 E 02 06 02 15 00 00 E1  >>C05
25/Sep/2019 06:41:37.905 E 03 06 02 15 00 00 E0  >>C06
*)
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
    //Timer1.Enabled:=false;
    try
      try
        s1:=copy(LinCmndHJ,1,1);
        s2:=copy(LinCmndHJ,2,length(LinCmndHJ)-1);
        try
          pSerial.Parity:=pNone;
          pSerial.Parity:=pMark;
        except
        end;
        pSerial.RTS:=false;
        if pSerial.Open then
          pSerial.Output:=s1;
        try
          pSerial.Parity:=pNone;
          pSerial.Parity:=pSpace;
        except
        end;
        if pSerial.Open then
          pSerial.OutPut:=s2;
        try
          pSerial.Parity:=pSpace;
        except
        end;
        AgregaLog('E '+StrToHexSep(LinCmndHJ)+'  >>'+ss);
      except
      end;
    finally
      Timer1.Enabled:=true;
    end;
  end;
end;

function Togcvdispensarios_hongyang.EjecutaComando(xCmnd: string): integer;
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
  until (not TabCmnd[ind].SwActivo)or(ind>40);
  // Si no lo encuentra se sale
  if ind>40 then begin
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
end;

function Togcvdispensarios_hongyang.AutorizarVenta(msj: string): string;
var
  cmd,cantidad,posCarga,comb,finv:string;
begin
  try
    if StrToFloatDef(ExtraeElemStrSep(msj,3,'|'),0)>0 then begin
      cmd:='OCC';
      cantidad:=ExtraeElemStrSep(msj,3,'|');
    end
    else if StrToFloatDef(ExtraeElemStrSep(msj,4,'|'),0)>0 then begin
      cmd:='OCL';
      cantidad:=ExtraeElemStrSep(msj,4,'|');
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

function Togcvdispensarios_hongyang.ActivaModoPrepago(msj: string): string;
var
  xpos:Integer;
begin
  try
    xpos:=StrToIntDef(msj,-1);
    Result:='True|'+IntToStr(EjecutaComando('AMP '+IntToClaveNum(xpos,2)))+'|';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_hongyang.DesactivaModoPrepago(
  msj: string): string;
var
  xpos:Integer;
begin
  try
    xpos:=StrToIntDef(msj,-1);
    Result:='True|'+IntToStr(EjecutaComando('DMP '+IntToClaveNum(xpos,2)))+'|';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_hongyang.FinVenta(msj: string): string;
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

procedure Togcvdispensarios_hongyang.ProcesoComandoA(xResp: string);
// Receiver  0C  03  * 64 17 00  * 00 00 00 * 07 13 00 5C
//                IMPORTE=0013.07          LITROS=0017.64
//           0C  12    00 40 00    00 00 00   92 01 00 0F
var ss:string;
    ee,xp,ne:integer;
begin
  with TMangueras[MangCmnd] do begin
    ss:=StrToHexSep(xResp);
    ne:=NoElemStrSep(ss,' ');
    ee:=DameEstatus(ss,SwEnllavado,SwErrorCmnd);
    if SwErrorCmnd then
      exit;
    if ne<9 then
      exit;
    try
      if PreciosInicio then
        IniciarPrecios;
      estatusant:=estatus;
      importeant:=importe;
      volumenant:=volumen;
      importe:=ExtraeBCD(ss,3,5);
      volumen:=ExtraeBCD(ss,9,11);
      if preciofisico>0 then
        precio:=preciofisico
      else
        precio:=ajustafloat(dividefloat(importe,volumen),2);
      if precio>0.01 then
        precioant:=precio;
      estatus:=ee;
      if (estatusant=0)and(estatus<>0) then begin
        SwCargaTotales:=true;
        ActualizarPrecio:=true;
      end;
      if (estatus=1)and(finventa=1)and(swfinventa) then begin
        if not SwVentaValidada then begin
          estatus:=8;
          if estatusant=5 then
            HoraFV:=Now;
          AgregaLog('>>Estatus 8 en Manguera '+inttostr(MangCmnd));
        end
        else
          estatus:=7;
      end;
      if (estatus in [7,8])and((now-HoraFV)>10*tmsegundo) then begin
        estatus:=1;
        swfinventa:=false;
      end;
      case estatus of
        1:begin  // Inactivo
            descestat:='Inactivo';
            SwPreset:=false;
            Swfinventa:=false;
            ContInicDesp:=0;
            if EstatusAnt<>1 then begin
              FinVenta:=0;
            end
            else if importe<>importeant then begin
              importe:=importeant;
              volumen:=volumenant;
              if preciofisico>0 then
                precio:=preciofisico
              else
                precio:=ajustafloat(dividefloat(importe,volumen),2);
              if (swprepagom)and(not swenllavado) then
                MeteACola('C'+inttoclavenum(MangCmnd,2));
            end;
          end;
        2:descestat:='Autorizado';
        3:descestat:='Pistola Levantada';
        5:begin                // Despachando
            descestat:='Despachando';
            swcargando:=true;
            swfinventa:=true;
            ContTotErr:=0;
            SwVentaValidada:=false;
            if (SwPrepagoM)and(Importe<=0.001) then
              descestat:='Autorizado';
            Inc(ContInicDesp);
          end;
        7,8:descestat:='Fin de Venta';
        9:descestat:='Enllavado';
      end;
      if (Estatus in [1,8])and(swcargando) then begin
        swcargando:=false;
        swdesptot:=true;
        SwCargaTotales:=true;
      end;
      if poscomb in [1..3] then with TPosCarga[PosCarga] do begin
        PosEstatus[poscomb]:=estatus;
        if estatus in [5,7] then
          posactual2:=poscomb;
        posactual:=1;
        for xp:=2 to 3 do
          if posestatus[xp]>posestatus[posactual] then
            posactual:=xp;
      end;
    except
      on e:Exception do
        AgregaLog('ProcesoComandoA: '+e.Message);
    end;
  end;
end;

function Togcvdispensarios_hongyang.DameEstatus(xstr: string; var swlocked,
  swerror: boolean): integer;
//  [5] Motor encendido
//  [2] Pistola levantada

{

8   CAMBIO DE PRECIO
7   CAMBIO IMPORTE
6   CAMBIO TOTALES
5   MOTOR ON
4   BLOQUEADO
3   ESTATUS ERROR
2   PISTOLA LEVANTADA NO USADO

FIN DE VENTA
46 - 06 - 02
4A - 06 - 02
46 - 12 - 52 - 02
12  0001 0010   inactivo enllavado
02  0000 0010   inactivo desenllavado
4A  0100 1010   despachando
06  0000 0110   fin venta PISTOLA COLGADA
16  0001 0110   fin venta PISTOLA COLGADA
0A  0000 1010   despachando
1A  0001 1010   despachando
0E  0000 1110   despachando
46  0100 0110   FIN VENTA PISTOLA LEVANTADA
52  0101 0010
4E  0100 1110}
var xst,ss:string;
    ee:integer;
begin
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

  if (ss='06')or(ss='16')or(ss='46') then      // fin venta
    ee:=1
  else if (ss='02')or(ss='12') then            // inativo
    ee:=1
  else if (ss='4A')or(ss='0A')or(ss='0E')or(ss='1A') then  // despachando
    ee:=5;

  SwLocked:=false;
  if (ss='12')or(ss='16')or(ss='1A')or(ss='52') then  // enllavado
    swlocked:=true;

  result:=ee;
end;

function Togcvdispensarios_hongyang.ExtraeBCD(xstr: string; xini,
  xfin: integer): real;
var i:integer;
    ss:string;
begin
  i:=xfin;
  ss:='';
  while i>=xini do begin
    ss:=ss+ExtraeElemStrSep(xstr,i,' ');
    dec(i);
  end;
  result:=strtoint(ss)/100;
end;

procedure Togcvdispensarios_hongyang.MeteACola(xstr: string);
begin
  if ApCola<50 then begin
    inc(ApCola);
    TColaCmnd[ApCola]:=xstr;
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
  result:=ConvierteBin(ss[1])+ConvierteBin(ss[2]);
end;

procedure Togcvdispensarios_hongyang.ProcesoComandoC(xResp: string);
// Receiver  03  07 F6
var ss:string;
    swerr:boolean;
begin
  with TMangueras[MangCmnd] do begin
    ss:=StrToHexSep(xResp);
    DameEstatus(ss,SwEnllavado,SwErr);
    if not SwErr then begin
      //ActualizarPrecio:=false;
      //LeerPrecio:=true;
    end;
  end;
end;

procedure Togcvdispensarios_hongyang.ProcesoComandoD(xResp: string);
// Receiver  03  07 F6
var ss:string;
    swerr:boolean;
begin
  with TMangueras[MangCmnd] do begin
    ss:=StrToHexSep(xResp);
    DameEstatus(ss,SwEnllavado,SwErr);
    if not SwErr then begin
      //ActualizarPrecio:=false;
      //LeerPrecio:=true;
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
          if PosComb in [1..4] then
            TPosCarga[xpos].TotalLitros[PosComb]:=totallitros;
      SwCargaTotales:=false;
      if swdesptot then begin
        diflitrostot:=abs(totallitros-totallitrosant);
        if diflitrostot>0.01 then begin // hay venta
          if (abs(diflitrostot-volumen)>0.05)and(ContTotErr<2) then
            AgregaLog('Diferencia Volumen Manguera '+inttostr(MangCmnd)+'  litros: '+FormatoNumero(abs(diflitrostot-volumen),5,2));
          swdesp:=true;
          HoraFV:=Now;
          if TMangueras[MangCmnd].SwPrepagoM then begin
            MeteACola('C'+inttoclavenum(MangCmnd,2));
          end;
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
      AgregaLog('Error BCD: '+xresp);
    end;
  end;
end;

procedure Togcvdispensarios_hongyang.ProcesoComandoU(xResp: string);
// Receiver  03  07 F6
var ss:string;
    swerr:boolean;
begin
  with TMangueras[MangCmnd] do begin
    ss:=StrToHexSep(xResp);
    DameEstatus(ss,SwEnllavado,SwErr);
    if not SwErr then begin
      ActualizarPrecio:=false;
      LeerPrecio:=true;
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
      AgregaLog('Error BCD: '+xresp);
    end;
  end;
end;

procedure Togcvdispensarios_hongyang.ProcesoComandoS(xResp: string);
// Receiver  03  07 F6
var ss:string;
    swerr:boolean;
begin
  with TMangueras[MangCmnd] do begin
    ss:=StrToHexSep(xResp);
    DameEstatus(ss,SwEnllavado,SwErr);
    if not SwErr then begin
      SwPreset:=true;
      SwPresetImp:=true;
    end;
  end;
end;

procedure Togcvdispensarios_hongyang.ProcesoComandoL(xResp: string);
// Receiver  03  07 F6
var ss:string;
    swerr:boolean;
begin
  with TMangueras[MangCmnd] do begin
    ss:=StrToHexSep(xResp);
    DameEstatus(ss,SwEnllavado,SwErr);
    if not SwErr then begin
      SwPreset:=true;
      SwPresetImp:=false;
    end;
  end;
end;

procedure Togcvdispensarios_hongyang.ProcesaLineaRec(LineaRsp: string);
var xstr,xstr2,xdv,xdv2:string;
begin
  try
    FinLinea:=false;  LineaProc:='';
    SwEsperaCmnd:=false;
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
            ProcesoComandoA(LineaRsp);
      'C':if length(LineaRsp)=3 then
            ProcesoComandoC(LineaRsp);
      'D':if length(LineaRsp)=3 then
            ProcesoComandoD(LineaRsp);
      'N':if length(LineaRsp)=21 then
            ProcesoComandoN(LineaRsp);
      'U':if length(LineaRsp)=3 then
            ProcesoComandoU(LineaRsp);
      'V':if length(LineaRsp)=7 then
            ProcesoComandoV(LineaRsp);
      'S':if length(LineaRsp)=3 then
            ProcesoComandoS(LineaRsp);
      'L':if length(LineaRsp)=3 then
            ProcesoComandoL(LineaRsp);
    end;
  except
  end;
end;

procedure Togcvdispensarios_hongyang.pSerialTriggerAvail(CP: TObject;
  Count: Word);
var I:Word;
    C:Char;
    xlong:integer;
begin
  ContadorAlarma:=0;
  //Timer1.Enabled:=false;
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
end;

procedure Togcvdispensarios_hongyang.PublicaEstatusDispensarios;
var xpos,xmang:integer;
    lin,xestado,
    xmodo,ss        :string;
begin
  try
    lin:='';xestado:='';xmodo:='';
    for xpos:=1 to MaxPosiciones do with TPosCarga[xpos] do begin
      xmang:=PosManguera[PosActual2];
      with TMangueras[xmang] do begin
        xmodo:=xmodo+ModoOpera[1];
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
        ss:=inttoclavenum(xpos,2)+'/'+inttostr(combustible);
        ss:=ss+'/'+FormatFloat('###0.##',volumen);
        ss:=ss+'/'+FormatFloat('#0.##',precio);
        ss:=ss+'/'+FormatFloat('####0.##',importe);
        lin:=lin+'#'+ss;
      end;
    end;
    if lin='' then
      lin:=xestado+'#'
    else
      lin:=xestado+lin;
    lin:=lin+'&'+xmodo;
    LinEstadoGen:=xestado;
  except
  end;
end;

procedure Togcvdispensarios_hongyang.SacaDeCola(var xstr: string);
var i:integer;
begin
  xstr:='';
  if ApCola>0 then begin
    xstr:=TColaCmnd[1];
    dec(ApCola);
    if ApCola>0 then
      for i:=1 to ApCola do
        TColaCmnd[i]:=TColaCmnd[i+1];
  end;
end;

procedure Togcvdispensarios_hongyang.Timer1Timer(Sender: TObject);
label uno;
var xmang:integer;
    swestatus7:boolean;
    xcmnd:string;
begin
  try
    // ENVIO DE COMANDOS
    if not SwEsperaCmnd then begin
      SwReintentoCmnd:=false;
      uno:
      Case CmndProc of
        // LEE DISPLAY Y STATUS
        'A':begin
              if MangCiclo<=MaxMangueras then with TMangueras[MangCiclo] do begin
                if ContParo<=0 then begin
                  if (ContBrinca<=0)or(Estatus<>1)or(SwPreset) then begin
                    if Estatus=1 then
                      ContBrinca:=4;
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
                if (SwCargaTotales)and(estatus>0) then begin
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
      if ((Now-TimeResp)>TmSegundo*0.15)and(LineaProc<>'') then begin
        SwEsperaCmnd:=false;
        ProcesaLineaRec(LineaProc);
      end
      else if ((Now-TimeCmnd)>TmSegundo) then begin
        SwEsperaCmnd:=false;
        with TMangueras[MangCmnd] do begin
          estatus:=0;
          descestat:='Sin Comunicacion';
          contparo:=5;
        end;
      end;
    end;
   except
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
    for xcmnd:=1 to 40 do if (TabCmnd[xcmnd].SwActivo)and(not TabCmnd[xcmnd].SwResp) then begin
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
                  TMangueras[i].ModoOpera:='Normal';
                //end;
              end;
            end;
          end
          else begin
            for i:=1 to MaxMangueras do begin
              if (TMangueras[i].PosCarga=xpos) then begin
                MeteACola('D'+inttoclavenum(i,2));
                TMangueras[i].SwPrepagoM:=false;
                TMangueras[i].ModoOpera:='Normal';
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
            if (TMangueras[i].PosCarga=xpos)and(TMangueras[i].Combustible=xcomb) then
              xmang:=i;
          end;
          if (xmang in [1..MaxMangueras]) then begin
            if (TMangueras[xmang].estatus in [1,3])then begin
              try
                xImporte:=StrToFLoat(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,3,' '));
                rsp:=ValidaCifra(xImporte,4,2);
                if rsp='OK' then
                  if (xImporte<1) then
                    rsp:='Importe minimo permitido: $1.00';
              except
                xImporte:=0;
                rsp:='Error en Importe';
              end;
              if rsp='OK' then begin
                TMangueras[xmang].tipopago:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,5,' '),0);
                TMangueras[xmang].finventa:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,6,' '),0);
                TMangueras[xmang].boucher:=ExtraeElemStrSep(TabCmnd[xcmnd].Comando,7,' ');
                TMangueras[xmang].impopreset:=ximporte;
                ximp:=Trunc(xImporte*100+0.5);

                if TMangueras[xmang].SwPrepagoM then begin
                  //MeteACola('D'+inttoclavenum(xmang,2));
                end;

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
            if (TMangueras[i].PosCarga=xpos)and(TMangueras[i].Combustible=xcomb) then
              xmang:=i;
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
                TMangueras[xmang].tipopago:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,5,' '),0);
                TMangueras[xmang].finventa:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,6,' '),0);
                TMangueras[xmang].boucher:=ExtraeElemStrSep(TabCmnd[xcmnd].Comando,7,' ');
                TMangueras[xmang].litrospreset:=xlitros;
                ximp:=Trunc(xLitros*100+0.5);

                if TMangueras[xmang].SwPrepagoM then begin
                  //MeteACola('D'+inttoclavenum(xmang,2));
                end;

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
              rsp:='OK'+FormatFloat('0.000',ToTalLitros[1])+'|'+FormatoMoneda(ToTalLitros[1]*LPrecios[1])+'|'+
                              FormatFloat('0.000',ToTalLitros[2])+'|'+FormatoMoneda(ToTalLitros[2]*LPrecios[2])+'|'+
                              FormatFloat('0.000',ToTalLitros[3])+'|'+FormatoMoneda(ToTalLitros[3]*LPrecios[3])+'|';
              SwAplicaCmnd:=True;
            end;
          end;
        end;
      end
      else if ss='FINV' then
        rsp:='OK'
      else rsp:='Comando no Soportado o no Existe';
      if SwAplicaCmnd then begin
        TabCmnd[xcmnd].SwResp:=true;
        TabCmnd[xcmnd].Respuesta:=rsp;
        AgregaLog(LlenaStr(TabCmnd[xcmnd].Comando,'I',40,' ')+' Respuesta: '+TabCmnd[xcmnd].Respuesta);
      end;
      if SwSalir then exit;
    end;
  except
  end;
end;

function Togcvdispensarios_hongyang.ValidaCifra(xvalor: real; xenteros,
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

function Togcvdispensarios_hongyang.TransaccionPosCarga(
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

    if xpos>MaxPosiciones then begin
      Result:='False|La posicion de carga no se encuentra registrada|';
      Exit;
    end;

    with TPosCarga[xpos] do with TMangueras[PosManguera[PosActual2]] do
      Result:='True|'+FormatDateTime('yyyy-mm-dd',HoraFv)+'T'+FormatDateTime('hh:nn',HoraFv)+'|'+IntToStr(PosManguera[PosActual2])+'|'+IntToStr(Combustible)+'|'+
              FormatFloat('0.000',volumen)+'|'+FormatFloat('0.00',precio)+'|'+FormatFloat('0.00',importe)+'|';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_hongyang.EstadoPosiciones(msj: string): string;
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

function Togcvdispensarios_hongyang.Detener: string;
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

function Togcvdispensarios_hongyang.Iniciar: string;
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
    CmndProc:='A';
    Timer1.Enabled:=True;
    numPaso:=0;

    Result:='True|';
  except
    on e:Exception do
      Result:='False|'+e.Message+'|';
  end;
end;

function Togcvdispensarios_hongyang.Shutdown: string;
begin
  if estado>0 then
    Result:='False|El servicio esta en proceso, no fue posible detenerlo|'
  else begin
    ServiceThread.Terminate;
    Result:='True|';
  end;
end;

function Togcvdispensarios_hongyang.Terminar: string;
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

function Togcvdispensarios_hongyang.ObtenerEstado: string;
begin
  Result:='True|'+IntToStr(estado)+'|';
end;

function Togcvdispensarios_hongyang.GuardarLog: string;
begin
  try
    ListaLog.SaveToFile(rutaLog+'\LogDisp'+FiltraStrNum(FechaHoraToStr(Now))+'.txt');
    Result:='True|'+rutaLog+'\LogDisp'+FiltraStrNum(FechaHoraToStr(Now))+'.txt';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_hongyang.RespuestaComando(msj: string): string;
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
        resp:=copy(resp,3,Length(resp)-2)+'|'
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

function Togcvdispensarios_hongyang.ObtenerLog(r: Integer): string;
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

function Togcvdispensarios_hongyang.ObtenerLogPetRes(r: Integer): string;
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

function Togcvdispensarios_hongyang.ResultadoComando(
  xFolio: integer): string;
var i:integer;
begin
  Result:='*';
  for i:=1 to 40 do
    if (TabCmnd[i].folio=xfolio)and(TabCmnd[i].SwResp) then
      result:=TabCmnd[i].Respuesta;
end;

function Togcvdispensarios_hongyang.TotalesBomba(msj: string): string;
var
  xpos:Integer;
begin
  try
    xpos:=StrToIntDef(msj,-1);
    if xpos<1 then begin
      Result:='False|Favor de indicar correctamente la posicion de carga|';
      Exit;
    end;

    Result:='True|0|0|0|0|0|0|'+IntToStr(EjecutaComando('TOTAL'+' '+IntToStr(xpos)))+'|';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
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
    on e:Exception do
      AgregaLog('Excepcion: '+e.Message);
  end;
end;

function Togcvdispensarios_hongyang.Bloquear(msj: string): string;
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
        if not ContieneChar(LinEstadoGen,'2') then begin
          for xpos:=1 to MaxPosiciones do begin
            TPosCarga[xpos].SwDesHabilitado:=True;
            if TPosCarga[xpos].ModoOpera='Normal' then
              EjecutaComando('AMP '+IntToClaveNum(xpos,2));
          end;
          Result:='True|';       
        end
        else
          Result:='False|Existen dispensarios cargando combustible|';
      end
      else if (xpos in [1..MaxPosiciones]) then begin
        if LinEstadoGen[xpos]<>'2' then begin
          TPosCarga[xpos].SwDesHabilitado:=True;
          if TPosCarga[xpos].ModoOpera='Normal' then
            EjecutaComando('AMP '+IntToClaveNum(xpos,2));
          Result:='True|';
        end
        else
          Result:='False|El dispensario esta cargando combustible|';
      end;
    end
    else Result:='False|Posicion no Existe|';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_hongyang.Desbloquear(msj: string): string;
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
        for xpos:=1 to MaxPosiciones do begin
          TPosCarga[xpos].SwDesHabilitado:=False;
          if TPosCarga[xpos].ModoOpera='Normal' then
           EjecutaComando('DMP '+IntToClaveNum(xpos,2));
        end;
        Result:='True|';
      end
      else if (xpos in [1..MaxPosiciones]) then begin
        TPosCarga[xpos].SwDesHabilitado:=False;
        if TPosCarga[xpos].ModoOpera='Normal' then
          EjecutaComando('DMP '+IntToClaveNum(xpos,2));
        Result:='True|';
      end;
    end
    else Result:='False|Posicion no Existe|';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

end.
