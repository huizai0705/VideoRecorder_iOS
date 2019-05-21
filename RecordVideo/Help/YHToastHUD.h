//
//  YHToastHUD.h
//  RecordVideo
//
//  Created by huizai on 2019/5/21.
//  Copyright © 2019 huizai. All rights reserved.
//
//  作者Github址: https://github.com/huizai0705/VideoRecorder_iOS
//  作者CSDN博客地址: https://blog.csdn.net/m0_37677536
// 
//

#import "SVProgressHUD.h"

NS_ASSUME_NONNULL_BEGIN
typedef void (^ToastHUDDismissCompletion)(void);
@interface YHToastHUD : SVProgressHUD
+(void)showToast:(NSString*)msg;
+(void)showToast:(NSString*)msg andDuration:(CGFloat)duration;
+(void)showToast:(NSString*)msg completion:(nullable ToastHUDDismissCompletion)completion;
+(void)showToast:(NSString*)msg andDuration:(CGFloat)duration completion:(nullable ToastHUDDismissCompletion)completion;
@end

NS_ASSUME_NONNULL_END
