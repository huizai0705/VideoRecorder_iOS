//
//  YHFFmpegRecordVC.m
//  RecordVideo
//
//  Created by huizai on 2019/6/20.
//  Copyright © 2019 huizai. All rights reserved.
//
//  作者Github址: https://github.com/huizai0705/VideoRecorder_iOS
//  作者CSDN博客地址: https://blog.csdn.net/m0_37677536
//
//

#import "YHFFmpegRecordVC.h"
#import "YHGPUImageBeautifyFilter.h"
#import "YHHelp.h"
#import "YHToastHUD.h"
#import "YHGPUImageDataHandler.h"
#import "YHRecordTools.h"
#import "YHAVRecord.h"


@interface YHFFmpegRecordVC ()<YHGPUImageAudioCameraDelegate,YHGPUImageDataHandlerDelegate,GPUImageVideoCameraDelegate>{
    YHGPUImageAudioCamera            *videoCamera;
    GPUImageOutput<GPUImageInput>    *filter;
    GPUImageGaussianBlurFilter       *gaussBlurFilter;
    GPUImageDilationFilter           *dilationFilter;
    YHGPUImageBeautifyFilter         *beautifyFilter;
    GPUImageAlphaBlendFilter         *gifFilter;
    GPUImageFilter                   *videoFilter;
    YHGPUImageDataHandler            *dataHander;
    int                              videoIndex;
    NSTimer                          *myTimer;
    NSString                         *videoPathUrl;
    YHAVRecord                       *avRecorder;
}
@property (weak, nonatomic) IBOutlet GPUImageView *filteredVideoView;
@property (weak, nonatomic) IBOutlet UIView *viewIndicate;
@property (nonatomic, assign) BOOL isRecoding;
@property (nonatomic, assign) BOOL isCanReord;
@property (nonatomic) dispatch_queue_t recordQueue;
@end

@implementation YHFFmpegRecordVC

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    [self requestAuth];
    [self initFilter];
    [self createCamera];
    [self addTarget];
    
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (self.isCanReord) {
        if (videoCamera) {
            [videoCamera startCameraCapture];
        }
    }
    [self setNeedsStatusBarAppearanceUpdate];
}

#pragma mark noti
- (void)pauseCamera:(NSNotification *)notifi
{

}

- (void)startCamera:(NSNotification *)notifi
{

}
#pragma mark camera delegate
- (void)processAudioSample:(CMSampleBufferRef)sampleBuffer{
   // NSLog(@"aaaaaa");
    CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    //NSLog(@"---audio:%lld",pts.value/pts.timescale);//44100
    if (!_isRecoding) {
        return;
    }
    dispatch_sync(_recordQueue, ^{
         [YHRecordTools WriteAudioData:sampleBuffer withRecord:avRecorder];
    });
}
- (void)newFrameReadyAtTime:(CMTime)frameTime andSize:(CGSize)imageSize andData:(uint8_t *)rawBytesForImage{
   //NSLog(@"---video:%lld",frameTime.value/frameTime.timescale);//1000000000
    if (!_isRecoding) {
        return;
    }
    int64_t intPTS = frameTime.value / frameTime.timescale;
    dispatch_sync(_recordQueue, ^{
        [YHRecordTools WriteVideoData:rawBytesForImage andSize:imageSize withRecord:avRecorder withPTS:frameTime.value/10000];
    });
}


#pragma mark action

- (IBAction)actionCancel:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)actionStartRecord:(id)sender {
    self.isRecoding = YES;
    [self startRecord];
}

- (IBAction)actionPauseRecord:(UIButton*)sender {
    

}

- (IBAction)actionStopRecord:(id)sender {
    self.isRecoding = NO;
    [self endRecord];
}

- (void)startRecord{
    
    dispatch_sync(_recordQueue, ^{
        self.isRecoding = [avRecorder startRecord:video_file_url(@"test") withW:720 withH:1280];
    });
    
    myTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                               target:self
                                             selector:@selector(updateTimer:)
                                             userInfo:nil
                                              repeats:YES];
    [myTimer fire];
}

- (void)updateTimer:(NSTimer *)sender
{
    _viewIndicate.hidden = !_viewIndicate.isHidden;
}

- (void)endRecord{
    
    videoCamera.audioEncodingTarget = nil;
    [myTimer invalidate];
    myTimer = nil;
    
    dispatch_sync(_recordQueue, ^{
        [avRecorder stopRecord];
    });
}

- (void)createCamera
{
    avRecorder = [[YHAVRecord alloc]init];
    [avRecorder initParameters];
    _recordQueue = dispatch_queue_create("com.test.recordQueue", DISPATCH_QUEUE_SERIAL);
    
    videoCamera = [[YHGPUImageAudioCamera alloc] initWithSessionPreset:AVCaptureSessionPreset1280x720 cameraPosition:AVCaptureDevicePositionFront];
    videoCamera.audioDelegate = self;
    videoCamera.delegate = self;
    if ([videoCamera.inputCamera lockForConfiguration:nil]) {
        //自动对焦
        if ([videoCamera.inputCamera isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
            [videoCamera.inputCamera setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
        }
        //自动曝光
        if ([videoCamera.inputCamera isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
            [videoCamera.inputCamera setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
        }
        //自动白平衡
        if ([videoCamera.inputCamera isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance]) {
            [videoCamera.inputCamera setWhiteBalanceMode:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance];
        }
        [videoCamera.inputCamera unlockForConfiguration];
    }
    
    //    videoCamera.frameRate = 30;
    videoCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
    [videoCamera addAudioInputsAndOutputs];
    videoCamera.horizontallyMirrorFrontFacingCamera = YES;
    videoCamera.horizontallyMirrorRearFacingCamera = NO;
    
}

- (void)initFilter{
    
    /////////////////////////////高斯
    gaussBlurFilter = [[GPUImageGaussianBlurFilter alloc]init];
    gaussBlurFilter.texelSpacingMultiplier = 4;
    gaussBlurFilter.blurRadiusInPixels = 3;
    ////////////////////////////美颜
    beautifyFilter = [[YHGPUImageBeautifyFilter alloc]init];
    ///////////////////////////dataHander
    dataHander = [[YHGPUImageDataHandler alloc]initWithImageSize:CGSizeMake(720, 1280) resultsInBGRAFormat:YES];
    dataHander.dataDelegate = self;
}

- (void)addTarget{
    _filteredVideoView.backgroundColor = [UIColor colorWithWhite:1 alpha:0.6];
    [videoCamera addTarget:_filteredVideoView];
    [videoCamera addTarget:gaussBlurFilter];
    [gaussBlurFilter addTarget:dataHander];
}


- (void)requestAuth{
    
    self.isCanReord = NO;
    
    AVAuthorizationStatus videoAuthStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (videoAuthStatus == AVAuthorizationStatusRestricted || videoAuthStatus == AVAuthorizationStatusDenied) {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"无法使用相机" message:@"请在设置-隐私-相机中允许访问相机" preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self dismissViewControllerAnimated:YES completion:nil];
        }];
        [alertController addAction:okAction];
        [self presentViewController:alertController animated:YES completion:nil];
    } else {
        self.isCanReord = YES;
    }
    AVAuthorizationStatus audioAuthStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    if (audioAuthStatus == AVAuthorizationStatusRestricted || audioAuthStatus == AVAuthorizationStatusDenied) {
        // 未授权
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"无法使用麦克风" message:@"请在设置-隐私-麦克风中允许访问麦克风" preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self dismissViewControllerAnimated:YES completion:nil];
        }];
        [alertController addAction:okAction];
        [self presentViewController:alertController animated:YES completion:nil];
    } else {
        self.isCanReord = YES;
    }
}


@end
