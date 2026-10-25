#include <fuse3/fuse.h>
int fuse_version(void){ return 399; }
int fuse_main(int argc, char **argv, const struct fuse_operations *op, void *data){
  (void)argc; (void)argv; (void)op; (void)data; return 0;
}
