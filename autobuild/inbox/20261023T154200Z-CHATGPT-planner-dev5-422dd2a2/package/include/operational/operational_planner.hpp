#pragma once
#include <array>
#include <cstdint>
#include <map>
#include <mutex>
#include <optional>
#include <string>
#include <vector>

namespace operational {

enum class OperatingState : uint8_t { Normal=0, Degraded=1, Constrained=2, Emergency=3 };
enum class Disposition : uint8_t { Allow=0, Throttle=1, Sample=2, Aggregate=3, Defer=4, Suspend=5, Drop=6, RefuseForward=7 };
enum class FallbackPolicy : uint8_t { Allow=0, Forbid=1, Require=2 };

struct StatePolicy {
    Disposition disposition = Disposition::Allow;
    uint8_t rate_percent = 100;
    FallbackPolicy fallback = FallbackPolicy::Allow;
    bool protected_path_only = false;
    uint8_t per_context_cap_percent = 100;
    uint16_t max_parallel_contexts = 1;
    uint8_t aggregate_cap_percent = 100;
};

struct OperationalClass {
    std::string name;
    std::array<StatePolicy,4> states{};
    std::optional<uint32_t> transport_sort;
    std::optional<uint64_t> transport_deadline_us;
};

struct Decision {
    std::string class_name;
    OperatingState state = OperatingState::Normal;
    StatePolicy policy{};
    std::optional<uint32_t> transport_sort;
    std::optional<uint64_t> transport_deadline_us;
    bool permits_transmission() const;
    bool requires_upstream_transform() const;
};


struct CapacityDomain {
    std::string name;
    uint64_t nominal_bytes_per_sec = 0;
    uint64_t current_bytes_per_sec = 0;
};

struct CapacityTicket {
    uint64_t id = 0;
    std::string class_name;
    std::string domain_name;
    uint8_t reserved_percent = 0;
    uint64_t effective_bytes_per_sec = 0;
    bool admitted = true;
};

class CapacityRegistry {
public:
    void set_domain(const CapacityDomain& domain);
    const CapacityDomain* find(const std::string& name) const;
    std::vector<CapacityDomain> domains() const;
private:
    std::map<std::string,CapacityDomain> domains_;
};

class CapacityGovernor {
public:
    explicit CapacityGovernor(CapacityRegistry registry = {}): registry_(std::move(registry)) {}
    std::optional<CapacityTicket> acquire(const Decision& decision, const std::string& domain_name);
    bool release(uint64_t ticket_id);
    void set_domain(const CapacityDomain& domain);
    std::vector<CapacityTicket> reconcile(const Decision& decision, const std::string& domain_name);
    std::optional<CapacityTicket> ticket(uint64_t ticket_id) const;
    std::vector<CapacityTicket> tickets(const std::string& class_name, const std::string& domain_name) const;
    uint16_t active_contexts(const std::string& class_name, const std::string& domain_name) const;
    uint16_t active_percent(const std::string& class_name, const std::string& domain_name) const;
    CapacityRegistry registry_snapshot() const;
private:
    uint16_t active_contexts_unlocked(const std::string& class_name, const std::string& domain_name) const;
    uint16_t active_percent_unlocked(const std::string& class_name, const std::string& domain_name) const;
    CapacityRegistry registry_;
    uint64_t next_ticket_ = 1;
    std::map<uint64_t,CapacityTicket> tickets_;
    mutable std::mutex mutex_;
};

class Registry {
public:
    void register_class(const OperationalClass& c);
    bool erase(const std::string& name);
    const OperationalClass* find(const std::string& name) const;
    std::vector<OperationalClass> classes() const;
private:
    std::map<std::string,OperationalClass> classes_;
};

class Planner {
public:
    explicit Planner(Registry registry = {}): registry_(std::move(registry)) {}
    Decision decide(const std::string& class_name, OperatingState state) const;
    Registry& registry() { return registry_; }
    const Registry& registry() const { return registry_; }
private:
    Registry registry_;
};

std::string state_name(OperatingState);
std::string disposition_name(Disposition);
std::string fallback_name(FallbackPolicy);
OperatingState parse_state(const std::string&);
Disposition parse_disposition(const std::string&);
FallbackPolicy parse_fallback(const std::string&);
StatePolicy parse_state_policy(const std::string&); // disposition[:rate][:fallback][:protected][:per_context_cap][:max_parallel][:aggregate_cap]
std::string encode_state_policy(const StatePolicy&);

Registry load_registry(const std::string& path);
void save_registry(const Registry&, const std::string& path);

CapacityRegistry load_capacity_registry(const std::string& path);
void save_capacity_registry(const CapacityRegistry&, const std::string& path);

} // namespace operational
