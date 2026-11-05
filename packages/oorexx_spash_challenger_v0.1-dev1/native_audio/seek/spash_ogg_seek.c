/* SPASH Ogg random-access reader v0.2 (experimental).
 * Application authority: ooRexx; native boundary: libavformat/codec/swresample.
 * READ ONLY local regular files. No shell, Python, network, source write,
 * transcription, Ogg remuxing, or whole-file transfer through Storage Fabric.
 * Formats: all FFmpeg-demuxed audio streams in one seekable Ogg physical file,
 * independently selectable physical channel per stream. Chained-stream and
 * resampler/PTS details require host qualification before evidential use.
 */
#define _POSIX_C_SOURCE 200809L
#include <stdint.h>
#include <inttypes.h>
#include <limits.h>
#include <errno.h>
#include <fcntl.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>
#include <libavformat/avformat.h>
#include <libavformat/avio.h>
#include <libavcodec/avcodec.h>
#include <libavutil/channel_layout.h>
#include <libavutil/error.h>
#include <libavutil/mathematics.h>
#include <libswresample/swresample.h>

#define IO_BUFFER 32768
#define MIN_BUDGET (1024 * 1024ULL)
#define MAX_BUDGET (128ULL * 1024 * 1024)
#define MAX_PACKETS 24000
#define MAX_WINDOW_MS 120000
#define PREROLL_MS 5000
#define MAX_FIRST_FRAME_LEAD_MS 15000
static _Thread_local char last_err[512];
const char *spash_seek_last_error(void) {return last_err;}
static int err(const char *stage,int rc) {
    char descr[170]="";
    if(rc<0) av_strerror(rc,descr,sizeof descr);
    else snprintf(descr,sizeof descr,"invalid state %d",rc);
    snprintf(last_err,sizeof last_err,"%s: %s",stage,descr);
    return -1;
}

typedef struct {
    int fd;
    int64_t pos;
    int64_t size;
    uint64_t compressed_read;
    uint64_t max_read;
    uint64_t read_calls,seek_calls;
    int64_t first_read_byte,max_read_byte;
    int over_budget;
} LocalIO;
static int local_read(void *opaque,uint8_t *buf,int size) {
    LocalIO *f=opaque;
    if(size<=0)return AVERROR(EINVAL);
    if(f->compressed_read >= f->max_read) {f->over_budget=1;return AVERROR(ENOSPC);}
    uint64_t room=f->max_read-f->compressed_read;
    if((uint64_t)size>room)size=(int)room;
    if(size<=0){f->over_budget=1;return AVERROR(ENOSPC);}
    ssize_t n=pread(f->fd,buf,(size_t)size,(off_t)f->pos);
    if(n<0)return AVERROR(errno);
    if(n==0)return AVERROR_EOF;
    if(f->first_read_byte<0)f->first_read_byte=f->pos;
    f->pos+=n;
    if(f->pos>f->max_read_byte)f->max_read_byte=f->pos;
    f->compressed_read+=(uint64_t)n;
    f->read_calls++;
    return (int)n;
}
static int64_t local_seek(void *opaque,int64_t offset,int whence) {
    LocalIO *f=opaque;
    int basis=whence & ~AVSEEK_FORCE;
    if(basis==AVSEEK_SIZE)return f->size;
    int64_t base;
    if(basis==SEEK_SET)base=0;
    else if(basis==SEEK_CUR)base=f->pos;
    else if(basis==SEEK_END)base=f->size;
    else return AVERROR(EINVAL);
    if((offset>0 && base>INT64_MAX-offset) ||
       (offset<0 && base<INT64_MIN-offset))return AVERROR(EINVAL);
    int64_t target=base+offset;
    if(target<0 || target>f->size)return AVERROR(EINVAL);
    f->pos=target;
    f->seek_calls++;
    return target;
}

typedef struct {
    AVFormatContext *fmt;
    AVIOContext *avio;
    LocalIO local;
} Source;
static void close_source(Source *s) {
    if(s->fmt)avformat_close_input(&s->fmt);
    if(s->avio)avio_context_free(&s->avio);
    if(s->local.fd>=0)close(s->local.fd);
    s->local.fd=-1;
}
static int open_source(Source *s,const char *path,uint64_t budget) {
    memset(s,0,sizeof *s);
    s->local.fd=-1;s->local.first_read_byte=-1;s->local.max_read=(budget==0?64ULL*1024*1024:budget);
    if(!path || !*path || s->local.max_read<MIN_BUDGET || s->local.max_read>MAX_BUDGET)
        return err("invalid source path or compressed-read budget",AVERROR(EINVAL));
    int fd=open(path,O_RDONLY|O_CLOEXEC);
    if(fd<0)return err("open local original",-errno);
    s->local.fd=fd;
    struct stat st;
    if(fstat(fd,&st)<0 || !S_ISREG(st.st_mode) || st.st_size<1)
        return err("source must be a local nonempty regular file",AVERROR(EINVAL));
    s->local.size=st.st_size;
    uint8_t *buffer=av_malloc(IO_BUFFER);
    if(!buffer)return err("allocate AVIO buffer",AVERROR(ENOMEM));
    s->avio=avio_alloc_context(buffer,IO_BUFFER,0,&s->local,local_read,NULL,local_seek);
    if(!s->avio){av_free(buffer);return err("avio_alloc_context",AVERROR(ENOMEM));}
    s->avio->seekable=AVIO_SEEKABLE_NORMAL;
    s->fmt=avformat_alloc_context();
    if(!s->fmt)return err("avformat_alloc_context",AVERROR(ENOMEM));
    s->fmt->pb=s->avio;
    s->fmt->flags |= AVFMT_FLAG_CUSTOM_IO;
    /* FFmpeg probes locally via our bounded pread-based AVIO; path never
       goes through URL handlers, remote protocols or Storage Fabric. */
    int rc=avformat_open_input(&s->fmt,NULL,NULL,NULL);
    if(rc<0)return err("avformat_open_input local IO",rc);
    rc=avformat_find_stream_info(s->fmt,NULL);
    if(rc<0)return err("avformat_find_stream_info",rc);
    if(s->local.over_budget)return err("source read budget exceeded",AVERROR(ENOSPC));
    if(!s->fmt->iformat || !s->fmt->iformat->name ||
       strstr(s->fmt->iformat->name,"ogg")==NULL)
        return err("not an Ogg container",AVERROR(EINVAL));
    return 0;
}
static int is_audio(const Source *s,uint32_t stream){
    return stream<s->fmt->nb_streams &&
       s->fmt->streams[stream]->codecpar->codec_type==AVMEDIA_TYPE_AUDIO;
}
static FILE *private_out(const char *path) {
    int fd=open(path,O_WRONLY|O_CREAT|O_EXCL|O_CLOEXEC,0600);
    if(fd<0){err("exclusive private output",-errno);return NULL;}
    FILE *f=fdopen(fd,"wb");
    if(!f){err("fdopen private output",-errno);close(fd);unlink(path);}
    return f;
}
/* Compact local metadata; caller can catalogue references, not raw bytes. */
int32_t spash_seek_catalogue(const char *path,const char *tsv,uint32_t read_budget_mb){
    last_err[0]=0;
    if(!tsv || !*tsv || !path || !strcmp(path,tsv))return err("invalid catalogue paths",AVERROR(EINVAL));
    uint64_t budget=(uint64_t)read_budget_mb*1024*1024;
    Source s;int ok=-1,created=0;FILE *f=NULL;
    if(open_source(&s,path,budget)<0)goto done;
    f=private_out(tsv);if(!f)goto done;
    created=1;
    fprintf(f,"schema\tspash.ogg.logical-stream-catalogue/2\n");
    fprintf(f,"stream_index\tcodec\tchannels\trate_hz\tstart_pts\tduration_pts\ttb_num\ttb_den\tbitrate_declared\n");
    for(unsigned i=0;i<s.fmt->nb_streams;++i){
        if(!is_audio(&s,i))continue;
        AVStream *st=s.fmt->streams[i];AVCodecParameters *p=st->codecpar;
        fprintf(f,"%u\t%s\t%d\t%d\t%"PRId64"\t%"PRId64"\t%d\t%d\t%"PRId64"\n",
             i,avcodec_get_name(p->codec_id),p->ch_layout.nb_channels,p->sample_rate,
             st->start_time,st->duration,st->time_base.num,st->time_base.den,p->bit_rate);
    }
    fprintf(f,"local_bytes_total\t%"PRId64"\ncompressed_bytes_read\t%"PRIu64"\nsource_residency\tLOCAL_ONLY\n",
           s.local.size,s.local.compressed_read);
    if(fflush(f)!=0){err("flush catalogue",-errno);goto done;}
    ok=0;
done:
    if(f)fclose(f);
    if(ok && created)unlink(tsv);
    close_source(&s);
    return ok;
}

typedef struct {
    SwrContext *swr;
    AVCodecContext *codec;
    FILE *out;
    AVStream *st;
    uint32_t physical_channel,rate;
    int input_rate,input_channels,input_format;
    int64_t start_pts,first_output,end_output,next_output;
    int first_frame;
    uint64_t samples_written,packet_count,frames_decoded;
    double peak;
    int64_t jitter_max;
} Extract;
static int admit(Extract *e,AVFrame *frame){
    if(frame->nb_samples<=0)return 0;
    if(frame->best_effort_timestamp==AV_NOPTS_VALUE)
        return err("missing frame presentation timestamp after seek",AVERROR_INVALIDDATA);
    if(frame->decode_error_flags)
        return err("decoded frame reports corruption",AVERROR_INVALIDDATA);
    if(frame->sample_rate<1 || frame->ch_layout.nb_channels<1 ||
       (unsigned)frame->ch_layout.nb_channels<=e->physical_channel)
        return err("missing selected physical channel",AVERROR(EINVAL));
    if(!e->swr){
        e->input_rate=frame->sample_rate;e->input_channels=frame->ch_layout.nb_channels;
        e->input_format=frame->format;
        AVChannelLayout mono;av_channel_layout_default(&mono,1);
        int rc=swr_alloc_set_opts2(&e->swr,&mono,AV_SAMPLE_FMT_FLT,(int)e->rate,
                   &frame->ch_layout,(enum AVSampleFormat)e->input_format,e->input_rate,0,NULL);
        av_channel_layout_uninit(&mono);
        if(rc<0 || !e->swr)return err("swr_alloc_set_opts2",rc<0?rc:AVERROR(ENOMEM));
        double *matrix=calloc((size_t)e->input_channels,sizeof *matrix);
        if(!matrix)return err("channel matrix allocation",AVERROR(ENOMEM));
        matrix[e->physical_channel]=1.0;
        rc=swr_set_matrix(e->swr,matrix,e->input_channels);
        free(matrix);if(rc<0)return err("swr_set_matrix",rc);
        rc=swr_init(e->swr);if(rc<0)return err("swr_init",rc);
    }else if(e->input_rate!=frame->sample_rate ||
              e->input_channels!=frame->ch_layout.nb_channels ||
              e->input_format!=frame->format)
        return err("source sample format changed within logical stream",AVERROR_INVALIDDATA);
    int64_t relative_pts=frame->best_effort_timestamp-e->start_pts;
    /* Preserve the whole-file resampling grid. At 44100 -> 8000 Hz, the
     * exact common grid has input period 441 and output period 80 samples.
     * Frame PTS near Vorbis block changes can jitter due to overlap. The
     * sample count, not each frame's PTS, advances the continuous grid.
     * Credit: Claude Opus 5.5, independent tp07 real-file qualification. */
    int skip=0;
    int64_t in_idx=av_rescale_q(relative_pts,e->st->time_base,(AVRational){1,e->input_rate});
    if(!e->first_frame){
        int64_t g=e->input_rate,h=e->rate;
        while(h){int64_t t=g%h;g=h;h=t;}
        int64_t P=e->input_rate/g,Q=e->rate/g;
        int64_t aligned=((in_idx+P-1)/P)*P;
        if(in_idx<0)aligned=((in_idx)/P)*P;
        skip=(int)(aligned-in_idx);
        if(skip>=frame->nb_samples)return 0;
        e->first_frame=1;e->next_output=(aligned/P)*Q;
        int64_t early=e->first_output-((int64_t)MAX_FIRST_FRAME_LEAD_MS*e->rate/1000);
        if(e->next_output>e->first_output || e->next_output<early)
            return err("random seek failed to land inside bounded pre-roll",AVERROR_INVALIDDATA);
    }else{
        int64_t frame_sample=av_rescale_q(relative_pts,e->st->time_base,(AVRational){1,(int)e->rate});
        int64_t delay=swr_get_delay(e->swr,(int)e->rate);
        int64_t jit=llabs(frame_sample-delay-e->next_output);
        if(jit>e->jitter_max)e->jitter_max=jit;
        if(jit>(int64_t)e->rate/20)
            return err("audio PTS discontinuity/chained stream requires new segment",AVERROR_INVALIDDATA);
    }
    const uint8_t *in[AV_NUM_DATA_POINTERS]={0};
    int bps=av_get_bytes_per_sample((enum AVSampleFormat)frame->format);
    if(bps<1)return err("invalid input sample format",AVERROR_INVALIDDATA);
    if(av_sample_fmt_is_planar((enum AVSampleFormat)frame->format)){
        for(int c=0;c<frame->ch_layout.nb_channels && c<AV_NUM_DATA_POINTERS;c++)
            in[c]=frame->extended_data[c]+(size_t)skip*bps;
    }else in[0]=frame->extended_data[0]+(size_t)skip*bps*frame->ch_layout.nb_channels;
    int in_n=frame->nb_samples-skip;
    int maxout=swr_get_out_samples(e->swr,in_n);
    if(maxout<1 || maxout>2000000)return err("invalid native resample bound",AVERROR(EINVAL));
    float *values=malloc((size_t)maxout*sizeof *values);
    if(!values)return err("resample buffer allocation",AVERROR(ENOMEM));
    uint8_t *dst[1]={(uint8_t*)values};
    int n=swr_convert(e->swr,dst,maxout,in,in_n);
    if(n<0){free(values);return err("swr_convert",n);}
    int64_t from=e->next_output,until=from+n;
    int64_t low=from>e->first_output?from:e->first_output;
    int64_t high=until<e->end_output?until:e->end_output;
    if(high>low){
        size_t off=(size_t)(low-from), count=(size_t)(high-low);
        for(size_t i=off;i<off+count;++i){
            if(!isfinite(values[i])){free(values);return err("nonfinite audio sample",AVERROR_INVALIDDATA);}
            double a=fabs(values[i]);if(a>e->peak)e->peak=a;
        }
        if(fwrite(values+off,sizeof *values,count,e->out)!=count){
            free(values);return err("write decoded audio",AVERROR(EIO));}
        e->samples_written+=count;
    }
    e->next_output=until;e->frames_decoded++;free(values);return 0;
}

/* Seek into selected Ogg logical audio stream, emit only selected channel and
 * requested range; fail instead of forward-decoding from file origin.
 * Return 0 ONLY if all requested samples are present with PTS continuity.
 * This is an experimental seek and resampling implementation until qualified
 * against independent original Ogg timestamps and channel-reference fixtures.
 */
int32_t spash_seek_decode_f32(const char *path,const char *out,const char *report,
                              uint32_t stream_index,uint32_t channel,
                              uint32_t start_ms,uint32_t duration_ms,
                              uint32_t target_rate,uint32_t read_budget_mb){
    last_err[0]=0;
    if(!path || !out || !report || !*path || !*out || !*report ||
       !strcmp(path,out) || !strcmp(path,report) || !strcmp(out,report) ||
       duration_ms<1 || duration_ms>MAX_WINDOW_MS || channel>31 ||
       (target_rate!=8000 && target_rate!=16000 && target_rate!=48000))
       return err("invalid exact bounded seek arguments",AVERROR(EINVAL));
    Source s;int status=-1,created=0,report_created=0;
    FILE *f=NULL,*r=NULL;
    AVCodecContext *decoder=NULL;AVPacket *pkt=NULL;AVFrame *frame=NULL;
    Extract e={0};int rc=0,early_end=0;
    uint64_t budget=(uint64_t)read_budget_mb*1024*1024;
    if(open_source(&s,path,budget)<0)goto done;
    if(!is_audio(&s,stream_index)){err("requested Ogg logical audio stream absent",AVERROR_STREAM_NOT_FOUND);goto done;}
    AVStream *st=s.fmt->streams[stream_index];
    if(st->time_base.num<1 || st->time_base.den<1 || st->codecpar->sample_rate<1 ||
       st->codecpar->ch_layout.nb_channels<=0 ||
       channel>=(uint32_t)st->codecpar->ch_layout.nb_channels){
       err("stream time base or physical channel invalid",AVERROR_INVALIDDATA);goto done;}
    const AVCodec *dec=avcodec_find_decoder(st->codecpar->codec_id);
    if(!dec){err("native codec unavailable",AVERROR_DECODER_NOT_FOUND);goto done;}
    decoder=avcodec_alloc_context3(dec);
    if(!decoder){err("codec context allocation",AVERROR(ENOMEM));goto done;}
    rc=avcodec_parameters_to_context(decoder,st->codecpar);
    if(rc<0){err("codec parameters",rc);goto done;}
    rc=avcodec_open2(decoder,dec,NULL);
    if(rc<0){err("codec open",rc);goto done;}
    int64_t stream_start=st->start_time==AV_NOPTS_VALUE?0:st->start_time;
    int64_t seek_ms=(int64_t)start_ms>PREROLL_MS?(int64_t)start_ms-PREROLL_MS:0;
    int64_t seek_ts=av_rescale_q(seek_ms,(AVRational){1,1000},st->time_base)+stream_start;
    /* This is actual byte-seeking via the Ogg demuxer's page/granule search,
       not a decode-from-zero sample skip. Reject failure and read budget overruns. */
    rc=av_seek_frame(s.fmt,(int)stream_index,seek_ts,AVSEEK_FLAG_BACKWARD);
    if(rc<0){err("demuxer direct seek",rc);goto done;}
    int64_t byte_after_seek=avio_tell(s.fmt->pb);
    avcodec_flush_buffers(decoder);
    f=private_out(out);if(!f)goto done;created=1;
    pkt=av_packet_alloc();frame=av_frame_alloc();
    if(!pkt || !frame){err("packet/frame allocation",AVERROR(ENOMEM));goto done;}
    e.codec=decoder;e.st=st;e.out=f;e.rate=target_rate;
    e.physical_channel=channel;e.start_pts=stream_start;
    e.first_output=((int64_t)start_ms*target_rate)/1000;
    e.end_output=(((int64_t)start_ms+duration_ms)*target_rate)/1000;
    uint64_t required=(uint64_t)(e.end_output-e.first_output);
    while((rc=av_read_frame(s.fmt,pkt))>=0){
        if(pkt->stream_index==(int)stream_index){
            if(++e.packet_count>MAX_PACKETS){err("bounded post-seek packet budget exceeded",AVERROR(ENOSPC));av_packet_unref(pkt);goto done;}
            int sent=avcodec_send_packet(decoder,pkt);
            if(sent<0){err("avcodec_send_packet",sent);av_packet_unref(pkt);goto done;}
            while((sent=avcodec_receive_frame(decoder,frame))>=0){
                if(admit(&e,frame)<0){av_frame_unref(frame);av_packet_unref(pkt);goto done;}
                av_frame_unref(frame);
                if(e.samples_written>=required){early_end=1;break;}
                if(e.first_frame && e.next_output>e.end_output+(int64_t)target_rate){
                    err("requested audio interval has a PTS hole",AVERROR_INVALIDDATA);av_packet_unref(pkt);goto done;}
            }
            if(sent<0 && sent!=AVERROR(EAGAIN) && sent!=AVERROR_EOF){
                err("avcodec_receive_frame",sent);av_packet_unref(pkt);goto done;}
        }
        av_packet_unref(pkt);
        if(early_end)break;
    }
    if(s.local.over_budget){err("source compressed-byte read budget exceeded",AVERROR(ENOSPC));goto done;}
    if(rc<0 && rc!=AVERROR_EOF){err("post-seek av_read_frame",rc);goto done;}
    /* At an actual file edge, release delayed codec and resampler samples;
       do NOT silently pad a missing extent with zeros. */
    if(rc==AVERROR_EOF && e.samples_written<required){
        int sent=avcodec_send_packet(decoder,NULL);
        if(sent<0 && sent!=AVERROR_EOF){err("codec EOF flush",sent);goto done;}
        while((sent=avcodec_receive_frame(decoder,frame))>=0){
            if(admit(&e,frame)<0){av_frame_unref(frame);goto done;}
            av_frame_unref(frame);
            if(e.samples_written==required)break;
        }
        if(sent<0 && sent!=AVERROR_EOF && sent!=AVERROR(EAGAIN)){
            err("codec tail receive",sent);goto done;
        }
        if(e.swr && e.samples_written<required){
            int maxout=swr_get_out_samples(e.swr,0);
            if(maxout<0 || maxout>2000000){err("resampler flush bound",AVERROR_INVALIDDATA);goto done;}
            if(maxout>0){
                float *tail=malloc((size_t)maxout*sizeof *tail);
                if(!tail){err("resampler tail allocation",AVERROR(ENOMEM));goto done;}
                uint8_t *dst[1]={(uint8_t*)tail};
                int n=swr_convert(e.swr,dst,maxout,NULL,0);
                if(n<0){free(tail);err("resampler tail conversion",n);goto done;}
                int64_t from=e.next_output,until=from+n;
                int64_t low=from>e.first_output?from:e.first_output;
                int64_t high=until<e.end_output?until:e.end_output;
                if(high>low){
                    size_t off=(size_t)(low-from),count=(size_t)(high-low);
                    for(size_t i=off;i<off+count;++i){
                        if(!isfinite(tail[i])){free(tail);err("nonfinite resampler tail",AVERROR_INVALIDDATA);goto done;}
                        double a=fabs(tail[i]);if(a>e.peak)e.peak=a;
                    }
                    if(fwrite(tail+off,sizeof *tail,count,f)!=count){free(tail);err("write resampler tail",AVERROR(EIO));goto done;}
                    e.samples_written+=count;
                }
                free(tail);
            }
        }
    }
    if(e.samples_written!=required){err("source ended or gap before exact requested audio",AVERROR_EOF);goto done;}
    if(fflush(f)!=0){err("flush private f32",-errno);goto done;}
    r=private_out(report);if(!r)goto done;report_created=1;
    fprintf(r,"schema\tspash.ogg.random-seek-extent/2\n");
    fprintf(r,"stream_index\t%u\nphysical_channel_zero_based\t%u\nstart_ms\t%u\nduration_ms\t%u\n",
           stream_index,channel,start_ms,duration_ms);
    fprintf(r,"input_rate_hz\t%d\ntarget_rate_hz\t%u\noutput_samples\t%"PRIu64"\npeak_abs\t%.9g\n",
           e.input_rate,target_rate,e.samples_written,e.peak);
    fprintf(r,"compressed_file_size_bytes\t%"PRId64"\ncompressed_bytes_fetched\t%"PRIu64"\n",
           s.local.size,s.local.compressed_read);
    fprintf(r,"local_read_calls\t%"PRIu64"\nlocal_seeks\t%"PRIu64"\nseek_byte_after\t%"PRId64"\n",
           s.local.read_calls,s.local.seek_calls,byte_after_seek);
    fprintf(r,"selected_packets_decoded\t%"PRIu64"\nselected_frames_decoded\t%"PRIu64"\n",
           e.packet_count,e.frames_decoded);
    fprintf(r,"pts_jitter_max_output_samples\t%lld\n",(long long)e.jitter_max);
    fprintf(r,"source_io\tLOCAL_PREAD_ONLY\nclock_authority\tAUDIO_STREAM_PTS_ONLY\nchained_segment_qualified\tNO\n");
    if(fflush(r)!=0){err("flush private report",-errno);goto done;}
    status=0;
done:
    if(r)fclose(r);
    if(f)fclose(f);
    if(status!=0){if(report_created)unlink(report);if(created)unlink(out);}
    swr_free(&e.swr);
    av_frame_free(&frame);av_packet_free(&pkt);avcodec_free_context(&decoder);
    close_source(&s);
    return status;
}