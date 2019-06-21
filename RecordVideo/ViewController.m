//
//  ViewController.m
//  RecordVideo
//
//  Created by huizai on 2019/5/14.
//  Copyright © 2019 huizai. All rights reserved.
//
//  作者Github址: https://github.com/huizai0705/VideoRecorder_iOS
//  作者CSDN博客地址: https://blog.csdn.net/m0_37677536
// 
//

#import "ViewController.h"
#import "YHVideoPlayVC.h"
#import "YHVideoRecordVC.h"
#import "YHFFmpegRecordVC.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.

}
- (IBAction)actionGoRecord:(id)sender {
    YHVideoRecordVC * vc = [YHVideoRecordVC new];
    [self presentViewController:vc animated:YES completion:nil];
}

- (IBAction)actionGoPlay:(id)sender {
    YHVideoPlayVC * vc = [YHVideoPlayVC new];
    [self presentViewController:vc animated:YES completion:nil];
}
- (IBAction)actionTest:(UIButton *)sender {

    YHFFmpegRecordVC * vc = [YHFFmpegRecordVC new];
    [self presentViewController:vc animated:YES completion:nil];
}

@end
