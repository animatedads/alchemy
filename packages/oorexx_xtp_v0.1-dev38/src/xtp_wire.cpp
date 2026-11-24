#include "xtp/xtp_wire.hpp"
#include <algorithm>
#include <stdexcept>

namespace xtp {
namespace {
constexpr uint8_t MAGIC[4] = {'X','W','F','1'};

void put32(std::vector<uint8_t>& b, uint32_t v) {
    b.push_back(uint8_t(v >> 24)); b.push_back(uint8_t(v >> 16));
    b.push_back(uint8_t(v >> 8)); b.push_back(uint8_t(v));
}
uint32_t get32(const std::vector<uint8_t>& b, size_t o) {
    if (o + 4 > b.size()) throw std::runtime_error("truncated wire-filter length");
    return (uint32_t(b[o]) << 24) | (uint32_t(b[o+1]) << 16) |
           (uint32_t(b[o+2]) << 8) | uint32_t(b[o+3]);
}

std::vector<uint8_t> zero_encode(const std::vector<uint8_t>& in) {
    std::vector<uint8_t> out;
    for (size_t i = 0; i < in.size();) {
        if (in[i] != 0) { out.push_back(in[i++]); continue; }
        size_t j = i; while (j < in.size() && in[j] == 0) ++j;
        size_t n = j - i;
        if (n >= 4) {
            out.push_back(0); out.push_back(1); put32(out, uint32_t(n));
        } else {
            for (size_t k = 0; k < n; ++k) { out.push_back(0); out.push_back(0); }
        }
        i = j;
    }
    return out;
}
std::vector<uint8_t> zero_decode(const std::vector<uint8_t>& in, size_t limit) {
    std::vector<uint8_t> out;
    for (size_t i = 0; i < in.size();) {
        if (in[i] != 0) { out.push_back(in[i++]); continue; }
        if (++i >= in.size()) throw std::runtime_error("truncated zero-block escape");
        uint8_t kind = in[i++];
        if (kind == 0) out.push_back(0);
        else if (kind == 1) {
            uint32_t n = get32(in, i); i += 4;
            if (n > limit - std::min(limit, out.size())) throw std::runtime_error("zero-block expansion exceeds logical limit");
            out.insert(out.end(), n, 0);
        } else throw std::runtime_error("unknown zero-block escape");
    }
    return out;
}

std::vector<uint8_t> crunch_encode(const std::vector<uint8_t>& in) {
    std::vector<uint8_t> out;
    for (size_t i = 0; i < in.size();) {
        size_t j = i + 1; while (j < in.size() && in[j] == in[i]) ++j;
        size_t n = j - i;
        if (n >= 4) {
            out.push_back(0xff); out.push_back(1); out.push_back(in[i]); put32(out, uint32_t(n));
            i = j; continue;
        }
        for (size_t k = 0; k < n; ++k) {
            if (in[i+k] == 0xff) { out.push_back(0xff); out.push_back(0); }
            else out.push_back(in[i+k]);
        }
        i = j;
    }
    return out;
}
std::vector<uint8_t> crunch_decode(const std::vector<uint8_t>& in, size_t limit) {
    std::vector<uint8_t> out;
    for (size_t i = 0; i < in.size();) {
        if (in[i] != 0xff) { out.push_back(in[i++]); continue; }
        if (++i >= in.size()) throw std::runtime_error("truncated crunch escape");
        uint8_t kind = in[i++];
        if (kind == 0) out.push_back(0xff);
        else if (kind == 1) {
            if (i >= in.size()) throw std::runtime_error("truncated crunch run");
            uint8_t v = in[i++]; uint32_t n = get32(in, i); i += 4;
            if (n > limit - std::min(limit, out.size())) throw std::runtime_error("crunch expansion exceeds logical limit");
            out.insert(out.end(), n, v);
        } else throw std::runtime_error("unknown crunch escape");
    }
    return out;
}

std::vector<uint8_t> apply_encode(WireFilterId id, const std::vector<uint8_t>& in) {
    switch (id) { case WireFilterId::ZeroBlock: return zero_encode(in); case WireFilterId::Crunch: return crunch_encode(in); }
    throw std::runtime_error("unknown wire filter");
}
std::vector<uint8_t> apply_decode(WireFilterId id, const std::vector<uint8_t>& in, size_t limit) {
    switch (id) { case WireFilterId::ZeroBlock: return zero_decode(in, limit); case WireFilterId::Crunch: return crunch_decode(in, limit); }
    throw std::runtime_error("unknown wire filter");
}
}

const char* filter_name(WireFilterId id) {
    switch (id) { case WireFilterId::ZeroBlock: return "zero-block"; case WireFilterId::Crunch: return "crunch"; }
    return "unknown";
}
void WireFilterChain::add(WireFilterId id) { filters_.push_back(id); }
WireFilterChain WireFilterChain::parse_spec(const std::string& spec) {
    WireFilterChain c; size_t p = 0;
    while (p < spec.size()) {
        size_t q = spec.find(',', p); if (q == std::string::npos) q = spec.size();
        auto s = spec.substr(p, q-p);
        if (s == "zero-block" || s == "zero") c.add(WireFilterId::ZeroBlock);
        else if (s == "crunch") c.add(WireFilterId::Crunch);
        else if (!s.empty() && s != "none") throw std::runtime_error("unknown wire filter: " + s);
        p = q + 1;
    }
    return c;
}
WireResult WireFilterChain::encode(const std::vector<uint8_t>& input) const {
    WireResult r; r.logical_bytes = input.size();
    if (filters_.empty()) { r.bytes = input; r.wire_bytes = input.size(); return r; }
    std::vector<uint8_t> cur = input;
    for (auto f : filters_) cur = apply_encode(f, cur);
    r.bytes.insert(r.bytes.end(), MAGIC, MAGIC+4);
    r.bytes.push_back(uint8_t(filters_.size()));
    for (auto f : filters_) r.bytes.push_back(uint8_t(f));
    put32(r.bytes, uint32_t(input.size()));
    r.bytes.insert(r.bytes.end(), cur.begin(), cur.end());
    r.wire_bytes = r.bytes.size();
    return r;
}
bool WireFilterChain::is_enveloped(const std::vector<uint8_t>& d) {
    return d.size() >= 5 && std::equal(MAGIC, MAGIC+4, d.begin());
}
std::vector<uint8_t> WireFilterChain::decode_envelope(const std::vector<uint8_t>& data,
                                                       std::vector<WireFilterId>* used,
                                                       size_t max_logical_bytes) {
    if (!is_enveloped(data)) return data;
    size_t n = data[4]; size_t pos = 5;
    if (pos + n + 4 > data.size()) throw std::runtime_error("truncated wire-filter envelope");
    std::vector<WireFilterId> fs;
    for (size_t i = 0; i < n; ++i) {
        uint8_t v = data[pos++];
        if (v != uint8_t(WireFilterId::ZeroBlock) && v != uint8_t(WireFilterId::Crunch))
            throw std::runtime_error("unknown wire-filter id");
        fs.push_back(WireFilterId(v));
    }
    uint32_t original = get32(data, pos); pos += 4;
    if (original > max_logical_bytes) throw std::runtime_error("wire-filter logical length exceeds configured limit");
    std::vector<uint8_t> cur(data.begin()+pos, data.end());
    for (auto it = fs.rbegin(); it != fs.rend(); ++it) cur = apply_decode(*it, cur, max_logical_bytes);
    if (cur.size() != original) throw std::runtime_error("wire-filter length mismatch");
    if (used) *used = fs;
    return cur;
}
std::vector<uint8_t> WireFilterChain::decode(const std::vector<uint8_t>& wire) const {
    if (filters_.empty()) return wire;
    return decode_envelope(wire, nullptr, 64u * 1024u * 1024u);
}

} // namespace xtp
