#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <unistd.h>

#ifndef RENAME_NOREPLACE
#define RENAME_NOREPLACE (1 << 0)
#endif

static int sync_file(const char *path) {
    int fd = open(path, O_RDWR | O_CLOEXEC | O_NOFOLLOW);
    if (fd < 0) { perror("open"); return 2; }
    if (fdatasync(fd) != 0) { perror("fdatasync"); close(fd); return 3; }
    if (close(fd) != 0) { perror("close"); return 4; }
    return 0;
}

static int sync_dir(const char *path) {
    int fd = open(path, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW);
    if (fd < 0) { perror("open-dir"); return 5; }
    if (fsync(fd) != 0) { perror("fsync-dir"); close(fd); return 6; }
    if (close(fd) != 0) { perror("close-dir"); return 7; }
    return 0;
}

static char *parent_of(const char *path) {
    char *p = strdup(path);
    if (!p) return NULL;
    char *slash = strrchr(p, '/');
    if (!slash) { strcpy(p, "."); return p; }
    if (slash == p) { slash[1] = '\0'; return p; }
    *slash = '\0';
    return p;
}

static int same_inode(const char *a, const char *b) {
    struct stat sa, sb;
    if (lstat(a, &sa) != 0 || lstat(b, &sb) != 0) return 0;
    return sa.st_dev == sb.st_dev && sa.st_ino == sb.st_ino;
}

/* Publish without replacement.  renameat2(RENAME_NOREPLACE) is preferred
 * because it works on filesystems that do not implement hard links.  The
 * link/unlink route remains a compatibility fallback and also recognises the
 * dev19 crash state in which temp and final are already the same inode. */
static int publish_no_replace(const char *temp, const char *final) {
    int rc = sync_file(temp);
    if (rc) return rc;

    int moved = 0;
#ifdef SYS_renameat2
    if (syscall(SYS_renameat2, AT_FDCWD, temp, AT_FDCWD, final,
                RENAME_NOREPLACE) == 0) {
        moved = 1;
    } else if (errno == EEXIST) {
        if (!same_inode(temp, final)) {
            perror("rename-noreplace");
            return 17;
        }
    } else if (errno != ENOSYS && errno != EINVAL &&
               errno != EOPNOTSUPP && errno != EXDEV) {
        perror("rename-noreplace");
        return 8;
    }
#endif

    if (!moved && access(final, F_OK) != 0) {
        if (link(temp, final) != 0) {
            if (errno == EEXIST && same_inode(temp, final)) {
                /* Recovery after a crash between link() and unlink(). */
            } else {
                perror("link-publish");
                return errno == EEXIST ? 17 : 8;
            }
        }
    }

    rc = sync_file(final);
    if (rc) return rc;

    char *parent = parent_of(final);
    if (!parent) return 9;
    rc = sync_dir(parent);
    if (rc) { free(parent); return rc; }

    if (!moved && unlink(temp) != 0 && errno != ENOENT) {
        perror("unlink-temp");
        free(parent);
        return 10;
    }
    rc = sync_dir(parent);
    free(parent);
    return rc;
}

static int write_all(int fd, const char *buf, size_t len) {
    while (len) {
        ssize_t n = write(fd, buf, len);
        if (n < 0) {
            if (errno == EINTR) continue;
            return -1;
        }
        buf += n;
        len -= (size_t)n;
    }
    return 0;
}

/* Exercise the actual publication primitives on the destination filesystem.
 * The scratch directory and files are package-owned, tiny and removed before
 * success is reported. */
static int probe_filesystem(const char *root) {
    size_t n = strlen(root) + 64;
    char *dir = malloc(n);
    char *temp = malloc(n + 32);
    char *final = malloc(n + 32);
    if (!dir || !temp || !final) { free(dir); free(temp); free(final); return 20; }

    snprintf(dir, n, "%s%s.sf-storage-preflight-XXXXXX",
             root, (root[0] && root[strlen(root)-1] == '/') ? "" : "/");
    if (!mkdtemp(dir)) { perror("mkdtemp"); free(dir); free(temp); free(final); return 21; }
    snprintf(temp, n + 32, "%s/partial", dir);
    snprintf(final, n + 32, "%s/final", dir);

    int fd = open(temp, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW, 0600);
    if (fd < 0) { perror("probe-open"); goto fail22; }
    const char payload[] = "storage-fabric-host-preflight\n";
    if (write_all(fd, payload, sizeof(payload)-1) != 0) { perror("probe-write"); close(fd); goto fail22; }
    if (fdatasync(fd) != 0) { perror("probe-fdatasync"); close(fd); goto fail22; }
    if (close(fd) != 0) { perror("probe-close"); goto fail22; }

    int rc = publish_no_replace(temp, final);
    if (rc) goto fail22;

    struct stat st;
    if (lstat(final, &st) != 0 || !S_ISREG(st.st_mode) ||
        st.st_size != (off_t)(sizeof(payload)-1)) {
        fprintf(stderr, "probe-final-invalid\n");
        goto fail22;
    }

    if (unlink(final) != 0) { perror("probe-unlink-final"); goto fail22; }
    if (sync_dir(dir) != 0) goto fail22;
    if (rmdir(dir) != 0) { perror("probe-rmdir"); goto fail23; }
    rc = sync_dir(root);
    free(dir); free(temp); free(final);
    return rc;

fail22:
    unlink(temp); unlink(final); rmdir(dir);
fail23:
    free(dir); free(temp); free(final);
    return 22;
}

int main(int argc, char **argv) {
    if (argc < 3) {
        fprintf(stderr, "usage: %s flush FILE | syncdir DIR | publish TEMP FINAL | probe DIR\n", argv[0]);
        return 64;
    }
    if (strcmp(argv[1], "flush") == 0 && argc == 3) return sync_file(argv[2]);
    if (strcmp(argv[1], "syncdir") == 0 && argc == 3) return sync_dir(argv[2]);
    if (strcmp(argv[1], "publish") == 0 && argc == 4) return publish_no_replace(argv[2], argv[3]);
    if (strcmp(argv[1], "probe") == 0 && argc == 3) return probe_filesystem(argv[2]);
    fprintf(stderr, "invalid arguments\n");
    return 64;
}
