#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
AppId={{E78862F2-F680-4767-A322-275B08EB07D4}
AppName=Retro
AppVersion={#AppVersion}
DefaultDirName={sd}\Retro
DisableDirPage=auto
DirExistsWarning=no
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.19045
WizardStyle=modern
CloseApplications=no
SetupLogging=yes
UsedUserAreasWarning=no
OutputDir=..\dist
OutputBaseFilename=RetroSetup
ExtraDiskSpaceRequired=4294967296
Compression=lzma2
SolidCompression=yes

[Languages]
Name: "pl"; MessagesFile: "compiler:Languages\Polish.isl"; InfoBeforeFile: "info-pl.txt"

[Messages]
pl.SelectDirLabel3=W tym folderze znajdzie się Retro i jego dane. Folder z grami wybierzesz w następnym kroku.
pl.FinishedLabel=Retro jest gotowe. RomM otworzy się w przeglądarce; przy pierwszym uruchomieniu utwórz konto administratora. Gry wrzucaj do podfolderu roms w folderze z grami. Skrót „Graj” uruchamia gry na tym komputerze. Ustawienia zmienisz w menu Start: Retro → Ustawienia Retro.
pl.FinishedLabelNoIcons=Retro jest gotowe.
pl.FinishedRestartLabel=Aby dokończyć instalację, komputer musi zostać uruchomiony ponownie. Po zalogowaniu konfiguracja dokończy się sama: zatwierdź okno uprawnień i nie zamykaj okna konfiguracji. Czy chcesz teraz uruchomić komputer ponownie?

[CustomMessages]
pl.Configuring=Konfigurowanie Retro, to może potrwać kilkanaście minut...
pl.ConfigureFailed=Konfiguracja Retro nie powiodła się. Uruchom „Ustawienia Retro” z menu Start. Szczegóły: %1
pl.Settings=Ustawienia Retro
pl.Games=Gry
pl.Play=Graj
pl.EsDeTask=Granie na tym komputerze: ES-DE i RetroArch (około 400 MB)
pl.LibraryCaption=Folder z grami
pl.LibraryDescription=Gdzie mają być gry?
pl.LibrarySubCaption=Wybierz folder biblioteki gier. Powstaną w nim podfoldery roms (gry, np. roms\snes) i bios. Może to być folder na innym dysku. Zmiana folderu nie przenosi gier.
pl.LibraryRequired=Wybierz folder z grami.
pl.VpnCaption=Pobieranie gier przez VPN (opcjonalne)
pl.VpnDescription=Ustawienia WireGuard dla minerva-helper
pl.VpnSubCaption=Wypełnij tylko, jeśli masz konto VPN obsługiwane przez gluetun. Zostaw puste, aby nie używać tej funkcji.
pl.VpnProvider=Dostawca VPN (np. mullvad, protonvpn, surfshark):
pl.VpnKey=Klucz prywatny WireGuard:
pl.VpnAddress=Adres WireGuard (np. 10.64.222.21/32):
pl.VpnCountries=Kraje serwerów (np. Poland, Czech Republic):
pl.VpnIncomplete=Podaj dostawcę VPN i adres WireGuard albo wyczyść klucz prywatny.
pl.MetadataCaption=Okładki i opisy gier (opcjonalne)
pl.MetadataDescription=Konto ScreenScraper
pl.MetadataSubCaption=Z kontem screenscraper.fr RomM pobiera więcej okładek i opisów. Możesz zostawić puste.
pl.MetadataUser=Login ScreenScraper:
pl.MetadataPassword=Hasło ScreenScraper:
pl.ReadyVpn=VPN:
pl.ReadyMetadata=ScreenScraper:
pl.ReadyOff=nie ustawiono

[Tasks]
Name: "esde"; Description: "{cm:EsDeTask}"

[Files]
Source: "..\compose.yml"; DestDir: "{app}\app"; Flags: ignoreversion
Source: "..\compose.windows.yml"; DestDir: "{app}\app"; Flags: ignoreversion
Source: "..\.env.example"; DestDir: "{app}\app"; Flags: ignoreversion
Source: "..\LICENSE"; DestDir: "{app}\app"; Flags: ignoreversion
Source: "..\config\romm\config.yml"; DestDir: "{app}\app\config\romm"; Flags: ignoreversion
Source: "..\config\gluetun\auth.toml"; DestDir: "{app}\app\config\gluetun"; Flags: ignoreversion
Source: "{srcexe}"; DestDir: "{app}\app"; DestName: "RetroSetup.exe"; Flags: external ignoreversion; Check: NotRunningFromApp
Source: "install.ps1"; DestDir: "{app}\app\windows"; Flags: ignoreversion; AfterInstall: Configure

[INI]
Filename: "{autoprograms}\Retro\Retro.url"; Section: "InternetShortcut"; Key: "URL"; String: "http://localhost:8080"

[Icons]
Name: "{autoprograms}\Retro\{cm:Settings}"; Filename: "{app}\app\RetroSetup.exe"
Name: "{autoprograms}\Retro\{cm:Games}"; Filename: "{code:GetLibraryDir}\roms"
Name: "{autoprograms}\Retro\{cm:Play}"; Filename: "{app}\ES-DE\ES-DE.exe"; WorkingDir: "{app}\ES-DE"; Tasks: esde

[UninstallRun]
Filename: "{commonpf64}\Docker\Docker\resources\bin\docker.exe"; Parameters: "compose --profile minerva down"; WorkingDir: "{app}\app"; Flags: runhidden waituntilterminated skipifdoesntexist; RunOnceId: "ComposeDown"

[UninstallDelete]
Type: filesandordirs; Name: "{autoprograms}\Retro"
Type: files; Name: "{userdesktop}\Retro.url"
Type: files; Name: "{userdesktop}\Graj.lnk"

[Code]
var
  RestartRequired: Boolean;
  LoadedFor: String;
  LibraryPage: TInputDirWizardPage;
  VpnPage, MetadataPage: TInputQueryWizardPage;

function NeedRestart: Boolean;
begin
  Result := RestartRequired;
end;

function NotRunningFromApp: Boolean;
begin
  Result := CompareText(ExpandConstant('{srcexe}'), ExpandConstant('{app}\app\RetroSetup.exe')) <> 0;
end;

function EnvValue(const Lines: TArrayOfString; const Key: String): String;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to GetArrayLength(Lines) - 1 do
    if Pos(Key + '=', Lines[I]) = 1 then
      Result := Copy(Lines[I], Length(Key) + 2, MaxInt);
  if (Length(Result) >= 2) and (Result[1] = '"') and (Result[Length(Result)] = '"') then
    Result := Copy(Result, 2, Length(Result) - 2);
end;

procedure LoadSettings;
var
  Lines: TArrayOfString;
  Path: String;
begin
  LoadedFor := WizardDirValue;
  LibraryPage.Values[0] := ExpandConstant('{app}\library');
  if not LoadStringsFromFile(ExpandConstant('{app}\app\.env'), Lines) then
    Exit;
  Path := EnvValue(Lines, 'LIBRARY_PATH');
  StringChangeEx(Path, '/', '\', True);
  if Path <> '' then
    LibraryPage.Values[0] := Path;
  VpnPage.Values[0] := EnvValue(Lines, 'VPN_SERVICE_PROVIDER');
  VpnPage.Values[1] := EnvValue(Lines, 'WIREGUARD_PRIVATE_KEY');
  VpnPage.Values[2] := EnvValue(Lines, 'WIREGUARD_ADDRESSES');
  VpnPage.Values[3] := EnvValue(Lines, 'SERVER_COUNTRIES');
  MetadataPage.Values[0] := EnvValue(Lines, 'SCREENSCRAPER_USER');
  MetadataPage.Values[1] := EnvValue(Lines, 'SCREENSCRAPER_PASSWORD');
end;

function GetLibraryDir(Param: String): String;
begin
  Result := LibraryPage.Values[0];
end;

procedure InitializeWizard;
begin
  LibraryPage := CreateInputDirPage(wpSelectDir, CustomMessage('LibraryCaption'), CustomMessage('LibraryDescription'), CustomMessage('LibrarySubCaption'), False, '');
  LibraryPage.Add('');
  VpnPage := CreateInputQueryPage(LibraryPage.ID, CustomMessage('VpnCaption'), CustomMessage('VpnDescription'), CustomMessage('VpnSubCaption'));
  VpnPage.Add(CustomMessage('VpnProvider'), False);
  VpnPage.Add(CustomMessage('VpnKey'), True);
  VpnPage.Add(CustomMessage('VpnAddress'), False);
  VpnPage.Add(CustomMessage('VpnCountries'), False);
  MetadataPage := CreateInputQueryPage(VpnPage.ID, CustomMessage('MetadataCaption'), CustomMessage('MetadataDescription'), CustomMessage('MetadataSubCaption'));
  MetadataPage.Add(CustomMessage('MetadataUser'), False);
  MetadataPage.Add(CustomMessage('MetadataPassword'), True);
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  if (CurPageID = LibraryPage.ID) and (LoadedFor <> WizardDirValue) then
    LoadSettings;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if (CurPageID = LibraryPage.ID) and (Trim(LibraryPage.Values[0]) = '') then begin
    MsgBox(CustomMessage('LibraryRequired'), mbError, MB_OK);
    Result := False;
  end;
  if (CurPageID = VpnPage.ID) and (Trim(VpnPage.Values[1]) <> '') and ((Trim(VpnPage.Values[0]) = '') or (Trim(VpnPage.Values[2]) = '')) then begin
    MsgBox(CustomMessage('VpnIncomplete'), mbError, MB_OK);
    Result := False;
  end;
end;

function OrOff(const Value: String): String;
begin
  Result := Trim(Value);
  if Result = '' then
    Result := CustomMessage('ReadyOff');
end;

function UpdateReadyMemo(Space, NewLine, MemoUserInfoInfo, MemoDirInfo, MemoTypeInfo, MemoComponentsInfo, MemoGroupInfo, MemoTasksInfo: String): String;
var
  Vpn: String;
begin
  Vpn := '';
  if Trim(VpnPage.Values[1]) <> '' then
    Vpn := VpnPage.Values[0];
  Result := '';
  if MemoDirInfo <> '' then
    Result := MemoDirInfo + NewLine + NewLine;
  Result := Result +
    CustomMessage('LibraryCaption') + ':' + NewLine + Space + LibraryPage.Values[0] + NewLine + NewLine +
    CustomMessage('ReadyVpn') + NewLine + Space + OrOff(Vpn) + NewLine + NewLine +
    CustomMessage('ReadyMetadata') + NewLine + Space + OrOff(MetadataPage.Values[0]);
  if MemoTasksInfo <> '' then
    Result := Result + NewLine + NewLine + MemoTasksInfo;
end;

procedure Configure;
var
  Lines: TArrayOfString;
  SettingsFile, Params: String;
  ResultCode: Integer;
begin
  if LoadedFor <> WizardDirValue then
    LoadSettings;
  SettingsFile := ExpandConstant('{app}\app\settings.env');
  SetArrayLength(Lines, 7);
  Lines[0] := 'LIBRARY_PATH=' + Trim(LibraryPage.Values[0]);
  Lines[1] := 'VPN_SERVICE_PROVIDER=' + Trim(VpnPage.Values[0]);
  Lines[2] := 'WIREGUARD_PRIVATE_KEY=' + Trim(VpnPage.Values[1]);
  Lines[3] := 'WIREGUARD_ADDRESSES=' + Trim(VpnPage.Values[2]);
  Lines[4] := 'SERVER_COUNTRIES=' + Trim(VpnPage.Values[3]);
  Lines[5] := 'SCREENSCRAPER_USER=' + Trim(MetadataPage.Values[0]);
  Lines[6] := 'SCREENSCRAPER_PASSWORD=' + MetadataPage.Values[1];
  SaveStringsToUTF8File(SettingsFile, Lines, False);

  WizardForm.StatusLabel.Caption := CustomMessage('Configuring');
  Params := '-NoProfile -ExecutionPolicy Bypass -File "' + ExpandConstant('{app}\app\windows\install.ps1') + '" -Root "' + ExpandConstant('{app}') + '" -Settings "' + SettingsFile + '"';
  if WizardIsTaskSelected('esde') then
    Params := Params + ' -EsDe';
  if WizardSilent then
    Params := Params + ' -NoPause';
  if not Exec('powershell.exe', Params, '', SW_SHOW, ewWaitUntilTerminated, ResultCode) then
    ResultCode := -1;
  if ResultCode = 3010 then
    RestartRequired := True
  else if ResultCode <> 0 then
    SuppressibleMsgBox(FmtMessage(CustomMessage('ConfigureFailed'), [ExpandConstant('{app}\app\install.log')]), mbError, MB_OK, IDOK);
end;
