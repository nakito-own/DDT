#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

usage() {
  cat <<'EOF'
Запуск дашборда с API-сервером.

Использование:
  ./run_server.sh [IP] [опции]

  IP              Адрес публикации (по умолчанию 127.0.0.1 — только локально)
  0.0.0.0         Слушать все интерфейсы (удобно для LAN)

Опции:
  --host IP       Адрес публикации
  -p, --port N    Порт (по умолчанию 8765)

Переменные окружения:
  HOST, PORT      То же, что --host и --port

Примеры:
  ./run_server.sh                          # localhost
  ./run_server.sh 192.168.1.42             # конкретный IP в LAN
  ./run_server.sh 0.0.0.0                  # все интерфейсы
  ./run_server.sh --host 192.168.1.42 -p 9000
EOF
}

if [[ ! -x venv/bin/python ]]; then
  echo "Создайте venv и установите зависимости:"
  echo "  python3 -m venv venv"
  echo "  ./venv/bin/pip install -r requirements-server.txt"
  exit 1
fi

HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8765}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --host)
      [[ $# -ge 2 ]] || { echo "Ошибка: --host требует значение"; exit 1; }
      HOST="$2"
      shift 2
      ;;
    -p|--port)
      [[ $# -ge 2 ]] || { echo "Ошибка: --port требует значение"; exit 1; }
      PORT="$2"
      shift 2
      ;;
    -*)
      echo "Неизвестная опция: $1"
      usage
      exit 1
      ;;
    *)
      HOST="$1"
      shift
      ;;
  esac
done

echo "Запуск на http://${HOST}:${PORT}"

if [[ "$HOST" == "0.0.0.0" ]]; then
  echo "Доступ в локальной сети:"
  while IFS= read -r addr; do
    echo "  http://${addr}:${PORT}"
  done < <(
    if command -v ip >/dev/null 2>&1; then
      ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1
    else
      for iface in en0 en1 eth0; do
        ipconfig getifaddr "$iface" 2>/dev/null || true
      done | grep -v '^$'
    fi
  )
elif [[ "$HOST" != "127.0.0.1" && "$HOST" != "localhost" ]]; then
  echo "  http://${HOST}:${PORT}"
fi

exec ./venv/bin/uvicorn server.app:app --host "$HOST" --port "$PORT" --reload
