#pragma once
#include "xtp/xtp_route.hpp"
#include <cstdint>
#include <memory>
#include <string>
#include <vector>

namespace xtp {

struct SendOptions {
    int timeout_ms = 250;
    int retries = 12;
    uint32_t key = 0x01234567u;
    bool little_endian = true;
};

struct SendResult {
    Route route;
    int attempts = 0;
    size_t logical_bytes = 0;
    size_t wire_bytes = 0;
    uint32_t rseq = 0;
    uint32_t dseq = 0;
    uint32_t alloc = 0;
    uint32_t peer_rate_bytes_per_sec = 0xffffffffu;
    uint32_t peer_burst_bytes = 0xffffffffu;
};


struct MulticastOptions {
    int timeout_ms = 250;
    int retries = 12;
    uint32_t key = 0x23456701u;
    bool little_endian = true;
    size_t expected_receivers = 1;
    bool reliable = true;
    int ttl = 1;
    bool loopback = true;
    // Maximum logical wire bytes carried by one FIRST/DATA information segment.
    // Values below 64 are rejected; the default is conservative for routed paths.
    size_t segment_bytes = 1200;
    // Reliable multicast flow control begins conservatively with one
    // information segment, then advances only within the minimum ALLOC
    // advertised by the receiver population.
    bool allocation_pacing = true;
    // XTP receiver-advertised RATE/BURST pacing.  Before receiver status is
    // known, these conservative sender defaults are used.  0xffffffff disables
    // rate pacing, matching XTP's RATE=-1 convention.
    bool rate_pacing = true;
    uint32_t default_rate_bytes_per_sec = 0xffffffffu;
    uint32_t default_burst_bytes = 0xffffffffu;
};

struct MulticastSendResult {
    Route route;
    int attempts = 0;
    size_t logical_bytes = 0;
    size_t wire_bytes = 0;
    size_t acknowledgements = 0;
    size_t required_acknowledgements = 0;
    std::vector<std::string> responders;
    size_t packets = 0;
    size_t retransmitted_packets = 0;
    size_t rollback_events = 0;
    uint32_t slowest_rseq = 0;
    uint32_t slowest_alloc = 0;
    size_t allocation_rounds = 0;
    size_t allocation_stalls = 0;
    uint32_t slowest_rate_bytes_per_sec = 0xffffffffu;
    uint32_t slowest_burst_bytes = 0xffffffffu;
    size_t rate_paced_bursts = 0;
    uint64_t rate_sleep_microseconds = 0;
};

struct QualificationResult {
    Route route;
    std::string provider;
    std::string method;
    int attempts = 0;
    uint32_t generation_before = 1;
    uint32_t generation_after = 1;
};

struct ListenOptions {
    int timeout_ms = 0; // 0 = blocking
    size_t max_logical_bytes = 64u * 1024u * 1024u;
    uint32_t receive_window = 1024u * 1024u;
    // Receiver-advertised XTP rate-control parameters returned in CNTL.
    // RATE=0xffffffff disables rate control.  BURST is bytes per burst.
    uint32_t advertised_rate_bytes_per_sec = 0xffffffffu;
    uint32_t advertised_burst_bytes = 0xffffffffu;
    // Multicast reject suppression follows the XTP rule: before emitting a
    // reject, listen briefly for another receiver's multicast reject. If that
    // reject asks the sender to roll back at least as far as we require, ours
    // is suppressed.
    int reject_suppression_ms = 20;
};

struct MulticastListenerStats {
    size_t reject_notices_sent = 0;
    size_t reject_notices_suppressed = 0;
};

struct ReceiveResult {
    Route route;
    uint32_t key = 0;
    uint32_t sequence = 0;
    bool little_endian = true;
    bool replay = false;
    std::string peer_address;
    size_t wire_bytes = 0;
    std::vector<uint8_t> logical;
};


// XTP multicast reject coverage rule.  An observed reject at or before our
// own RSEQ already requests sufficient rollback, so our reject is redundant.
bool multicast_reject_covers(uint32_t own_rseq, uint32_t observed_rseq);

// Carrier-independent XTP client send. Route.layer/carrier determines the
// actual L2/L3/L4 provider. Wire filters are taken from Route::wire_filters.
SendResult send_message(const Route& route, const std::vector<uint8_t>& logical,
                        const SendOptions& options = {});

// XTP 3.4 multicast message/stream transaction. FIRST carries the initial
// information segment and subsequent bytes are carried in DATA packets.
// Reliable mode uses sequence-level go-back-N: receiver CNTL RSEQ values
// identify the earliest byte that must be replayed. NOERR mode sends once.
MulticastSendResult send_multicast(const Route& route, const std::vector<uint8_t>& logical,
                                   const MulticastOptions& options = {});

// Live path qualification uses a reserved XTP transaction that is acknowledged
// by the remote Listener but never delivered to the application. The carrier
// remains provider-specific: L2 EtherType 0x817D, native IP protocol 36, or
// configured L4 carrier.
QualificationResult qualify_path(const Route& route,
                                 const SendOptions& options = {});

// Persistent receive-side endpoint.  It owns the carrier socket, acknowledges
// XTP FIRST transactions, suppresses duplicate KEY delivery, and decodes the
// self-describing wire-filter envelope before returning application bytes.
// The same class is used for L2 EtherType 0x817D, L3 protocol 36 and L4 UDP.
class Listener {
public:
    explicit Listener(const Route& route, const ListenOptions& options = {});
    ~Listener();
    Listener(Listener&&) noexcept;
    Listener& operator=(Listener&&) noexcept;
    Listener(const Listener&) = delete;
    Listener& operator=(const Listener&) = delete;

    ReceiveResult receive();
    const Route& route() const;
    void close();
private:
    struct Impl;
    std::unique_ptr<Impl> impl_;
};

class MulticastListener {
public:
    explicit MulticastListener(const Route& route, const ListenOptions& options = {});
    ~MulticastListener();
    MulticastListener(MulticastListener&&) noexcept;
    MulticastListener& operator=(MulticastListener&&) noexcept;
    MulticastListener(const MulticastListener&) = delete;
    MulticastListener& operator=(const MulticastListener&) = delete;
    ReceiveResult receive();
    const Route& route() const;
    MulticastListenerStats stats() const;
    void close();
private:
    struct Impl;
    std::unique_ptr<Impl> impl_;
};

} // namespace xtp
