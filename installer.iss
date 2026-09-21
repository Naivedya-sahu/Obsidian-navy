#define MyAppName "Obsidian Context Menu"
#define MyAppVersion "1.2"
#define MyAppPublisher "Naivedya Sahu"
#define MyAppURL "https://github.com/Naivedya-sahu/Obsidian-navy"

[Setup]
AppId={{6F1E9B4A-2C7D-4E3F-9A1B-8D4C5E6F7A2B}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
DefaultDirName={autopf}\ObsidianContextMenu
DisableProgramGroupPage=yes
DisableWelcomePage=no
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=Output
OutputBaseFilename=ObsidianContextMenu-Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Files]
Source: "open-vault.exe"; DestDir: "{app}"; Flags: ignoreversion
; The seed vault copied into <folder>\.obsidian by the "with plugins" verb.
; workspace.json / workspaces.json are the author's own window layout and open
; tabs — vault-specific state, never something to stamp onto someone's folder.
Source: "Default\.obsidian\*"; DestDir: "{app}\Template"; Excludes: "workspace.json,workspaces.json"; Flags: ignoreversion recursesubdirs createallsubdirs

[Registry]
; v1.0 put the verb's command directly on this key. The shell honours a \command
; subkey over "subcommands", so an upgrade that leaves it behind silently keeps
; the old single-action menu. Delete it before writing the cascade.
Root: HKCR; Subkey: "Directory\shell\Obsidian\command"; ValueType: none; Flags: deletekey
Root: HKCR; Subkey: "Directory\shell\Obsidian"; ValueType: none; ValueName: ""; Flags: deletevalue

; Cascading submenu: one "Obsidian" entry that expands into the two modes.
; Icon on the parent is also the runtime's single source of truth for
; Obsidian.exe's path — open-vault.exe reads it back from here on every click.
Root: HKCR; Subkey: "Directory\shell\Obsidian"; ValueType: string; ValueName: "MUIVerb"; ValueData: "Obsidian"; Flags: uninsdeletekey
Root: HKCR; Subkey: "Directory\shell\Obsidian"; ValueType: string; ValueName: "Icon"; ValueData: "{code:GetObsidianExePath}"
Root: HKCR; Subkey: "Directory\shell\Obsidian"; ValueType: string; ValueName: "subcommands"; ValueData: ""

; Subkey names are sorted alphabetically by the shell, hence the 01/02 prefixes.
Root: HKCR; Subkey: "Directory\shell\Obsidian\shell\01plain"; ValueType: string; ValueName: "MUIVerb"; ValueData: "Open as plain vault"
Root: HKCR; Subkey: "Directory\shell\Obsidian\shell\01plain"; ValueType: string; ValueName: "Icon"; ValueData: "{code:GetObsidianExePath}"
Root: HKCR; Subkey: "Directory\shell\Obsidian\shell\01plain\command"; ValueType: string; ValueName: ""; ValueData: """{app}\open-vault.exe"" ""%1"""

Root: HKCR; Subkey: "Directory\shell\Obsidian\shell\02full"; ValueType: string; ValueName: "MUIVerb"; ValueData: "Open as vault with plugins"
Root: HKCR; Subkey: "Directory\shell\Obsidian\shell\02full"; ValueType: string; ValueName: "Icon"; ValueData: "{code:GetObsidianExePath}"
Root: HKCR; Subkey: "Directory\shell\Obsidian\shell\02full\command"; ValueType: string; ValueName: ""; ValueData: """{app}\open-vault.exe"" --template ""%1"""

[Code]
var
  ObsidianPath: String;
  DetectPage: TWizardPage;
  PathEdit: TNewEdit;
  StatusLabel: TNewStaticText;
  DownloadBtn: TNewButton;

function GetObsidianExePath(Param: String): String;
begin
  Result := ObsidianPath;
end;

function TryPath(P: String): String;
begin
  if FileExists(P) then Result := P else Result := '';
end;

function ScanUninstallKeys(RootKey: Integer): String;
var
  Names: TArrayOfString;
  I: Integer;
  BasePath, SubKey, DisplayName, InstallLocation, ExePath: String;
begin
  Result := '';
  BasePath := 'Software\Microsoft\Windows\CurrentVersion\Uninstall';
  if RegGetSubkeyNames(RootKey, BasePath, Names) then
  begin
    for I := 0 to GetArrayLength(Names) - 1 do
    begin
      SubKey := BasePath + '\' + Names[I];
      if RegQueryStringValue(RootKey, SubKey, 'DisplayName', DisplayName) then
      begin
        if Pos('obsidian', Lowercase(DisplayName)) > 0 then
        begin
          if RegQueryStringValue(RootKey, SubKey, 'InstallLocation', InstallLocation) and (InstallLocation <> '') then
          begin
            ExePath := TryPath(AddBackslash(InstallLocation) + 'Obsidian.exe');
            if ExePath <> '' then begin Result := ExePath; Exit; end;
          end;
        end;
      end;
    end;
  end;
end;

function DetectObsidian(): String;
begin
  Result := ScanUninstallKeys(HKLM);
  if Result = '' then Result := ScanUninstallKeys(HKCU);
  if Result = '' then Result := TryPath(ExpandConstant('{pf}\Obsidian\Obsidian.exe'));
  if Result = '' then Result := TryPath(ExpandConstant('{localappdata}\Obsidian\Obsidian.exe'));
  if Result = '' then Result := TryPath(ExpandConstant('{localappdata}\Programs\obsidian\Obsidian.exe'));
end;

procedure BrowseButtonClick(Sender: TObject);
var
  FN: String;
begin
  FN := 'Obsidian.exe';
  if GetOpenFileName('Select Obsidian.exe', FN, ExpandConstant('{pf}'),
       'Obsidian.exe|Obsidian.exe|Executable files|*.exe', 'exe') then
    PathEdit.Text := FN;
end;

procedure DownloadButtonClick(Sender: TObject);
var
  ScriptPath: String;
  ResultCode: Integer;
  Found: String;
begin
  DownloadBtn.Enabled := False;
  StatusLabel.Caption := 'Downloading latest Obsidian from GitHub releases...';
  WizardForm.Refresh;

  ScriptPath := ExpandConstant('{tmp}\fetch-obsidian.ps1');
  SaveStringToFile(ScriptPath,
    '$ErrorActionPreference = "Stop"' + #13#10 +
    '$rel = Invoke-RestMethod "https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest"' + #13#10 +
    '$asset = $rel.assets | Where-Object { $_.name -like "*.exe" } | Select-Object -First 1' + #13#10 +
    'if (-not $asset) { exit 2 }' + #13#10 +
    '$out = Join-Path $env:TEMP "ObsidianSetup.exe"' + #13#10 +
    'Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $out' + #13#10 +
    'Start-Process -FilePath $out -Wait' + #13#10,
    False);

  if Exec(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'),
       '-NoProfile -ExecutionPolicy Bypass -File "' + ScriptPath + '"',
       '', SW_HIDE, ewWaitUntilTerminated, ResultCode) and (ResultCode = 0) then
  begin
    Found := DetectObsidian();
    if Found <> '' then
    begin
      PathEdit.Text := Found;
      StatusLabel.Caption := 'Found: ' + Found;
    end else
      StatusLabel.Caption := 'Obsidian installed, but Obsidian.exe still wasn''t found automatically — browse for it manually.';
  end else
    StatusLabel.Caption := 'Download/install failed (exit code ' + IntToStr(ResultCode) + '). Check your internet connection, or browse manually.';

  DownloadBtn.Enabled := True;
end;

procedure InitializeWizard;
begin
  DetectPage := CreateCustomPage(wpSelectDir, 'Locate Obsidian',
    'Setup could not find Obsidian.exe automatically.');

  StatusLabel := TNewStaticText.Create(DetectPage);
  StatusLabel.Parent := DetectPage.Surface;
  StatusLabel.Caption := 'Browse for Obsidian.exe, or download and install the latest official version, then continue.';
  StatusLabel.Left := 0;
  StatusLabel.Top := 0;
  StatusLabel.Width := DetectPage.SurfaceWidth;
  StatusLabel.WordWrap := True;

  PathEdit := TNewEdit.Create(DetectPage);
  PathEdit.Parent := DetectPage.Surface;
  PathEdit.Left := 0;
  PathEdit.Top := StatusLabel.Top + 40;
  PathEdit.Width := DetectPage.SurfaceWidth - 90;

  with TNewButton.Create(DetectPage) do
  begin
    Parent := DetectPage.Surface;
    Left := PathEdit.Left + PathEdit.Width + 10;
    Top := PathEdit.Top - 2;
    Width := 80;
    Caption := 'Browse...';
    OnClick := @BrowseButtonClick;
  end;

  DownloadBtn := TNewButton.Create(DetectPage);
  DownloadBtn.Parent := DetectPage.Surface;
  DownloadBtn.Left := 0;
  DownloadBtn.Top := PathEdit.Top + 40;
  DownloadBtn.Width := 260;
  DownloadBtn.Caption := 'Download && Install Latest Obsidian';
  DownloadBtn.OnClick := @DownloadButtonClick;
end;

function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := (PageID = DetectPage.ID) and (ObsidianPath <> '');
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if CurPageID = DetectPage.ID then
  begin
    if (not FileExists(PathEdit.Text)) or (Lowercase(ExtractFileName(PathEdit.Text)) <> 'obsidian.exe') then
    begin
      MsgBox('Select a valid Obsidian.exe first.', mbError, MB_OK);
      Result := False;
    end else
      ObsidianPath := PathEdit.Text;
  end;
end;

function InitializeSetup(): Boolean;
begin
  ObsidianPath := DetectObsidian();
  Result := True;
end;
