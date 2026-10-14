#!/bin/bash
# run_rust_demo.sh — modern systems protection (Rust) demo, for recording.
#
# Shows the SAME overflow idea in Rust:
#   1) COMPILE-TIME: a constant out-of-bounds index -> rustc refuses to build.
#   2) RUNTIME:      an oversized packet -> a SAFE PANIC (exit 101), no
#                    memory corruption (contrast with C's exit 139 stack smash).
#
# Uses the official rust:slim image. Usage:  ./run_rust_demo.sh

set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

BOLD=$'\033[1m'; GRN=$'\033[32m'; RED=$'\033[31m'; CYN=$'\033[36m'; RST=$'\033[0m'
clear
echo "${BOLD}============================================================${RST}"
echo "${BOLD}   Modern Systems Protection — Rust${RST}"
echo "${BOLD}   現代系統防護 — Rust 從語言層根絕緩衝區溢位${RST}"
echo "${BOLD}============================================================${RST}"
sleep 3

docker run --rm -v "$DIR/rust_demo":/src:ro rust:slim bash -c '
  BOLD="\033[1m"; GRN="\033[32m"; RED="\033[31m"; YEL="\033[33m"; DIM="\033[2m"; RST="\033[0m"
  sep(){ echo -e "${DIM}------------------------------------------------------------${RST}"; }

  echo -e "${BOLD}[1] COMPILE-TIME bounds check${RST}  (constant out-of-bounds index)"
  echo -e "    ${DIM}let buffer = [0u8; 64];  let x = buffer[200];${RST}"
  echo -e "    ${DIM}\$ rustc bounds_compile_error.rs${RST}"
  sleep 1
  rustc /src/bounds_compile_error.rs -o /tmp/ce 2>&1 | sed "s/^/    /"
  RC=${PIPESTATUS[0]}
  if [ -f /tmp/ce ]; then echo -e "    binary produced"; else echo -e "    ${RED}${BOLD}>>> rustc exit $RC — NO BINARY produced (build refused)${RST}"; fi
  sep; sleep 4

  echo -e "${BOLD}[2] RUNTIME safe panic${RST}  (oversized packet, same 200 bytes)"
  rustc -O /src/server.rs -o /tmp/server 2>&1 | sed "s/^/    /"
  /tmp/server > /tmp/s.log 2>&1 & SRV=$!
  sleep 1.5
  echo -e "    ${RED}[client] send 200 bytes -> 127.0.0.1:8888${RST}"
  printf "%0.sA" $(seq 1 200) > /dev/tcp/127.0.0.1/8888 2>/dev/null || true
  sleep 1
  wait $SRV 2>/dev/null; RC=$?
  sed "s/^/    /" /tmp/s.log
  echo -e "    ${GRN}${BOLD}>>> safe panic, exit $RC (no memory corruption)${RST}"
  sep; sleep 2
'
echo
echo "${CYN}${BOLD}> Rust demo finished${RST}"
echo "  C (strcpy)  : stack smashed, exit 139 — undefined behavior / exploitable"
echo "  Rust        : refused at compile time, or safe panic (exit 101) at runtime"
echo "  記憶體安全語言把這一整類漏洞從『可被利用』變成『根本編不出來 / 安全中止』。"
echo
