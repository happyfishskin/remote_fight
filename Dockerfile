# Isolated sandbox for the buffer-overflow teaching demo.
# A crash inside here never touches your Mac.
#
# Build:  docker build -t overflow-demo .
# Run:    docker run --rm -it -p 8888:8888 overflow-demo                      # canary ON
#         docker run --rm -it -p 8888:8888 -e MODE=unprotected overflow-demo  # segfault
#
# Notes for Apple Silicon: PLATFORM defaults to linux/amd64 so the classic
# x86 behavior is reproducible. Docker Desktop runs it under emulation.
# Using an ARG (instead of a constant) also silences the build-check warning.

ARG PLATFORM=linux/amd64
FROM --platform=${PLATFORM} debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential python3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY server.c server_safe.c client.py Makefile entrypoint.sh ./

# Build BOTH variants so MODE can switch between them at run time.
RUN make all && chmod +x entrypoint.sh

EXPOSE 8888

# entrypoint.sh reads MODE (default: protected) and runs the matching server.
CMD ["./entrypoint.sh"]
