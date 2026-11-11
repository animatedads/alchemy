/* Local source identity fence for SPASH Ogg native seek.
 * POSIX C provider boundary: ooRexx retains application authority.
 * Architecture Tom Dyer; implementation ChatGPT GPT-6.
 */
#ifndef SPASH_OGG_SOURCE_FENCE_H
#define SPASH_OGG_SOURCE_FENCE_H
#include <sys/types.h>
#include <sys/stat.h>
#include <time.h>

typedef struct {
    dev_t device;
    ino_t inode;
    off_t size;
    mode_t mode;
    struct timespec modified;
    struct timespec changed;
} SpashOggSourceFence;

static inline int spash_ogg_fence_capture_stat(SpashOggSourceFence *out,
                                                const struct stat *st) {
    if (!out || !st || !S_ISREG(st->st_mode) || st->st_size <= 0) return -1;
    out->device=st->st_dev;
    out->inode=st->st_ino;
    out->size=st->st_size;
    out->mode=st->st_mode;
    out->modified=st->st_mtim;
    out->changed=st->st_ctim;
    return 0;
}
static inline int spash_ogg_fence_capture(int fd, SpashOggSourceFence *out) {
    struct stat st;
    if (fd < 0 || fstat(fd, &st) != 0) return -1;
    return spash_ogg_fence_capture_stat(out, &st);
}
static inline int spash_ogg_fence_unchanged(int fd,
                                             const SpashOggSourceFence *expected) {
    SpashOggSourceFence actual;
    if (!expected || spash_ogg_fence_capture(fd, &actual) != 0) return 0;
    return actual.device==expected->device &&
           actual.inode==expected->inode &&
           actual.size==expected->size &&
           actual.mode==expected->mode &&
           actual.modified.tv_sec==expected->modified.tv_sec &&
           actual.modified.tv_nsec==expected->modified.tv_nsec &&
           actual.changed.tv_sec==expected->changed.tv_sec &&
           actual.changed.tv_nsec==expected->changed.tv_nsec;
}
#endif
