#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$ROOT_DIR/config"
CACHE_DIR="$ROOT_DIR/cache"
TEMPLATES_DIR="$ROOT_DIR/templates"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Не найдено: $1"
    exit 1
  fi
}

require_cmd docker

if docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD="docker-compose"
else
  echo "Не найден Docker Compose (ни plugin 'docker compose', ни бинарь 'docker-compose')."
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "Docker daemon недоступен. Запустите Docker и повторите."
  exit 1
fi

HOST_ARCH="$(uname -m)"
case "$HOST_ARCH" in
  x86_64) TARGET_ARCH="amd64" ;;
  aarch64|arm64) TARGET_ARCH="arm64" ;;
  *) TARGET_ARCH="unknown" ;;
esac
echo "Host architecture: $HOST_ARCH (target: $TARGET_ARCH)"
if [[ "$TARGET_ARCH" == "unknown" ]]; then
  echo "Неизвестная архитектура хоста. Dockerfile поддерживает amd64/arm64."
fi

if [[ ! -f "$ROOT_DIR/app/lampac-go-amd64" || ! -f "$ROOT_DIR/app/lampac-go-arm64" ]]; then
  echo "Не найдены бинарники app/lampac-go-amd64 и app/lampac-go-arm64."
  echo "Проверьте комплект поставки."
  exit 1
fi

mkdir -p "$CONFIG_DIR" "$CACHE_DIR"

if [[ ! -f "$ROOT_DIR/.env" ]]; then
  cp "$ROOT_DIR/.env.example" "$ROOT_DIR/.env"
  echo "Создан .env из .env.example"
fi

if [[ ! -f "$CONFIG_DIR/current.conf" ]]; then
  cp "$TEMPLATES_DIR/current.conf" "$CONFIG_DIR/current.conf"
  echo "Создан config/current.conf из шаблона"
fi

read -r -p "Включить TelegramAuth? [y/N]: " TG_ENABLE_INPUT
TG_ENABLE_INPUT="$(printf '%s' "$TG_ENABLE_INPUT" | tr '[:upper:]' '[:lower:]')"
TG_ENABLE=false
if [[ "$TG_ENABLE_INPUT" == "y" || "$TG_ENABLE_INPUT" == "yes" || "$TG_ENABLE_INPUT" == "д" || "$TG_ENABLE_INPUT" == "да" ]]; then
  TG_ENABLE=true
fi

TG_BOT_TOKEN=""
TG_ADMIN_ID="0"
TG_BOT_NAME=""

if [[ "$TG_ENABLE" == "true" ]]; then
  read -r -p "Введите Telegram bot token: " TG_BOT_TOKEN
  read -r -p "Введите Telegram admin id: " TG_ADMIN_ID
  read -r -p "Введите Telegram bot username (без @, можно пусто): " TG_BOT_NAME
fi

read -r -p "Videoseed token (Enter = пусто): " VIDEOSEED_TOKEN
read -r -p "Collaps token (Enter = пусто): " COLLAPS_TOKEN
read -r -p "Mirage token (Enter = пусто): " MIRAGE_TOKEN

json_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

json_string_or_null() {
  local value="$1"
  if [[ -z "$value" ]]; then
    printf 'null'
  else
    printf '"%s"' "$(json_escape "$value")"
  fi
}

json_string() {
  printf '"%s"' "$(json_escape "$1")"
}

if [[ -z "${TG_ADMIN_ID// }" ]]; then
  TG_ADMIN_ID="0"
fi
if ! [[ "$TG_ADMIN_ID" =~ ^[0-9]+$ ]]; then
  echo "TG admin id должен быть числом. Использую 0."
  TG_ADMIN_ID="0"
fi

cat > "$CONFIG_DIR/init.json" <<EOF
{
  "Videoseed": {
    "token": $(json_string_or_null "$VIDEOSEED_TOKEN")
  },
  "Collaps": {
    "token": $(json_string_or_null "$COLLAPS_TOKEN")
  },
  "Mirage": {
    "token": $(json_string_or_null "$MIRAGE_TOKEN")
  },
  "TelegramAuth": {
    "enable": $TG_ENABLE,
    "bot_token": $(json_string "$TG_BOT_TOKEN"),
    "admin_id": $TG_ADMIN_ID,
    "bot_name": $(json_string "$TG_BOT_NAME")
  }
}
EOF

echo
echo "Готово."
echo "Дальше:"
echo "  cd $ROOT_DIR"
echo "  $COMPOSE_CMD up -d --build"
echo
echo "Логи:"
echo "  $COMPOSE_CMD logs -f lampac-go"
