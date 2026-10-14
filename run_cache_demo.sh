#!/bin/bash
# run_cache_demo.sh — CPU cache timing side-channel demo (for recording).
#
# IMPORTANT: runs NATIVELY on macOS (not in Docker). Cache timing depends on
# real hardware caches, so it does NOT survive virtualization / emulation.
#
# It (1) measures the cache-HIT vs DRAM-MISS timing gap, then (2) recovers a
# secret index purely from access timing (Flush+Reload principle) without ever
# reading the secret memory. Usage:  ./run_cache_demo.sh

set -u
DIR="$(cd "$(dirname "$0")" && pwd)/cache_timing"

BOLD=$'\033[1m'; CYN=$'\033[36m'; GRN=$'\033[32m'; RST=$'\033[0m'
clear
echo "${BOLD}============================================================${RST}"
echo "${BOLD}   CPU Cache Timing Side-Channel  (Flush + Reload)${RST}"
echo "${BOLD}   CPU 快取計時側信道 — 純靠時間差偷資料,不碰敏感記憶體${RST}"
echo "${BOLD}============================================================${RST}"
echo "${CYN}native macOS · Apple Silicon · no memory corruption, no crash${RST}"
sleep 3

echo
echo "${BOLD}\$ cc -O1 -o cache_timing cache_timing.c${RST}"
cc -O1 -o "$DIR/cache_timing" "$DIR/cache_timing.c" || { echo "compile failed"; exit 1; }
echo "${BOLD}\$ ./cache_timing${RST}"
echo
"$DIR/cache_timing"
echo
echo "${GRN}${BOLD}> cache timing demo finished${RST}"
echo "  快取命中(L1/L2)比 DRAM 快約兩個數量級;攻擊者只量時間,就推出了秘密值。"
echo "  Breaks the myth that you must corrupt memory to steal data."
echo
