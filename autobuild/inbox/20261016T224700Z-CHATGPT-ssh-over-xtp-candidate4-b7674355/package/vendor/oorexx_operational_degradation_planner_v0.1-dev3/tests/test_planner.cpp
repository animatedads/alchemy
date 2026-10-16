#include "operational/operational_planner.hpp"
#include <cassert>
#include <iostream>
using namespace operational;
int main(){Registry r;OperationalClass c;c.name="INTERNODE.TELEMETRY";c.states[0]=parse_state_policy("allow:100:allow:any");c.states[1]=parse_state_policy("throttle:50:allow:any");c.states[2]=parse_state_policy("sample:10:forbid:protected");c.states[3]=parse_state_policy("refuse-forward:0:forbid:protected");c.transport_sort=100;r.register_class(c);Planner p(r);auto a=p.decide(c.name,OperatingState::Normal);assert(a.permits_transmission());auto d=p.decide(c.name,OperatingState::Degraded);assert(d.permits_transmission()&&d.policy.rate_percent==50);auto q=p.decide(c.name,OperatingState::Constrained);assert(!q.permits_transmission()&&q.requires_upstream_transform()&&q.policy.fallback==FallbackPolicy::Forbid);auto e=p.decide(c.name,OperatingState::Emergency);assert(!e.permits_transmission()&&!e.requires_upstream_transform());std::cout<<"PASS operational class decisions\n";}
