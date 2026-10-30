#pragma once
#include "xtp/xtp_priority.hpp"
#include "operational/operational_planner.hpp"
#include <chrono>
#include <cstdint>
#include <optional>
#include <string>

namespace xtp {

struct OperationalEnforcementPlan {
    std::string class_name;
    operational::OperatingState state = operational::OperatingState::Normal;
    operational::Disposition disposition = operational::Disposition::Allow;
    bool transmit = true;
    bool requires_upstream_transform = false;
    bool fallback_allowed = true;
    bool fallback_required = false;
    bool protected_path_only = false;
    uint8_t rate_percent = 100;
    uint8_t per_context_cap_percent = 100;
    uint16_t max_parallel_contexts = 1;
    uint8_t aggregate_cap_percent = 100;
    PrioritySpec priority{};
};

OperationalEnforcementPlan make_operational_plan(const operational::Decision& decision);

// Apply only XTP-owned mechanics.  SAMPLE/AGGREGATE remain upstream semantic
// transformations and therefore are not silently converted to ordinary sends.
bool operational_path_permitted(const OperationalEnforcementPlan& plan,
                                bool is_fallback,
                                bool protected_path);

// Optional sender-side pacing for transports where the class decision is
// THROTTLE but no stronger receiver-advertised native rate constraint exists.
uint8_t operational_effective_rate_percent(const OperationalEnforcementPlan& plan);

std::chrono::microseconds operational_delay_for_bytes(const OperationalEnforcementPlan& plan,
                                                       size_t bytes,
                                                       uint64_t nominal_rate_bytes_per_sec);

} // namespace xtp
