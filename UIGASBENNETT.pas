unit UIGASBENNETT;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, SvcMgr, Dialogs,
  ScktComp, IniFiles, ULIBGRAL, OoMisc, AdPort, DB, RxMemDS, Variants,
  ExtCtrls, uLkJSON, CRCs, IdHashMessageDigest, IdHash, ActiveX, ComObj,
  LbCipher, LbString;

  const
    MCxP=4;

type
  Togcvdispensarios_bennett = class(TService)
    ServerSocket1: TServerSocket;
    pSerial: TApdComPort;
    Timer1: TTimer;
    procedure ServiceExecute(Sender: TService);
    procedure ServerSocket1ClientRead(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure pSerialTriggerAvail(CP: TObject; Count: Word);
    procedure Timer1Timer(Sender: TObject);
  private
    { Private declarations }
    ContadorAlarma:integer;
    LineaBuff,
    LineaTimer,
    Linea:string;
    SwBcc,
    SwEspera,
    swcierrabd,
    FinLinea:boolean;
    ContEspera,
    ContEsperaPaso2,
    ContEsperaPaso3,
    NumPaso,
    PosicionActual:integer;
    SoportaSeleccionProducto,
    Bennett8Digitos:string;
    BennetReintentosPreset:Integer;
    UltimoStatus:string;
    SnPosCarga:integer;
    SnImporte,SnLitros:real;
    MaxPosCarga:integer;
    MaxPosCargaActiva:integer;
    SegundosFinv:Integer;
    MapCombs:string;
  public
    ListaLog:TStringList;
    ListaLogPetRes:TStringList;
    ListaComandos:TStringList;
    rutaLog:string;
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
    horaLog:TDateTime;
    minutosLog:Integer;
    version:String;
    function GetServiceController: TServiceController; override;
    procedure AgregaLog(lin:string);
    procedure AgregaLogPetRes(lin: string);
    function  IniciaPrecios(msj:string):string;
    function AgregaPosCarga(posiciones: TlkJSONbase):string;
    procedure Responder(socket:TCustomWinSocket;resp:string);
    function FechaHoraExtToStr(FechaHora:TDateTime):String;
    procedure ComandoConsola(ss:string);
    procedure ComandoConsolaBuff(ss:string;swinicio:boolean);
    procedure IniciarPrecios;
    function CalculaBCC(ss:string):char;
    function CRC16(Data: AnsiString): AnsiString;
    function MD5(const usuario: string): string;    
    procedure ProcesaLinea;
    procedure EnviaPreset(var rsp:string;xcomb:integer);
    function CombustibleEnPosicion(xpos,xposcarga:integer):integer;
    function MangueraEnPosicion(xpos,xposcarga:integer):integer;
    function EjecutaComando(xCmnd:string):integer;
    function ResultadoComando(xFolio:integer):string;
    function ValidaCifra(xvalor:real;xenteros,xdecimales:byte):string;
    function PosicionDeCombustible(xpos,xcomb:integer):integer;
    function Inicializar(msj:string): string;
    function Parametros(json:string): string;
    function Login(mensaje:string): string;
    function Logout: string;
    function Iniciar: string;
    function Detener: string;
    function ObtenerEstado: string;
    function GuardarLog: string;
    function GuardarLogPetRes: string;
    function ObtenerLog(r:Integer): string;
    function ObtenerLogPetRes(r:Integer): string;
    function AutorizarVenta(msj:string): string;
    function RespuestaComando(msj:string): string;
    function DetenerVenta(msj:string): string;
    function ReanudarVenta(msj:string): string;
    function ActivaModoPrepago(msj:string): string;
    function Bloquear(msj:string): string;
    function Desbloquear(msj:string): string;
    function DesactivaModoPrepago(msj:string): string;
    function FinVenta(msj:string): string;
    function TransaccionPosCarga(msj:string): string;
    function IniciaPSerial(datosPuerto:string):string;
    function EstadoPosiciones(msj: string):string;
    function TotalesBomba(msj: string):string;
    function Shutdown:string;
    function Terminar:string;
    procedure GuardaLogComandos;
    function Encrypt(data,key3DES:string):string;
    function Decrypt(data,key3DES:string):string;
    function NoElemStrEnter(xstr:string):word;
    function ExtraeElemStrEnter(xstr:string;ind:word):string;    
    { Public declarations }
  end;

type
     tiposcarga = record
       estatus  :integer;
       descestat:string[20];
       importe,
       volumen,
       precio   :real;
       impopreset:real;
       PosActual:integer; // Posicion del combustible en proceso: 1..NoComb
       estatusant:integer;
       NoComb   :integer; // Cuantos combustibles hay en la posicion
       TComb    :array[1..MCxP] of integer; // Claves de los combustibles
       TCombx   :array[1..MCxP] of integer;
       TPos     :array[1..MCxP] of integer;
       TotalLitros  :array[1..MCxP] of real;
       TMang    :array[1..MCxP] of integer;
       SwDesp,SwA,SwPrec   :boolean;
       HoraFinv,
       Hora         :TDateTime;
       SwInicio,
       SwInicio2    :boolean;
       SwCargaTotales:boolean;
       IntentosTotales:byte;
       ActualizarPrecio:Boolean;
       swcargando,
       SwActivo,
       SwCmndF,
       SwDesHabilitado,
       SwOcc,SwCmndB  :boolean;
       ModoOpera    :string[8];
       ContPreset,
       ContOcc,
       StCero       :integer;
       TipoPago     :integer;
       FinVenta     :integer;
       PresetComb,
       PresetImpoN:integer;
       PresetImpo:real;
       SwPresetHora:boolean;
       PresetHora:TDateTime;
       Bloqueda:Boolean;
       CombActual:Integer;
       MangActual:Integer;
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
      MaxEsperaRsp=4;

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
  ogcvdispensarios_bennett: Togcvdispensarios_bennett;
  TPosCarga:array[1..100] of tiposcarga;
  TabCmnd  :array[1..200] of RegCmnd;
  LPrecios  :array[1..4] of Double;
  AvanceBar:integer;
  SwAplicaCmnd,
  PreciosInicio,
  SwSolOk:boolean;
  ContDA,
  StErrSol:integer;
  ruta_db:string;
  // CONTROL TRAFICO COMANDOS
  ListaCmnd    :TStrings;
  LinCmnd      :string;
  CharCmnd     :char;
  SwEsperaRsp  :boolean;
  ContEsperaRsp:integer;
  NumPaso      :integer;
  LinEstado    :string;
  LinEstadoGen :string;
  Token        :string;

implementation

uses StrUtils, TypInfo, DateUtils;

{$R *.DFM}

procedure ServiceController(CtrlCode: DWord); stdcall;
begin
  ogcvdispensarios_bennett.Controller(CtrlCode);
end;

function Togcvdispensarios_bennett.GetServiceController: TServiceController;
begin
  Result := ServiceController;
end;

procedure Togcvdispensarios_bennett.ServiceExecute(Sender: TService);
var
  config:TIniFile;
  lic:string;
begin
  try
    config:= TIniFile.Create(ExtractFilePath(ParamStr(0)) +'PDISPENSARIOS.ini');
    rutaLog:=config.ReadString('CONF','RutaLog','C:\ImagenCo');
    ServerSocket1.Port:=config.ReadInteger('CONF','Puerto',8585);
    licencia:=config.ReadString('CONF','Licencia','');
    minutosLog:=StrToInt(config.ReadString('CONF','MinutosLog','0'));
    MapCombs:=config.ReadString('CONF','MapeoCombustibles','');
    ContadorAlarma:=0;
    ListaCmnd:=TStringList.Create;
    SwEsperaRsp:=false;
    ServerSocket1.Active:=True;
    detenido:=True;
    estado:=-1;
    SegundosFinv:=30;
    horaLog:=Now;
    ListaLog:=TStringList.Create;
    ListaLogPetRes:=TStringList.Create;
    ListaComandos:=TStringList.Create;

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

procedure Togcvdispensarios_bennett.ServerSocket1ClientRead(Sender: TObject;
  Socket: TCustomWinSocket);
  var
    mensaje,comando,checksum,parametro:string;
    i:Integer;
    chks_valido:Boolean;
    metodoEnum:TMetodos;
begin
  try
    mensaje:=Socket.ReceiveText;
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
          Responder(Socket, 'DISPENSERS|PARAMETERS|'+Parametros(parametro));
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

procedure Togcvdispensarios_bennett.Responder(socket:TCustomWinSocket;resp:string);
begin
  socket.SendText(#1#2+resp+#3+CRC16(resp)+#23);
  AgregaLogPetRes('E '+#1#2+resp+#3+CRC16(resp)+#23);
end;

procedure Togcvdispensarios_bennett.AgregaLog(lin: string);
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

procedure Togcvdispensarios_bennett.AgregaLogPetRes(lin: string);
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

function Togcvdispensarios_bennett.IniciaPSerial(datosPuerto:string): string;
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

function Togcvdispensarios_bennett.IniciaPrecios(msj: string): string;
var
  ss:string;
  precioComb:Double;
  xpos,i:Integer;
begin
  try
    for xpos:=1 to MaxPosCargaActiva do begin
      with TPosCarga[xpos] do if xpos<=MaximoDePosiciones then begin
        for i:=1 to NoComb do begin
          precioComb:=StrToFloatDef(ExtraeElemStrSep(msj,TComb[i],'|'),-1);
          if precioComb=-1 then begin
            Result:='False|El precio '+IntToStr(i)+' es incorrecto|';
            Exit;
          end;
          if precioComb<=0 then
            Continue;
          LPrecios[TComb[i]]:=precioComb;
          // precio contado
          ss:='U'+IntToClaveNum(xpos,2)+NivelPrecioContado+IntToStr(TPos[i])+FiltraStrNum(FormatoNumeroSinComas(precioComb,5,2));
          ComandoConsolaBuff(ss,false);
          // precio credito
          ss:='U'+IntToClaveNum(xpos,2)+NivelPrecioCredito+IntToStr(TPos[i])+FiltraStrNum(FormatoNumeroSinComas(precioComb,5,2));
          ComandoConsolaBuff(ss,false);
        end;
      end;
    end;
    Result:='True|';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_bennett.AgregaPosCarga(posiciones: TlkJSONbase): string;
var
  i,j,k,xpos,xcomb:integer;
  existe:boolean;
  mangueras:TlkJSONbase;
begin
  try
    if not detenido then begin
      Result:='False|Es necesario detener el proceso antes de inicializar las posiciones de carga|';
      Exit;
    end;
    MaxPosCarga:=0;
    for i:=1 to 100 do with TPosCarga[i] do begin
      estatus:=-1;
      estatusant:=-1;
      NoComb:=0;
      SwInicio:=true;
      SwInicio2:=true;
      ContPreset:=0;
      ActualizarPrecio:=false;
      importe:=0;
      impopreset:=0;
      volumen:=0;
      precio:=0;
      for j:=1 to MCxP do
        TotalLitros[j]:=0;
      SwCargando:=false;
      SwCargaTotales:=true;
      IntentosTotales:=0;
      SwDeshabilitado:=false;
      SwCmndF:=false;
      SwActivo:=false;
      StCero:=0;
      tipopago:=0;
      finventa:=0;
      SwOCC:=false;
      ContOcc:=0;
      PresetImpo:=0;
      PresetImpoN:=0;
      PresetComb:=0;
      SwPresetHora:=false;
      HoraTotales:=0;
    end;

    for i:=0 to posiciones.Count-1 do begin
      xpos:=posiciones.Child[i].Field['DispenserId'].Value;
      if xpos>MaxPosCarga then
        MaxPosCarga:=xpos;
      with TPosCarga[xpos] do begin
        SwDesp:=false;
        SwA:=false;
        SwPrec:=false;
        existe:=false;
        ModoOpera:='Prepago';

        mangueras:=posiciones.Child[i].Field['Hoses'];
        for j:=0 to mangueras.Count-1 do begin
          if MapCombs<>'' then
            xcomb:=StrToInt(ExtraeElemStrSep(ExtraeElemStrSep(MapCombs,xpos,';'),mangueras.Child[j].Field['HoseId'].Value,','))
          else
            xcomb:=mangueras.Child[j].Field['ProductId'].Value;
          for k:=1 to NoComb do
            if TCombx[k]=xcomb then
              existe:=true;
          if not existe then begin
            inc(NoComb);
            TComb[NoComb]:=mangueras.Child[j].Field['ProductId'].Value;;
            TCombx[NoComb]:=xcomb;
            if mangueras.Child[j].Field['HoseId'].Value=3 then begin
              TMang[NoComb]:=4;
              TPos[NoComb]:=4;
            end
            else begin
              TMang[NoComb]:=mangueras.Child[j].Field['HoseId'].Value;
              TPos[NoComb]:=mangueras.Child[j].Field['HoseId'].Value;
            end;
          end;
        end;
      end;
    end;
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_bennett.FechaHoraExtToStr(FechaHora: TDateTime): String;
begin
  result:=FechaPaq(FechaHora)+' '+FormatDatetime('hh:mm:ss.zzz',FechaHora);
end;

procedure Togcvdispensarios_bennett.ComandoConsolaBuff(ss:string;swinicio:boolean);
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

procedure Togcvdispensarios_bennett.ComandoConsola(ss:string);
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

function Togcvdispensarios_bennett.CalculaBCC(ss:string):char;
var i,n,m:integer;
begin
  n:=0;
  for i:=1 to length(ss) do
    n:=n+ord(ss[i]);
  m:=(n)mod(256);
  result:=char(256-m);
end;

procedure Togcvdispensarios_bennett.pSerialTriggerAvail(CP: TObject; Count: Word);
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
      ProcesaLinea;
      LineaTimer:='';
      SwEspera:=false;
    end
    else SwEspera:=true;
  finally
    Timer1.Enabled:=true;
  end;
end;


procedure Togcvdispensarios_bennett.ProcesaLinea;
label uno;
var lin,ss,ss2,rsp,rsp2,
    descrsp,xestado,xmodo,
    xdisp2,xmodo2,xestado2,
    sslin           :string;
    simp,spre,sval  :string[20];
    claveCmnd:Integer;
    k:Integer;
    i,j,xpos,ii     :integer;
    XMANG,XCTE,XVEHI,
    xp,xpr,xcomb,xfolio:integer;
    xLista:TStrings;
    ximporte,
    ximpo,xdif,
    xprecio,xvol    :real;
    swerr           :boolean;
    totlts:array[1..4] of real;
begin
  if (minutosLog>0) and (MinutesBetween(Now,horaLog)>=minutosLog) then begin
    horaLog:=Now;
    GuardarLog;
  end;
  if (LineaTimer='') then
    exit;
  SwEsperaRsp:=false;
  ContEsperaRsp:=0;
  if length(LineaTimer)>2 then begin
    while (LineaTimer[1]<>idSTX)and(length(LineaTimer)>2) do
      delete(LineaTimer,1,1);
    lin:=copy(lineaTimer,2,length(lineatimer)-2);
  end
  else
    lin:=LineaTimer;
  LineaTimer:='';
  if lin='' then
    exit;
  case lin[1] of
   'B':begin // pide estatus de todas las bombas
         NumPaso:=1;
         ContEspera:=0;
         UltimoStatus:=LineaTimer;
         sslin:=copy(lin,4,length(lin)-3);
         MaxPosCargaActiva:=(length(sslin))div(2);
         if MaxPosCargaActiva>MaxPosCarga then
           MaxPosCargaActiva:=MaxPosCarga;
         if PreciosInicio then
           IniciarPrecios;           
         for xpos:=1 to MaxPosCargaActiva do begin
           with TPosCarga[xpos] do begin
             SwCmndB:=true;
             PosActual:=StrToIntDef(sslin[xpos*2-1],0);
             if PosActual=0 then
               PosActual:=1;
             if estatusant<>estatus then begin
               //SwPreset:=false;
               SwA:=true; //CAMBIO
             end;
             estatusant:=estatus;
             estatus:=StrToIntDef(sslin[xpos*2],0);
             if (estatus=0)and(stcero<=3) then begin
               inc(stcero);
               estatus:=estatusant;
             end
             else stcero:=0;
             //Mensaje:='Pos = '+inttostr(posactual);
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
                   descestat:='---';
                 end;
               1:begin
                   descestat:='Inactivo';
                   swcargando:=false;
                   if swprec then
                     swprec:=false;
                   if estatusant<>1 then begin
                     SwPresetHora:=false;
                     //SwArosMag:=false;
                     //PosAutorizada:=0;
                     FinVenta:=0;
                     TipoPago:=0;
                     SwOcc:=false;
                     ContOcc:=0;
                     PresetImpo:=0;
                     PresetImpoN:=0;
                     if SwCmndF then begin
                       ss:='F'+IntToClaveNum(xpos,2)+'9999';
                       ComandoConsolaBuff(ss,false);
                       SwCmndF:=false;
                     end;
                   end;
                 end;
               2:begin
                   descestat:='Autorizado';
                 end;
               3:begin
                   swcargando:=false;
                   descestat:='Pistola Levantada';
                   if (estatusant=4)and(PresetImpo>=0.01) then begin  // vuelve a autorizar
                     SnPosCarga:=xpos;
                     SnImporte:=PresetImpo;
                     inc(PresetImpoN);
                     if PresetImpoN<=3 then
                       estatus:=estatusant;
                     EnviaPreset(rsp,PresetComb);
                   end;
                 end;
               4:begin
                   descestat:='Listo para Despachar';
                 end;
               5:begin
                   descestat:='Despachando';
                   swcargando:=true;
                 end;
               6:begin
                   descestat:='Detenido';
                 end;
               7:begin
                   descestat:='Fin de Venta';
                   if Estatus<>Estatusant then
                     HoraFinv:=Now;
                   if (Now-HoraFinv)>=(SegundosFinv*tmSegundo) then
                     ComandoConsolaBuff('J'+IntToClaveNum(xpos,2),false);
                 end;
               8:descestat:='Venta Pendiente';
               9:descestat:='Error';
             end;
           end;
         end;
         // Checa las posiciones que estan solicitando autorizacion
         for xpos:=1 to MaxPosCargaActiva do begin
           with TPosCarga[xpos] do if xpos<=MaximoDePosiciones then begin
             if contpreset>0 then
               dec(contpreset);
             case Estatus of
               1:if SwInicio then begin
                   ss:='K'+IntToClaveNum(xpos,2)+'1'; // Postpago
                   ComandoConsolaBuff(ss,false);
                   ss:='L'+IntToClaveNum(xpos,2)+NivelPrecioContado; // Nivel de Precios
                   ComandoConsolaBuff(ss,false);
                   ss:='E'+IntToClaveNum(xpos,2); // Desautorizar
                   ComandoConsolaBuff(ss,false);
                   SwInicio:=false;
                   //SwPrepago:=false;
                   //SwPreset:=false;
                 end;
               3:if (not SwDesHabilitado)and(ModoOpera='Normal') then begin
                   if ContPreset<=0 then begin
                     FinVenta:=0;
                     ss:='S'+IntToClaveNum(xpos,2); // Autorizar
                     ComandoConsolaBuff(ss,false);
                     presetimpo:=0;presetimpon:=0;
                     SwInicio:=false;
                   end;
                 end;
             end;
           end;
         end;
       end;
   'A':begin // pide estatus de una bomba
         NumPaso:=2;
         xpos:=StrToIntDef(copy(lin,2,2),0);
         if (xpos>=1)and(xpos<=MaximoDePosiciones) then begin
           ContEsperaPaso2:=0;
           with TPosCarga[xpos] do begin
             try
               swinicio2:=false;
               volumen:=StrToFloat(copy(lin,5,6))/100;
               simp:=copy(lin,11,6);
               spre:=copy(lin,17,4);
               importe:=StrToFloat(simp)/100;
               precio:=StrToFloat(spre)/100;

               // valida ventas mayores a 10000 pesos
               ximpo:=volumen*precio;
               xdif:=abs(ximpo-importe);
               if xdif>=900 then begin
                 importe:=AjustaFloat(ximpo,2);
               end;
               // fin

               xvol:=ajustafloat(dividefloat(importe,precio),3);
               if abs(volumen-xvol)<0.05 then
                 volumen:=xvol;
               if (Estatus in [7,8])and(swcargando) then begin
                 swcargando:=false;
                 swdesp:=true;
               end;
             except
             end;
           end;
         end;
       end;
   '1':begin // pide estatus de una bomba
         NumPaso:=2;
         xpos:=StrToIntDef(copy(lin,2,2),0);
         if (xpos>=1)and(xpos<=MaximoDePosiciones) then begin
           ContEsperaPaso2:=0;
           with TPosCarga[xpos] do begin
             try
               swinicio2:=false;
               volumen:=StrToFloat(copy(lin,5,8))/100;
               simp:=copy(lin,13,8);
               spre:=copy(lin,21,5);
               importe:=StrToFloat(simp)/100;
               precio:=StrToFloat(spre)/100;
               xvol:=ajustafloat(dividefloat(importe,precio),3);
               if abs(volumen-xvol)<0.05 then
                 volumen:=xvol;
               if (Estatus in [7,8])and(swcargando) then begin
                 swcargando:=false;
                 swdesp:=true;
                 AgregaLog('GUARDA VENTA Pos:'+inttostr(xpos)+' Estatus:'+inttostr(estatus)+' - ant:'+inttostr(estatusant));
               end;
               if (TPosCarga[xpos].finventa=0) then begin
                 if Estatus in [7,8] then begin
                   ss:='J'+IntToClaveNum(xpos,2); // Fin de Venta
                   ComandoConsola(ss);
                 end;
               end;
             except
             end;
           end;
         end;
       end;
   'N':begin // totales de la bomba
         NumPaso:=3;
         xpos:=StrToIntDef(copy(lin,2,2),0);
         if (xpos>=1)and(xpos<=MaximoDePosiciones) then begin
           ContEsperaPaso3:=0;
           with TPosCarga[xpos] do begin
             SwCargaTotales:=false;
             IntentosTotales:=0;
             Totlts[1]:=StrToFloat(copy(lin,4,10))/1000;
             Totlts[2]:=StrToFloat(copy(lin,14,10))/1000;
             Totlts[3]:=StrToFloat(copy(lin,24,10))/1000;
             Totlts[4]:=StrToFloat(copy(lin,34,10))/1000;
             for j:=1 to MCxP do
               if TPos[j] in [1..4] then
                 TotalLitros[j]:=TotLts[TPos[j]];
             HoraTotales:=Now;
           end;
         end;
       end;
  end;
  if (ListaCmnd.Count>0)and(not SwEsperaRsp) then begin
    ss:=ListaCmnd[0];
    ListaCmnd.Delete(0);
    ComandoConsola(ss);
    exit;
  end
  else begin
    inc(NumPaso);
    PosicionActual:=0;
  end;
  // checa lecturas de dispensarios
  if NumPaso=2 then begin
    if PosicionActual<MaxPosCargaActiva then begin
      repeat
        Inc(PosicionActual);
        with TPosCarga[PosicionActual] do if NoComb>0 then begin
          if (estatus<>9)and(estatus<>estatusant)or(estatus>=5)or(SwA)or(swinicio2)or(swcargando) then begin
            SwA:=false;
            if Bennett8Digitos<>'Si' then
              ComandoConsolaBuff('A'+IntToClaveNum(PosicionActual,2),false)
            else
              ComandoConsolaBuff('1'+IntToClaveNum(PosicionActual,2),false);
          end;
        end;
      until (PosicionActual>=MaxPosCargaActiva);
    end;
    if not SwEsperaRsp then begin
      NumPaso:=3;
      PosicionActual:=0;
    end;
  end;
  // Lee Totales
  if NumPaso=3 then begin
    // GUARDA VALORES DE DISPENSARIOS CARGANDO
    try
      xestado2:='';xdisp2:='';xmodo2:='';
      try
        if MaximoDePosiciones<24 then begin
          xdisp2:=LinEstado;

          // leo modo de operacion al final de la linea
          xmodo2:=ExtraeElemStrSep(xdisp2,2,'&');
          if length(xmodo2)>MaximoDePosiciones then
            delete(xmodo2,1,MaximoDePosiciones)
          else xmodo2:='';

          // leo estados al principio de la linea
          ss:=ExtraeElemStrSep(xdisp2,1,'&');
          xestado2:=ExtraeElemStrSep(ss,1,'#');
          if xestado2<>'' then
            if xestado2[1]='D' then
              delete(xestado2,1,1);
          if length(xestado2)>MaximoDePosiciones then
            delete(xestado2,1,MaximoDePosiciones)
          else xestado2:='';

          // saco lecturas de cada posicion
          ii:=NoElemStrSep(ss,'#');
          xdisp2:='';
          for i:=2 to ii do begin
            ss2:=ExtraeElemStrSep(ss,i,'#');
            rsp:=ExtraeElemStrSep(ss2,1,'/');
            xpos:=strtointdef(rsp,0);
            if xpos>MaximoDePosiciones then
              xdisp2:=xdisp2+'#'+ss2;
          end;
        end;
      except
      end;

      lin:='';xestado:='';xmodo:='';
      for xpos:=1 to MaxPosCarga do with TPosCarga[xpos] do begin
        xmodo:=xmodo+ModoOpera[1];
        if not SwDesHabilitado then begin
          case estatus of
            0:xestado:=xestado+'0'; // Sin Comunicaci�n
            1:xestado:=xestado+'1'; // Inactivo (Idle)
            5:xestado:=xestado+'2'; // Cargando (In Use)
            7:if not swcargando then
                xestado:=xestado+'3' // Fin de Carga (Used)
              else
                xestado:=xestado+'2';
            3,4:xestado:=xestado+'5'; // Llamando (Calling)
            2,8:xestado:=xestado+'9'; // Autorizado
            6:xestado:=xestado+'8'; // Detenido (Stoped)
            else xestado:=xestado+'0';
          end;
        end
        else xestado:=xestado+'7'; // Deshabilitado
        xcomb:=CombustibleEnPosicion(xpos,PosActual);
        CombActual:=xcomb;
        MangActual:=MangueraEnPosicion(xpos,PosActual);
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
      LinEstado:='D'+lin;
      LinEstadoGen:=xestado;
    except
    end;
    // FIN

//    if PosicionActual<MaxPosCargaActiva then begin
//      repeat
//        Inc(PosicionActual);
//        with TPosCarga[PosicionActual] do if NoComb>0 then begin
//          if swcargatotales then begin
//            inc(intentostotales);
//            if intentostotales>3 then
//              swcargatotales:=false;
//            ComandoConsolaBuff('N'+IntToClaveNum(PosicionActual,2),false); // Totales
//          end;
//        end;
//      until (PosicionActual>=MaxPosCargaActiva);
//    end;
    if not SwEsperaRsp then begin
      NumPaso:=4;
      PosicionActual:=0;
    end;
  end;
  if (NumPaso=4) then begin
    // Checa Comandos
    if swcierrabd then begin
      Esperamiliseg(300);
      swcierrabd:=false;
    end;
    for k:=1 to 200 do begin
      claveCmnd:=k;
      if (TabCmnd[claveCmnd].SwActivo)and(not TabCmnd[claveCmnd].SwResp) then begin
        SwAplicaCmnd:=true;
        ss:=ExtraeElemStrSep(TabCmnd[claveCmnd].Comando,1,' ');
        AgregaLog(TabCmnd[claveCmnd].Comando);
        // ORDENA CARGA DE COMBUSTIBLE EN IMPORTE
        if ss='OCC' then begin     // OCC POSCARGA IMPORTE COMBUSTIBLE TIPOVENTA FINVENTA BOUCHER
          SnPosCarga:=StrToIntDef(ExtraeElemStrSep(TabCmnd[claveCmnd].Comando,2,' '),0);
          xpos:=SnPosCarga;
          rsp:='OK';
          if (SnPosCarga in [1..MaxPosCarga]) then begin
            if (TPosCarga[SnPosCarga].estatus in [1,3])or(TPosCarga[SnPosCarga].SwOCC) then begin
              // Valida que se haya aplicado el PRESET
              if TabCmnd[claveCmnd].SwNuevo then begin
                TPosCarga[SnPosCarga].SwOCC:=false;
                TabCmnd[claveCmnd].SwNuevo:=false;
              end;
              Swerr:=false;
              if (TPosCarga[SnPosCarga].SwOCC) then begin
                if (TPosCarga[SnPosCarga].SwCmndB) then begin
                  if (TPosCarga[SnPosCarga].estatus in [1,3])and(TPosCarga[SnPosCarga].ContOCC>0) then begin
                    TPosCarga[SnPosCarga].SwOCC:=false;
                  end
                  else if (TPosCarga[SnPosCarga].estatus in [1,3])and(TPosCarga[SnPosCarga].ContOCC<=0) then begin
                    rsp:='Error al aplicar PRESET';
                    TPosCarga[SnPosCarga].SwOCC:=false;
                    TPosCarga[SnPosCarga].ContOCC:=0;
                    Swerr:=true;
                  end;
                end
                else SwAplicaCmnd:=false;
              end;
              if (TPosCarga[SnPosCarga].estatus in [1,3])and(not TPosCarga[SnPosCarga].SwOCC)and(not swerr) then begin
                TPosCarga[SnPosCarga].SwOCC:=true;
                TPosCarga[SnPosCarga].SwCmndB:=false;
                if TPosCarga[SnPosCarga].ContOCC=0 then
                  TPosCarga[SnPosCarga].ContOCC:=BennetReintentosPreset
                else begin
                  dec(TPosCarga[SnPosCarga].ContOCC);
                  esperamiliseg(500);
                end;
                SwAplicaCmnd:=false;
                try
                  SnImporte:=StrToFLoat(ExtraeElemStrSep(TabCmnd[claveCmnd].Comando,3,' '));
                  rsp:=ValidaCifra(SnImporte,4,2);
                  if (SnImporte<0.01) then
                    SnImporte:=9999;
                except
                  rsp:='Error en Importe';
                end;
                if rsp='OK' then begin
                  ss:=ExtraeElemStrSep(TabCmnd[claveCmnd].Comando,4,' ');
                  if ss[1]='P' then begin
                    delete(ss,1,1);
                    xp:=StrToIntDef(ss,0);
                    xcomb:=CombustibleEnPosicion(xpos,xp);
                  end
                  else begin
                    xcomb:=StrToIntDef(ss,0);
                    xp:=PosicionDeCombustible(xpos,xcomb);
                  end;
                  if xp>0 then begin
                    TPosCarga[SnPosCarga].finventa:=StrToIntDef(ExtraeElemStrSep(TabCmnd[claveCmnd].Comando,5,' '),0);
                    if rsp='OK' then
                      EnviaPreset(rsp,xcomb);
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
        // ORDENA CARGA DE COMBUSTIBLE EN LITROS
        else if ss='OCL' then begin     // OCL POSCARGA LITROS COMBUSTIBLE TIPOVENTA FINVENTA BOUCHER
          SnPosCarga:=StrToIntDef(ExtraeElemStrSep(TabCmnd[claveCmnd].Comando,2,' '),0);
          xpos:=SnPosCarga;
          if (xpos<=MaximoDePosiciones) then begin
            rsp:='OK';
            if (SnPosCarga in [1..MaxPosCarga]) then begin
              if (TPosCarga[SnPosCarga].estatus in [1,3])or(TPosCarga[SnPosCarga].SwOCC) then begin
                // Valida que se haya aplicado el PRESET
                if TabCmnd[claveCmnd].SwNuevo then begin
                  TPosCarga[SnPosCarga].SwOCC:=false;
                  TabCmnd[claveCmnd].SwNuevo:=false;
                end;
                Swerr:=false;
                if (TPosCarga[SnPosCarga].SwOCC) then begin
                  if (TPosCarga[SnPosCarga].SwCmndB) then begin
                    if (TPosCarga[SnPosCarga].estatus in [1,3])and(TPosCarga[SnPosCarga].ContOCC>0) then begin
                      TPosCarga[SnPosCarga].SwOCC:=false;
                    end
                    else if (TPosCarga[SnPosCarga].estatus in [1,3])and(TPosCarga[SnPosCarga].ContOCC<=0) then begin
                      rsp:='Error al aplicar PRESET';
                      TPosCarga[SnPosCarga].SwOCC:=false;
                      TPosCarga[SnPosCarga].ContOCC:=0;
                      Swerr:=true;
                    end;
                  end
                  else SwAplicaCmnd:=false;
                end;
                if (TPosCarga[SnPosCarga].estatus in [1,3])and(not TPosCarga[SnPosCarga].SwOCC)and(not swerr) then begin
                  TPosCarga[SnPosCarga].SwOCC:=true;
                  TPosCarga[SnPosCarga].SwCmndB:=false;
                  if TPosCarga[SnPosCarga].ContOCC=0 then
                    TPosCarga[SnPosCarga].ContOCC:=BennetReintentosPreset
                  else begin
                    dec(TPosCarga[SnPosCarga].ContOCC);
                    esperamiliseg(500);
                  end;
                  SwAplicaCmnd:=false;
                  try
                    SnLitros:=StrToFLoat(ExtraeElemStrSep(TabCmnd[claveCmnd].Comando,3,' '));
                    SnImporte:=0;
                    rsp:=ValidaCifra(SnLitros,4,0);
                    if rsp='OK' then
                      if (SnLitros<1) then
                        rsp:='Valor en cero no permitido'
                  except
                    rsp:='Error en Valor Litros';
                  end;
                  if rsp='OK' then begin
                    ss:=ExtraeElemStrSep(TabCmnd[claveCmnd].Comando,4,' ');
                    if ss[1]='P' then begin
                      delete(ss,1,1);
                      xp:=StrToIntDef(ss,0);
                      xcomb:=CombustibleEnPosicion(xpos,xp);
                    end
                    else begin
                      xcomb:=StrToIntDef(ss,0);
                      xp:=PosicionDeCombustible(xpos,xcomb);
                    end;
                    if xp>0 then begin
                      TPosCarga[SnPosCarga].finventa:=StrToIntDef(ExtraeElemStrSep(TabCmnd[claveCmnd].Comando,5,' '),0);
                      if rsp='OK' then begin
                        ss:='F'+IntToClaveNum(xpos,2)+FiltraStrNum(FormatFloat('0000',SnLitros));
                        ComandoConsolaBuff(ss,false);
                        EsperaMiliSeg(300);
                        TPosCarga[SnPosCarga].SwCmndF:=true;
                        if Bennett8Digitos<>'Si' then
                          SnImporte:=9999.99
                        else
                          SnImporte:=999999.99;

                        SnLitros:=0;
                        EnviaPreset(rsp,xcomb);
                      end;
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
          else rsp:='Posicion no Existe';
        end
        // ORDENA FIN DE VENTA
        else if ss='FINV' then begin
          xpos:=StrToIntDef(ExtraeElemStrSep(TabCmnd[claveCmnd].Comando,2,' '),0);
          if (xpos<=MaximoDePosiciones) then begin
            rsp:='OK';
            if (xpos in [1..MaxPosCarga]) then begin
              TPosCarga[xpos].tipopago:=StrToIntDef(ExtraeElemStrSep(TabCmnd[claveCmnd].Comando,3,' '),0);
              if TPosCarga[xpos].Estatus in [7,8,1] then begin // EOT
                if (not TPosCarga[xpos].swcargando) then begin
                  ss:='J'+IntToClaveNum(xpos,2); // Fin de Venta
                  ComandoConsolaBuff(ss,False);
                end
                else
                  rsp:='Posicion no esta despachando';
              end
              else begin // EOT
                rsp:='Posicion aun no esta en fin de venta';
              end;
            end
            else rsp:='Posicion de Carga no Existe';
          end
          else rsp:='Posicion no Existe';
        end
        // ORDENA ESPERA FIN DE VENTA
        else if ss='EFV' then begin
          xpos:=StrToIntDef(ExtraeElemStrSep(TabCmnd[claveCmnd].Comando,2,' '),0);
          rsp:='OK';
          if (xpos in [1..MaxPosCarga]) then
            if (TPosCarga[xpos].Estatus=5) then
              TPosCarga[xpos].finventa:=1
            else rsp:='Posicion debe estar Despachando'
          else rsp:='Posicion de Carga no Existe';
        end
        // CMND: DESAUTORIZA VENTA DE COMBUSTIBLE
        else if (ss='DVC')or(ss='PARAR') then begin
          rsp:='OK';
          xpos:=strtointdef(ExtraeElemStrSep(TabCmnd[claveCmnd].Comando,2,' '),0);
          if (xpos<=MaximoDePosiciones) then begin
            if TPosCarga[xpos].ModoOpera='Normal' then begin
              if Bennett8Digitos<>'Si' then
                ComandoConsolaBuff('P'+IntToClaveNum(xpos,2)+FiltraStrNum(FormatFloat('0000.00',9999.00)),false)
              else
                ComandoConsolaBuff('5'+IntToClaveNum(xpos,2)+FiltraStrNum(FormatFloat('000000.00',999999.00)),false);
            end;
            ComandoConsolaBuff('E'+IntToClaveNum(xpos,2),false);
            if TPosCarga[xpos].estatus=2 then
              TPosCarga[xpos].tipopago:=0;
            TPosCarga[xpos].PresetImpo:=0;
            TPosCarga[xpos].PresetImpoN:=0;
          end
          else rsp:='Posicion no Existe';
        end
        else if (ss='REANUDAR') then begin
          rsp:='OK';
          xpos:=strtointdef(ExtraeElemStrSep(TabCmnd[claveCmnd].Comando,2,' '),0);
          if xpos in [1..MaxPosCarga] then begin
            if (TPosCarga[xpos].estatus in [6]) then begin
              ComandoConsolaBuff('S'+IntToClaveNum(xpos,2),False);
            end;
          end;
        end
        else if (ss='TOTAL') then begin
          SnPosCarga:=StrToIntDef(ExtraeElemStrSep(TabCmnd[claveCmnd].Comando,2,' '),0);
          xpos:=SnPosCarga;
          rsp:='OK';
          with TPosCarga[xpos] do begin
            if (TabCmnd[claveCmnd].SwNuevo) and (SecondsBetween(Now,HoraTotales)>10) then begin
              SwCargaTotales:=True;
              TabCmnd[claveCmnd].SwNuevo:=false;
              ComandoConsolaBuff('N'+IntToClaveNum(xpos,2),false);
            end;
            if not SwCargaTotales then begin
              rsp:='OK'+FormatFloat('0.000',ToTalLitros[1])+'|'+FormatoMoneda(ToTalLitros[1]*LPrecios[TComb[1]])+'|'+
                              FormatFloat('0.000',ToTalLitros[2])+'|'+FormatoMoneda(ToTalLitros[2]*LPrecios[TComb[2]])+'|'+
                              FormatFloat('0.000',ToTalLitros[3])+'|'+FormatoMoneda(ToTalLitros[3]*LPrecios[TComb[3]]);
              SwAplicaCmnd:=True;
            end
            else
              SwAplicaCmnd:=False;
          end;
        end
        else rsp:='Comando no Soportado o no Existe';

        if SwAplicaCmnd then begin
          TabCmnd[claveCmnd].SwNuevo:=false;
          TabCmnd[claveCmnd].SwResp:=true;
          TabCmnd[claveCmnd].Respuesta:=rsp;
          AgregaLogPetRes('C '+LlenaStr(TabCmnd[claveCmnd].Comando,'I',40,' ')+' Respuesta: '+TabCmnd[claveCmnd].Respuesta);
        end;
      end;
    end;

    if not SwEsperaRsp then
      NumPaso:=1;
  end;
end;

procedure Togcvdispensarios_bennett.EnviaPreset(var rsp:string;xcomb:integer);
var xpos,xp,xc:integer;
    ss:string;
begin
  rsp:='OK';
  xpos:=SnPosCarga;
  if not (TPosCarga[xpos].estatus in [1..3]) then begin
    rsp:='Posicion no Disponible';
    exit;
  end;
  if TPosCarga[xpos].SwDesHabilitado then begin
    rsp:='Posicion Bloqueada';
    exit;
  end;
  if SnImporte<>9999 then begin
    ss:='K'+IntToClaveNum(xpos,2)+'2'; // Modo PrePago
    ComandoConsolaBuff(ss,false);
    if Bennett8Digitos<>'Si' then
      ss:='P'+IntToClaveNum(xpos,2)+FiltraStrNum(FormatFloat('0000.00',SnImporte))
    else
      ss:='5'+IntToClaveNum(xpos,2)+FiltraStrNum(FormatFloat('000000.00',SnImporte));
    ComandoConsolaBuff(ss,false);
    ss:='L'+IntToClaveNum(xpos,2)+NivelPrecioContado; // Nivel de Precios
    ComandoConsolaBuff(ss,false);
  end;

  ss:='S'+IntToClaveNum(xpos,2); // Autorizar

  if (SoportaSeleccionProducto='Si') and (xcomb>0) and (SnImporte<>9999) then with TPosCarga[xpos] do begin
    xp:=0;
    for xc:=1 to NoComb do
      if TComb[xc]=xcomb then
        xp:=TPos[xc];
    case xp of
      1:ss:=ss+char(33);   // 21h
      2:ss:=ss+char(34);   // 22h
      3:ss:=ss+char(40);   // 28h
      4:ss:=ss+char(36);   // 24h
    end;
  end;
  ComandoConsolaBuff(ss,false);
  TPosCarga[xpos].ContPreset:=5;
  TPosCarga[xpos].PresetComb:=xcomb;
  TPosCarga[xpos].PresetImpo:=SnImporte;
end;

function Togcvdispensarios_bennett.CombustibleEnPosicion(xpos,xposcarga:integer):integer;
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

function Togcvdispensarios_bennett.MangueraEnPosicion(xpos,xposcarga:integer):integer;
var i:integer;
begin
  with TPosCarga[xpos] do begin
    result:=TMang[1];
    for i:=1 to NoComb do begin
      if TPos[i]=xposcarga then
        result:=TMang[i];
    end;
    if Result=4 then
      Result:=3;
  end;
end;

function Togcvdispensarios_bennett.EjecutaComando(xCmnd:string):integer;
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
    SwNuevo:=True;
    Respuesta:='';
  end;
  Result:=FolioCmnd;
end;

function Togcvdispensarios_bennett.ResultadoComando(xFolio:integer):string;
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

function Togcvdispensarios_bennett.ValidaCifra(xvalor:real;xenteros,xdecimales:byte):string;
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

function Togcvdispensarios_bennett.PosicionDeCombustible(xpos,xcomb:integer):integer;
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

function Togcvdispensarios_bennett.Iniciar: string;
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

    Result:='True|';
  except
    on e:Exception do
      Result:='False|'+e.Message+'|';
  end;
end;

function Togcvdispensarios_bennett.Detener: string;
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

function Togcvdispensarios_bennett.ObtenerEstado: string;
begin
  Result:='True|'+IntToStr(estado)+'|';
end;

function Togcvdispensarios_bennett.GuardarLog:string;
begin
  try
    AgregaLog('Version: '+version);
    ListaLog.SaveToFile(rutaLog+'\LogDisp'+FiltraStrNum(FechaHoraToStr(Now))+'.txt');
    GuardarLogPetRes;
    GuardaLogComandos;
    Result:='True|'+rutaLog+'\LogDisp'+FiltraStrNum(FechaHoraToStr(Now))+'.txt';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_bennett.GuardarLogPetRes:string;
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

function Togcvdispensarios_bennett.ObtenerLog(r: Integer): string;
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

function Togcvdispensarios_bennett.ObtenerLogPetRes(r: Integer): string;
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

function Togcvdispensarios_bennett.AutorizarVenta(msj: string): string;
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

procedure Togcvdispensarios_bennett.Timer1Timer(Sender: TObject);
begin
  try
    if not SwEsperaRsp then begin // NO HAY COMANDOS EN PROCESO
      ComandoConsola('B00');
    end
    else begin // HAY COMANDOS EN PROCESO
      inc(ContEsperaRsp);
      if ContEsperaRsp>MaxEsperaRsp then begin
        ContEsperaRsp:=0;
        case CharCmnd of
         'B':LineaTimer:=idStx+idStx+'B00'+idEtx+'.*';
         'A','N':LineaTimer:=idStx+CharCmnd+'00'+idEtx+'.*';
         else LineaTimer:=idNak;
        end;
        ProcesaLinea;
      end;
    end;
  except
  end;
end;

function Togcvdispensarios_bennett.RespuestaComando(msj: string): string;
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

function Togcvdispensarios_bennett.DetenerVenta(msj: string): string;
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

function Togcvdispensarios_bennett.ReanudarVenta(msj: string): string;
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

function Togcvdispensarios_bennett.ActivaModoPrepago(msj: string): string;
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

function Togcvdispensarios_bennett.DesactivaModoPrepago(msj: string): string;
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

function Togcvdispensarios_bennett.FinVenta(msj: string): string;
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

function Togcvdispensarios_bennett.TransaccionPosCarga(msj: string): string;
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
      Result:='True|'+FormatDateTime('yyyy-mm-dd',HoraFinv)+'T'+FormatDateTime('hh:nn',HoraFinv)+'|'+IntToStr(MangActual)+'|'+IntToStr(CombActual)+'|'+
              FormatFloat('0.000',volumen)+'|'+FormatFloat('0.00',precio)+'|'+FormatFloat('0.00',importe)+'|';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_bennett.EstadoPosiciones(msj: string): string;
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

function Togcvdispensarios_bennett.TotalesBomba(msj: string): string;
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

function Togcvdispensarios_bennett.Shutdown: string;
begin
  if estado>0 then
    Result:='False|El servicio esta en proceso, no fue posible detenerlo|'
  else begin
    ServiceThread.Terminate;
    Result:='True|';
  end;
end;

function Togcvdispensarios_bennett.Bloquear(msj: string): string;
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
          for xpos:=1 to MaxPosCarga do
            TPosCarga[xpos].SwDesHabilitado:=True;
          Result:='True|';
        end
        else
          Result:='False|Existen posiciones cargando combustible|';
      end
      else if (xpos in [1..maxposcarga]) then begin
        if not TPosCarga[xpos].swcargando then begin
          TPosCarga[xpos].SwDesHabilitado:=True;
          Result:='True|';
        end
        else
          Result:='False|Posicion esta cargando combustible|';
      end;
    end
    else Result:='False|Posicion no Existe|';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_bennett.Desbloquear(msj: string): string;
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

function Togcvdispensarios_bennett.Inicializar(msj: string): string;
var
  js: TlkJSONBase;
  consolas,dispensarios,productos: TlkJSONbase;
  i,productID: Integer;
  datosPuerto, variables, variable:string;
begin
  try
    if estado>-1 then begin
      Result:='False|El servicio ya habia sido inicializado|';
      Exit;
    end;

    js := TlkJSON.ParseText(ExtraeElemStrSep(msj,1,'|'));
    variables:=ExtraeElemStrSep(msj,2,'|');

    SoportaSeleccionProducto:='Si';
    Bennett8Digitos:='No';
    BennetReintentosPreset:=5;
    for i:=1 to NoElemStrEnter(variables) do begin
      variable:=ExtraeElemStrEnter(variables,i);
      if UpperCase(ExtraeElemStrSep(variable,1,'='))='SOPORTASELECCIONPRODUCTO' then
        SoportaSeleccionProducto:=ExtraeElemStrSep(variable,2,'=')
      else if UpperCase(ExtraeElemStrSep(variable,1,'='))='BENNETT8DIGITOS' then
        Bennett8Digitos:=ExtraeElemStrSep(variable,2,'=')
      else if UpperCase(ExtraeElemStrSep(variable,1,'='))='BENNETREINTENTOSPRESET' then
        BennetReintentosPreset:=StrToIntDef(ExtraeElemStrSep(variable,2,'='),5);
    end;

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
    PreciosInicio:=False;
    estado:=0;
    SwBcc:=false;
    Result:='True|';
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_bennett.Terminar: string;
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

function Togcvdispensarios_bennett.CRC16(Data: AnsiString): AnsiString;
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

function Togcvdispensarios_bennett.Login(mensaje: string): string;
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

function Togcvdispensarios_bennett.MD5(const usuario: string): string;
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

function Togcvdispensarios_bennett.Parametros(json: string): string;
var 
  js: TlkJSONBase;
begin
  try
    js := TlkJSON.ParseText(json);
    if js.Field['CounterToPaySale'].Value>0 then
      SegundosFinv := js.Field['CounterToPaySale'].Value;
    Result:='True|';
  except
    on e:Exception do begin
      SegundosFinv:=30;
      Result:='False|Excepcion: '+e.Message+'|';
    end;
  end;
end;

function Togcvdispensarios_bennett.Logout: string;
begin
  Token:='';
  Result:='True|';
end;

procedure Togcvdispensarios_bennett.IniciarPrecios;
var
  xpos,i:Integer;
  ss:String;
begin
  for i:=1 to 4 do begin
    if LPrecios[i]>0 then begin
      for xpos:=1 to MaxPosCargaActiva do begin
        with TPosCarga[xpos] do begin
          // precio contado
          ss:='U'+IntToClaveNum(xpos,2)+NivelPrecioContado+IntToStr(TPos[i])+FiltraStrNum(FormatoNumeroSinComas(LPrecios[TComb[i]],5,2));
          ComandoConsolaBuff(ss,false);
          esperamiliseg(100);
          // precio credito
          ss:='U'+IntToClaveNum(xpos,2)+NivelPrecioCredito+IntToStr(TPos[i])+FiltraStrNum(FormatoNumeroSinComas(LPrecios[TComb[i]],5,2));
          ComandoConsolaBuff(ss,false);
          esperamiliseg(100);
        end;
      end;
    end;
  end;
  PreciosInicio:=False;
end;

procedure Togcvdispensarios_bennett.GuardaLogComandos;
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

function Togcvdispensarios_bennett.Decrypt(data, key3DES: string): string;
var
  key128 : TKey128;
  dataOut : string;
begin
  GenerateMD5Key(key128, Key3DES);
  TripleDESEncryptString(data,dataOut,key128,false);
  dataOut := UTF8Decode(dataOut);
  Result := dataOut;
end;

function Togcvdispensarios_bennett.Encrypt(data, key3DES: string): string;
var
  key128 : TKey128;
  dataIn,dataOut : string;
begin
  dataIn := UTF8Encode(data);
  GenerateMD5Key(key128, Key3DES);
  TripleDESEncryptString(dataIn,dataOut,key128,true);
  Result := dataOut;
end;

function Togcvdispensarios_bennett.ExtraeElemStrEnter(xstr: string;
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

function Togcvdispensarios_bennett.NoElemStrEnter(xstr: string): word;
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

end.
