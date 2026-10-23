#include "xtp/xtp_operational.hpp"
#include <algorithm>
#include <limits>

namespace xtp {
OperationalEnforcementPlan make_operational_plan(const operational::Decision& d){
    OperationalEnforcementPlan p;
    p.class_name=d.class_name;p.state=d.state;p.disposition=d.policy.disposition;
    p.transmit=d.permits_transmission();p.requires_upstream_transform=d.requires_upstream_transform();
    p.fallback_allowed=d.policy.fallback!=operational::FallbackPolicy::Forbid;
    p.fallback_required=d.policy.fallback==operational::FallbackPolicy::Require;
    p.protected_path_only=d.policy.protected_path_only;p.rate_percent=d.policy.rate_percent;
    p.per_context_cap_percent=d.policy.per_context_cap_percent;p.max_parallel_contexts=d.policy.max_parallel_contexts;p.aggregate_cap_percent=d.policy.aggregate_cap_percent;
    if(d.transport_deadline_us){p.priority.mode=PriorityMode::Deadline;p.priority.sort=deadline_sort_after(std::chrono::microseconds(*d.transport_deadline_us));}
    else if(d.transport_sort){p.priority.mode=PriorityMode::Static;p.priority.sort=*d.transport_sort;}
    return p;
}
bool operational_path_permitted(const OperationalEnforcementPlan& p,bool is_fallback,bool protected_path){
    if(!p.transmit||p.requires_upstream_transform)return false;
    if(is_fallback&&!p.fallback_allowed)return false;
    if(!is_fallback&&p.fallback_required)return false;
    if(p.protected_path_only&&!protected_path)return false;
    return true;
}
uint8_t operational_effective_rate_percent(const OperationalEnforcementPlan& p){
    uint8_t cap=p.per_context_cap_percent;
    if(p.disposition==operational::Disposition::Throttle) cap=std::min(cap,p.rate_percent);
    return cap;
}
std::chrono::microseconds operational_delay_for_bytes(const OperationalEnforcementPlan& p,size_t bytes,uint64_t nominal){
    const auto percent=operational_effective_rate_percent(p);
    if(percent>=100||percent==0||nominal==0)return std::chrono::microseconds(0);
    const long double rate=(static_cast<long double>(nominal)*percent)/100.0L;
    if(rate<=0)return std::chrono::microseconds::max();
    const long double us=(static_cast<long double>(bytes)*1000000.0L)/rate;
    const auto maxv=static_cast<long double>(std::numeric_limits<int64_t>::max());
    return std::chrono::microseconds(static_cast<int64_t>(std::min(us,maxv)));
}
} // namespace xtp
