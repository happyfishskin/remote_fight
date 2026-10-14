# Build the demo server two ways so you can contrast the defenses on camera.
#
#   make protected     -> Stack Canary ON  (default GCC behavior)
#                         overflow is detected: "*** stack smashing detected ***"
#                         and the process aborts before returning.
#
#   make unprotected   -> Stack Canary OFF + executable stack
#                         overflow corrupts the stack silently -> Segmentation fault.
#
# Both still crash (that is the point of the demo). The difference is HOW:
# a controlled abort by the canary vs. an uncontrolled memory fault.

CC ?= gcc

protected: server.c
	$(CC) -fstack-protector-all -O0 -o server_protected server.c

unprotected: server.c
	$(CC) -fno-stack-protector -z execstack -O0 -o server_unprotected server.c

# The fixed server: bounded strncpy instead of strcpy. Even with no canary,
# the same overflow payload is truncated and the server keeps running.
safe: server_safe.c
	$(CC) -fno-stack-protector -O0 -o server_safe server_safe.c

all: protected unprotected safe

clean:
	rm -f server_protected server_unprotected server_safe

.PHONY: all clean
