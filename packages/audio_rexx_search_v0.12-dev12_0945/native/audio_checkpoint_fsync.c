#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static int fsync_parent(const char *path) {
    char buf[PATH_MAX];
    size_t n = strlen(path);
    if (n == 0 || n >= sizeof(buf)) return -1;
    memcpy(buf, path, n + 1);
    char *slash = strrchr(buf, '/');
    const char *dir = ".";
    if (slash) {
        if (slash == buf) slash[1] = '\0';
        else *slash = '\0';
        dir = buf;
    }
    int fd = open(dir, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
    if (fd < 0) return -1;
    int rc = fsync(fd);
    int saved = errno;
    close(fd);
    errno = saved;
    return rc;
}

static int fsync_path(const char *path) {
    int fd = open(path, O_RDONLY | O_CLOEXEC);
    if (fd < 0) {
        if (errno == ENOENT) return 0;
        return -1;
    }
    int rc = fsync(fd);
    int saved = errno;
    close(fd);
    errno = saved;
    if (rc != 0) return -1;
    return fsync_parent(path);
}

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "usage: %s PATH [PATH ...]\n", argv[0]);
        return 2;
    }
    for (int i = 1; i < argc; ++i) {
        if (fsync_path(argv[i]) != 0) {
            fprintf(stderr, "fsync failed for %s: %s\n", argv[i], strerror(errno));
            return 1;
        }
    }
    return 0;
}
