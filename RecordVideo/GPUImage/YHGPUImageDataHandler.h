//
//  YHGPUImageDataHandler.h
//  RecordVideo
//
//  Created by huizai on 2019/5/24.
//  Copyright © 2019 huizai. All rights reserved.
//
//  作者Github址: https://github.com/huizai0705/VideoRecorder_iOS
//  作者CSDN博客地址: https://blog.csdn.net/m0_37677536
//
//

#import "GPUImageRawDataOutput.h"
#import "YHGPUImageAudioCamera.h"


NS_ASSUME_NONNULL_BEGIN

@protocol YHGPUImageDataHandlerDelegate <NSObject>
- (void)newFrameReadyAtTime:(CMTime)frameTime andSize:(CGSize)imageSize andData:(uint8_t *)rawBytesForImage;
@end

@interface YHGPUImageDataHandler : GPUImageRawDataOutput<GPUImageVideoCameraDelegate>

@property (nonatomic,weak)id <YHGPUImageDataHandlerDelegate> dataDelegate;

@end

NS_ASSUME_NONNULL_END
