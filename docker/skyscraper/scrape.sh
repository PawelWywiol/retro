#!/bin/sh
# Scrapes media into /library/roms/<system>/<type>, read by both ES-DE and RomM.
# Usage: scrape [system ...]   (no arguments: every folder in /library/roms)
roms=/library/roms
sky=/opt/skyscraper/AppRun
cfg="$HOME/.skyscraper"

mkdir -p "$cfg"
cp /usr/local/share/retro/artwork-esde.xml "$cfg/"
cat >"$cfg/config.ini" <<EOF
[main]
subdirs="false"
frontend="esde"
videos="true"
manuals="true"
fanarts="true"
backcovers="true"
unattend="true"
artworkXml="artwork-esde.xml"

[screenscraper]
${SCREENSCRAPER_USER:+userCreds="$SCREENSCRAPER_USER:$SCREENSCRAPER_PASSWORD"}
EOF

# ES-DE folder name -> Skyscraper platform, where they differ
platform() {
  case "$1" in
    amiga1200) echo amiga ;;
    commodore-c128) echo c128 ;;
    dos) echo pc ;;
    famicom) echo nes ;;
    fbneo) echo fba ;;
    genesis | megadrivejp) echo megadrive ;;
    saturnjp) echo saturn ;;
    sfc) echo snes ;;
    supergrafx | tg16) echo pcengine ;;
    tg-cd) echo pcenginecd ;;
    *) echo "$1" ;;
  esac
}

# ES-DE runs a folder like Game.cue/ holding Game.cue as one game named Game.cue
dir_games() {
  for d in "$src"/*/; do
    n=$(basename "$d")
    [ -f "$d$n" ] && printf '%s\n' "$n"
  done
}

[ $# -gt 0 ] || for d in "$roms"/*/; do [ -n "$(ls -A "$d")" ] && set -- "$@" "$(basename "$d")"; done
for sys; do
  src="$roms/$sys"
  [ -d "$src" ] || { echo "skip $sys: no $src"; continue; }
  gamelists="/gamelists/$sys"
  in="$src"
  # Skyscraper turns such folders into skipped <folder> entries, so it scrapes a flat view of links instead
  if [ -n "$(dir_games)" ]; then
    in="/tmp/view/$sys"
    rm -rf "$in" && mkdir -p "$in"
    for f in "$src"/*; do
      n=$(basename "$f")
      if [ -f "$f/$n" ]; then ln -s "$f/$n" "$in/$n"; else ln -s "$f" "$in/$n"; fi
    done
  fi
  run() { "$sky" -p "$(platform "$sys")" -i "$in" -g "$gamelists" -o "$src" "$@"; }
  if ! run -s screenscraper || ! run; then continue; fi
  for media in "$src"/*/; do
    case "$(basename "$media")" in
      3dboxes | backcovers | covers | fanart | manuals | marquees | miximages | physicalmedia | screenshots | titlescreens | videos)
        : >"$media/noload.txt"
        # ES-DE and RomM look for Game.cue.png, Skyscraper writes Game.png
        dir_games | while IFS= read -r n; do
          rm -rf "${media:?}$n"
          for m in "$media${n%.*}".*; do
            ext=${m#"$media${n%.*}".}
            case "$ext" in *.*) continue ;; esac
            [ -f "$m" ] && mv -f "$m" "$media$n.$ext"
          done
        done
        ;;
    esac
  done
  # ES-DE skips entries outside its own ROM folder path, so paths must be ./ relative
  prefix=$(printf '%s/' "$in" | sed 's/[]\|$*.^[]/\\&/g')
  sed -i "s|<path>$prefix|<path>./|" "$gamelists/gamelist.xml"
  # RomM only reads gamelist.xml from the system folder
  cp "$gamelists/gamelist.xml" "$src/gamelist.xml"
done
