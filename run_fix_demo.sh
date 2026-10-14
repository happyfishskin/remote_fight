#!/bin/bash
# run_fix_demo.sh — "fix at the source" demo (for screen / asciinema recording)
#
# Sends the SAME 200-byte overflow payload to two servers:
#   - VULNERABLE (strcpy)   -> crashes (Segmentation fault, exit 139)
#   - FIXED      (strncpy)  -> truncates safely, keeps running (exit 0)
#
# Usage:  ./run_fix_demo.sh

set -u
IMAGE="overflow-demo"

BOLD=$'\033[1m'; GRN=$'\033[32m'; RED=$'\033[31m'; CYN=$'\033[36m'; RST=$'\033[0m'
clear
echo "${BOLD}============================================================${RST}"
echo "${BOLD}   Fix at the Source — strcpy vs strncpy${RST}"
echo "${BOLD}   從源頭修復 — 同一個溢位 payload,兩種結果${RST}"
echo "${BOLD}============================================================${RST}"
sleep 3

docker run --rm --platform linux/amd64 "$IMAGE" bash -c '
  BOLD="\033[1m"; GRN="\033[32m"; RED="\033[31m"; YEL="\033[33m"; DIM="\033[2m"; RST="\033[0m"
  sep(){ echo -e "${DIM}------------------------------------------------------------${RST}"; }
  make all >/dev/null 2>&1

  run_one() {           # $1=binary  $2=label  $3=color
    local bin="$1" label="$2" col="$3"
    echo "[entrypoint] $label" > /tmp/s.log
    rm -f /tmp/rc
    ( "./$bin" >> /tmp/s.log 2>&1; echo $? > /tmp/rc ) 2>/dev/null &
    local SRV=$!; disown
    sleep 1
    echo -e "${BOLD}[CLIENT]${RST} python3 client.py overflow 200   ->  ${col}${label}${RST}"
    python3 client.py overflow 200 2>&1 | sed "s/^/  /"
    sleep 1.2
    echo -e "${BOLD}[SERVER]${RST} log:"; sed "s/^/  /" /tmp/s.log
    if [ -f /tmp/rc ]; then
      echo -e "  ${col}${BOLD}exit code = $(cat /tmp/rc)${RST}"
    else
      echo -e "  ${col}${BOLD}still running — server SURVIVED (no crash)${RST}"
      kill $SRV 2>/dev/null   # stop the surviving server before the next scene
    fi
  }

  echo -e "${RED}${BOLD}### 1) VULNERABLE build (strcpy) ###${RST}"
  run_one server_unprotected "VULNERABLE (strcpy)" "$RED"
  echo -e "  ${RED}-> stack smashed, server DIED (139 = SIGSEGV)${RST}"
  sep; sleep 4

  echo -e "${GRN}${BOLD}### 2) FIXED build (strncpy) ###${RST}"
  run_one server_safe "FIXED (strncpy)" "$GRN"
  echo -e "  ${GRN}-> payload truncated to 63 bytes, server SURVIVED${RST}"
  sep; sleep 2
'
echo
echo "${CYN}${BOLD}> Fix demo finished${RST}"
echo "  同一份 200-byte 攻擊:strcpy 版崩潰,strncpy 版安全存活。"
echo "  Secure coding (邊界檢查) is the root-cause fix — not just a crash guard."
echo
