; windows/windows_installer.iss

#define MyAppName "ttp App"
#define MyAppVersion "1.0.8"
#define MyAppPublisher "ttp Papenburg GmbH"
#define MyAppURL "https://ttp-kunststoffprofile.de"
#define MyAppExeName "ttp_urlcompleter.exe"

[Setup]
AppId={{A5FA1269-70CC-4F34-8964-A60FB79819EF}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputBaseFilename=ttpApp
;This is the final installer name: ttp_App.exe
OutputDir=installer      
;The compiled installer goes into windows\installer by default
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "german"; MessagesFile: "compiler:Languages\German.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
;  1) Use relative paths from the .iss file to the release folder
;  2) Check your actual output path from "flutter build windows --release". Usually: build\windows\x64\runner\Release
Source: "..\..\build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
