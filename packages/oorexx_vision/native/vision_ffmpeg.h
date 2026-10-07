#pragma once
#include <stddef.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct VisionFfmpeg VisionFfmpeg;
VisionFfmpeg *vision_ffmpeg_open(const char *url, int out_w, int out_h, double out_fps,
                                 char *err, size_t errcap);
int vision_ffmpeg_next_rgb24(VisionFfmpeg *v, unsigned char *dst, size_t dstcap,
                             double *source_seconds, char *err, size_t errcap);
void vision_ffmpeg_close(VisionFfmpeg *v);
#ifdef __cplusplus
}
#endif
