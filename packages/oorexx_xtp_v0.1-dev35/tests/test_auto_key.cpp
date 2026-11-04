#include "xtp/xtp_transport.hpp"
#include <cassert>
#include <chrono>
#include <iostream>
#include <thread>
using namespace xtp;
int main(){
    Route r; r.peer="auto-key-node"; r.layer=4; r.carrier="udp"; r.destination="127.0.0.1:44922";
    ListenOptions lo; lo.timeout_ms=3000; lo.allowed_services={"storage.range.read"};
    std::string a,b;
    std::thread t([&]{Listener l(r,lo); auto x=l.receive(); auto y=l.receive(); a.assign(x.logical.begin(),x.logical.end()); b.assign(y.logical.begin(),y.logical.end());});
    std::this_thread::sleep_for(std::chrono::milliseconds(50));
    SendOptions so; so.service_name="storage.range.read";
    send_message(r,std::vector<uint8_t>{'o','n','e'},so);
    send_message(r,std::vector<uint8_t>{'t','w','o'},so);
    t.join();
    assert(a=="one"&&b=="two");
    std::cout<<"PASS automatic XTP context keys prevent false replay across repeated named-service sends\n";
}
