#!/usr/bin/env bash
# Little Pilot developer commands. Usage: ./dev.sh <command>
#   editor   open the project in the Godot editor
#   run      play the game in a window        (add "full" for fullscreen)
#   city N   play with the city grown N hours ahead (preview only, not saved)
#   test     run all headless tests (exit code 0 = all pass)
#   check    import the project and report script errors, no window
#   export   build ../LittlePilot-builds/LittlePilot.x86_64 (release)
set -euo pipefail
cd "$(dirname "$0")"
GODOT="${GODOT:-flatpak run org.godotengine.Godot}"
BUILD_DIR="../LittlePilot-builds"

case "${1:-}" in
  editor) $GODOT --path . --editor ;;
  run)    if [[ "${2:-}" == full ]]; then $GODOT --path . --fullscreen; else $GODOT --path .; fi ;;
  test)   fail=0
          for t in controller_test save_test crash_test dragon_test star_run_test city_growth_test landing_test walk_test stress_test; do
            echo "=== $t"
            # Capture the exit code directly (a pipe would lose it).
            out=$($GODOT --headless --path . --fixed-fps 60 "res://tests/$t.tscn" 2>&1) && status=0 || status=$?
            grep -E "PASS|FAIL|note|ERROR|---|Stars|unreached|#[0-9]" <<<"$out" || true
            [[ $status -eq 0 ]] || { fail=1; echo "!!! $t exited with $status"; }
          done
          [[ $fail -eq 0 ]] && echo "ALL TESTS PASSED" || { echo "SOME TESTS FAILED"; exit 1; } ;;
  city)   $GODOT --path . -- "--city-hours=${2:-12}" ;;
  check)  $GODOT --headless --path . --import 2>&1 | grep -E "ERROR|SCRIPT ERROR|WARNING" || echo "No errors." ;;
  export) mkdir -p "$BUILD_DIR"
          $GODOT --headless --path . --export-release Linux "$BUILD_DIR/LittlePilot.x86_64" >/dev/null
          echo "Built $(realpath "$BUILD_DIR/LittlePilot.x86_64")" ;;
  *)      sed -n '2,9p' "$0"; exit 1 ;;
esac
