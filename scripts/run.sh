#!/bin/zsh
# Build and launch Minecraft Server Viewer.
#
# Usage: scripts/run.sh [--release] [--logs]
#   --release  build the Release configuration (default: Debug)
#   --logs     run in the foreground so print() output shows in this terminal
set -euo pipefail

cd "$(dirname "$0")/.."

configuration=Debug
logs=false
for arg in "$@"; do
    case $arg in
        --release) configuration=Release ;;
        --logs) logs=true ;;
        -h|--help) sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

app_name=MinecraftServerViewer
# Debug builds are named "MinecraftServerViewer (Debug)" (PRODUCT_NAME in the project).
product_name=$app_name
[[ $configuration == Debug ]] && product_name="$app_name (Debug)"
derived_data=build
app="$derived_data/Build/Products/$configuration/$product_name.app"

echo "▸ Building $configuration…"
xcodebuild -project "$app_name.xcodeproj" \
    -scheme "$app_name" \
    -configuration "$configuration" \
    -destination "platform=macOS,arch=$(uname -m)" \
    -derivedDataPath "$derived_data" \
    -allowProvisioningUpdates \
    -quiet build

# Bump the bundle date and re-register it so Finder and the Dock pick up icon changes.
touch "$app"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$app"

# Quit a running copy so the new build is the one that opens.
# pgrep takes a regex, so escape the parentheses in "(Debug)".
process_pattern=${product_name//\(/\\(}
process_pattern=${process_pattern//\)/\\)}
if pgrep -xq "$process_pattern"; then
    echo "▸ Quitting running app…"
    osascript -e "quit app \"$product_name\"" || true
    while pgrep -xq "$process_pattern"; do /bin/sleep 0.2; done
fi

if $logs; then
    echo "▸ Running in foreground (Ctrl+C to quit)…"
    exec "$app/Contents/MacOS/$product_name"
else
    echo "▸ Launching $app"
    open "$app"
fi
