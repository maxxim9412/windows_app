; Скрипт Inno Setup — собирает установщик из уже готовой Flutter-сборки
; (build\windows\x64\runner\Release). Версию передаёт CI через
; /DMyAppVersion=x.x.x; если не передана — берётся заглушка ниже, чтобы
; скрипт можно было проверить компиляцией и локально.
#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif

#define MyAppName "Размышления над Библией"
#define MyAppExeName "bible_reflection.exe"
#define MyAppPublisher "QT"

[Setup]
; Стабильный AppId — не менять между версиями, иначе установщик перестанет
; видеть предыдущую установку как обновление и будет ставить рядом вторую.
AppId={{0AC00899-1FE7-4905-AE23-14F43E6D947D}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
; Ставим в папку пользователя (AppData), а не Program Files — не нужны
; права администратора ни на установку, ни на будущее самообновление.
DefaultDirName={localappdata}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=..\..\installer_output
OutputBaseFilename=QT-Setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Создать значок на рабочем столе"; GroupDescription: "Дополнительные значки:"

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Запустить {#MyAppName}"; Flags: nowait postinstall skipifsilent
