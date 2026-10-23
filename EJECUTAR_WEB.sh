#!/usr/bin/env sh
set -e
cd "$(dirname "$0")"
flutter pub get
flutter run -d chrome --web-port 8080 --dart-define=API_BASE_URL=http://localhost:3000
