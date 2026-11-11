/* Synthetic FD identity regression: no media processing or external DSP. */
#define _POSIX_C_SOURCE 200809L
#include "../spash_ogg_source_fence.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>

int main(void) {
    char path[]="/tmp/spash-ogg-fence-XXXXXX";
    int fd=mkstemp(path);
    assert(fd>=0);
    assert(unlink(path)==0);
    assert(write(fd,"SOURCE",6)==6);
    SpashOggSourceFence initial;
    assert(spash_ogg_fence_capture(fd,&initial)==0);
    assert(spash_ogg_fence_unchanged(fd,&initial));
    assert(!spash_ogg_fence_unchanged(-1,&initial));
    assert(!spash_ogg_fence_unchanged(fd,NULL));
    assert(ftruncate(fd,3)==0);
    assert(!spash_ogg_fence_unchanged(fd,&initial));
    char other[]="/tmp/spash-ogg-fence-other-XXXXXX";
    int fd2=mkstemp(other);
    assert(fd2>=0);
    assert(unlink(other)==0);
    assert(write(fd2,"SOURCE",6)==6);
    assert(!spash_ogg_fence_unchanged(fd2,&initial));
    assert(ftruncate(fd2,0)==0);
    SpashOggSourceFence empty;
    assert(spash_ogg_fence_capture(fd2,&empty)!=0);
    close(fd); close(fd2);
    puts("PASS source fence unchanged/mutation/new-inode/empty/missing-fd");
    return 0;
}
