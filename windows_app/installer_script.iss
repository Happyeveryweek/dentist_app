; 脚本由 Inno Setup 脚本向导生成
; 有关创建 Inno Setup 脚本文件的详细资料请查阅帮助文档

#define MyAppName "牙医诊所管理系统"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "牙医诊所"
#define MyAppURL "https://www.example.com/"
#define MyAppExeName "dentist_app_windows.exe"

[Setup]
; 注: AppId的值为单独标识该应用程序
; 不要为其他安装程序使用相同的AppId值
AppId={{F7CFF7D5-54F7-4E20-BCFC-9E7DAB9B5C19}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
;AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DisableProgramGroupPage=yes
; 以下行取消注释，以在非管理安装模式下运行（仅为当前用户安装）
;PrivilegesRequired=lowest
OutputDir=installer
OutputBaseFilename=牙医诊所管理系统_安装程序
SetupIconFile=assets\icons\app_icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "chinesesimp"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Dirs]
; 创建数据目录并确保有完全访问权限
Name: "{app}\data"; Permissions: users-full
Name: "{app}\tools"; Permissions: users-full
Name: "{localappdata}\DentistAppData"; Permissions: users-full

[Files]
; 注意: 不要在任何共享系统文件上使用"Flags: ignoreversion"
Source: "build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "assets\*"; DestDir: "{app}\assets"; Flags: ignoreversion recursesubdirs createallsubdirs
; MySQL工具 - 设置正确的目标路径和权限
Source: "tools\mysql.exe"; DestDir: "{app}\tools"; Flags: ignoreversion; Permissions: users-full
Source: "tools\mysqldump.exe"; DestDir: "{app}\tools"; Flags: ignoreversion; Permissions: users-full
Source: "tools\libmysql.dll"; DestDir: "{app}\tools"; Flags: ignoreversion; Permissions: users-full
; 默认数据库文件
Source: "data\dentist.db"; DestDir: "{app}\data"; Flags: ignoreversion onlyifdoesntexist
; 注意: 其他你可能需要的文件
; 必要: 应用程序需要的所有文件

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; 启动应用程序
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent 
; 创建环境设置脚本
Filename: "{cmd}"; Parameters: "/c echo @echo off > ""{app}\setup_env.bat"""; Flags: runhidden
Filename: "{cmd}"; Parameters: "/c echo set PATH=%PATH%;{app}\tools >> ""{app}\setup_env.bat"""; Flags: runhidden 