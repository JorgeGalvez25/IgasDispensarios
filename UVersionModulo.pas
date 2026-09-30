unit UVersionModulo;

{ Identificacion del ejecutable en uso para agregarla al final de los logs:
  version de archivo, fecha, tamano y MD5, calculados al cargar el programa. }

interface

function InfoVersionModulo(const aModulo: string): string;

implementation

uses
  Windows, SysUtils, Classes;

const
  PROV_RSA_FULL       = 1;
  CRYPT_VERIFYCONTEXT = $F0000000;
  CALG_MD5            = $00008003;
  HP_HASHVAL          = $0002;

function CryptAcquireContext(var phProv: Cardinal; pszContainer, pszProvider: PChar;
  dwProvType, dwFlags: DWORD): BOOL; stdcall; external advapi32 name 'CryptAcquireContextA';
function CryptReleaseContext(hProv: Cardinal; dwFlags: DWORD): BOOL; stdcall;
  external advapi32 name 'CryptReleaseContext';
function CryptCreateHash(hProv, Algid, hKey: Cardinal; dwFlags: DWORD;
  var phHash: Cardinal): BOOL; stdcall; external advapi32 name 'CryptCreateHash';
function CryptHashData(hHash: Cardinal; pbData: Pointer; dwDataLen, dwFlags: DWORD): BOOL; stdcall;
  external advapi32 name 'CryptHashData';
function CryptGetHashParam(hHash: Cardinal; dwParam: DWORD; pbData: Pointer;
  var pdwDataLen: DWORD; dwFlags: DWORD): BOOL; stdcall; external advapi32 name 'CryptGetHashParam';
function CryptDestroyHash(hHash: Cardinal): BOOL; stdcall;
  external advapi32 name 'CryptDestroyHash';

var
  InfoEjecutable: string;

function MD5Archivo(const aArchivo: string; var aTamano: Int64): string;
var
  prov, hash: Cardinal;
  fs: TFileStream;
  buf: array[0..65535] of Byte;
  dig: array[0..15] of Byte;
  n, i: Integer;
  len: DWORD;
begin
  Result:='';
  aTamano:=0;
  if not CryptAcquireContext(prov, nil, nil, PROV_RSA_FULL, CRYPT_VERIFYCONTEXT) then
    Exit;
  try
    if not CryptCreateHash(prov, CALG_MD5, 0, 0, hash) then
      Exit;
    try
      fs:=TFileStream.Create(aArchivo, fmOpenRead or fmShareDenyNone);
      try
        aTamano:=fs.Size;
        repeat
          n:=fs.Read(buf, SizeOf(buf));
          if n>0 then
            CryptHashData(hash, @buf, n, 0);
        until n<=0;
      finally
        fs.Free;
      end;
      len:=SizeOf(dig);
      if CryptGetHashParam(hash, HP_HASHVAL, @dig, len, 0) then
        for i:=0 to Integer(len)-1 do
          Result:=Result+LowerCase(IntToHex(dig[i], 2));
    finally
      CryptDestroyHash(hash);
    end;
  finally
    CryptReleaseContext(prov, 0);
  end;
end;

function VersionArchivo(const aArchivo: string): string;
var
  tam, h: DWORD;
  buf: Pointer;
  fi: PVSFixedFileInfo;
  len: UINT;
begin
  Result:='';
  tam:=GetFileVersionInfoSize(PChar(aArchivo), h);
  if tam=0 then
    Exit;
  GetMem(buf, tam);
  try
    if GetFileVersionInfo(PChar(aArchivo), 0, tam, buf) and
       VerQueryValue(buf, '\', Pointer(fi), len) then
      Result:=Format('%d.%d.%d.%d', [HiWord(fi.dwFileVersionMS), LoWord(fi.dwFileVersionMS),
                                     HiWord(fi.dwFileVersionLS), LoWord(fi.dwFileVersionLS)]);
  finally
    FreeMem(buf);
  end;
end;

function CalculaInfoEjecutable: string;
var
  archivo, md5: string;
  tamano: Int64;
  edad: Integer;
begin
  try
    archivo:=ParamStr(0);
    md5:=MD5Archivo(archivo, tamano);
    edad:=FileAge(archivo);
    Result:='Ejecutable: '+archivo+
            ' | Version archivo: '+VersionArchivo(archivo)+
            ' | Fecha archivo: ';
    if edad<>-1 then
      Result:=Result+FormatDateTime('dd/mm/yyyy hh:nn:ss', FileDateToDateTime(edad));
    Result:=Result+' | Tamano: '+IntToStr(tamano)+' bytes'+
            ' | MD5: '+md5;
  except
    on e:Exception do
      Result:='Ejecutable: '+ParamStr(0)+' | Error al identificar: '+e.Message;
  end;
end;

// Linea con el modulo (marca) activo y la identificacion del ejecutable
function InfoVersionModulo(const aModulo: string): string;
begin
  Result:='Modulo: '+aModulo+' | '+InfoEjecutable;
end;

initialization
  InfoEjecutable:=CalculaInfoEjecutable;

end.
