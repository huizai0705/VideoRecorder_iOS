//
//  YHAVRecord.h
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

NS_ASSUME_NONNULL_BEGIN

@interface YHAVRecord : NSObject
- (BOOL) initParameters;

- (BOOL) startRecord: (NSString *)outPath
               withW: (int)width
               withH: (int)height;

- (void) stopRecord;

- (BOOL) isWriteable;

- (BOOL) copyVideo:  (UInt8*)pY
            withUV: (UInt8*)pUV
         withYSize: (int)yBs
        withUVSize: (int)uvBs;

- (BOOL) writeVideo: (int64_t) intPTS;

- (BOOL) copyAudio: (const char*) pcmBuffer
    withBufferSize: (int)pcmBufferSize
        withFrames: (int)numFrames;

- (BOOL) writeAudio: (int)numFrames
            withPTS: (int64_t)intPTS;
@end

NS_ASSUME_NONNULL_END
