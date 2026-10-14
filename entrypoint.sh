#!/bin/sh
# Pick which build to run based on the MODE env var.
#   MODE=protected    (default) -> Stack Canary ON  -> "stack smashing detected"
#   MODE=unprotected            -> Stack Canary OFF -> "Segmentation fault"
#
#   docker run --rm -it -p 8888:8888 overflow-demo                      # protected
#   docker run --rm -it -p 8888:8888 -e MODE=unprotected overflow-demo  # segfault

MODE="${MODE:-protected}"

case "$MODE" in
    protected)
        echo "[entrypoint] MODE=protected  (Stack Canary ON)"
        exec ./server_protected
        ;;
    unprotected)
        echo "[entrypoint] MODE=unprotected (Stack Canary OFF)"
        exec ./server_unprotected
        ;;
    safe)
        echo "[entrypoint] MODE=safe (fixed: bounded strncpy)"
        exec ./server_safe
        ;;
    *)
        echo "[entrypoint] unknown MODE='$MODE' (use 'protected', 'unprotected' or 'safe')" >&2
        exit 1
        ;;
esac
