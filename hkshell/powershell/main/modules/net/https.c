#include <stdlib.h>
#include <stddef.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <WinSock2.h>
#include <WS2tcpip.h>
#include <windows.h>
#include <openssl\ssl.h>
#include <openssl\err.h>

uint8_t _debug_ = 0;
uint8_t _silent_ = 0;

char* https_concate (const char* a, uint8_t incl_null_a, const char* b, uint8_t incl_null_b) {
    const uint8_t sza = strlen(a) + incl_null_a;
    const uint8_t szb = strlen(b) + incl_null_b;
    const uint8_t sz = sza + szb;
    char* con = malloc(sz * sizeof(char)); 
    if(con == NULL) {
        return NULL;
    }
    strcpy_s(con, sza, a);
    strcat_s(con, sz, b);
    return con;
}

char* https_concate_3 (const char* a, uint8_t incl_null_a, const char* b, uint8_t incl_null_b, const char* c, uint8_t incl_null_c) {
    const uint8_t sza = strlen(a) + incl_null_a;
    const uint8_t szb = strlen(b) + incl_null_b;
    const uint8_t szc = strlen(c) + incl_null_c;
    const uint8_t sz = sza + szb + szc;
    char* con = malloc(sz * sizeof(char)); 
    if(con == NULL) {
        return NULL;
    }
    strcpy_s(con, sza, a);
    strcat_s(con, sza + szb, b);
    strcat_s(con, sz, c);
    return con;
}

char* https_int2str (uint32_t i){
    uint32_t tmp = i;
    uint32_t digits = 1;
    while(tmp != 0) {
        tmp /= 10;
        ++digits;
    }
    char* str = malloc(digits * (sizeof(char)));
    _itoa_s(i, str, digits * (sizeof(char)), 10);
    return str;
}

void https_debug_function (const char* function) {
    if(_debug_ != 1) { return; }
    printf_s("  >_ %s\n",function);
}

void https_debug (const char* message) {
     if(_debug_ != 1) { return; }   
     printf_s("    \\\\ %s\n",message);
}

void https_error (const char* error, uint8_t code) {
     if(_silent_ == 1) { return; }
     const char* h_resStr = https_int2str(code);
     const char* h_con = https_concate(error, 1, h_resStr, 0);

     printf_s(" !! %s !! \n", h_con);
     free((void*)h_resStr);
     free((void*)h_con);
}

int main(int numArgs, char** args) {
    https_debug_function("main");
   
    if(numArgs < 3) { 
        return 1;
    }

    char* h_httpMethod = args[1];
    h_httpMethod = https_concate(h_httpMethod,1," HTTP/1.1\r\n",1);
    char* h_host = args[2];
    h_host = https_concate_3("Host: ",1,h_host,1,"\r\n",1);
    
    char* h_end = "\r\n";

    if(numArgs >= 4) {
        for (int i = numArgs - 1; i > 2; i--) {
            h_end = https_concate_3(args[i],1,"\r\n",1,h_end,1);            
        }
    }

    https_debug(h_httpMethod);
    https_debug(h_host);
    https_debug(h_end);

    https_debug("Creating WSADATA Object");
    WSADATA wsadata;

    https_debug("Initializing WinSock with WSAStartup");
    uint8_t res = WSAStartup(MAKEWORD(2, 2), &wsadata);
    if(res != 0) {
        https_error("WSAStartup failed: ", res);
        return 1;
    }

    https_debug("Building address info");
    struct addrinfo hints;
    struct addrinfo* result = NULL;
    ZeroMemory(&hints, sizeof(hints));
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_protocol = IPPROTO_TCP;
    res = getaddrinfo(args[2], "443", &hints, &result);
    if(res != 0) {
        https_error("getaddrinfo failed: ", res);
        freeaddrinfo(result);
        WSACleanup();
        return 1;
    }

    https_debug("Initializing the socket");
    SOCKET sock = socket(result->ai_family,result->ai_socktype,result->ai_protocol);
    if(sock == INVALID_SOCKET){
        https_error("Error at socket(): ", WSAGetLastError());
        freeaddrinfo(result);
        closesocket(sock);
        WSACleanup();
        return 1;
    }
    
    struct timeval timeout;
    timeout.tv_sec = 2500;
    timeout.tv_usec = 0;

    setsockopt(sock, SOL_SOCKET,SO_RCVTIMEO, (char*)&timeout, sizeof(timeout));

    res = connect(sock, result->ai_addr, (int) result->ai_addrlen);
    if(res != 0){
        https_error("Could not connect: ", res);
        freeaddrinfo(result);
        closesocket(sock);
        WSACleanup();
        return 1;
    }

    freeaddrinfo(result);

    https_debug("Initializing OpenSSL and creating connection");
    SSL_library_init();
    OpenSSL_add_ssl_algorithms();
    SSL_load_error_strings();
    const SSL_METHOD *method = TLS_client_method();
    SSL_CTX *ctx = SSL_CTX_new(method);

    if (ctx == NULL) {
        https_error("\nFailed to create SSL_CTX: ",1);
        WSACleanup();
        return 1;
    }

    SSL *ssl = SSL_new(ctx);

    if (ssl == NULL) {
        https_error("\nFailed to create SSL: ",1);
        SSL_CTX_free(ctx);
        WSACleanup();
        return 1;
    }

    // Connect the SSL object with a file descriptor
    https_debug("Connecting SSL object with a file descriptor");
    if (!SSL_set_fd(ssl, sock)) {
        https_error("\nFailed to connect the SSL object with the file descriptor: ",1);
        SSL_free(ssl);
        SSL_CTX_free(ctx);
        WSACleanup();
        return 1;
    }

    // Perform the SSL/TLS handshake
    https_debug("Performing SSL/TLS handshake");
    res = SSL_connect(ssl);
    if (res <= 0) {
        https_error("\nFailed to perform SSL/TLS handshake: ", res);
        SSL_free(ssl);
        SSL_CTX_free(ctx);
        WSACleanup();
        return 1;
    }

    // Join Request
    char* h_request = https_concate_3(h_httpMethod, 1,h_host,1,h_end,1);

    free(h_httpMethod);
    free(h_host);
    free(h_end);

    // Send an HTTP request
    https_debug("Sending HTTP request");
    if(_debug_ == 1) {
        printf_s("\n\n%s",h_request);
    }
    if (SSL_write(ssl, h_request, strlen(h_request)) <= 0) {
        printf("Failed to send HTTP request\n");
    }

    free(h_request);

    // Receive and print out the response
    https_debug("\n\n ~ Receiving Request ~ \n\n");
    char buf[4096];
    int bytes;
    do {
        bytes = SSL_read(ssl, buf, sizeof(buf) - 1);
        if(bytes < 0) {
            //TODO handle error
            break;
        } else if (bytes == 0) {
            //Connection closed
            break;
        } else {
            buf[bytes] = 0;
            printf("%s", buf);
        }
    } while (bytes > 0);
    // Clean up
    https_debug("Cleaning Up\n");
    SSL_free(ssl);
    SSL_CTX_free(ctx);
    closesocket(sock);
    WSACleanup();

    return 0;
}
