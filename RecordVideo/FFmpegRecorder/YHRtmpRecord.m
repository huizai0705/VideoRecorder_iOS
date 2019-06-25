//
//  YHRtmpRecord.m
//  RecordVideo
//
//  Created by huizai on 2019/5/24.
//  Copyright © 2019 huizai. All rights reserved.
//
//  作者Github址: https://github.com/huizai0705/VideoRecorder_iOS
//  作者CSDN博客地址: https://blog.csdn.net/m0_37677536
//
//

#import "YHRtmpRecord.h"
#import "YHToastHUD.h"

// enable/disable swresample usage
#define USE_SWRESAMPLE      1
// enable/disable avresample usage
#define USE_AVRESAMPLE      0
// enable/disable libsamplerate usage
#define USE_LIBSAMPLERATE   0
#define AV_ALIGN            1

typedef enum AVCodecID AVCodecID;
typedef enum AVPixelFormat AVPixelFormat;
typedef enum AVMediaType AVMediaType;


@implementation YHRtmpRecord
{
    const char * outFilePath;
    volatile BOOL running;
    int audio_bitrate;     // kbit
    int audio_samplerate;  // HZ
    int audio_channels;
    
    int video_bitrate;     // kbit
    int video_width;
    int video_height;
    int video_framerate;
    
    int audio_frame_count;
    int video_frame_count;
    
    AVCodecID audio_codec_id;
    AVCodecID video_codec_id;
    
#if USE_SWRESAMPLE
    struct SwrContext *swrc;
#elif USE_AVRESAMPLE
    struct AVAudioResampleContext * swrc;
#endif /* USE_SWRESAMPLE */
    uint8_t **src_samples_data;
    int src_samples;
    int src_samples_size;
    
    uint8_t **dst_samples_data;
    int dst_samples;
    int dst_samples_size;
    
    AVFrame *audio_frame;
    AVFrame *video_frame;
    AVFrame *video_frame_filtered;
    
    AVStream *audio_st;
    AVStream *video_st;
    
    AVCodecContext *ac;
    AVCodecContext *vc;
    
    AVFormatContext *fmt_context;
    AVPixelFormat pixelformat;
    NSLock *avcodecLock;
    NSLock *writeLock;
    
    AVFilterContext *buffersink_ctx;
    AVFilterContext *buffersrc_ctx;
    AVFilterGraph *filter_graph;
}

- (void) Reset {
    audio_frame_count = 0;
    video_frame_count = 0;
    
#if USE_SWRESAMPLE || USE_AVRESAMPLE
    swrc = NULL;
#endif /* USE_SWRESAMPLE || USE_AVRESAMPLE */
    dst_samples_data = NULL;
    src_samples_data = NULL;
    
    audio_frame = NULL;
    video_frame = NULL;
    video_frame_filtered = NULL;
    
    audio_st = NULL;
    video_st = NULL;
    fmt_context = NULL;
    
    buffersink_ctx = NULL;
    buffersrc_ctx = NULL;
    filter_graph = NULL;
}

- (BOOL) initParameters {
    avcodecLock = [[NSLock alloc] init];
    writeLock = [[NSLock alloc] init];
    
    //video
    pixelformat      = AV_PIX_FMT_YUV420P;
    video_width      = 720;
    video_height     = 1280;
    video_framerate  = 15;
    video_bitrate    = 1000;
    
    //auido
    audio_samplerate = 44100;
    audio_channels   = 1;
    audio_bitrate    = 64;
    
    [self Reset];
    running = FALSE;
    
    /* Initialize libavcodec, and register
     all codecs and formats */
    av_register_all();
    avfilter_register_all();
    avformat_network_init();
    
    return TRUE;
}

- (AVCodecID) GetCodecId:(const char*) codec_name {
    AVCodec *codec = avcodec_find_encoder_by_name(codec_name);
    if(codec) {
        return codec->id;
    }
    return AV_CODEC_ID_NONE;
}

- (BOOL) startRecord: (NSString *)outPath withW:(int)width withH:(int)height {
    if(running) {
        NSLog( @"recorder is running");
        return TRUE;
    }
    if (outPath == nil && outPath.length < 5) {
        [YHToastHUD showToast:@"推流地址不正确" completion:^{
        }];
        return FALSE;
    }
    outFilePath  = [outPath UTF8String];
    if(width > 0 && width != video_width) {
        video_width  = width;
    }
    if(height > 0 && height != video_height) {
        video_height = height;
    }
    
    // codecs
    audio_codec_id = [self GetCodecId:"aac"];
    video_codec_id = [self GetCodecId:"h264_videotoolbox"]; //“libx264”
    if(audio_codec_id == AV_CODEC_ID_NONE || video_codec_id == AV_CODEC_ID_NONE) {
        NSLog( @"recorder config codec failed");
        return FALSE;
    }
    
    if(![self InitRecorder]) {
        NSLog( @"recorder init failed");
        [self stopRecordPrivate];
        return FALSE;
    }
    
    if (![self InitFilters]) {
        NSLog( @"filter init failed");
        avfilter_graph_free(&filter_graph);
        [self stopRecordPrivate];
        return FALSE;
    }
    running = TRUE;
    return TRUE;
}

- (void) stopRecordPrivate {
    
    [avcodecLock lock];
    if(audio_st) {
        avcodec_close(ac);
    }
    if(video_st) {
        avcodec_close(vc);
    }
    [avcodecLock unlock];
    
    if(fmt_context) {
        // close the output file
        if(fmt_context->pb && fmt_context->oformat
           && !(fmt_context->oformat->flags & AVFMT_NOFILE)) {
            avio_close(fmt_context->pb);
        }
        // free the stream
        avformat_free_context(fmt_context);
    }
    
#if USE_SWRESAMPLE
    if(swrc) {
        swr_free(&swrc);
    }
#elif USE_AVRESAMPLE
    if(swrc) {
        avresample_free(&swrc);
    }
#endif /* USE_SWRESAMPLE */
    
    if(dst_samples_data) {
        if(src_samples_data && dst_samples_data[0] &&
           src_samples_data[0] != dst_samples_data[0]) {
            av_free(dst_samples_data[0]);
        }
        av_free(dst_samples_data);
    }
    if(src_samples_data) {
        if(src_samples_data[0]) {
            av_free(src_samples_data[0]);
        }
        av_free(src_samples_data);
    }
    if(audio_frame) {
        av_frame_free(&audio_frame);
    }
    if(video_frame) {
        av_frame_free(&video_frame);
    }
    if (video_frame_filtered) {
        av_frame_free(&video_frame_filtered);
    }
    
    [self Reset];
}

- (void) stopRecord {
    if(!running) {
        NSLog( @"recorder is stopped");
        return;
    }
    running = FALSE;
    [self DeInitFilters];
    [self stopRecordPrivate];
    return;
}

- (BOOL) InitRecorder {
    int ret = 0;
    AVDictionary *opt = NULL;
    AVOutputFormat *fmt = NULL;
    
    // Allocate the output media context
    avformat_alloc_output_context2(&fmt_context, NULL,
                                   "flv", outFilePath);
    if (!fmt_context) {
        NSLog( @"avformat_alloc_output_context2 failed");
        return FALSE;
    }
    if(!(fmt = fmt_context->oformat)) {
        NSLog( @"Request 'mp4' is not suitable output format");
        return FALSE;
    }
    // Set audio code identifier
    fmt->audio_codec = audio_codec_id;
    // Add audio stream and initialize audio codec
    audio_st = [self AddStream: AVMEDIA_TYPE_AUDIO];
    
    // Set video code identifier
    fmt->video_codec = video_codec_id;
    // Add video stream and initialize video codec
    video_st = [self AddStream: AVMEDIA_TYPE_VIDEO];
    
    if(audio_st && ![self OpenAudio]) {
        return FALSE;
    }
    if(video_st && ![self OpenVideo]) {
        return FALSE;
    }
    //av_dump_format(fmt_context, 0, outFilePath, 1);
    
    if (av_dict_set(&opt, "movflags", "faststart", 0) < 0) {
        NSLog( @"set 'faststart' pram failed");
    }
    // open the output file, if needed
    if (!(fmt_context->flags & AVFMT_NOFILE)) {
        NSLog( @"call avio_open2");
        ret = avio_open2(&fmt_context->pb, outFilePath,
                         AVIO_FLAG_WRITE, NULL, &opt);
        if(ret < 0) {
            NSLog( @"could not open output file");
            return FALSE;
        }
    }
    
    // write the stream header
    ret = avformat_write_header(fmt_context, &opt);
    av_dict_free(&opt);
    if(ret < 0) {
        NSLog( @"avformat write header failed");
        return FALSE;
    }
    return TRUE;
}

- (AVStream*) AddStream: (AVMediaType) codec_type {
    AVOutputFormat *fmt = fmt_context->oformat;
    AVCodecContext *c = NULL;
    AVCodec *codec = NULL;
    AVStream *st = NULL;
    
    // find the encoder
    if(codec_type == AVMEDIA_TYPE_AUDIO) {
        codec = avcodec_find_encoder(fmt->audio_codec);
    } else if(codec_type == AVMEDIA_TYPE_VIDEO) {
        codec = avcodec_find_encoder(fmt->video_codec);
    }
    
    if(codec == NULL) {
        NSLog( @"could not find encoder");
        return NULL;
    }
    
    st = avformat_new_stream(fmt_context, codec);
    if(st == NULL) {
        NSLog( @"could not allocate stream");
        return NULL;
    }
    st->id = fmt_context->nb_streams - 1;
    c = avcodec_alloc_context3(codec);
    avcodec_parameters_from_context(st->codecpar,c);
    c->codec = codec;
    
    if(codec_type == AVMEDIA_TYPE_AUDIO) {
        if(codec->id == AV_CODEC_ID_PCM_S16LE) {
            c->sample_fmt  = AV_SAMPLE_FMT_S16;
        } else {
#if LIBAVCODEC_VERSION_INT < AV_VERSION_INT(55, 0, 0)
            c->sample_fmt  = AV_SAMPLE_FMT_FLT;
#else
            c->sample_fmt  = AV_SAMPLE_FMT_FLTP;
#endif /* LIBAVCODEC_VERSION_INT < AV_VERSION_INT(55, 0, 0) */
        }
        c->codec_id      = codec->id;
        c->bit_rate      = audio_bitrate * audio_channels * 1000;
        c->sample_rate   = audio_samplerate;
        c->channels      = audio_channels;
        c->channel_layout= YH_AV_CH_Layout_Selector[c->channels];
        st->time_base    = (AVRational){1, audio_samplerate};
        //c->time_base     = st->time_base;
        ac = c;
    } else if(codec_type == AVMEDIA_TYPE_VIDEO) {
        c->pix_fmt       = pixelformat;
        c->codec_id      = codec->id;
        c->bit_rate      = video_bitrate * 1000;
        c->width         = video_width;
        c->height        = video_height;
        c->qmin          = 20;
        c->qmax          = 45;
        c->gop_size      = video_framerate * 3;
        st->time_base    = (AVRational){1, video_framerate*2};
        c->time_base     = st->time_base;
        if(c->codec->id == AV_CODEC_ID_H264) {
            av_opt_set(c->priv_data, "preset", "ultrafast", 0);
            av_opt_set(c->priv_data, "tune", "zerolatency", 0);
            c->max_b_frames = 0;
        }
        vc = c;
    }
    
    // Some formats want stream headers to be separate
    if(fmt->flags & AVFMT_GLOBALHEADER)
        c->flags |= CODEC_FLAG_GLOBAL_HEADER;
    return st;
}

- (BOOL) OpenAudio {
    AVCodecContext *c = ac;//audio_st->codec;
    int nb_samples = 0;
    int ret = 0;
    
    // open codec
    [avcodecLock lock];
    ret = avcodec_open2(c, c->codec, NULL);
    [avcodecLock unlock];
    if(ret < 0) {
        char err[1024] = { 0 };
        av_strerror(ret, err, sizeof(err) - 1);
        NSLog( @"could not open audio codec:%s",err);
        return FALSE;
    }
    
    if(c->codec->capabilities & AV_CODEC_CAP_VARIABLE_FRAME_SIZE) {
        nb_samples = 10000;
    } else {
        nb_samples = c->frame_size;
    }
    AVFrame *frame = av_frame_alloc();
    if(frame == NULL) {
        NSLog( @"could not allocate audio frame");
        return FALSE;
    }
    frame->format         = c->sample_fmt;
    frame->channel_layout = c->channel_layout;
    frame->sample_rate    = c->sample_rate;
    frame->nb_samples     = nb_samples;
    audio_frame           = frame;
    
    ret = avcodec_parameters_from_context(audio_st->codecpar, c);
    if (ret < 0) {
        NSLog( @"could not copy the stream parameters");
        return FALSE;
    }
    return [self OpenResampler];
}

- (BOOL) copyAudio: (const char*) pcmBuffer
    withBufferSize: (int) pcmBufferSize
        withFrames: (int)numFrames {
    if(!running) {
        return FALSE;
    } else {
        if(numFrames != src_samples) {
            NSString *log = [NSString stringWithFormat: @"samples error: %d_%d",
                             numFrames, src_samples];
            NSLog(@"%@",log);
            return FALSE;
        }
        memcpy(src_samples_data[0], pcmBuffer, src_samples_size);
        return TRUE;
    }
}

- (BOOL) writeAudio: (int)numFrames withPTS: (int64_t) intPTS {
    if(!running) {
        return FALSE;
    }
    
    AVCodecContext *c = ac;
    int ret = 0;
    AVPacket pkt = { 0 };
    av_init_packet(&pkt);
    
    // first, increase the counter, set PTS for packet
    audio_frame->pts = audio_frame_count;
    if(![self Resampler]) {
        NSLog( @"error while resampler");
        return FALSE;
    }
    
    audio_frame->nb_samples = dst_samples;
    avcodec_fill_audio_frame(audio_frame, c->channels, c->sample_fmt,
                             dst_samples_data[0], dst_samples_size, AV_ALIGN);
    ret = avcodec_send_frame(ac, audio_frame);
    if (ret != 0){
        NSLog( @"error send_frame audio frame");
        return FALSE;
    }
    ret = avcodec_receive_packet(ac, &pkt);
    if(ret < 0) {
        NSLog( @"error receive_packet audio frame");
        return FALSE;
    }
    
    audio_frame_count += numFrames;
    ret = [self WritePacket:audio_st withPacket:&pkt];
    av_packet_unref(&pkt);
    if(ret < 0) {
        NSLog(@"error while writing audio frame");
        return FALSE;
    }
    return TRUE;
}

- (BOOL) OpenVideo {
    AVCodecContext *c = vc;//video_st->codec;
    AVDictionary *opt = NULL;
    int ret = 0;
    
    // open the codec
    [avcodecLock lock];
    if(c->codec->id == AV_CODEC_ID_H264) {
        if (av_dict_set(&opt, "profile", "high", 0) < 0) {
            NSLog( @"set 'profile' pram failed");
        }
    }
    ret = avcodec_open2(c, c->codec, &opt);
    av_dict_free(&opt);
    [avcodecLock unlock];
    if(ret < 0) {
        NSLog( @"could not open video codec");
        return FALSE;
    }
    
    video_frame = av_frame_alloc();
    if (video_frame == NULL) {
        NSLog( @"could not alloc video frame");
        return FALSE;
    }
    
    unsigned char* frame_buffer_in = (unsigned char*)av_malloc(av_image_get_buffer_size(AV_PIX_FMT_YUV420P, c->width, c->height, 1));
    av_image_fill_arrays(video_frame->data, video_frame->linesize, frame_buffer_in, AV_PIX_FMT_YUV420P, c->width, c->height, 1);
    
    video_frame->width  = c->width;
    video_frame->height = c->height;
    video_frame->format = c->pix_fmt;
    
    video_frame_filtered = av_frame_alloc();
    if (video_frame_filtered == NULL) {
        NSLog( @"could not alloc video frame filter");
        return FALSE;
    }
    
    ret = avcodec_parameters_from_context(video_st->codecpar, c);
    if(ret < 0) {
        NSLog( @"could not copy the stream parameters");
        return FALSE;
    }
    return TRUE;
}

- (BOOL) copyVideo: (UInt8*)pY withUV: (UInt8*)pUV withYSize: (int)yBs withUVSize: (int)uvBs {
    if(!running) {
        return FALSE;
    } else {
        /* change format from nv12 to 420p */
        UInt8* pU = video_frame->data[1];
        UInt8* pV = video_frame->data[2];
        memcpy(video_frame->data[0], pY,  yBs );
        for (int j = 0; j < video_height / 2; j++) {
            for (int i = 0; i < video_width / 2; i++) {
                *pU++ = *pUV++;
                *pV++ = *pUV++;
            }
        }
        video_frame->pts = video_frame_count;
        return TRUE;
    }
}

- (BOOL) writeVideo: (int64_t)intPTS {
    /**
     *   Notice:
     *
     *   1. Can not av_frame_unref(video_frame)
     *      the method will release all the memory
     *
     *   2. Can av_frame_unref(video_frame_filtered)
     *      because av_buffersink_get_frame will auto allocate memroy
     */
    if(!running) {
        return FALSE;
    } else {
        /* add warter mark */
        if (av_buffersrc_add_frame(buffersrc_ctx, video_frame) < 0) {
            NSLog( @"error add frame to buffer src");
            return FALSE;
        }
        
        if (av_buffersink_get_frame(buffersink_ctx, video_frame_filtered) < 0) {
            NSLog( @"error get frame");
            av_frame_unref(video_frame_filtered);
            return FALSE;
        }
        
        int ret = 0;
        AVPacket pkt = { 0 };
        av_init_packet(&pkt);
        
        ret = avcodec_send_frame(vc, video_frame_filtered);
        if (ret != 0){
            NSLog( @"error send_frame");
        }
        ret = avcodec_receive_packet(vc, &pkt);
        // if size is zero, it means the image was buffered
        if(ret < 0) {
            NSString* errorinfo = [NSString stringWithFormat:@"error receive_packet video frame, ret : %d", ret];
            char err[1024] = { 0 };
            av_strerror(ret, err, sizeof(err) - 1);
            NSLog( @"%@:%s",errorinfo,err);
            av_packet_unref(&pkt);
            av_frame_unref(video_frame_filtered);
            return FALSE;
        }
        
        video_frame_count++;
        
        ret = [self WritePacket: video_st withPacket: &pkt];
        av_packet_unref(&pkt);
        if(ret < 0) {
            NSLog( @"error while writing video frame");
            av_frame_unref(video_frame_filtered);
            return FALSE;
        }
        av_frame_unref(video_frame_filtered);
        return TRUE;
    }
}

- (BOOL) OpenResampler {
    AVCodecContext *c = ac;//audio_st->codec;
    int ret = 0;
    
    // check resampler
    if(USE_SWRESAMPLE == 0 && USE_AVRESAMPLE == 0 && c->sample_fmt == AV_SAMPLE_FMT_FLTP) {
        NSLog( @"resampler not found");
        return FALSE;
    }
    
    // set frame size
    if(c->frame_size == 0) {//audio_st->codec->time_base
        c->frame_size = c->sample_rate * av_q2d(ac->time_base);
    }
    
    src_samples = c->frame_size;
    src_samples_size = av_samples_get_buffer_size(NULL, c->channels, src_samples, AV_SAMPLE_FMT_S16, AV_ALIGN);
    src_samples_data = (uint8_t **)av_malloc(c->channels * sizeof(uint8_t *));
    ret = av_samples_alloc(src_samples_data, NULL, c->channels, src_samples,
                           AV_SAMPLE_FMT_S16, AV_ALIGN);
    if(ret < 0) {
        NSLog( @"could not allocate source samples");
        return FALSE;
    }
    
#if USE_SWRESAMPLE || USE_AVRESAMPLE
    // create resampler context
    if(c->sample_fmt == AV_SAMPLE_FMT_FLTP)
    {
#if USE_SWRESAMPLE
        swrc = swr_alloc();
#elif USE_AVRESAMPLE
        swrc = avresample_alloc_context();
#endif /* USE_SWRESAMPLE */
        if(swrc == NULL) {
            NSLog( @"could not allocate resampler context");
            return FALSE;
        }
        
        // set options
        av_opt_set_int(swrc, "in_sample_fmt",       AV_SAMPLE_FMT_S16,  0);
        av_opt_set_int(swrc, "in_sample_rate",      c->sample_rate,     0);
        av_opt_set_int(swrc, "in_channel_count",    c->channels,        0);
        av_opt_set_int(swrc, "in_channel_layout",   c->channel_layout,  0);
        av_opt_set_int(swrc, "out_sample_fmt",      c->sample_fmt,      0);
        av_opt_set_int(swrc, "out_sample_rate",     c->sample_rate,     0);
        av_opt_set_int(swrc, "out_channel_count",   c->channels,        0);
        av_opt_set_int(swrc, "out_channel_layout",  c->channel_layout,  0);
        
        // initialize the resampling context
#if USE_SWRESAMPLE
        ret = swr_init(swrc);
#elif USE_AVRESAMPLE
        ret = avresample_open(swrc);
#endif /* USE_SWRESAMPLE */
        if(ret < 0) {
            NSLog( @"failed to initialize the resampling context");
            return FALSE;
        }
    }
#endif /* USE_SWRESAMPLE or USE_AVRESAMPLE */
    
    // allocate destination samples
    dst_samples = src_samples;
    dst_samples_size = av_samples_get_buffer_size(NULL, c->channels, dst_samples,
                                                  c->sample_fmt, AV_ALIGN);
    dst_samples_data = (uint8_t **)av_malloc(c->channels * sizeof(uint8_t *));
    ret = av_samples_alloc(dst_samples_data, NULL, c->channels, dst_samples,
                           c->sample_fmt, AV_ALIGN);
    if(ret < 0) {
        NSLog(@"could not allocate destination samples");
        return FALSE;
    }
    if(c->sample_fmt == AV_SAMPLE_FMT_S16) {
        av_free(dst_samples_data[0]);
    }
    return TRUE;
}

- (BOOL) Resampler {
    AVCodecContext *c = ac;//audio_st->codec;
    int ret = 0;
    
    // convert to destination format
    if(c->sample_fmt == AV_SAMPLE_FMT_S16) {
        dst_samples = src_samples;
        dst_samples_size = src_samples_size;
        dst_samples_data[0] = src_samples_data[0];
    } else if(c->sample_fmt == AV_SAMPLE_FMT_FLT) {
        for(int i = 0; i < src_samples * c->channels; ++i)
            ((float *)dst_samples_data[0])[i] = ((int16_t *)src_samples_data[0])[i] * (1.0 / (1<<15));
    } else {
        // convert samples from native format to destination codec format, using the resampler
#if USE_SWRESAMPLE
        ret = swr_convert(swrc, dst_samples_data, dst_samples, (const uint8_t **)src_samples_data, src_samples);
#elif USE_AVRESAMPLE
        ret = avresample_convert(swrc, dst_samples_data, dst_samples_size, dst_samples, (uint8_t **)src_samples_data, src_samples_size, src_samples);
#endif /* USE_SWRESAMPLE */
        if(ret < 0) {
            NSLog(@"error while converting");
            return FALSE;
        }
    }
    return TRUE;
}

- (int) WritePacket:(AVStream *)st withPacket:(AVPacket *)pkt {
    int ret = 0;
    if (st->codecpar->codec_id == audio_codec_id) {
        av_packet_rescale_ts(pkt, ac->time_base, st->time_base);
    }else{
        av_packet_rescale_ts(pkt, vc->time_base, st->time_base);
    }
    pkt->stream_index = st->index;
    
    // write the compressed frame to the media file
    [writeLock lock];
    ret = av_write_frame(fmt_context, pkt);
    [writeLock unlock];
    return ret;
}

- (BOOL) InitFilters {
    char args[512];
    int ret;
    AVFilter *buffersrc  = avfilter_get_by_name("buffer");
    if (!buffersrc) {
        NSLog( @"get buffer src avfilter failed");
        return NO;
    }
    
    AVFilter *buffersink = avfilter_get_by_name("buffersink");
    if (!buffersink) {
        NSLog( @"get buffer sink avfilter failed");
        return NO;
    }
    
    AVFilterInOut *outputs = avfilter_inout_alloc();
    AVFilterInOut *inputs  = avfilter_inout_alloc();
    enum AVPixelFormat pix_fmts[] = { AV_PIX_FMT_YUV420P, AV_PIX_FMT_NONE };
    AVBufferSinkParams *buffersink_params;
    
    NSLog( @"In InitFilters");
    
    NSString* buffersrcinfo = [NSString stringWithFormat:@"buffer src info : %s", buffersrc->description];
    NSLog(@"%@",buffersrcinfo);
    NSString* buffersinkinfo = [NSString stringWithFormat:@"buffer sink info : %s", buffersink->description];
    NSLog(@"%@",buffersinkinfo);
    
    filter_graph = avfilter_graph_alloc();
    
    if (!video_st) {
        NSLog( @"Init filter failed, must init video stream first");
        return NO;
    }
    
    AVCodecContext *pCodecCtx = vc;//video_st->codec;
    /* buffer video source: the decoded frames from the decoder will be inserted here. */
    snprintf(args, sizeof(args),
             "video_size=%dx%d:pix_fmt=%d:time_base=%d/%d:pixel_aspect=%d/%d",
             pCodecCtx->width, pCodecCtx->height, pCodecCtx->pix_fmt,
             pCodecCtx->time_base.num, pCodecCtx->time_base.den,
             pCodecCtx->sample_aspect_ratio.num, pCodecCtx->sample_aspect_ratio.den);
    
    NSString* argstr = [NSString stringWithFormat:@"argument : %s", args];
    NSLog(@"%@", argstr);
    
    ret = avfilter_graph_create_filter(&buffersrc_ctx, buffersrc, "in",
                                       args, NULL, filter_graph);
    if (ret < 0) {
        NSString* errinfo = [NSString stringWithFormat:@"Cannot create buffer source, ret : %d", ret];
        NSLog(@"%@", errinfo);
        return NO;
    }
    
    /* buffer video sink: to terminate the filter chain. */
    buffersink_params = av_buffersink_params_alloc();
    buffersink_params->pixel_fmts = pix_fmts;
    ret = avfilter_graph_create_filter(&buffersink_ctx, buffersink, "out",
                                       NULL, buffersink_params, filter_graph);
    av_free(buffersink_params);
    if (ret < 0) {
        NSLog( @"Cannot create buffer sink");
        return NO;
    }
    
    /* Endpoints for the filter graph. */
    outputs->name       = av_strdup("in");
    outputs->filter_ctx = buffersrc_ctx;
    outputs->pad_idx    = 0;
    outputs->next       = NULL;
    
    inputs->name       = av_strdup("out");
    inputs->filter_ctx = buffersink_ctx;
    inputs->pad_idx    = 0;
    inputs->next       = NULL;
    
    NSString *wmpath = [[NSBundle mainBundle] pathForResource:@"watermark" ofType:@"bmp"];
    if (wmpath) {
        NSLog(@"%@", wmpath);
    } else {
        NSLog( @"Can not get resource path");
        avfilter_inout_free(&inputs);
        avfilter_inout_free(&outputs);
        return NO;
    }
    
    NSString* nsfilter_descr = [NSString stringWithFormat:@"movie=%@[wm];[in][wm]overlay=24:24[out]", wmpath];
    
    NSLog(@"%@", nsfilter_descr);
    
    if ((ret = avfilter_graph_parse_ptr(filter_graph, [nsfilter_descr UTF8String],
                                        &inputs, &outputs, NULL)) < 0) {
        NSLog(@"avfilter graph parse error");
        avfilter_inout_free(&inputs);
        avfilter_inout_free(&outputs);
        return NO;
    }
    
    if ((ret = avfilter_graph_config(filter_graph, NULL)) < 0) {
        NSLog(@"avfilter graph config error");
        avfilter_inout_free(&inputs);
        avfilter_inout_free(&outputs);
        return NO;
    }
    
    avfilter_inout_free(&inputs);
    avfilter_inout_free(&outputs);
    
    NSLog( @"Success init avfilter");
    
    return YES;
}

- (void) DeInitFilters {
    NSLog( @"DeInit filters");
    if (filter_graph) {
        avfilter_graph_free(&filter_graph);
        filter_graph = nil;
    }
}
@end
