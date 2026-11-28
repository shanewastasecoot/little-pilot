#!/usr/bin/env bash
# Little Pilot developer commands. Usage: ./dev.sh <command>
#   editor   open the project in the Godot editor
#   run      play the game in a window        (add "full" for fullscreen)
#   city N   play with the city grown N hours ahead (preview only, not saved)
#   props    rebuild the outfit props in Blender (Flatpak)
#   test     run all headless tests (exit code 0 = all pass)
#   check    import, load every script/scene, boot headless; fail on errors
#   export   build ../LittlePilot-builds/LittlePilot.x86_64 (release)
#   credits  write CREDITS.md from resources/credits.json
#   bench-sim     simulation cost along a fixed route, headless (not FPS)
#   bench-render  frame times per area on screen, 1280x800 (add -- --bench-...)
#   shots [label] pictures from fixed camera spots -> user://bench/shots/<label>/
#                 (then variants, then extras like --contact=0,0,0)
#   audit-aircraft  what each aircraft model is made of (parts, triangles...)
set -euo pipefail
cd "$(dirname "$0")"
GODOT="${GODOT:-flatpak run org.godotengine.Godot}"
BUILD_DIR="${BUILD_DIR:-../LittlePilot-builds}"

case "${1:-}" in
  editor) $GODOT --path . --editor ;;
  run)    if [[ "${2:-}" == full ]]; then $GODOT --path . --fullscreen; else $GODOT --path .; fi ;;
  test)   fail=0
          for t in controller_test save_test crash_test dragon_test star_run_test city_growth_test landing_test walk_test character_test character_screen_test delivery_test house_test treasure_test post_office_test city_house_test hat_shop_test reactions_test credits_test aircraft_view_test save_safety_test style_test contact_shade_test terrain_detail_test render_settings_test audio_test service_test livery_test skywriting_test summary_test sticker_book_test parachute_test boat_test seaplane_test loop_test follow_test all_stars_test weather_test stress_test; do
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
  credits) # (Import first, so a new script class is known; then write the file.)
          $GODOT --headless --path . --import >/dev/null 2>&1 || true
          $GODOT --headless --path . res://tools/make_credits.tscn 2>&1 | grep -E "Wrote|ERROR" ;;
  bench-sim) shift
          $GODOT --headless --path . --fixed-fps 60 res://tools/bench_sim.tscn "$@" 2>&1 | grep -vE "^(Godot Engine|WARNING|   at:|$)" ;;
  bench-render) shift
          $GODOT --path . --resolution 1280x800 --rendering-method mobile res://tools/bench_render.tscn "$@" 2>&1 \
            | grep -vE "^(Godot Engine|Vulkan|WARNING|   at:|$)" ;;
  shots)  shift
          $GODOT --path . --resolution 1280x800 --rendering-method mobile res://tools/bench_shots.tscn -- --label="${1:-now}" --variants="${2:-}" "${@:3}" 2>&1 \
            | grep -E "shot|Saved|SCRIPT ERROR" ;;
  audit-aircraft) $GODOT --headless --path . res://tools/aircraft_audit.tscn 2>&1 | grep -vE "^(Godot Engine|WARNING|   at:|$)" ;;
  *)      sed -n '2,14p' "$0"; exit 1 ;;
esac
