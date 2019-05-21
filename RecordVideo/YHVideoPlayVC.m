//
//  YHVideoPlayVC.m
//  RecordVideo
//
//  Created by huizai on 2019/5/14.
//  Copyright © 2019 huizai. All rights reserved.
//
//  作者Github址: https://github.com/huizai0705/VideoRecorder_iOS
//  作者CSDN博客地址: https://blog.csdn.net/m0_37677536
// 
//

#import "YHVideoPlayVC.h"
#import <AVFoundation/AVFoundation.h>
#import "YHToastHUD.h"
#import "YHHelp.h"

@interface YHVideoPlayVC (){
    AVPlayer    * player;
}

@end

@implementation YHVideoPlayVC

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    //self.view.backgroundColor = [UIColor blackColor];
    
    
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    
    if (![[NSFileManager defaultManager]fileExistsAtPath:video_file_url(@"test")]) {
        [YHToastHUD showToast:@"视频文件不存在" completion:^{
            [self dismissViewControllerAnimated:YES completion:nil];
        }];
    }else{
        player = [[AVPlayer alloc] init];
        AVPlayerItem*  playerItem = [[AVPlayerItem alloc] initWithURL:[NSURL fileURLWithPath:video_file_url(@"test")]];
        [player replaceCurrentItemWithPlayerItem:playerItem];
        AVPlayerLayer*  playerLayer = [AVPlayerLayer playerLayerWithPlayer:player];
        CGFloat height = 1280./720.*ScreenWidth;
        playerLayer.frame = CGRectMake(0, (ScreenHeight-height)/2., ScreenWidth, height);
        [self.view.layer addSublayer:playerLayer];
        [player play];
    }
}

- (IBAction)actionCancel:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}


@end
