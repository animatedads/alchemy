// NEGATIVE TEST: a class whose policy is THROTTLE at 0% in the current state.
// Planner (owner of admission) refuses a ticket.  Does the XTP enforcement adapter agree?
#include "xtp/xtp_operational.hpp"
#include <iostream>
using namespace operational;
int main(){
  Registry r; OperationalClass c; c.name="BULK.STORAGE.COPY";
  for(auto&s:c.states) s=parse_state_policy("throttle:0:allow:any");
  r.register_class(c); Planner planner(r);
  auto d=planner.decide(c.name,OperatingState::Degraded);
  CapacityRegistry reg; CapacityDomain dom; dom.name="wan"; dom.nominal_bytes_per_sec=1000000; reg.set_domain(dom);
  CapacityGovernor gov(reg);
  auto ticket=gov.acquire(d,"wan");
  auto plan=xtp::make_operational_plan(d);
  bool permitted=xtp::operational_path_permitted(plan,false,false);
  auto delay=xtp::operational_delay_for_bytes(plan,60000,1000000);
  std::cout<<"planner ticket admitted="<<(ticket?"YES":"NO")<<"\n";
  std::cout<<"xtp adapter path_permitted="<<(permitted?"YES":"NO")<<" delay_us_for_60000B="<<delay.count()<<"\n";
  if(!ticket && (permitted || delay.count()==0)){ std::cout<<"FAIL: XTP adapter fails OPEN on zero-THROTTLE that the planner refuses\n"; return 1; }
  std::cout<<"PASS\n"; return 0;
}
