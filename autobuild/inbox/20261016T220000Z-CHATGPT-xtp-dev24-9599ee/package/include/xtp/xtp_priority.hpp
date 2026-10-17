#pragma once
#include <chrono>
#include <cstdint>
#include <deque>
#include <optional>
#include <string>

namespace xtp {

enum class PriorityMode { Disabled, Static, Deadline };

struct PrioritySpec {
    PriorityMode mode = PriorityMode::Disabled;
    uint32_t sort = 0;
};

// XTP 3.4 uses a 32-bit SORT field. Lower values are higher priority in
// static mode. In deadline mode SORT is a synchronized-clock deadline with
// 100 microsecond resolution. This helper encodes the low 32 bits of Unix
// epoch 100us ticks; callers that use another synchronized clock may supply
// the raw SORT value directly.
uint32_t deadline_sort(std::chrono::system_clock::time_point when);
uint32_t deadline_sort_after(std::chrono::microseconds delta);

// Return an ordering key suitable for a preemptive queue. Lower key wins.
// Expired deadlines deliberately become lowest priority, as specified by XTP.
uint64_t priority_order_key(const PrioritySpec& spec,
                            std::chrono::system_clock::time_point now = std::chrono::system_clock::now());

std::string priority_mode_name(PriorityMode mode);
PriorityMode parse_priority_mode(const std::string& value);

struct ScheduledToken {
    uint64_t id = 0;
    PrioritySpec priority;
    uint64_t insertion_order = 0;
};

// Small carrier-independent scheduler used by transports which have queued
// work. It models XTP's sender-side priority choice without coupling policy to
// UDP/raw36/L2. pop() always returns the currently highest-priority token.
class PriorityScheduler {
public:
    void push(uint64_t id, const PrioritySpec& priority);
    std::optional<ScheduledToken> pop();
    size_t size() const { return queue_.size(); }
private:
    PriorityMode discipline_ = PriorityMode::Disabled;
    uint64_t next_order_ = 0;
    std::deque<ScheduledToken> queue_;
};

} // namespace xtp
