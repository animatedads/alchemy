#include <oorexxapi.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <stdint.h>
#include <stdlib.h>
#include <atomic>
#include <string>

static std::atomic<unsigned long> seq{0};

static RexxDirectoryObject newResult(RexxCallContext *c, bool ok)
{
    RexxDirectoryObject d = c->NewDirectory();
    c->DirectoryPut(d, ok ? c->True() : c->False(), "OK");
    c->DirectoryPut(d, c->NewStringFromAsciiz("rxatomicnative"), "PROVIDER");
    return d;
}
static void putString(RexxCallContext *c, RexxDirectoryObject d, const char *k, const std::string &v)
{ c->DirectoryPut(d, c->NewString(v.data(), v.size()), k); }
static void putCString(RexxCallContext *c, RexxDirectoryObject d, const char *k, const char *v)
{ c->DirectoryPut(d, c->NewStringFromAsciiz(v ? v : ""), k); }
static void putI64(RexxCallContext *c, RexxDirectoryObject d, const char *k, int64_t v)
{ c->DirectoryPut(d, c->Int64ToObject(v), k); }
static void putBool(RexxCallContext *c, RexxDirectoryObject d, const char *k, bool v)
{ c->DirectoryPut(d, v ? c->True() : c->False(), k); }

static RexxObjectPtr failure(RexxCallContext *c, int err, const char *stage, bool published, const std::string &temp = std::string())
{
    RexxDirectoryObject d = newResult(c, false);
    putI64(c, d, "ERRNO", err);
    putCString(c, d, "ERROR_MESSAGE", strerror(err));
    putCString(c, d, "STAGE", stage);
    putBool(c, d, "PUBLISHED", published);
    putBool(c, d, "DURABILITY_ACHIEVED", false);
    putString(c, d, "TEMP_NAME", temp);
    return d;
}
static RexxObjectPtr opt(RexxCallContext *c, RexxDirectoryObject d, const char *name)
{
    RexxObjectPtr o = c->DirectoryAt(d, name);
    return o == NULLOBJECT ? c->Nil() : o;
}
static std::string optString(RexxCallContext *c, RexxDirectoryObject d, const char *name, const char *def)
{
    RexxObjectPtr o = opt(c, d, name); if (o == c->Nil()) return def ? def : "";
    RexxStringObject s = c->ObjectToString(o); return std::string(c->StringData(s), c->StringLength(s));
}
static int64_t optI64(RexxCallContext *c, RexxDirectoryObject d, const char *name, int64_t def)
{
    RexxObjectPtr o = opt(c, d, name); if (o == c->Nil()) return def; int64_t v=def; if (!c->ObjectToInt64(o,&v)) return def; return v;
}
static bool optBool(RexxCallContext *c, RexxDirectoryObject d, const char *name, bool def)
{
    RexxObjectPtr o = opt(c, d, name); if (o == c->Nil()) return def; logical_t v=def?1:0; if (!c->ObjectToLogical(o,&v)) return def; return v!=0;
}

static bool splitPath(const std::string &path, std::string &parent, std::string &base)
{
    if (path.empty()) return false;
    size_t end = path.size(); while (end > 1 && path[end-1] == '/') --end;
    std::string p = path.substr(0,end);
    size_t slash = p.rfind('/');
    if (slash == std::string::npos) { parent = "."; base = p; }
    else if (slash == 0) { parent = "/"; base = p.substr(1); }
    else { parent = p.substr(0,slash); base = p.substr(slash+1); }
    return !base.empty() && base != "." && base != "..";
}

static int writeAll(int fd, const char *p, size_t n)
{
    while (n)
    {
        ssize_t w = write(fd,p,n);
        if (w > 0) { p += w; n -= (size_t)w; continue; }
        if (w < 0 && errno == EINTR) continue;
        return -1;
    }
    return 0;
}

RexxRoutine3(RexxObjectPtr, AtomicNativeReplace, CSTRING, pathC, RexxStringObject, bytesObj, RexxObjectPtr, optionsObj)
{
    if (!context->IsDirectory(optionsObj)) return failure(context, EINVAL, "OPTIONS_TYPE", false);
    RexxDirectoryObject options = (RexxDirectoryObject)optionsObj;
    std::string path(pathC ? pathC : "");
    std::string parent, base;
    if (!splitPath(path,parent,base)) return failure(context, EINVAL, "PATH", false);

    std::string durability = optString(context, options, "DURABILITY", "FULL");
    bool noFollow = optBool(context, options, "NO_FOLLOW", true);
    bool preserveMode = optBool(context, options, "PRESERVE_MODE", true);
    int64_t requestedMode = optI64(context, options, "MODE", 384); /* 0600 */
    if (durability != "NONE" && durability != "DATA" && durability != "FULL") return failure(context, EINVAL, "DURABILITY", false);
    if (requestedMode < 0 || requestedMode > 07777) return failure(context, EINVAL, "MODE", false);

    int dirfd = open(parent.c_str(), O_RDONLY|O_DIRECTORY|O_CLOEXEC);
    if (dirfd < 0) return failure(context, errno, "OPEN_PARENT", false);

    mode_t mode = (mode_t)requestedMode;
    struct stat existing;
    bool existed = false;
    if (fstatat(dirfd, base.c_str(), &existing, AT_SYMLINK_NOFOLLOW) == 0)
    {
        existed = true;
        if (noFollow && S_ISLNK(existing.st_mode)) { int e=ELOOP; close(dirfd); return failure(context,e,"TARGET_SYMLINK",false); }
        if (preserveMode) mode = existing.st_mode & 07777;
    }
    else if (errno != ENOENT) { int e=errno; close(dirfd); return failure(context,e,"STAT_TARGET",false); }

    std::string temp;
    int fd = -1;
    for (int attempt=0; attempt<100; ++attempt)
    {
        unsigned long n = ++seq;
        temp = "." + base + ".oorexx-atomic-" + std::to_string((long long)getpid()) + "-" + std::to_string(n);
        fd = openat(dirfd, temp.c_str(), O_WRONLY|O_CREAT|O_EXCL|O_CLOEXEC|O_NOFOLLOW, 0600);
        if (fd >= 0) break;
        if (errno != EEXIST) { int e=errno; close(dirfd); return failure(context,e,"CREATE_TEMP",false,temp); }
    }
    if (fd < 0) { close(dirfd); return failure(context,EEXIST,"CREATE_TEMP",false,temp); }

    auto cleanup = [&]() { if (fd >= 0) close(fd); unlinkat(dirfd,temp.c_str(),0); close(dirfd); };
    const char *data = context->StringData(bytesObj); size_t len = context->StringLength(bytesObj);
    if (writeAll(fd,data,len) != 0) { int e=errno; cleanup(); return failure(context,e,"WRITE_TEMP",false,temp); }
    if (fchmod(fd,mode) != 0) { int e=errno; cleanup(); return failure(context,e,"CHMOD_TEMP",false,temp); }

    if (durability == "DATA")
    {
#if defined(__APPLE__)
        if (fsync(fd) != 0)
#else
        if (fdatasync(fd) != 0)
#endif
        { int e=errno; cleanup(); return failure(context,e,"SYNC_DATA",false,temp); }
    }
    else if (durability == "FULL")
    {
        if (fsync(fd) != 0) { int e=errno; cleanup(); return failure(context,e,"SYNC_FILE",false,temp); }
    }

    if (close(fd) != 0) { int e=errno; fd=-1; unlinkat(dirfd,temp.c_str(),0); close(dirfd); return failure(context,e,"CLOSE_TEMP",false,temp); }
    fd = -1;
    if (renameat(dirfd,temp.c_str(),dirfd,base.c_str()) != 0) { int e=errno; unlinkat(dirfd,temp.c_str(),0); close(dirfd); return failure(context,e,"RENAME",false,temp); }

    if (durability == "FULL")
    {
        if (fsync(dirfd) != 0) { int e=errno; close(dirfd); return failure(context,e,"SYNC_PARENT",true,temp); }
    }
    close(dirfd);

    RexxDirectoryObject d = newResult(context,true);
    putBool(context,d,"PUBLISHED",true);
    putBool(context,d,"DURABILITY_ACHIEVED",durability!="NONE");
    putBool(context,d,"FILE_SYNCED",durability=="DATA" || durability=="FULL");
    putBool(context,d,"PARENT_SYNCED",durability=="FULL");
    putCString(context,d,"DURABILITY",durability.c_str());
    putI64(context,d,"BYTES",(int64_t)len);
    putI64(context,d,"MODE",(int64_t)mode);
    putBool(context,d,"REPLACED_EXISTING",existed);
    putString(context,d,"TEMP_NAME",temp);
    return d;
}

RexxRoutineEntry atomic_routines[] = {
    REXX_TYPED_ROUTINE(AtomicNativeReplace, AtomicNativeReplace),
    REXX_LAST_ROUTINE()
};
RexxPackageEntry RxAtomicNative_package_entry = {
    STANDARD_PACKAGE_HEADER
    REXX_INTERPRETER_4_0_0,
    "RxAtomicNative",
    "0.1-dev1",
    NULL, NULL, atomic_routines, NULL
};
OOREXX_GET_PACKAGE(RxAtomicNative);
