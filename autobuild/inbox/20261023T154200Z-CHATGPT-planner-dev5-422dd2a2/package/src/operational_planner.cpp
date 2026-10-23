#include "operational/operational_planner.hpp"
#include <algorithm>
#include <cctype>
#include <fstream>
#include <sstream>
#include <stdexcept>

namespace operational {
static std::string lower(std::string s){std::transform(s.begin(),s.end(),s.begin(),[](unsigned char c){return char(std::tolower(c));});return s;}
static size_t idx(OperatingState s){return static_cast<size_t>(s);}

bool Decision::permits_transmission() const {
    return policy.disposition==Disposition::Allow || policy.disposition==Disposition::Throttle;
}
bool Decision::requires_upstream_transform() const {
    return policy.disposition==Disposition::Sample || policy.disposition==Disposition::Aggregate;
}

void CapacityRegistry::set_domain(const CapacityDomain& d){
    if(d.name.empty()) throw std::runtime_error("capacity domain name may not be empty");
    if(d.nominal_bytes_per_sec==0) throw std::runtime_error("capacity nominal bytes/sec must be positive");
    CapacityDomain x=d;
    if(x.current_bytes_per_sec==0) x.current_bytes_per_sec=x.nominal_bytes_per_sec;
    domains_[x.name]=x;
}
const CapacityDomain* CapacityRegistry::find(const std::string& name) const {auto i=domains_.find(name);return i==domains_.end()?nullptr:&i->second;}
std::vector<CapacityDomain> CapacityRegistry::domains() const {std::vector<CapacityDomain> out;for(const auto& kv:domains_)out.push_back(kv.second);return out;}

std::optional<CapacityTicket> CapacityGovernor::acquire(const Decision& d,const std::string& domain_name){
    std::lock_guard<std::mutex> lock(mutex_);
    const auto* dom=registry_.find(domain_name);
    if(!dom) throw std::runtime_error("unknown capacity domain: "+domain_name);
    if(!d.permits_transmission()||d.requires_upstream_transform()) return std::nullopt;
    uint8_t percent=d.policy.per_context_cap_percent;
    if(d.policy.disposition==Disposition::Throttle) percent=std::min(percent,d.policy.rate_percent);
    if(percent==0) return std::nullopt;
    const auto count=active_contexts_unlocked(d.class_name,domain_name);
    if(d.policy.max_parallel_contexts>0 && count>=d.policy.max_parallel_contexts) return std::nullopt;
    const auto used=active_percent_unlocked(d.class_name,domain_name);
    if(d.policy.aggregate_cap_percent>0 && unsigned(used)+unsigned(percent)>d.policy.aggregate_cap_percent) return std::nullopt;
    CapacityTicket t; t.id=next_ticket_++; t.class_name=d.class_name; t.domain_name=domain_name; t.reserved_percent=percent; t.admitted=true;
    const uint64_t base=dom->current_bytes_per_sec?dom->current_bytes_per_sec:dom->nominal_bytes_per_sec;
    t.effective_bytes_per_sec=(base*percent)/100u;
    tickets_[t.id]=t;
    return t;
}
bool CapacityGovernor::release(uint64_t id){std::lock_guard<std::mutex> lock(mutex_);return tickets_.erase(id)!=0;}
void CapacityGovernor::set_domain(const CapacityDomain& domain){
    std::lock_guard<std::mutex> lock(mutex_);
    registry_.set_domain(domain);
    const auto* dom=registry_.find(domain.name);
    const uint64_t base=dom->current_bytes_per_sec?dom->current_bytes_per_sec:dom->nominal_bytes_per_sec;
    for(auto& kv:tickets_) if(kv.second.domain_name==domain.name){
        kv.second.effective_bytes_per_sec=kv.second.admitted?(base*kv.second.reserved_percent)/100u:0;
    }
}
std::vector<CapacityTicket> CapacityGovernor::reconcile(const Decision& d,const std::string& domain_name){
    std::lock_guard<std::mutex> lock(mutex_);
    const auto* dom=registry_.find(domain_name);
    if(!dom) throw std::runtime_error("unknown capacity domain: "+domain_name);
    uint8_t percent=d.policy.per_context_cap_percent;
    if(d.policy.disposition==Disposition::Throttle) percent=std::min(percent,d.policy.rate_percent);
    const bool can_transmit=d.permits_transmission()&&!d.requires_upstream_transform()&&percent>0;
    uint16_t admitted_count=0;
    uint16_t admitted_percent=0;
    const uint64_t base=dom->current_bytes_per_sec?dom->current_bytes_per_sec:dom->nominal_bytes_per_sec;
    std::vector<CapacityTicket> out;
    for(auto& kv:tickets_){
        auto& t=kv.second;
        if(t.class_name!=d.class_name||t.domain_name!=domain_name) continue;
        bool admit=can_transmit;
        if(admit && d.policy.max_parallel_contexts>0 && admitted_count>=d.policy.max_parallel_contexts) admit=false;
        if(admit && d.policy.aggregate_cap_percent>0 && unsigned(admitted_percent)+unsigned(percent)>d.policy.aggregate_cap_percent) admit=false;
        t.admitted=admit;
        if(admit){
            t.reserved_percent=percent;
            t.effective_bytes_per_sec=(base*percent)/100u;
            ++admitted_count;
            admitted_percent=uint16_t(admitted_percent+percent);
        } else {
            t.reserved_percent=0;
            t.effective_bytes_per_sec=0;
        }
        out.push_back(t);
    }
    return out;
}
std::optional<CapacityTicket> CapacityGovernor::ticket(uint64_t id) const {std::lock_guard<std::mutex> lock(mutex_);auto i=tickets_.find(id);if(i==tickets_.end())return std::nullopt;return i->second;}
std::vector<CapacityTicket> CapacityGovernor::tickets(const std::string& cls,const std::string& domain) const {std::lock_guard<std::mutex> lock(mutex_);std::vector<CapacityTicket> out;for(const auto& kv:tickets_)if(kv.second.class_name==cls&&kv.second.domain_name==domain)out.push_back(kv.second);return out;}
uint16_t CapacityGovernor::active_contexts_unlocked(const std::string& cls,const std::string& domain) const {uint32_t n=0;for(const auto& kv:tickets_)if(kv.second.admitted&&kv.second.class_name==cls&&kv.second.domain_name==domain)++n;return uint16_t(std::min<uint32_t>(n,65535));}
uint16_t CapacityGovernor::active_percent_unlocked(const std::string& cls,const std::string& domain) const {uint32_t n=0;for(const auto& kv:tickets_)if(kv.second.admitted&&kv.second.class_name==cls&&kv.second.domain_name==domain)n+=kv.second.reserved_percent;return uint16_t(std::min<uint32_t>(n,65535));}
uint16_t CapacityGovernor::active_contexts(const std::string& cls,const std::string& domain) const {std::lock_guard<std::mutex> lock(mutex_);return active_contexts_unlocked(cls,domain);}
uint16_t CapacityGovernor::active_percent(const std::string& cls,const std::string& domain) const {std::lock_guard<std::mutex> lock(mutex_);return active_percent_unlocked(cls,domain);}
CapacityRegistry CapacityGovernor::registry_snapshot() const {std::lock_guard<std::mutex> lock(mutex_);return registry_;}


void Registry::register_class(const OperationalClass& c){if(c.name.empty()) throw std::runtime_error("operational class name may not be empty");classes_[c.name]=c;}
bool Registry::erase(const std::string& name){return classes_.erase(name)!=0;}
const OperationalClass* Registry::find(const std::string& name) const {auto i=classes_.find(name);return i==classes_.end()?nullptr:&i->second;}
std::vector<OperationalClass> Registry::classes() const {std::vector<OperationalClass> out;for(const auto& kv:classes_)out.push_back(kv.second);return out;}
Decision Planner::decide(const std::string& class_name,OperatingState state) const {
    const auto* c=registry_.find(class_name); if(!c) throw std::runtime_error("unregistered operational class: "+class_name);
    return Decision{c->name,state,c->states[idx(state)],c->transport_sort,c->transport_deadline_us};
}
std::string state_name(OperatingState s){switch(s){case OperatingState::Normal:return"normal";case OperatingState::Degraded:return"degraded";case OperatingState::Constrained:return"constrained";case OperatingState::Emergency:return"emergency";}return"normal";}
std::string disposition_name(Disposition d){switch(d){case Disposition::Allow:return"allow";case Disposition::Throttle:return"throttle";case Disposition::Sample:return"sample";case Disposition::Aggregate:return"aggregate";case Disposition::Defer:return"defer";case Disposition::Suspend:return"suspend";case Disposition::Drop:return"drop";case Disposition::RefuseForward:return"refuse-forward";}return"allow";}
std::string fallback_name(FallbackPolicy f){switch(f){case FallbackPolicy::Allow:return"allow";case FallbackPolicy::Forbid:return"forbid";case FallbackPolicy::Require:return"require";}return"allow";}
OperatingState parse_state(const std::string& v){auto s=lower(v);if(s=="normal")return OperatingState::Normal;if(s=="degraded")return OperatingState::Degraded;if(s=="constrained")return OperatingState::Constrained;if(s=="emergency")return OperatingState::Emergency;throw std::runtime_error("unknown operating state: "+v);}
Disposition parse_disposition(const std::string& v){auto s=lower(v);if(s=="allow")return Disposition::Allow;if(s=="throttle")return Disposition::Throttle;if(s=="sample")return Disposition::Sample;if(s=="aggregate")return Disposition::Aggregate;if(s=="defer")return Disposition::Defer;if(s=="suspend")return Disposition::Suspend;if(s=="drop")return Disposition::Drop;if(s=="refuse-forward"||s=="refuse_forward")return Disposition::RefuseForward;throw std::runtime_error("unknown disposition: "+v);}
FallbackPolicy parse_fallback(const std::string& v){auto s=lower(v);if(s=="allow")return FallbackPolicy::Allow;if(s=="forbid"||s=="deny")return FallbackPolicy::Forbid;if(s=="require")return FallbackPolicy::Require;throw std::runtime_error("unknown fallback policy: "+v);}
StatePolicy parse_state_policy(const std::string& value){
    std::vector<std::string> p;std::stringstream ss(value);std::string x;while(std::getline(ss,x,':'))p.push_back(x);
    StatePolicy out; if(p.empty()||p[0].empty())throw std::runtime_error("empty state policy");out.disposition=parse_disposition(p[0]);
    if(p.size()>1&&!p[1].empty()){int n=std::stoi(p[1]);if(n<0||n>100)throw std::runtime_error("rate percent must be 0..100");out.rate_percent=static_cast<uint8_t>(n);} 
    else if(out.disposition==Disposition::Throttle) out.rate_percent=50;
    if(p.size()>2&&!p[2].empty())out.fallback=parse_fallback(p[2]);
    if(p.size()>3&&!p[3].empty()){auto q=lower(p[3]);out.protected_path_only=(q=="protected"||q=="1"||q=="true"||q=="yes");}
    if(p.size()>4&&!p[4].empty()){int n=std::stoi(p[4]);if(n<1||n>100)throw std::runtime_error("per-context cap percent must be 1..100");out.per_context_cap_percent=static_cast<uint8_t>(n);}
    if(p.size()>5&&!p[5].empty()){int n=std::stoi(p[5]);if(n<1||n>65535)throw std::runtime_error("max parallel contexts must be 1..65535");out.max_parallel_contexts=static_cast<uint16_t>(n);}
    if(p.size()>6&&!p[6].empty()){int n=std::stoi(p[6]);if(n<1||n>100)throw std::runtime_error("aggregate cap percent must be 1..100");out.aggregate_cap_percent=static_cast<uint8_t>(n);}
    if(out.aggregate_cap_percent < out.per_context_cap_percent) { /* valid: aggregate may deliberately be lower than one context cap */ }
    return out;
}
std::string encode_state_policy(const StatePolicy& p){return disposition_name(p.disposition)+":"+std::to_string(p.rate_percent)+":"+fallback_name(p.fallback)+":"+(p.protected_path_only?"protected":"any")+":"+std::to_string(p.per_context_cap_percent)+":"+std::to_string(p.max_parallel_contexts)+":"+std::to_string(p.aggregate_cap_percent);}
Registry load_registry(const std::string& path){Registry r;std::ifstream in(path);if(!in.good())return r;std::string line;while(std::getline(in,line)){if(line.empty()||line[0]=='#')continue;std::stringstream ss(line);std::string f;std::vector<std::string> v;while(std::getline(ss,f,'\t'))v.push_back(f);if(v.size()<5)throw std::runtime_error("invalid operational registry line");OperationalClass c;c.name=v[0];for(size_t i=0;i<4;i++)c.states[i]=parse_state_policy(v[i+1]);if(v.size()>5&&!v[5].empty()&&v[5]!="-")c.transport_sort=static_cast<uint32_t>(std::stoul(v[5]));if(v.size()>6&&!v[6].empty()&&v[6]!="-")c.transport_deadline_us=std::stoull(v[6]);r.register_class(c);}return r;}
CapacityRegistry load_capacity_registry(const std::string& path){CapacityRegistry r;std::ifstream in(path);if(!in.good())return r;std::string line;while(std::getline(in,line)){if(line.empty()||line[0]=='#')continue;std::stringstream ss(line);std::string name,nominal,current;std::getline(ss,name,'\t');std::getline(ss,nominal,'\t');std::getline(ss,current,'\t');if(name.empty()||nominal.empty())throw std::runtime_error("invalid capacity registry line");CapacityDomain d;d.name=name;d.nominal_bytes_per_sec=std::stoull(nominal);d.current_bytes_per_sec=current.empty()?d.nominal_bytes_per_sec:std::stoull(current);r.set_domain(d);}return r;}
void save_capacity_registry(const CapacityRegistry& r,const std::string& path){std::ofstream out(path,std::ios::trunc);if(!out)throw std::runtime_error("cannot write capacity registry: "+path);out<<"#name\tnominal_bytes_per_sec\tcurrent_bytes_per_sec\n";for(const auto& d:r.domains())out<<d.name<<'\t'<<d.nominal_bytes_per_sec<<'\t'<<d.current_bytes_per_sec<<'\n';}

void save_registry(const Registry& r,const std::string& path){std::ofstream out(path,std::ios::trunc);if(!out)throw std::runtime_error("cannot write operational registry: "+path);out<<"#name\tnormal\tdegraded\tconstrained\temergency\tsort\tdeadline_us\n";for(const auto& c:r.classes()){out<<c.name;for(const auto& p:c.states)out<<'\t'<<encode_state_policy(p);out<<'\t'<<(c.transport_sort?std::to_string(*c.transport_sort):"-")<<'\t'<<(c.transport_deadline_us?std::to_string(*c.transport_deadline_us):"-")<<'\n';}}
} // namespace operational
