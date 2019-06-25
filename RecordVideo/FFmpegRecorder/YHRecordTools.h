//
//  YHRecordTools.h
//  RecordVideo
//
//  Created by huizai on 2019/5/24.
//  Copyright © 2019 huizai. All rights reserved.
//
//  作者Github址: https://github.com/huizai0705/VideoRecorder_iOS
//  作者CSDN博客地址: https://blog.csdn.net/m0_37677536
//
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

#import "YHNAVRecord.h"
#import "YHAVRecord.h"

NS_ASSUME_NONNULL_BEGIN

@interface YHRecordTools : NSObject

+ (BOOL) WriteVideoData:(uint8_t *)rawBytesForImage andSize:(CGSize)imageSize withRecord:(YHBaseRecord*)recorder withPTS:(int64_t)pts;

+ (BOOL) WriteVideoData:(CVPixelBufferRef) pixelBuffer withRecord:(YHBaseRecord*) recorder withPTS:(int64_t)pts;

+ (BOOL) WriteAudioData:(CMSampleBufferRef) pixelBuffer withRecord:(YHBaseRecord*) recorder;

@end

NS_ASSUME_NONNULL_END
