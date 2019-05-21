//
//  YHGPUImageBeautifyFilter.h
//  RecordVideo
//
//  Created by huizai on 2019/5/14.
//  Copyright © 2019 huizai. All rights reserved.
//
//  作者Github址: https://github.com/huizai0705/VideoRecorder_iOS
//  作者CSDN博客地址: https://blog.csdn.net/m0_37677536
// 
//

#import "GPUImageFilterGroup.h"
#import "GPUImage.h"

NS_ASSUME_NONNULL_BEGIN

@class GPUImageCombinationFilter;

@interface YHGPUImageBeautifyFilter : GPUImageFilterGroup{
    GPUImageBilateralFilter *bilateralFilter;
    GPUImageCannyEdgeDetectionFilter *cannyEdgeFilter;
    GPUImageCombinationFilter *combinationFilter;
    GPUImageHSBFilter *hsbFilter;
}

@end

NS_ASSUME_NONNULL_END
