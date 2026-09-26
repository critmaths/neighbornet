; NeighborNet - Tactical Emergency & Local Resilience Mesh Network
; Inno Setup 6 Installer Script for Windows Desktop (x64)

#define MyAppName "NeighborNet"
#define MyAppVersion "0.1.0"
#define MyAppPublisher "Sovereign Mesh Project"
#define MyAppURL "https://github.com/critmaths/Neighbornet"
#define MyAppExeName "neighbornet_app.exe"
#define MyNodeExeName "neighbornet_node.exe"

[Setup]
AppId={{94F5E68C-C78D-43C1-A2A9-B101E9D7A5C2}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DisableProgramGroupPage=yes
OutputDir=..\dist
OutputBaseFilename=NeighborNet_Setup_v{#MyAppVersion}_x64
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"
Name: "firewall"; Description: "Configure Windows Defender Firewall rules for Mesh Discovery (UDP 42424) and Web Gateway (TCP 8080)"; GroupDescription: "Network Security Configuration:"

[Files]
; Copy all binaries, DLLs, and Flutter runtime data from the staging release folder
Source: "..\dist\NeighborNet_v0.1.0_Windows_x64\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autoprograms}\{#MyAppName}\NeighborNet Headless Relay Daemon"; Filename: "{app}\{#MyNodeExeName}"; Parameters: "-p 42424 -t -w 8080 -z 53"
Name: "{autoprograms}\{#MyAppName}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "netsh"; Parameters: "advfirewall firewall add rule name=""NeighborNet Mesh Discovery (UDP 42424)"" dir=in action=allow protocol=UDP localport=42424"; Flags: runhidden; Tasks: firewall; StatusMsg: "Configuring mesh firewall rules..."
Filename: "netsh"; Parameters: "advfirewall firewall add rule name=""NeighborNet Web Gateway (TCP 8080)"" dir=in action=allow protocol=TCP localport=8080"; Flags: runhidden; Tasks: firewall; StatusMsg: "Configuring web gateway firewall rules..."
Filename: "netsh"; Parameters: "advfirewall firewall add rule name=""NeighborNet Captive DNS (UDP 53)"" dir=in action=allow protocol=UDP localport=53"; Flags: runhidden; Tasks: firewall; StatusMsg: "Configuring captive DNS firewall rules..."
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "netsh"; Parameters: "advfirewall firewall delete rule name=""NeighborNet Mesh Discovery (UDP 42424)"""; Flags: runhidden
Filename: "netsh"; Parameters: "advfirewall firewall delete rule name=""NeighborNet Web Gateway (TCP 8080)"""; Flags: runhidden
Filename: "netsh"; Parameters: "advfirewall firewall delete rule name=""NeighborNet Captive DNS (UDP 53)"""; Flags: runhidden
