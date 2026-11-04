#pragma once
// dev32: per-service protection for XTP contexts (decision D-07).
// Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).  See docs/SECURITY.md.
//
// XTP links are per named service, so protection is per service.  Each named
// service has a profile (none, authenticate, encrypt) and keys.  libxtp holds
// the keys it is given in a KeyTable and applies them; it does not fetch them.
// Keys come from the Identity Directory over LDAP first (rexx/XtpServiceKeys.cls),
// and from a key file only when LDAP is unavailable.  A C++-only program may
// load a key file itself.
//
// Primitives: HKDF-SHA256, and AES-256-GCM or ChaCha20-Poly1305, from libcrypto.
// Authenticate mode uses the AEAD with no plaintext (the whole packet is
// authenticated data); encrypt mode encrypts the data.  One mechanism, one tail.
#include <array>
#include <cstdint>
#include <mutex>
#include <optional>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

namespace xtp {

enum class Protection : uint8_t { None = 0, Authenticate = 1, Encrypt = 2 };

// dev35: a send or open refused here, before anything went on the wire,
// because of keys or protection (no active key, a key revoked mid-send, a
// segment too small for the tail).  It says nothing about the path, so route
// failover and path health must not count it against a route.
struct ProtectionError : std::runtime_error { using std::runtime_error::runtime_error; };
enum class CipherSuite : uint8_t { Aes256Gcm = 1, ChaCha20Poly1305 = 2 };

const char* protection_name(Protection p);            // "none", "authenticate", "encrypt"
Protection parse_protection(const std::string& text);  // accepts none|auth|authenticate|encrypt
const char* suite_name(CipherSuite s);                 // "aes256gcm", "chacha20poly1305"
CipherSuite parse_suite(const std::string& text);

struct ServiceKey {
    std::string service;            // the named service this key protects
    std::string principal;          // who holds it; "" = any holder of the service key
    uint64_t key_id = 0;            // non-zero, unique across the table
    Protection protection = Protection::Authenticate;   // the service's profile
    CipherSuite suite = CipherSuite::Aes256Gcm;
    std::array<uint8_t, 32> secret{};
    int64_t not_before_ms = 0;      // Unix ms; 0 = no lower bound
    int64_t not_after_ms = 0;       // Unix ms; 0 = no upper bound
    bool active = true;             // false = retiring: accepted, never used to open
    std::string source;             // "ldap", "file", "api": where it came from
    ServiceKey() = default;
    ServiceKey(const ServiceKey&) = default;
    ServiceKey& operator=(const ServiceKey&) = default;
    ~ServiceKey();                  // wipes the secret, so no copy outlives its use
};

// What a listing shows: everything except the secret.
struct ServiceKeyInfo {
    std::string service, principal, source;
    uint64_t key_id = 0;
    Protection protection = Protection::None;
    CipherSuite suite = CipherSuite::Aes256Gcm;
    int64_t not_before_ms = 0, not_after_ms = 0;
    bool active = true;
};

// One key in the key-file line format (docs/SECURITY.md):
//   service key_id(16 hex) protection suite secret(64 hex) [principal|- not_before_ms not_after_ms active|retiring]
// Strict: exact hex lengths, hex digits only, protection authenticate or encrypt,
// non-zero key id.  Throws with the reason.  The same parser serves the key
// file, the ooRexx key sources and xtpNativeKeyInstall.
ServiceKey parse_key_line(const std::string& line, const std::string& source);

// The keys libxtp holds, and each service's profile.
//
// Profiles are sticky (review H1, fail closed): once a service has had keys
// for authenticate or encrypt, it keeps that profile when its keys expire, are
// revoked or vanish from a refresh.  Opens then fail (no valid key) instead of
// falling back to clear.  Only forget_profile lowers a profile, and only an
// operator should call it.
class KeyTable {
public:
    static KeyTable& global();
    // Add or replace (by key_id).  Throws on key_id 0, an empty service, a
    // protection of none, or a key_id that belongs to another service.
    void install(const ServiceKey& key);
    // Replace every key from source with keys, in one step under the table's
    // lock (review H2).  Everything is checked first; on any error nothing
    // changes and the error is thrown.  A key id held by another source for
    // the same service passes to this source.  Returns the number installed.
    size_t replace_source(const std::string& source, const std::vector<ServiceKey>& keys);
    // replace_source from text in the key-file line format (blank and # lines skipped).
    size_t replace_source_text(const std::string& source, const std::string& text);
    bool revoke(uint64_t key_id);
    size_t clear_source(const std::string& source);     // e.g. drop every "file" key; profiles stay
    size_t clear();                                     // every key and every profile (tests, reset)
    // Replace every key from source "file" with the contents of path.  The
    // path must be a regular file owned by this user, reached without a
    // symbolic link, and not readable or writable by group or others.
    size_t load_file(const std::string& path);
    // The newest active key valid now for opening a context to service, held
    // for exactly this principal ("" = the service's own keys, not a client's).
    std::optional<ServiceKey> for_open(const std::string& service, const std::string& principal = "") const;
    // Any key, active or retiring, valid now, by id (for accepting).
    std::optional<ServiceKey> by_id(uint64_t key_id) const;
    // Is key_id still present and valid now for service?  (No secret copied.)
    bool valid(uint64_t key_id, const std::string& service) const;
    // The service's profile: the strongest of its sticky profile and its keys.
    Protection required(const std::string& service) const;
    // Raise a service's profile without keys (policy declared ahead of keys).
    void require(const std::string& service, Protection p);
    // Lower a service's profile to what its current keys give (operator action).
    void forget_profile(const std::string& service);
    std::vector<std::pair<std::string, Protection>> profiles() const;
    std::vector<ServiceKeyInfo> list() const;
private:
    void check_locked(const ServiceKey& k, const std::string& replacing_source) const;
    void raise_locked(const std::string& service, Protection p);
    mutable std::mutex m_;
    std::vector<ServiceKey> keys_;
    std::vector<std::pair<std::string, Protection>> profiles_;
};

namespace security {
int64_t now_ms();
std::vector<uint8_t> random_bytes(size_t n);
std::vector<uint8_t> hkdf_sha256(const uint8_t* secret, size_t secret_len,
                                 const std::vector<uint8_t>& salt,
                                 const std::vector<uint8_t>& info, size_t out_len);
// AEAD with a 12-byte nonce and a 16-byte tag.  Ciphertext has the plaintext's
// length.  open() returns false if the tag does not verify.
void seal(CipherSuite s, const uint8_t key[32], const uint8_t nonce[12],
          const std::vector<uint8_t>& aad, const uint8_t* plain, size_t n,
          uint8_t* cipher_out, uint8_t tag_out[16]);
bool open(CipherSuite s, const uint8_t key[32], const uint8_t nonce[12],
          const std::vector<uint8_t>& aad, const uint8_t* cipher, size_t n,
          const uint8_t tag[16], uint8_t* plain_out);
} // namespace security

} // namespace xtp
