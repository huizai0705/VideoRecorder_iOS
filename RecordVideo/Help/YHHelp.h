//
//  YHHelp.h
//  RecordVideo
//
//  Created by huizai on 2019/5/15.
//  Copyright © 2019 huizai. All rights reserved.
//
//  作者Github址: https://github.com/huizai0705/VideoRecorder_iOS
//  作者CSDN博客地址: https://blog.csdn.net/m0_37677536
// 
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define ScreenWidth [[UIScreen mainScreen] bounds].size.width
#define ScreenHeight [[UIScreen mainScreen] bounds].size.height

NS_ASSUME_NONNULL_BEGIN

@interface YHHelp : NSObject
+(NSMutableArray*)changeGifToImage:(NSData*)gifData;
void video_file_clear(void);
NSString *create_video_dir(void);
NSString *video_file_url(NSString *file);
@end

NS_ASSUME_NONNULL_END
