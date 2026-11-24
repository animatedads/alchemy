#include "xtp/xtp_route.hpp"
#include <algorithm>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <stdexcept>
#include <unistd.h>

namespace xtp {
namespace fs = std::filesystem;
static std::string default_path() {
    if (const char* p = std::getenv("XTP_ROUTE_FILE")) return p;
    const char* h = std::getenv("HOME");
    return std::string(h ? h : ".") + "/.config/oorexx-xtp/routes.tsv";
}
RouteTable::RouteTable(std::string path) : path_(path.empty() ? default_path() : std::move(path)) {}
std::vector<Route> RouteTable::load() const {
    std::vector<Route> out; std::ifstream f(path_); if (!f) return out;
    std::string line;
    while (std::getline(f, line)) {
        if (line.empty() || line[0]=='#') continue;
        std::istringstream s(line); Route r; std::string layer, metric, enabled, multicast;
        if (!std::getline(s,r.peer,'\t') || !std::getline(s,layer,'\t') || !std::getline(s,r.carrier,'\t') ||
            !std::getline(s,r.destination,'\t') || !std::getline(s,r.interface_name,'\t') ||
            !std::getline(s,metric,'\t') || !std::getline(s,enabled,'\t')) continue;
        // dev6 route files are accepted; wire_filters was added in dev7 and multicast in dev15.
        std::getline(s, r.wire_filters, '\t');
        std::getline(s, multicast, '\t');
        r.layer=std::stoi(layer); r.metric=std::stoi(metric); r.enabled=(enabled=="1"); r.multicast=(multicast=="1"); out.push_back(r);
    }
    return out;
}
void RouteTable::save(const std::vector<Route>& routes) const {
    fs::path p(path_); if (p.has_parent_path()) fs::create_directories(p.parent_path());
    const std::string tmp = path_ + ".tmp." + std::to_string(static_cast<unsigned long long>(::getpid()));
    {
        std::ofstream f(tmp, std::ios::trunc); if(!f) throw std::runtime_error("cannot write route table: "+tmp);
        f << "#peer\tlayer\tcarrier\tdestination\tinterface\tmetric\tenabled\twire_filters\tmulticast\n";
        for (const auto& r: routes) {
            if (r.peer.find('\t')!=std::string::npos || r.destination.find('\t')!=std::string::npos ||
                r.interface_name.find('\t')!=std::string::npos || r.carrier.find('\t')!=std::string::npos ||
                r.wire_filters.find('\t')!=std::string::npos)
                throw std::runtime_error("route fields may not contain tabs");
            f<<r.peer<<'\t'<<r.layer<<'\t'<<r.carrier<<'\t'<<r.destination<<'\t'<<r.interface_name<<'\t'<<r.metric<<'\t'<<(r.enabled?1:0)<<'\t'<<r.wire_filters<<'\t'<<(r.multicast?1:0)<<'\n';
        }
        f.flush(); if(!f) throw std::runtime_error("cannot flush route table: "+tmp);
    }
    fs::rename(tmp, path_);
}
std::vector<Route> RouteTable::list(const std::string& peer) const {
    auto r=load(); if(peer.empty()) return r; r.erase(std::remove_if(r.begin(),r.end(),[&](const Route& x){return x.peer!=peer;}),r.end()); return r;
}
void RouteTable::add(const Route& route) {
    if(route.layer<2||route.layer>4) throw std::runtime_error("route layer must be 2, 3 or 4");
    if(route.peer.empty()) throw std::runtime_error("route peer must not be empty");
    if(route.carrier.empty()) throw std::runtime_error("route carrier must not be empty");
    if(route.layer==2 && route.interface_name.empty()) throw std::runtime_error("L2 route requires interface");
    auto rs=load();
    rs.erase(std::remove_if(rs.begin(),rs.end(),[&](const Route& r){return r.peer==route.peer&&r.layer==route.layer&&r.carrier==route.carrier&&r.destination==route.destination;}),rs.end());
    rs.push_back(route); save(rs);
}
size_t RouteTable::remove(const std::string& peer,std::optional<int> layer,const std::string& carrier){
    auto rs=load(); auto before=rs.size();
    rs.erase(std::remove_if(rs.begin(),rs.end(),[&](const Route&r){return r.peer==peer&&(!layer||r.layer==*layer)&&(carrier.empty()||r.carrier==carrier);}),rs.end());
    save(rs); return before-rs.size();
}
size_t RouteTable::set_enabled(const std::string& peer,bool enabled,std::optional<int> layer,const std::string& carrier){
    auto rs=load(); size_t n=0;
    for(auto& r:rs) if(r.peer==peer&&(!layer||r.layer==*layer)&&(carrier.empty()||r.carrier==carrier)){r.enabled=enabled;++n;}
    if(n) save(rs);
    return n;
}
std::vector<Route> RouteTable::best_paths(const std::string& peer, size_t max_paths, bool multicast) const {
    auto rs=list(peer); rs.erase(std::remove_if(rs.begin(),rs.end(),[&](const Route&r){return !r.enabled || r.multicast!=multicast;}),rs.end());
    std::stable_sort(rs.begin(),rs.end(),[](const Route&a,const Route&b){if(a.layer!=b.layer)return a.layer<b.layer;return a.metric<b.metric;});
    if(max_paths && rs.size()>max_paths) rs.resize(max_paths);
    return rs;
}
std::optional<Route> RouteTable::best_connect(const std::string& peer) const {
    auto rs=best_paths(peer,1); if(rs.empty()) return std::nullopt; return rs.front();
}
}

namespace xtp {
static std::string default_health_path() {
    if (const char* p = std::getenv("XTP_HEALTH_FILE")) return p;
    const char* h = std::getenv("HOME");
    return std::string(h ? h : ".") + "/.config/oorexx-xtp/path-health.tsv";
}
static bool same_route_identity(const Route& a, const Route& b) {
    return a.peer==b.peer && a.layer==b.layer && a.carrier==b.carrier &&
           a.destination==b.destination && a.interface_name==b.interface_name;
}
PathHealthTable::PathHealthTable(std::string path) : path_(path.empty()?default_health_path():std::move(path)) {}
std::vector<PathHealth> PathHealthTable::load() const {
    std::vector<PathHealth> out; std::ifstream f(path_); if(!f) return out;
    std::string line;
    while(std::getline(f,line)) {
        if(line.empty()||line[0]=='#') continue;
        std::istringstream s(line); PathHealth h; std::string layer,generation,failures;
        if(!std::getline(s,h.route.peer,'\t') || !std::getline(s,layer,'\t') || !std::getline(s,h.route.carrier,'\t') ||
           !std::getline(s,h.route.destination,'\t') || !std::getline(s,h.route.interface_name,'\t') ||
           !std::getline(s,h.state,'\t') || !std::getline(s,generation,'\t') || !std::getline(s,failures,'\t')) continue;
        std::getline(s,h.last_error,'\t');
        h.route.layer=std::stoi(layer); h.generation=uint32_t(std::stoul(generation)); h.failure_count=uint32_t(std::stoul(failures));
        if(h.generation==0) h.generation=1;
        out.push_back(std::move(h));
    }
    return out;
}
void PathHealthTable::save(const std::vector<PathHealth>& rows) const {
    fs::path p(path_); if(p.has_parent_path()) fs::create_directories(p.parent_path());
    const std::string tmp=path_+".tmp."+std::to_string(static_cast<unsigned long long>(::getpid()));
    std::ofstream f(tmp,std::ios::trunc); if(!f) throw std::runtime_error("cannot write path health table: "+tmp);
    f << "#peer\tlayer\tcarrier\tdestination\tinterface\tstate\tgeneration\tfailures\tlast_error\n";
    for(const auto& h:rows){
        auto clean=[](std::string v){std::replace(v.begin(),v.end(),'\t',' ');std::replace(v.begin(),v.end(),'\n',' ');return v;};
        f<<clean(h.route.peer)<<'\t'<<h.route.layer<<'\t'<<clean(h.route.carrier)<<'\t'<<clean(h.route.destination)<<'\t'<<clean(h.route.interface_name)<<'\t'
         <<clean(h.state)<<'\t'<<h.generation<<'\t'<<h.failure_count<<'\t'<<clean(h.last_error)<<'\n';
    }
    f.flush(); if(!f) throw std::runtime_error("cannot flush path health table: "+tmp); f.close(); fs::rename(tmp,path_);
}
std::vector<PathHealth> PathHealthTable::list(const std::string& peer) const {
    auto rows=load(); if(peer.empty()) return rows;
    rows.erase(std::remove_if(rows.begin(),rows.end(),[&](const PathHealth&h){return h.route.peer!=peer;}),rows.end()); return rows;
}
PathHealth PathHealthTable::status(const Route& route) const {
    for(const auto& h:load()) if(same_route_identity(h.route,route)) return h;
    PathHealth h; h.route=route; return h;
}
bool PathHealthTable::is_eligible(const Route& route) const { return status(route).state=="UP"; }
uint32_t PathHealthTable::generation(const Route& route) const { return status(route).generation; }
void PathHealthTable::mark_failure(const Route& route,const std::string& error){
    auto rows=load(); auto it=std::find_if(rows.begin(),rows.end(),[&](const PathHealth&h){return same_route_identity(h.route,route);});
    if(it==rows.end()){PathHealth h;h.route=route;rows.push_back(h);it=std::prev(rows.end());}
    it->state="DOWN"; it->failure_count++; it->last_error=error; save(rows);
}
void PathHealthTable::begin_requalify(const Route& route){
    auto rows=load(); auto it=std::find_if(rows.begin(),rows.end(),[&](const PathHealth&h){return same_route_identity(h.route,route);});
    if(it==rows.end()){PathHealth h;h.route=route;rows.push_back(h);it=std::prev(rows.end());}
    it->state="PROBING"; save(rows);
}
uint32_t PathHealthTable::mark_requalified(const Route& route){
    auto rows=load(); auto it=std::find_if(rows.begin(),rows.end(),[&](const PathHealth&h){return same_route_identity(h.route,route);});
    if(it==rows.end()){PathHealth h;h.route=route;rows.push_back(h);it=std::prev(rows.end());}
    it->state="UP"; it->generation++; if(it->generation==0) it->generation=1; it->last_error.clear(); save(rows); return it->generation;
}
void PathHealthTable::clear(const Route& route){
    auto rows=load(); rows.erase(std::remove_if(rows.begin(),rows.end(),[&](const PathHealth&h){return same_route_identity(h.route,route);}),rows.end()); save(rows);
}
}
