//
//  YHBaseRecord.m
//  RecordVideo
//
//  Created by huizai on 2019/5/24.
//  Copyright © 2019 huizai. All rights reserved.
//
//  作者Github址: https://github.com/huizai0705/VideoRecorder_iOS
//  作者CSDN博客地址: https://blog.csdn.net/m0_37677536
//
//

#import "YHBaseRecord.h"


@implementation YHBaseRecord

extern const uint64_t YH_AV_CH_Layout_Selector[] =
{
    0
    ,AV_CH_LAYOUT_MONO
    ,AV_CH_LAYOUT_STEREO
    ,AV_CH_LAYOUT_2_1
    ,AV_CH_LAYOUT_3POINT1
    ,AV_CH_LAYOUT_5POINT0
    ,AV_CH_LAYOUT_5POINT1
    ,AV_CH_LAYOUT_7POINT0
    ,AV_CH_LAYOUT_7POINT1
};

-(id)init{
    self = [super init];
    if (self){}
    return self;
}

- (BOOL) initParameters{
    return NO;
}

- (BOOL) startRecord: (NSString *)outPath
               withW: (int)width
               withH: (int)height{
    return NO;
}

- (void) stopRecord{}

- (BOOL) copyVideo:  (UInt8*)pY
            withUV: (UInt8*)pUV
         withYSize: (int)yBs
        withUVSize: (int)uvBs{
    return NO;
}

- (BOOL) writeVideo: (int64_t) intPTS{
    return NO;
}

- (BOOL) copyAudio: (const char*) pcmBuffer
    withBufferSize: (int)pcmBufferSize
        withFrames: (int)numFrames{
    return NO;
}

- (BOOL) writeAudio: (int)numFrames
            withPTS: (int64_t)intPTS{
    return NO;
}
@end
