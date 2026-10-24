#include "xtp/xtp_operational.hpp"
#include <cassert>
#include <iostream>
using namespace operational;
int main(){
 Registry r; OperationalClass telemetry; telemetry.name="INTERNODE.TELEMETRY";
 telemetry.states[0]=parse_state_policy("allow:100:allow:any:30:2:60");
 telemetry.states[1]=parse_state_policy("throttle:40:allow:any:30:2:60");
 telemetry.states[2]=parse_state_policy("sample:10:forbid:protected:30:1:30");
 telemetry.states[3]=parse_state_policy("refuse-forward:0:forbid:protected:30:1:30");
 telemetry.transport_sort=100; r.register_class(telemetry); Planner planner(r);
 auto n=xtp::make_operational_plan(planner.decide(telemetry.name,OperatingState::Normal)); assert(n.transmit&&n.priority.mode==xtp::PriorityMode::Static&&n.priority.sort==100); assert(n.per_context_cap_percent==30&&n.max_parallel_contexts==2&&n.aggregate_cap_percent==60); assert(xtp::operational_effective_rate_percent(n)==30);
 auto d=xtp::make_operational_plan(planner.decide(telemetry.name,OperatingState::Degraded)); assert(d.transmit&&d.rate_percent==40); assert(xtp::operational_effective_rate_percent(d)==30); assert(xtp::operational_path_permitted(d,true,true));
 auto c=xtp::make_operational_plan(planner.decide(telemetry.name,OperatingState::Constrained)); assert(!c.transmit&&c.requires_upstream_transform); assert(!xtp::operational_path_permitted(c,true,true));
 auto e=xtp::make_operational_plan(planner.decide(telemetry.name,OperatingState::Emergency)); assert(!e.transmit&&!e.requires_upstream_transform);
 OperationalClass critical;critical.name="STORAGE.CRITICAL";for(auto&s:critical.states)s=parse_state_policy("allow:100:allow:protected");critical.states[3]=parse_state_policy("allow:100:require:protected");r.register_class(critical);Planner p2(r);auto ep=xtp::make_operational_plan(p2.decide(critical.name,OperatingState::Emergency));assert(!xtp::operational_path_permitted(ep,false,true));assert(xtp::operational_path_permitted(ep,true,true));assert(!xtp::operational_path_permitted(ep,true,false));
 auto delay=xtp::operational_delay_for_bytes(d,1000,10000); assert(delay.count()==333333);
 std::cout<<"PASS XTP operational-class enforcement mapping\n";
}
