// Architecture: Tom Dyer. Coding: ChatGPT. Linux POSIX read-only provider.
#include <oorexxapi.h>
#include <sys/stat.h>
#include <sys/statvfs.h>
#include <fcntl.h>
#include <unistd.h>
#include <cerrno>
#include <cstring>
#include <string>
#include <cstdint>
#include <dirent.h>
#include <map>
#include <set>
#include <mutex>
#include <sys/syscall.h>
#include <linux/openat2.h>
#include <sys/random.h>
#include <cstdio>
#include <sstream>
#include <vector>
#include <poll.h>
#include <signal.h>
#include <chrono>
#include <sys/vfs.h>
#include <linux/magic.h>
#include <sys/inotify.h>
#include <sys/epoll.h>
#include <sys/timerfd.h>
#include <sys/eventfd.h>
#include <memory>
#include <algorithm>
#include <cstddef>
#include <sys/socket.h>
#include <netinet/in.h>
#include <linux/netlink.h>
#include <linux/rtnetlink.h>
#include <linux/sock_diag.h>
#include <linux/inet_diag.h>
#include <linux/tcp.h>
struct Fd { int n; explicit Fd(int v):n(v){} ~Fd(){if(n>=0){int saved=errno;close(n);errno=saved;}} Fd(const Fd&)=delete; Fd& operator=(const Fd&)=delete; };
// Traverse one component at a time relative to an open directory; no links.
// Reject ambiguous paths, including dot-dot, rather than normalize them.
static int walk(int base, const std::string& path) {
    Fd cur(fcntl(base,F_DUPFD_CLOEXEC,0)); if(cur.n<0)return -1;
    if(path.empty() || path==".")return fcntl(cur.n,F_DUPFD_CLOEXEC,0);
    size_t p=0;
    while(p<path.size()) {
        size_t end=path.find('/',p); bool last=end==std::string::npos;
        std::string part=path.substr(p,last?std::string::npos:end-p);
        if(part.empty()||part=="."||part==".."||part.find('\0')!=std::string::npos){errno=EINVAL;return -1;}
        int flags=O_PATH|O_NOFOLLOW|O_CLOEXEC; if(!last)flags|=O_DIRECTORY;
        Fd next(openat(cur.n,part.c_str(),flags)); if(next.n<0)return -1;
        struct stat st; if(fstat(next.n,&st)<0)return -1;
        if(S_ISLNK(st.st_mode)){errno=ELOOP;return -1;}
        if(last)return fcntl(next.n,F_DUPFD_CLOEXEC,0);
        close(cur.n);cur.n=next.n;next.n=-1;p=end+1;
        if(p==path.size()){errno=EINVAL;return -1;}
    } errno=EINVAL;return -1;
}
static int target(const std::string& root,const std::string& rel){
    if(root.empty()||root[0]!='/'||root.find('\0')!=std::string::npos||rel.empty()||rel[0]=='/'||rel.find('\0')!=std::string::npos){errno=EINVAL;return -1;}
    Fd slash(open("/",O_PATH|O_DIRECTORY|O_CLOEXEC)); if(slash.n<0)return -1;
    Fd r(walk(slash.n,root.substr(1)));if(r.n<0)return -1;
    struct stat st;if(fstat(r.n,&st)<0)return -1;if(!S_ISDIR(st.st_mode)){errno=ENOTDIR;return -1;}
    return walk(r.n,rel);
}
static void put(RexxCallContext* c,RexxDirectoryObject d,const char* k,uint64_t v){c->DirectoryPut(d,c->UnsignedInt64ToObject(v),k);}
static void signedPut(RexxCallContext* c,RexxDirectoryObject d,const char* k,int64_t v){c->DirectoryPut(d,c->Int64ToObject(v),k);}
static RexxDirectoryObject result(RexxCallContext* c,int e){auto d=c->NewDirectory();put(c,d,"OK",e==0);put(c,d,"ERRNO",e);c->DirectoryPut(d,c->NewStringFromAsciiz(e?strerror(e):""),"ERROR");return d;}
static RexxDirectoryObject registryFull(RexxCallContext* c,const char* message){
    auto d=result(c,0);put(c,d,"OK",0);c->DirectoryPut(d,c->NewStringFromAsciiz(message),"ERROR");return d;
}
static RexxObjectPtr metadata(RexxCallContext* context,int fd){
    struct stat st;if(fstat(fd,&st)<0)return result(context,errno);auto d=result(context,0);
    put(context,d,"DEVICE",st.st_dev);put(context,d,"INODE",st.st_ino);put(context,d,"MODE",st.st_mode&07777);char mode[6];std::snprintf(mode,sizeof(mode),"%04o",static_cast<unsigned>(st.st_mode&07777));context->DirectoryPut(d,context->NewStringFromAsciiz(mode),"MODE_OCTAL");put(context,d,"UID",st.st_uid);put(context,d,"GID",st.st_gid);put(context,d,"LINKS",st.st_nlink);signedPut(context,d,"SIZE",st.st_size);signedPut(context,d,"MTIME_SEC",st.st_mtim.tv_sec);put(context,d,"MTIME_NS",st.st_mtim.tv_nsec);signedPut(context,d,"CTIME_SEC",st.st_ctim.tv_sec);put(context,d,"CTIME_NS",st.st_ctim.tv_nsec);
    const char* k=S_ISREG(st.st_mode)?"file":S_ISDIR(st.st_mode)?"folder":S_ISFIFO(st.st_mode)?"fifo":S_ISSOCK(st.st_mode)?"socket":S_ISCHR(st.st_mode)?"character":S_ISBLK(st.st_mode)?"block":"other";context->DirectoryPut(d,context->NewStringFromAsciiz(k),"KIND");return d;
}
RexxRoutine2(RexxObjectPtr, PosixNativeStat, RexxStringObject, root, RexxStringObject, rel){
    Fd fd(target(std::string(context->StringData(root),context->StringLength(root)),std::string(context->StringData(rel),context->StringLength(rel))));if(fd.n<0)return result(context,errno);return metadata(context,fd.n);
}
static RexxObjectPtr capacity(RexxCallContext* c,int fd){
    struct statvfs s;if(fstatvfs(fd,&s)<0)return result(c,errno);auto d=result(c,0);put(c,d,"FRAGMENT_BYTES",s.f_frsize);put(c,d,"BLOCKS",s.f_blocks);put(c,d,"FREE_BLOCKS",s.f_bfree);put(c,d,"AVAILABLE_BLOCKS",s.f_bavail);put(c,d,"INODES",s.f_files);put(c,d,"FREE_INODES",s.f_ffree);return d;
}
RexxRoutine2(RexxObjectPtr,PosixNativeCapacity,RexxStringObject,root,RexxStringObject,rel){
    Fd fd(target(std::string(context->StringData(root),context->StringLength(root)),std::string(context->StringData(rel),context->StringLength(rel))));if(fd.n<0)return result(context,errno);return capacity(context,fd.n);
}
RexxRoutine0(int64_t,PosixNativePageSize){(void)context;return sysconf(_SC_PAGESIZE);}
// Handles are process-local trusted capabilities, never OS fd numbers.
// Explicit release plus Rexx UNINIT; bounded registry, random opaque tokens.
struct Scan { std::string root; DIR* dir; bool done; };
static std::mutex guard;
static std::map<std::string,int> roots;
static std::map<std::string,Scan> scans;
struct Reader { std::string root; int fd; };
static std::map<std::string,Reader> readers;
static std::map<std::string,int> processes;
struct Watch { std::string root; int fd; std::vector<char> pending; size_t offset; bool lost; bool invalid; };
static std::map<std::string,Watch> watches;
static std::map<std::string,int> timers;
struct MuxRegistration { std::string key; int fd; const char* kind; };
struct PersistentMux {
    int ep=-1,wake=-1; uint64_t next=1; bool waiting=false,closed=false,explicitWake=false,changed=false;
    std::map<uint64_t,MuxRegistration> regs;
    ~PersistentMux(){for(auto& r:regs)if(r.second.fd>=0)close(r.second.fd);if(ep>=0)close(ep);if(wake>=0)close(wake);}
};
static std::map<std::string,std::shared_ptr<PersistentMux>> muxes;
// eventfd saturation means it is already readable. Called under guard.
static void notifyMux(PersistentMux& m){uint64_t one=1;ssize_t n;do{n=write(m.wake,&one,sizeof(one));}while(n<0&&errno==EINTR);}
static void notifySourceClosed(const std::string& key){for(auto& pair:muxes){auto& m=*pair.second;for(auto& r:m.regs)if(r.second.key==key){if(r.second.fd>=0){epoll_ctl(m.ep,EPOLL_CTL_DEL,r.second.fd,nullptr);close(r.second.fd);r.second.fd=-1;}if(m.waiting)notifyMux(m);break;}}}

// Called under guard. Fail closed if OS entropy cannot be obtained.
static std::string token(){
    for(int attempt=0;attempt<8;++attempt){
        unsigned char bytes[16];size_t got=0;
        while(got<sizeof(bytes)){ssize_t n=getrandom(bytes+got,sizeof(bytes)-got,0);if(n<0&&errno==EINTR)continue;if(n<=0){if(!n)errno=EIO;return {}; }got+=static_cast<size_t>(n);}
        static const char hex[]="0123456789abcdef";std::string t;for(auto b:bytes){t+=hex[b>>4];t+=hex[b&15];}
        if(!roots.count(t)&&!scans.count(t)&&!readers.count(t)&&!processes.count(t)&&!watches.count(t)&&!timers.count(t)&&!muxes.count(t))return t;
    }errno=EAGAIN;return {};
}
static void putToken(RexxCallContext* c,RexxDirectoryObject d,const std::string& t){c->DirectoryPut(d,c->NewString(t.data(),t.size()),"HANDLE");}
static std::string str(RexxCallContext* c,RexxStringObject x){return std::string(c->StringData(x),c->StringLength(x));}
static bool validRel(const std::string& p){
    if(p==".")return true;
    if(p.empty()||p[0]=='/'||p.back()=='/'||p.find('\0')!=std::string::npos)return false;
    size_t i=0;while(i<p.size()){auto j=p.find('/',i);auto v=p.substr(i,j==std::string::npos?j:j-i);if(v.empty()||v=="."||v=="..")return false;if(j==std::string::npos)break;i=j+1;}return true;
}
static int rooted(int fd,const std::string& path,int flags){
    if(!validRel(path)){errno=EINVAL;return -1;}
    struct open_how h={};h.flags=flags|O_CLOEXEC;h.resolve=RESOLVE_BENEATH|RESOLVE_NO_SYMLINKS|RESOLVE_NO_MAGICLINKS;
    // No weaker fallback on kernels without openat2.
    return static_cast<int>(syscall(SYS_openat2,fd,path.c_str(),&h,sizeof(h)));
}
RexxRoutine1(RexxObjectPtr,PosixRootOpen,RexxStringObject,path){
    auto p=str(context,path);if(p.empty()||p[0]!='/'||p.find('\0')!=std::string::npos)return result(context,EINVAL);
    Fd slash(open("/",O_PATH|O_DIRECTORY|O_CLOEXEC));if(slash.n<0)return result(context,errno);
    Fd fd(rooted(slash.n,p=="/"?".":p.substr(1),O_PATH|O_DIRECTORY));if(fd.n<0)return result(context,errno);
    Fd probe(rooted(fd.n,".",O_PATH|O_DIRECTORY));if(probe.n<0)return result(context,errno);
    std::lock_guard<std::mutex> l(guard);if(roots.size()>=128)return registryFull(context,"ROOT_REGISTRY_FULL (128 open roots)");
    auto id=token();if(id.empty())return result(context,errno);roots.emplace(id,fd.n);fd.n=-1;auto d=result(context,0);putToken(context,d,id);return d;
}
RexxRoutine1(RexxObjectPtr,PosixRootClose,RexxStringObject,tokenArg){
    std::lock_guard<std::mutex> l(guard);auto id=str(context,tokenArg);auto r=roots.find(id);if(r==roots.end())return result(context,EBADF);
    for(auto i=scans.begin();i!=scans.end();){if(i->second.root==id){closedir(i->second.dir);i=scans.erase(i);}else ++i;}
    for(auto i=readers.begin();i!=readers.end();){if(i->second.root==id){close(i->second.fd);i=readers.erase(i);}else ++i;}
    for(auto i=watches.begin();i!=watches.end();){if(i->second.root==id){notifySourceClosed(i->first);close(i->second.fd);i=watches.erase(i);}else ++i;}
    close(r->second);roots.erase(r);return result(context,0);
}
RexxRoutine2(RexxObjectPtr,PosixRootStat,RexxStringObject,tokenArg,RexxStringObject,path){
    std::lock_guard<std::mutex> l(guard);auto id=str(context,tokenArg);auto r=roots.find(id);if(r==roots.end())return result(context,EBADF);
    Fd fd(rooted(r->second,str(context,path),O_PATH));if(fd.n<0)return result(context,errno);return metadata(context,fd.n);
}
RexxRoutine2(RexxObjectPtr,PosixRootCapacity,RexxStringObject,tokenArg,RexxStringObject,path){
    // Duplicate the pinned root while holding the registry lock, then perform I/O outside it.
    int copy;
    {std::lock_guard<std::mutex> l(guard);auto r=roots.find(str(context,tokenArg));if(r==roots.end())return result(context,EBADF);copy=fcntl(r->second,F_DUPFD_CLOEXEC,0);}
    Fd base(copy);if(base.n<0)return result(context,errno);
    Fd fd(rooted(base.n,str(context,path),O_PATH));if(fd.n<0)return result(context,errno);return capacity(context,fd.n);
}
RexxRoutine2(RexxObjectPtr,PosixScanOpen,RexxStringObject,tokenArg,RexxStringObject,path){
    std::lock_guard<std::mutex> l(guard);auto id=str(context,tokenArg);auto r=roots.find(id);if(r==roots.end())return result(context,EBADF);
    if(scans.size()>=128)return registryFull(context,"CURSOR_REGISTRY_FULL (128 open cursors)");
    Fd fd(rooted(r->second,str(context,path),O_RDONLY|O_DIRECTORY));if(fd.n<0)return result(context,errno);
    auto key=token();if(key.empty())return result(context,errno);DIR* dir=fdopendir(fd.n);if(!dir)return result(context,errno);fd.n=-1;scans.emplace(key,Scan{id,dir,false});auto d=result(context,0);putToken(context,d,key);return d;
}
RexxRoutine2(RexxObjectPtr,PosixScanNext,RexxStringObject,tokenArg,uint32_t,limit){
    if(limit<1||limit>1024)return result(context,EINVAL);
    std::lock_guard<std::mutex> l(guard);auto id=str(context,tokenArg);auto i=scans.find(id);if(i==scans.end())return result(context,EBADF);
    auto& s=i->second;auto a=context->NewArray(0);uint32_t count=0;
    while(!s.done&&count<limit){errno=0;auto e=readdir(s.dir);if(!e){if(errno){int err=errno;closedir(s.dir);scans.erase(i);return result(context,err);}s.done=true;break;}
        if(strcmp(e->d_name,".")==0||strcmp(e->d_name,"..")==0)continue;
        auto row=context->NewDirectory();context->DirectoryPut(row,context->NewStringFromAsciiz(e->d_name),"NAME");put(context,row,"INODE_HINT",e->d_ino);put(context,row,"TYPE_HINT",e->d_type);context->ArrayAppend(a,row);++count;
    }
    auto d=result(context,0);context->DirectoryPut(d,a,"ENTRIES");put(context,d,"DONE",s.done);return d;
}
RexxRoutine1(RexxObjectPtr,PosixScanClose,RexxStringObject,tokenArg){
    std::lock_guard<std::mutex> l(guard);auto id=str(context,tokenArg);auto i=scans.find(id);if(i==scans.end())return result(context,EBADF);closedir(i->second.dir);scans.erase(i);return result(context,0);
}
// Open only an already identified regular file. Never open a device/FIFO
// for data, even if the caller races a pathname replacement.
static int regularData(int pathfd){
    struct stat a,b;if(fstat(pathfd,&a)<0)return -1;
    if(!S_ISREG(a.st_mode)){errno=EINVAL;return -1;}
    std::string name="/proc/self/fd/"+std::to_string(pathfd);
    Fd fd(open(name.c_str(),O_RDONLY|O_CLOEXEC|O_NONBLOCK));if(fd.n<0)return -1;
    if(fstat(fd.n,&b)<0)return -1;
    if(a.st_dev!=b.st_dev||a.st_ino!=b.st_ino||!S_ISREG(b.st_mode)){errno=ESTALE;return -1;}
    int n=fd.n;fd.n=-1;return n;
}
static bool validRead(uint64_t offset,uint32_t limit){return limit>0&&limit<=1048576&&offset<=static_cast<uint64_t>(INT64_MAX)-limit;}
static RexxObjectPtr readData(RexxCallContext* context,int fd,uint64_t offset,uint32_t limit){
    std::string bytes(limit,'\0');size_t got=0;
    while(got<limit){ssize_t n=pread(fd,&bytes[got],limit-got,static_cast<off_t>(offset+got));if(n<0&&errno==EINTR)continue;if(n<0)return result(context,errno);if(!n)break;got+=static_cast<size_t>(n);}
    auto d=result(context,0);context->DirectoryPut(d,context->NewString(bytes.data(),got),"DATA");put(context,d,"BYTES",got);put(context,d,"NEXT_OFFSET",offset+got);put(context,d,"EOF",got<limit);return d;
}
RexxRoutine4(RexxObjectPtr,PosixRootRead,RexxStringObject,tokenArg,RexxStringObject,path,uint64_t,offset,uint32_t,limit){
    if(!validRead(offset,limit))return result(context,EINVAL);
    Fd base(-1);{
        std::lock_guard<std::mutex> l(guard);auto r=roots.find(str(context,tokenArg));if(r==roots.end())return result(context,EBADF);
        base.n=fcntl(r->second,F_DUPFD_CLOEXEC,0);if(base.n<0)return result(context,errno);
    }
    Fd pathfd(rooted(base.n,str(context,path),O_PATH));if(pathfd.n<0)return result(context,errno);
    Fd fd(regularData(pathfd.n));if(fd.n<0)return result(context,errno);
    return readData(context,fd.n,offset,limit);
}
RexxRoutine2(RexxObjectPtr,PosixReaderOpen,RexxStringObject,tokenArg,RexxStringObject,path){
    std::lock_guard<std::mutex> l(guard);auto id=str(context,tokenArg);auto r=roots.find(id);if(r==roots.end())return result(context,EBADF);
    if(readers.size()>=128)return registryFull(context,"READER_REGISTRY_FULL (128 open readers)");
    Fd pathfd(rooted(r->second,str(context,path),O_PATH));if(pathfd.n<0)return result(context,errno);
    Fd fd(regularData(pathfd.n));if(fd.n<0)return result(context,errno);
    auto key=token();if(key.empty())return result(context,errno);
    readers.emplace(key,Reader{id,fd.n});fd.n=-1;auto d=result(context,0);putToken(context,d,key);return d;
}
static int readerDup(RexxCallContext* context,RexxStringObject tokenArg){
    std::lock_guard<std::mutex> l(guard);auto i=readers.find(str(context,tokenArg));if(i==readers.end()){errno=EBADF;return -1;}
    return fcntl(i->second.fd,F_DUPFD_CLOEXEC,0);
}
RexxRoutine3(RexxObjectPtr,PosixReaderRead,RexxStringObject,tokenArg,uint64_t,offset,uint32_t,limit){
    if(!validRead(offset,limit))return result(context,EINVAL);
    Fd fd(readerDup(context,tokenArg));if(fd.n<0)return result(context,errno);return readData(context,fd.n,offset,limit);
}
RexxRoutine1(RexxObjectPtr,PosixReaderStat,RexxStringObject,tokenArg){
    Fd fd(readerDup(context,tokenArg));if(fd.n<0)return result(context,errno);return metadata(context,fd.n);
}
RexxRoutine1(RexxObjectPtr,PosixReaderClose,RexxStringObject,tokenArg){
    std::lock_guard<std::mutex> l(guard);auto i=readers.find(str(context,tokenArg));if(i==readers.end())return result(context,EBADF);
    close(i->second.fd);readers.erase(i);return result(context,0);
}
// Read start time from the pinned proc directory, not a reconstructed PID path.
static bool procStart(int base,std::string& start){
    Fd fd(rooted(base,"stat",O_RDONLY|O_NONBLOCK));if(fd.n<0)return false;
    char buf[8192];ssize_t n;do{n=read(fd.n,buf,sizeof(buf));}while(n<0&&errno==EINTR);if(n<=0){if(!n)errno=ESRCH;return false;}
    std::string s(buf,n);auto p=s.rfind(')');if(p==std::string::npos){errno=EIO;return false;}
    std::istringstream in(s.substr(p+1));for(int i=0;i<20;++i)if(!(in>>start)){errno=EIO;return false;}return true;
}
RexxRoutine4(RexxObjectPtr,PosixProcessList,uint32_t,pid,RexxStringObject,expected,RexxStringObject,kind,uint32_t,limit){
    auto k=str(context,kind);if(!pid||pid>2147483647||!limit||limit>1024||(k!="task"&&k!="fd"))return result(context,EINVAL);
    Fd proc(open("/proc",O_PATH|O_DIRECTORY|O_CLOEXEC|O_NOFOLLOW));if(proc.n<0)return result(context,errno);
    Fd base(rooted(proc.n,std::to_string(pid),O_PATH|O_DIRECTORY));if(base.n<0)return result(context,errno);
    std::string start;if(!procStart(base.n,start))return result(context,errno);
    if(start!=str(context,expected))return result(context,ESTALE);
    Fd folder(rooted(base.n,k,O_RDONLY|O_DIRECTORY));if(folder.n<0)return result(context,errno);
    DIR* dir=fdopendir(folder.n);if(!dir)return result(context,errno);folder.n=-1;
    auto rows=context->NewArray(0);uint32_t count=0;bool truncated=false;int err=0;
    for(;;){errno=0;auto e=readdir(dir);if(!e){err=errno;break;}
        std::string name(e->d_name);if(name.empty()||name.find_first_not_of("0123456789")!=std::string::npos)continue;
        if(count==limit){truncated=true;break;}context->ArrayAppend(rows,context->NewString(name.data(),name.size()));++count;
    }
    closedir(dir);if(err)return result(context,err);if(!procStart(base.n,start))return result(context,errno);
    if(start!=str(context,expected))return result(context,ESTALE);
    auto d=result(context,0);context->DirectoryPut(d,rows,"IDS");put(context,d,"TRUNCATED",truncated);put(context,d,"PID",pid);context->DirectoryPut(d,context->NewString(start.data(),start.size()),"START_TICKS");return d;
}

static bool readProcFile(int base,const char* name,std::string& data){
    Fd fd(rooted(base,name,O_RDONLY|O_NONBLOCK));if(fd.n<0)return false;
    char chunk[4096];constexpr size_t maxBytes=262144;
    for(;;){ssize_t n=read(fd.n,chunk,sizeof(chunk));if(n<0&&errno==EINTR)continue;if(n<0)return false;if(!n)return true;
        if(data.size()+static_cast<size_t>(n)>maxBytes){errno=EOVERFLOW;return false;}data.append(chunk,static_cast<size_t>(n));}
}
static std::string trim(const std::string& s){auto a=s.find_first_not_of(" \t\r");if(a==std::string::npos)return {};return s.substr(a,s.find_last_not_of(" \t\r")-a+1);}
static void putText(RexxCallContext* c,RexxDirectoryObject d,const char* k,const std::string& v){c->DirectoryPut(d,c->NewString(v.data(),v.size()),k);}
static bool digits(const std::string& v){return !v.empty()&&v.find_first_not_of("0123456789")==std::string::npos;}
static bool limitValue(const std::string& v){return v=="unlimited"||digits(v);}
RexxRoutine3(RexxObjectPtr,PosixProcessDetails,uint32_t,pid,RexxStringObject,expected,RexxStringObject,kind){
    auto k=str(context,kind);if(!pid||pid>2147483647||(k!="credentials"&&k!="limits"))return result(context,EINVAL);
    Fd proc(open("/proc",O_PATH|O_DIRECTORY|O_CLOEXEC|O_NOFOLLOW));if(proc.n<0)return result(context,errno);
    Fd base(rooted(proc.n,std::to_string(pid),O_PATH|O_DIRECTORY));if(base.n<0)return result(context,errno);
    std::string start;if(!procStart(base.n,start))return result(context,errno);
    if(start!=str(context,expected))return result(context,ESTALE);
    std::string data;if(!readProcFile(base.n,k=="credentials"?"status":"limits",data))return result(context,errno);
    if(!procStart(base.n,start))return result(context,errno);
    if(start!=str(context,expected))return result(context,ESTALE);
    auto d=result(context,0);put(context,d,"PID",pid);putText(context,d,"START_TICKS",start);
    std::istringstream input(data);std::string line;
    if(k=="credentials"){
        bool uid=false,gid=false,groups=false;
        while(std::getline(input,line)){
            auto sep=line.find(':');if(sep==std::string::npos)continue;auto key=line.substr(0,sep);auto value=trim(line.substr(sep+1));
            if(key=="Uid"||key=="Gid"){
                std::istringstream values(value);std::string v[4],extra;
                for(auto& x:v){if(!(values>>x)||!digits(x))return result(context,EIO);}if(values>>extra)return result(context,EIO);
                const char* names=key=="Uid"?"UID":"GID";
                const char* prefixes[]={"REAL_","EFFECTIVE_","SAVED_","FILESYSTEM_"};
                for(int i=0;i<4;++i)putText(context,d,(std::string(prefixes[i])+names).c_str(),v[i]);
                if(key=="Uid")uid=true;else gid=true;
            }else if(key=="Groups"){
                std::istringstream values(value);std::string v;auto a=context->NewArray(0);size_t count=0;
                while(values>>v){if(!digits(v))return result(context,EIO);if(count<1024)context->ArrayAppend(a,context->NewString(v.data(),v.size()));++count;}
                context->DirectoryPut(d,a,"GROUPS");put(context,d,"GROUPS_TRUNCATED",count>1024);groups=true;
            }else if(key=="CapInh"||key=="CapPrm"||key=="CapEff"||key=="CapBnd"||key=="CapAmb"){
                if(value.empty()||value.find_first_not_of("0123456789abcdefABCDEF")!=std::string::npos)return result(context,EIO);
                const char* name=key=="CapInh"?"CAP_INHERITABLE":key=="CapPrm"?"CAP_PERMITTED":key=="CapEff"?"CAP_EFFECTIVE":key=="CapBnd"?"CAP_BOUNDING":"CAP_AMBIENT";putText(context,d,name,value);
            }else if(key=="NoNewPrivs"||key=="Seccomp"){
                if(!digits(value))return result(context,EIO);
                putText(context,d,key=="NoNewPrivs"?"NO_NEW_PRIVS":"SECCOMP",value);
            }
        }
        if(!uid||!gid||!groups)return result(context,EIO);
    }else{
        if(!std::getline(input,line))return result(context,EIO);
        auto soft=line.find("Soft Limit"),hard=line.find("Hard Limit"),units=line.find("Units");
        if(soft==std::string::npos||hard==std::string::npos||units==std::string::npos||!(soft<hard&&hard<units))return result(context,EIO);
        auto a=context->NewArray(0);size_t count=0;
        while(std::getline(input,line)){
            if(trim(line).empty())continue;
            if(line.size()<units||++count>128)return result(context,EIO);
            auto name=trim(line.substr(0,soft)),sv=trim(line.substr(soft,hard-soft)),hv=trim(line.substr(hard,units-hard)),u=trim(line.substr(units));
            if(name.empty()||!limitValue(sv)||!limitValue(hv))return result(context,EIO);
            auto row=context->NewDirectory();putText(context,row,"NAME",name);putText(context,row,"SOFT",sv);putText(context,row,"HARD",hv);putText(context,row,"UNITS",u);context->ArrayAppend(a,row);
        }
        if(!count)return result(context,EIO);
        context->DirectoryPut(d,a,"LIMITS");
    }
    return d;
}

// pidfd is a kernel process reference, not a PID to be looked up again.
// Require a trusted procfs mounted for the calling PID namespace.
RexxRoutine2(RexxObjectPtr,PosixPidOpen,uint32_t,pid,RexxStringObject,expected){
    auto tick=str(context,expected);
    if(!pid||pid>2147483647||!digits(tick))return result(context,EINVAL);
    Fd proc(open("/proc",O_PATH|O_DIRECTORY|O_CLOEXEC|O_NOFOLLOW));if(proc.n<0)return result(context,errno);
    struct statfs fs;if(fstatfs(proc.n,&fs)<0)return result(context,errno);
    if(fs.f_type!=PROC_SUPER_MAGIC)return result(context,EXDEV);
    char self[64];ssize_t n=readlinkat(proc.n,"self",self,sizeof(self));
    if(n<0)return result(context,errno);
    if(std::string(self,n)!=std::to_string(getpid()))return result(context,EXDEV);
    Fd base(rooted(proc.n,std::to_string(pid),O_PATH|O_DIRECTORY));if(base.n<0)return result(context,errno);
    std::string start;if(!procStart(base.n,start))return result(context,errno);
    if(start!=tick)return result(context,ESTALE);
#ifdef SYS_pidfd_open
    Fd fd(static_cast<int>(syscall(SYS_pidfd_open,pid,0)));
#else
    Fd fd(-1);errno=ENOSYS;
#endif
    if(fd.n<0)return result(context,errno);
    // Verify the pidfd's PID as projected by this procfs, and revalidate the
    // original directory against a fresh lookup before registering the handle.
    Fd info(openat(proc.n,("self/fdinfo/"+std::to_string(fd.n)).c_str(),O_RDONLY|O_CLOEXEC));if(info.n<0)return result(context,errno);
    char buf[4096];do{n=read(info.n,buf,sizeof(buf));}while(n<0&&errno==EINTR);
    if(n<0)return result(context,errno);
    std::istringstream lines(std::string(buf,static_cast<size_t>(n)));std::string line;bool match=false;
    while(std::getline(lines,line)){if(line.compare(0,4,"Pid:")==0)match=trim(line.substr(4))==std::to_string(pid);}
    if(!match)return result(context,ESTALE);
    Fd fresh(rooted(proc.n,std::to_string(pid),O_PATH|O_DIRECTORY));if(fresh.n<0)return result(context,errno);
    struct stat a,b;if(fstat(base.n,&a)<0||fstat(fresh.n,&b)<0)return result(context,errno);
    if(a.st_dev!=b.st_dev||a.st_ino!=b.st_ino)return result(context,ESTALE);
    if(!procStart(base.n,start))return result(context,errno);
    if(start!=tick)return result(context,ESTALE);
    std::lock_guard<std::mutex> l(guard);
    if(processes.size()>=128)return registryFull(context,"PROCESS_REGISTRY_FULL (128 open process handles)");
    auto key=token();if(key.empty())return result(context,errno);
    processes.emplace(key,fd.n);fd.n=-1;auto d=result(context,0);putToken(context,d,key);put(context,d,"PID",pid);putText(context,d,"START_TICKS",tick);return d;
}
static int processDup(RexxCallContext* c,RexxStringObject h){
    std::lock_guard<std::mutex> l(guard);auto i=processes.find(str(c,h));if(i==processes.end()){errno=EBADF;return -1;}return fcntl(i->second,F_DUPFD_CLOEXEC,0);
}
RexxRoutine2(RexxObjectPtr,PosixPidWait,RexxStringObject,h,uint32_t,ms){
    if(ms>5000)return result(context,EINVAL);
    Fd fd(processDup(context,h));if(fd.n<0)return result(context,errno);
    using Clock=std::chrono::steady_clock;auto deadline=Clock::now()+std::chrono::milliseconds(ms);
    struct pollfd p={fd.n,POLLIN,0};int remaining=static_cast<int>(ms),n;
    for(;;){n=poll(&p,1,remaining);if(n>=0)break;if(errno!=EINTR)return result(context,errno);
        auto left=deadline-Clock::now();if(left<=Clock::duration::zero()){n=0;break;}
        remaining=static_cast<int>(std::chrono::duration_cast<std::chrono::milliseconds>(left).count())+1;}
    if(n>0&&(p.revents&(POLLERR|POLLNVAL)))return result(context,EIO);
    if(n>0&&!(p.revents&(POLLIN|POLLHUP)))return result(context,EIO);
    auto d=result(context,0);put(context,d,"EXITED",n>0);put(context,d,"TIMED_OUT",n==0&&ms>0);return d;
}
RexxRoutine2(RexxObjectPtr,PosixPidSignal,RexxStringObject,h,int32_t,sig){
    // Deliberately narrow internal operation; kernel permissions still apply.
    if(sig!=0&&sig!=SIGTERM&&sig!=SIGINT&&sig!=SIGHUP&&sig!=SIGKILL)return result(context,EINVAL);
    Fd fd(processDup(context,h));if(fd.n<0)return result(context,errno);
#ifdef SYS_pidfd_send_signal
    if(syscall(SYS_pidfd_send_signal,fd.n,sig,nullptr,0)<0)return result(context,errno);
    auto d=result(context,0);put(context,d,"SIGNAL",sig);put(context,d,"ACCEPTED",1);return d;
#else
    return result(context,ENOSYS);
#endif
}
RexxRoutine1(RexxObjectPtr,PosixPidClose,RexxStringObject,h){
    std::lock_guard<std::mutex> l(guard);auto i=processes.find(str(context,h));if(i==processes.end())return result(context,EBADF);
    notifySourceClosed(i->first);close(i->second);processes.erase(i);return result(context,0);
}

// One inotify instance per watch; no recursion and no user-supplied masks.
RexxRoutine2(RexxObjectPtr,PosixWatchOpen,RexxStringObject,h,RexxStringObject,path){
    std::lock_guard<std::mutex> l(guard);auto id=str(context,h);auto r=roots.find(id);if(r==roots.end())return result(context,EBADF);
    if(watches.size()>=128)return registryFull(context,"WATCH_REGISTRY_FULL (128 open watches)");
    Fd targetfd(rooted(r->second,str(context,path),O_PATH|O_DIRECTORY));if(targetfd.n<0)return result(context,errno);
    Fd proc(open("/proc",O_PATH|O_DIRECTORY|O_CLOEXEC|O_NOFOLLOW));if(proc.n<0)return result(context,errno);
    struct statfs fs;if(fstatfs(proc.n,&fs)<0)return result(context,errno);if(fs.f_type!=PROC_SUPER_MAGIC)return result(context,EXDEV);
    Fd fd(inotify_init1(IN_NONBLOCK|IN_CLOEXEC));if(fd.n<0)return result(context,errno);
    auto name="/proc/self/fd/"+std::to_string(targetfd.n);
    constexpr uint32_t mask=IN_CREATE|IN_DELETE|IN_MOVED_FROM|IN_MOVED_TO|IN_CLOSE_WRITE|IN_ATTRIB|IN_MODIFY|IN_DELETE_SELF|IN_MOVE_SELF|IN_UNMOUNT|IN_ONLYDIR;
    if(inotify_add_watch(fd.n,name.c_str(),mask)<0)return result(context,errno);
    auto key=token();if(key.empty())return result(context,errno);
    watches.emplace(key,Watch{id,fd.n,{},0,false,false});fd.n=-1;auto out=result(context,0);putToken(context,out,key);return out;
}
static void watchFlags(RexxCallContext* c,RexxDirectoryObject d,const Watch& w){put(c,d,"RESCAN_REQUIRED",w.lost||w.invalid);put(c,d,"OVERFLOW",w.lost);put(c,d,"INVALIDATED",w.invalid);}
RexxRoutine2(RexxObjectPtr,PosixWatchNext,RexxStringObject,h,uint32_t,limit){
    if(!limit||limit>1024)return result(context,EINVAL);
    std::lock_guard<std::mutex> l(guard);auto i=watches.find(str(context,h));if(i==watches.end())return result(context,EBADF);
    auto& w=i->second;auto rows=context->NewArray(0);uint32_t count=0;bool drained=false;
    while(count<limit){
        if(w.offset==w.pending.size()){
            w.pending.resize(4096);ssize_t n=read(w.fd,w.pending.data(),w.pending.size());w.offset=0;
            if(n<0){int e=errno;w.pending.clear();if(e==EAGAIN){drained=true;break;}if(e==EINTR)continue;w.lost=true;return result(context,e);}
            if(!n){w.pending.clear();w.invalid=true;drained=true;break;}w.pending.resize(static_cast<size_t>(n));
        }
        size_t remaining=w.pending.size()-w.offset;struct inotify_event ev;
        if(remaining<sizeof(ev)){w.pending.clear();w.offset=0;w.lost=true;return result(context,EIO);}
        memcpy(&ev,w.pending.data()+w.offset,sizeof(ev));
        if(ev.len>remaining-sizeof(ev)){w.pending.clear();w.offset=0;w.lost=true;return result(context,EIO);}
        const char* name=w.pending.data()+w.offset+sizeof(ev);size_t len=ev.len?strnlen(name,ev.len):0;
        w.offset+=sizeof(ev)+ev.len;
        if(ev.mask&IN_Q_OVERFLOW)w.lost=true;
        if(ev.mask&(IN_IGNORED|IN_DELETE_SELF|IN_MOVE_SELF|IN_UNMOUNT))w.invalid=true;
        auto row=context->NewDirectory();putText(context,row,"NAME",std::string(name,len));put(context,row,"MASK",ev.mask);put(context,row,"COOKIE",ev.cookie);put(context,row,"IS_DIRECTORY",(ev.mask&IN_ISDIR)!=0);
        auto kinds=context->NewArray(0);
        struct Kind{uint32_t bit;const char* name;};const Kind all[]={{IN_CREATE,"CREATE"},{IN_DELETE,"DELETE"},{IN_MOVED_FROM,"MOVED_FROM"},{IN_MOVED_TO,"MOVED_TO"},{IN_CLOSE_WRITE,"CLOSE_WRITE"},{IN_ATTRIB,"ATTRIB"},{IN_MODIFY,"MODIFY"},{IN_DELETE_SELF,"DELETE_SELF"},{IN_MOVE_SELF,"MOVE_SELF"},{IN_UNMOUNT,"UNMOUNT"},{IN_IGNORED,"IGNORED"},{IN_Q_OVERFLOW,"OVERFLOW"}};
        for(auto k:all)if(ev.mask&k.bit)context->ArrayAppend(kinds,context->NewStringFromAsciiz(k.name));
        context->DirectoryPut(row,kinds,"KINDS");context->ArrayAppend(rows,row);++count;
    }
    auto d=result(context,0);context->DirectoryPut(d,rows,"EVENTS");put(context,d,"DRAINED",drained);watchFlags(context,d,w);return d;
}
RexxRoutine2(RexxObjectPtr,PosixWatchWait,RexxStringObject,h,uint32_t,ms){
    if(ms>5000)return result(context,EINVAL);
    Fd fd(-1);{
        std::lock_guard<std::mutex> l(guard);auto i=watches.find(str(context,h));if(i==watches.end())return result(context,EBADF);
        if(i->second.offset<i->second.pending.size()||i->second.lost||i->second.invalid){auto d=result(context,0);put(context,d,"READY",1);put(context,d,"TIMED_OUT",0);watchFlags(context,d,i->second);return d;}
        fd.n=fcntl(i->second.fd,F_DUPFD_CLOEXEC,0);if(fd.n<0)return result(context,errno);
    }
    using Clock=std::chrono::steady_clock;auto deadline=Clock::now()+std::chrono::milliseconds(ms);struct pollfd p={fd.n,POLLIN,0};int remaining=static_cast<int>(ms),n;
    for(;;){n=poll(&p,1,remaining);if(n>=0)break;if(errno!=EINTR)return result(context,errno);auto left=deadline-Clock::now();if(left<=Clock::duration::zero()){n=0;break;}remaining=static_cast<int>(std::chrono::duration_cast<std::chrono::milliseconds>(left).count())+1;}
    if(n>0&&(p.revents&(POLLERR|POLLNVAL|POLLHUP)))return result(context,EIO);
    std::lock_guard<std::mutex> l(guard);auto i=watches.find(str(context,h));if(i==watches.end())return result(context,EBADF);
    bool ready=n>0||i->second.offset<i->second.pending.size()||i->second.lost||i->second.invalid;auto d=result(context,0);put(context,d,"READY",ready);put(context,d,"TIMED_OUT",!ready&&ms>0);watchFlags(context,d,i->second);return d;
}
RexxRoutine1(RexxObjectPtr,PosixWatchClose,RexxStringObject,h){
    std::lock_guard<std::mutex> l(guard);auto i=watches.find(str(context,h));if(i==watches.end())return result(context,EBADF);notifySourceClosed(i->first);close(i->second.fd);watches.erase(i);return result(context,0);
}

// Monotonic timer; no callback runs in native code. Counts are drained explicitly.
RexxRoutine2(RexxObjectPtr,PosixTimerOpen,uint32_t,first,uint32_t,interval){
    if(!first||first>86400000||interval>86400000)return result(context,EINVAL);
    Fd fd(timerfd_create(CLOCK_MONOTONIC,TFD_NONBLOCK|TFD_CLOEXEC));if(fd.n<0)return result(context,errno);
    struct itimerspec spec={};spec.it_value.tv_sec=first/1000;spec.it_value.tv_nsec=(first%1000)*1000000L;
    spec.it_interval.tv_sec=interval/1000;spec.it_interval.tv_nsec=(interval%1000)*1000000L;
    if(timerfd_settime(fd.n,0,&spec,nullptr)<0)return result(context,errno);
    std::lock_guard<std::mutex> l(guard);if(timers.size()>=128)return registryFull(context,"TIMER_REGISTRY_FULL (128 open timers)");
    auto key=token();if(key.empty())return result(context,errno);timers.emplace(key,fd.n);fd.n=-1;auto d=result(context,0);putToken(context,d,key);return d;
}
RexxRoutine1(RexxObjectPtr,PosixTimerDrain,RexxStringObject,h){
    std::lock_guard<std::mutex> l(guard);auto i=timers.find(str(context,h));if(i==timers.end())return result(context,EBADF);
    uint64_t count=0;ssize_t n;do{n=read(i->second,&count,sizeof(count));}while(n<0&&errno==EINTR);
    if(n<0&&errno!=EAGAIN)return result(context,errno);
    if(n>=0&&n!=static_cast<ssize_t>(sizeof(count)))return result(context,EIO);
    auto d=result(context,0);put(context,d,"EXPIRATIONS",count);return d;
}
RexxRoutine1(RexxObjectPtr,PosixTimerClose,RexxStringObject,h){
    std::lock_guard<std::mutex> l(guard);auto i=timers.find(str(context,h));if(i==timers.end())return result(context,EBADF);
    notifySourceClosed(i->first);close(i->second);timers.erase(i);return result(context,0);
}
struct EventItem { std::string key; int fd; const char* kind; uint32_t flags; bool buffered; bool closed; };
struct EventCopies { std::vector<EventItem> items; ~EventCopies(){for(auto& i:items)if(i.fd>=0)close(i.fd);} };
// Called with registry mutex held; buffered watch events and sticky loss must
// remain ready even when inotify's own fd is no longer readable.
static int eventSource(EventItem& i){
    auto w=watches.find(i.key);if(w!=watches.end()){i.kind="FILESYSTEM";i.buffered=w->second.offset<w->second.pending.size()||w->second.lost||w->second.invalid;return w->second.fd;}
    auto p=processes.find(i.key);if(p!=processes.end()){i.kind="PROCESS";return p->second;}
    auto t=timers.find(i.key);if(t!=timers.end()){i.kind="TIMER";return t->second;}
    return -1;
}
// Level-triggered epoll, one bounded registration snapshot per wait. Duplicates
// pin file descriptions only for this call; close is revalidated before return.
RexxRoutine2(RexxObjectPtr,PosixEventWait,RexxArrayObject,keys,uint32_t,ms){
    size_t count=context->ArraySize(keys);if(!count||count>128||ms>5000)return result(context,EINVAL);
    EventCopies refs;std::map<std::string,bool> seen;
    for(size_t j=1;j<=count;++j){auto obj=context->ArrayAt(keys,j);if(!obj)return result(context,EINVAL);auto key=str(context,context->ObjectToString(obj));if(!key.empty()&&!seen.emplace(key,true).second)return result(context,EINVAL);refs.items.push_back(EventItem{key,-1,"UNKNOWN",0,false,false});}
    Fd ep(epoll_create1(EPOLL_CLOEXEC));if(ep.n<0)return result(context,errno);bool immediate=false;
    {
        std::lock_guard<std::mutex> l(guard);
        for(size_t j=0;j<count;++j){auto& i=refs.items[j];int fd=eventSource(i);if(fd<0){i.closed=true;immediate=true;continue;}
            i.fd=fcntl(fd,F_DUPFD_CLOEXEC,0);if(i.fd<0)return result(context,errno);
            struct epoll_event e={};e.events=EPOLLIN|EPOLLERR|EPOLLHUP;e.data.u64=j;
            if(epoll_ctl(ep.n,EPOLL_CTL_ADD,i.fd,&e)<0)return result(context,errno);
            immediate=immediate||i.buffered;
        }
    }
    using Clock=std::chrono::steady_clock;auto deadline=Clock::now()+std::chrono::milliseconds(ms);
    int remain=immediate?0:static_cast<int>(ms);struct epoll_event events[128];int n;
    for(;;){n=epoll_wait(ep.n,events,static_cast<int>(count),remain);if(n>=0)break;if(errno!=EINTR)return result(context,errno);
        auto left=deadline-Clock::now();if(immediate||left<=Clock::duration::zero()){n=0;break;}remain=static_cast<int>(std::chrono::duration_cast<std::chrono::milliseconds>(left).count())+1;}
    for(int j=0;j<n;++j)refs.items[events[j].data.u64].flags|=events[j].events;
    auto rows=context->NewArray(0);
    {
        std::lock_guard<std::mutex> l(guard);
        for(size_t j=0;j<count;++j){auto& i=refs.items[j];i.buffered=false;if(eventSource(i)<0)i.closed=true;
            if(!i.closed&&!i.flags&&!i.buffered)continue;
            auto row=context->NewDirectory();put(context,row,"INDEX",j+1);putText(context,row,"KIND",i.kind);put(context,row,"CLOSED",i.closed);put(context,row,"READY",!i.closed&&(i.buffered||(i.flags&EPOLLIN)||(i.kind==std::string("PROCESS")&&(i.flags&EPOLLHUP))));
            put(context,row,"ERROR_EVENT",!i.closed&&(i.flags&EPOLLERR));put(context,row,"HANGUP",!i.closed&&(i.flags&EPOLLHUP));context->ArrayAppend(rows,row);
        }
    }
    auto d=result(context,0);context->DirectoryPut(d,rows,"EVENTS");put(context,d,"TIMED_OUT",context->ArraySize(rows)==0&&ms>0);return d;
}

// Persistent epoll registrations. All state is guarded; a waiting call pins
// the mux itself, and only one wait is allowed per mux. Source closure wakes
// subscribers; closed registrations are reported once and then removed.
RexxRoutine0(RexxObjectPtr,PosixMuxOpen){
    std::lock_guard<std::mutex> l(guard);
    if(muxes.size()>=32)return registryFull(context,"MUX_REGISTRY_FULL (32 open multiplexers)");
    auto m=std::make_shared<PersistentMux>();
    m->ep=epoll_create1(EPOLL_CLOEXEC);if(m->ep<0)return result(context,errno);
    m->wake=eventfd(0,EFD_NONBLOCK|EFD_CLOEXEC);if(m->wake<0)return result(context,errno);
    struct epoll_event e={};e.events=EPOLLIN;e.data.u64=0;
    if(epoll_ctl(m->ep,EPOLL_CTL_ADD,m->wake,&e)<0)return result(context,errno);
    auto key=token();if(key.empty())return result(context,errno);muxes.emplace(key,m);
    auto d=result(context,0);putToken(context,d,key);return d;
}
RexxRoutine2(RexxObjectPtr,PosixMuxAdd,RexxStringObject,h,RexxStringObject,source){
    std::lock_guard<std::mutex> l(guard);auto it=muxes.find(str(context,h));if(it==muxes.end())return result(context,EBADF);auto& m=*it->second;
    if(m.regs.size()>=128)return registryFull(context,"MUX_SOURCE_REGISTRY_FULL (128 registered sources)");
    auto key=str(context,source);for(const auto& r:m.regs)if(r.second.key==key)return result(context,EEXIST);
    EventItem item{key,-1,"UNKNOWN",0,false,false};int fd=eventSource(item);if(fd<0)return result(context,EBADF);
    if(m.next==UINT64_MAX)return result(context,EOVERFLOW);
    Fd copy(fcntl(fd,F_DUPFD_CLOEXEC,0));if(copy.n<0)return result(context,errno);
    uint64_t id=m.next++;struct epoll_event e={};e.events=EPOLLIN|EPOLLERR|EPOLLHUP;e.data.u64=id;
    if(epoll_ctl(m.ep,EPOLL_CTL_ADD,copy.n,&e)<0)return result(context,errno);
    m.regs.emplace(id,MuxRegistration{key,copy.n,item.kind});copy.n=-1;
    if(m.waiting){m.changed=true;notifyMux(m);}
    auto d=result(context,0);put(context,d,"REGISTRATION",id);return d;
}
static void eraseRegistration(PersistentMux& m,std::map<uint64_t,MuxRegistration>::iterator i){
    if(i->second.fd>=0){epoll_ctl(m.ep,EPOLL_CTL_DEL,i->second.fd,nullptr);close(i->second.fd);}m.regs.erase(i);
}
RexxRoutine2(RexxObjectPtr,PosixMuxRemove,RexxStringObject,h,uint64_t,id){
    std::lock_guard<std::mutex> l(guard);auto it=muxes.find(str(context,h));if(it==muxes.end())return result(context,EBADF);auto& m=*it->second;
    auto i=m.regs.find(id);if(i==m.regs.end())return result(context,ENOENT);eraseRegistration(m,i);
    if(m.waiting){m.changed=true;notifyMux(m);}return result(context,0);
}
RexxRoutine1(RexxObjectPtr,PosixMuxWake,RexxStringObject,h){
    std::lock_guard<std::mutex> l(guard);auto i=muxes.find(str(context,h));if(i==muxes.end())return result(context,EBADF);
    i->second->explicitWake=true;notifyMux(*i->second);return result(context,0);
}
RexxRoutine1(RexxObjectPtr,PosixMuxClose,RexxStringObject,h){
    std::lock_guard<std::mutex> l(guard);auto i=muxes.find(str(context,h));if(i==muxes.end())return result(context,EBADF);
    auto& m=*i->second;m.closed=true;notifyMux(m);while(!m.regs.empty())eraseRegistration(m,m.regs.begin());muxes.erase(i);return result(context,0);
}
RexxRoutine2(RexxObjectPtr,PosixMuxWait,RexxStringObject,h,uint32_t,ms){
    if(ms>5000)return result(context,EINVAL);
    std::shared_ptr<PersistentMux> m;bool immediate=false;
    {std::lock_guard<std::mutex> l(guard);auto i=muxes.find(str(context,h));if(i==muxes.end())return result(context,EBADF);m=i->second;
     if(m->waiting)return result(context,EBUSY);
     m->waiting=true;immediate=m->explicitWake||m->changed;
     for(const auto& r:m->regs){EventItem item{r.second.key,-1,r.second.kind,0,false,false};if(r.second.fd<0||eventSource(item)<0||item.buffered)immediate=true;}}
    using Clock=std::chrono::steady_clock;auto deadline=Clock::now()+std::chrono::milliseconds(ms);
    int remain=immediate?0:static_cast<int>(ms);struct epoll_event events[129];int n;
    for(;;){n=epoll_wait(m->ep,events,129,remain);if(n>=0||errno!=EINTR)break;
        auto left=deadline-Clock::now();if(immediate||left<=Clock::duration::zero()){n=0;break;}remain=static_cast<int>(std::chrono::duration_cast<std::chrono::milliseconds>(left).count())+1;}
    int error=n<0?errno:0;std::lock_guard<std::mutex> l(guard);m->waiting=false;if(error)return result(context,error);
    uint64_t ignored;ssize_t count;do{count=read(m->wake,&ignored,sizeof(ignored));}while(count<0&&errno==EINTR);
    std::map<uint64_t,uint32_t> flags;for(int j=0;j<n;++j)if(events[j].data.u64)flags[events[j].data.u64]|=events[j].events;
    auto rows=context->NewArray(0);
    for(auto i=m->regs.begin();i!=m->regs.end();){auto id=i->first;EventItem item{i->second.key,-1,i->second.kind,flags[id],false,false};item.closed=i->second.fd<0||eventSource(item)<0;
        if(item.closed||item.flags||item.buffered){auto row=context->NewDirectory();put(context,row,"REGISTRATION",id);putText(context,row,"KIND",item.kind);put(context,row,"CLOSED",item.closed);
            put(context,row,"READY",!item.closed&&(item.buffered||(item.flags&EPOLLIN)||(std::string(item.kind)=="PROCESS"&&(item.flags&EPOLLHUP))));put(context,row,"ERROR_EVENT",!item.closed&&(item.flags&EPOLLERR));put(context,row,"HANGUP",!item.closed&&(item.flags&EPOLLHUP));context->ArrayAppend(rows,row);}
        if(item.closed){auto old=i++;eraseRegistration(*m,old);}else ++i;
    }
    auto d=result(context,0);context->DirectoryPut(d,rows,"EVENTS");put(context,d,"WOKEN",m->explicitWake);put(context,d,"CHANGED",m->changed);put(context,d,"CLOSED",m->closed);put(context,d,"TIMED_OUT",!m->closed&&!m->explicitWake&&!m->changed&&context->ArraySize(rows)==0&&ms>0);m->explicitWake=false;m->changed=false;return d;
}

// Read-only, bounded snapshots. No audit configuration, packet capture or memory reads.
static uint64_t epochMs(){return std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::system_clock::now().time_since_epoch()).count();}
static uint64_t monoMs(){return std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now().time_since_epoch()).count();}
static bool bootIdentity(int proc,std::string& boot){if(!readProcFile(proc,"sys/kernel/random/boot_id",boot))return false;boot=trim(boot.substr(0,boot.find('\n')));if(boot.size()!=36||boot.find_first_not_of("0123456789abcdef-")!=std::string::npos){errno=EIO;return false;}return true;}
static bool nsIdentity(int base,std::string& ns){struct stat st;if(fstatat(base,"ns/net",&st,0)<0)return false;ns=std::to_string(st.st_dev)+":"+std::to_string(st.st_ino);return true;}
RexxRoutine2(RexxObjectPtr,PosixSecurityProcess,uint32_t,pid,RexxStringObject,expected){
    if(!pid||pid>2147483647)return result(context,EINVAL);
    Fd proc(open("/proc",O_PATH|O_DIRECTORY|O_CLOEXEC|O_NOFOLLOW));if(proc.n<0)return result(context,errno);
    Fd base(rooted(proc.n,std::to_string(pid),O_PATH|O_DIRECTORY));if(base.n<0)return result(context,errno);
    std::string start,boot,data;if(!procStart(base.n,start))return result(context,errno);
    if(start!=str(context,expected))return result(context,ESTALE);
    if(!bootIdentity(proc.n,boot)||!readProcFile(base.n,"status",data))return result(context,errno);
    auto d=result(context,0);put(context,d,"PID",pid);putText(context,d,"START_TICKS",start);putText(context,d,"BOOT_ID",boot);
    putText(context,d,"IDENTITY",boot+":"+std::to_string(pid)+":"+start);
    std::istringstream input(data);std::string line;bool rss=false,uid=false,ppid=false;
    while(std::getline(input,line)){
        auto sep=line.find(':');if(sep==std::string::npos)continue;auto key=line.substr(0,sep);std::istringstream vals(line.substr(sep+1));std::string v,u;
        if(key=="Uid"){if(!(vals>>v>>u)||!digits(v)||!digits(u))return result(context,EIO);putText(context,d,"UID",v);putText(context,d,"EUID",u);uid=true;}
        else if(key=="PPid"){if(!(vals>>v)||!digits(v))return result(context,EIO);putText(context,d,"PPID",v);ppid=true;}
        else if(key=="VmRSS"||key=="VmHWM"||key=="VmSize"||key=="VmSwap"||key=="RssAnon"||key=="RssFile"||key=="RssShmem"){
            if(!(vals>>v>>u)||!digits(v)||u!="kB")return result(context,EIO);
            std::string name=key=="VmRSS"?"RSS_KIB":key=="VmHWM"?"PEAK_RSS_KIB":key=="VmSize"?"VIRTUAL_KIB":key=="VmSwap"?"SWAP_KIB":key=="RssAnon"?"ANON_KIB":key=="RssFile"?"FILE_KIB":"SHMEM_KIB";
            putText(context,d,name.c_str(),v);if(key=="VmRSS")rss=true;
        }
    }
    if(!uid||!ppid)return result(context,EIO);
    put(context,d,"MEMORY_AVAILABLE",rss);for(const auto& a:std::vector<std::pair<const char*,const char*>>{{"loginuid","AUID"},{"sessionid","AUDIT_SESSION"}}){
        std::string value; if(readProcFile(base.n,a.first,value)){value=trim(value.substr(0,value.find('\n')));if(!digits(value)||value.size()>10)return result(context,EIO);if(value=="4294967295")value="UNSET";putText(context,d,a.second,value);}else putText(context,d,a.second,"UNKNOWN");
    }
    std::string ns;if(nsIdentity(base.n,ns))putText(context,d,"NET_NAMESPACE",ns);else putText(context,d,"NET_NAMESPACE","UNKNOWN");
    if(!procStart(base.n,start))return result(context,errno);
    if(start!=str(context,expected))return result(context,ESTALE);
    put(context,d,"MONO_MS",monoMs());put(context,d,"EPOCH_MS",epochMs());return d;
}
static bool hexNum(const std::string& s,uint64_t& v){if(s.empty()||s.size()>16||s.find_first_not_of("0123456789abcdefABCDEF")!=std::string::npos)return false;v=0;for(char c:s){unsigned n=c<='9'?c-'0':(c|32)-'a'+10;v=(v<<4)|n;}return true;}
// Compare descriptor links by socket inode only, never follow them. A shared
// socket is a reference held by this process, not proof of unique ownership.
static bool socketRefs(int base,std::set<std::string>& refs){
    Fd fd(rooted(base,"fd",O_RDONLY|O_DIRECTORY));if(fd.n<0)return false;
    DIR* dir=fdopendir(fd.n);if(!dir)return false;fd.n=-1;unsigned count=0;int err=0;
    for(;;){errno=0;auto ent=readdir(dir);if(!ent){err=errno;break;}std::string name(ent->d_name);if(!digits(name))continue;
        if(++count>4096){err=EOVERFLOW;break;}char link[512];ssize_t n=readlinkat(dirfd(dir),name.c_str(),link,sizeof(link));
        if(n<0){err=errno;break;}if(n==sizeof(link)){err=EOVERFLOW;break;}std::string val(link,n);
        if(val.size()>9&&val.compare(0,8,"socket:[")==0&&val.back()==']'){
            auto ino=val.substr(8,val.size()-9);if(!digits(ino)){err=EIO;break;}refs.insert(ino);
        }
    }
    closedir(dir);if(err){errno=err;return false;}return true;
}
static RexxObjectPtr portSnapshot(RexxCallContext* context,uint32_t port,const std::string& proto,uint32_t pid,const std::string& expected){
    if(!port||port>65535||(proto!="tcp"&&proto!="udp")||pid>2147483647)return result(context,EINVAL);
    bool scoped=pid!=0;Fd proc(open("/proc",O_PATH|O_DIRECTORY|O_CLOEXEC|O_NOFOLLOW));if(proc.n<0)return result(context,errno);
    Fd base(rooted(proc.n,std::to_string(scoped?pid:getpid()),O_PATH|O_DIRECTORY));if(base.n<0)return result(context,errno);
    std::string boot,ns,endns,start;std::set<std::string> refs,after;
    if(scoped){if(!procStart(base.n,start))return result(context,errno);if(start!=expected)return result(context,ESTALE);if(!socketRefs(base.n,refs))return result(context,errno);}
    if(!bootIdentity(proc.n,boot)||!nsIdentity(base.n,ns))return result(context,errno);
    uint64_t count=0,established=0,listeners=0,rx=0,tx=0;uint32_t families=0;
    for(const auto& suffix:std::vector<std::string>{"","6"}){
        std::string data;auto path="net/"+proto+suffix;if(!readProcFile(base.n,path.c_str(),data))return result(context,errno);
        ++families;std::istringstream input(data);std::string line;std::getline(input,line);if(line.find("local_address")==std::string::npos)return result(context,EIO);
        while(std::getline(input,line)){std::istringstream row(line);std::string slot,local,remote,state,queues,timer,retrans,uid,timeout,inode;if(!(row>>slot>>local>>remote>>state>>queues>>timer>>retrans>>uid>>timeout>>inode))return result(context,EIO);
            auto p=local.rfind(':');uint64_t lp;if(p==std::string::npos||!hexNum(local.substr(p+1),lp)||!digits(inode))return result(context,EIO);if(lp!=port||(scoped&&!refs.count(inode)))continue;
            p=queues.find(':');uint64_t a,b;if(p==std::string::npos||!hexNum(queues.substr(0,p),a)||!hexNum(queues.substr(p+1),b)||UINT64_MAX-tx<a||UINT64_MAX-rx<b)return result(context,EOVERFLOW);
            ++count;tx+=a;rx+=b;if(proto=="tcp"&&state=="01")++established;if(proto=="tcp"&&state=="0A")++listeners;
        }
    }
    if(!nsIdentity(base.n,endns))return result(context,errno);
    if(ns!=endns)return result(context,ESTALE);
    if(scoped){if(!socketRefs(base.n,after)||!procStart(base.n,start))return result(context,errno);if(start!=expected||refs!=after)return result(context,ESTALE);}
    auto d=result(context,0);putText(context,d,"BOOT_ID",boot);putText(context,d,"NET_NAMESPACE",ns);
    std::string identity=boot+":"+ns+":"+proto+":"+std::to_string(port);
    if(scoped){auto procid=boot+":"+std::to_string(pid)+":"+start;putText(context,d,"PROCESS_IDENTITY",procid);put(context,d,"PID",pid);putText(context,d,"START_TICKS",start);identity+=":"+procid;}
    putText(context,d,"SCOPE",scoped?"PROCESS_REFERENCES":"NETWORK_NAMESPACE");putText(context,d,"IDENTITY",identity);putText(context,d,"PROTOCOL",proto);put(context,d,"PORT",port);put(context,d,"SOCKET_COUNT",count);put(context,d,"ESTABLISHED_COUNT",established);put(context,d,"LISTENER_COUNT",listeners);put(context,d,"RX_QUEUE",rx);put(context,d,"TX_QUEUE",tx);put(context,d,"FAMILIES",families);put(context,d,"MONO_MS",monoMs());put(context,d,"EPOCH_MS",epochMs());return d;
}
RexxRoutine2(RexxObjectPtr,PosixPortSnapshot,uint32_t,port,RexxStringObject,protocol){return portSnapshot(context,port,str(context,protocol),0,"");}
RexxRoutine4(RexxObjectPtr,PosixProcessPortSnapshot,uint32_t,pid,RexxStringObject,expected,uint32_t,port,RexxStringObject,protocol){if(!pid)return result(context,EINVAL);return portSnapshot(context,port,str(context,protocol),pid,str(context,expected));}
// A current, revalidated parent edge, not historical ancestry or authority.
static bool procEdge(int fd,std::string& start,std::string& parent){
    std::string data;if(!readProcFile(fd,"stat",data))return false;
    auto p=data.rfind(')');if(p==std::string::npos){errno=EIO;return false;}
    std::istringstream in(data.substr(p+1));std::string v;
    for(int i=0;i<20;++i){if(!(in>>v)){errno=EIO;return false;}if(i==1)parent=v;if(i==19)start=v;}
    if(!digits(start)||!digits(parent)){errno=EIO;return false;}return true;
}
RexxRoutine2(RexxObjectPtr,PosixParentEdge,uint32_t,pid,RexxStringObject,expected){
    if(!pid||pid>2147483647)return result(context,EINVAL);
    Fd proc(open("/proc",O_PATH|O_DIRECTORY|O_CLOEXEC|O_NOFOLLOW));if(proc.n<0)return result(context,errno);
    Fd child(rooted(proc.n,std::to_string(pid),O_PATH|O_DIRECTORY));if(child.n<0)return result(context,errno);
    std::string start,parent,boot,ps,pp,check,cp;
    if(!procEdge(child.n,start,parent)||!bootIdentity(proc.n,boot))return result(context,errno);
    if(start!=str(context,expected))return result(context,ESTALE);
    auto d=result(context,0);putText(context,d,"CHILD_IDENTITY",boot+":"+std::to_string(pid)+":"+start);putText(context,d,"PPID",parent);
    put(context,d,"PID",pid);putText(context,d,"START_TICKS",start);putText(context,d,"BOOT_ID",boot);
    if(parent=="0"){if(!procEdge(child.n,check,cp)||check!=start||cp!=parent)return result(context,ESTALE);put(context,d,"LINK_AVAILABLE",0);put(context,d,"MONO_MS",monoMs());put(context,d,"EPOCH_MS",epochMs());return d;}
    Fd par(rooted(proc.n,parent,O_PATH|O_DIRECTORY));if(par.n<0)return result(context,errno);
    if(!procEdge(par.n,ps,pp)||!procEdge(child.n,check,cp))return result(context,errno);
    if(check!=start||cp!=parent)return result(context,ESTALE);
    Fd fresh(rooted(proc.n,parent,O_PATH|O_DIRECTORY));if(fresh.n<0)return result(context,errno);
    struct stat a{},b{};if(fstat(par.n,&a)||fstat(fresh.n,&b))return result(context,errno);
    if(a.st_dev!=b.st_dev||a.st_ino!=b.st_ino||!procStart(fresh.n,check)||check!=ps||!procEdge(child.n,check,cp)||check!=start||cp!=parent)return result(context,ESTALE);
    put(context,d,"LINK_AVAILABLE",1);putText(context,d,"PARENT_IDENTITY",boot+":"+parent+":"+ps);putText(context,d,"PARENT_START_TICKS",ps);putText(context,d,"BOOT_ID",boot);put(context,d,"MONO_MS",monoMs());put(context,d,"EPOCH_MS",epochMs());return d;
}
// TCP_INFO counters for established sockets in caller's network namespace.
// No payload, remote addresses, or arbitrary netlink commands are returned.
struct TcpCounter{uint64_t acked,received;};
static int tcpDump(int family,uint32_t port,std::map<std::string,TcpCounter>& rows){
    Fd sock(socket(AF_NETLINK,SOCK_RAW|SOCK_CLOEXEC|SOCK_NONBLOCK,NETLINK_SOCK_DIAG));if(sock.n<0)return errno;
    sockaddr_nl local{};local.nl_family=AF_NETLINK;if(bind(sock.n,reinterpret_cast<sockaddr*>(&local),sizeof(local)))return errno;
    struct {nlmsghdr h;inet_diag_req_v2 r;} req{};
    req.h.nlmsg_len=NLMSG_LENGTH(sizeof(req.r));req.h.nlmsg_type=SOCK_DIAG_BY_FAMILY;req.h.nlmsg_flags=NLM_F_REQUEST|NLM_F_DUMP;req.h.nlmsg_seq=1;
    req.r.sdiag_family=family;req.r.sdiag_protocol=IPPROTO_TCP;req.r.idiag_ext=1<<(INET_DIAG_INFO-1);req.r.idiag_states=1u<<1;
    sockaddr_nl kernel{};kernel.nl_family=AF_NETLINK;
    if(sendto(sock.n,&req,req.h.nlmsg_len,0,reinterpret_cast<sockaddr*>(&kernel),sizeof(kernel))!=static_cast<ssize_t>(req.h.nlmsg_len))return errno?errno:EIO;
    auto deadline=std::chrono::steady_clock::now()+std::chrono::milliseconds(500);size_t total=0;unsigned seen=0;
    for(;;){auto remain=std::chrono::duration_cast<std::chrono::milliseconds>(deadline-std::chrono::steady_clock::now()).count();if(remain<=0)return ETIMEDOUT;
        pollfd p{sock.n,POLLIN,0};int ready=poll(&p,1,static_cast<int>(remain));if(ready<0&&errno==EINTR)continue;if(ready<=0)return ready==0?ETIMEDOUT:errno;
        alignas(nlmsghdr) char buf[65536];sockaddr_nl from{};iovec iov{buf,sizeof(buf)};msghdr msg{};msg.msg_name=&from;msg.msg_namelen=sizeof(from);msg.msg_iov=&iov;msg.msg_iovlen=1;
        ssize_t got=recvmsg(sock.n,&msg,0);if(got<0&&(errno==EINTR||errno==EAGAIN))continue;if(got<0)return errno;
        if(!got||(msg.msg_flags&MSG_TRUNC)||from.nl_pid!=0)return EIO;
        total+=static_cast<size_t>(got);if(total>4*1024*1024)return EOVERFLOW;
        int left=static_cast<int>(got);
        for(auto* h=reinterpret_cast<nlmsghdr*>(buf);NLMSG_OK(h,left);h=NLMSG_NEXT(h,left)){
            if(h->nlmsg_seq!=1||(h->nlmsg_flags&NLM_F_DUMP_INTR))return EAGAIN;
            if(h->nlmsg_type==NLMSG_DONE){int status=0;if(NLMSG_PAYLOAD(h,0)>=sizeof(status))memcpy(&status,NLMSG_DATA(h),sizeof(status));return status<0?-status:0;}
            if(h->nlmsg_type==NLMSG_ERROR){if(NLMSG_PAYLOAD(h,0)<sizeof(nlmsgerr))return EIO;nlmsgerr e{};memcpy(&e,NLMSG_DATA(h),sizeof(e));return e.error<0?-e.error:EIO;}
            if(h->nlmsg_type!=SOCK_DIAG_BY_FAMILY||NLMSG_PAYLOAD(h,0)<sizeof(inet_diag_msg))return EIO;
            if(++seen>8192)return EOVERFLOW;
            auto* d=reinterpret_cast<inet_diag_msg*>(NLMSG_DATA(h));if(d->idiag_family!=family)return EIO;
            if(ntohs(d->id.idiag_sport)!=port||d->idiag_state!=1)continue;
            if(d->id.idiag_cookie[0]==INET_DIAG_NOCOOKIE&&d->id.idiag_cookie[1]==INET_DIAG_NOCOOKIE)return EIO;
            int alen=NLMSG_PAYLOAD(h,sizeof(*d));bool found=false;tcp_info ti{};
            for(auto* a=reinterpret_cast<rtattr*>(reinterpret_cast<char*>(d)+NLMSG_ALIGN(sizeof(*d)));RTA_OK(a,alen);a=RTA_NEXT(a,alen)){
                if(a->rta_type==INET_DIAG_INFO){if(found||RTA_PAYLOAD(a)<offsetof(tcp_info,tcpi_bytes_received)+sizeof(ti.tcpi_bytes_received))return ENOTSUP;memcpy(&ti,RTA_DATA(a),std::min(static_cast<size_t>(RTA_PAYLOAD(a)),sizeof(ti)));found=true;}
            }
            if(alen||!found)return ENOTSUP;
            auto key=std::to_string(family)+":"+std::to_string(d->id.idiag_cookie[0])+":"+std::to_string(d->id.idiag_cookie[1]);
            if(rows.size()>=1024||!rows.emplace(key,TcpCounter{ti.tcpi_bytes_acked,ti.tcpi_bytes_received}).second)return EOVERFLOW;
        }
        if(left)return EIO;
    }
}
RexxRoutine1(RexxObjectPtr,PosixTcpCounters,uint32_t,port){
    if(!port||port>65535)return result(context,EINVAL);
    Fd proc(open("/proc",O_PATH|O_DIRECTORY|O_CLOEXEC|O_NOFOLLOW));if(proc.n<0)return result(context,errno);
    Fd self(openat(proc.n,"self",O_PATH|O_DIRECTORY|O_CLOEXEC));if(self.n<0)return result(context,errno);
    std::string boot,ns,end;if(!bootIdentity(proc.n,boot)||!nsIdentity(self.n,ns))return result(context,errno);
    std::map<std::string,TcpCounter> rows;int e=tcpDump(AF_INET,port,rows);if(!e)e=tcpDump(AF_INET6,port,rows);if(e)return result(context,e);
    if(!nsIdentity(self.n,end))return result(context,errno);
    if(ns!=end)return result(context,ESTALE);
    auto d=result(context,0);auto a=context->NewArray(0);
    for(const auto& i:rows){auto r=context->NewDirectory();putText(context,r,"COOKIE",i.first);put(context,r,"ACKED_BYTES",i.second.acked);put(context,r,"RECEIVED_BYTES",i.second.received);context->ArrayAppend(a,r);}
    context->DirectoryPut(d,a,"SOCKETS");putText(context,d,"IDENTITY",boot+":"+ns+":tcp:"+std::to_string(port));putText(context,d,"BOOT_ID",boot);putText(context,d,"NET_NAMESPACE",ns);put(context,d,"PORT",port);putText(context,d,"SCOPE","ESTABLISHED_TCP_LOCAL_PORT");put(context,d,"MONO_MS",monoMs());put(context,d,"EPOCH_MS",epochMs());return d;
}

RexxRoutine0(RexxObjectPtr,PosixClockSnapshot){auto d=result(context,0);put(context,d,"MONO_MS",monoMs());put(context,d,"EPOCH_MS",epochMs());return d;}
RexxRoutineEntry routines[]={REXX_TYPED_ROUTINE(PosixClockSnapshot,PosixClockSnapshot),REXX_TYPED_ROUTINE(PosixParentEdge,PosixParentEdge),REXX_TYPED_ROUTINE(PosixTcpCounters,PosixTcpCounters),REXX_TYPED_ROUTINE(PosixSecurityProcess,PosixSecurityProcess),REXX_TYPED_ROUTINE(PosixPortSnapshot,PosixPortSnapshot),REXX_TYPED_ROUTINE(PosixProcessPortSnapshot,PosixProcessPortSnapshot),REXX_TYPED_ROUTINE(PosixNativeStat,PosixNativeStat),REXX_TYPED_ROUTINE(PosixNativeCapacity,PosixNativeCapacity),REXX_TYPED_ROUTINE(PosixNativePageSize,PosixNativePageSize),REXX_TYPED_ROUTINE(PosixRootOpen,PosixRootOpen),REXX_TYPED_ROUTINE(PosixRootClose,PosixRootClose),REXX_TYPED_ROUTINE(PosixRootStat,PosixRootStat),REXX_TYPED_ROUTINE(PosixRootCapacity,PosixRootCapacity),REXX_TYPED_ROUTINE(PosixScanOpen,PosixScanOpen),REXX_TYPED_ROUTINE(PosixScanNext,PosixScanNext),REXX_TYPED_ROUTINE(PosixScanClose,PosixScanClose),REXX_TYPED_ROUTINE(PosixRootRead,PosixRootRead),REXX_TYPED_ROUTINE(PosixProcessList,PosixProcessList),REXX_TYPED_ROUTINE(PosixReaderOpen,PosixReaderOpen),REXX_TYPED_ROUTINE(PosixReaderRead,PosixReaderRead),REXX_TYPED_ROUTINE(PosixReaderStat,PosixReaderStat),REXX_TYPED_ROUTINE(PosixReaderClose,PosixReaderClose),REXX_TYPED_ROUTINE(PosixProcessDetails,PosixProcessDetails),REXX_TYPED_ROUTINE(PosixPidOpen,PosixPidOpen),REXX_TYPED_ROUTINE(PosixPidWait,PosixPidWait),REXX_TYPED_ROUTINE(PosixPidSignal,PosixPidSignal),REXX_TYPED_ROUTINE(PosixPidClose,PosixPidClose),REXX_TYPED_ROUTINE(PosixWatchOpen,PosixWatchOpen),REXX_TYPED_ROUTINE(PosixWatchNext,PosixWatchNext),REXX_TYPED_ROUTINE(PosixWatchWait,PosixWatchWait),REXX_TYPED_ROUTINE(PosixWatchClose,PosixWatchClose),REXX_TYPED_ROUTINE(PosixTimerOpen,PosixTimerOpen),REXX_TYPED_ROUTINE(PosixTimerDrain,PosixTimerDrain),REXX_TYPED_ROUTINE(PosixTimerClose,PosixTimerClose),REXX_TYPED_ROUTINE(PosixEventWait,PosixEventWait),REXX_TYPED_ROUTINE(PosixMuxOpen,PosixMuxOpen),REXX_TYPED_ROUTINE(PosixMuxAdd,PosixMuxAdd),REXX_TYPED_ROUTINE(PosixMuxRemove,PosixMuxRemove),REXX_TYPED_ROUTINE(PosixMuxWake,PosixMuxWake),REXX_TYPED_ROUTINE(PosixMuxClose,PosixMuxClose),REXX_TYPED_ROUTINE(PosixMuxWait,PosixMuxWait),REXX_LAST_ROUTINE()};
RexxPackageEntry posix_package_entry={STANDARD_PACKAGE_HEADER REXX_INTERPRETER_5_3_0,"rxshellposix","0.1",nullptr,nullptr,routines,nullptr};
OOREXX_GET_PACKAGE(posix)
