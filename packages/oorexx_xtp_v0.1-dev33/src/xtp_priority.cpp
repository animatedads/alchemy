#include "xtp/xtp_priority.hpp"
#include <algorithm>
#include <cctype>
#include <limits>
#include <stdexcept>

namespace xtp {

uint32_t deadline_sort(std::chrono::system_clock::time_point when) {
    const auto us = std::chrono::duration_cast<std::chrono::microseconds>(when.time_since_epoch()).count();
    const uint64_t ticks = us <= 0 ? 0u : static_cast<uint64_t>(us / 100);
    return static_cast<uint32_t>(ticks & 0xffffffffu);
}

uint32_t deadline_sort_after(std::chrono::microseconds delta) {
    if (delta.count() < 0) throw std::runtime_error("XTP deadline delta cannot be negative");
    return deadline_sort(std::chrono::system_clock::now() + delta);
}

static int32_t signed_tick_distance(uint32_t future, uint32_t now) {
    return static_cast<int32_t>(future - now);
}

uint64_t priority_order_key(const PrioritySpec& spec, std::chrono::system_clock::time_point now) {
    if (spec.mode == PriorityMode::Disabled) return std::numeric_limits<uint64_t>::max() - 1u;
    if (spec.mode == PriorityMode::Static) return spec.sort;
    const uint32_t current = deadline_sort(now);
    const int32_t remaining = signed_tick_distance(spec.sort, current);
    // The XTP tutorial specifies that an expired deadline drops to the lowest
    // priority rather than being discarded.
    if (remaining <= 0) return std::numeric_limits<uint64_t>::max();
    return static_cast<uint32_t>(remaining);
}

std::string priority_mode_name(PriorityMode mode) {
    switch (mode) {
        case PriorityMode::Disabled: return "disabled";
        case PriorityMode::Static: return "static";
        case PriorityMode::Deadline: return "deadline";
    }
    return "disabled";
}

PriorityMode parse_priority_mode(const std::string& value) {
    std::string s=value;
    std::transform(s.begin(),s.end(),s.begin(),[](unsigned char c){return char(std::tolower(c));});
    if(s=="disabled"||s=="none"||s=="off") return PriorityMode::Disabled;
    if(s=="static"||s=="sort") return PriorityMode::Static;
    if(s=="deadline") return PriorityMode::Deadline;
    throw std::runtime_error("unknown XTP priority mode: "+value);
}

void PriorityScheduler::push(uint64_t id, const PrioritySpec& priority) {
    if(priority.mode!=PriorityMode::Disabled){
        if(discipline_==PriorityMode::Disabled) discipline_=priority.mode;
        else if(discipline_!=priority.mode) throw std::runtime_error("XTP static SORT and DEADLINE disciplines may not coexist on one scheduler");
    }
    queue_.push_back(ScheduledToken{id,priority,next_order_++});
}

std::optional<ScheduledToken> PriorityScheduler::pop() {
    if(queue_.empty()) return std::nullopt;
    const auto now=std::chrono::system_clock::now();
    auto best=queue_.begin();
    auto best_key=priority_order_key(best->priority,now);
    for(auto it=std::next(queue_.begin());it!=queue_.end();++it){
        const auto k=priority_order_key(it->priority,now);
        if(k<best_key || (k==best_key && it->insertion_order<best->insertion_order)){
            best=it;best_key=k;
        }
    }
    auto out=*best;queue_.erase(best);return out;
}

} // namespace xtp
