//
//  YHVideoRecordVC.m
//  RecordVideo
//
//  Created by huizai on 2019/5/14.
//  Copyright © 2019 huizai. All rights reserved.
//
//  作者Github址: https://github.com/huizai0705/VideoRecorder_iOS
//  作者CSDN博客地址: https://blog.csdn.net/m0_37677536
// 
//

#import "YHVideoRecordVC.h"
#import "YHGPUImageBeautifyFilter.h"
#import "YHHelp.h"
#import "YHToastHUD.h"

typedef NS_ENUM(NSInteger, CameraManagerDevicePosition) {
    CameraManagerDevicePositionBack,
    CameraManagerDevicePositionFront,
};

typedef NS_ENUM(NSInteger, TypeFilter) {
    filterNone,
    filterGaussBlur,
    filterDilation,
    filterBeautify,
    filterGif,
};


@interface YHVideoRecordVC ()<GPUImageVideoCameraDelegate>{
    GPUImageVideoCamera              *videoCamera;
    GPUImageMovieWriter              *movieWriter;
    GPUImageOutput<GPUImageInput>    *filter;
    GPUImageGaussianBlurFilter       *gaussBlurFilter;
    GPUImageDilationFilter           *dilationFilter;
    YHGPUImageBeautifyFilter         *beautifyFilter;
    GPUImageAlphaBlendFilter         *gifFilter;
    GPUImageFilter                   *videoFilter;
    int                              videoIndex;
    NSTimer                          *myTimer;
    NSString                         *videoPathUrl;
}
@property (weak, nonatomic) IBOutlet GPUImageView *filteredVideoView;

@property (nonatomic, assign) CameraManagerDevicePosition position;
@property (nonatomic, strong) NSMutableArray *urlArray;
@property (nonatomic, strong) NSMutableArray *lastAry;
@property (nonatomic, strong) NSMutableArray *progressViewArray;
@property (nonatomic, assign) BOOL isRecoding;
@property (nonatomic, assign) BOOL isCanReord;
@property (nonatomic, assign) TypeFilter typeFilter;
@property (weak, nonatomic) IBOutlet UIView *viewIndicate;

@end

@implementation YHVideoRecordVC

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    [self requestAuth];
    [self initComponent];
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

- (void)initComponent{
    
    _lastAry = [[NSMutableArray alloc] init];
    _urlArray = [[NSMutableArray alloc] init];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pauseCamera:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startCamera:) name:UIApplicationWillEnterForegroundNotification object:nil];
}

- (void)initFilter{
    
    /////////////////////////////高斯
    gaussBlurFilter = [[GPUImageGaussianBlurFilter alloc]init];
    gaussBlurFilter.texelSpacingMultiplier = 5;
    gaussBlurFilter.blurRadiusInPixels = 5;
    
    
    /////////////////////////////灰度
    dilationFilter = [[GPUImageDilationFilter alloc]initWithRadius:3];
    
    
    ////////////////////////////美颜
    beautifyFilter = [[YHGPUImageBeautifyFilter alloc]init];
    
    
    ///////////////////////////gif
    NSString *path = [[NSBundle mainBundle] pathForResource:@"video.gif" ofType:nil] ;
    NSData *imageData = [NSData dataWithContentsOfFile:path];
    NSArray * arrImage =  [YHHelp changeGifToImage:imageData];
    UIImageView * imageV = [[UIImageView alloc]initWithFrame:CGRectMake(80, 0, 100, 80)];
    imageV.image = arrImage[0];
    
    
    //创建滤镜 GPUImageDissolveBlendFilter
    gifFilter = [[GPUImageAlphaBlendFilter alloc] init];
    // GPUImageGaussianBlurFilter *filter = [[GPUImageGaussianBlurFilter alloc] init];
    gifFilter.mix = 0.8;
    //创建水印图形
    
    UIView* watermarkView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 180, 380)];
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 80, 80)];
    label.text = @"Record";
    label.textColor = [UIColor whiteColor];
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    [watermarkView addSubview:imageV];
    [watermarkView addSubview:label];
    
    GPUImageUIElement *uiElement = [[GPUImageUIElement alloc] initWithView:watermarkView];
    videoFilter = [[GPUImageFilter alloc] init];
    [videoFilter addTarget:gifFilter];
    [uiElement addTarget:gifFilter];
    __block NSInteger imageIndex = 0;
    __block GPUImageUIElement *weakElement = uiElement;
    __block NSInteger timeCount = 0;
    [videoFilter setFrameProcessingCompletionBlock:^(GPUImageOutput *output, CMTime time) {
        NSInteger tempCount = time.value/(time.timescale/1000);
        if (tempCount - timeCount > 100) {
            imageIndex ++;
            dispatch_async(dispatch_get_main_queue(), ^{
                imageV.image = arrImage[imageIndex];
            });
            if (imageIndex == arrImage.count -1) {
                imageIndex = 0;
            }
            timeCount = tempCount;
        }
        [weakElement update];
    }];
}

#pragma mark noti
- (void)pauseCamera:(NSNotification *)notifi
{
    if (_isRecoding == YES) {
        [self actionPauseRecord:nil];
        if (videoCamera) {
            [videoCamera stopCameraCapture];
        }
    }
}

- (void)startCamera:(NSNotification *)notifi
{
    [self startRecord];
}

#pragma mark action

- (IBAction)actionStartRecord:(id)sender {
    
    if (_isRecoding) {
        [YHToastHUD showToast:@"已经在录制...."];
        return;
    }
    [YHToastHUD showToast:@"开始录制"];
    videoIndex = 1;
    //清除文件 创建目录
    [YHHelp video_file_clear];
    create_video_dir();
    [self initMovieWriter:videoIndex];
    [self startRecord];
    self.isRecoding = YES;
}

- (IBAction)actionPauseRecord:(UIButton*)sender {

    if (_isRecoding) {
        [YHToastHUD showToast:@"暂停录制"];
        sender.selected = YES;
        self.isRecoding = NO;
        [self endRecord];
    }else{
        [YHToastHUD showToast:@"开始录制"];
        ++videoIndex;
        [self initMovieWriter:videoIndex];
        [self startRecord];
        self.isRecoding = YES;
        sender.selected = NO;
    }
}

- (IBAction)actionStopRecord:(id)sender {
    if (!_isRecoding) {
        [YHToastHUD showToast:@"还没开始录制...."];
        return;
    }
    self.isRecoding = NO;
    [self endRecord];
    [SVProgressHUD showWithStatus:@"视频合成中......"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self mergeAndExportVideos:_urlArray withOutPath:video_file_url(@"test")];
    });
}

- (IBAction)filterA:(id)sender {
    self.typeFilter = filterGaussBlur;
}

- (IBAction)filterB:(id)sender {
    self.typeFilter = filterBeautify;
}

- (IBAction)filterC:(id)sender {
    self.typeFilter = filterDilation;
}

- (IBAction)filterD:(id)sender {
    self.typeFilter = filterGif;
}

- (IBAction)filterN:(id)sender {
    self.typeFilter = filterNone;
}

- (IBAction)actionChangeVPosition:(id)sender {
    switch (_position) {
        case CameraManagerDevicePositionBack: {
            if (videoCamera.cameraPosition == AVCaptureDevicePositionBack) {
                [videoCamera pauseCameraCapture];
                _position = CameraManagerDevicePositionFront;
                [videoCamera rotateCamera];
                [videoCamera resumeCameraCapture];
            }
        }
            break;
        case CameraManagerDevicePositionFront: {
            if (videoCamera.cameraPosition == AVCaptureDevicePositionFront) {
                [videoCamera pauseCameraCapture];
                _position = CameraManagerDevicePositionBack;
                [videoCamera rotateCamera];
                [videoCamera resumeCameraCapture];
            }
        }
            break;
        default:
            break;
    }
    
    if ([videoCamera.inputCamera lockForConfiguration:nil] && [videoCamera.inputCamera isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
        [videoCamera.inputCamera setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
        [videoCamera.inputCamera unlockForConfiguration];
    }
}

- (IBAction)actionCancel:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}


- (void)setTypeFilter:(TypeFilter)typeFilter{
    _typeFilter = typeFilter;
    [videoCamera removeAllTargets];
    switch (typeFilter) {
        case filterNone:
        {
            if (movieWriter) {
                [videoCamera addTarget:movieWriter];
            }
            [videoCamera addTarget:_filteredVideoView];
        }
            break;
        case filterDilation:
        {
            [videoCamera addTarget:dilationFilter];
            if (movieWriter) {
                [dilationFilter addTarget:movieWriter];
            }
            [dilationFilter addTarget:_filteredVideoView];
        }
            break;
        case filterGif:
        {
            [videoCamera addTarget:videoFilter];
            //由于GPUImageAlphaBlendFilter 不能直接以videoCamera为输入源中间以videoFilter桥接一下
            [videoFilter addTarget:gifFilter];
            if (movieWriter) {
                [gifFilter addTarget:movieWriter];
            }
            [gifFilter addTarget:_filteredVideoView];
        }
            break;
        case filterBeautify:
        {
            [videoCamera addTarget:beautifyFilter];
            if (movieWriter) {
                [beautifyFilter addTarget:movieWriter];
            }
            [beautifyFilter addTarget:_filteredVideoView];
        }
            break;
        case filterGaussBlur:
        {
            [videoCamera addTarget:gaussBlurFilter];
            if (movieWriter) {
                [gaussBlurFilter addTarget:movieWriter];
            }
            [gaussBlurFilter addTarget:_filteredVideoView];
        }
            break;
            
        default:
            break;
    }
}

- (CVPixelBufferRef)didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    return pixelBuffer;
}


- (void)initMovieWriter:(int)index{
    videoPathUrl = video_file_url([NSString stringWithFormat:@"%d",index]);
    unlink([videoPathUrl UTF8String]);
    movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:[NSURL fileURLWithPath:videoPathUrl] size:CGSizeMake(720.0, 1280.0)];
    movieWriter.isNeedBreakAudioWhiter = YES;
    movieWriter.encodingLiveVideo = YES;
    movieWriter.shouldPassthroughAudio = YES;
    switch (_typeFilter) {
        case filterNone:
        {
            [videoCamera addTarget:movieWriter];
        }
            break;
        case filterDilation:
        {
            [dilationFilter addTarget:movieWriter];
        }
            break;
        case filterGif:
        {
            [gifFilter addTarget:movieWriter];
        }
            break;
        case filterBeautify:
        {
            [beautifyFilter addTarget:movieWriter];
        }
            break;
        case filterGaussBlur:
        {
            [gaussBlurFilter addTarget:movieWriter];
        }
            break;
            
        default:
            break;
    }
    
}

- (void)startRecord{
    videoCamera.audioEncodingTarget = movieWriter;
    [movieWriter startRecording];
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
    
    [movieWriter finishRecording];
    videoCamera.audioEncodingTarget = nil;
    [_urlArray addObject:[NSURL URLWithString:[NSString stringWithFormat:@"file://%@",videoPathUrl]]];
    [myTimer invalidate];
    myTimer = nil;
}


- (void)mergeAndExportVideos:(NSArray*)videosPathArray withOutPath:(NSString*)outpath{
    
    if (videosPathArray.count == 0) {
        [YHToastHUD showToast:@"没有可处理视频文件！"];
        return;
    }
    //音频视频合成体
    AVMutableComposition *mixComposition = [[AVMutableComposition alloc] init];

    //创建音频通道容器
    AVMutableCompositionTrack *audioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    //创建视频通道容器
    AVMutableCompositionTrack *videoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    
    
    CMTime totalDuration = kCMTimeZero;
    for (int i = 0; i < videosPathArray.count; i++) {
        //        AVURLAsset *asset = [AVURLAsset assetWithURL:[NSURL URLWithString:videosPathArray[i]]];
        NSDictionary* options = @{AVURLAssetPreferPreciseDurationAndTimingKey:@YES};
        AVAsset* asset = [AVURLAsset URLAssetWithURL:videosPathArray[i] options:options];
        
        NSError *erroraudio = nil;
        //获取AVAsset中的音频 或者视频
        AVAssetTrack *assetAudioTrack = [[asset tracksWithMediaType:AVMediaTypeAudio] firstObject];
        //向通道内加入音频或者视频
        BOOL ba = [audioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration)
                                      ofTrack:assetAudioTrack
                                       atTime:totalDuration
                                        error:&erroraudio];
        
        NSLog(@"erroraudio:%@%d",erroraudio,ba);
        NSError *errorVideo = nil;
        AVAssetTrack *assetVideoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo]firstObject];
        BOOL bl = [videoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration)
                                      ofTrack:assetVideoTrack
                                       atTime:totalDuration
                                        error:&errorVideo];
        
        NSLog(@"errorVideo:%@%d",errorVideo,bl);
        totalDuration = CMTimeAdd(totalDuration, asset.duration);
    }
    NSLog(@"%@",NSHomeDirectory());
    
    CGSize videoSize = [videoTrack naturalSize];
    
    AVMutableVideoComposition* videoComp = [AVMutableVideoComposition videoComposition];
    videoComp.renderSize = videoSize;
    videoComp.frameDuration = CMTimeMake(1, 30);
    
    AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    instruction.timeRange = CMTimeRangeMake(kCMTimeZero, [mixComposition duration]);
    AVAssetTrack *mixVideoTrack = [[mixComposition tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    AVMutableVideoCompositionLayerInstruction *layerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:mixVideoTrack];
    instruction.layerInstructions = [NSArray arrayWithObject:layerInstruction];
    videoComp.instructions = [NSArray arrayWithObject: instruction];
    
    NSURL *mergeFileURL = [NSURL fileURLWithPath:outpath];
    
    //视频导出工具
#pragma mark 录制分辨率设置
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetMediumQuality];
    exporter.videoComposition = videoComp;
    /*
     exporter.progress
     导出进度
     This property is not key-value observable.
     不支持kvo 监听
     只能用定时器监听了  NStimer
     */
    
    exporter.outputURL = mergeFileURL;
    exporter.outputFileType = AVFileTypeMPEG4;
    exporter.shouldOptimizeForNetworkUse = YES;
    __weak typeof(self) weak_self = self;
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [YHToastHUD showToast:@"处理完毕...." completion:^{
                [weak_self dismissViewControllerAnimated:YES completion:nil];
            }];
        });
    }];
}

#pragma mark 通过视频的URL，获得视频缩略图
-(UIImage *)getImage:(NSString *)videoURL
{
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:[NSURL fileURLWithPath:videoURL] options:nil];
    AVAssetImageGenerator *gen = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    gen.appliesPreferredTrackTransform = YES;
    CMTime time = CMTimeMakeWithSeconds(0.0, 600);
    NSError *error = nil;
    CMTime actualTime;
    CGImageRef image = [gen copyCGImageAtTime:time actualTime:&actualTime error:&error];
    UIImage *thumb = [[UIImage alloc] initWithCGImage:image];
    CGImageRelease(image);
    return thumb;
}

- (void)createCamera
{
    videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset1280x720 cameraPosition:AVCaptureDevicePositionFront];
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
    _position = CameraManagerDevicePositionFront;
    
}

- (void)addTarget{
    _filteredVideoView.backgroundColor = [UIColor colorWithWhite:1 alpha:0.6];
    [videoCamera addTarget:_filteredVideoView];
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
