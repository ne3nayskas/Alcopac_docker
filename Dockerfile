FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        tzdata \
        ffmpeg \
        curl \
        wget \
        unzip \
        rsync \
        proxychains4 \
        nodejs \
    && (apt-get install -y --no-install-recommends chromium \
        || apt-get install -y --no-install-recommends chromium-browser \
        || true) \
    && rm -rf /var/lib/apt/lists/*

# yt-dlp runtime check expects `node` binary name.
RUN if [ ! -x /usr/bin/node ] && [ -x /usr/bin/nodejs ]; then ln -s /usr/bin/nodejs /usr/bin/node; fi

WORKDIR /opt/lampac

COPY app/lampac-go /usr/local/bin/lampac-go
COPY app/module /opt/lampac/module
COPY app/plugins /opt/lampac/plugins
COPY app/wwwroot /opt/lampac/wwwroot
COPY app/torrserver /opt/lampac/torrserver
COPY app/bin /opt/lampac/bin
COPY templates /opt/lampac/templates
COPY docker/entrypoint.sh /entrypoint.sh

RUN chmod +x /usr/local/bin/lampac-go /entrypoint.sh

ENV LAMPAC_GO_ADDR=0.0.0.0:18118 \
    LAMPAC_GO_REPO_ROOT=/opt/lampac \
    LAMPAC_GO_CACHE_DIR=/opt/lampac/cache \
    LAMPAC_GO_LOCAL_CORE=true \
    LAMPAC_GO_FALLBACK_ENABLE=false

EXPOSE 18118

ENTRYPOINT ["/entrypoint.sh"]
