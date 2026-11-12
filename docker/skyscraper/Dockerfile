FROM debian:bookworm-slim

ARG SKYSCRAPER_VERSION=3.21.1

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl libegl1 libgl1 libopengl0 libharfbuzz0b libfontconfig1 libglib2.0-0 shared-mime-info \
  && curl -fsSL -o /tmp/skyscraper.AppImage "https://github.com/Gemba/skyscraper/releases/download/${SKYSCRAPER_VERSION}/Skyscraper-${SKYSCRAPER_VERSION}-x86_64.AppImage" \
  && chmod +x /tmp/skyscraper.AppImage \
  && cd /opt && /tmp/skyscraper.AppImage --appimage-extract >/dev/null \
  && mv /opt/squashfs-root /opt/skyscraper \
  && rm /tmp/skyscraper.AppImage \
  && apt-get purge -y curl && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

ENV QT_QPA_PLATFORM=offscreen
COPY artwork-esde.xml /usr/local/share/retro/artwork-esde.xml
COPY --chmod=755 scrape.sh /usr/local/bin/scrape
ENTRYPOINT ["scrape"]
