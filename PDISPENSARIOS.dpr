program PDISPENSARIOS;

uses
  SvcMgr,
  IniFiles,
  SysUtils,
  uLkJSON in 'uLkJSON.pas',
  CRCs in 'CRCs.pas',
  IdHashMessageDigest in 'IdHashMessageDigest.pas',
  IdHash in 'IdHash.pas',
  OG_Hasp in 'OG_Hasp.pas',
  UVersionModulo in 'UVersionModulo.pas',
  UIGASPAM in 'UIGASPAM.pas' {ogcvdispensarios_pam: TService},
  UIGASBENNETT in 'UIGASBENNETT.pas' {ogcvdispensarios_bennett: TService},  
  UIGASWAYNE in 'UIGASWAYNE.pas' {ogcvdispensarios_wayne: TService},
  UIGASHONGYANG in 'UIGASHONGYANG.pas' {ogcvdispensarios_hongyang: TService},
  UIGASGILBARCO in 'UIGASGILBARCO.pas' {ogcvdispensarios_gilbarco2W: TService},
  UIGASKAIROS in 'UIGASKAIROS.pas' {ogcvdispensarios_kairos: TService},
  UIGASTEAM in 'UIGASTEAM.pas' {ogcvdispensarios_team: TService},
  UIGASWAYNE2W in 'UIGASWAYNE2W.pas' {ogcvdispensarios_wayne2w: TService},
  UIGASTRITON in 'UIGASTRITON.pas' {ogcvdispensarios_triton: TService};

{$R *.RES}
var
  config:TIniFile;
  marca:Integer;


begin
  Application.Initialize;

  config:=TIniFile.Create(ExtractFilePath(ParamStr(0)) + 'PDISPENSARIOS.ini');
  marca:=StrToInt(config.ReadString('CONF','Marca','0'));

  case marca of
    1:begin
        Application.CreateForm(Togcvdispensarios_wayne, ogcvdispensarios_wayne);
      end;
    2:begin
        Application.CreateForm(Togcvdispensarios_bennett, ogcvdispensarios_bennett);
      end;
    3:begin
        Application.CreateForm(Togcvdispensarios_team, ogcvdispensarios_team);
      end;
    4:begin
        Application.CreateForm(Togcvdispensarios_pam, ogcvdispensarios_pam);
      end;
    5:begin
        Application.CreateForm(Togcvdispensarios_hongyang, ogcvdispensarios_hongyang);
      end;
    6:begin
        Application.CreateForm(Togcvdispensarios_gilbarco2W, ogcvdispensarios_gilbarco2W);
      end;
    7:begin
        Application.CreateForm(Togcvdispensarios_kairos, ogcvdispensarios_kairos);
      end;
    9:begin
        Application.CreateForm(Togcvdispensarios_wayne2w, ogcvdispensarios_wayne2w);
      end;
   10:begin
        Application.CreateForm(Togcvdispensarios_triton, ogcvdispensarios_triton);
      end;
  end;
  
  Application.Run;
end.

