#pragma once
#include <cstdint>
#include <string>
#include <vector>

namespace xtp {

enum class WireFilterId : uint8_t {
    ZeroBlock = 1,
    Crunch = 2,
};

struct WireResult {
    std::vector<uint8_t> bytes;
    size_t logical_bytes = 0;
    size_t wire_bytes = 0;
};

class WireFilterChain {
public:
    void add(WireFilterId id);
    bool empty() const { return filters_.empty(); }
    const std::vector<WireFilterId>& filters() const { return filters_; }
    WireResult encode(const std::vector<uint8_t>& input) const;
    std::vector<uint8_t> decode(const std::vector<uint8_t>& wire) const;
    static WireFilterChain parse_spec(const std::string& spec);
    static bool is_enveloped(const std::vector<uint8_t>& data);
    static std::vector<uint8_t> decode_envelope(const std::vector<uint8_t>& data,
                                                std::vector<WireFilterId>* used = nullptr,
                                                size_t max_logical_bytes = 64u * 1024u * 1024u);
private:
    std::vector<WireFilterId> filters_;
};

const char* filter_name(WireFilterId id);

} // namespace xtp
