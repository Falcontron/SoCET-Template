#include <atomic>
#include <cctype>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <netdb.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>

#include "UARTDataBuffer.hh"
#include "UARTTcpServer.hh"


#define SERVER_ERROR(fname, x) std::cerr << "TCP server error (" << (fname) << "): "<< (x) << std::endl;

int bind_connection(const char *port) {
    int sock, optval = 1;
    
    struct addrinfo hint;
    struct addrinfo *info;
    int status;

    std::memset(&hint, 0, sizeof(hint));
    hint.ai_family = AF_INET;
    hint.ai_socktype = SOCK_STREAM;
    hint.ai_flags = AI_PASSIVE;

    if((status = getaddrinfo(NULL, port, &hint, &info)) != 0) {
        SERVER_ERROR("getaddrinfo", gai_strerror(status));
        return -1;
    }

    if((sock = socket(AF_INET, SOCK_STREAM, 0)) < 0) {
        SERVER_ERROR("socket", std::strerror(errno));
        return -1;
    }

    if(setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &optval, sizeof(int)) < 0) {
        SERVER_ERROR("setsockopt", std::strerror(errno));
        return -1;
    }

    if(bind(sock, info->ai_addr, info->ai_addrlen) < 0) {
        SERVER_ERROR("bind", std::strerror(errno));
        close(sock);
        return -1;
    }

    if(listen(sock, 10) < 0) {
        SERVER_ERROR("listen", std::strerror(errno));
        close(sock);
        return -1;
    }

    freeaddrinfo(info);

    return sock;
}

void tcp_server(UARTDataBuffer& rx_buf, UARTDataBuffer& tx_buf, const char *port, std::atomic_bool& finished) {
    using namespace std::chrono_literals;
    // 1. Setup TCP server, establish connection
    struct sockaddr client;
    unsigned size = sizeof(client);
    std::memset(&client, 0, sizeof(client));

    // Bind to port
    int listenfd = bind_connection(port);

    // Only anticipate a single connection
    // TODO: Is this true?

    std::cout << "Waiting for UART server connection..." << std::endl;
    int writefd = accept(listenfd, &client, &size);
    if(writefd == -1) {
        SERVER_ERROR("accept", std::strerror(errno));
        close(listenfd);
        return;
    }
    std::cout << "Connected to UART client." << std::endl;

    while(!finished.load()) {
        if(tx_buf.data_avail()) {
            std::cout << "TX Data available!" << std::endl;
            uint8_t value = tx_buf.pop();
            if(send(writefd, &value, 1, 0) <= 0) {
                SERVER_ERROR("send", std::strerror(errno));
                break;
            }
        }

        char buf[128];
        int rv = recv(writefd, buf, 128, MSG_DONTWAIT);        
        if(rv > 0) {
            std::cout << "[TCP Server]: Received " << rv << "bytes." << std::endl;
            for(int i = 0; i < rv; i++) {
               rx_buf.push(buf[i]);
            }
            //std::cout << "ECHO" << buf << "\n";
        } else if(rv < 0 && errno != EAGAIN/*|| (rv == 0 && errno != EAGAIN && errno != EWOULDBLOCK)*/) {
            SERVER_ERROR("recv", std::strerror(errno));
        }

        //std::this_thread::sleep_for(10ms);
    }
}

#ifdef DEBUG

int main() {
    using namespace std::chrono_literals;
    UARTDataBuffer tx_buf;
    UARTDataBuffer rx_buf;
    const char * msg = "Hello there!\n";

    std::thread server_thread([&] {
        tcp_server(std::ref(rx_buf), std::ref(tx_buf), "7777");
    });

    for(int i = 0; i < strlen(msg); i++) {
        tx_buf.push(msg[i]);
    }

    while(1) {
        if(rx_buf.data_avail()) {
            printf("ECHO: %d\n", rx_buf.pop());
        }

        std::this_thread::sleep_for(10ms);
    }

    server_thread.join();
}

#endif