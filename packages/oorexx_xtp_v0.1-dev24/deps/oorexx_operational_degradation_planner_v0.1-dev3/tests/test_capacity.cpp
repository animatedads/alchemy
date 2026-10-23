#include "operational/operational_planner.hpp"
#include <cassert>
#include <iostream>
using namespace operational;
int main(){
 auto p=parse_state_policy("allow:100:allow:any:30:2:60");
 assert(p.per_context_cap_percent==30); assert(p.max_parallel_contexts==2); assert(p.aggregate_cap_percent==60);
 Registry r; OperationalClass c; c.name="normal.storage"; for(auto &s:c.states)s=p; r.register_class(c); Planner pl(r);
 auto d=pl.decide("normal.storage",OperatingState::Normal);
 assert(d.policy.per_context_cap_percent==30 && d.policy.max_parallel_contexts==2 && d.policy.aggregate_cap_percent==60);
 std::cout<<"PASS operational capacity scopes\n";
}
