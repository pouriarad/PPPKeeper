#!/bin/bash
# Keeps "bash <(curl -s http://192.168.49.1:8181/msh)" running, restarting it
# whenever it prints a disconnect message or exits. Runs until a stop file
# appears (menu bar "Stop") or it gets Ctrl+C / SIGTERM.
#
# Usage: sudo ./keeper.sh [state_dir]

URL="http://192.168.49.1:8181/msh"
TRIGGERS='terminated with signal 15|Connection terminated'
RETRY_DELAY=3

DIR="${1:-$HOME/Library/Application Support/PPPKeeper}"
mkdir -p "$DIR"
LOG="$DIR/keeper.log"
RUNLOG="$DIR/run.log"
STATUS="$DIR/status"
STOPFILE="$DIR/stop"
PIDFILE="$DIR/keeper.pid"

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  echo "keeper already running (pid $(cat "$PIDFILE"))"; exit 0
fi
echo $$ > "$PIDFILE"
rm -f "$STOPFILE"
chmod 644 "$PIDFILE"

say()      { echo "$(date '+%F %T') [keeper] $*" | tee -a "$LOG"; }
set_status() { echo "$1" > "$STATUS"; chmod 644 "$STATUS" 2>/dev/null; }

kill_tree() {
  local p=$1 c
  for c in $(pgrep -P "$p"); do kill_tree "$c"; done
  kill -TERM "$p" 2>/dev/null
}

CHILD=""
stop_child() {
  [ -n "$CHILD" ] && kill_tree "$CHILD"
  CHILD=""
  killall pppd 2>/dev/null
  pkill -f "nc 192.168.49.1 8181" 2>/dev/null
}

cleanup() {
  say "stopping"
  stop_child
  set_status stopped
  rm -f "$PIDFILE" "$STOPFILE"
  exit 0
}
trap cleanup INT TERM

attempt=0
while [ ! -f "$STOPFILE" ]; do
  attempt=$((attempt + 1))
  set_status connecting
  say "starting attempt #$attempt"
  : > "$RUNLOG"; chmod 644 "$RUNLOG"
  bash -c "bash <(curl -s -m 15 '$URL')" >> "$RUNLOG" 2>&1 &
  CHILD=$!
  shown=0
  connected=0

  while :; do
    sleep 1
    # mirror new output to terminal + main log
    total=$(wc -l < "$RUNLOG")
    if [ "$total" -gt "$shown" ]; then
      tail -n +"$((shown + 1))" "$RUNLOG" | head -n "$((total - shown))" | tee -a "$LOG"
      shown=$total
    fi
    [ -f "$STOPFILE" ] && break
    if grep -Eq "$TRIGGERS" "$RUNLOG"; then
      say "disconnect detected -> restarting"; break
    fi
    if ! kill -0 "$CHILD" 2>/dev/null && ! pgrep -x pppd >/dev/null; then
      say "command exited -> restarting"; break
    fi
    if [ "$connected" = 0 ] && grep -Eq 'local +IP address' "$RUNLOG"; then
      connected=1; set_status "connected $(date +%s)"   # epoch = connected since
    fi
  done

  stop_child
  [ -f "$STOPFILE" ] && break
  set_status retrying
  sleep "$RETRY_DELAY"
done
cleanup
