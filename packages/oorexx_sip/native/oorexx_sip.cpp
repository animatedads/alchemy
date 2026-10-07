#include <oorexxapi.h>
#include <openssl/evp.h>
#include <openssl/rand.h>
#include <algorithm>
#include <atomic>
#include <cctype>
#include <chrono>
#include <cstdlib>
#include <ctime>
#include <map>
#include <memory>
#include <mutex>
#include <sstream>
#include <stdexcept>
#include <string>
#include <strings.h>
#include <utility>
#include <vector>

namespace {
struct Header { std::string name, value; };
struct SipMessage {
    bool response = false;
    std::string method, uri, reason, version = "SIP/2.0", body;
    int status = 0;
    std::vector<Header> headers;
    std::string header(const std::string &name) const {
        for (const auto &item : headers) if (!strcasecmp(item.name.c_str(), name.c_str())) return item.value;
        return "";
    }
    std::vector<std::string> headersAll(const std::string &name) const {
        std::vector<std::string> result;
        for (const auto &item : headers) if (!strcasecmp(item.name.c_str(), name.c_str())) result.push_back(item.value);
        return result;
    }
};

struct Registration {
    std::string aor, contact, ip;
    int port = 0;
    uint64_t expiresAt = 0;
};

struct Call {
    std::string callId;
    std::string remoteIp;
    int remoteSipPort = 0;
    int remoteRtpPort = 0;
    int payload = 0;
    std::string inviteRaw;
};

struct Server {
    std::string ip, realm, algorithm = "SHA-256", currentNonce;
    std::map<std::string, std::string> users;
    std::map<std::string, Registration> regs;
    std::map<std::string, std::shared_ptr<Call>> calls;
};

std::mutex gmu;
std::map<uint64_t, std::shared_ptr<Server>> servers;
std::atomic<uint64_t> nextId{1};

static std::string trim(std::string value) {
    auto first = value.find_first_not_of(" \t\r\n");
    if (first == std::string::npos) return "";
    auto last = value.find_last_not_of(" \t\r\n");
    return value.substr(first, last - first + 1);
}

static std::string lower(std::string value) {
    std::transform(value.begin(), value.end(), value.begin(), [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
    return value;
}

static SipMessage parseSip(const std::string &raw) {
    auto split = raw.find("\r\n\r\n");
    if (split == std::string::npos) throw std::runtime_error("SIP message missing CRLF header terminator");
    std::string headerText = raw.substr(0, split);
    std::string body = raw.substr(split + 4);
    std::istringstream input(headerText);
    std::string line;
    if (!std::getline(input, line)) throw std::runtime_error("empty SIP message");
    if (!line.empty() && line.back() == '\r') line.pop_back();
    SipMessage message;
    if (line.rfind("SIP/2.0 ", 0) == 0) {
        message.response = true;
        std::istringstream statusLine(line);
        statusLine >> message.version >> message.status;
        std::getline(statusLine, message.reason);
        message.reason = trim(message.reason);
    } else {
        std::istringstream requestLine(line);
        requestLine >> message.method >> message.uri >> message.version;
        if (message.method.empty() || message.uri.empty() || message.version != "SIP/2.0") throw std::runtime_error("invalid SIP request line");
    }
    Header *last = nullptr;
    while (std::getline(input, line)) {
        if (!line.empty() && line.back() == '\r') line.pop_back();
        if (line.empty()) continue;
        if ((line[0] == ' ' || line[0] == '\t') && last != nullptr) {
            last->value += " " + trim(line);
            continue;
        }
        auto colon = line.find(':');
        if (colon == std::string::npos) throw std::runtime_error("malformed SIP header");
        message.headers.push_back({trim(line.substr(0, colon)), trim(line.substr(colon + 1))});
        last = &message.headers.back();
    }
    size_t contentLength = body.size();
    auto contentLengthText = message.header("Content-Length");
    if (!contentLengthText.empty()) {
        char *end = nullptr;
        unsigned long parsed = std::strtoul(contentLengthText.c_str(), &end, 10);
        if (end == nullptr || *end != '\0') throw std::runtime_error("invalid Content-Length");
        contentLength = static_cast<size_t>(parsed);
        if (body.size() < contentLength) throw std::runtime_error("truncated SIP body");
    }
    message.body = body.substr(0, contentLength);
    return message;
}

static std::string uriUser(const std::string &value) {
    auto position = lower(value).find("sip:");
    if (position == std::string::npos) return "";
    position += 4;
    auto end = value.find_first_of("@;> \t", position);
    return value.substr(position, end == std::string::npos ? std::string::npos : end - position);
}

static std::string uriHostPort(std::string value, std::string &host, int &port) {
    auto position = lower(value).find("sip:");
    if (position != std::string::npos) value = value.substr(position + 4);
    auto at = value.rfind('@');
    if (at != std::string::npos) value = value.substr(at + 1);
    auto end = value.find_first_of(";> \t");
    if (end != std::string::npos) value = value.substr(0, end);
    auto colon = value.rfind(':');
    port = 5060;
    if (colon != std::string::npos && value.find(':') == colon) {
        host = value.substr(0, colon);
        port = std::atoi(value.substr(colon + 1).c_str());
    } else {
        host = value;
    }
    return value;
}

static std::string hexDigest(const EVP_MD *md, const std::string &value) {
    unsigned char output[EVP_MAX_MD_SIZE];
    unsigned int length = 0;
    EVP_MD_CTX *digest = EVP_MD_CTX_new();
    if (digest == nullptr) throw std::runtime_error("EVP_MD_CTX_new failed");
    if (EVP_DigestInit_ex(digest, md, nullptr) != 1 || EVP_DigestUpdate(digest, value.data(), value.size()) != 1 || EVP_DigestFinal_ex(digest, output, &length) != 1) {
        EVP_MD_CTX_free(digest);
        throw std::runtime_error("digest failed");
    }
    EVP_MD_CTX_free(digest);
    static const char *hex = "0123456789abcdef";
    std::string result;
    result.reserve(length * 2);
    for (unsigned int index = 0; index < length; index++) {
        result.push_back(hex[output[index] >> 4]);
        result.push_back(hex[output[index] & 15]);
    }
    return result;
}

static const EVP_MD *mdFor(std::string algorithm) {
    algorithm = lower(trim(algorithm));
    if (algorithm.empty() || algorithm == "md5") return EVP_md5();
    if (algorithm == "sha-256") return EVP_sha256();
    if (algorithm == "sha-512-256") return EVP_sha512_256();
    return nullptr;
}

static std::string nonce() {
    unsigned char bytes[18];
    if (RAND_bytes(bytes, sizeof bytes) != 1) throw std::runtime_error("RAND_bytes failed");
    static const char *hex = "0123456789abcdef";
    std::string result;
    for (unsigned char byte : bytes) {
        result.push_back(hex[byte >> 4]);
        result.push_back(hex[byte & 15]);
    }
    return result;
}

static std::map<std::string, std::string> digestFields(std::string value) {
    std::map<std::string, std::string> result;
    auto space = value.find(' ');
    if (space != std::string::npos) value = value.substr(space + 1);
    size_t index = 0;
    while (index < value.size()) {
        while (index < value.size() && (value[index] == ',' || std::isspace(static_cast<unsigned char>(value[index])))) index++;
        auto equals = value.find('=', index);
        if (equals == std::string::npos) break;
        std::string key = lower(trim(value.substr(index, equals - index)));
        index = equals + 1;
        std::string fieldValue;
        if (index < value.size() && value[index] == '"') {
            index++;
            auto quote = value.find('"', index);
            if (quote == std::string::npos) break;
            fieldValue = value.substr(index, quote - index);
            index = quote + 1;
        } else {
            auto comma = value.find(',', index);
            fieldValue = trim(value.substr(index, comma == std::string::npos ? std::string::npos : comma - index));
            index = comma == std::string::npos ? value.size() : comma;
        }
        result[key] = fieldValue;
    }
    return result;
}

static std::string digestResponse(const std::string &algorithm, const std::string &user, const std::string &realm, const std::string &password, const std::string &method, const std::string &uri, const std::string &nonceValue, const std::string &nonceCount, const std::string &clientNonce, const std::string &qop) {
    const EVP_MD *md = mdFor(algorithm);
    if (md == nullptr) throw std::runtime_error("unsupported digest algorithm");
    auto ha1 = hexDigest(md, user + ":" + realm + ":" + password);
    auto ha2 = hexDigest(md, method + ":" + uri);
    if (!qop.empty()) return hexDigest(md, ha1 + ":" + nonceValue + ":" + nonceCount + ":" + clientNonce + ":" + qop + ":" + ha2);
    return hexDigest(md, ha1 + ":" + nonceValue + ":" + ha2);
}

static std::string tag() { return nonce().substr(0, 16); }

static std::string ensureToTag(std::string to) {
    if (lower(to).find(";tag=") == std::string::npos) to += ";tag=" + tag();
    return to;
}

static int contactExpires(const std::string &contact) {
    std::string lowerContact = lower(contact);
    auto position = lowerContact.find(";expires=");
    if (position == std::string::npos) return -1;
    position += 9;
    while (position < contact.size() && std::isspace(static_cast<unsigned char>(contact[position]))) position++;
    size_t end = position;
    while (end < contact.size() && std::isdigit(static_cast<unsigned char>(contact[end]))) end++;
    if (end == position) return -1;
    long value = std::strtol(contact.substr(position, end - position).c_str(), nullptr, 10);
    if (value < 0) value = 0;
    if (value > 86400L * 365L) value = 86400L * 365L;
    return static_cast<int>(value);
}

static std::string contactWithExpires(const std::string &contact, int expires) {
    if (contact.empty() || contact == "*" || contactExpires(contact) >= 0) return contact;
    return contact + ";expires=" + std::to_string(expires);
}

static std::string responseVia(std::string via, const std::string &peerIp, int peerPort) {
    if (peerIp.empty() || peerPort <= 0) return via;
    std::string lowerVia = lower(via);
    auto rport = lowerVia.find(";rport");
    if (rport != std::string::npos) {
        size_t after = rport + 6;
        if (after >= via.size() || via[after] != '=') via.insert(after, "=" + std::to_string(peerPort));
    }
    lowerVia = lower(via);
    if (lowerVia.find(";received=") == std::string::npos) via += ";received=" + peerIp;
    return via;
}

static std::string response(const SipMessage &message, int code, const std::string &reason, const std::vector<Header> &extra = {}, const std::string &body = "", const std::string &peerIp = "", int peerPort = 0) {
    std::ostringstream output;
    output << "SIP/2.0 " << code << " " << reason << "\r\n";
    bool firstVia = true;
    for (const auto &via : message.headersAll("Via")) {
        output << "Via: " << (firstVia ? responseVia(via, peerIp, peerPort) : via) << "\r\n";
        firstVia = false;
    }
    output << "From: " << message.header("From") << "\r\n";
    output << "To: " << ensureToTag(message.header("To")) << "\r\n";
    output << "Call-ID: " << message.header("Call-ID") << "\r\n";
    output << "CSeq: " << message.header("CSeq") << "\r\n";
    for (const auto &header : extra) output << header.name << ": " << header.value << "\r\n";
    output << "Server: ooRexx-SIP/0.1-dev10\r\n";
    if (!body.empty()) output << "Content-Type: application/sdp\r\n";
    output << "Content-Length: " << body.size() << "\r\n\r\n" << body;
    return output.str();
}

static std::pair<int, int> parseSdpAudio(const std::string &body) {
    std::istringstream input(body);
    std::string line;
    while (std::getline(input, line)) {
        line = trim(line);
        if (line.rfind("m=audio ", 0) != 0) continue;
        std::istringstream media(line.substr(8));
        int port = 0;
        std::string protocol;
        media >> port >> protocol;
        int payload = -1;
        int candidate = -1;
        while (media >> candidate) {
            if (candidate == 0 || candidate == 8) { payload = candidate; break; }
        }
        if (protocol != "RTP/AVP") return {-1, -1};
        return {port, payload};
    }
    return {-1, -1};
}

static std::string sdp(const std::string &ip, int port, int payload) {
    std::ostringstream output;
    output << "v=0\r\n"
           << "o=oorexx-sip 1 1 IN IP4 " << ip << "\r\n"
           << "s=ooRexx SIP\r\n"
           << "c=IN IP4 " << ip << "\r\n"
           << "t=0 0\r\n"
           << "m=audio " << port << " RTP/AVP " << payload << "\r\n"
           << "a=rtpmap:" << payload << " " << (payload == 0 ? "PCMU" : "PCMA") << "/8000\r\n"
           << "a=sendrecv\r\n";
    return output.str();
}

static RexxObjectPtr event(RexxCallContext *context, const std::vector<std::string> &values) {
    auto result = context->NewArray(values.size());
    for (size_t index = 0; index < values.size(); index++) context->ArrayPut(result, context->String(values[index].c_str()), index + 1);
    return result;
}

static RexxObjectPtr fail(RexxCallContext *context, const std::exception &error) {
    context->RaiseException1(Rexx_Error_System_service_user_defined, context->String(error.what()));
    return context->Nil();
}

static std::shared_ptr<Server> server(uint64_t id) {
    std::lock_guard<std::mutex> guard(gmu);
    auto found = servers.find(id);
    if (found == servers.end()) throw std::runtime_error("SIP engine handle not found");
    return found->second;
}
}

RexxRoutine0(CSTRING, sip_native_version) {
    (void)context;
    return "oorexx.sip.native/0.1-dev10";
}

RexxRoutine3(uint64_t, sip_engine_open, CSTRING, ip, CSTRING, realm, CSTRING, algorithm) {
    try {
        if (mdFor(algorithm) == nullptr) throw std::runtime_error("algorithm must be MD5, SHA-256, or SHA-512-256");
        auto value = std::make_shared<Server>();
        value->ip = ip;
        value->realm = realm;
        value->algorithm = algorithm;
        value->currentNonce = nonce();
        uint64_t id = nextId++;
        std::lock_guard<std::mutex> guard(gmu);
        servers[id] = value;
        return id;
    } catch (const std::exception &error) {
        fail(context, error);
        return 0;
    }
}

RexxRoutine3(int, sip_server_set_credential, uint64_t, id, CSTRING, user, CSTRING, password) {
    try { server(id)->users[user] = password; return 1; }
    catch (const std::exception &error) { fail(context, error); return 0; }
}

RexxRoutine2(int, sip_server_set_auth_algorithm, uint64_t, id, CSTRING, algorithm) {
    try {
        if (mdFor(algorithm) == nullptr) throw std::runtime_error("algorithm must be MD5, SHA-256, or SHA-512-256");
        server(id)->algorithm = algorithm;
        return 1;
    } catch (const std::exception &error) {
        fail(context, error);
        return 0;
    }
}

RexxRoutine4(RexxObjectPtr, sip_engine_process, uint64_t, id, CSTRING, raw, CSTRING, peerIp, int, peerPort) {
    try {
        auto value = server(id);
        SipMessage message = parseSip(raw);
        if (message.response) return event(context, {"response", "", "", std::to_string(message.status), message.reason, message.header("Call-ID")});
        std::string method = lower(message.method);
        if (method == "register") {
            std::string user = uriUser(message.header("To"));
            auto credential = value->users.find(user);
            if (credential != value->users.end()) {
                auto authorization = message.header("Authorization");
                bool accepted = false;
                std::string reason = "missing-authorization";
                if (!authorization.empty()) {
                    auto fields = digestFields(authorization);
                    std::string algorithm = fields["algorithm"].empty() ? "MD5" : fields["algorithm"];
                    if (mdFor(algorithm) == nullptr) reason = "unsupported-algorithm";
                    else if (lower(algorithm) != lower(value->algorithm)) reason = "algorithm-mismatch";
                    else if (fields["username"] != user) reason = "username-mismatch";
                    else if (fields["realm"] != value->realm) reason = "realm-mismatch";
                    else if (fields["nonce"] != value->currentNonce) reason = "nonce-mismatch";
                    else if (fields["uri"] != message.uri) reason = "uri-mismatch";
                    else if (fields["qop"] != "auth") reason = "qop-mismatch";
                    else if (fields["nc"].empty() || fields["cnonce"].empty()) reason = "qop-fields-missing";
                    else if (fields["response"].empty()) reason = "response-missing";
                    else {
                        auto wanted = digestResponse(algorithm, user, value->realm, credential->second, message.method, fields["uri"], fields["nonce"], fields["nc"], fields["cnonce"], fields["qop"]);
                        if (!strcasecmp(wanted.c_str(), fields["response"].c_str())) { accepted = true; reason = "accepted"; }
                        else reason = "response-mismatch";
                    }
                }
                if (!accepted) {
                    value->currentNonce = nonce();
                    std::string authenticate = "Digest realm=\"" + value->realm + "\", nonce=\"" + value->currentNonce + "\", algorithm=" + value->algorithm + ", qop=\"auth\"";
                    return event(context, {"register-challenge", response(message, 401, "Unauthorized", {{"WWW-Authenticate", authenticate}}, "", peerIp, peerPort), "", user, peerIp, std::to_string(peerPort), reason});
                }
            }
            std::string contact = message.header("Contact");
            std::string aor = message.header("To");
            int expires = 3600;
            int contactExpiry = contactExpires(contact);
            auto expiresHeader = message.header("Expires");
            if (contactExpiry >= 0) expires = contactExpiry;
            else if (!expiresHeader.empty()) expires = std::max(0, std::atoi(expiresHeader.c_str()));
            if (expires == 0) {
                value->regs.erase(user);
                return event(context, {"unregistered", response(message, 200, "OK", {{"Contact", contactWithExpires(contact, 0)}}, "", peerIp, peerPort), "", user, aor, contact, peerIp, std::to_string(peerPort), "0", "0"});
            }
            uint64_t expiresAt = static_cast<uint64_t>(std::time(nullptr)) + static_cast<uint64_t>(expires);
            value->regs[user] = Registration{aor, contact, peerIp, peerPort, expiresAt};
            return event(context, {"registered", response(message, 200, "OK", {{"Contact", contactWithExpires(contact, expires)}}, "", peerIp, peerPort), "", user, aor, contact, peerIp, std::to_string(peerPort), std::to_string(expires), std::to_string(expiresAt)});
        }
        if (method == "options") return event(context, {"options", response(message, 200, "OK", {{"Allow", "INVITE, ACK, BYE, CANCEL, OPTIONS, REGISTER"}, {"Accept", "application/sdp"}}, "", peerIp, peerPort), "", peerIp, std::to_string(peerPort)});
        if (method == "invite") {
            auto audio = parseSdpAudio(message.body);
            if (audio.first <= 0 || audio.second < 0) return event(context, {"invite-rejected", response(message, 488, "Not Acceptable Here", {}, "", peerIp, peerPort), "", message.header("Call-ID"), "unsupported-audio"});
            auto call = std::make_shared<Call>();
            call->callId = message.header("Call-ID");
            call->remoteIp = peerIp;
            call->remoteSipPort = peerPort;
            call->remoteRtpPort = audio.first;
            call->payload = audio.second;
            call->inviteRaw = raw;
            value->calls[call->callId] = call;
            return event(context, {"invite-offer", response(message, 100, "Trying", {}, "", peerIp, peerPort), "", call->callId, peerIp, std::to_string(peerPort), std::to_string(call->remoteRtpPort), std::to_string(call->payload)});
        }
        if (method == "ack") return event(context, {"ack", "", "", message.header("Call-ID")});
        if (method == "bye") {
            auto callId = message.header("Call-ID");
            value->calls.erase(callId);
            return event(context, {"bye", response(message, 200, "OK", {}, "", peerIp, peerPort), "", callId});
        }
        if (method == "cancel") return event(context, {"cancel", response(message, 200, "OK", {}, "", peerIp, peerPort), "", message.header("Call-ID")});
        return event(context, {"method-not-allowed", response(message, 405, "Method Not Allowed", {{"Allow", "INVITE, ACK, BYE, CANCEL, OPTIONS, REGISTER"}}, "", peerIp, peerPort), "", message.method});
    } catch (const std::exception &error) {
        return fail(context, error);
    }
}

RexxRoutine3(RexxObjectPtr, sip_engine_accept_invite, uint64_t, id, CSTRING, callId, int, localRtpPort) {
    try {
        auto value = server(id);
        auto found = value->calls.find(callId);
        if (found == value->calls.end()) throw std::runtime_error("SIP call offer not found");
        auto call = found->second;
        SipMessage message = parseSip(call->inviteRaw);
        auto body = sdp(value->ip, localRtpPort, call->payload);
        auto ok = response(message, 200, "OK", {{"Contact", "<sip:oorexx@" + value->ip + ">"}}, body, call->remoteIp, call->remoteSipPort);
        return event(context, {"invite", ok, call->callId, call->remoteIp, std::to_string(call->remoteSipPort), std::to_string(call->remoteRtpPort), std::to_string(localRtpPort), std::to_string(call->payload)});
    } catch (const std::exception &error) {
        return fail(context, error);
    }
}

RexxRoutine1(int, sip_engine_close, uint64_t, id) {
    (void)context;
    std::lock_guard<std::mutex> guard(gmu);
    return servers.erase(id) ? 1 : 0;
}

RexxRoutine0(uint64_t, sip_epoch_seconds) {
    (void)context;
    return static_cast<uint64_t>(std::time(nullptr));
}

RexxRoutine0(uint64_t, sip_epoch_millis) {
    (void)context;
    return static_cast<uint64_t>(std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::system_clock::now().time_since_epoch()).count());
}

RexxRoutine0(CSTRING, sip_random_token) {
    (void)context;
    static thread_local std::string value;
    try { value = nonce(); return value.c_str(); }
    catch (...) { value = "0000000000000000"; return value.c_str(); }
}

RexxRoutine2(CSTRING, sip_message_header, CSTRING, raw, CSTRING, name) {
    (void)context;
    static thread_local std::string value;
    try { value = parseSip(raw).header(name); return value.c_str(); }
    catch (...) { value.clear(); return value.c_str(); }
}

RexxRoutine1(int, sip_message_status, CSTRING, raw) {
    (void)context;
    try { return parseSip(raw).status; }
    catch (...) { return 0; }
}

RexxRoutine1(RexxObjectPtr, sip_uri_target, CSTRING, uri) {
    try {
        std::string host;
        int port = 0;
        uriHostPort(uri, host, port);
        return event(context, {host, std::to_string(port)});
    } catch (const std::exception &error) {
        return fail(context, error);
    }
}

RexxRoutine5(CSTRING, sip_digest_authorization, CSTRING, challenge, CSTRING, user, CSTRING, password, CSTRING, method, CSTRING, uri) {
    (void)context;
    static thread_local std::string value;
    try {
        auto fields = digestFields(challenge);
        std::string algorithm = fields["algorithm"].empty() ? "MD5" : fields["algorithm"];
        std::string nonceCount = "00000001";
        std::string clientNonce = nonce().substr(0, 16);
        std::string qop = "auth";
        auto responseValue = digestResponse(algorithm, user, fields["realm"], password, method, uri, fields["nonce"], nonceCount, clientNonce, qop);
        std::ostringstream output;
        output << "Digest username=\"" << user << "\", realm=\"" << fields["realm"] << "\", nonce=\"" << fields["nonce"] << "\", uri=\"" << uri << "\", response=\"" << responseValue << "\", algorithm=" << algorithm << ", qop=" << qop << ", nc=" << nonceCount << ", cnonce=\"" << clientNonce << "\"";
        value = output.str();
        return value.c_str();
    } catch (...) {
        value.clear();
        return value.c_str();
    }
}

RexxRoutineEntry sip_routines[] = {
    REXX_TYPED_ROUTINE(sip_native_version, sip_native_version),
    REXX_TYPED_ROUTINE(sip_engine_open, sip_engine_open),
    REXX_TYPED_ROUTINE(sip_engine_process, sip_engine_process),
    REXX_TYPED_ROUTINE(sip_engine_accept_invite, sip_engine_accept_invite),
    REXX_TYPED_ROUTINE(sip_server_set_credential, sip_server_set_credential),
    REXX_TYPED_ROUTINE(sip_server_set_auth_algorithm, sip_server_set_auth_algorithm),
    REXX_TYPED_ROUTINE(sip_engine_close, sip_engine_close),
    REXX_TYPED_ROUTINE(sip_epoch_seconds, sip_epoch_seconds),
    REXX_TYPED_ROUTINE(sip_epoch_millis, sip_epoch_millis),
    REXX_TYPED_ROUTINE(sip_random_token, sip_random_token),
    REXX_TYPED_ROUTINE(sip_message_header, sip_message_header),
    REXX_TYPED_ROUTINE(sip_message_status, sip_message_status),
    REXX_TYPED_ROUTINE(sip_uri_target, sip_uri_target),
    REXX_TYPED_ROUTINE(sip_digest_authorization, sip_digest_authorization),
    REXX_LAST_ROUTINE()
};

RexxPackageEntry oorexx_sip_package_entry = {
    STANDARD_PACKAGE_HEADER REXX_INTERPRETER_5_0_0,
    "oorexx_sip",
    "0.1-dev10",
    NULL,
    NULL,
    sip_routines,
    NULL
};
OOREXX_GET_PACKAGE(oorexx_sip);
