#include "operational/operational_planner.hpp"
#include <atomic>
#include <cassert>
#include <iostream>
#include <thread>
#include <vector>
using namespace operational;

static Decision decision(const char *policy, OperatingState state=OperatingState::Normal){
    Registry r; OperationalClass c; c.name="normal.storage";
    for(auto &p:c.states)p=parse_state_policy(policy);
    r.register_class(c); return Planner(r).decide(c.name,state);
}

int main(){
    CapacityRegistry cr; cr.set_domain({"mi1-mu2.ingress",100000000,100000000});
    CapacityGovernor g(cr);
    auto normal=decision("allow:100:allow:any:30:2:60");
    auto a=g.acquire(normal,"mi1-mu2.ingress");
    auto b=g.acquire(normal,"mi1-mu2.ingress");
    assert(a&&b&&!g.acquire(normal,"mi1-mu2.ingress"));

    g.set_domain({"mi1-mu2.ingress",100000000,50000000});
    auto ar=g.ticket(a->id); auto br=g.ticket(b->id);
    assert(ar&&br&&ar->effective_bytes_per_sec==15000000&&br->effective_bytes_per_sec==15000000);

    auto constrained=decision("allow:100:allow:any:15:1:15",OperatingState::Constrained);
    auto rr=g.reconcile(constrained,"mi1-mu2.ingress");
    assert(rr.size()==2);
    assert(g.active_contexts("normal.storage","mi1-mu2.ingress")==1);
    assert(g.active_percent("normal.storage","mi1-mu2.ingress")==15);
    unsigned admitted=0,suspended=0;
    for(const auto&t:rr){if(t.admitted){++admitted;assert(t.effective_bytes_per_sec==7500000);}else{++suspended;assert(t.effective_bytes_per_sec==0);}}
    assert(admitted==1&&suspended==1);

    auto emergency=decision("suspend:0:forbid:protected:10:1:10",OperatingState::Emergency);
    rr=g.reconcile(emergency,"mi1-mu2.ingress");
    assert(g.active_contexts("normal.storage","mi1-mu2.ingress")==0);
    for(const auto&t:rr)assert(!t.admitted&&t.effective_bytes_per_sec==0);

    g.set_domain({"mi1-mu2.ingress",100000000,100000000});
    rr=g.reconcile(normal,"mi1-mu2.ingress");
    assert(g.active_contexts("normal.storage","mi1-mu2.ingress")==2);
    assert(g.active_percent("normal.storage","mi1-mu2.ingress")==60);
    for(const auto&t:rr)assert(t.admitted&&t.effective_bytes_per_sec==30000000);
    g.release(a->id); g.release(b->id);

    std::atomic<int> failures{0};
    constexpr int threads=12, loops=3000;
    std::vector<std::thread> ws;
    for(int n=0;n<threads;++n) ws.emplace_back([&]{
        for(int i=0;i<loops;++i){
            auto t=g.acquire(normal,"mi1-mu2.ingress");
            if(t){
                if(t->reserved_percent!=30||t->effective_bytes_per_sec!=30000000)++failures;
                if(g.active_contexts("normal.storage","mi1-mu2.ingress")>2)++failures;
                if(g.active_percent("normal.storage","mi1-mu2.ingress")>60)++failures;
                if(!g.release(t->id))++failures;
            }
        }
    });
    for(auto& w:ws)w.join();
    assert(failures.load()==0);
    assert(g.active_contexts("normal.storage","mi1-mu2.ingress")==0);
    assert(g.active_percent("normal.storage","mi1-mu2.ingress")==0);
    std::cout<<"PASS pressure: 36000 concurrent admission/release attempts plus live contraction/restoration\n";
}
