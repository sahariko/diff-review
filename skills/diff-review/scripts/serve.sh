#!/usr/bin/env bash
# Run a long-lived process (Storybook, dev server…) so it can never be orphaned. Run from the repo root.
# It gets its own process group (setsid), so wrappers like npm/pnpm/sh and their children stop together.
# There is no fixed time limit: startup waits for readiness, and the process lives as long as the job,
# or the Claude session, that needs it.
#
#   serve.sh run   --cmd "<command with {port}>" [opts] -- <job...>
#       Start, wait until ready, run <job> with SERVER_URL and SERVER_PORT set, then stop the process
#       (any exit status, Ctrl-C and kill included). Exits with the job's status.
#   serve.sh start --cmd "<command with {port}>" [opts] [--watch-pid <pid>]
#       Start detached and print SERVER_URL, SERVER_PORT, SERVER_PID and SERVER_LOG. A watchdog stops it
#       when <pid> exits (default: the enclosing `claude` process) or the process dies on its own.
#   serve.sh stop <SERVER_PID>
#       Stop a process started with `start`.
#
# Options for run/start:
#   --cmd "<command>"      required; `{port}` is replaced by a free port. Use the repo's package manager,
#                          e.g. "pnpm exec storybook dev -p {port} --ci --no-open".
#   --pre "<command>"      runs first, in the current directory (e.g. generate files).
#   --ready-path <path>    HTTP path that must answer (any status) before we continue. Default /;
#                          use /index.json for Storybook.
#   --no-ready             skip the readiness wait (for processes with no HTTP port).
#   --ready-timeout <sec>  cap on the startup wait only. Default 300.
set -euo pipefail

stop_group() {
  local pgid="$1"
  kill -TERM -- "-$pgid" 2>/dev/null || return 0
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    kill -0 -- "-$pgid" 2>/dev/null || return 0
    sleep 0.5
  done
  kill -KILL -- "-$pgid" 2>/dev/null || true
}

find_claude_ancestor() {
  local pid=$$
  while [ "$pid" -gt 1 ]; do
    if [ "$(ps -o comm= -p "$pid" 2>/dev/null | tr -d ' ')" = "claude" ]; then
      echo "$pid"
      return 0
    fi
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    [ -n "$pid" ] || break
  done
  return 1
}

usage() {
  sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
}

MODE="${1:-}"
[ -n "$MODE" ] || usage
shift

if [ "$MODE" = "stop" ]; then
  [ -n "${1:-}" ] || usage
  stop_group "$1"
  exit 0
fi
{ [ "$MODE" = "run" ] || [ "$MODE" = "start" ]; } || usage

CMD="" PRE="" READY_PATH="/" CHECK_READY=1 READY_TIMEOUT=300 WATCH_PID=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --cmd) CMD="${2:?--cmd needs a value}"; shift 2 ;;
    --pre) PRE="${2:?--pre needs a value}"; shift 2 ;;
    --ready-path) READY_PATH="${2:?--ready-path needs a value}"; shift 2 ;;
    --no-ready) CHECK_READY=0; shift ;;
    --ready-timeout) READY_TIMEOUT="${2:?--ready-timeout needs a value}"; shift 2 ;;
    --watch-pid) WATCH_PID="${2:?--watch-pid needs a value}"; shift 2 ;;
    --) shift; break ;;
    *) usage ;;
  esac
done
[ -n "$CMD" ] || { echo "--cmd is required" >&2; usage; }

start_process() {
  [ -z "$PRE" ] || bash -c "$PRE" >/dev/null
  PORT=$(python3 -c 'import socket; s = socket.socket(); s.bind(("", 0)); print(s.getsockname()[1])')
  LOG=$(mktemp -t serve.XXXXXX.log)
  # setsid makes the process its own group leader, so $PGID is also its pid.
  setsid bash -c "exec ${CMD//\{port\}/$PORT}" >"$LOG" 2>&1 &
  PGID=$!
  URL="http://localhost:$PORT"

  [ "$CHECK_READY" -eq 1 ] || return 0
  local waited=0 code
  while :; do
    code=$(curl -s -o /dev/null -w '%{http_code}' "$URL$READY_PATH" 2>/dev/null || true)
    [ "$code" != "000" ] && [ -n "$code" ] && return 0
    if ! kill -0 "$PGID" 2>/dev/null; then
      echo "Process exited during startup. Log: $LOG" >&2
      tail -20 "$LOG" >&2
      exit 1
    fi
    if [ "$waited" -ge "$READY_TIMEOUT" ]; then
      echo "Not ready after ${READY_TIMEOUT}s. Log: $LOG" >&2
      stop_group "$PGID"
      exit 1
    fi
    sleep 1
    waited=$((waited + 1))
  done
}

if [ "$MODE" = "start" ]; then
  if [ -z "$WATCH_PID" ]; then
    WATCH_PID=$(find_claude_ancestor) || {
      echo "No enclosing claude process found; pass --watch-pid <pid>." >&2
      exit 2
    }
  fi
  start_process
  # Watchdog in its own session: ends the process when the owner is gone or the process died.
  setsid bash -c '
    while kill -0 "$1" 2>/dev/null && kill -0 "$2" 2>/dev/null; do sleep 5; done
    kill -TERM -- "-$2" 2>/dev/null; sleep 3; kill -KILL -- "-$2" 2>/dev/null; true
  ' _ "$WATCH_PID" "$PGID" >/dev/null 2>&1 &
  echo "SERVER_URL=$URL"
  echo "SERVER_PORT=$PORT"
  echo "SERVER_PID=$PGID"
  echo "SERVER_LOG=$LOG"
else
  [ "$#" -gt 0 ] || { echo "run needs a job after --" >&2; usage; }
  PGID=""
  trap '[ -z "$PGID" ] || stop_group "$PGID"' EXIT
  trap 'exit 143' INT TERM
  start_process
  SERVER_URL="$URL" SERVER_PORT="$PORT" "$@"
fi
