#include "xtp/xtp_socket.hpp"
#include <algorithm>
#include <stdexcept>
namespace xtp {
namespace {
std::vector<Route> eligible(const RouteTable& routes, const PathHealthTable& health,
                            const std::string& peer, size_t max_paths=0) {
    auto rs=routes.best_paths(peer,0);
    rs.erase(std::remove_if(rs.begin(),rs.end(),[&](const Route&r){return !health.is_eligible(r);}),rs.end());
    if(max_paths && rs.size()>max_paths) rs.resize(max_paths);
    return rs;
}
uint32_t pathset_generation(const std::vector<Route>& rs,const PathHealthTable& health){
    uint32_t g=1; for(const auto&r:rs) g=std::max(g,health.generation(r)); return g;
}
}
std::optional<SocketSelection> SocketProvider::select(const std::string& peer) const {
    auto rs=eligible(routes_,health_,peer,1); if(rs.empty()) return std::nullopt;
    return SocketSelection{rs.front(),"xtp",WireFilterChain::parse_spec(rs.front().wire_filters)};
}
SocketPathSet SocketProvider::select_paths(const std::string& peer,size_t max_paths) const {
    SocketPathSet set;
    for(const auto&r:eligible(routes_,health_,peer,max_paths)) set.paths.push_back(SocketSelection{r,"xtp",WireFilterChain::parse_spec(r.wire_filters)});
    return set;
}
SendResult SocketProvider::send(const std::string& peer,const std::vector<uint8_t>&logical,const SendOptions&options) const {
    auto rs=eligible(routes_,health_,peer,0); if(rs.empty()) throw std::runtime_error("no healthy enabled XTP route for peer: "+peer);
    std::string last;
    for(const auto&r:rs){try{return send_message(r,logical,options);}catch(const std::exception&e){last=e.what();health_.mark_failure(r,last);}}
    throw std::runtime_error("all XTP routes failed for peer: "+peer+": "+last);
}
std::unique_ptr<Listener> SocketProvider::listen(const std::string& peer,const ListenOptions&options) const {
    auto rs=routes_.best_paths(peer,1); if(rs.empty()) throw std::runtime_error("no enabled XTP listener route for peer: "+peer);
    return std::make_unique<Listener>(rs.front(),options);
}
MultipathSendResult SocketProvider::send_multipath(const std::string& peer,const std::vector<uint8_t>&logical,const MultipathOptions&options) const {
    auto rs=eligible(routes_,health_,peer,options.max_paths); if(rs.empty()) throw std::runtime_error("no healthy enabled XTP multipath routes for peer: "+peer);
    MultipathOptions effective=options; if(effective.generation==0) effective.generation=pathset_generation(rs,health_);
    try {
        auto out=xtp::send_multipath(rs,logical,effective);
        for(const auto&p:out.paths) if(p.failed) health_.mark_failure(p.route,p.error);
        return out;
    } catch(...) {
        throw;
    }
}
std::unique_ptr<MultipathListener> SocketProvider::listen_multipath(const std::string& peer,size_t max_paths,const ListenOptions&options) const {
    auto rs=routes_.best_paths(peer,max_paths); if(rs.empty()) throw std::runtime_error("no enabled XTP multipath listener routes for peer: "+peer);
    return std::make_unique<MultipathListener>(rs,options);
}
QualificationResult SocketProvider::requalify(const Route& route,const SendOptions&options) const {
    auto before=health_.status(route);
    health_.begin_requalify(route);
    try{
        auto q=qualify_path(route,options);
        q.generation_before=before.generation;
        q.generation_after=health_.mark_requalified(route);
        return q;
    }catch(const std::exception&e){
        health_.mark_failure(route,e.what());
        throw;
    }
}
}

namespace xtp {
MulticastSendResult SocketProvider::send_multicast(const std::string& peer,const std::vector<uint8_t>&logical,const MulticastOptions&options) const {
    auto rs=routes_.multicast_paths(peer,0);
    rs.erase(std::remove_if(rs.begin(),rs.end(),[&](const Route&r){return !health_.is_eligible(r);}),rs.end());
    if(rs.empty()) throw std::runtime_error("no healthy enabled XTP multicast route for peer/group: "+peer);
    std::string last;
    for(const auto&r:rs){try{return xtp::send_multicast(r,logical,options);}catch(const std::exception&e){last=e.what();}}
    throw std::runtime_error("all XTP multicast routes failed for peer/group: "+peer+": "+last);
}
std::unique_ptr<MulticastListener> SocketProvider::listen_multicast(const std::string& peer,const ListenOptions&options) const {
    auto rs=routes_.multicast_paths(peer,1);if(rs.empty())throw std::runtime_error("no enabled XTP multicast listener route for peer/group: "+peer);
    return std::make_unique<MulticastListener>(rs.front(),options);
}
}
