#Requires -Version 5.1
param([switch]$Restore, [string]$File, [int]$Keep = 14, [switch]$NoPause)

$ErrorActionPreference = 'Continue'
$AppDir = Split-Path $PSScriptRoot -Parent
$BackupDir = Join-Path (Split-Path $AppDir -Parent) 'backup'
$Docker = "$env:ProgramFiles\Docker\Docker\resources\bin\docker.exe"

function Exit-Backup([string]$Message, [int]$Code) {
  Write-Host "`n$Message`n" -ForegroundColor $(if ($Code) { 'Red' } else { 'Green' })
  if (-not $NoPause) { Read-Host 'Naciśnij Enter, aby zamknąć' | Out-Null }
  exit $Code
}

function Invoke-Db([string]$Command) {
  & $Docker compose exec -T romm-db sh -c $Command
  if ($LASTEXITCODE -ne 0) { Exit-Backup 'Operacja na bazie danych nie powiodła się.' 1 }
}

Set-Location $AppDir
if (-not (& $Docker compose ps -q romm-db 2>$null)) { Exit-Backup 'Retro nie działa. Uruchom Docker Desktop i spróbuj ponownie.' 1 }

if ($Restore) {
  if (-not $File) { $File = (Get-ChildItem $BackupDir -Filter 'romm-*.sql' -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -Last 1).FullName }
  if (-not $File -or -not (Test-Path $File)) { Exit-Backup 'Nie znaleziono kopii zapasowej.' 1 }
  Write-Host "Przywracanie kopii: $File" -ForegroundColor Yellow
  if ((Read-Host 'Obecna biblioteka RomM zostanie zastąpiona. Wpisz TAK, aby kontynuować') -ne 'TAK') { Exit-Backup 'Anulowano.' 0 }
  & $Docker compose stop romm
  & $Docker compose cp $File romm-db:/tmp/restore.sql
  Invoke-Db 'mariadb -uroot -p$MARIADB_ROOT_PASSWORD < /tmp/restore.sql && rm /tmp/restore.sql'
  & $Docker compose start romm
  Exit-Backup 'Kopia przywrócona.' 0
}

New-Item -ItemType Directory -Force $BackupDir | Out-Null
$target = Join-Path $BackupDir "romm-$(Get-Date -Format 'yyyyMMdd-HHmmss').sql"
Invoke-Db 'mariadb-dump -uroot -p$MARIADB_ROOT_PASSWORD --single-transaction --databases $MARIADB_DATABASE > /tmp/backup.sql'
& $Docker compose cp romm-db:/tmp/backup.sql $target
if ($LASTEXITCODE -ne 0) { Exit-Backup 'Nie udało się zapisać kopii.' 1 }
Invoke-Db 'rm /tmp/backup.sql'
Get-ChildItem $BackupDir -Filter 'romm-*.sql' | Sort-Object Name | Select-Object -SkipLast $Keep | Remove-Item
Exit-Backup "Kopia zapisana: $target" 0
