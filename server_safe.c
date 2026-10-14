/*
 * server_safe.c — the FIXED version of server.c (educational use only).
 *
 * Same server, same 64-byte buffer, but the unbounded strcpy() is replaced
 * with a length-limited copy. The identical overflow payload is now safely
 * truncated instead of smashing the stack: the server keeps running.
 *
 * This is the "fix at the source" counterpart to the vulnerable demo.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <sys/socket.h>

#define PORT 8888
#define RECV_MAX 4096

/* The FIXED handler: copy at most sizeof(buffer)-1 bytes, always NUL-terminate. */
static void handle_request(const char *input)
{
    char buffer[64];
    strncpy(buffer, input, sizeof(buffer) - 1);  /* bounded copy          */
    buffer[sizeof(buffer) - 1] = '\0';            /* guarantee terminator  */
    printf("[server] stored request (%zu bytes kept): %s\n", strlen(buffer), buffer);
    fflush(stdout);
}

int main(void)
{
    int server_fd, client_fd;
    struct sockaddr_in addr;
    socklen_t addrlen = sizeof(addr);
    char recvbuf[RECV_MAX];

    server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd < 0) { perror("socket"); exit(1); }

    int opt = 1;
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(PORT);

    if (bind(server_fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        perror("bind"); exit(1);
    }
    if (listen(server_fd, 1) < 0) { perror("listen"); exit(1); }

    printf("[server] (SAFE build) listening on port %d (buffer size = 64 bytes)\n", PORT);
    fflush(stdout);

    while ((client_fd = accept(server_fd, (struct sockaddr *)&addr, &addrlen)) >= 0) {
        ssize_t n = recv(client_fd, recvbuf, RECV_MAX - 1, 0);
        if (n > 0) {
            recvbuf[n] = '\0';
            printf("[server] received %zd bytes\n", n);
            fflush(stdout);

            handle_request(recvbuf);   /* bounded copy: no overflow */

            const char *ok = "OK (safe)\n";
            send(client_fd, ok, strlen(ok), 0);
        }
        close(client_fd);
    }

    close(server_fd);
    return 0;
}
