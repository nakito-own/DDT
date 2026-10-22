#!/usr/bin/env bash
# Собирает release APK и App Bundle.
# Подпись сейчас debug-ключом из android/app/build.gradle.kts.
# Для публикации в Google Play замените signingConfig на release-keystore.
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
api_url="${1:-${API_URL:-}}"

if [[ -z "$api_url" ]]; then
  echo "Usage: $0 <API_URL>" >&2
  echo "Example: $0 https://sixseven.nakito-own.ru" >&2
  exit 1
fi

api_url="${api_url%/}"

(
  cd "$repo_root/frontend"
  flutter pub get
  flutter build appbundle --release --dart-define="API_URL=$api_url"
  flutter build apk --release --dart-define="API_URL=$api_url"
)

echo "Android release artifacts:"
echo "  $repo_root/frontend/build/app/outputs/bundle/release/app-release.aab"
echo "  $repo_root/frontend/build/app/outputs/flutter-apk/app-release.apk"
echo "API_URL=$api_url"
