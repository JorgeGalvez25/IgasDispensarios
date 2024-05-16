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
  UIGASHONGYANG in 'UIGASHONGYANG.pas' {ogcvdispensarios_hongyang: TService},
  UIGASGILBARCO in 'UIGASGILBARCO.pas' {ogcvdispensarios_gilbarco2W: TService},
  UIGASKAIROS in 'UIGASKAIROS.pas' {ogcvdispensarios_kairos: TService},
  UIGASTEAM in 'UIGASTEAM.pas' {ogcvdispensarios_team: TService};

{$R *.RES}
var
  config:TIniFile;
  marca:Integer;
  version:string;

begin
  Application.Initialize;

  version:='898f1badaf01c03b921be926fbd6036c59704531';
  config:=TIniFile.Create(ExtractFilePath(ParamStr(0)) + 'PDISPENSARIOS.ini');
  marca:=StrToInt(config.ReadString('CONF','Marca','0'));

  case marca of
    1:
      begin
        Application.CreateForm(Togcvdispensarios_wayne, ogcvdispensarios_wayne);
        ogcvdispensarios_wayne.version:=version;
      end;
    2:
      begin
        Application.CreateForm(Togcvdispensarios_bennett, ogcvdispensarios_bennett);
        ogcvdispensarios_bennett.version:=version;
      end;
    3:
      begin
        Application.CreateForm(Togcvdispensarios_team, ogcvdispensarios_team);
        ogcvdispensarios_team.version:=version;
      end;
    4:
      begin
        Application.CreateForm(Togcvdispensarios_pam, ogcvdispensarios_pam);
        ogcvdispensarios_pam.version:=version;
      end;
    5:
      begin
        Application.CreateForm(Togcvdispensarios_hongyang, ogcvdispensarios_hongyang);
        ogcvdispensarios_hongyang.version:=version;
      end;
    6:
      begin
        Application.CreateForm(Togcvdispensarios_gilbarco2W, ogcvdispensarios_gilbarco2W);
        ogcvdispensarios_gilbarco2W.version:=version;
      end;
    7:
      begin
        Application.CreateForm(Togcvdispensarios_kairos, ogcvdispensarios_kairos);
        ogcvdispensarios_kairos.version:=version;
      end;
  end;
  
  Application.Run;
end.

