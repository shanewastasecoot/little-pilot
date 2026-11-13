#!/usr/bin/env bash
# Little Pilot developer commands. Usage: ./dev.sh <command>
#   editor   open the project in the Godot editor
#   run      play the game in a window        (add "full" for fullscreen)
#   test     run the headless flight stress test (exit code 0 = pass)
#   check    import the project and report script errors, no window
#   export   build ../LittlePilot-builds/LittlePilot.x86_64 (release)
set -euo pipefail
cd "$(dirname "$0")"
GODOT="${GODOT:-flatpak run org.godotengine.Godot}"
BUILD_DIR="../LittlePilot-builds"

case "${1:-}" in
  editor) $GODOT --path . --editor ;;
  run)    if [[ "${2:-}" == full ]]; then $GODOT --path . --fullscreen; else $GODOT --path .; fi ;;
  test)   $GODOT --headless --path . --fixed-fps 60 res://tests/stress_test.tscn ;;
  check)  $GODOT --headless --path . --import 2>&1 | grep -E "ERROR|SCRIPT ERROR|WARNING" || echo "No errors." ;;
  export) mkdir -p "$BUILD_DIR"
          $GODOT --headless --path . --export-release Linux "$BUILD_DIR/LittlePilot.x86_64" >/dev/null
          echo "Built $(realpath "$BUILD_DIR/LittlePilot.x86_64")" ;;
  *)      sed -n '2,8p' "$0"; exit 1 ;;
esac
