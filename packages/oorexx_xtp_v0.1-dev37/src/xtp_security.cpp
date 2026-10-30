// dev32: per-service protection keys and primitives.  See include/xtp/xtp_security.hpp.
// Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).
#include "xtp/xtp_security.hpp"
#include "xtp/xtp_service.hpp"
#include <openssl/core_names.h>
#include <openssl/crypto.h>
#include <openssl/evp.h>
#include <openssl/kdf.h>
#include <openssl/rand.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>
#include <cerrno>
#include <algorithm>
#include <chrono>
#include <cstring>
#include <sstream>
#include <stdexcept>
#include <string_view>
#include <unordered_map>
#include <unordered_set>

namespace xtp {

const char* protection_name(Protection p){
    switch(p){case Protection::None:return "none";case Protection::Authenticate:return "authenticate";case Protection::Encrypt:return "encrypt";}
    return "none";
}
Protection parse_protection(const std::string& t){
    if(t=="none")return Protection::None;
    if(t=="auth"||t=="authenticate")return Protection::Authenticate;
    if(t=="encrypt")return Protection::Encrypt;
    throw std::runtime_error("unknown XTP protection: "+t+" (none, authenticate or encrypt)");
}
const char* suite_name(CipherSuite s){return s==CipherSuite::ChaCha20Poly1305?"chacha20poly1305":"aes256gcm";}
CipherSuite parse_suite(const std::string& t){
    if(t=="aes256gcm"||t=="AES256GCM")return CipherSuite::Aes256Gcm;
    if(t=="chacha20poly1305"||t=="CHACHA20POLY1305")return CipherSuite::ChaCha20Poly1305;
    throw std::runtime_error("unknown XTP cipher suite: "+t+" (aes256gcm or chacha20poly1305)");
}

ServiceKey::~ServiceKey(){OPENSSL_cleanse(secret.data(),secret.size());}

namespace {
bool valid_now(const ServiceKey&k,int64_t now){
    if(k.not_before_ms&&now<k.not_before_ms)return false;
    if(k.not_after_ms&&now>=k.not_after_ms)return false;
    return true;
}
void wipe(std::string&s){if(!s.empty())OPENSSL_cleanse(&s[0],s.size());}
// Strict hex: exactly want*2 digits 0-9, a-f, A-F.  Nothing else is accepted.
void from_hex(std::string_view h,uint8_t*out,size_t want,const char*what){
    if(h.size()!=want*2)throw std::runtime_error(std::string(what)+" must be "+std::to_string(want*2)+" hex digits");
    auto nib=[&](char c)->int{if(c>='0'&&c<='9')return c-'0';if(c>='a'&&c<='f')return c-'a'+10;if(c>='A'&&c<='F')return c-'A'+10;throw std::runtime_error(std::string(what)+" is not hex");};
    for(size_t i=0;i<want;++i)out[i]=uint8_t(nib(h[2*i])*16+nib(h[2*i+1]));
}
int64_t parse_ms(const std::string&t,const char*what){
    if(t.empty()||t.find_first_not_of("0123456789")!=std::string::npos||t.size()>15)throw std::runtime_error(std::string(what)+" must be Unix milliseconds (digits only)");
    return std::stoll(t);
}
uint8_t rank(Protection p){return uint8_t(p);}
}

// Fields are taken as views of the caller's line, so the secret's hex is
// never copied into a temporary (review Q6); the caller wipes its own line.
ServiceKey parse_key_line(const std::string&line,const std::string&source){
    std::vector<std::string_view> f;
    for(size_t i=0;i<line.size();){
        while(i<line.size()&&(line[i]==' '||line[i]=='\t'||line[i]=='\r'))++i;
        if(i>=line.size())break;
        if(line[i]=='\n')throw std::runtime_error("a key line must not contain a newline");
        size_t j=i;while(j<line.size()&&line[j]!=' '&&line[j]!='\t'&&line[j]!='\r'&&line[j]!='\n')++j;
        f.emplace_back(line.data()+i,j-i);i=j;
    }
    if(f.size()<5)throw std::runtime_error("needs at least service, key id, protection, suite and secret");
    if(f.size()>9)throw std::runtime_error("too many fields (at most 9)");
    ServiceKey k;k.service=std::string(f[0]);k.source=source;
    if(!valid_service_name(k.service))throw std::runtime_error("invalid named service");
    uint8_t id[8];from_hex(f[1],id,8,"key id");for(uint8_t b:id)k.key_id=(k.key_id<<8)|b;
    k.protection=parse_protection(std::string(f[2]));k.suite=parse_suite(std::string(f[3]));
    from_hex(f[4],k.secret.data(),32,"secret");
    if(f.size()>5&&f[5]!="-"){
        k.principal=std::string(f[5]);
        for(unsigned char c:k.principal)if(c<=0x20||c==0x7f)throw std::runtime_error("invalid principal");
    }
    if(f.size()>6)k.not_before_ms=parse_ms(std::string(f[6]),"not_before");
    if(f.size()>7)k.not_after_ms=parse_ms(std::string(f[7]),"not_after");
    if(f.size()>8){if(f[8]=="active")k.active=true;else if(f[8]=="retiring")k.active=false;else throw std::runtime_error("state must be active or retiring");}
    if(k.key_id==0)throw std::runtime_error("key id must be non-zero");
    if(k.protection==Protection::None)throw std::runtime_error("a key's protection must be authenticate or encrypt");
    if(k.not_after_ms&&k.not_after_ms<=k.not_before_ms)throw std::runtime_error("not_after must be later than not_before");
    return k;
}

KeyTable& KeyTable::global(){static KeyTable t;return t;}

void KeyTable::check_locked(const ServiceKey&k,const std::string&replacing) const{
    if(k.key_id==0)throw std::runtime_error("XTP key id must be non-zero");
    if(k.service.empty())throw std::runtime_error("XTP key needs a named service");
    if(k.protection==Protection::None)throw std::runtime_error("XTP key "+std::to_string(k.key_id)+": protection must be authenticate or encrypt");
    for(auto&x:keys_)if(x.key_id==k.key_id&&x.service!=k.service&&x.source!=replacing)
        throw std::runtime_error("XTP key id "+std::to_string(k.key_id)+" already belongs to service "+x.service);
}
void KeyTable::raise_locked(const std::string&service,Protection p){
    for(auto&sp:profiles_)if(sp.first==service){if(rank(p)>rank(sp.second))sp.second=p;return;}
    if(p!=Protection::None)profiles_.emplace_back(service,p);
}
// dev36 (review 3): the same id, service and secret keep their serial; any
// other change of the secret under an id gives a new one, which ends the
// contexts opened under the old secret as a revocation would.
// dev37 (second review 4): so does any change of who holds the key or how it
// is used (principal, protection, suite).  Its state (active or retiring) and
// validity times are not part of it: those are checked as they are.
namespace {
bool same_key(const ServiceKey&a,const ServiceKey&b){
    return a.key_id==b.key_id&&a.service==b.service&&a.principal==b.principal&&a.protection==b.protection&&a.suite==b.suite&&
           CRYPTO_memcmp(a.secret.data(),b.secret.data(),32)==0;
}
}
void KeyTable::serial_locked(ServiceKey&k){
    for(auto&x:keys_)if(same_key(x,k)){k.serial=x.serial;return;}
    k.serial=++next_serial_;
}
void KeyTable::install(const ServiceKey&key){
    std::lock_guard<std::mutex> g(m_);
    check_locked(key,std::string());
    ServiceKey k=key;serial_locked(k);
    raise_locked(k.service,k.protection);
    for(auto&x:keys_)if(x.key_id==k.key_id){x=k;return;}
    keys_.push_back(k);
}
size_t KeyTable::replace_source(const std::string&src,const std::vector<ServiceKey>&in){
    // O(n) with hash sets (review Q7): the table lock is held only briefly
    std::unordered_set<uint64_t> ids;ids.reserve(in.size()*2+1);
    std::lock_guard<std::mutex> g(m_);
    std::unordered_map<uint64_t,const ServiceKey*> held;held.reserve(keys_.size()*2+1);
    for(auto&x:keys_)held[x.key_id]=&x;
    // check everything before changing anything
    for(auto&k:in){
        if(k.source!=src)throw std::runtime_error("XTP key "+std::to_string(k.key_id)+" is from source "+k.source+", not "+src);
        if(k.key_id==0)throw std::runtime_error("XTP key id must be non-zero");
        if(k.service.empty())throw std::runtime_error("XTP key needs a named service");
        if(k.protection==Protection::None)throw std::runtime_error("XTP key "+std::to_string(k.key_id)+": protection must be authenticate or encrypt");
        if(!ids.insert(k.key_id).second)throw std::runtime_error("XTP key id "+std::to_string(k.key_id)+" appears twice");
        auto h=held.find(k.key_id);
        if(h!=held.end()&&h->second->service!=k.service&&h->second->source!=src)throw std::runtime_error("XTP key id "+std::to_string(k.key_id)+" already belongs to service "+h->second->service);
    }
    // one step: drop this source's keys and any same-service key ids it takes over
    std::vector<ServiceKey> next;next.reserve(keys_.size()+in.size());
    for(auto&x:keys_)if(x.source!=src&&!ids.count(x.key_id))next.push_back(x);
    for(auto&k:in){
        next.push_back(k);auto&n=next.back();
        // the serial, by the same hash lookup (O(1) per key, review Q7)
        auto h=held.find(k.key_id);
        if(h!=held.end()&&same_key(*h->second,k))n.serial=h->second->serial;
        else n.serial=++next_serial_;
        raise_locked(k.service,k.protection);
    }
    keys_.swap(next);   // the old vector's keys are wiped by ~ServiceKey
    return in.size();
}
size_t KeyTable::replace_source_text(const std::string&src,const std::string&text){
    std::vector<ServiceKey> keys;size_t lineno=0;std::string line;
    struct Wipe{std::string&l;~Wipe(){wipe(l);}} guard{line};
    line.reserve(512);   // one buffer, wiped after each line, so no secret is left in a freed block
    for(size_t pos=0;pos<text.size();){
        size_t end=text.find('\n',pos);if(end==std::string::npos)end=text.size();
        ++lineno;wipe(line);line.assign(text,pos,end-pos);pos=end+1;
        const auto first=line.find_first_not_of(" \t\r");
        if(first==std::string::npos||line[first]=='#')continue;
        try{keys.push_back(parse_key_line(line,src));}
        catch(const std::exception&e){throw std::runtime_error("line "+std::to_string(lineno)+": "+e.what());}
    }
    return replace_source(src,keys);
}
bool KeyTable::revoke(uint64_t id){
    std::lock_guard<std::mutex> g(m_);
    for(auto it=keys_.begin();it!=keys_.end();++it)if(it->key_id==id){keys_.erase(it);return true;}
    return false;
}
size_t KeyTable::clear_source(const std::string&src){
    std::lock_guard<std::mutex> g(m_);size_t n=0;
    for(auto it=keys_.begin();it!=keys_.end();){if(it->source==src){it=keys_.erase(it);++n;}else ++it;}
    return n;
}
size_t KeyTable::clear(){
    std::lock_guard<std::mutex> g(m_);size_t n=keys_.size();
    keys_.clear();profiles_.clear();return n;
}
// The key file: one key per line in the parse_key_line format.  Opened without
// following a symbolic link; it must be a regular file, owned by this user,
// with no group or other permissions (review ML2: checked on the open file).
size_t KeyTable::load_file(const std::string&path){
    const int fd=::open(path.c_str(),O_RDONLY|O_NOFOLLOW|O_CLOEXEC|O_NOCTTY);
    if(fd<0){
        if(errno==ELOOP)throw std::runtime_error("XTP key file "+path+" is a symbolic link; give the real path");
        throw std::runtime_error("XTP key file cannot be opened: "+path+" ("+std::strerror(errno)+")");
    }
    struct Fd{int fd;~Fd(){::close(fd);}} guard{fd};
    struct stat st{};
    if(::fstat(fd,&st)!=0)throw std::runtime_error("XTP key file cannot be examined: "+path);
    if(!S_ISREG(st.st_mode))throw std::runtime_error("XTP key file "+path+" is not a regular file");
    if(st.st_uid!=::geteuid())throw std::runtime_error("XTP key file "+path+" is owned by uid "+std::to_string(st.st_uid)+", not by this process's user");
    if(st.st_mode&077)throw std::runtime_error("XTP key file "+path+" is readable or writable by group or others; chmod 600 it");
    if(st.st_size>4*1024*1024)throw std::runtime_error("XTP key file "+path+" is larger than 4 MB");
    std::string text(size_t(st.st_size),'\0');size_t got=0;
    while(got<text.size()){const ssize_t n=::read(fd,&text[got],text.size()-got);if(n<0&&errno==EINTR)continue;if(n<=0)break;got+=size_t(n);}
    text.resize(got);
    struct Wipe{std::string&t;~Wipe(){wipe(t);}} wt{text};
    try{return replace_source_text("file",text);}
    catch(const std::exception&e){throw std::runtime_error("XTP key file "+path+" "+e.what());}
}
std::optional<ServiceKey> KeyTable::for_open(const std::string&service,const std::string&principal) const{
    std::lock_guard<std::mutex> g(m_);const int64_t now=security::now_ms();
    const ServiceKey*best=nullptr;
    for(auto&k:keys_){
        if(k.service!=service||!k.active||!valid_now(k,now))continue;
        // dev35 (gateway mode B): a key held for a principal (a client) is
        // used only by an opener that names that principal, and an opener
        // naming a principal uses only that principal's keys.
        if(k.principal!=principal)continue;
        if(!best||k.not_before_ms>best->not_before_ms)best=&k;
    }
    if(!best)return std::nullopt;
    return *best;
}
std::optional<ServiceKey> KeyTable::by_id(uint64_t id) const{
    std::lock_guard<std::mutex> g(m_);const int64_t now=security::now_ms();
    for(auto&k:keys_)if(k.key_id==id&&valid_now(k,now))return k;
    return std::nullopt;
}
bool KeyTable::valid(uint64_t id,const std::string&service,uint64_t serial) const{
    std::lock_guard<std::mutex> g(m_);const int64_t now=security::now_ms();
    for(auto&k:keys_)if(k.key_id==id)return k.service==service&&valid_now(k,now)&&(serial==0||k.serial==serial);
    return false;
}
Protection KeyTable::required(const std::string&service) const{
    std::lock_guard<std::mutex> g(m_);Protection p=Protection::None;const int64_t now=security::now_ms();
    for(auto&sp:profiles_)if(sp.first==service){p=sp.second;break;}
    for(auto&k:keys_)if(k.service==service&&valid_now(k,now)&&rank(k.protection)>rank(p))p=k.protection;
    return p;
}
void KeyTable::require(const std::string&service,Protection p){
    if(service.empty())throw std::runtime_error("XTP require needs a named service");
    std::lock_guard<std::mutex> g(m_);raise_locked(service,p);
}
void KeyTable::forget_profile(const std::string&service){
    std::lock_guard<std::mutex> g(m_);
    profiles_.erase(std::remove_if(profiles_.begin(),profiles_.end(),[&](const auto&sp){return sp.first==service;}),profiles_.end());
    const int64_t now=security::now_ms();
    for(auto&k:keys_)if(k.service==service&&valid_now(k,now))raise_locked(service,k.protection);
}
std::vector<std::pair<std::string,Protection>> KeyTable::profiles() const{std::lock_guard<std::mutex> g(m_);return profiles_;}
std::vector<ServiceKeyInfo> KeyTable::list() const{
    std::lock_guard<std::mutex> g(m_);std::vector<ServiceKeyInfo> v;
    for(auto&k:keys_){ServiceKeyInfo i;i.service=k.service;i.principal=k.principal;i.source=k.source;i.key_id=k.key_id;i.protection=k.protection;i.suite=k.suite;i.not_before_ms=k.not_before_ms;i.not_after_ms=k.not_after_ms;i.active=k.active;i.serial=k.serial;v.push_back(i);}
    return v;
}

namespace security {
int64_t now_ms(){return std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::system_clock::now().time_since_epoch()).count();}
std::vector<uint8_t> random_bytes(size_t n){
    std::vector<uint8_t> v(n);
    if(n&&RAND_bytes(v.data(),int(n))!=1)throw std::runtime_error("XTP: the system random source failed");
    return v;
}
std::vector<uint8_t> hkdf_sha256(const uint8_t*secret,size_t secret_len,const std::vector<uint8_t>&salt,const std::vector<uint8_t>&info,size_t out_len){
    EVP_KDF*kdf=EVP_KDF_fetch(nullptr,"HKDF",nullptr);if(!kdf)throw std::runtime_error("XTP: HKDF unavailable in libcrypto");
    EVP_KDF_CTX*ctx=EVP_KDF_CTX_new(kdf);EVP_KDF_free(kdf);if(!ctx)throw std::runtime_error("XTP: HKDF context");
    char digest[]="SHA256";
    OSSL_PARAM p[5];size_t i=0;
    p[i++]=OSSL_PARAM_construct_utf8_string(OSSL_KDF_PARAM_DIGEST,digest,0);
    p[i++]=OSSL_PARAM_construct_octet_string(OSSL_KDF_PARAM_KEY,const_cast<uint8_t*>(secret),secret_len);
    p[i++]=OSSL_PARAM_construct_octet_string(OSSL_KDF_PARAM_SALT,const_cast<uint8_t*>(salt.data()),salt.size());
    p[i++]=OSSL_PARAM_construct_octet_string(OSSL_KDF_PARAM_INFO,const_cast<uint8_t*>(info.data()),info.size());
    p[i++]=OSSL_PARAM_construct_end();
    std::vector<uint8_t> out(out_len);
    const int ok=EVP_KDF_derive(ctx,out.data(),out_len,p);EVP_KDF_CTX_free(ctx);
    if(ok!=1)throw std::runtime_error("XTP: HKDF derivation failed");
    return out;
}
namespace {
const EVP_CIPHER* cipher_for(CipherSuite s){return s==CipherSuite::ChaCha20Poly1305?EVP_chacha20_poly1305():EVP_aes_256_gcm();}
struct Ctx{EVP_CIPHER_CTX*c;Ctx():c(EVP_CIPHER_CTX_new()){if(!c)throw std::runtime_error("XTP: cipher context");}~Ctx(){EVP_CIPHER_CTX_free(c);}};
}
void seal(CipherSuite s,const uint8_t key[32],const uint8_t nonce[12],const std::vector<uint8_t>&aad,const uint8_t*plain,size_t n,uint8_t*cipher_out,uint8_t tag_out[16]){
    Ctx x;int len=0;
    if(EVP_EncryptInit_ex(x.c,cipher_for(s),nullptr,nullptr,nullptr)!=1||EVP_CIPHER_CTX_ctrl(x.c,EVP_CTRL_AEAD_SET_IVLEN,12,nullptr)!=1||EVP_EncryptInit_ex(x.c,nullptr,nullptr,key,nonce)!=1)throw std::runtime_error("XTP: AEAD init");
    if(!aad.empty()&&EVP_EncryptUpdate(x.c,nullptr,&len,aad.data(),int(aad.size()))!=1)throw std::runtime_error("XTP: AEAD aad");
    if(n&&EVP_EncryptUpdate(x.c,cipher_out,&len,plain,int(n))!=1)throw std::runtime_error("XTP: AEAD encrypt");
    if(EVP_EncryptFinal_ex(x.c,cipher_out+n,&len)!=1)throw std::runtime_error("XTP: AEAD final");
    if(EVP_CIPHER_CTX_ctrl(x.c,EVP_CTRL_AEAD_GET_TAG,16,tag_out)!=1)throw std::runtime_error("XTP: AEAD tag");
}
bool open(CipherSuite s,const uint8_t key[32],const uint8_t nonce[12],const std::vector<uint8_t>&aad,const uint8_t*cipher,size_t n,const uint8_t tag[16],uint8_t*plain_out){
    Ctx x;int len=0;
    if(EVP_DecryptInit_ex(x.c,cipher_for(s),nullptr,nullptr,nullptr)!=1||EVP_CIPHER_CTX_ctrl(x.c,EVP_CTRL_AEAD_SET_IVLEN,12,nullptr)!=1||EVP_DecryptInit_ex(x.c,nullptr,nullptr,key,nonce)!=1)return false;
    if(!aad.empty()&&EVP_DecryptUpdate(x.c,nullptr,&len,aad.data(),int(aad.size()))!=1)return false;
    if(n&&EVP_DecryptUpdate(x.c,plain_out,&len,cipher,int(n))!=1)return false;
    if(EVP_CIPHER_CTX_ctrl(x.c,EVP_CTRL_AEAD_SET_TAG,16,const_cast<uint8_t*>(tag))!=1)return false;
    return EVP_DecryptFinal_ex(x.c,plain_out+n,&len)==1;
}
} // namespace security
} // namespace xtp
