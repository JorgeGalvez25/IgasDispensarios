
unit OG_Hasp;

interface

uses
  SysUtils, hasp_unit, LbCipher, LbString;

type
  THaspKeyOG = class
    PermisoCRE : string;
    Key3DES : string;
    CENAM : string;
    Vencimiento : TDateTime;
    Status : hasp_status_t;
    StatusMessage : string;
  private
    HaspHandle : hasp_handle_t;
    procedure ReadOnly;
    procedure ReadWrite;
    function ByteArrayToString(const buffer: array of Byte): String;
    function GetMesage(const status : hasp_status_t) : string;
  public
    function Encrypt(const data: string) : string;
    function Decrypt(const data: string) : string;
    procedure Logout;
  end;

  THaspOG = class
  public
    class function Login(const vendorCode: AnsiString; const keyId: string) : THaspKeyOG;
  end;
  
const
  HASP_INVALID_FILE_SIZE = 1001;

implementation

{ THaspOG }

class function THaspOG.Login(const vendorCode: AnsiString;
  const keyId: string): THaspKeyOG;
const
  SCOPE_VIEW_MAXSIZE = (1024 * 128);
var
  keyIdScope : Array[0..SCOPE_VIEW_MAXSIZE-1] of AnsiChar;
  haspHandle : hasp_handle_t;
begin
  Result := THaspKeyOG.Create;

//  strpcopy(keyIdScope, '<haspscope><hasp id="' + keyId + '"/></haspscope>');
//
//  Result.Status := hasp_login_scope(HASP_DEFAULT_FID, keyIdScope, @vendorCode[1], haspHandle);
//  Result.StatusMessage := Result.GetMesage(Result.Status);
//
//  if Result.Status <> HASP_STATUS_OK then
//    Exit;
//
//  Result.HaspHandle := haspHandle;
//
//  Result.ReadOnly;
//
//  if Result.Status <> HASP_STATUS_OK then
//    Exit;
//
//  Result.ReadWrite;

  Result.Status:=HASP_STATUS_OK;
  Result.StatusMessage := Result.GetMesage(Result.Status);
  Result.Vencimiento:=0;
  Result.PermisoCRE:='PL/9580/EXP/ES/2015';
  Result.Key3DES:='8FDEEECF8548D9052CCE98A0B2A9736A';
//  Result.PermisoCRE:='PL/21121/EXP/ES/2018';
//  Result.Key3DES:='BA7531BE5316010FE34B3EFE352C546A';
  Result.CENAM:='';
end;

{ THaspKeyOG }

function THaspKeyOG.Encrypt(const data: string): string;
var
  key128 : TKey128;
  dataIn,dataOut : string;
begin
  dataIn := UTF8Encode(data);
  GenerateMD5Key(key128, Key3DES);
  TripleDESEncryptString(dataIn,dataOut,key128,true);
  Result := dataOut;
end;

function THaspKeyOG.Decrypt(const data: string): string;
var
  key128 : TKey128;
  dataOut : string;
begin
  GenerateMD5Key(key128, Key3DES);
  TripleDESEncryptString(data,dataOut,key128,false);
  dataOut := UTF8Decode(dataOut);
  Result := dataOut;
end;

procedure THaspKeyOG.Logout;
begin
  Status := hasp_logout(HaspHandle);
  StatusMessage := GetMesage(Status);

  if Status = HASP_STATUS_OK then begin
    PermisoCRE := EmptyStr;
    Key3DES := EmptyStr;
    CENAM := EmptyStr;
    Vencimiento := 0;
    HaspHandle := 0;
  end;
end;

procedure THaspKeyOG.ReadOnly;
var
  size : hasp_size_t;
  buffer : array [0..53] of byte;
  data : string;
begin
  Status := hasp_get_size(HaspHandle, HASP_FILEID_RO, size);
  StatusMessage := GetMesage(Status);

  if Status <> HASP_STATUS_OK then
    Exit;

  if size < 53 then begin
    Status := HASP_INVALID_FILE_SIZE;
    StatusMessage := 'Invalid file size: ' + IntToStr(size);
    Exit;
  end;

  Status := hasp_read(HaspHandle, HASP_FILEID_RO, 0, 53, buffer);
  StatusMessage := GetMesage(Status);

  if Status <> HASP_STATUS_OK then
    Exit;

  data := ByteArrayToString(buffer);
  PermisoCRE := Trim(Copy(data,1,21));
  key3DES := Trim(Copy(data,22,32));
end;

procedure THaspKeyOG.ReadWrite;
var
  size : hasp_size_t;
  buffer : array [0..40] of byte;
  data,aastr,mmstr,ddstr : string;
  aa,mm,dd : Integer;
begin
  Status := hasp_get_size(HaspHandle, HASP_FILEID_RW, size);
  StatusMessage := GetMesage(Status);

  if Status <> HASP_STATUS_OK then
    Exit;

  if size < 40 then begin
    Status := HASP_INVALID_FILE_SIZE;
    StatusMessage := 'Invalid file size: ' + IntToStr(size);
    Exit;
  end;

  Status := hasp_read(HaspHandle, HASP_FILEID_RW, 0, 40, buffer);
  StatusMessage := GetMesage(Status);

  if Status <> HASP_STATUS_OK then
    Exit;

  data := ByteArrayToString(buffer);
  CENAM := Trim(Copy(data,1,32));

  aastr := Trim(Copy(data,33,4));
  mmstr := Trim(Copy(data,37,2));
  ddstr := Trim(Copy(data,39,2));
  aa := StrToIntDef(aastr,0);
  mm := StrToIntDef(mmstr,0);
  dd := StrToIntDef(ddstr,0);
  if (aa > 0) and (mm > 0) and (dd > 0) then
    Vencimiento := EncodeDate(aa,mm,dd)
  else
    Vencimiento := 0;
end;

function THaspKeyOG.ByteArrayToString(const buffer: array of Byte): String;
var
  size:Integer;
  i:Integer;
  x:Char;
begin
  size := Length(buffer);
  SetLength(Result,size);

  for i:=0 to size-1 do begin
    x := AnsiChar(buffer[i]);
    if x = #0 then
      Result[i+1]:=' '
    else
      Result[i+1]:=x;
  end;
end;

function THaspKeyOG.GetMesage(const status: hasp_status_t): string;
begin
  case status of
      HASP_STATUS_OK: Result := ' Request successfully completed ';
      HASP_MEM_RANGE: Result := 'Request exceeds memory range of a HASP file';
      HASP_INV_PROGNUM_OPT: Result := 'Legacy HASP HL Run-time API: Unknown/Invalid Feature ID option';
      HASP_INSUF_MEM: Result := 'System is out of memory';
      HASP_TMOF: Result := 'Too many open Features/login sessions';
      HASP_ACCESS_DENIED: Result := 'Access to Feature, HASP protection key or functionality denied';
      HASP_INCOMPAT_FEATURE: Result := 'Legacy decryption function cannot work on Feature';
      HASP_HASP_NOT_FOUND: Result := 'Sentinel HASP protection key not available';
      HASP_TOO_SHORT: Result := 'Encrypted/decrypted data length too short to execute function call';
      HASP_INV_HND: Result := 'Invalid login handle passed to function';
      HASP_INV_FILEID: Result := 'Specified File ID not recognized by API';
      HASP_OLD_DRIVER: Result := 'Installed driver or daemon too old to execute function';
      HASP_NO_TIME: Result := 'Real-time clock (rtc) not available';
      HASP_SYS_ERR: Result := 'Generic error from host system call';
      HASP_NO_DRIVER: Result := 'Required driver not installed';
      HASP_INV_FORMAT: Result := 'Unrecognized file format for update';
      HASP_REQ_NOT_SUPP: Result := 'Unable to execute function in this context';
      HASP_INV_UPDATE_OBJ: Result := 'Binary data passed to function does not contain valid update';
      HASP_KEYID_NOT_FOUND: Result := 'HASP protection key not found';
      HASP_INV_UPDATE_DATA: Result := 'Required XML tags not found Contents in binary data are missing';
      HASP_INV_UPDATE_NOTSUPP: Result := 'Update request not supported by Sentinel HASP protection key';
      HASP_INV_UPDATE_CNTR: Result := 'Update counter set incorrectly';
      HASP_INV_VCODE: Result := 'Invalid Vendor Code passed';
      HASP_ENC_NOT_SUPP: Result := 'Sentinel HASP protection key does not support encryption type';
      HASP_INV_TIME: Result := 'Passed time value outside supported value range';
      HASP_NO_BATTERY_POWER: Result := 'Real-time clock battery out of power';
      HASP_NO_ACK_SPACE: Result := 'Acknowledge data requested by update, but ack_data parameter is null';
      HASP_TS_DETECTED: Result := 'Program running on a terminal server';
      HASP_FEATURE_TYPE_NOT_IMPL: Result := 'Requested Feature type not implemented';
      HASP_UNKNOWN_ALG: Result := 'Unknown algorithm used in H2R/V2C file';
      HASP_INV_SIG: Result := 'Signature verification operation failed';
      HASP_FEATURE_NOT_FOUND: Result := 'Requested Feature not available';
      HASP_NO_LOG: Result := 'Access log not enabled';
      HASP_LOCAL_COMM_ERR: Result := 'Communication error between API and local HASP License Manager';
      HASP_UNKNOWN_VCODE: Result := 'Vendor Code not recognized by API';
      HASP_INV_SPEC: Result := 'Invalid XML specification';
      HASP_INV_SCOPE: Result := 'Invalid XML scope';
      HASP_TOO_MANY_KEYS: Result := 'Too many Sentinel HASP protection keys currently connected';
      HASP_TOO_MANY_USERS: Result := 'Too many concurrent user sessions currently connected';
      HASP_BROKEN_SESSION: Result := 'Session been interrupted';
      HASP_REMOTE_COMM_ERR: Result := 'Communication error between local and remote HASP License Managers';
      HASP_FEATURE_EXPIRED: Result := 'Feature expired';
      HASP_OLD_LM: Result := 'HASP License Manager version too old';
      HASP_DEVICE_ERR: Result := 'Input/Output error occurred';
      HASP_UPDATE_BLOCKED: Result := 'Update installation not permitted This update was already applied';
      HASP_TIME_ERR: Result := 'System time has been tampered with';
      HASP_SCHAN_ERR: Result := 'Communication error occurred in secure channel';
      HASP_STORAGE_CORRUPT: Result := 'Corrupt data exists in secure storage area of HASP SL protection key';
      HASP_NO_VLIB: Result := 'Unable to find Vendor library';
      HASP_INV_VLIB: Result := 'Unable to load Vendor library';
      HASP_SCOPE_RESULTS_EMPTY: Result := 'Unable to locate any Feature matching scope';
      HASP_VM_DETECTED: Result := 'Program running on a virtual machine';
      HASP_HARDWARE_MODIFIED: Result := 'HASP SL key incompatible';
      HASP_USER_DENIED: Result := 'Login denied because of user restrictions';
      HASP_UPDATE_TOO_OLD: Result := 'out of sequence';
      HASP_UPDATE_TOO_NEW: Result := 'Update to old';
      HASP_OLD_VLIB: Result := 'Old vlib';
      HASP_UPLOAD_ERROR: Result := 'Upload via ACC failed, e.g. because of illegal format';
      HASP_INV_RECIPIENT: Result := 'Invalid XML "recipient" parameter';
      HASP_INV_DETACH_ACTION: Result := 'Invalid XML "action" parameter';
      HASP_TOO_MANY_PRODUCTS: Result := 'scope does not specify a unique product';
      HASP_INV_PRODUCT: Result := 'Invalid Product information';
      HASP_UNKNOWN_RECIPIENT: Result := 'Unknown Recipient';
      HASP_INV_DURATION: Result := 'Invalid Duration';
      HASP_CLONE_DETECTED: Result := 'Cloned HASP SL secure storage detected';
      HASP_UPDATE_ALREADY_ADDED: Result := 'Specified v2c update already installed in the LLM';
      HASP_HASP_INACTIVE: Result := 'Specified Hasp Id is in Inactive state';
      HASP_NO_DETACHABLE_FEATURE: Result := 'No detachable feature exists';
      HASP_TOO_MANY_HOSTS: Result := 'scope does not specify a unique Host';
      HASP_REHOST_NOT_ALLOWED: Result := 'Rehost is not allowed for any license';
      HASP_LICENSE_REHOSTED: Result := 'License is rehosted to other machine';
      HASP_REHOST_ALREADY_APPLIED: Result := 'Old rehost license try to apply';
      HASP_CANNOT_READ_FILE: Result := 'File not found or access denied';
      HASP_EXTENSION_NOT_ALLOWED: Result := 'Extension of license not allowed as number of detached licenses is greater than current concurrency count';
      HASP_DETACH_DISABLED: Result := 'Detach of license not allowed as product contains VM disabled feature and host machine is a virtual machine';
      HASP_REHOST_DISABLED: Result := 'Rehost of license not allowed as container contains VM disabled feature and host machine is a virtual machine';
      HASP_DETACHED_LICENSE_FOUND: Result := 'Format SL-AdminMode or migrate SL-Legacy to SL-AdminMode not allowed as container has detached license';
      HASP_RECIPIENT_OLD_LM: Result := 'Recipient of the requested operation is older than expected';
      HASP_SECURE_STORE_ID_MISMATCH: Result := 'Secure storage ID mismatch';
      HASP_NO_API_DYLIB: Result := 'API dispatcher: API for this Vendor Code was not found';
      HASP_INV_API_DYLIB: Result := 'API dispatcher: Unable to load API DLL possibly corrupt?';
      HASP_INVALID_OBJECT: Result := 'C++ API: Object incorrectly initialized';
      HASP_INVALID_PARAMETER: Result := 'C++ API: Invalid function parameter';
      HASP_ALREADY_LOGGED_IN: Result := 'C++ API: Logging in twice to the same object';
      HASP_ALREADY_LOGGED_OUT: Result := 'C++ API: Logging out twice of the same object';
      HASP_OPERATION_FAILED: Result := '.NET API: Incorrect use of system or platform';
      HASP_NO_EXTBLOCK: Result := 'Internal use: no classic memory extension block available';
      HASP_INV_PORT_TYPE: Result := 'Internal use: invalid port type';
      HASP_INV_PORT: Result := 'Internal use: invalid port value';
      HASP_NOT_IMPL: Result := 'Requested function not implemented';
      HASP_INT_ERR: Result := 'Internal error occurred in API';
      HASP_FIRST_HELPER: Result := 'Reserved for HASP helper libraries';
      HASP_FIRST_HASP_ACT: Result := 'Reserved for HASP Activation API';
      else
          Result := 'Unidentified status: ' + IntToStr(status);
    end;
end;

end.
