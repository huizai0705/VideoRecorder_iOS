//
//  YHGPUImageAudioCamera.h
//  RecordVideo
//
//  Created by huizai on 2019/5/24.
//  Copyright © 2019 huizai. All rights reserved.
//
//  作者Github址: https://github.com/huizai0705/VideoRecorder_iOS
//  作者CSDN博客地址: https://blog.csdn.net/m0_37677536
//
//

#import "GPUImageVideoCamera.h"

NS_ASSUME_NONNULL_BEGIN
//取音频信息
@protocol YHGPUImageAudioCameraDelegate <NSObject>
-(void) processAudioSample:(CMSampleBufferRef)sampleBuffer;
@end

@interface YHGPUImageAudioCamera : GPUImageVideoCamera
@property (nonatomic, weak) id<YHGPUImageAudioCameraDelegate> audioDelegate;
@end

NS_ASSUME_NONNULL_END
