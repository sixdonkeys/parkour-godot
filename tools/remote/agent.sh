#!/bin/sh
# Remote-loop agent (decision remote-test). Piped over SSH on every call
# (`ssh <alias> sh -s -- <verb> <folder> ...`), so nothing is installed on the
# target. It only ever writes inside <folder>, the one folder this build may
# use there. Prints one JSON object per call on stdout.
#
#   agent.sh probe   <folder>                  state of the machine (no writes)
#   agent.sh install <folder> <commit>         unpack <folder>/incoming.* as the build
#   agent.sh run     <folder> <id> <mode> [extra args...]   mode: bench|play
#   agent.sh status  <folder> <id>             is run <id> still going?
#   agent.sh list    <folder>                  result folders present
set -u
VERB=${1:-probe}
DIR=${2:-}
[ -n "$DIR" ] || { echo '{"ok":false,"error":"no folder given"}'; exit 2; }
case "$DIR" in
  "~/"*) DIR="$HOME/${DIR#\~/}" ;;
esac
OS=$(uname -s)

jstr() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | tr -d '\n\r'; }

# --- machine state -----------------------------------------------------------
idle_s() {
  if [ "$OS" = Darwin ]; then
    ioreg -c IOHIDSystem 2>/dev/null | awk '/HIDIdleTime/ {print int($NF/1000000000); exit}'
  else
    v=$(gdbus call --session --dest org.gnome.Mutter.IdleMonitor --object-path /org/gnome/Mutter/IdleMonitor/Core \
        --method org.gnome.Mutter.IdleMonitor.GetIdletime 2>/dev/null | sed -n 's/.*uint64 \([0-9]*\).*/\1/p')
    [ -n "$v" ] && echo $((v / 1000))
  fi
}
locked() {
  if [ "$OS" = Darwin ]; then
    # Joel Bruner's method (docs/survey/remote-test.md): the console session's lock flag.
    v=$(ioreg -n Root -d1 -a 2>/dev/null | /usr/libexec/PlistBuddy -c "print :IOConsoleUsers:0:CGSSessionScreenIsLocked" /dev/stdin 2>/dev/null)
    [ "$v" = "true" ] && echo true || echo false
  else
    s=$(loginctl show-session "$(loginctl list-sessions --no-legend 2>/dev/null | awk -v u="$(id -un)" '$3==u {print $1; exit}')" -p LockedHint --value 2>/dev/null)
    [ -n "$s" ] && { [ "$s" = yes ] && echo true || echo false; } || echo unknown
  fi
}
console_user() {
  if [ "$OS" = Darwin ]; then stat -f %Su /dev/console 2>/dev/null
  else loginctl list-sessions --no-legend 2>/dev/null | awk '$4 ~ /seat/ {print $3; exit}'; fi
}
display_awake() {
  if [ "$OS" = Darwin ]; then
    # pmset reports a display-sleep prevention assertion count; the honest
    # check of an awake display is the game's own frame pacing (see run).
    if pmset -g powerstate 2>/dev/null | grep -qi "AppleDisplay\|DCPAVServiceProxy"; then
      pmset -g powerstate 2>/dev/null | awk '/AppleDisplay|DCPAV/ {print ($2>=4)?"true":"false"; exit}'
    else echo unknown; fi
  else echo unknown; fi
}
power_source() {
  if [ "$OS" = Darwin ]; then pmset -g batt 2>/dev/null | sed -n "s/.*drawing from '\(.*\)'.*/\1/p"
  elif [ -r /sys/class/power_supply/AC/online ]; then [ "$(cat /sys/class/power_supply/AC/online)" = 1 ] && echo "AC Power" || echo "Battery Power"
  else echo unknown; fi
}
low_power() {
  if [ "$OS" = Darwin ]; then
    v=$(pmset -g 2>/dev/null | awk '/lowpowermode/ {print $2; exit}'); [ "$v" = 1 ] && echo true || { [ -n "$v" ] && echo false || echo unknown; }
  else
    p=$(powerprofilesctl get 2>/dev/null); [ "$p" = power-saver ] && echo true || { [ -n "$p" ] && echo false || echo unknown; }
  fi
}
front_app() {
  # macOS 27 prints the front app as: "Terminal" ASN:0x0-0x...: (in front)
  if [ "$OS" = Darwin ]; then lsappinfo info -only name "$(lsappinfo front 2>/dev/null)" 2>/dev/null | sed -n '1s/^"\([^"]*\)".*/\1/p'
  else echo unknown; fi
}
refresh_hz() {
  # system_profiler on macOS 27 doesn't list it for the built-in panel; the
  # game logs DisplayServer.screen_get_refresh_rate() itself.
  echo game-reported
}
case "$VERB" in
probe)
  idle=$(idle_s); [ -n "$idle" ] || idle=null
  printf '{"ok":true,"os":"%s","user":"%s","console_user":"%s","idle_s":%s,"locked":"%s","display_awake":"%s","power":"%s","low_power":"%s","front_app":"%s","refresh_hz":"%s","folder":"%s","folder_exists":%s,"time":"%s"}\n' \
    "$OS" "$(id -un)" "$(jstr "$(console_user)")" "$idle" "$(locked)" "$(display_awake)" \
    "$(jstr "$(power_source)")" "$(low_power)" "$(jstr "$(front_app)")" "$(jstr "$(refresh_hz)")" "$(jstr "$DIR")" \
    "$([ -d "$DIR" ] && echo true || echo false)" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  ;;
install)
  COMMIT=${3:-unknown}
  mkdir -p "$DIR" || { echo '{"ok":false,"error":"cannot create folder"}'; exit 1; }
  cd "$DIR" || exit 1
  # The build always goes to <folder>/build; the previous one is kept as
  # build.prev until the next install, so builds never pile up.
  rm -rf build.new
  mkdir build.new
  if [ -f incoming.zip ]; then
    if [ "$OS" = Darwin ]; then ditto -x -k incoming.zip build.new || { echo '{"ok":false,"error":"unzip failed"}'; exit 1; }
    else unzip -q incoming.zip -d build.new || { echo '{"ok":false,"error":"unzip failed"}'; exit 1; }; fi
  elif [ -f incoming.tar ]; then
    tar -xf incoming.tar -C build.new || { echo '{"ok":false,"error":"untar failed"}'; exit 1; }
  else
    echo '{"ok":false,"error":"nothing to install"}'; exit 1
  fi
  rm -rf build.prev
  [ -d build ] && mv build build.prev
  mv build.new build
  rm -f incoming.zip incoming.tar
  echo "$COMMIT" > build/COMMIT
  printf '{"ok":true,"installed":"%s","commit":"%s"}\n' "$(jstr "$DIR/build")" "$(jstr "$COMMIT")"
  ;;
run)
  ID=${3:?}; MODE=${4:?}; shift 4
  OUT="$DIR/results/$ID"
  mkdir -p "$OUT"
  if [ "$OS" = Darwin ]; then
    APP=$(ls -d "$DIR"/build/*.app 2>/dev/null | head -1)
    EXE="$APP/Contents/MacOS/$(basename "$APP" .app)"
  else
    EXE=$(ls "$DIR"/build/*.arm64 "$DIR"/build/*.x86_64 2>/dev/null | head -1)
  fi
  [ -x "$EXE" ] || { printf '{"ok":false,"error":"no build executable in %s"}\n' "$(jstr "$DIR/build")"; exit 1; }
  if [ "$MODE" = bench ]; then set -- -- --bench "$OUT" --bench-fullscreen "$@"; else set -- "$@"; fi
  # Honesty samples every 5 s while the game runs: lock, idle, front app,
  # power, low power mode, display. Written beside the results.
  # Detached from the SSH session: ignores hang-up and holds none of its pipes,
  # so the call returns at once and the game outlives the connection.
  (
    trap '' HUP
    if [ "$OS" = Darwin ]; then
      # caffeinate keeps the display and machine awake for exactly the run.
      caffeinate -d -i open -n -W "$APP" --args "$@" >"$OUT/launch.txt" 2>&1
    else
      "$EXE" "$@" >"$OUT/launch.txt" 2>&1
    fi
    echo "$?" > "$OUT/EXIT"
  ) </dev/null >/dev/null 2>&1 &
  GAME=$!
  echo "$GAME" > "$OUT/PID"
  (
    trap '' HUP
    while kill -0 "$GAME" 2>/dev/null; do
      idle=$(idle_s); [ -n "$idle" ] || idle=null
      printf '{"time":"%s","locked":"%s","idle_s":%s,"front_app":"%s","power":"%s","low_power":"%s","display_awake":"%s"}\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(locked)" "$idle" "$(jstr "$(front_app)")" "$(jstr "$(power_source)")" "$(low_power)" "$(display_awake)" >> "$OUT/honesty.jsonl"
      sleep 5
    done
  ) </dev/null >/dev/null 2>&1 &
  printf '{"ok":true,"id":"%s","mode":"%s","results":"%s","refresh_hz":"%s"}\n' "$ID" "$MODE" "$(jstr "$OUT")" "$(jstr "$(refresh_hz)")"
  ;;
status)
  ID=${3:?}; OUT="$DIR/results/$ID"
  if [ -f "$OUT/EXIT" ]; then printf '{"ok":true,"running":false,"exit":"%s"}\n' "$(cat "$OUT/EXIT")"
  elif [ -f "$OUT/PID" ] && kill -0 "$(cat "$OUT/PID")" 2>/dev/null; then echo '{"ok":true,"running":true}'
  else echo '{"ok":true,"running":false,"exit":"unknown"}'; fi
  ;;
list)
  printf '{"ok":true,"results":['
  first=1
  if [ -d "$DIR/results" ]; then
    for d in "$DIR"/results/*/; do
      [ -d "$d" ] || continue
      n=$(basename "$d"); [ $first = 1 ] || printf ','; first=0
      printf '"%s"' "$(jstr "$n")"
    done
  fi
  printf ']}\n'
  ;;
*)
  printf '{"ok":false,"error":"unknown verb %s"}\n' "$(jstr "$VERB")"; exit 2 ;;
esac
