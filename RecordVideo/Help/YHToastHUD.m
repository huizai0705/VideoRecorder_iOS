//
//  YHToastHUD.m
//  RecordVideo
//
//  Created by huizai on 2019/5/21.
//  Copyright © 2019 huizai. All rights reserved.
//
//  作者Github址: https://github.com/huizai0705/VideoRecorder_iOS
//  作者CSDN博客地址: https://blog.csdn.net/m0_37677536
// 
//

#import "YHToastHUD.h"

@implementation YHToastHUD

+(void)showToast:(NSString*)msg andDuration:(CGFloat)duration{
    [self showToast:msg andDuration:duration completion:nil];
}

+(void)showToast:(NSString*)msg{
    [self showToast:msg andDuration:1.2];
}

+(void)showToast:(NSString*)msg completion:(nullable ToastHUDDismissCompletion)completion{
    [self showToast:msg andDuration:1.2 completion:^{
        completion();
    }];
}

+(void)showToast:(NSString*)msg andDuration:(CGFloat)duration completion:(nullable ToastHUDDismissCompletion)completion{
    [SVProgressHUD dismiss];
    [SVProgressHUD setDefaultMaskType:SVProgressHUDMaskTypeClear];
    [SVProgressHUD setDefaultStyle:SVProgressHUDStyleDark];
    [SVProgressHUD setImageViewSize:CGSizeMake(0, -1)];
    [SVProgressHUD showImage:[UIImage imageNamed:@"icon_cancel"] status:msg];
    [SVProgressHUD dismissWithDelay:duration completion:^{
        [SVProgressHUD setDefaultStyle:SVProgressHUDStyleDark];
        [SVProgressHUD setImageViewSize:CGSizeMake(28, 28)];
        [SVProgressHUD setDefaultMaskType:SVProgressHUDMaskTypeBlack];
        if (completion) {
            completion();
        }
    }];
}

@end
