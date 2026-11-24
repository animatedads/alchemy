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
// Called under guard. Fail closed if OS entropy cannot be obtained.
static std::string token(){
    for(int attempt=0;attempt<8;++attempt){
        unsigned char bytes[16];size_t got=0;
        while(got<sizeof(bytes)){ssize_t n=getrandom(bytes+got,sizeof(bytes)-got,0);if(n<0&&errno==EINTR)continue;if(n<=0){if(!n)errno=EIO;return {}; }got+=static_cast<size_t>(n);}
        static const char hex[]="0123456789abcdef";std::string t;for(auto b:bytes){t+=hex[b>>4];t+=hex[b&15];}
        if(!roots.count(t)&&!scans.count(t)&&!readers.count(t)&&!processes.count(t)&&!watches.count(t)&&!timers.count(t))return t;
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
    for(auto i=watches.begin();i!=watches.end();){if(i->second.root==id){close(i->second.fd);i=watches.erase(i);}else ++i;}
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
    std::string start;if(!procStart(base.n,start))return result(context,errno);if(start!=str(context,expected))return result(context,ESTALE);
    Fd folder(rooted(base.n,k,O_RDONLY|O_DIRECTORY));if(folder.n<0)return result(context,errno);
    DIR* dir=fdopendir(folder.n);if(!dir)return result(context,errno);folder.n=-1;
    auto rows=context->NewArray(0);uint32_t count=0;bool truncated=false;int err=0;
    for(;;){errno=0;auto e=readdir(dir);if(!e){err=errno;break;}
        std::string name(e->d_name);if(name.empty()||name.find_first_not_of("0123456789")!=std::string::npos)continue;
        if(count==limit){truncated=true;break;}context->ArrayAppend(rows,context->NewString(name.data(),name.size()));++count;
    }
    closedir(dir);if(err)return result(context,err);if(!procStart(base.n,start))return result(context,errno);if(start!=str(context,expected))return result(context,ESTALE);
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
    std::string start;if(!procStart(base.n,start))return result(context,errno);if(start!=str(context,expected))return result(context,ESTALE);
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
    close(i->second);processes.erase(i);return result(context,0);
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
    std::lock_guard<std::mutex> l(guard);auto i=watches.find(str(context,h));if(i==watches.end())return result(context,EBADF);close(i->second.fd);watches.erase(i);return result(context,0);
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
    close(i->second);timers.erase(i);return result(context,0);
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

RexxRoutineEntry routines[]={REXX_TYPED_ROUTINE(PosixNativeStat,PosixNativeStat),REXX_TYPED_ROUTINE(PosixNativeCapacity,PosixNativeCapacity),REXX_TYPED_ROUTINE(PosixNativePageSize,PosixNativePageSize),REXX_TYPED_ROUTINE(PosixRootOpen,PosixRootOpen),REXX_TYPED_ROUTINE(PosixRootClose,PosixRootClose),REXX_TYPED_ROUTINE(PosixRootStat,PosixRootStat),REXX_TYPED_ROUTINE(PosixRootCapacity,PosixRootCapacity),REXX_TYPED_ROUTINE(PosixScanOpen,PosixScanOpen),REXX_TYPED_ROUTINE(PosixScanNext,PosixScanNext),REXX_TYPED_ROUTINE(PosixScanClose,PosixScanClose),REXX_TYPED_ROUTINE(PosixRootRead,PosixRootRead),REXX_TYPED_ROUTINE(PosixProcessList,PosixProcessList),REXX_TYPED_ROUTINE(PosixReaderOpen,PosixReaderOpen),REXX_TYPED_ROUTINE(PosixReaderRead,PosixReaderRead),REXX_TYPED_ROUTINE(PosixReaderStat,PosixReaderStat),REXX_TYPED_ROUTINE(PosixReaderClose,PosixReaderClose),REXX_TYPED_ROUTINE(PosixProcessDetails,PosixProcessDetails),REXX_TYPED_ROUTINE(PosixPidOpen,PosixPidOpen),REXX_TYPED_ROUTINE(PosixPidWait,PosixPidWait),REXX_TYPED_ROUTINE(PosixPidSignal,PosixPidSignal),REXX_TYPED_ROUTINE(PosixPidClose,PosixPidClose),REXX_TYPED_ROUTINE(PosixWatchOpen,PosixWatchOpen),REXX_TYPED_ROUTINE(PosixWatchNext,PosixWatchNext),REXX_TYPED_ROUTINE(PosixWatchWait,PosixWatchWait),REXX_TYPED_ROUTINE(PosixWatchClose,PosixWatchClose),REXX_TYPED_ROUTINE(PosixTimerOpen,PosixTimerOpen),REXX_TYPED_ROUTINE(PosixTimerDrain,PosixTimerDrain),REXX_TYPED_ROUTINE(PosixTimerClose,PosixTimerClose),REXX_TYPED_ROUTINE(PosixEventWait,PosixEventWait),REXX_LAST_ROUTINE()};
RexxPackageEntry posix_package_entry={STANDARD_PACKAGE_HEADER REXX_INTERPRETER_5_3_0,"rxshellposix","0.1",nullptr,nullptr,routines,nullptr};
OOREXX_GET_PACKAGE(posix)
