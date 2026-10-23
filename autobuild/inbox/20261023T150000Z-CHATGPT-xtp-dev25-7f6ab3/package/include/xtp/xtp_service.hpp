#pragma once
#include <cstdint>
#include <string>
#include <vector>

namespace xtp {

// Alchemy named-service address format carried only in XTP FIRST information
// segments.  This is a private XTP address-format profile, not an IP address.
constexpr uint16_t XTP_NAMED_SERVICE_FORMAT = 0xA11Cu;

struct NamedServiceDescriptor {
    std::string name;
    uint64_t token = 0; // fast lookup hint only; name remains authoritative
};

bool valid_service_name(const std::string& name);
uint64_t service_name_token(const std::string& name);
std::vector<uint8_t> encode_named_service(const std::string& name, bool little_endian);
// If data begins with the private named-service address segment, returns the
// descriptor and removes that segment from data.  Otherwise returns empty.
bool decode_named_service(std::vector<uint8_t>& data, bool little_endian,
                          NamedServiceDescriptor& out);

} // namespace xtp
