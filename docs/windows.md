# Windows

The same stack runs on Windows 10 22H2 / Windows 11 with Docker Desktop on WSL 2.

## Requirements

- 64-bit Windows 10 22H2 (build 19045) or Windows 11, 8 GB RAM
- virtualization enabled in BIOS/UEFI (Intel VT-x / AMD-V / SVM)
- Docker Desktop is free for personal use and small businesses (fewer than 250 employees and less than $10 million in annual revenue)

## Install

Run `RetroSetup.exe` as the user who will use Retro and follow the Polish wizard:

1. Retro folder (default `C:\Retro`): `app\` and `data\`
2. games folder (default `C:\Retro\library`, any drive): `roms\` and `bios\`
3. optional VPN for minerva-helper: provider, WireGuard private key, address, server countries
4. optional ScreenScraper login
5. task _Granie na tym komputerze_ (checked by default): ES-DE portable, RetroArch and the default ES-DE cores for common systems in `<Retro folder>\ES-DE`, a `Graj` shortcut

Windows restarts once; after sign-in the setup finishes by itself and opens RomM in the browser.

To change settings later, use Start menu → Retro → _Ustawienia Retro_: the wizard opens with the current values from `.env` and restarts Retro after the change. Clearing the private key removes gluetun and minerva-helper. Changing the games folder does not move existing games.

`.env` holds the secrets and is readable only by the user, SYSTEM and Administrators.

The wizard runs `windows\install.ps1` (settings are passed in a temporary file that the script merges into `.env` and deletes). It can also be run directly:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File windows\install.ps1 -Root D:\Retro
```

The script:

1. checks the requirements
2. enables WSL and Virtual Machine Platform, installs WSL and Docker Desktop, sets Docker Desktop to start at sign-in without opening its window, then exits with code 3010 and continues after the restart (RunOnce)
3. creates `.env` with generated secrets, `COMPOSE_FILE=compose.yml;compose.windows.yml` and the folder tree
4. removes inbound Block rules for Docker Desktop and allows `ROMM_PORT` and `MINERVA_PORT` on private networks
5. starts the stack, with minerva-helper when `WIREGUARD_PRIVATE_KEY` is set in `.env`
6. puts a `Retro` shortcut on the desktop and opens RomM

Run it again after editing `.env`: existing secrets are kept. The log is in `app\install.log`. Uninstalling stops the containers and keeps `library\`, `data\` and the database volumes.

## Build the installer

```sh
pnpm build:windows   # dist/RetroSetup.exe, Inno Setup in Docker (Wine)
```

CI builds it on `windows-latest` with the preinstalled Inno Setup; the tag workflow attaches it to the GitHub release of each new version.

The installer is not code-signed, so Windows SmartScreen shows a warning (_More info → Run anyway_).

## ES-DE

`install.ps1 -EsDe` downloads the latest ES-DE portable release, RetroArch (`$RetroArchVersion`) and the nightly cores in `$Cores` (ES-DE defaults for NES, SNES, Mega Drive/Master System/Game Gear, Game Boy/Color/Advance, N64, PlayStation, PC Engine, Atari 2600, DS). It sets `ROMDirectory` in `ES-DE\ES-DE\settings\es_settings.xml` to `<games folder>\roms` and `system_directory` in `retroarch.cfg` to `<games folder>\bios`. Existing downloads are kept; changing the games folder updates both settings. Other cores can be added in RetroArch (Online Updater). Media scraped by ES-DE go to `ES-DE\ES-DE\downloaded_media`.

## Differences from Linux

- `compose.windows.yml` keeps MariaDB and Redis in named volumes: bind mounts from NTFS are much slower for small files. They live inside Docker Desktop's disk, so resetting or uninstalling Docker Desktop deletes them.
- The library stays on NTFS, so ES-DE on the same PC can use it.
- RomM is reachable from other devices only when Windows marks the network as private.
