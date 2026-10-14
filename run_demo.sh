#!/bin/bash
# run_demo.sh — auto-playing buffer overflow demo (for screen / asciinema recording)
#
# Usage:
#   ./run_demo.sh                 # Canary ON  (stack smashing detected, exit 134)
#   ./run_demo.sh unprotected     # Canary OFF (Segmentation fault,     exit 139)
#
# The script walks through "normal request -> overflow -> crash" at a fixed
# pace by itself, so you only need to start a screen recording and run it;
# no commands to type during the recording.

set -u
MODE="${1:-protected}"
IMAGE="overflow-demo"

# ---- display helpers ----
BOLD=$'\033[1m'; DIM=$'\033[2m'; GRN=$'\033[32m'; RED=$'\033[31m'; CYN=$'\033[36m'; RST=$'\033[0m'
pause() { sleep "${1:-2}"; }
say()   { echo; echo "${CYN}${BOLD}> $*${RST}"; echo; }

clear
echo "${BOLD}============================================================${RST}"
echo "${BOLD}   Remote Buffer Overflow Demo   (MODE=${MODE})${RST}"
echo "${BOLD}   Target: 64-byte stack buffer + unbounded strcpy()${RST}"
echo "${BOLD}============================================================${RST}"
pause 3

# Everything runs inside one isolated container; the [SERVER]/[CLIENT]
# labels stand in for the two terminal windows.
docker run --rm --platform linux/amd64 -e MODE="$MODE" "$IMAGE" bash -c '
  BOLD="\033[1m"; GRN="\033[32m"; RED="\033[31m"; YEL="\033[33m"; DIM="\033[2m"; RST="\033[0m"
  sep() { echo -e "${DIM}------------------------------------------------------------${RST}"; }

  # Pick the matching binary
  BIN=./server_protected
  [ "'"$MODE"'" = "unprotected" ] && BIN=./server_unprotected
  echo "[entrypoint] MODE='"$MODE"'" > /tmp/server.log

  # Wrap the binary in a subshell: when the binary is killed by a signal the
  # subshell still exits normally and writes the exit code to /tmp/rc; disown
  # stops the shell from printing job notices like "Aborted" on screen.
  rm -f /tmp/rc
  ( "$BIN" >> /tmp/server.log 2>&1; echo $? > /tmp/rc ) 2>/dev/null &
  SRV=$!
  disown
  sleep 1

  echo -e "${BOLD}[SERVER]${RST} server started (MODE='"$MODE"')"
  sed "s/^/  /" /tmp/server.log
  sep; sleep 3

  echo -e "${BOLD}[CLIENT]${RST} ${GRN}Step 1 - normal request${RST}"
  echo -e "  $ python3 client.py normal"
  python3 client.py normal 2>&1 | sed "s/^/  /"
  sleep 3
  echo -e "${BOLD}[SERVER]${RST} server log:"
  sed "s/^/  /" /tmp/server.log
  echo -e "  ${GRN}-> communication OK, server still running${RST}"
  sep; sleep 4

  echo -e "${BOLD}[CLIENT]${RST} ${RED}Step 2 - send oversized data (200 bytes) to overflow${RST}"
  echo -e "  $ python3 client.py overflow 200"
  python3 client.py overflow 200 2>&1 | sed "s/^/  /"
  sleep 1
  # Wait until the subshell has written the binary exit code
  for _ in $(seq 1 25); do [ -f /tmp/rc ] && break; sleep 0.2; done
  RC=$(cat /tmp/rc 2>/dev/null || echo "?")
  sleep 2

  echo -e "${BOLD}[SERVER]${RST} server log:"
  sed "s/^/  /" /tmp/server.log
  echo
  if [ "'"$MODE"'" = "protected" ]; then
    echo -e "  ${RED}${BOLD}*** stack tampering detected, process aborted by the canary ***${RST}"
    echo -e "  ${YEL}exit code = $RC  (134 = SIGABRT)${RST}"
  else
    echo -e "  ${RED}${BOLD}*** return address overwritten, memory fault ***${RST}"
    echo -e "  ${YEL}exit code = $RC  (139 = SIGSEGV)${RST}"
  fi
  sep; sleep 2

  echo -e "${BOLD}[RESULT]${RST} server terminated - this is the remote crash / denial-of-service (DoS) effect."
'
RC=$?

say "Demo finished"
if [ "$MODE" = "protected" ]; then
  echo "How it works: the Stack Canary detects that its guard value was"
  echo "              overwritten before the function returns, and aborts the"
  echo "              process so the tampered return address is never used."
  echo
  echo "${DIM}To see the unprotected variant (no canary, raw segfault): ./run_demo.sh unprotected${RST}"
else
  echo "How it works: with the Stack Canary off, the overflow silently"
  echo "              overwrites the return address, causing an uncontrolled"
  echo "              Segmentation fault."
  echo
  echo "${DIM}Together with ASLR / DEP(NX), when the protections are not bypassed"
  echo "the most common outcome is a crash, not attacker code execution.${RST}"
fi
echo
exit $RC
