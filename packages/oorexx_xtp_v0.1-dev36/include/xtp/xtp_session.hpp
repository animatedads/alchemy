#pragma once
// dev31: persistent interactive XTP contexts.
// Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).
//
// A Session is one XTP context that stays open: both ends send and receive
// on the same KEY until each has closed its sending direction.  Bytes are
// delivered as they arrive, in order, with optional message boundaries (EOM),
// per-direction close (WCLOSE / RCLOSE), flow control from the reader
// (ALLOC follows what the application has read), selective repair (SPANs),
// SYNC/ECHO round-trip timing, and a keepalive that ends a context whose peer
// has gone silent.  The wire is the libxtp 3.4 profile; see docs/SESSIONS.md.
//
// dev32: optional per-service protection (authenticate or encrypt), from the
// service's keys in KeyTable::global(); see docs/SECURITY.md.
// Not provided: wire filters, multicast, and more than 2^32-1 bytes per direction.
#include "xtp/xtp_route.hpp"
#include "xtp/xtp_priority.hpp"
#include "xtp/xtp_security.hpp"
#include <optional>
#include <cstdint>
#include <memory>
#include <string>
#include <vector>

namespace xtp {

// Settings shared by both ends of a session.
struct SessionTuning {
    // Data bytes per packet.  0 = L2: interface MTU - 40; raw36 and UDP: 1408
    // (one unfragmented packet on a 1500-byte path).  Multiple of 8, >= 64.
    size_t segment_bytes = 0;
    // Bytes the peer may send beyond what our application has read.
    uint32_t receive_window = 256u * 1024u;
    // Bytes write() may hold that the peer has not yet acknowledged.
    size_t send_buffer_bytes = 1024u * 1024u;
    int rto_min_ms = 10;            // retransmission timer floor
    int rto_max_ms = 2000;          // retransmission timer ceiling
    int keepalive_ms = 5000;        // idle time before a status request
    int dead_after_ms = 30000;      // silence after which the context fails
    int close_linger_ms = 5000;     // time a finished context answers retransmissions (> rto_max_ms)
};

struct SessionOptions : SessionTuning {
    std::string service_name;       // required: the named service to open
    uint32_t key = 0;               // 0 = chosen automatically
    bool little_endian = true;
    PrioritySpec priority{};
    int open_timeout_ms = 3000;
    // dev32: protection.  Unset = the service's profile from KeyTable::global()
    // (none if the service has no keys).  Set it to demand at least that much;
    // open_session throws if no key for the service allows it.
    std::optional<Protection> protection;
    std::string key_principal;      // choose this principal's key, if the service has several
};

struct SessionListenOptions : SessionTuning {
    // Empty accepts any named service; otherwise only these.
    std::vector<std::string> allowed_services;
    size_t max_sessions = 256;      // contexts held at once (open or lingering)
    size_t accept_backlog = 64;     // opened but not yet accept()ed
    // DIAG refusals, rate limited as for Listener (dev30).
    uint32_t diag_rate_per_sec = 10;
    uint32_t diag_burst = 20;
    uint32_t diag_global_rate_per_sec = 100;
    // dev32: a service with keys always requires its profile.  This also
    // refuses unprotected opens for services that have no keys.
    bool require_protection = false;
    // dev32 (review M1): protected opens cost a key derivation and a tag check
    // each, so they are rate limited before any cryptography: per sending
    // address (host:port) and in total.  Opens over the limit are dropped
    // unanswered; established contexts are not affected.
    uint32_t open_rate_per_sec = 200;
    uint32_t open_burst = 400;
    uint32_t open_global_rate_per_sec = 2000;
};

struct SessionStats {
    uint64_t bytes_written = 0, bytes_read = 0;
    uint64_t packets_sent = 0, packets_received = 0;
    uint64_t retransmitted_packets = 0, keepalives_sent = 0;
    double srtt_ms = -1;            // -1 until a SYNC/ECHO round trip is measured
    uint64_t auth_failures = 0;     // dev32: packets dropped because their tag did not verify
    uint64_t replays_rejected = 0;  // dev32: packets dropped by the anti-replay window
};

struct SessionChunk {
    std::vector<uint8_t> data;
    bool eom = false;   // data ends a message (the writer passed eom)
    bool end = false;   // the peer closed its sending direction; nothing follows
};

class Session {
public:
    struct Impl;
    explicit Session(std::shared_ptr<Impl> impl);
    ~Session();                     // aborts the context unless it was closed
    Session(const Session&) = delete;
    Session& operator=(const Session&) = delete;

    // Queue bytes.  Blocks while the send buffer is full, which happens when
    // the peer's application is not reading.  eom marks the end of a message
    // after these bytes (data must then be non-empty).  timeout_ms < 0 waits
    // without limit; on timeout, throws and keeps what was already queued.
    // Throws after shutdown_write(), or if the context failed.
    void write(const std::vector<uint8_t>& data, bool eom = false, int timeout_ms = -1);
    // Up to max_bytes, never past a message boundary.  On timeout returns an
    // empty chunk with end == false.  Throws if the context failed or the peer
    // aborted it.
    SessionChunk read(size_t max_bytes, int timeout_ms = -1);
    // Send WCLOSE after everything queued.  Reading continues.  Idempotent.
    void shutdown_write();
    // shutdown_write(), then wait until the peer has closed its direction too
    // and both closes are acknowledged.  Returns false, after aborting, if
    // that does not happen within timeout_ms.
    bool close(int timeout_ms = 5000);
    // End the context at once; the peer's reads fail with "peer aborted".
    void abort();

    bool is_open() const;           // neither finished nor failed
    bool peer_closed() const;       // the peer's WCLOSE has been delivered
    std::string error() const;      // why the context failed; empty if it has not
    uint32_t key() const;
    std::string service_name() const;
    std::string peer_address() const;
    Protection protection() const;  // dev32
    uint64_t key_id() const;        // dev32: 0 when unprotected
    std::string key_principal() const;   // dev32: the principal the key belongs to
    CipherSuite suite() const;      // dev36: the AEAD in use (meaningless when unprotected)
    uint64_t key_serial() const;    // dev36: the key table's serial of the key at open (ServiceKey::serial)
    SessionStats stats() const;
private:
    std::shared_ptr<Impl> impl_;
};

// Open an interactive context to a named service on route.  Returns once the
// peer has accepted.  Throws "XTP context refused by peer: ..." on a DIAG, or
// on timeout if the peer does not accept (for example an older listener).
std::unique_ptr<Session> open_session(const Route& route, const SessionOptions& options);

// Receive side: owns the carrier socket for route and accepts sessions.
class SessionListener {
public:
    explicit SessionListener(const Route& route, const SessionListenOptions& options = {});
    ~SessionListener();
    SessionListener(const SessionListener&) = delete;
    SessionListener& operator=(const SessionListener&) = delete;
    // The next opened session; nullptr on timeout (timeout_ms < 0 waits) or after close().
    std::unique_ptr<Session> accept(int timeout_ms = -1);
    // Stop accepting.  Sessions already accepted continue.
    void close();
    size_t contexts() const;        // contexts currently held
    struct Impl;
private:
    std::shared_ptr<Impl> impl_;
};

} // namespace xtp
