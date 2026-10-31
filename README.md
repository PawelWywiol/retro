# retro

Self-hosted retro gaming stack in Docker Compose:

- [RomM](https://github.com/rommapp/romm): library manager with metadata and in-browser play (EmulatorJS)
- [minerva-helper-web-app](https://github.com/PawelWywiol/minerva-helper-web-app): picks single games out of the MiNERVA archive and files them into the library (optional, routed through VPN)
- [gluetun](https://github.com/qdm12/gluetun): VPN client used only by minerva-helper

The library uses the [ES-DE](https://es-de.org) folder layout, so the same disk works with ES-DE + RetroArch on the host.

This repository contains configuration only: no games, BIOS files or keys.

## Requirements

- Linux host with Docker Engine and Docker Compose v2
- `openssl`, `make`
- a WireGuard (or OpenVPN) account supported by gluetun, only for minerva-helper

## Quick start

```sh
git clone https://github.com/PawelWywiol/retro.git && cd retro
make init        # creates .env with generated secrets
$EDITOR .env     # set LIBRARY_PATH, DATA_PATH, ports, optional metadata keys
make init        # creates the folder tree and the RomM config
make up          # RomM only
make up-all      # RomM + gluetun + minerva-helper (needs the VPN settings in .env)
```

RomM: `http://<host>:${ROMM_PORT}`, minerva-helper: `http://<host>:${MINERVA_PORT}`.

## Layout

```
${LIBRARY_PATH}/
├── roms/<system>/   ES-DE system names: nes, snes, megadrive, psx, gc, n3ds, ...
└── bios/
${DATA_PATH}/
├── romm/{resources,assets,config,redis}
├── mariadb/
├── gluetun/
└── minerva/
```

`config/romm/config.yml` maps ES-DE folder names to RomM platform slugs where they differ. `make init` copies it to `${DATA_PATH}/romm/config/` once; edit the copy there.

## Guides

- [Library disk](docs/storage.md)
- [ES-DE on the library disk](docs/es-de.md)
- [Streaming with Sunshine and Moonlight](docs/streaming.md)

## Commands

| Command        | Action                                     |
| -------------- | ------------------------------------------ |
| `make init`    | create `.env`, secrets and folders         |
| `make up`      | start RomM                                 |
| `make up-all`  | start everything, including minerva-helper |
| `make down`    | stop everything                            |
| `make logs`    | follow logs                                |
| `make pull`    | pull pinned images                         |

## Development

Node 26 and pnpm are used only for tooling.

```sh
pnpm install      # also installs git hooks (lefthook)
pnpm fmt:check    # oxfmt
pnpm lint         # shellcheck, actionlint, compose validation (via Docker)
pnpm secrets      # gitleaks over the git history
pnpm audit        # audit-ci
pnpm release      # commit-and-tag-version
```

Commits follow [Conventional Commits](https://www.conventionalcommits.org) (commitlint, header ≤ 70 chars).

## Security

See [SECURITY.md](SECURITY.md). Never commit `.env`, `data/` or anything from the library.

## License

[MIT](LICENSE)
