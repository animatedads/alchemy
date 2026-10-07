#include <oorexxapi.h>
#include <oorexxerrors.h>
#include <sys/socket.h>
#include <poll.h>
#include <sys/time.h>
#include <openssl/bio.h>
#include <openssl/err.h>
#include <openssl/quic.h>
#include <openssl/ssl.h>
#include <atomic>
#include <cstdint>
#include <cstring>
#include <memory>
#include <mutex>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <vector>

namespace {
struct Connection {
    SSL_CTX *ctx = nullptr;      // owned for client connections; null for accepted server connections
    SSL *ssl = nullptr;
    bool client = false;
    ~Connection() {
        if (ssl) SSL_free(ssl);
        if (ctx) SSL_CTX_free(ctx);
    }
};

struct Listener {
    SSL_CTX *ctx = nullptr;
    SSL *listener = nullptr;
    int fd = -1;
    std::string alpn;
    ~Listener() {
        if (listener) SSL_free(listener);
        if (fd >= 0) BIO_closesocket(fd);
        if (ctx) SSL_CTX_free(ctx);
    }
};

std::mutex g_lock;
std::unordered_map<uint64_t, std::unique_ptr<Connection>> g_connections;
std::unordered_map<uint64_t, std::unique_ptr<Listener>> g_listeners;
std::atomic<uint64_t> g_next{1};

void raise_error(RexxCallContext *context, const std::string &s) {
    std::string msg = s;
    unsigned long e;
    char buf[256];
    while ((e = ERR_get_error()) != 0) {
        ERR_error_string_n(e, buf, sizeof(buf));
        msg += "; ";
        msg += buf;
    }
    context->RaiseException1(Rexx_Error_System_service_user_defined,
                             context->NewStringFromAsciiz(msg.c_str()));
}

std::vector<unsigned char> wire_alpn(const std::string &s) {
    if (s.empty() || s.size() > 255) throw std::runtime_error("ALPN must contain 1..255 bytes");
    std::vector<unsigned char> out(s.size() + 1);
    out[0] = static_cast<unsigned char>(s.size());
    std::copy(s.begin(), s.end(), out.begin() + 1);
    return out;
}

int select_alpn(SSL *, const unsigned char **out, unsigned char *out_len,
                const unsigned char *in, unsigned int in_len, void *arg) {
    auto *listener = static_cast<Listener *>(arg);
    if (!listener) return SSL_TLSEXT_ERR_ALERT_FATAL;
    const unsigned char *p = in;
    unsigned int remaining = in_len;
    while (remaining > 0) {
        unsigned int n = *p++;
        --remaining;
        if (n == 0 || n > remaining) return SSL_TLSEXT_ERR_ALERT_FATAL;
        if (n == listener->alpn.size() &&
            std::memcmp(p, listener->alpn.data(), n) == 0) {
            *out = p;
            *out_len = static_cast<unsigned char>(n);
            return SSL_TLSEXT_ERR_OK;
        }
        p += n;
        remaining -= n;
    }
    return SSL_TLSEXT_ERR_ALERT_FATAL;
}

BIO *create_client_bio(const char *host, const char *port, BIO_ADDR **peer_addr) {
    BIO_ADDRINFO *res = nullptr;
    const BIO_ADDRINFO *ai = nullptr;
    int sock = -1;
    if (!BIO_lookup_ex(host, port, BIO_LOOKUP_CLIENT, AF_UNSPEC, SOCK_DGRAM, 0, &res))
        return nullptr;
    for (ai = res; ai != nullptr; ai = BIO_ADDRINFO_next(ai)) {
        sock = BIO_socket(BIO_ADDRINFO_family(ai), SOCK_DGRAM, 0, 0);
        if (sock == -1) continue;
        if (!BIO_connect(sock, BIO_ADDRINFO_address(ai), 0) || !BIO_socket_nbio(sock, 1)) {
            BIO_closesocket(sock);
            sock = -1;
            continue;
        }
        break;
    }
    if (sock != -1) *peer_addr = BIO_ADDR_dup(BIO_ADDRINFO_address(ai));
    BIO_ADDRINFO_free(res);
    if (sock == -1 || *peer_addr == nullptr) {
        if (sock != -1) BIO_closesocket(sock);
        return nullptr;
    }
    BIO *bio = BIO_new(BIO_s_datagram());
    if (!bio) {
        BIO_closesocket(sock);
        return nullptr;
    }
    BIO_set_fd(bio, sock, BIO_CLOSE);
    return bio;
}

int create_server_socket(const char *host, const char *port) {
    BIO_ADDRINFO *res = nullptr;
    const BIO_ADDRINFO *ai = nullptr;
    int fd = -1;
    const char *lookup_host = (host && *host) ? host : nullptr;
    if (!BIO_lookup_ex(lookup_host, port, BIO_LOOKUP_SERVER, AF_UNSPEC, SOCK_DGRAM, 0, &res))
        return -1;
    for (ai = res; ai != nullptr; ai = BIO_ADDRINFO_next(ai)) {
        fd = BIO_socket(BIO_ADDRINFO_family(ai), SOCK_DGRAM, 0, 0);
        if (fd == -1) continue;
        int on = 1;
        (void)setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &on, sizeof(on));
        if (!BIO_bind(fd, BIO_ADDRINFO_address(ai), 0)) {
            BIO_closesocket(fd);
            fd = -1;
            continue;
        }
        break;
    }
    BIO_ADDRINFO_free(res);
    return fd;
}

Connection *connection_for(uint64_t handle) {
    auto it = g_connections.find(handle);
    return it == g_connections.end() ? nullptr : it->second.get();
}
Listener *listener_for(uint64_t handle) {
    auto it = g_listeners.find(handle);
    return it == g_listeners.end() ? nullptr : it->second.get();
}

int bounded_wait_ms(SSL *ssl, int requested_ms) {
    if (requested_ms < 0) requested_ms = 0;
    struct timeval tv{};
    int infinite = 0;
    if (ssl && SSL_get_event_timeout(ssl, &tv, &infinite)) {
        if (!infinite) {
            long long event_ms = static_cast<long long>(tv.tv_sec) * 1000LL + (tv.tv_usec + 999) / 1000;
            if (event_ms < 0) event_ms = 0;
            if (requested_ms == 0 || event_ms < requested_ms) requested_ms = static_cast<int>(event_ms);
        }
    }
    return requested_ms;
}

int poll_fd(int fd, short events, int timeout_ms) {
    if (fd < 0) return -1;
    struct pollfd pfd{};
    pfd.fd = fd;
    pfd.events = events;
    int rc;
    do { rc = ::poll(&pfd, 1, timeout_ms); } while (rc < 0 && errno == EINTR);
    if (rc <= 0) return rc;
    if (pfd.revents & (POLLERR | POLLHUP | POLLNVAL)) return -1;
    return (pfd.revents & events) ? 1 : 0;
}

std::pair<std::string,int> peer_address(SSL *ssl) {
    BIO *bio = SSL_get_rbio(ssl);
    if (!bio) return {"", 0};
    BIO_ADDR *addr = BIO_ADDR_new();
    if (!addr) return {"", 0};
    std::pair<std::string,int> out{"",0};
    if (BIO_dgram_get_peer(bio, addr) > 0) {
        char *h = BIO_ADDR_hostname_string(addr, 1);
        char *p = BIO_ADDR_service_string(addr, 1);
        if (h) out.first = h;
        if (p) out.second = std::atoi(p);
        OPENSSL_free(h);
        OPENSSL_free(p);
    }
    BIO_ADDR_free(addr);
    return out;
}
}

RexxRoutine7(uint64_t, quicNativeClientOpen,
             CSTRING, host,
             int, port,
             CSTRING, serverName,
             CSTRING, alpn,
             CSTRING, caFile,
             int, verifyPeer,
             OPTIONAL_int, blocking)
{
    try {
        ERR_clear_error();
        auto c = std::make_unique<Connection>();
        c->client = true;
        c->ctx = SSL_CTX_new(OSSL_QUIC_client_method());
        if (!c->ctx) throw std::runtime_error("SSL_CTX_new QUIC client failed");
        if (verifyPeer) {
            SSL_CTX_set_verify(c->ctx, SSL_VERIFY_PEER, nullptr);
            if (caFile && *caFile) {
                if (!SSL_CTX_load_verify_locations(c->ctx, caFile, nullptr))
                    throw std::runtime_error("failed to load QUIC CA file");
            } else if (!SSL_CTX_set_default_verify_paths(c->ctx)) {
                throw std::runtime_error("failed to load default trust store");
            }
        } else {
            SSL_CTX_set_verify(c->ctx, SSL_VERIFY_NONE, nullptr);
        }
        c->ssl = SSL_new(c->ctx);
        if (!c->ssl) throw std::runtime_error("SSL_new QUIC client failed");
        if (argumentExists(7) && !blocking) {
            if (!SSL_set_blocking_mode(c->ssl, 0)) throw std::runtime_error("failed to set nonblocking mode");
        }
        std::string port_s = std::to_string(port);
        BIO_ADDR *peer = nullptr;
        BIO *bio = create_client_bio(host, port_s.c_str(), &peer);
        if (!bio) throw std::runtime_error("failed to create QUIC UDP BIO");
        SSL_set_bio(c->ssl, bio, bio);
        std::string sni = (serverName && *serverName) ? serverName : host;
        if (!SSL_set_tlsext_host_name(c->ssl, sni.c_str())) {
            BIO_ADDR_free(peer);
            throw std::runtime_error("failed to set QUIC SNI");
        }
        if (verifyPeer && !SSL_set1_host(c->ssl, sni.c_str())) {
            BIO_ADDR_free(peer);
            throw std::runtime_error("failed to set QUIC verification name");
        }
        auto a = wire_alpn(alpn ? alpn : "oorexx-quic/0.1");
        if (SSL_set_alpn_protos(c->ssl, a.data(), static_cast<unsigned int>(a.size())) != 0) {
            BIO_ADDR_free(peer);
            throw std::runtime_error("failed to set QUIC ALPN");
        }
        if (!SSL_set1_initial_peer_addr(c->ssl, peer)) {
            BIO_ADDR_free(peer);
            throw std::runtime_error("failed to set QUIC initial peer");
        }
        BIO_ADDR_free(peer);
        if (SSL_connect(c->ssl) < 1) {
            long vr = SSL_get_verify_result(c->ssl);
            if (vr != X509_V_OK)
                throw std::runtime_error(std::string("QUIC handshake verification failed: ") + X509_verify_cert_error_string(vr));
            throw std::runtime_error("QUIC handshake failed");
        }
        uint64_t handle = g_next.fetch_add(1);
        std::lock_guard<std::mutex> guard(g_lock);
        g_connections.emplace(handle, std::move(c));
        return handle;
    } catch (const std::exception &e) {
        raise_error(context, std::string("QUIC client open: ") + e.what());
        return 0;
    }
}

RexxRoutine6(uint64_t, quicNativeListenerOpen,
             CSTRING, host,
             int, port,
             CSTRING, certFile,
             CSTRING, keyFile,
             CSTRING, alpn,
             OPTIONAL_int, backlog)
{
    try {
        ERR_clear_error();
        (void)backlog;
        auto l = std::make_unique<Listener>();
        l->alpn = (alpn && *alpn) ? alpn : "oorexx-quic/0.1";
        l->ctx = SSL_CTX_new(OSSL_QUIC_server_method());
        if (!l->ctx) throw std::runtime_error("SSL_CTX_new QUIC server failed");
        if (SSL_CTX_use_certificate_chain_file(l->ctx, certFile) <= 0)
            throw std::runtime_error("failed to load QUIC certificate chain");
        if (SSL_CTX_use_PrivateKey_file(l->ctx, keyFile, SSL_FILETYPE_PEM) <= 0)
            throw std::runtime_error("failed to load QUIC private key");
        if (!SSL_CTX_check_private_key(l->ctx))
            throw std::runtime_error("QUIC certificate/private key mismatch");
        SSL_CTX_set_verify(l->ctx, SSL_VERIFY_NONE, nullptr);
        SSL_CTX_set_alpn_select_cb(l->ctx, select_alpn, l.get());
        std::string port_s = std::to_string(port);
        l->fd = create_server_socket(host, port_s.c_str());
        if (l->fd < 0) throw std::runtime_error("failed to bind QUIC UDP socket");
        l->listener = SSL_new_listener(l->ctx, 0);
        if (!l->listener) throw std::runtime_error("SSL_new_listener failed");
        if (!SSL_set_fd(l->listener, l->fd)) throw std::runtime_error("SSL_set_fd listener failed");
        if (!SSL_listen(l->listener)) throw std::runtime_error("SSL_listen failed");
        uint64_t handle = g_next.fetch_add(1);
        std::lock_guard<std::mutex> guard(g_lock);
        g_listeners.emplace(handle, std::move(l));
        return handle;
    } catch (const std::exception &e) {
        raise_error(context, std::string("QUIC listener open: ") + e.what());
        return 0;
    }
}

RexxRoutine1(uint64_t, quicNativeAccept, uint64_t, listenerHandle)
{
    try {
        Listener *l;
        {
            std::lock_guard<std::mutex> guard(g_lock);
            l = listener_for(listenerHandle);
        }
        if (!l) throw std::runtime_error("unknown QUIC listener handle");
        SSL *ssl = SSL_accept_connection(l->listener, 0);
        if (!ssl) throw std::runtime_error("QUIC accept failed");
        auto c = std::make_unique<Connection>();
        c->ssl = ssl;
        c->client = false;
        uint64_t handle = g_next.fetch_add(1);
        std::lock_guard<std::mutex> guard(g_lock);
        g_connections.emplace(handle, std::move(c));
        return handle;
    } catch (const std::exception &e) {
        raise_error(context, std::string("QUIC accept: ") + e.what());
        return 0;
    }
}

RexxRoutine1(uint64_t, quicNativeTryAccept, uint64_t, listenerHandle)
{
    try {
        Listener *l;
        {
            std::lock_guard<std::mutex> guard(g_lock);
            l = listener_for(listenerHandle);
        }
        if (!l) throw std::runtime_error("unknown QUIC listener handle");
        ERR_clear_error();
        SSL *ssl = SSL_accept_connection(l->listener, SSL_ACCEPT_CONNECTION_NO_BLOCK);
        if (!ssl) {
            ERR_clear_error();
            return 0;
        }
        auto c = std::make_unique<Connection>();
        c->ssl = ssl;
        c->client = false;
        uint64_t handle = g_next.fetch_add(1);
        std::lock_guard<std::mutex> guard(g_lock);
        g_connections.emplace(handle, std::move(c));
        return handle;
    } catch (const std::exception &e) {
        raise_error(context, std::string("QUIC tryAccept: ") + e.what());
        return 0;
    }
}

RexxRoutine1(int, quicNativeDescriptor, uint64_t, handle)
{
    try {
        Connection *c;
        {
            std::lock_guard<std::mutex> guard(g_lock);
            c = connection_for(handle);
        }
        if (!c) throw std::runtime_error("unknown QUIC connection handle");
        return SSL_get_fd(c->ssl);
    } catch (const std::exception &e) {
        raise_error(context, std::string("QUIC descriptor: ") + e.what());
        return -1;
    }
}

RexxRoutine2(int, quicNativePump, uint64_t, handle, int, timeoutMilliseconds)
{
    try {
        Connection *c;
        {
            std::lock_guard<std::mutex> guard(g_lock);
            c = connection_for(handle);
        }
        if (!c) throw std::runtime_error("unknown QUIC connection handle");
        int fd = SSL_get_fd(c->ssl);
        int wait_ms = bounded_wait_ms(c->ssl, timeoutMilliseconds);
        int ready = poll_fd(fd, POLLIN | POLLOUT, wait_ms);
        if (!SSL_handle_events(c->ssl)) throw std::runtime_error("SSL_handle_events failed");
        return ready < 0 ? 0 : 1;
    } catch (const std::exception &e) {
        raise_error(context, std::string("QUIC pump: ") + e.what());
        return 0;
    }
}

RexxRoutine1(int, quicNativeListenerDescriptor, uint64_t, listenerHandle)
{
    try {
        Listener *l;
        {
            std::lock_guard<std::mutex> guard(g_lock);
            l = listener_for(listenerHandle);
        }
        if (!l) throw std::runtime_error("unknown QUIC listener handle");
        return l->fd;
    } catch (const std::exception &e) {
        raise_error(context, std::string("QUIC listener descriptor: ") + e.what());
        return -1;
    }
}

RexxRoutine2(int, quicNativeListenerWaitReady, uint64_t, listenerHandle, int, timeoutMilliseconds)
{
    try {
        Listener *l;
        {
            std::lock_guard<std::mutex> guard(g_lock);
            l = listener_for(listenerHandle);
        }
        if (!l) throw std::runtime_error("unknown QUIC listener handle");
        int wait_ms = bounded_wait_ms(l->listener, timeoutMilliseconds);
        int ready = poll_fd(l->fd, POLLIN, wait_ms);
        if (!SSL_handle_events(l->listener)) throw std::runtime_error("listener SSL_handle_events failed");
        return ready > 0 ? 1 : 0;
    } catch (const std::exception &e) {
        raise_error(context, std::string("QUIC listener waitReady: ") + e.what());
        return 0;
    }
}

RexxRoutine2(int, quicNativeSend, uint64_t, handle, RexxStringObject, bytes)
{
    try {
        Connection *c;
        {
            std::lock_guard<std::mutex> guard(g_lock);
            c = connection_for(handle);
        }
        if (!c) throw std::runtime_error("unknown QUIC connection handle");
        size_t nwritten = 0;
        if (!SSL_write_ex(c->ssl, context->StringData(bytes), context->StringLength(bytes), &nwritten))
            throw std::runtime_error("QUIC stream write failed");
        if (nwritten > static_cast<size_t>(INT32_MAX)) throw std::runtime_error("QUIC write too large");
        return static_cast<int>(nwritten);
    } catch (const std::exception &e) {
        raise_error(context, std::string("QUIC send: ") + e.what());
        return -1;
    }
}

RexxRoutine2(RexxObjectPtr, quicNativeRecv, uint64_t, handle, int, maximumBytes)
{
    try {
        if (maximumBytes < 1) return context->NewStringFromAsciiz("");
        Connection *c;
        {
            std::lock_guard<std::mutex> guard(g_lock);
            c = connection_for(handle);
        }
        if (!c) throw std::runtime_error("unknown QUIC connection handle");
        std::vector<char> buffer(static_cast<size_t>(maximumBytes));
        size_t nread = 0;
        if (!SSL_read_ex(c->ssl, buffer.data(), buffer.size(), &nread)) {
            int err = SSL_get_error(c->ssl, 0);
            if (err == SSL_ERROR_ZERO_RETURN) return context->NewStringFromAsciiz("");
            throw std::runtime_error("QUIC stream read failed");
        }
        return context->NewString(buffer.data(), nread);
    } catch (const std::exception &e) {
        raise_error(context, std::string("QUIC recv: ") + e.what());
        return NULLOBJECT;
    }
}

RexxRoutine1(int, quicNativeClose, uint64_t, handle)
{
    try {
        std::unique_ptr<Connection> c;
        {
            std::lock_guard<std::mutex> guard(g_lock);
            auto it = g_connections.find(handle);
            if (it == g_connections.end()) return 0;
            c = std::move(it->second);
            g_connections.erase(it);
        }
        if (c->ssl) {
            int loops = 0;
            while (loops++ < 8) {
                int rc = SSL_shutdown(c->ssl);
                if (rc == 1) break;
                if (rc < 0) break;
            }
        }
        return 0;
    } catch (const std::exception &e) {
        raise_error(context, std::string("QUIC close: ") + e.what());
        return -1;
    }
}

RexxRoutine1(int, quicNativeListenerClose, uint64_t, handle)
{
    try {
        std::unique_ptr<Listener> l;
        {
            std::lock_guard<std::mutex> guard(g_lock);
            auto it = g_listeners.find(handle);
            if (it == g_listeners.end()) return 0;
            l = std::move(it->second);
            g_listeners.erase(it);
        }
        return 0;
    } catch (const std::exception &e) {
        raise_error(context, std::string("QUIC listener close: ") + e.what());
        return -1;
    }
}

RexxRoutine1(RexxStringObject, quicNativePeerHost, uint64_t, handle)
{
    try {
        Connection *c;
        {
            std::lock_guard<std::mutex> guard(g_lock);
            c = connection_for(handle);
        }
        if (!c) throw std::runtime_error("unknown QUIC connection handle");
        auto p = peer_address(c->ssl);
        return context->NewStringFromAsciiz(p.first.c_str());
    } catch (const std::exception &e) {
        raise_error(context, std::string("QUIC peer host: ") + e.what());
        return context->NewStringFromAsciiz("");
    }
}

RexxRoutine1(int, quicNativePeerPort, uint64_t, handle)
{
    try {
        Connection *c;
        {
            std::lock_guard<std::mutex> guard(g_lock);
            c = connection_for(handle);
        }
        if (!c) throw std::runtime_error("unknown QUIC connection handle");
        return peer_address(c->ssl).second;
    } catch (const std::exception &e) {
        raise_error(context, std::string("QUIC peer port: ") + e.what());
        return 0;
    }
}

RexxRoutineEntry quic_native_routines[] = {
    REXX_TYPED_ROUTINE(quicNativeClientOpen, quicNativeClientOpen),
    REXX_TYPED_ROUTINE(quicNativeListenerOpen, quicNativeListenerOpen),
    REXX_TYPED_ROUTINE(quicNativeAccept, quicNativeAccept),
    REXX_TYPED_ROUTINE(quicNativeTryAccept, quicNativeTryAccept),
    REXX_TYPED_ROUTINE(quicNativeDescriptor, quicNativeDescriptor),
    REXX_TYPED_ROUTINE(quicNativePump, quicNativePump),
    REXX_TYPED_ROUTINE(quicNativeListenerDescriptor, quicNativeListenerDescriptor),
    REXX_TYPED_ROUTINE(quicNativeListenerWaitReady, quicNativeListenerWaitReady),
    REXX_TYPED_ROUTINE(quicNativeSend, quicNativeSend),
    REXX_TYPED_ROUTINE(quicNativeRecv, quicNativeRecv),
    REXX_TYPED_ROUTINE(quicNativeClose, quicNativeClose),
    REXX_TYPED_ROUTINE(quicNativeListenerClose, quicNativeListenerClose),
    REXX_TYPED_ROUTINE(quicNativePeerHost, quicNativePeerHost),
    REXX_TYPED_ROUTINE(quicNativePeerPort, quicNativePeerPort),
    REXX_LAST_ROUTINE()
};

RexxPackageEntry oorexx_quic_native_package_entry = {
    STANDARD_PACKAGE_HEADER
    REXX_INTERPRETER_5_0_0,
    "oorexx_quic_native",
    "0.1-dev2",
    nullptr,
    nullptr,
    quic_native_routines,
    nullptr
};

OOREXX_GET_PACKAGE(oorexx_quic_native);
