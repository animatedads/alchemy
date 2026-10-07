#ifndef STORAGE_FUSE3_STUB_H
#define STORAGE_FUSE3_STUB_H
#include <stdint.h>
#include <sys/stat.h>
#include <sys/types.h>
struct fuse_file_info { int flags; uint64_t fh; unsigned int direct_io; unsigned int keep_cache; };
enum fuse_fill_dir_flags { FUSE_FILL_DIR_PLUS = 1 };
enum fuse_readdir_flags { FUSE_READDIR_PLUS = 1 };
typedef int (*fuse_fill_dir_t)(void *, const char *, const struct stat *, off_t, enum fuse_fill_dir_flags);
struct fuse_operations {
 int (*getattr)(const char *, struct stat *, struct fuse_file_info *);
 int (*readdir)(const char *, void *, fuse_fill_dir_t, off_t, struct fuse_file_info *, enum fuse_readdir_flags);
 int (*open)(const char *, struct fuse_file_info *);
 int (*create)(const char *, mode_t, struct fuse_file_info *);
 int (*read)(const char *, char *, size_t, off_t, struct fuse_file_info *);
 int (*write)(const char *, const char *, size_t, off_t, struct fuse_file_info *);
 int (*release)(const char *, struct fuse_file_info *);
 int (*mkdir)(const char *, mode_t);
 int (*unlink)(const char *);
 int (*rmdir)(const char *);
 int (*rename)(const char *, const char *, unsigned int);
 int (*truncate)(const char *, off_t, struct fuse_file_info *);
};
int fuse_main(int argc, char **argv, const struct fuse_operations *op, void *data);
int fuse_version(void);
#endif
