#include "xtp/xtp_priority.hpp"
#include "xtp/xtp_transport.hpp"
#include <cassert>
#include <chrono>
#include <iostream>
#include <thread>
#include <vector>

int main(){
    using namespace xtp;
    PriorityScheduler s;
    s.push(1,{PriorityMode::Static,100});
    s.push(2,{PriorityMode::Static,10});
    s.push(3,{PriorityMode::Static,50});
    assert(s.pop()->id==2); assert(s.pop()->id==3); assert(s.pop()->id==1);
    bool mixed=false;try{PriorityScheduler q;q.push(1,{PriorityMode::Static,1});q.push(2,{PriorityMode::Deadline,deadline_sort_after(std::chrono::seconds(1))});}catch(...){mixed=true;}assert(mixed);
    auto now=std::chrono::system_clock::now();
    PrioritySpec soon{PriorityMode::Deadline,deadline_sort(now+std::chrono::milliseconds(200))};
    PrioritySpec later{PriorityMode::Deadline,deadline_sort(now+std::chrono::seconds(2))};
    assert(priority_order_key(soon,now)<priority_order_key(later,now));
    PrioritySpec expired{PriorityMode::Deadline,deadline_sort(now-std::chrono::milliseconds(100))};
    assert(priority_order_key(expired,now)>priority_order_key(later,now));

    Route r; r.peer="priority-test";r.layer=4;r.carrier="udp";r.destination="127.0.0.1:43719";
    ListenOptions lo;lo.timeout_ms=2500;
    ReceiveResult first,second;bool ok=false;
    std::thread listener([&]{try{Listener l(r,lo);first=l.receive();second=l.receive();ok=true;}catch(const std::exception&e){std::cerr<<e.what()<<"\n";}});
    std::this_thread::sleep_for(std::chrono::milliseconds(80));
    SendOptions so;so.timeout_ms=500;so.retries=4;so.key=0x190019;so.priority={PriorityMode::Static,7};
    send_message(r,std::vector<uint8_t>{'s','t','a','t','i','c'},so);
    SendOptions dead=so;dead.key=0x190020;dead.priority={PriorityMode::Deadline,deadline_sort_after(std::chrono::seconds(3))};
    send_message(r,std::vector<uint8_t>{'d','e','a','d','l','i','n','e'},dead);
    listener.join();assert(ok);
    assert(first.priority.mode==PriorityMode::Static);assert(first.priority.sort==7);
    assert(second.priority.mode==PriorityMode::Deadline);assert(second.priority.sort==dead.priority.sort);
    std::cout<<"PASS XTP SORT/DEADLINE scheduler and wire priority round-trip\n";
}
