#!/bin/sh
# Builds the web app with a production API address and deploys it to Firebase Hosting.
#   API_BASE_URL=https://your-api.example.com sh scripts/deploy-web.sh
#   add --build-only to skip the deploy
# Until the backend is online use https://api.invalid: the address can never resolve, so data sections fail cleanly.
set -e
cd "$(git rev-parse --show-toplevel)"

case "${API_BASE_URL:-}" in
  https://*) ;;
  *) echo "API_BASE_URL must be set to an https address." >&2; exit 1 ;;
esac

# The build bundles app.env, so swap in the production one and put any local file back afterwards.
env_file=assets/env/app.env
backup="$env_file.local"
[ -f "$env_file" ] && mv "$env_file" "$backup"
restore() {
  rm -f "$env_file"
  if [ -f "$backup" ]; then mv "$backup" "$env_file"; fi
}
trap restore EXIT

echo "API_BASE_URL=$API_BASE_URL" > "$env_file"
flutter build web --release

[ "${1:-}" = "--build-only" ] && exit 0
firebase deploy --only hosting
