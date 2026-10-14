/*
 * server.c — DELIBERATELY VULNERABLE demo server (educational use only)
 *
 * Purpose: demonstrate a classic remote stack buffer overflow for a
 * security report. It is meant to CRASH (segfault / stack-smashing abort),
 * NOT to run attacker code. Run it only inside the provided Docker sandbox.
 *
 * The vulnerability: it copies network input into a fixed 64-byte stack
 * buffer with strcpy(), which performs no bounds checking.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <sys/socket.h>

#define PORT 8888
#define RECV_MAX 4096

/* The vulnerable function: input flows into a small fixed buffer. */
static void handle_request(const char *input)
{
    char buffer[64];          /* intentionally small, on the stack        */
    strcpy(buffer, input);    /* VULNERABLE: no bounds check -> overflow  */
    printf("[server] stored request: %s\n", buffer);
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

    printf("[server] listening on port %d (buffer size = 64 bytes)\n", PORT);
    fflush(stdout);

    /* Single-threaded accept loop: one connection at a time keeps the
       demo easy to narrate. A crash terminates the whole process. */
    while ((client_fd = accept(server_fd, (struct sockaddr *)&addr, &addrlen)) >= 0) {
        ssize_t n = recv(client_fd, recvbuf, RECV_MAX - 1, 0);
        if (n > 0) {
            recvbuf[n] = '\0';
            printf("[server] received %zd bytes\n", n);
            fflush(stdout);

            handle_request(recvbuf);   /* <- overflow happens in here */

            const char *ok = "OK\n";
            send(client_fd, ok, strlen(ok), 0);
        }
        close(client_fd);
    }

    close(server_fd);
    return 0;
}
