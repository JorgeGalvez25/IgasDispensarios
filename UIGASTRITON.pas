unit UIGASTRITON;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, SvcMgr, Dialogs, IdHash,
  ExtCtrls, OoMisc, AdPort, ScktComp, IniFiles, ULIBGRAL, uLkJSON, IdHashMessageDigest;

type
  Togcvdispensarios_triton = class(TService)
    ClientSocket1: TClientSocket;
    pSerial: TApdComPort;
    Timer1: TTimer;
    Timer2: TTimer;
    procedure ServiceExecute(Sender: TService);
    procedure ClientSocket1Connect(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure ClientSocket1Disconnect(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure Timer2Timer(Sender: TObject);
    procedure ClientSocket1Read(Sender: TObject; Socket: TCustomWinSocket);
    procedure Timer1Timer(Sender: TObject);
    procedure pSerialTriggerAvail(CP: TObject; Count: Word);
  private
    { Private declarations }
    conectado, respJson:Boolean;
    rootJSON : TlkJSONbase;
    socketResponse : TCustomWinSocket;
    CmndNuevo     :Boolean;
    stx,etx:Boolean;
    respPSerial:AnsiString;
  public
    ListaLog:TStringList;
    ListaLogPetRes:TStringList;
    version:string;
    rutaLog:string;
    minutosLog:Integer;
    estado:Integer;
    horaLog:TDateTime;
    HoraArranque:TDateTime;
    FolioCmnd   :integer;
    detenido:Boolean;
    horaEnvio:TDateTime;
    esperandoResp:Boolean;
    verificaPrecio:Boolean;
    function GetServiceController: TServiceController; override;
    procedure SetEstadoJSON(const AEstado: Integer);
    procedure AgregaLogPetRes(lin: string);
    procedure AgregaLog(lin:string);
    procedure GuardarLog(folio:Integer);
    procedure GuardarLogPetRes(folio:Integer);
    procedure AddPeticionJSON(const aFolio: Integer; const aResultado : string);
    procedure Responder(resp:string);
    procedure Inicializar(folio:Integer; msj: string);
    function AgregaPosCarga(posiciones: TlkJSONbase): string;
    function IniciaPSerial(datosPuerto:string): string;
    procedure ComandoConsola(ss:string);
    procedure IniciaPrecios(folio:Integer; msj:string);
    procedure AutorizarVenta(folio:Integer; msj: string);
    function EjecutaComando(xCmnd:string):integer;
    procedure FinVenta(folio:Integer; msj: string);
    procedure TotalesBomba(folio:Integer; msj: string);
    procedure Detener(folio:Integer);
    procedure Iniciar(folio:Integer);
    procedure Shutdown(folio:Integer);
    procedure Terminar(folio:Integer);
    procedure Login(folio:Integer; mensaje:string);
    procedure Logout(folio:Integer);
    procedure RespuestaComando(folio:Integer; msj: string);
    function ResultadoComando(xFolio:integer):string;
    procedure ObtenerLog(folio:Integer; r: Integer);
    procedure ObtenerLogPetRes(folio:Integer; r: Integer);
    procedure DetenerVenta(folio:Integer; msj: string);
    function MD5(const usuario: string): string;
    procedure ProcesaComandos;
    procedure ProcesaLinea(xlin:string);
    function InsertaDecimal(const S: string; Decimales: Integer): string;
    procedure ActualizaCampoJSON(xpos:Integer; campo:string; valor:Variant);
    procedure ApplyTotalLitrosToJSON(const xpos: Integer; const TotalLitros: array of Real);
    procedure ActivaModoPrepago(folio: Integer; msj: string);
    procedure DesactivaModoPrepago(folio: Integer; msj: string);
    procedure Bloquear(folio: Integer; msj: string);
    procedure Desbloquear(folio: Integer; msj: string);
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
       PosDispActual:integer;
       estatusant:integer;
       ModoOpera:string;
       SwDesHabil:Boolean;
       NoComb   :integer;
       TComb    :array[1..4] of integer;
       TPos     :array[1..4] of integer;
       TPrec    :array[1..4] of integer;
       TMang     :array[1..4] of integer;
       TotalLitros:array[1..4] of real;
       TipoPago,
       FinVenta:integer;
       HoraTotales:TDateTime;
       CombActual:Integer;
       MangActual:Integer;
       EsperandoTotales:Boolean;

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

type TMetodos = (NOTHING_e, INITIALIZE_e, LOGIN_e, LOGOUT_e, PRICES_e,
                PARAMETERS_e, AUTHORIZE_e,PAYMENT_e, TOTALS_e,HALT_e,
                RUN_e, SHUTDOWN_e, TERMINATE_e, TRACE_e, STOP_e,
                SAVELOGREQ_e, RESPCMND_e, LOG_e, LOGREQ_e, SELFSERVICE_e,
                FULLSERVICE_e, BLOCK_e, UNBLOCK_e);

var
  ogcvdispensarios_triton: Togcvdispensarios_triton;
  TPosCarga:array[1..32] of tiposcarga;
  TabCmnd  :array[1..200] of RegCmnd;
  Token        :string;
  MaxPosCarga:integer;

implementation

uses
  TypInfo, Variants, StrUtils, DateUtils;

{$R *.DFM}

procedure ServiceController(CtrlCode: DWord); stdcall;
begin
  ogcvdispensarios_triton.Controller(CtrlCode);
end;

function Togcvdispensarios_triton.GetServiceController: TServiceController;
begin
  Result := ServiceController;
end;

procedure Togcvdispensarios_triton.ServiceExecute(Sender: TService);
var
  config:TIniFile;
begin
  try
    ListaLog:=TStringList.Create;
    ListaLogPetRes:=TStringList.Create;
    config:= TIniFile.Create(ExtractFilePath(ParamStr(0)) +'PDISPENSARIOS.ini');
    rutaLog:=config.ReadString('CONF','RutaLog','C:\ImagenCo');
    ClientSocket1.Host:=ExtraeElemStrSep(config.ReadString('CONF','ServidorSocket','127.0.0.1:1004'), 1, ':');
    ClientSocket1.Port:=StrToInt(ExtraeElemStrSep(config.ReadString('CONF','ServidorSocket','127.0.0.1:1004'), 2, ':'));
    minutosLog:=StrToInt(config.ReadString('CONF','MinutosLog','0'));
    estado:=-1;
    horaLog:=Now;
    HoraArranque:=Now;
    detenido:=True;
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

procedure Togcvdispensarios_triton.SetEstadoJSON(const AEstado: Integer);
var
  estadoNode: TlkJSONbase;
begin
  estadoNode := rootJSON.Field['Estado'];

  if Assigned(estadoNode) then
    estadoNode.Value := AEstado
  else
    TlkJSONObject(rootJSON).Add('Estado', TlkJSONnumber.Generate(AEstado));
end;

procedure Togcvdispensarios_triton.AgregaLogPetRes(lin: string);
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

procedure Togcvdispensarios_triton.GuardarLog(folio: Integer);
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

procedure Togcvdispensarios_triton.AgregaLog(lin: string);
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

procedure Togcvdispensarios_triton.GuardarLogPetRes(folio: Integer);
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

procedure Togcvdispensarios_triton.AddPeticionJSON(const aFolio: Integer;
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

procedure Togcvdispensarios_triton.ClientSocket1Connect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
  conectado:=True;
end;

procedure Togcvdispensarios_triton.ClientSocket1Disconnect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
  conectado:=False;
  Timer1.Enabled:=False;
  Timer2.Enabled:=True;
end;

procedure Togcvdispensarios_triton.Timer2Timer(Sender: TObject);
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
    Timer2.Enabled:=estado<=0;
  end;
end;

procedure Togcvdispensarios_triton.Responder(resp: string);
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

procedure Togcvdispensarios_triton.ClientSocket1Read(Sender: TObject;
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

procedure Togcvdispensarios_triton.Inicializar(folio: Integer;
  msj: string);
var
  js: TlkJSONBase;
  consolas,dispensarios,productos: TlkJSONbase;
  datosPuerto,json,resultado:string;
  i:Integer;
begin
  try
    if estado>-1 then begin
      resultado:='False|El servicio ya habia sido inicializado|';
      AddPeticionJSON(folio, resultado);
      Exit;
    end;

    json:=ExtraeElemStrSep(msj,1,'|');

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

    productos := js.Field['Products'];

    for i:=0 to productos.Count-1 do begin
      if productos.Child[i].Field['Price'].Value<0 then begin
        AddPeticionJSON(folio, 'False|El precio '+IntToStr(productos.Child[i].Field['ProductId'].Value)+' es incorrecto|');
        Exit;
      end;

      TPosCarga[1].precio:=productos.Child[i].Field['Price'].Value;
      verificaPrecio:=True;
    end;

    estado:=0;
    AddPeticionJSON(folio, 'True|');
  except
    on e:Exception do
      AddPeticionJSON(folio, 'False|Excepcion: '+e.Message+'|');
  end;
end;

function Togcvdispensarios_triton.AgregaPosCarga(
  posiciones: TlkJSONbase): string;
var
  i,j,k,xpos,xcomb:integer;
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
      tag:=1;
      estatus:=-1;
      estatusant:=-1;
      NoComb:=0;
      for j:=1 to 4 do
        TotalLitros[j]:=0;
      Importeant:=0;
      finventa:=0;
    end;

    posArr := TlkJSONlist.Create;

    for i:=0 to posiciones.Count-1 do begin
      xpos:=posiciones.Child[i].Field['DispenserId'].Value;
      if (xpos>0)and(xpos>MaxPosCarga) then
        MaxPosCarga:=xpos;
      with TPosCarga[xpos] do begin
        posObj := TlkJSONObject.Create;
        posObj.Add('DispenserId', xpos);
        posObj.Add('HoraOcc', FormatDateTime('yyyy-mm-dd',0)+'T'+FormatDateTime('hh:nn',0));
        posObj.Add('Manguera', 0);
        posObj.Add('Combustible', 0);
        posObj.Add('Estatus', 0);
        posObj.Add('Importe', 0);
        posObj.Add('Volumen', 0);
        posObj.Add('Precio', 0);

        if posiciones.Child[i].Field['OperationMode'].Value = 'FULLSERVICE' then
          ModoOpera := 'Normal'
        else
          ModoOpera := 'Prepago';

        hosesArr := TlkJSONlist.Create;
        existe:=false;

        mangueras:=posiciones.Child[i].Field['Hoses'];
        for j:=0 to mangueras.Count-1 do begin
          xcomb:=mangueras.Child[j].Field['ProductId'].Value;

          if xcomb=0 then
            Continue;

          for k:=1 to NoComb do
            if TComb[k]=xcomb then
              existe:=true;
          if not existe then begin
            inc(NoComb);
            TComb[NoComb]:=xcomb;
            TMang[NoComb]:=mangueras.Child[j].Field['HoseId'].Value;

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
    TlkJSONobject(rootJSON).Add('PosCarga',   posArr);
  except
    on e:Exception do
      Result:='False|Excepcion: '+e.Message+'|';
  end;
end;

function Togcvdispensarios_triton.IniciaPSerial(
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

procedure Togcvdispensarios_triton.ComandoConsola(ss: string);
begin
  try
    if (not esperandoResp) or (SecondsBetween(Now, horaEnvio)>=2) then begin
      ss:=#2+ss+#3;
      if pSerial.OutBuffFree >= Length(ss) then begin
        AgregaLog('E: '+ss);
        if pSerial.Open then
          pSerial.PutString(ss);
        horaEnvio:=Now;
        esperandoResp:=True;
      end;
    end;
  except
    on e:Exception do begin
      AgregaLog('Error ComandoConsola: '+e.Message);
      GuardarLog(0);
    end;
  end;
end;

procedure Togcvdispensarios_triton.IniciaPrecios(folio: Integer;
  msj: string);
var
  precioComb:Double;
  xpos,i:Integer;
  entro:Boolean;
begin
  try
    for i:=1 to NoElemStrSep(msj,'|') do begin
      precioComb:=StrToFloatDef(ExtraeElemStrSep(msj,i,'|'),-1);
      if precioComb<=0 then
        Continue;
      if precioComb>=0.01 then begin
        ComandoConsola('WU'+StringReplace(FormatFloat('0000.00', precioComb),'.','',[]));
        TPosCarga[1].precio:=precioComb;
        Sleep(100);
      end;
    end;
    AddPeticionJSON(folio, 'True|');
  except
    on e:Exception do
      AddPeticionJSON(folio, 'False|Excepcion: '+e.Message+'|');
  end;
end;

procedure Togcvdispensarios_triton.AutorizarVenta(folio: Integer;
  msj: string);
var
  tipo,cantidad:string;
begin
  try
    if not TPosCarga[1].SwDesHabil then begin
      if StrToFloatDef(ExtraeElemStrSep(msj,4,'|'),0)>0 then begin
        cantidad:=ExtraeElemStrSep(msj,4,'|');
        tipo:='V';
      end
      else if StrToFloatDef(ExtraeElemStrSep(msj,3,'|'),-99)<>-99 then begin
        cantidad:=ExtraeElemStrSep(msj,3,'|');
        tipo:='$';
      end
      else begin
        AddPeticionJSON(folio,'False|Favor de indicar la cantidad que se va a despachar|');
        Exit;
      end;

      ActualizaCampoJSON(1,'HoraOcc',FormatDateTime('yyyy-mm-dd',Now)+'T'+FormatDateTime('hh:nn',Now));
      ComandoConsola('AP'+tipo+StringReplace(FormatFloat('00000.00',StrToFloat(cantidad)),'.','',[]));

      AddPeticionJSON(folio, 'True|');
    end
    else
      AddPeticionJSON(folio, 'False|Posicion se encuentra deshabilitada');
  except
    on e:Exception do
      AddPeticionJSON(folio, 'False|Excepcion: '+e.Message+'|');
  end;
end;

function Togcvdispensarios_triton.EjecutaComando(xCmnd: string): integer;
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

procedure Togcvdispensarios_triton.FinVenta(folio: Integer; msj: string);
begin
  try
    ComandoConsola('CS');

    AddPeticionJSON(folio, 'True|');
  except
    on e:Exception do
      AddPeticionJSON(folio, 'False|Excepcion: '+e.Message+'|');
  end;
end;

procedure Togcvdispensarios_triton.TotalesBomba(folio: Integer;
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

procedure Togcvdispensarios_triton.Detener(folio: Integer);
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
    on e:Exception do
      AddPeticionJSON(folio, 'False|'+e.Message+'|');
  end;
end;

procedure Togcvdispensarios_triton.Iniciar(folio: Integer);
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

procedure Togcvdispensarios_triton.Shutdown(folio: Integer);
begin
  if estado>0 then
    AddPeticionJSON(folio, 'False|El servicio esta en proceso, no fue posible detenerlo|')
  else begin
    AddPeticionJSON(folio, 'True|');
    ServiceThread.Terminate;
  end;
end;

procedure Togcvdispensarios_triton.Login(folio: Integer; mensaje: string);
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

procedure Togcvdispensarios_triton.Logout(folio: Integer);
begin
  Token:='';
  AddPeticionJSON(folio, 'True|')
end;

procedure Togcvdispensarios_triton.Terminar(folio: Integer);
begin
  if estado>0 then
    AddPeticionJSON(folio, 'False|El servicio no esta detenido, no es posible terminar la comunicacion|')
  else begin
    Timer1.Enabled:=False;
    pSerial.Open:=False;
    estado:=-1;
    SetEstadoJSON(estado);
    AddPeticionJSON(folio, 'True|');
  end;
end;

procedure Togcvdispensarios_triton.RespuestaComando(folio: Integer;
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

function Togcvdispensarios_triton.ResultadoComando(
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
      Result:='False|'+e.Message;
  end;
end;

procedure Togcvdispensarios_triton.ObtenerLog(folio, r: Integer);
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

procedure Togcvdispensarios_triton.ObtenerLogPetRes(folio, r: Integer);
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

function Togcvdispensarios_triton.MD5(const usuario: string): string;
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

procedure Togcvdispensarios_triton.Timer1Timer(Sender: TObject);
begin
  try
    if CmndNuevo then
      ProcesaComandos
    else
      ComandoConsola('ST');
  except
    on e:Exception do
      AgregaLog('Excepcion Timer1Timer: '+e.Message+'|');
  end;
end;

procedure Togcvdispensarios_triton.DetenerVenta(folio: Integer;
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

procedure Togcvdispensarios_triton.ProcesaComandos;
var ss,rsp,scmnd,precios      :string;
    xcmnd,xpos,xcomb,
    xp,xfolio,i               :integer;
    ximporte,xlitros,nprec  :real;
    SwAplicaCmnd:Boolean;
begin
  try
    CmndNuevo:=False;
    for xcmnd:=1 to 200 do begin
      if (TabCmnd[xcmnd].SwActivo)and(not TabCmnd[xcmnd].SwResp) then begin
        SwAplicaCmnd:=true;
        scmnd:=TabCmnd[xcmnd].Comando;
        ss:=ExtraeElemStrSep(scmnd,1,' ');
        AgregaLog(scmnd);
        if (ss='TOTAL') then begin
          xpos:=StrToIntDef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,2,' '),0);
          SwAplicaCmnd:=False;
          if (TabCmnd[xcmnd].SwNuevo) and (SecondsBetween(Now,TPosCarga[xpos].HoraTotales)>10) then begin
            ComandoConsola('TT');
            TPosCarga[xpos].EsperandoTotales:=True;
          end
          else if not TPosCarga[xpos].EsperandoTotales then begin
            rsp:='OK'+FormatFloat('0.000',TPosCarga[xpos].TotalLitros[1])+'|'+FormatoMoneda(TPosCarga[xpos].TotalLitros[1]*TPosCarga[xpos].precio)+'||||';
            SwAplicaCmnd:=True;
          end;
        end
        else if (ss='DVC') then begin
          rsp:='OK';
          xpos:=strtointdef(ExtraeElemStrSep(TabCmnd[xcmnd].Comando,2,' '),0);
          if xpos in [1..MaxPosCarga] then begin
            if (TPosCarga[xpos].estatus in [2,9]) then
              ComandoConsola('DE');
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

procedure Togcvdispensarios_triton.pSerialTriggerAvail(CP: TObject; Count: Word);
var
  I: Word;
  ch: AnsiChar;
  b: Byte;

  function ToAsciiByte(x: Byte): AnsiString;
  begin
    x := x and $7F;
    case x of
      13: Result := #13#10;
      10: Result := '';
      32..126: Result := AnsiChar(x);
    else
      Result := '';
    end;
  end;

begin
  esperandoResp:=False;
  for I := 1 to Count do begin
    ch := pSerial.GetChar;
    b  := Byte(ch);

    if b = 2 then begin
      stx := True;
      etx := False;
      respPSerial := '';
      Continue;
    end;

    if b = 3 then begin
      etx := True;
      stx := False;
      Break;
    end;

    if stx then
      respPSerial := respPSerial + ToAsciiByte(b);
  end;

  if etx then begin
    AgregaLog('R: ' + respPSerial);
    ProcesaLinea(respPSerial);
    respPSerial := '';
    etx := False;
    Responder(TlkJSON.GenerateText(rootJSON));
  end;
end;

procedure Togcvdispensarios_triton.ProcesaLinea(xlin: string);
var
  cmd:string;
begin
  try
    if (xlin='') then
      exit;
    cmd:=ExtraeElemStrSep(xlin,1,',');

    if cmd='ST' then begin
      with TPosCarga[1] do begin
        estatusant:=estatus;
        estatus:=StrToIntDef(ExtraeElemStrSep(xlin,2,','),0);

        if estatus = 3 then
          estatus := 5
        else if estatus = 4 then
          estatus := 2
        else if estatus = 5 then
          estatus := 3;

        volumen:=StrToFloatDef(InsertaDecimal(ExtraeElemStrSep(xlin,4,','),2),0);
        importe:=StrToFloatDef(InsertaDecimal(ExtraeElemStrSep(xlin,5,','),2),0);
        ActualizaCampoJSON(1,'Volumen',Volumen);
        ActualizaCampoJSON(1,'Precio',precio);
        ActualizaCampoJSON(1,'Importe',importe);
        ActualizaCampoJSON(1,'Estatus',estatus);
        ActualizaCampoJSON(1,'Combustible',1);
        ActualizaCampoJSON(1,'Manguera',1);

        if (verificaPrecio) and (estatus=1) then begin
          Sleep(50);
          ComandoConsola('RU');
        end
        else if estatus=3 then begin
          Sleep(50);
          ComandoConsola('CS');
        end
        else if (estatus=5) and (TPosCarga[1].ModoOpera='Normal') and (not TPosCarga[1].SwDesHabil) then begin
          Sleep(50);
          ActualizaCampoJSON(1,'HoraOcc',FormatDateTime('yyyy-mm-dd',Now)+'T'+FormatDateTime('hh:nn',Now));
          ComandoConsola('AT');
        end;
      end;
    end
    else if cmd='RU' then begin
      if FormatFloat('0000.00', TPosCarga[1].precio)<>FormatFloat('0000.00', StrToFloatDef(InsertaDecimal(ExtraeElemStrSep(xlin,2,','),2),0)) then
        ComandoConsola('WU'+StringReplace(FormatFloat('0000.00', TPosCarga[1].precio),'.','',[]))
      else
        verificaPrecio:=False;
    end
    else if cmd='TT' then begin
      with TPosCarga[1] do begin
        HoraTotales:=Now;
        TotalLitros[1]:=StrToFloatDef(InsertaDecimal(ExtraeElemStrSep(xlin,2,','),3),0);
        ApplyTotalLitrosToJSON(1,TotalLitros);
        EsperandoTotales:=False;
        ProcesaComandos;
      end;
    end;
  except
    on e:Exception do begin
      AgregaLog('Error ProcesaLinea: '+e.Message);
      GuardarLog(0);
    end;
  end;
end;

function Togcvdispensarios_triton.InsertaDecimal(const S: string;
  Decimales: Integer): string;
var
  Len: Integer;
begin
  if Pos('.', S) > 0 then
  begin
    Result := S;
    Exit;
  end;

  Len := Length(S);
  if Decimales <= 0 then
    Result := S
  else if Decimales >= Len then
    Result := '0.' + StringOfChar('0', Decimales - Len) + S
  else
    Result := Copy(S, 1, Len - Decimales) + '.' + Copy(S, Len - Decimales + 1, Decimales);
end;

procedure Togcvdispensarios_triton.ActualizaCampoJSON(xpos: Integer;
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

procedure Togcvdispensarios_triton.ApplyTotalLitrosToJSON(
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

procedure Togcvdispensarios_triton.ActivaModoPrepago(folio: Integer;
  msj: string);
var
  xpos: Integer;
begin
  try
    xpos := StrToIntDef(msj, -1);
    if xpos = -1 then
    begin
      AddPeticionJSON(folio, 'False|Favor de indicar correctamente la posicion de carga|');
      Exit;
    end;

    if xpos = 0 then
    begin
      for xpos := 1 to MaxPosCarga do
        TPosCarga[xpos].ModoOpera := 'Prepago';
    end
    else if (xpos in [1..maxposcarga]) then
      TPosCarga[xpos].ModoOpera := 'Prepago';

    AddPeticionJSON(folio, 'True|');
  except
    on e: Exception do
      AddPeticionJSON(folio, 'False|Excepcion: ' + e.Message + '|');
  end;
end;

procedure Togcvdispensarios_triton.DesactivaModoPrepago(folio: Integer;
  msj: string);
var
  xpos: Integer;
begin
  try
    xpos := StrToIntDef(msj, -1);
    if xpos = -1 then
    begin
      AddPeticionJSON(folio, 'False|Favor de indicar correctamente la posicion de carga|');
      Exit;
    end;

    if xpos = 0 then
    begin
      for xpos := 1 to MaxPosCarga do
        TPosCarga[xpos].ModoOpera := 'Normal';
    end
    else if (xpos in [1..maxposcarga]) then
      TPosCarga[xpos].ModoOpera := 'Normal';

    AddPeticionJSON(folio, 'True|');
  except
    on e: Exception do
      AddPeticionJSON(folio, 'False|Excepcion: ' + e.Message + '|');
  end;
end;
procedure Togcvdispensarios_triton.Bloquear(folio: Integer; msj: string);
var
  xpos: Integer;
begin
  try
    TPosCarga[1].SwDesHabil := True;
    AddPeticionJSON(folio, 'True|');
  except
    on e: Exception do
      AddPeticionJSON(folio, 'False|Excepcion: ' + e.Message + '|');
  end;
end;

procedure Togcvdispensarios_triton.Desbloquear(folio: Integer;
  msj: string);
var
  xpos: Integer;
begin
  try
    TPosCarga[1].SwDesHabil := False;
    AddPeticionJSON(folio, 'True|');
  except
    on e: Exception do
      AddPeticionJSON(folio, 'False|Excepcion: ' + e.Message + '|');
  end;
end;

end.
