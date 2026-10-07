#pragma once
#include "xtp/xtp_route.hpp"
#include "xtp/xtp_transport.hpp"
#include "xtp/xtp_multipath.hpp"
#include "xtp/xtp_wire.hpp"
#include <memory>
#include <optional>
#include <string>
#include <vector>

namespace xtp {
struct SocketSelection {
    Route route;
    std::string protocol = "xtp";
    WireFilterChain wire_filters;
};
struct SocketPathSet {
    std::vector<SocketSelection> paths;
    std::string protocol = "xtp";
};
class SocketProvider {
public:
    explicit SocketProvider(RouteTable routes = RouteTable{}, PathHealthTable health = PathHealthTable{}) : routes_(std::move(routes)), health_(std::move(health)) {}
    std::optional<SocketSelection> select(const std::string& peer) const;
    SocketPathSet select_paths(const std::string& peer, size_t max_paths = 0) const;
    SendResult send(const std::string& peer, const std::vector<uint8_t>& logical,
                    const SendOptions& options = {}) const;
    std::unique_ptr<Listener> listen(const std::string& peer,
                                     const ListenOptions& options = {}) const;
    MultipathSendResult send_multipath(const std::string& peer, const std::vector<uint8_t>& logical,
                                       const MultipathOptions& options = {}) const;
    std::unique_ptr<MultipathListener> listen_multipath(const std::string& peer,
                                                        size_t max_paths = 2,
                                                        const ListenOptions& options = {}) const;
    PathHealth path_status(const Route& route) const { return health_.status(route); }
    QualificationResult requalify(const Route& route,
                                  const SendOptions& options = {}) const;
    MulticastSendResult send_multicast(const std::string& peer, const std::vector<uint8_t>& logical,
                                       const MulticastOptions& options = {}) const;
    std::unique_ptr<MulticastListener> listen_multicast(const std::string& peer,
                                                        const ListenOptions& options = {}) const;
private:
    RouteTable routes_;
    mutable PathHealthTable health_;
};
} // namespace xtp
