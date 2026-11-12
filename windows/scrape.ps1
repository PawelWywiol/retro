#Requires -Version 5.1
param([string[]]$Systems, [switch]$NoPause)

$AppDir = Split-Path $PSScriptRoot -Parent
$Docker = "$env:ProgramFiles\Docker\Docker\resources\bin\docker.exe"

$Host.UI.RawUI.WindowTitle = 'Retro - okładki'
Write-Host "Pobieranie okładek, opisów i filmów z ScreenScraper. Przy dużej bibliotece może to potrwać nawet kilka godzin.`n" -ForegroundColor Cyan
Set-Location $AppDir
& $Docker compose --profile scrape run --rm --build skyscraper @Systems
if ($LASTEXITCODE -eq 0) {
  Write-Host "`nGotowe. W RomM uruchom skanowanie biblioteki (źródło metadanych: Gamelist), a ES-DE pokaże okładki po ponownym uruchomieniu.`n" -ForegroundColor Green
} else {
  Write-Host "`nPobieranie nie powiodło się. Sprawdź, czy Docker Desktop działa, i spróbuj ponownie.`n" -ForegroundColor Red
}
if (-not $NoPause) { Read-Host 'Naciśnij Enter, aby zamknąć' | Out-Null }
exit $LASTEXITCODE
