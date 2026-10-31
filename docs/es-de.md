# ES-DE on the library disk

[ES-DE](https://es-de.org) is the frontend, RetroArch and standalone emulators run the games. ES-DE, the emulators, their settings and the scraped media live on the same disk as the library, so the disk starts the same setup on any Linux PC.

## Layout

```
<disk>/
├── ES-DE.sh                       start script: sets HOME to es-de/home, runs ES-DE with --home
├── Skyscraper.sh                  scraper: media to library/roms/<system>/<type>, gamelists for ES-DE and RomM
├── es-de/
│   ├── ES-DE_x64.AppImage
│   └── home/
│       ├── ES-DE/                 settings, gamelists, themes, collections
│       ├── ROMs -> ../../library/roms
│       ├── Applications/          RetroArch, Cemu, xemu and Skyscraper AppImages
│       ├── .skyscraper/           config.ini (ScreenScraper login), artwork-esde.xml, cache
│       ├── .config/retroarch/     retroarch.cfg, cores/, saves/, states/, system -> ../../../../library/bios
│       └── .local/share/Cemu/     keys.txt
└── library/                       roms/, bios/ (shared with RomM)
```

Every path inside is relative (`~/…` or a relative symlink), so the mount point does not matter. ES-DE takes `retroarch` from `PATH` when the PC has one installed, otherwise the AppImage from `~/Applications`; either way it loads the cores, config and BIOS from the disk.

## Build it

1. ES-DE: download `ES-DE_x64.AppImage` to `es-de/` (latest from `https://gitlab.com/api/v4/projects/es-de%2Femulationstation-de/releases/permalink/latest`).
2. RetroArch: unpack `RetroArch.7z` and `RetroArch_cores.7z` from `https://buildbot.libretro.com/stable/<version>/linux/x86_64/`; move the AppImage to `home/Applications/` and the bundled `.config/retroarch` (assets, shaders, autoconfig, cores) to `home/.config/retroarch/`. Do not keep a `RetroArch-Linux-x86_64.AppImage.home` directory, it would override `HOME`.
3. In `retroarch.cfg` keep every directory under `~/.config/retroarch/` and point `system` at the BIOS with a relative symlink.
4. In `es_settings.xml` set `ROMDirectory` and `MediaDirectory` to `~/ROMs`, so media sit next to the games where RomM reads them too.
5. Standalone emulators: put their AppImages in `home/Applications/` (ES-DE's find rules look there); Cemu reads `keys.txt` from `~/.local/share/Cemu/`.
6. Skyscraper: download `Skyscraper-<version>-x86_64.AppImage` from `https://github.com/Gemba/skyscraper/releases` to `home/Applications/`; in `home/.skyscraper/config.ini` set `frontend="esde"`, `videos`, `manuals`, `fanarts`, `backcovers`, `unattend` to `"true"`, `artworkXml="artwork-esde.xml"` (raw `screenshot`, `cover`, and `wheel` as `marquee`) and `userCreds` under `[screenscraper]`.

## Use it

Run `<disk>/ES-DE.sh`. For a desktop launcher or Sunshine, use the same script as the command.

Scrape with `<disk>/Skyscraper.sh [system ...]` (no argument: every system). It writes media to `library/roms/<system>/<type>/` with a `noload.txt` so ES-DE does not scan them as games, the gamelist to `ES-DE/gamelists/<system>/` and a copy to `library/roms/<system>/gamelist.xml` for RomM. Miximages: ES-DE, _Scraper → Miximage settings → Offline generator_. RomM: scan with the _Gamelist_ metadata source (`config/romm/config.yml` puts it first).

The disk must be mounted with exec permissions and the files must belong to the user (UID 1000 by default). AppImages need FUSE on the host.
