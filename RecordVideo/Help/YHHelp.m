//
//  YHHelp.m
//  RecordVideo
//
//  Created by huizai on 2019/5/15.
//  Copyright © 2019 huizai. All rights reserved.
//
//  作者Github址: https://github.com/huizai0705/VideoRecorder_iOS
//  作者CSDN博客地址: https://blog.csdn.net/m0_37677536
// 
//

#import "YHHelp.h"

@implementation YHHelp

+(NSMutableArray*)changeGifToImage:(NSData*)gifData{
    //通过文件的url来将gif文件读取为图片数据引用
    CFDataRef my_cfdata = CFBridgingRetain(gifData);
    CGImageSourceRef source = CGImageSourceCreateWithData(my_cfdata, NULL);
    //获取gif文件里图片的个数
    size_t count = CGImageSourceGetCount(source);
    //存放全部图片
    NSMutableArray * imageArray = [[NSMutableArray alloc]init];
    //遍历
    for (size_t i=0; i<count; i++) {
        CGImageRef image = CGImageSourceCreateImageAtIndex(source, i, NULL);
        [imageArray addObject:[UIImage imageWithCGImage:image]];
        CGImageRelease(image);
        //获取图片信息
        NSDictionary * info = (__bridge NSDictionary*)CGImageSourceCopyPropertiesAtIndex(source, i, NULL);
        NSDictionary * timeDic = [info objectForKey:(__bridge NSString *)kCGImagePropertyGIFDictionary];
    }
    return imageArray;
}

+(void)video_file_clear{
    NSString *path = [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:@"Video"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    }
}

NSString *create_video_dir(void){
    NSString *path = [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:@"Video"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        //创建目录
        BOOL isSuccess =  [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
        if (isSuccess) {
            return path;
        }else
            return nil;
    }else
        return path;
    return nil;
}

NSString *video_file_url(NSString *file){
    NSString * videoPath =  [file stringByAppendingString:@".mp4"];
    NSString *path = [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:@"Video"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        //创建目录
       BOOL isSuccess =  [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
        if (isSuccess) {
            videoPath = [path stringByAppendingPathComponent:videoPath];
        }else
            videoPath = nil;
    }else
        videoPath = [path stringByAppendingPathComponent:videoPath];
    return videoPath;
}

@end
