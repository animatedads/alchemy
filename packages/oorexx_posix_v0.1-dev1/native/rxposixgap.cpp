/*----------------------------------------------------------------------------*/
/* Temporary ooRexx POSIX gap provider                                        */
/*                                                                            */
/* These routines exist to qualify the oorexx.posix/0.1 facade while the      */
/* generally useful primitives are proposed for absorption into RxUnixSys.     */
/* They are NOT intended to become a second permanent Unix extension library.  */
/*----------------------------------------------------------------------------*/

#include <oorexxapi.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>

static RexxDirectoryObject newResult(RexxCallContext *context, bool ok)
{
    RexxDirectoryObject d = context->NewDirectory();
    context->DirectoryPut(d, ok ? context->True() : context->False(), "OK");
    context->DirectoryPut(d, context->NewStringFromAsciiz("rxposixgap"), "PROVIDER");
    return d;
}

static void putString(RexxCallContext *context, RexxDirectoryObject d, const char *key, const char *value)
{
    context->DirectoryPut(d, context->NewStringFromAsciiz(value == NULL ? "" : value), key);
}

static void putBytes(RexxCallContext *context, RexxDirectoryObject d, const char *key, const char *value, size_t n)
{
    context->DirectoryPut(d, context->NewString(value, n), key);
}

static void putI64(RexxCallContext *context, RexxDirectoryObject d, const char *key, int64_t value)
{
    context->DirectoryPut(d, context->Int64ToObject(value), key);
}

static void putU64(RexxCallContext *context, RexxDirectoryObject d, const char *key, uint64_t value)
{
    context->DirectoryPut(d, context->UnsignedInt64ToObject(value), key);
}

static RexxObjectPtr errorResult(RexxCallContext *context, int err)
{
    RexxDirectoryObject d = newResult(context, false);
    putI64(context, d, "ERRNO", err);
    putString(context, d, "ERROR_MESSAGE", strerror(err));
    return d;
}

static const char *fileType(mode_t mode)
{
    if (S_ISREG(mode))  return "REGULAR";
    if (S_ISDIR(mode))  return "DIRECTORY";
    if (S_ISLNK(mode))  return "SYMLINK";
    if (S_ISCHR(mode))  return "CHARACTER_DEVICE";
    if (S_ISBLK(mode))  return "BLOCK_DEVICE";
    if (S_ISFIFO(mode)) return "FIFO";
    if (S_ISSOCK(mode)) return "SOCKET";
    return "UNKNOWN";
}

static void statTimes(const struct stat &st,
                      int64_t &asec, int64_t &ansec,
                      int64_t &msec, int64_t &mnsec,
                      int64_t &csec, int64_t &cnsec)
{
#if defined(__APPLE__)
    asec = (int64_t)st.st_atimespec.tv_sec;
    ansec = (int64_t)st.st_atimespec.tv_nsec;
    msec = (int64_t)st.st_mtimespec.tv_sec;
    mnsec = (int64_t)st.st_mtimespec.tv_nsec;
    csec = (int64_t)st.st_ctimespec.tv_sec;
    cnsec = (int64_t)st.st_ctimespec.tv_nsec;
#else
    asec = (int64_t)st.st_atim.tv_sec;
    ansec = (int64_t)st.st_atim.tv_nsec;
    msec = (int64_t)st.st_mtim.tv_sec;
    mnsec = (int64_t)st.st_mtim.tv_nsec;
    csec = (int64_t)st.st_ctim.tv_sec;
    cnsec = (int64_t)st.st_ctim.tv_nsec;
#endif
}

static RexxObjectPtr statInfo(RexxCallContext *context, const char *path, bool follow)
{
    struct stat st;
    int rc = follow ? stat(path, &st) : lstat(path, &st);
    if (rc != 0)
    {
        int err = errno; /* capture before any other native/library work */
        return errorResult(context, err);
    }

    RexxDirectoryObject d = newResult(context, true);
    putString(context, d, "PATH", path);
    context->DirectoryPut(d, follow ? context->True() : context->False(), "FOLLOWED_SYMLINK");
    putU64(context, d, "DEVICE", (uint64_t)st.st_dev);
    putU64(context, d, "INODE", (uint64_t)st.st_ino);
    putU64(context, d, "MODE", (uint64_t)st.st_mode);
    putString(context, d, "FILETYPE", fileType(st.st_mode));
    putU64(context, d, "LINKCOUNT", (uint64_t)st.st_nlink);
    putU64(context, d, "UID", (uint64_t)st.st_uid);
    putU64(context, d, "GID", (uint64_t)st.st_gid);
    putU64(context, d, "RDEV", (uint64_t)st.st_rdev);
    putI64(context, d, "SIZE", (int64_t)st.st_size);
    putI64(context, d, "BLOCKSIZE", (int64_t)st.st_blksize);
    putI64(context, d, "BLOCKS", (int64_t)st.st_blocks);

    int64_t asec, ansec, msec, mnsec, csec, cnsec;
    statTimes(st, asec, ansec, msec, mnsec, csec, cnsec);
    putI64(context, d, "ATIME_SEC", asec);
    putI64(context, d, "ATIME_NSEC", ansec);
    putI64(context, d, "MTIME_SEC", msec);
    putI64(context, d, "MTIME_NSEC", mnsec);
    putI64(context, d, "CTIME_SEC", csec);
    putI64(context, d, "CTIME_NSEC", cnsec);
    return d;
}

RexxRoutine1(RexxObjectPtr, PosixGapStatInfo, CSTRING, path)
{
    return statInfo(context, path, true);
}

RexxRoutine1(RexxObjectPtr, PosixGapLstatInfo, CSTRING, path)
{
    return statInfo(context, path, false);
}

RexxRoutine1(RexxObjectPtr, PosixGapReadlink, CSTRING, path)
{
    struct stat st;
    if (lstat(path, &st) != 0)
    {
        int err = errno;
        return errorResult(context, err);
    }
    if (!S_ISLNK(st.st_mode))
    {
        return errorResult(context, EINVAL);
    }

    size_t cap = st.st_size > 0 ? (size_t)st.st_size + 1 : 256;
    if (cap < 2) cap = 2;
    char *buf = NULL;

    for (;;)
    {
        char *next = (char *)realloc(buf, cap);
        if (next == NULL)
        {
            free(buf);
            return errorResult(context, ENOMEM);
        }
        buf = next;

        ssize_t n = readlink(path, buf, cap);
        if (n < 0)
        {
            int err = errno;
            free(buf);
            return errorResult(context, err);
        }
        if ((size_t)n < cap)
        {
            RexxDirectoryObject d = newResult(context, true);
            putString(context, d, "PATH", path);
            putBytes(context, d, "VALUE", buf, (size_t)n);
            free(buf);
            return d;
        }

        if (cap > (SIZE_MAX / 2))
        {
            free(buf);
            return errorResult(context, ENAMETOOLONG);
        }
        cap *= 2;
    }
}

RexxRoutine1(RexxObjectPtr, PosixGapFsync, int, fd)
{
    if (fsync(fd) != 0)
    {
        int err = errno;
        return errorResult(context, err);
    }
    return newResult(context, true);
}

RexxRoutine1(RexxObjectPtr, PosixGapFdatasync, int, fd)
{
#if defined(__APPLE__)
    if (fsync(fd) != 0)
#else
    if (fdatasync(fd) != 0)
#endif
    {
        int err = errno;
        return errorResult(context, err);
    }
    return newResult(context, true);
}

RexxRoutineEntry posix_gap_routines[] = {
    REXX_TYPED_ROUTINE(PosixGapStatInfo, PosixGapStatInfo),
    REXX_TYPED_ROUTINE(PosixGapLstatInfo, PosixGapLstatInfo),
    REXX_TYPED_ROUTINE(PosixGapReadlink, PosixGapReadlink),
    REXX_TYPED_ROUTINE(PosixGapFsync, PosixGapFsync),
    REXX_TYPED_ROUTINE(PosixGapFdatasync, PosixGapFdatasync),
    REXX_LAST_ROUTINE()
};

RexxPackageEntry RxPosixGap_package_entry = {
    STANDARD_PACKAGE_HEADER
    REXX_INTERPRETER_4_0_0,
    "RxPosixGap",
    "0.1-dev1",
    NULL,
    NULL,
    posix_gap_routines,
    NULL
};

OOREXX_GET_PACKAGE(RxPosixGap);
