//
//  YHGPUImageAudioCamera.m
//  RecordVideo
//
//  Created by huizai on 2019/5/24.
//  Copyright © 2019 huizai. All rights reserved.
//
//  作者Github址: https://github.com/huizai0705/VideoRecorder_iOS
//  作者CSDN博客地址: https://blog.csdn.net/m0_37677536
//
//

#import "YHGPUImageAudioCamera.h"

@implementation YHGPUImageAudioCamera


-(void)processAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer{
    [super processAudioSampleBuffer:sampleBuffer];
    if (self.audioDelegate && [self.audioDelegate respondsToSelector:@selector(processAudioSample:)]) {
        [self.audioDelegate processAudioSample:sampleBuffer];
    }
}


@end
