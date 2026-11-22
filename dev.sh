#!/usr/bin/env bash
# Little Pilot developer commands. Usage: ./dev.sh <command>
#   editor   open the project in the Godot editor
#   run      play the game in a window        (add "full" for fullscreen)
#   city N   play with the city grown N hours ahead (preview only, not saved)
#   props    rebuild the outfit props in Blender (Flatpak)
#   test     run all headless tests (exit code 0 = all pass)
#   check    import, load every script/scene, boot headless; fail on errors
#   export   build ../LittlePilot-builds/LittlePilot.x86_64 (release)
set -euo pipefail
cd "$(dirname "$0")"
GODOT="${GODOT:-flatpak run org.godotengine.Godot}"
BUILD_DIR="${BUILD_DIR:-../LittlePilot-builds}"

case "${1:-}" in
  editor) $GODOT --path . --editor ;;
  run)    if [[ "${2:-}" == full ]]; then $GODOT --path . --fullscreen; else $GODOT --path .; fi ;;
  test)   fail=0
          for t in controller_test save_test crash_test dragon_test star_run_test city_growth_test landing_test walk_test character_test character_screen_test delivery_test house_test treasure_test post_office_test stress_test; do
            echo "=== $t"
            # Capture the exit code directly (a pipe would lose it).
            out=$($GODOT --headless --path . --fixed-fps 60 "res://tests/$t.tscn" 2>&1) && status=0 || status=$?
            grep -E "PASS|FAIL|note|ERROR|---|Stars|unreached|#[0-9]" <<<"$out" || true
            [[ $status -eq 0 ]] || { fail=1; echo "!!! $t exited with $status"; }
          done
          [[ $fail -eq 0 ]] && echo "ALL TESTS PASSED" || { echo "SOME TESTS FAILED"; exit 1; } ;;
  city)   $GODOT --path . -- "--city-hours=${2:-12}" ;;
  props)  flatpak run org.blender.Blender -b --factory-startup -P "$PWD/tools/blender/build_props.py" \
            -- "$PWD/assets/characters/props/props.glb" | grep -E "PROPS|tris|BUILT|Error|Traceback"
          $GODOT --headless --path . --import >/dev/null 2>&1 || true ;;
  check)  # Three steps; each keeps Godot's real exit status (no pipes):
          #   1 import the project (assets and scripts)
          #   2 load every script and scene (tools/check_scripts.gd), so a
          #     broken script nothing uses yet is still caught
          #   3 start the game headless for a few frames (autoloads, main scene)
          # Fails on a non-zero exit or any ERROR line; warnings print but
          # don't fail. "No errors." only when all three are clean.
          fail=0
          for step in import scripts boot; do
            case $step in
              import)  args=(--headless --path . --import) ;;
              scripts) args=(--headless --path . -s res://tools/check_scripts.gd) ;;
              boot)    args=(--headless --path . --quit-after 30) ;;
            esac
            out=$($GODOT "${args[@]}" 2>&1) && status=0 || status=$?
            grep -E "WARNING" <<<"$out" || true
            errors=$(grep -E "ERROR|SCRIPT CHECK FAILED" <<<"$out" || true)
            if [[ $status -ne 0 || -n "$errors" ]]; then
              [[ -n "$errors" ]] && echo "$errors"
              echo "!!! check step '$step' failed (exit $status)"
              fail=1
            fi
          done
          [[ $fail -eq 0 ]] && echo "No errors." || { echo "CHECK FAILED"; exit 1; } ;;
  export) mkdir -p "$BUILD_DIR"
          $GODOT --headless --path . --export-release Linux "$BUILD_DIR/LittlePilot.x86_64" >/dev/null
          echo "Built $(realpath "$BUILD_DIR/LittlePilot.x86_64")" ;;
  *)      sed -n '2,10p' "$0"; exit 1 ;;
esac
