//
//  YHGPUImageDataHandler.m
//  RecordVideo
//
//  Created by huizai on 2019/5/24.
//  Copyright © 2019 huizai. All rights reserved.
//
//  作者Github址: https://github.com/huizai0705/VideoRecorder_iOS
//  作者CSDN博客地址: https://blog.csdn.net/m0_37677536
//
//

#import "YHGPUImageDataHandler.h"

@implementation YHGPUImageDataHandler

- (instancetype)initWithImageSize:(CGSize)newImageSize resultsInBGRAFormat:(BOOL)resultsInBGRAFormat
{
    self = [super initWithImageSize:newImageSize resultsInBGRAFormat:resultsInBGRAFormat];
    if (self) {
        
    }
    return self;
}

- (id)init{
    if (self = [super init]) {
    }
    return self;
}

-(void)newFrameReadyAtTime:(CMTime)frameTime atIndex:(NSInteger)textureIndex{
    [super newFrameReadyAtTime:frameTime atIndex:textureIndex];
    if (self.dataDelegate && [self.dataDelegate respondsToSelector:@selector(newFrameReadyAtTime:andSize:andData:)]) {
        [self lockFramebufferForReading];
        [self.dataDelegate newFrameReadyAtTime:frameTime andSize:imageSize andData:self.rawBytesForImage];
        [self unlockFramebufferAfterReading];
    }
}

@end
