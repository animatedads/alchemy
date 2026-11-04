#include "xtp/xtp_route.hpp"
#include "xtp/xtp_socket.hpp"
#include "xtp/xtp_wire.hpp"
#include <iomanip>
#include <iostream>
#include <map>
#include <optional>
#include <sstream>
#include <string>
#include <vector>

static void usage(){std::cerr<<"usage:\n  xtp-admin route add PEER --layer 2|3|4 --carrier NAME --to DEST [--interface IFACE] [--metric N] [--filters SPEC] [--multicast]\n  xtp-admin route list [PEER] [--json]\n  xtp-admin route remove PEER [--layer N] [--carrier NAME]\n  xtp-admin route enable|disable PEER [--layer N] [--carrier NAME]\n  xtp-admin best-connect PEER [--json]\n  xtp-admin best-paths PEER [--max N] [--json]\n  xtp-admin path list [PEER] [--json]\n  xtp-admin path down|probe|qualify|force-up|clear PEER --layer N --carrier NAME [--to DEST] [--error TEXT] [--timeout-ms N] [--retries N]\n  xtp-admin filter roundtrip --filters zero-block,crunch --hex HEX\n";}
static std::vector<uint8_t> unhex(std::string s){if(s.size()%2)throw std::runtime_error("hex must have even length");std::vector<uint8_t>b;for(size_t i=0;i<s.size();i+=2)b.push_back(uint8_t(std::stoul(s.substr(i,2),nullptr,16)));return b;}
static std::string hex(const std::vector<uint8_t>&b){std::ostringstream o;o<<std::hex<<std::setfill('0');for(auto v:b)o<<std::setw(2)<<unsigned(v);return o.str();}
static std::string jq(const std::string&s){std::string o="\"";for(unsigned char c:s){switch(c){case '\\':o+="\\\\";break;case '"':o+="\\\"";break;case '\n':o+="\\n";break;case '\r':o+="\\r";break;case '\t':o+="\\t";break;default:if(c<0x20){std::ostringstream x;x<<"\\u"<<std::hex<<std::setw(4)<<std::setfill('0')<<unsigned(c);o+=x.str();}else o+=char(c);}}return o+"\"";}
static void print_json(const xtp::Route&r){std::cout<<"{\"peer\":"<<jq(r.peer)<<",\"layer\":"<<r.layer<<",\"carrier\":"<<jq(r.carrier)<<",\"destination\":"<<jq(r.destination)<<",\"interface\":"<<jq(r.interface_name)<<",\"metric\":"<<r.metric<<",\"enabled\":"<<(r.enabled?"true":"false")<<",\"wire_filters\":"<<jq(r.wire_filters)<<",\"multicast\":"<<(r.multicast?"true":"false")<<"}";}
static std::map<std::string,std::string> opts(int argc,char**argv,int start){std::map<std::string,std::string>o;for(int i=start;i<argc;++i){std::string k=argv[i];if(k=="--json"||k=="--multicast"){o[k]="1";continue;}if(i+1>=argc)throw std::runtime_error("option needs value: "+k);o[k]=argv[++i];}return o;}
static std::optional<int> opt_layer(const std::map<std::string,std::string>&o){auto it=o.find("--layer");if(it==o.end())return std::nullopt;return std::stoi(it->second);}
static xtp::Route find_route(xtp::RouteTable&rt,const std::string&peer,const std::map<std::string,std::string>&o){
 auto layer=opt_layer(o);if(!layer)throw std::runtime_error("path operation requires --layer");
 auto carrier=o.find("--carrier");if(carrier==o.end())throw std::runtime_error("path operation requires --carrier");
 auto rs=rt.list(peer);for(const auto&r:rs)if(r.layer==*layer&&r.carrier==carrier->second&&(o.count("--to")==0||r.destination==o.at("--to")))return r;
 throw std::runtime_error("matching route not found");
}
static void print_health_json(const xtp::PathHealth&h){std::cout<<"{\"peer\":"<<jq(h.route.peer)<<",\"layer\":"<<h.route.layer<<",\"carrier\":"<<jq(h.route.carrier)<<",\"destination\":"<<jq(h.route.destination)<<",\"interface\":"<<jq(h.route.interface_name)<<",\"state\":"<<jq(h.state)<<",\"generation\":"<<h.generation<<",\"failures\":"<<h.failure_count<<",\"last_error\":"<<jq(h.last_error)<<"}";}
int main(int argc,char**argv){try{if(argc<2){usage();return 2;}std::string cmd=argv[1];xtp::RouteTable rt;
 if(cmd=="route"&&argc>=3){std::string op=argv[2];
  if(op=="list"){std::string peer;int start=3;if(argc>=4&&std::string(argv[3]).rfind("--",0)!=0){peer=argv[3];start=4;}auto o=opts(argc,argv,start);auto rs=rt.list(peer);if(o.count("--json")){std::cout<<"[";for(size_t i=0;i<rs.size();++i){if(i)std::cout<<",";print_json(rs[i]);}std::cout<<"]\n";}else for(auto&r:rs)std::cout<<r.peer<<'\t'<<r.layer<<'\t'<<r.carrier<<'\t'<<r.destination<<'\t'<<r.interface_name<<'\t'<<r.metric<<'\t'<<(r.enabled?"enabled":"disabled")<<'\t'<<r.wire_filters<<'\t'<<(r.multicast?"multicast":"unicast")<<'\n';return 0;}
  if(argc<4){usage();return 2;}std::string peer=argv[3];auto o=opts(argc,argv,4);
  if(op=="add"){xtp::Route r;r.peer=peer;r.layer=std::stoi(o.at("--layer"));r.carrier=o.at("--carrier");r.destination=o.count("--to")?o["--to"]:"";r.interface_name=o.count("--interface")?o["--interface"]:"";r.metric=o.count("--metric")?std::stoi(o["--metric"]):100;r.wire_filters=o.count("--filters")?o["--filters"]:"";r.multicast=o.count("--multicast")!=0;xtp::WireFilterChain::parse_spec(r.wire_filters);rt.add(r);std::cout<<"ROUTE_ADDED peer="<<r.peer<<" layer="<<r.layer<<" carrier="<<r.carrier<<" filters="<<r.wire_filters<<" multicast="<<(r.multicast?1:0)<<"\n";return 0;}
  if(op=="remove"){auto n=rt.remove(peer,opt_layer(o),o.count("--carrier")?o["--carrier"]:"");std::cout<<"ROUTE_REMOVED count="<<n<<"\n";return n?0:1;}
  if(op=="enable"||op=="disable"){auto n=rt.set_enabled(peer,op=="enable",opt_layer(o),o.count("--carrier")?o["--carrier"]:"");std::cout<<"ROUTE_"<<(op=="enable"?"ENABLED":"DISABLED")<<" count="<<n<<"\n";return n?0:1;}
 }
 if(cmd=="path"&&argc>=3){std::string op=argv[2];xtp::PathHealthTable ht;
  if(op=="list"){std::string peer;int start=3;if(argc>=4&&std::string(argv[3]).rfind("--",0)!=0){peer=argv[3];start=4;}auto o=opts(argc,argv,start);auto hs=ht.list(peer);if(o.count("--json")){std::cout<<"[";for(size_t i=0;i<hs.size();++i){if(i)std::cout<<",";print_health_json(hs[i]);}std::cout<<"]\n";}else for(auto&h:hs)std::cout<<h.route.peer<<'\t'<<h.route.layer<<'\t'<<h.route.carrier<<'\t'<<h.route.destination<<'\t'<<h.route.interface_name<<'\t'<<h.state<<'\t'<<h.generation<<'\t'<<h.failure_count<<'\t'<<h.last_error<<"\n";return 0;}
  if(argc<4){usage();return 2;}std::string peer=argv[3];auto o=opts(argc,argv,4);auto r=find_route(rt,peer,o);
  if(op=="down"){ht.mark_failure(r,o.count("--error")?o["--error"]:"administratively marked down");std::cout<<"PATH_DOWN peer="<<peer<<" layer="<<r.layer<<" carrier="<<r.carrier<<"\n";return 0;}
  if(op=="probe"){ht.begin_requalify(r);std::cout<<"PATH_PROBING peer="<<peer<<" layer="<<r.layer<<" carrier="<<r.carrier<<" generation="<<ht.generation(r)<<"\n";return 0;}
  if(op=="qualify"){
    xtp::SendOptions so; if(o.count("--timeout-ms"))so.timeout_ms=std::stoi(o.at("--timeout-ms")); if(o.count("--retries"))so.retries=std::stoi(o.at("--retries"));
    so.key=0x5155414cU;
    xtp::SocketProvider provider{rt,ht};
    try{
      auto q=provider.requalify(r,so);
      std::cout<<"PATH_QUALIFIED peer="<<peer<<" layer="<<r.layer<<" carrier="<<r.carrier<<" provider="<<q.provider<<" method="<<q.method<<" attempts="<<q.attempts<<" generation_before="<<q.generation_before<<" generation="<<q.generation_after<<"\n";
      return 0;
    }catch(const std::exception&e){
      std::cerr<<"PATH_QUALIFY_FAILED peer="<<peer<<" layer="<<r.layer<<" carrier="<<r.carrier<<" error="<<e.what()<<"\n";
      return 7;
    }
  }
  if(op=="force-up"){auto g=ht.mark_requalified(r);std::cout<<"PATH_FORCE_UP peer="<<peer<<" layer="<<r.layer<<" carrier="<<r.carrier<<" generation="<<g<<"\n";return 0;}
  if(op=="clear"){ht.clear(r);std::cout<<"PATH_CLEARED peer="<<peer<<" layer="<<r.layer<<" carrier="<<r.carrier<<"\n";return 0;}
 }
 if((cmd=="best-connect"||cmd=="best-paths")&&argc>=3){std::string peer=argv[2];auto o=opts(argc,argv,3);bool json=o.count("--json");if(cmd=="best-connect"){auto r=rt.best_connect(peer);if(!r){std::cerr<<"NO_ROUTE\n";return 3;}if(json){print_json(*r);std::cout<<"\n";}else std::cout<<"BEST_CONNECT peer="<<r->peer<<" layer="<<r->layer<<" carrier="<<r->carrier<<" to="<<r->destination<<" interface="<<r->interface_name<<" metric="<<r->metric<<" filters="<<r->wire_filters<<"\n";return 0;}size_t max=o.count("--max")?std::stoul(o["--max"]):0;auto rs=rt.best_paths(peer,max);if(rs.empty()){std::cerr<<"NO_ROUTE\n";return 3;}if(json){std::cout<<"[";for(size_t i=0;i<rs.size();++i){if(i)std::cout<<",";print_json(rs[i]);}std::cout<<"]\n";}else for(auto&r:rs)std::cout<<"PATH peer="<<r.peer<<" layer="<<r.layer<<" carrier="<<r.carrier<<" to="<<r.destination<<" interface="<<r.interface_name<<" metric="<<r.metric<<" filters="<<r.wire_filters<<" multicast="<<(r.multicast?1:0)<<"\n";return 0;}
 if(cmd=="filter"&&argc>=7&&std::string(argv[2])=="roundtrip"){std::string spec,hs;for(int i=3;i+1<argc;i+=2){std::string k=argv[i];if(k=="--filters")spec=argv[i+1];else if(k=="--hex")hs=argv[i+1];}auto in=unhex(hs);auto c=xtp::WireFilterChain::parse_spec(spec);auto wr=c.encode(in);auto out=xtp::WireFilterChain::decode_envelope(wr.bytes);std::cout<<"FILTER_OK logical="<<in.size()<<" wire="<<wr.bytes.size()<<" filters="<<spec<<" encoded="<<hex(wr.bytes)<<" decoded="<<hex(out)<<"\n";return in==out?0:4;}
 usage();return 2;}catch(const std::exception&e){std::cerr<<"error: "<<e.what()<<"\n";return 2;}}
