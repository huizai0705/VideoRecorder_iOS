//
//  YHRecordTools.m
//  RecordVideo
//
//  Created by huizai on 2019/5/24.
//  Copyright © 2019 huizai. All rights reserved.
//
//  作者Github址: https://github.com/huizai0705/VideoRecorder_iOS
//  作者CSDN博客地址: https://blog.csdn.net/m0_37677536
//
//

#import "YHRecordTools.h"
#import "libyuv.h"
//视频编码加速，stride须设置为16的倍数
#define stride(wid) ((wid % 16 != 0) ? ((wid) + 16 - (wid) % 16): (wid))
@implementation YHRecordTools

+ (BOOL) WriteVideoData:(uint8_t *)rawBytesForImage andSize:(CGSize)imageSize withRecord:(YHBaseRecord*)recorder withPTS:(int64_t)pts{
    //将bgra转为yuv
    //图像宽度
    int width = stride((int)imageSize.width);
    //图像高度
    int height = imageSize.height;
    //宽*高
    int w_x_h = width * height;
    //yuv数据
    uint8_t *y_bytes = malloc(w_x_h);
    uint8_t *uv_bytes = malloc(w_x_h/2);
    //ARGBToNV12这个函数是libyuv这个第三方库提供的一个将bgra图片转为yuv420格式的一个函数。
    ARGBToNV12(rawBytesForImage, width * 4, y_bytes, width, uv_bytes, width, width, height);
    if (![recorder copyVideo: y_bytes withUV:uv_bytes withYSize:w_x_h withUVSize:w_x_h/2]) {
        NSLog(@"copy video buffer failed");
        free(y_bytes);
        free(uv_bytes);
        return FALSE;
    }
    free(y_bytes);
    free(uv_bytes);
    return [recorder writeVideo: pts];
}


+ (BOOL) WriteVideoData:(CVPixelBufferRef) pixelBuffer withRecord:(YHBaseRecord*) recorder withPTS:(int64_t)pts {
    if (CVPixelBufferLockBaseAddress(pixelBuffer, 0) == kCVReturnSuccess) {
        int pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
        switch (pixelFormat) {
            case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
                break;
            default: {
                NSString *log = [NSString stringWithFormat: @"pixel format unknown %d",
                                 pixelFormat];
                NSLog( @"%@",log);
            }
                CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
                return FALSE;
        }
        
        UInt8 *pY  = (UInt8 *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer,  0);
        UInt8 *pUV = (UInt8 *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer,  1);
        int rows = (int)CVPixelBufferGetHeight(pixelBuffer);
        int yBs  = (int)CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0) * rows;
        int uvBs = (int)CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1) * (rows / 2);
        if (![recorder copyVideo: pY withUV: pUV withYSize: yBs withUVSize: uvBs]) {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
            CVPixelBufferRelease(pixelBuffer);
            NSLog(@"copy video buffer failed");
            return FALSE;
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        CVPixelBufferRelease(pixelBuffer);
        return [recorder writeVideo: pts];
    } else {
        NSLog(@"lock pixel buffer failed");
        return FALSE;
    }
}

+ (BOOL) WriteAudioData:(CMSampleBufferRef) sampleBuffer withRecord:(YHBaseRecord*) recorder {
    size_t _pcmBufferSize = 0;
    char* _pcmBuffer = NULL;
    
    CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    if(CFRetain(blockBuffer)) {
        CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        int64_t intPTS = (pts.value) / pts.timescale;
        
        AudioStreamBasicDescription inAudioStreamBasicDescription = *CMAudioFormatDescriptionGetStreamBasicDescription(                                           (CMAudioFormatDescriptionRef)CMSampleBufferGetFormatDescription(sampleBuffer));
        OSStatus status =
        CMBlockBufferGetDataPointer(blockBuffer, 0, NULL, &_pcmBufferSize, &_pcmBuffer);
        NSError *error = nil;
        if (status != kCMBlockBufferNoErr) {
            error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
            NSString *log = [NSString stringWithFormat: @"get data pointer error: %@",
                             NSError.description];
            NSLog( @"%@",log);
            CFRelease(blockBuffer);
        } else {
            int numFrames = (int)
            _pcmBufferSize / inAudioStreamBasicDescription.mBytesPerFrame; 
            if ([recorder copyAudio: _pcmBuffer
                     withBufferSize: (int)_pcmBufferSize withFrames: numFrames]) {
                CFRelease(blockBuffer);
                [recorder writeAudio: numFrames withPTS: intPTS];
            } else {
                NSLog( @"copyAudio failed");
                CFRelease(blockBuffer);
            }
        }
    } else {
        NSLog(@"CFRetain failed");
    }
    return true;
}
@end
