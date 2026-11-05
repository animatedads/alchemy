/* SPASH native Ogg audio provider. No ffmpeg CLI, Python, transcription or upload.
 * A bounded provider called from ooRexx via Foreign Runtime. All clock mapping
 * remains with ooRexx; output sample zero is the decoder output origin only.
 * Requires FFmpeg libavformat/libavcodec/libavutil/libswresample >= 5.1.
 */
#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <fcntl.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/channel_layout.h>
#include <libavutil/error.h>
#include <libavutil/mathematics.h>
#include <libswresample/swresample.h>

static _Thread_local char error_text[384];
const char *spash_decode_last_error(void) { return error_text; }
static int fail(const char *phase, int rc) {
    char detail[160] = "";
    if (rc < 0) av_strerror(rc, detail, sizeof detail);
    else snprintf(detail, sizeof detail, "invalid state (%d)", rc);
    snprintf(error_text, sizeof error_text, "%s: %s", phase, detail);
    return -1;
}

typedef struct {
    SwrContext *swr;
    FILE *out;
    int input_rate, input_channels, select_channel, target_rate;
    enum AVSampleFormat input_format;
    uint64_t seen, written, first, requested;
    double peak;
} Decoder;

static int admit_frame(Decoder *d, const AVFrame *fr) {
    if (fr->nb_samples <= 0) return 0;
    if (fr->sample_rate <= 0 || fr->ch_layout.nb_channels < 1 ||
        d->select_channel >= fr->ch_layout.nb_channels)
        return fail("invalid source audio layout", AVERROR(EINVAL));
    if (d->swr == NULL) {
        AVChannelLayout mono;
        av_channel_layout_default(&mono, 1);
        d->input_rate = fr->sample_rate;
        d->input_channels = fr->ch_layout.nb_channels;
        d->input_format = (enum AVSampleFormat)fr->format;
        int rc = swr_alloc_set_opts2(&d->swr, &mono, AV_SAMPLE_FMT_FLT,
                                      d->target_rate, &fr->ch_layout,
                                      d->input_format, d->input_rate, 0, NULL);
        av_channel_layout_uninit(&mono);
        if (rc < 0 || !d->swr) return fail("swr_alloc_set_opts2", rc < 0 ? rc : AVERROR(ENOMEM));
        /* Preserve one named physical channel. Never average FC/FD or silently
         * combine a live mic with the silent third source channel. */
        double *matrix = calloc((size_t)d->input_channels, sizeof *matrix);
        if (!matrix) return fail("channel matrix allocation", AVERROR(ENOMEM));
        matrix[d->select_channel] = 1.0;
        rc = swr_set_matrix(d->swr, matrix, d->input_channels);
        free(matrix);
        if (rc < 0) return fail("swr_set_matrix", rc);
        rc = swr_init(d->swr);
        if (rc < 0) return fail("swr_init", rc);
    } else if (fr->sample_rate != d->input_rate ||
               fr->ch_layout.nb_channels != d->input_channels ||
               (enum AVSampleFormat)fr->format != d->input_format) {
        return fail("source format changed midstream", AVERROR(EINVAL));
    }
    int max_out = swr_get_out_samples(d->swr, fr->nb_samples);
    if (max_out < 1 || max_out > 2000000) return fail("invalid resampling bound", AVERROR(EINVAL));
    float *samples = malloc((size_t)max_out * sizeof *samples);
    if (!samples) return fail("bounded sample allocation", AVERROR(ENOMEM));
    uint8_t *dest[1] = {(uint8_t *)samples};
    int n = swr_convert(d->swr, dest, max_out, (const uint8_t **)fr->extended_data, fr->nb_samples);
    if (n < 0) { free(samples); return fail("swr_convert", n); }
    uint64_t from = d->seen, until = from + (uint64_t)n;
    uint64_t lo = from > d->first ? from : d->first;
    uint64_t hi = until < d->first + d->requested ? until : d->first + d->requested;
    if (hi > lo) {
        size_t off = (size_t)(lo - from), count = (size_t)(hi - lo);
        for (size_t i=off; i<off+count; ++i) {
            if (!isfinite(samples[i])) { free(samples); return fail("nonfinite source sample", AVERROR(EINVAL)); }
            double magnitude = fabs(samples[i]);
            if (magnitude > d->peak) d->peak = magnitude;
        }
        if (fwrite(samples+off, sizeof *samples, count, d->out) != count) {
            free(samples); return fail("write f32", AVERROR(EIO));
        }
        d->written += count;
    }
    d->seen = until;
    free(samples);
    return 0;
}

/* start_ms and duration_ms refer strictly to decoded output-sample ordinal,
 * NOT file wall time, filename time, video PTS, or cross-camera clock.
 * max 120 seconds/output and 48 kHz; no whole-source extraction in one call.
 * return 0 only on complete exact sample count; partial output is removed.
 */
int32_t spash_decode_ogg_f32(const char *input_path, const char *output_path,
                             const char *report_path, uint32_t start_ms,
                             uint32_t duration_ms, uint32_t physical_channel,
                             uint32_t target_rate) {
    AVFormatContext *fmt = NULL;
    AVCodecContext *codec = NULL;
    AVPacket *packet = NULL;
    AVFrame *frame = NULL;
    Decoder d = {0};
    int32_t status=-1;
    int output_created=0, report_created=0, output_fd=-1, report_fd=-1;
    FILE *report=NULL;
    error_text[0] = '\0';
    if (!input_path || !output_path || !report_path || !*input_path || !*output_path ||
        !*report_path || !strcmp(input_path, output_path) ||
        !strcmp(input_path, report_path) || !strcmp(output_path, report_path) ||
        (target_rate != 8000 && target_rate != 16000 && target_rate != 48000) ||
        duration_ms < 1 || duration_ms > 120000 || physical_channel > 31)
        return fail("invalid bounded decode arguments", AVERROR(EINVAL));
    d.first = ((uint64_t)start_ms * target_rate)/1000;
    d.requested = ((uint64_t)duration_ms * target_rate)/1000;
    d.select_channel = (int)physical_channel;
    d.target_rate = (int)target_rate;
    int rc = avformat_open_input(&fmt, input_path, NULL, NULL);
    if (rc < 0) { fail("avformat_open_input", rc); goto cleanup; }
    rc = avformat_find_stream_info(fmt,NULL);
    if (rc < 0) { fail("avformat_find_stream_info", rc); goto cleanup; }
    const AVCodec *decoder = NULL;
    int stream = av_find_best_stream(fmt, AVMEDIA_TYPE_AUDIO, -1, -1, &decoder, 0);
    if (stream < 0 || !decoder) { fail("av_find_best_stream", stream<0?stream:AVERROR_DECODER_NOT_FOUND); goto cleanup; }
    codec = avcodec_alloc_context3(decoder);
    if (!codec) { fail("avcodec_alloc_context3", AVERROR(ENOMEM)); goto cleanup; }
    rc = avcodec_parameters_to_context(codec, fmt->streams[stream]->codecpar);
    if (rc < 0) { fail("avcodec_parameters_to_context",rc); goto cleanup; }
    rc = avcodec_open2(codec,decoder,NULL);
    if (rc < 0) { fail("avcodec_open2",rc); goto cleanup; }
    packet = av_packet_alloc(); frame = av_frame_alloc();
    if (!packet || !frame) { fail("codec allocation",AVERROR(ENOMEM)); goto cleanup; }
    output_fd = open(output_path,O_WRONLY|O_CREAT|O_EXCL|O_CLOEXEC,0600);
    if (output_fd < 0) { fail("private output open",-errno); goto cleanup; }
    output_created=1;
    d.out = fdopen(output_fd,"wb");
    if (!d.out) { fail("fdopen",-errno); goto cleanup; }
    output_fd=-1;
    /* Packet demux/decode is local libav, never the ffmpeg executable. */
    while ((rc=av_read_frame(fmt,packet)) >= 0) {
        if (packet->stream_index == stream) {
            int send_rc=avcodec_send_packet(codec,packet);
            if (send_rc < 0) { fail("avcodec_send_packet",send_rc); av_packet_unref(packet); goto cleanup; }
            while ((send_rc=avcodec_receive_frame(codec,frame)) >= 0) {
                if (admit_frame(&d,frame) < 0) { av_frame_unref(frame); av_packet_unref(packet); goto cleanup; }
                av_frame_unref(frame);
                if (d.written == d.requested) break;
            }
            if (send_rc != AVERROR(EAGAIN) && send_rc != AVERROR_EOF && send_rc < 0) {
                fail("avcodec_receive_frame",send_rc); av_packet_unref(packet); goto cleanup;
            }
        }
        av_packet_unref(packet);
        if (d.written == d.requested) break;
    }
    if (rc != AVERROR_EOF && rc < 0) { fail("av_read_frame",rc); goto cleanup; }
    if (d.written != d.requested) {
        rc=avcodec_send_packet(codec,NULL);
        if (rc < 0 && rc != AVERROR_EOF) { fail("decoder drain",rc); goto cleanup; }
        while ((rc=avcodec_receive_frame(codec,frame)) >= 0 && d.written < d.requested) {
            if (admit_frame(&d,frame) < 0) { av_frame_unref(frame); goto cleanup; }
            av_frame_unref(frame);
        }
        if (d.swr && d.written < d.requested) {
            int space=swr_get_out_samples(d.swr,0);
            if (space > 0 && space < 2000000) {
                float *tail=calloc((size_t)space,sizeof *tail);
                if (!tail) { fail("resampler drain allocation",AVERROR(ENOMEM)); goto cleanup; }
                uint8_t *out[1]={(uint8_t *)tail};
                int k=swr_convert(d.swr,out,space,NULL,0);
                if (k<0) {free(tail);fail("resampler drain",k);goto cleanup;}
                uint64_t lo=d.seen>d.first?d.seen:d.first;
                uint64_t end=d.seen+(uint64_t)k;
                uint64_t hi=end<d.first+d.requested?end:d.first+d.requested;
                if (hi>lo) {
                    size_t off=(size_t)(lo-d.seen),count=(size_t)(hi-lo);
                    if (fwrite(tail+off,sizeof *tail,count,d.out)!=count){free(tail);fail("write drained samples",AVERROR(EIO));goto cleanup;}
                    d.written+=count;
                }
                free(tail);
            }
        }
    }
    if (d.written != d.requested) {fail("source ended before requested sample extent",AVERROR_EOF);goto cleanup;}
    if (fflush(d.out)!=0) {fail("flush f32",-errno);goto cleanup;}
    report_fd = open(report_path,O_WRONLY|O_CREAT|O_EXCL|O_CLOEXEC,0600);
    if (report_fd<0) {fail("private report open",-errno);goto cleanup;}
    report_created=1;
    report=fdopen(report_fd,"w");
    if (!report){fail("report fdopen",-errno);goto cleanup;}
    report_fd=-1;
    if (fprintf(report,"schema\tspash.native.audio-extent/1\nstart_ms\t%u\nduration_ms\t%u\nchannel_zero_based\t%u\nsource_rate_hz\t%d\ntarget_rate_hz\t%d\noutput_samples\t%llu\npeak_abs\t%.9g\nclock_authority\tDECODED_AUDIO_SAMPLE_ORDINAL_ONLY\n",start_ms,duration_ms,physical_channel,d.input_rate,d.target_rate,(unsigned long long)d.written,d.peak)<0){fail("write report",AVERROR(EIO));goto cleanup;}
    if(fflush(report)!=0){fail("flush report",-errno);goto cleanup;}
    status=0;
cleanup:
    if(report) fclose(report); else if(report_fd>=0) close(report_fd);
    if(d.out) fclose(d.out); else if(output_fd>=0) close(output_fd);
    if(status!=0){if(output_created)unlink(output_path);if(report_created)unlink(report_path);}
    swr_free(&d.swr);
    av_frame_free(&frame);av_packet_free(&packet);
    avcodec_free_context(&codec);avformat_close_input(&fmt);
    return status;
}