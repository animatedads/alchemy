#pragma once
#include <optional>
#include <string>
#include <vector>
#include <cstdint>

namespace xtp {
struct Route {
    std::string peer;
    int layer = 0;              // 2, 3, 4
    std::string carrier;        // l2, raw36, udp, vpn, ...
    std::string destination;
    std::string interface_name;
    int metric = 100;
    bool enabled = true;
    // Wire representation belongs at the socket/path edge.  The route carries
    // the selected profile so applications never special-case carriers.
    std::string wire_filters;   // e.g. "zero-block,crunch" or empty
    bool multicast = false;     // this route names an XTP multicast group
};


struct PathHealth {
    Route route;
    std::string state = "UP";      // UP, DOWN, PROBING
    uint32_t generation = 1;
    uint32_t failure_count = 0;
    std::string last_error;
};

class PathHealthTable {
public:
    explicit PathHealthTable(std::string path = {});
    const std::string& path() const { return path_; }
    std::vector<PathHealth> list(const std::string& peer = {}) const;
    PathHealth status(const Route& route) const;
    bool is_eligible(const Route& route) const;
    uint32_t generation(const Route& route) const;
    void mark_failure(const Route& route, const std::string& error);
    void begin_requalify(const Route& route);
    uint32_t mark_requalified(const Route& route);
    void clear(const Route& route);
private:
    std::string path_;
    std::vector<PathHealth> load() const;
    void save(const std::vector<PathHealth>& rows) const;
};

class RouteTable {
public:
    explicit RouteTable(std::string path = {});
    const std::string& path() const { return path_; }
    std::vector<Route> list(const std::string& peer = {}) const;
    void add(const Route& route);
    size_t remove(const std::string& peer, std::optional<int> layer = std::nullopt,
                  const std::string& carrier = {});
    size_t set_enabled(const std::string& peer, bool enabled,
                       std::optional<int> layer = std::nullopt,
                       const std::string& carrier = {});
    std::optional<Route> best_connect(const std::string& peer) const;
    std::vector<Route> best_paths(const std::string& peer, size_t max_paths = 0, bool multicast = false) const;
    std::vector<Route> multicast_paths(const std::string& peer, size_t max_paths = 0) const { return best_paths(peer, max_paths, true); }
private:
    std::string path_;
    std::vector<Route> load() const;
    void save(const std::vector<Route>& routes) const;
};
}
