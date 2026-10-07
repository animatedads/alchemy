#include <oorexxapi.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <cerrno>
#include <cstdint>
#include <cstring>
#include <mutex>
#include <string>
#include <unordered_map>

struct Mapping {
    int fd = -1;
    uint8_t *base = nullptr;
    uint64_t bytes = 0;
    std::string path;
};

static std::mutex g_lock;
static std::unordered_map<uint64_t, Mapping> g_maps;
static uint64_t g_next = 1;

static Mapping *lookup(uint64_t handle) {
    auto it = g_maps.find(handle);
    return it == g_maps.end() ? nullptr : &it->second;
}

static bool validRange(const Mapping &m, uint64_t offset, uint64_t length) {
    return offset <= m.bytes && length <= (m.bytes - offset);
}

RexxMethod4(uint64_t, MBOpen,
            CSTRING, path,
            uint64_t, capacityBytes,
            OPTIONAL_logical_t, createFile,
            OPTIONAL_logical_t, hugePageAdvice)
{
    if (capacityBytes == 0) return 0;
    int flags = O_RDWR;
    if (argumentOmitted(3) || createFile) flags |= O_CREAT;
    int fd = ::open(path, flags, 0600);
    if (fd < 0) return 0;
    if (argumentOmitted(3) || createFile) {
        if (::ftruncate(fd, static_cast<off_t>(capacityBytes)) != 0) {
            ::close(fd);
            return 0;
        }
    } else {
        struct stat st {};
        if (::fstat(fd, &st) != 0 || static_cast<uint64_t>(st.st_size) < capacityBytes) {
            ::close(fd);
            return 0;
        }
    }
    void *p = ::mmap(nullptr, static_cast<size_t>(capacityBytes), PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (p == MAP_FAILED) {
        ::close(fd);
        return 0;
    }
#ifdef MADV_HUGEPAGE
    if (!argumentOmitted(4) && hugePageAdvice) {
        (void)::madvise(p, static_cast<size_t>(capacityBytes), MADV_HUGEPAGE);
    }
#endif
    std::lock_guard<std::mutex> guard(g_lock);
    uint64_t handle = g_next++;
    g_maps.emplace(handle, Mapping{fd, static_cast<uint8_t *>(p), capacityBytes, path});
    return handle;
}

RexxMethod1(logical_t, MBClose, uint64_t, handle)
{
    std::lock_guard<std::mutex> guard(g_lock);
    auto it = g_maps.find(handle);
    if (it == g_maps.end()) return 0;
    Mapping m = it->second;
    g_maps.erase(it);
    if (m.base != nullptr) ::munmap(m.base, static_cast<size_t>(m.bytes));
    if (m.fd >= 0) ::close(m.fd);
    return 1;
}

RexxMethod3(uint64_t, MBWrite,
            uint64_t, handle,
            uint64_t, offset,
            RexxStringObject, data)
{
    std::lock_guard<std::mutex> guard(g_lock);
    Mapping *m = lookup(handle);
    if (!m) return 0;
    size_t len = context->StringLength(data);
    if (!validRange(*m, offset, static_cast<uint64_t>(len))) return 0;
    if (len) std::memcpy(m->base + offset, context->StringData(data), len);
    return static_cast<uint64_t>(len);
}

RexxMethod3(RexxStringObject, MBRead,
            uint64_t, handle,
            uint64_t, offset,
            uint64_t, length)
{
    std::lock_guard<std::mutex> guard(g_lock);
    Mapping *m = lookup(handle);
    if (!m || !validRange(*m, offset, length)) return context->NullString();
    return context->NewString(reinterpret_cast<const char *>(m->base + offset), static_cast<size_t>(length));
}

RexxMethod4(uint64_t, MBCopy,
            uint64_t, handle,
            uint64_t, destinationOffset,
            uint64_t, sourceOffset,
            uint64_t, length)
{
    std::lock_guard<std::mutex> guard(g_lock);
    Mapping *m = lookup(handle);
    if (!m || !validRange(*m, destinationOffset, length) || !validRange(*m, sourceOffset, length)) return 0;
    if (length) std::memmove(m->base + destinationOffset, m->base + sourceOffset, static_cast<size_t>(length));
    return length;
}

RexxMethod3(uint64_t, MBZero,
            uint64_t, handle,
            uint64_t, offset,
            uint64_t, length)
{
    std::lock_guard<std::mutex> guard(g_lock);
    Mapping *m = lookup(handle);
    if (!m || !validRange(*m, offset, length)) return 0;
    if (length) std::memset(m->base + offset, 0, static_cast<size_t>(length));
    return length;
}

RexxMethod3(logical_t, MBFlush,
            uint64_t, handle,
            uint64_t, offset,
            uint64_t, length)
{
    std::lock_guard<std::mutex> guard(g_lock);
    Mapping *m = lookup(handle);
    if (!m || !validRange(*m, offset, length)) return 0;
    if (length == 0) return 1;
    long ps = ::sysconf(_SC_PAGESIZE);
    if (ps <= 0) ps = 4096;
    uint64_t start = offset & ~static_cast<uint64_t>(ps - 1);
    uint64_t end = (offset + length + ps - 1) & ~static_cast<uint64_t>(ps - 1);
    if (end > m->bytes) end = m->bytes;
    return ::msync(m->base + start, static_cast<size_t>(end - start), MS_SYNC) == 0;
}

RexxMethod1(uint64_t, MBCapacity, uint64_t, handle)
{
    std::lock_guard<std::mutex> guard(g_lock);
    Mapping *m = lookup(handle);
    return m ? m->bytes : 0;
}

RexxMethod0(uint64_t, MBPageSize)
{
    long ps = ::sysconf(_SC_PAGESIZE);
    return ps > 0 ? static_cast<uint64_t>(ps) : 4096;
}

RexxMethodEntry mb_methods[] = {
    REXX_METHOD(MBOpen, MBOpen),
    REXX_METHOD(MBClose, MBClose),
    REXX_METHOD(MBWrite, MBWrite),
    REXX_METHOD(MBRead, MBRead),
    REXX_METHOD(MBCopy, MBCopy),
    REXX_METHOD(MBZero, MBZero),
    REXX_METHOD(MBFlush, MBFlush),
    REXX_METHOD(MBCapacity, MBCapacity),
    REXX_METHOD(MBPageSize, MBPageSize),
    REXX_LAST_METHOD()
};

RexxPackageEntry memory_block_connector_package_entry = {
    STANDARD_PACKAGE_HEADER
    REXX_INTERPRETER_5_0_0,
    "MemoryBlockConnector",
    "0.1.0",
    nullptr,
    nullptr,
    nullptr,
    mb_methods
};

OOREXX_GET_PACKAGE(memory_block_connector);
