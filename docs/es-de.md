# ES-DE on the host

[ES-DE](https://es-de.org) is the frontend, RetroArch and standalone emulators run the games. Both read the same library as RomM.

## Install (Arch Linux)

```sh
sudo pacman -S retroarch libretro-core-info \
  libretro-nestopia libretro-snes9x libretro-genesis-plus-gx libretro-picodrive \
  libretro-gambatte libretro-mgba libretro-mupen64plus-next libretro-beetle-psx-hw \
  libretro-flycast libretro-dolphin libretro-ppsspp libretro-melonds \
  libretro-beetle-pce-fast libretro-mame libretro-scummvm

mkdir -p ~/Applications
curl -fL -o ~/Applications/ES-DE_x64.AppImage \
  "$(curl -sL https://gitlab.com/api/v4/projects/es-de%2Femulationstation-de/releases/permalink/latest \
    | jq -r '.assets.links[] | select(.name == "ES-DE_x64.AppImage") | .url')"
chmod +x ~/Applications/ES-DE_x64.AppImage
```

If the AppImage refuses to start with a FUSE error, install `fuse2`.

## Configure

1. Start ES-DE. On first run choose **change ROM directory** and pick `${LIBRARY_PATH}/roms`.
2. Menu → Utilities → **Create/update system directories** adds the ES-DE folder for every system.
3. RetroArch → Settings → Directory → **System/BIOS** = `${LIBRARY_PATH}/bios`.
4. Optional: in RomM enable gamelist export so ES-DE gets metadata and artwork without scraping twice.

Systems ES-DE launches through standalone emulators (e.g. PS2, Switch) need those emulators installed separately; ES-DE shows which one is missing when a game fails to start.
