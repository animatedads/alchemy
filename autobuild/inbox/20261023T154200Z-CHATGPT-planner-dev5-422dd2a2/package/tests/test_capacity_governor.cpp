#include "operational/operational_planner.hpp"
#include <cassert>
#include <iostream>
using namespace operational;

int main() {
    CapacityRegistry cr;
    CapacityDomain d;
    d.name = "mi1-mu2.ingress";
    d.nominal_bytes_per_sec = 100000000;
    d.current_bytes_per_sec = 100000000;
    cr.set_domain(d);

    Registry r;
    OperationalClass c;
    c.name = "normal.storage";
    for (auto &p : c.states) p = parse_state_policy("allow:100:allow:any:30:2:60");
    r.register_class(c);
    Planner planner(r);
    auto decision = planner.decide("normal.storage", OperatingState::Normal);

    CapacityGovernor g(cr);
    auto a = g.acquire(decision, d.name);
    assert(a);
    assert(a->reserved_percent == 30);
    assert(a->effective_bytes_per_sec == 30000000);
    auto b = g.acquire(decision, d.name);
    assert(b);
    assert(b->effective_bytes_per_sec == 30000000);
    assert(g.active_contexts("normal.storage", d.name) == 2);
    assert(g.active_percent("normal.storage", d.name) == 60);
    auto third = g.acquire(decision, d.name);
    assert(!third);
    assert(g.release(a->id));
    auto replacement = g.acquire(decision, d.name);
    assert(replacement);

    // Current capacity, not nominal capacity, determines the actual byte rate.
    CapacityRegistry degraded;
    CapacityDomain dd = d;
    dd.current_bytes_per_sec = 50000000;
    degraded.set_domain(dd);
    CapacityGovernor dg(degraded);
    auto x = dg.acquire(decision, d.name);
    assert(x && x->effective_bytes_per_sec == 15000000);

    // THROTTLE composes with the per-context cap by taking the lower percentage.
    OperationalClass t = c;
    t.name = "normal.storage.throttled";
    for (auto &p : t.states) p = parse_state_policy("throttle:20:allow:any:30:2:60");
    Registry tr; tr.register_class(t);
    auto td = Planner(tr).decide(t.name, OperatingState::Normal);
    CapacityGovernor tg(cr);
    auto y = tg.acquire(td, d.name);
    assert(y && y->reserved_percent == 20 && y->effective_bytes_per_sec == 20000000);

    std::cout << "PASS operational capacity domain admission and rates\n";
}
