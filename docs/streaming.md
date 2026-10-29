# Streaming

[Sunshine](https://github.com/LizardByte/Sunshine) on the gaming host, [Moonlight](https://moonlight-stream.org) on TVs, tablets, phones and PCs.

## Sunshine (Arch Linux, NVIDIA)

Use LizardByte's prebuilt package: it is built with CUDA (NVENC). Packages compiled elsewhere only have CUDA if the toolkit was present at build time.

Add the repo to `/etc/pacman.conf` **above** any other repo that also ships `sunshine` (pacman takes a package from the first repo that has it):

```conf
[lizardbyte]
SigLevel = Optional
Server = https://github.com/LizardByte/pacman-repo/releases/latest/download
```

```sh
sudo pacman -Syu
sudo pacman -S lizardbyte/sunshine
sudo gpasswd -a "$USER" input        # virtual gamepads, keyboard, mouse; log out and back in
systemctl --user --now enable app-dev.lizardbyte.app.Sunshine
```

Web UI: `https://localhost:47990` (create the admin login on first visit).

### Hyprland

Use the `wlr` capture method; it can also capture a virtual output, so the client gets its native resolution without touching the physical monitor:

```sh
hyprctl output create headless STREAM
hyprctl eval 'hl.monitor({ output = "STREAM", mode = "1920x1080@120", position = "auto", scale = 1 })'
```

With a Lua config (e.g. Hyprland 0.56) `hyprctl keyword` is rejected; hyprlang configs use `hyprctl keyword monitor STREAM,1920x1080@120,auto,1`. Both are lost on restart; to keep the rule, add the same `hl.monitor(...)` line to `~/.config/hypr/monitors.lua`.

In Sunshine → Configuration → Audio/Video: `capture = wlr`, `output_name = STREAM`. Remove the output with `hyprctl output remove STREAM`.

### Applications

Sunshine → Applications → add **ES-DE** with command `~/Applications/ES-DE_x64.AppImage` (fullscreen by default).

## Clients

- Android, iOS, Windows, macOS, Linux: official [Moonlight](https://moonlight-stream.org) apps; pair with the PIN shown in Sunshine's web UI.
- LG webOS TV: [Moonlight TV](https://github.com/mariotaku/moonlight-tv) (webOS 4.x and newer; 4.3.0 may not work).
  1. Install **Developer Mode** from the LG Content Store, sign in with an LG developer account, enable Dev Mode and the key server.
  2. Install [webOS Dev Manager](https://github.com/webosbrew/dev-manager-desktop) on a PC, add the TV, install Moonlight TV from its app list.
  3. Developer Mode expires (session up to 999 h) and its apps are removed then; renew it in the Developer Mode app or with Dev Manager's scheduled renewal.

Use wired Ethernet for the host and, where possible, the TV.
