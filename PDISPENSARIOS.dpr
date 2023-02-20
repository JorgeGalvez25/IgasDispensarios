program PDISPENSARIOS;

uses
  SvcMgr,
  IniFiles,
  SysUtils,
  UIGASPAM in 'UIGASPAM.pas' {ogcvdispensarios_pam: TService},
  UIGASBENNETT in 'UIGASBENNETT.pas' {ogcvdispensarios_bennett: TService},
  uLkJSON in 'uLkJSON.pas',
  CRCs in 'CRCs.pas',
  IdHashMessageDigest in 'IdHashMessageDigest.pas',
  IdHash in 'IdHash.pas',
  OG_Hasp in 'OG_Hasp.pas',
  UIGASWAYNE in 'UIGASWAYNE.pas' {ogcvdispensarios_wayne: TService},
  UIGASHONGYANG in 'UIGASHONGYANG.pas' {ogcvdispensarios_hongyang: TService};

{$R *.RES}
var
  config:TIniFile;
  marca:string;
begin
  Application.Initialize;

  config:= TIniFile.Create(ExtractFilePath(ParamStr(0)) +'PDISPENSARIOS.ini');
  marca:=config.ReadString('CONF','Marca','X');
  if marca='1' then
    Application.CreateForm(Togcvdispensarios_wayne, ogcvdispensarios_wayne);
  if marca='2' then
    Application.CreateForm(Togcvdispensarios_bennett, ogcvdispensarios_bennett);
  if marca='4' then
    Application.CreateForm(Togcvdispensarios_pam, ogcvdispensarios_pam);
  if marca='5' then
    Application.CreateForm(Togcvdispensarios_hongyang, ogcvdispensarios_hongyang);
  Application.Run;
end.
