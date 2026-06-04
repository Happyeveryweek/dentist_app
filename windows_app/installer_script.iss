; 脚本由 Inno Setup 脚本向导生成
; 有关创建 Inno Setup 脚本文件的详细资料请查阅帮助文档

#define MyAppName "牙科诊所管理系统"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "牙科诊所"
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
; 设置为最低权限模式，避免权限冲突
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir=installer
OutputBaseFilename=牙科诊所管理系统_安装程序
SetupIconFile=assets\icons\app_icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern
; 设置默认语言为中文
ShowLanguageDialog=no

[Languages]
Name: "chinesesimp"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[CustomMessages]
chinesesimp.LaunchProgram=启动 %1

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Dirs]
; 创建数据目录并确保有完全访问权限
Name: "{app}\data"
Name: "{app}\tools"
Name: "{localappdata}\DentistAppData"

[Files]
; 注意: 不要在任何共享系统文件上使用"Flags: ignoreversion"
Source: "build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; 资源文件（图标、字体等）- 这些会被打包到应用程序内部
Source: "assets\*"; DestDir: "{app}\assets"; Flags: ignoreversion recursesubdirs createallsubdirs
; MySQL工具
Source: "tools\mysql.exe"; DestDir: "{app}\tools"; Flags: ignoreversion
Source: "tools\mysqldump.exe"; DestDir: "{app}\tools"; Flags: ignoreversion
Source: "tools\libmysql.dll"; DestDir: "{app}\tools"; Flags: ignoreversion
; 预置模板数据文件（如果存在的话，首次安装时提供默认模板）
Source: "data\treatment_templates.json"; DestDir: "{app}\data"; Flags: ignoreversion skipifsourcedoesntexist
Source: "data\notes_templates.json"; DestDir: "{app}\data"; Flags: ignoreversion skipifsourcedoesntexist
; 注意: 数据库文件将在首次运行时自动创建，不需要预置数据库文件
; 注意: 其他你可能需要的文件
; 必要: 应用程序需要的所有文件

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; 创建环境设置脚本
Filename: "{cmd}"; Parameters: "/c echo @echo off > ""{app}\setup_env.bat"""; Flags: runhidden
Filename: "{cmd}"; Parameters: "/c echo set PATH=%PATH%;{app}\tools >> ""{app}\setup_env.bat"""; Flags: runhidden
; 启动应用程序
Filename: "{app}\{#MyAppExeName}"; Description: "启动牙科诊所管理系统"; Flags: nowait postinstall skipifsilent 