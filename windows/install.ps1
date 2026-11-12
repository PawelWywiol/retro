#Requires -Version 5.1
param([string]$Root = "$env:SystemDrive\Retro", [string]$Settings, [switch]$EsDe, [switch]$NoPause)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$AppDir = Split-Path $PSScriptRoot -Parent
$Docker = "$env:ProgramFiles\Docker\Docker\resources\bin\docker.exe"
$DockerDesktop = "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe"
$SelfArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Root `"$Root`"" + $(if ($EsDe) { ' -EsDe' })
$RestartExitCode = 3010
$RetroArchVersion = '1.22.2'
$Cores = 'mesen', 'snes9x', 'genesis_plus_gx', 'gambatte', 'mgba', 'mupen64plus_next', 'mednafen_psx', 'mednafen_pce', 'stella', 'melondsds'

function Test-Admin {
  ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Stop-Install([string]$Message) {
  Write-Host "`n$Message`n" -ForegroundColor Red
  if (-not $NoPause) { Read-Host 'Naciśnij Enter, aby zamknąć' | Out-Null }
  exit 1
}

function Assert-System {
  $os = Get-CimInstance Win32_OperatingSystem
  $cs = Get-CimInstance Win32_ComputerSystem
  $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
  if (-not [Environment]::Is64BitOperatingSystem) { Stop-Install 'Wymagany jest 64-bitowy Windows.' }
  if ([int]$os.BuildNumber -lt 19045) { Stop-Install 'Wymagany jest Windows 10 22H2 lub Windows 11. Najpierw zainstaluj aktualizacje (Windows Update).' }
  if ($cs.TotalPhysicalMemory -lt 7.5GB) { Stop-Install 'Komputer musi mieć co najmniej 8 GB pamięci RAM.' }
  if (-not ($cpu.VirtualizationFirmwareEnabled -or $cs.HypervisorPresent)) {
    Stop-Install 'Wirtualizacja jest wyłączona. Włącz ją w BIOS/UEFI (Intel VT-x / AMD-V / SVM) i uruchom instalator ponownie.'
  }
}

function Test-HypervisorFailed {
  $boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
  [bool](Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-Hyper-V-Hypervisor'; Id = 41; StartTime = $boot } -ErrorAction SilentlyContinue)
}

function Install-Wsl {
  $restart = $false
  foreach ($feature in 'Microsoft-Windows-Subsystem-Linux', 'VirtualMachinePlatform') {
    if ((Get-WindowsOptionalFeature -Online -FeatureName $feature).State -ne 'Enabled') {
      Write-Host "Włączanie funkcji Windows: $feature..."
      $restart = (Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart -WarningAction SilentlyContinue).RestartNeeded -or $restart
    }
  }
  if (-not (Test-Path "$env:ProgramFiles\WSL\wsl.exe")) {
    Write-Host 'Instalowanie WSL...'
    $release = Invoke-RestMethod https://api.github.com/repos/microsoft/WSL/releases/latest
    $url = ($release.assets | Where-Object name -Like '*.x64.msi').browser_download_url
    $msi = "$env:TEMP\wsl.msi"
    Invoke-WebRequest $url -OutFile $msi -UseBasicParsing
    $exit = (Start-Process msiexec.exe -Wait -PassThru -ArgumentList "/i `"$msi`" /qn /norestart").ExitCode
    if ($exit -notin 0, 3010) { Stop-Install "Instalacja WSL nie powiodła się (kod $exit)." }
    $restart = $restart -or $exit -eq 3010
  }
  $restart
}

function Install-DockerDesktop {
  if (Test-Path $DockerDesktop) { return $false }
  Write-Host 'Pobieranie Docker Desktop (około 600 MB)...'
  $installer = "$env:TEMP\DockerDesktopInstaller.exe"
  Invoke-WebRequest 'https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe' -OutFile $installer -UseBasicParsing
  if ((Get-AuthenticodeSignature $installer).Status -ne 'Valid') { Stop-Install 'Podpis instalatora Docker Desktop jest nieprawidłowy.' }
  Write-Host 'Instalowanie Docker Desktop...'
  $exit = (Start-Process $installer -Wait -PassThru -ArgumentList 'install', '--quiet', '--accept-license', '--backend=wsl-2').ExitCode
  if ($exit -ne 0) { Stop-Install "Instalacja Docker Desktop nie powiodła się (kod $exit)." }
  $true
}

function Exit-ForRestart {
  Set-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce -Name RetroInstall -Value "powershell.exe $SelfArgs"
  Write-Host "`nUruchom ponownie komputer. Po zalogowaniu instalacja dokończy się sama." -ForegroundColor Yellow
  exit $RestartExitCode
}

function Set-DockerDesktopSetting {
  $file = "$env:APPDATA\Docker\settings-store.json"
  $settings = if (Test-Path $file) { Get-Content $file -Raw | ConvertFrom-Json } else { New-Item -ItemType Directory -Force (Split-Path $file) | Out-Null; [pscustomobject]@{} }
  $settings | Add-Member -NotePropertyName AutoStart -NotePropertyValue $true -Force
  $settings | Add-Member -NotePropertyName OpenUIOnStartupDisabled -NotePropertyValue $true -Force
  [IO.File]::WriteAllText($file, ($settings | ConvertTo-Json))
}

function Start-DockerDesktop {
  $ErrorActionPreference = 'Continue'
  if (-not (Get-Process 'Docker Desktop' -ErrorAction SilentlyContinue)) {
    Write-Host 'Uruchamianie Docker Desktop...'
    Start-Process explorer.exe -ArgumentList "`"$DockerDesktop`""
  }
  for ($i = 0; $i -lt 60; $i++) {
    if ((& $Docker info --format '{{.ServerVersion}}' 2>$null) -match '^\d') { return }
    Start-Sleep 5
  }
  if (Test-HypervisorFailed) {
    Stop-Install 'Wirtualizacja jest niedostępna. Włącz ją w BIOS/UEFI (Intel VT-x / AMD-V / SVM) i uruchom instalator ponownie.'
  }
  Stop-Install 'Docker Desktop się nie uruchomił. Otwórz Docker Desktop z menu Start, poczekaj aż wystartuje i uruchom instalator ponownie.'
}

function New-Secret {
  $bytes = New-Object byte[] 32
  [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
  -join ($bytes | ForEach-Object { $_.ToString('x2') })
}

function Initialize-Env {
  $file = Join-Path $AppDir '.env'
  $lines = if (Test-Path $file) { Get-Content $file } else {
    $rootPath = $Root -replace '\\', '/'
    (Get-Content (Join-Path $AppDir '.env.example')) -replace '^LIBRARY_PATH=.*', "LIBRARY_PATH=$rootPath/library" -replace '^DATA_PATH=.*', "DATA_PATH=$rootPath/data"
  }
  $lines = $lines | ForEach-Object { if ($_ -match '^(DB_PASSWD|DB_ROOT_PASSWD|ROMM_AUTH_SECRET_KEY)=$') { "$($_)$(New-Secret)" } else { $_ } }
  if (-not ($lines -match '^COMPOSE_FILE=')) { $lines += 'COMPOSE_FILE=compose.yml;compose.windows.yml' }
  if ($EsDe) { $lines = @($lines -notmatch '^ESDE_GAMELISTS=') + "ESDE_GAMELISTS=$($Root -replace '\\', '/')/ES-DE/ES-DE/gamelists" }
  if ($Settings -and (Test-Path $Settings)) {
    $chosen = @{}
    Get-Content $Settings -Encoding UTF8 | Where-Object { $_ -match '^[A-Z_]+=' } | ForEach-Object { $k, $v = $_ -split '=', 2; $chosen[$k] = $v }
    if ($chosen.LIBRARY_PATH) { $chosen.LIBRARY_PATH = $chosen.LIBRARY_PATH -replace '\\', '/' }
    $lines = $lines | ForEach-Object { $k = ($_ -split '=', 2)[0]; if ($chosen.ContainsKey($k)) { "$k=$($chosen[$k])" } else { $_ } }
    Remove-Item $Settings
  }
  [IO.File]::WriteAllLines($file, [string[]]$lines)
  $me = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
  icacls.exe $file /inheritance:r /grant:r '*S-1-5-32-544:F' '*S-1-5-18:F' "*${me}:F" | Out-Null

  $vars = @{}
  $lines | Where-Object { $_ -match '^[A-Z_]+=' } | ForEach-Object { $k, $v = $_ -split '=', 2; $vars[$k] = $v }
  $vars
}

function Initialize-Directory($Vars) {
  'roms', 'bios' | ForEach-Object { New-Item -ItemType Directory -Force (Join-Path $Vars.LIBRARY_PATH $_) | Out-Null }
  'romm\resources', 'romm\assets', 'romm\config', 'gluetun', 'minerva' | ForEach-Object { New-Item -ItemType Directory -Force (Join-Path $Vars.DATA_PATH $_) | Out-Null }
  $config = Join-Path $Vars.DATA_PATH 'romm\config\config.yml'
  if (-not (Test-Path $config)) { Copy-Item (Join-Path $AppDir 'config\romm\config.yml') $config }
}

function Expand-Download([string]$Url, [string]$Name, [string]$Destination) {
  $file = Join-Path $env:TEMP $Name
  Invoke-WebRequest $Url -OutFile $file -UseBasicParsing
  New-Item -ItemType Directory -Force $Destination | Out-Null
  tar.exe -xf $file -C $Destination
  if ($LASTEXITCODE -ne 0) { Stop-Install "Nie udało się rozpakować $Name." }
  Remove-Item $file
}

function Set-Line([string]$File, [string]$Match, [string]$Line, [string]$Header) {
  $lines = @(if (Test-Path $File) { Get-Content $File | Where-Object { $_ -notmatch $Match } } elseif ($Header) { $Header })
  [IO.File]::WriteAllLines($File, [string[]]($lines + $Line))
}

function Install-EsDe($Vars) {
  $esde = Join-Path $Root 'ES-DE'
  $retroarch = Join-Path $esde 'Emulators\RetroArch-Win64'
  $library = $Vars.LIBRARY_PATH -replace '/', '\'
  if (-not (Test-Path "$esde\ES-DE.exe")) {
    Write-Host 'Pobieranie ES-DE...'
    $release = Invoke-RestMethod 'https://gitlab.com/api/v4/projects/es-de%2Femulationstation-de/releases?per_page=1'
    Expand-Download -Url ($release[0].assets.links | Where-Object name -Like '*_Portable.zip').url -Name 'es-de.zip' -Destination $Root
  }
  if (-not (Test-Path "$retroarch\retroarch.exe")) {
    Write-Host 'Pobieranie RetroArch...'
    Expand-Download -Url "https://buildbot.libretro.com/stable/$RetroArchVersion/windows/x86_64/RetroArch.7z" -Name 'retroarch.7z' -Destination (Join-Path $esde 'Emulators')
    Set-Line -File "$retroarch\retroarch.cfg" -Match '^video_fullscreen\s*=' -Line 'video_fullscreen = "true"'
  }
  foreach ($core in $Cores) {
    if (-not (Test-Path "$retroarch\cores\${core}_libretro.dll")) {
      Write-Host "Pobieranie emulatora $core..."
      Expand-Download -Url "https://buildbot.libretro.com/nightly/windows/x86_64/latest/${core}_libretro.dll.zip" -Name "$core.zip" -Destination "$retroarch\cores"
    }
  }
  Set-Line -File "$retroarch\retroarch.cfg" -Match '^system_directory\s*=' -Line "system_directory = `"$library\bios`""
  Set-Line -File "$esde\ES-DE\settings\es_settings.xml" -Match 'name="ROMDirectory"' -Line "<string name=`"ROMDirectory`" value=`"$library\roms`" />" -Header '<?xml version="1.0"?>'
  Set-Line -File "$esde\ES-DE\settings\es_settings.xml" -Match 'name="MediaDirectory"' -Line "<string name=`"MediaDirectory`" value=`"$library\roms`" />"
  $shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut("$([Environment]::GetFolderPath('Desktop'))\Graj.lnk")
  $shortcut.TargetPath = "$esde\ES-DE.exe"
  $shortcut.WorkingDirectory = $esde
  $shortcut.Save()
}

function Set-Firewall($Vars) {
  Get-NetFirewallApplicationFilter | Where-Object Program -Like '*\com.docker.backend.exe' |
    Get-NetFirewallRule | Where-Object Action -EQ Block | Remove-NetFirewallRule
  Remove-NetFirewallRule -Name RetroPorts -ErrorAction SilentlyContinue
  New-NetFirewallRule -Name RetroPorts -DisplayName 'Retro' -Direction Inbound -Protocol TCP -LocalPort $Vars.ROMM_PORT, $Vars.MINERVA_PORT -Action Allow -Profile Private | Out-Null
}

function Start-Stack($Vars) {
  $ErrorActionPreference = 'Continue'
  Write-Host 'Uruchamianie Retro (za pierwszym razem pobiera około 1 GB)...'
  $profileArgs = if ($Vars.WIREGUARD_PRIVATE_KEY) { '--profile', 'minerva' } else { @() }
  Push-Location $AppDir
  try {
    if (& $Docker compose ps -q romm-db 2>$null) {
      Write-Host 'Kopia zapasowa bazy przed zmianą...'
      & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\backup.ps1" -NoPause | Out-Host
    }
    if (-not $Vars.WIREGUARD_PRIVATE_KEY) { & $Docker compose --profile minerva rm --stop --force gluetun minerva-helper 2>&1 | Out-Null }
    & $Docker compose @profileArgs up -d
  } finally { Pop-Location }
  if ($LASTEXITCODE -ne 0) { Stop-Install 'Nie udało się uruchomić Retro. Uruchom instalator ponownie; jeśli błąd się powtarza, wyślij plik install.log.' }
}

function Register-Backup {
  $action = New-ScheduledTaskAction -Execute powershell.exe -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSScriptRoot\backup.ps1`" -NoPause"
  $trigger = New-ScheduledTaskTrigger -Daily -At 20:00
  $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable
  $principal = New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive
  Register-ScheduledTask -TaskName RetroBackup -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
}

function New-Shortcut($Vars) {
  $desktop = [Environment]::GetFolderPath('Desktop')
  [IO.File]::WriteAllLines("$desktop\Retro.url", [string[]]@('[InternetShortcut]', "URL=http://localhost:$($Vars.ROMM_PORT)"))
}

function Open-Romm($Vars) {
  $url = "http://localhost:$($Vars.ROMM_PORT)"
  Write-Host 'Czekanie na start RomM...'
  for ($i = 0; $i -lt 36; $i++) {
    try { Invoke-WebRequest "$url/api/heartbeat" -UseBasicParsing -TimeoutSec 5 | Out-Null; break } catch { Start-Sleep 5 }
  }
  Get-Process -Name 'Docker Desktop', wslsettings -ErrorAction SilentlyContinue | Where-Object MainWindowHandle -NE 0 | ForEach-Object { $_.CloseMainWindow() | Out-Null }
  Start-Process explorer.exe -ArgumentList $url
  $url
}

if (-not (Test-Admin)) {
  Start-Process powershell.exe -Verb RunAs -ArgumentList $SelfArgs
  exit 0
}

$Host.UI.RawUI.WindowTitle = 'Retro - konfiguracja'
Write-Host "Retro: konfiguracja. Nie zamykaj tego okna.`n" -ForegroundColor Cyan
Start-Transcript -Append -Path (Join-Path $AppDir 'install.log') | Out-Null
Assert-System
$cfg = Initialize-Env
Initialize-Directory $cfg
if ($EsDe) { Install-EsDe $cfg }
$restart = Install-Wsl
$restart = (Install-DockerDesktop) -or $restart
Set-DockerDesktopSetting
if ($restart) { Exit-ForRestart }
Start-DockerDesktop
Set-Firewall $cfg
Start-Stack $cfg
Register-Backup
New-Shortcut $cfg
$url = Open-Romm $cfg
Write-Host "`nGotowe. Retro: skrót 'Retro' na pulpicie lub $url`n" -ForegroundColor Green
Stop-Transcript | Out-Null
