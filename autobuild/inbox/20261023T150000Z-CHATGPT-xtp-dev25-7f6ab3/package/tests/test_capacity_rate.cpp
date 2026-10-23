#include "xtp/xtp_transport.hpp"
#include <cassert>
#include <chrono>
#include <iostream>
#include <thread>
using namespace xtp;
int main(){
    Route r; r.peer="rate-node"; r.layer=4; r.carrier="udp"; r.destination="127.0.0.1:44919";
    ListenOptions lo; lo.timeout_ms=3000; lo.allowed_services={"storage.range.read"};
    std::vector<uint8_t> received;
    std::thread listener([&]{Listener l(r,lo); auto x=l.receive(); received=x.logical; assert(x.service_name=="storage.range.read");});
    std::this_thread::sleep_for(std::chrono::milliseconds(50));
    std::vector<uint8_t> payload(60000,0x5a);
    SendOptions so; so.service_name="storage.range.read"; so.timeout_ms=1000; so.retries=3; so.max_rate_bytes_per_sec=300000;
    auto start=std::chrono::steady_clock::now();
    auto result=send_message(r,payload,so);
    auto elapsed=std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now()-start).count();
    listener.join();
    assert(result.logical_bytes==payload.size()); assert(received==payload);
    // XTP header/trailer make the paced wire packet slightly larger than payload.
    assert(elapsed>=185); assert(elapsed<2000);
    std::cout<<"PASS XTP live UDP capacity rate elapsed_ms="<<elapsed<<"\n";
}
