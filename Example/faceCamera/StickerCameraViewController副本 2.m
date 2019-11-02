//
//  StickerCameraViewController.m
//  faceCamera
//
//  Created by cain on 16/3/2.
//  Copyright © 2016年 cain. All rights reserved.
//

#import "StickerCameraViewController.h"
#import "iflyMSC/IFlyFaceSDK.h"
#import "IFlyFaceImage.h"
#import "IFlyFaceResultKeys.h"
#import "CalculatorTools.h"

#import "DenoiseFilter.h"
#import "GPUSmoothFilter.h"
#import "SliderManage.h"
#import "HUMSlider.h"

typedef enum{
    ratioNormal = 0,
    ratioSquare = 1,
}ratioEnum;

@interface StickerCameraViewController ()<GPUImageVideoCameraDelegate>{
    GPUImageVideoCamera *videoCamera;
    BOOL faceThinking;
    UIView *faceView;
    UIView *leftEyeView;
    UIView *leftEye;
    UIView *mouth;
    BOOL isUsingFrontFacingCamera;
}

@property UISwipeGestureRecognizer *leftSwipe;
@property UISwipeGestureRecognizer *rightSwipe;
@property NSInteger filterIndex;

@property (weak, nonatomic) IBOutlet UIView *cameraView;
@property (weak, nonatomic) IBOutlet UIButton *backButton;
@property (weak, nonatomic) IBOutlet UIButton *switchButton;
@property (weak, nonatomic) IBOutlet UIView *switchView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *switchViewBottomSpace;

@property (weak, nonatomic) IBOutlet UIButton *ratioButton;
@property (weak, nonatomic) IBOutlet UIButton *beautifyButto;
@property (weak, nonatomic) IBOutlet UIButton *darkButton;
@property (weak, nonatomic) IBOutlet UIButton *blueButton;
@property (weak, nonatomic) IBOutlet UIButton *timeButton;
@property (weak, nonatomic) IBOutlet UIButton *randomButton;
@property (weak, nonatomic) IBOutlet UIButton *stretchButton;

@property ratioEnum ratio;
@property BOOL beautify;
@property BOOL dark;
@property BOOL blue;
@property NSInteger time;
@property CGSize imgSize;

@property GPUImageView *primaryView;
@property GPUImagePicture  *filterPic;
@property GPUImagePicture *lookImg;
@property GPUImagePicture *lookImg2;
@property GPUImagePicture *lookImg3;
@property GPUImagePicture *lookImg4;

@property GPUImageFilter *firstFilter;
@property GPUSmoothFilter *smoothFilter;
@property GPUImageCropFilter *cropFilter;
@property GPUImageVignetteFilter *vignetteFilter;
@property MyFilter *myFilter;

@property GPUImageBlenderCustomQuanticeLab *mixFilter;
@property GPUImageBrightnessFilter *brightnessFilter;
@property GPUImageLutFilter *lutFilter;
@property GPUImageStretchFilter *stretchFilter;
@property GPUImagePeopleFilter *peopleFilter;
@property GPUImagePeopleFilter *peopleFilter2;
@property GPUImagePeopleFilter *peopleFilter3;
@property GPUImagePeopleFilter *peopleFilter4;

@property HUMSlider *beautifySlider;
@property HUMSlider *vignetteSlider;
@property NSString *sessionPreset;
@property NSInteger selectedStretch;
@property NSInteger filterCount;

@property UIImageView *testImgView;
@property(nonatomic,retain) CIDetector *faceDetector;

@property (nonatomic, retain ) IFlyFaceDetector *Itracker;
//
@property NSArray *stickerData;
@property NSTimeInterval beginTime;
@property NSInteger stickerFrameIndex;
@property NSInteger selectedSticker;
@property NSMutableDictionary *stickerConfig;
@property NSString *stickerBasePath;
@property (weak, nonatomic) IBOutlet UIView *stickerListView;
@property CIContext *ciContext;
@end


@implementation StickerCameraViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [SliderManage reset];
    
    self.hideTabBar = YES;
    self.hideNavigationBar = YES;
    self.ratio = ratioNormal;
    self.time = 0;
    self.filterIndex = 1;
    self.beautify = YES;
    //    self.sessionPreset = AVCaptureSessionPresetPhoto;
    self.sessionPreset = AVCaptureSessionPreset640x480;
//    self.sessionPreset = AVCaptureSessionPreset1280x720;
    self.selectedStretch = 0;
    self.darkButton.layer.opacity = 0.5;
    self.blueButton.layer.opacity = 0.5;
    self.stickerFrameIndex = 0;
    self.selectedSticker = 0;
    isUsingFrontFacingCamera = YES;
    self.ciContext = [CIContext contextWithOptions:nil];
    
    self.Itracker= [IFlyFaceDetector sharedInstance];
    NSString *strEnable = @"1";
    [self.Itracker setParameter:strEnable forKey:@"detect"];
    [self.Itracker setParameter:strEnable forKey:@"align"];
    
    self.stickerData = @[
                         @{@"folder":@"eyes_small2",@"name":@"eyes"},
                         @{@"folder":@"bunny",@"name":@"bunny"},
                         
                         ];
    int i = 0;
    for (NSDictionary *item in self.stickerData) {
        UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(i * 80, 10, 70, 40)];
        [button setTitle:item[@"name"] forState:UIControlStateNormal];
        //        [button setImage:[UIImage imageNamed:@"stretchButton"] forState:UIControlStateNormal];
        [self.stickerListView addSubview:button];
        [button addTarget:self action:@selector(pushedSticker:) forControlEvents:UIControlEventTouchUpInside];
        i++;
    }
    
    
    if ([GPUImageContext supportsFastTextureUpload])
    {
        NSDictionary *detectorOptions = [[NSDictionary alloc] initWithObjectsAndKeys:CIDetectorAccuracyLow, CIDetectorAccuracy, CIDetectorMinFeatureSize,@(0.15),nil];
        self.faceDetector = [CIDetector detectorOfType:CIDetectorTypeFace context:nil options:detectorOptions];
        faceThinking = false;
    }
    
    self.primaryView = [[GPUImageView alloc] initWithFrame:CGRectMake(0, 0, SCREEN_WIDTH , SCREEN_WIDTH  * (16./9.))];
    [self.cameraView addSubview:self.primaryView];
    [self.primaryView setInputRotation:kGPUImageFlipHorizonal atIndex:0];
    
    AVCaptureVideoOrientation newOrientation;
    switch ([[UIDevice currentDevice] orientation]) {
        case UIDeviceOrientationPortrait:
            newOrientation = AVCaptureVideoOrientationPortrait;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            newOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
            break;
        case UIDeviceOrientationLandscapeLeft:
            newOrientation = AVCaptureVideoOrientationLandscapeRight;
            break;
        case UIDeviceOrientationLandscapeRight:
            newOrientation = AVCaptureVideoOrientationLandscapeLeft;
            break;
        default:
            newOrientation = AVCaptureVideoOrientationPortrait;
    }
    
    videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:self.sessionPreset cameraPosition:AVCaptureDevicePositionFront];
    videoCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
    
    //    videoCamera.outputImageOrientation
    self.imgSize = CGSizeMake(1280,720);
    
    self.smoothFilter  = [[GPUSmoothFilter alloc] init];
    self.cropFilter = [[GPUImageCropFilter alloc] init];
    self.lutFilter = [[GPUImageLutFilter alloc] init];
    self.peopleFilter = [GPUImagePeopleFilter new];
    self.myFilter = [[MyFilter alloc] init];
    for (NSDictionary *group in self.myFilter.filterGroup) {
        self.filterCount += [group[@"subtools"] count];
    }
    
    [self resetFilters];
    [videoCamera addTarget:self.primaryView];
    [videoCamera startCameraCapture];
    
    @weakify(self);
    self.backButton.rac_command = [[RACCommand alloc] initWithSignalBlock:^RACSignal *(id input) {
        @strongify(self);
        [self back];
        return [RACSignal empty];
    }];
    
    self.switchButton.rac_command = [[RACCommand alloc] initWithSignalBlock:^RACSignal *(id input) {
        @strongify(self);
        [videoCamera rotateCamera];
        AVCaptureDevicePosition currentCameraPosition = [videoCamera cameraPosition];
        isUsingFrontFacingCamera = false;
        if (currentCameraPosition != AVCaptureDevicePositionBack){
            isUsingFrontFacingCamera = TRUE;
        }
        [self resetFilters];
        
        if(isUsingFrontFacingCamera){
            [self.primaryView setInputRotation:kGPUImageFlipHorizonal atIndex:0];
        }else{
            [self.primaryView setInputRotation:kGPUImageNoRotation atIndex:0];
        }
        return [RACSignal empty];
    }];
    
    [videoCamera setDelegate:self];
    faceView = [[UIView alloc] initWithFrame:CGRectMake(100.0, 100.0, 100.0, 100.0)];
    faceView.layer.borderWidth = 1;
    faceView.layer.borderColor = [[UIColor redColor] CGColor];
    [self.view addSubview:faceView];
    faceView.hidden = YES;
    
    self.testImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 400, 300)];
    self.testImgView.layer.borderWidth = 1;
    self.testImgView.layer.borderColor = [[UIColor redColor] CGColor];
    [self.view addSubview:self.testImgView];
    
    //    NSString* strResult=[self.Itracker detectARGB:[UIImage imageNamed:@"IMG_02381.JPG"]];
    //    NSLog(@"result:%@",strResult);
}

-(void)resetFilters{
    [self setFilter:self.filterIndex];
    self.beginTime = [NSDate timeIntervalSinceReferenceDate];
}

-(void) setFilter:(NSInteger) index {
    
    if(index >= self.filterCount){
        self.filterIndex = 1;
    }
    if(self.filterIndex <= 0){
        self.filterIndex = self.filterCount;
    }
    
    NSInteger filterCount = 0;
    NSInteger groupCount = 0;
    NSInteger groupFilterIndex = 0;
    for (NSDictionary *group in self.myFilter.filterGroup) {
        NSInteger tempCount = filterCount;
        filterCount += [group[@"subtools"] count];
        if(filterCount >= index){
            groupFilterIndex = index - tempCount - 1;
            break;
        }
        groupCount ++;
    }
    
    //    NSLog(@"index pash %ld %ld",(long)groupCount,(long)groupFilterIndex);
    
    self.filterIndex = index;
    [videoCamera removeAllTargets];
    [self.firstFilter removeAllTargets];
    if(self.cropFilter){
        [self.cropFilter removeAllTargets];
    }
    if(self.smoothFilter){
        [self.smoothFilter removeAllTargets];
    }
    if(self.vignetteFilter){
        [self.vignetteFilter removeAllTargets];
    }
    [self.peopleFilter removeAllTargets];
    [self.peopleFilter2 removeAllTargets];
    [self.peopleFilter3 removeAllTargets];
    [self.peopleFilter4 removeAllTargets];
    [self.lookImg removeAllTargets];
    [self.lookImg2 removeAllTargets];
    [self.lookImg3 removeAllTargets];
    [self.lookImg4 removeAllTargets];
    self.stickerFrameIndex = 0;
    
    GPUImageFilter *secondFilter;
    self.firstFilter = self.cropFilter;
    secondFilter = self.cropFilter;
    //    if(self.beautify){
    //        [self.firstFilter addTarget:self.smoothFilter];
    //        self.smoothFilter.gamma = 0.2;
    //        secondFilter = self.smoothFilter;
    //    }
    //    if(self.vignetteFilter){
    //        [secondFilter addTarget:self.vignetteFilter];
    //    }
    if(self.dark){
        [secondFilter addTarget:self.vignetteFilter];
        secondFilter = self.vignetteFilter;
    }
    
    if(self.selectedStretch > 0){
        [secondFilter addTarget:self.stretchFilter];
        secondFilter = self.stretchFilter;
    }
    
    
    self.stickerBasePath  = [[NSBundle mainBundle] pathForResource:[self.stickerData objectAtIndex:self.selectedSticker][@"folder"] ofType:@""];
    
    NSDictionary *json = [Utils readJson:[[NSString alloc] initWithFormat:@"%@/config.json",self.stickerBasePath]];
    self.stickerConfig = [json mutableDeepCopy];
    
    NSDictionary *parames = @{@"count" : @"0"};
    GPUImagePicture *lookImg = [[GPUImagePicture alloc] initWithImage:[UIImage imageNamed:@"back_normal_open.png"]];
    self.lookImg = lookImg;
    [self.lookImg addTarget:self.peopleFilter atTextureLocation:1];
    [self.lookImg processImage];
    
    int i = 0;
    for (NSDictionary *item in self.stickerConfig[@"items"]) {
        if(i == 0){
            [secondFilter addTarget:self.peopleFilter];
            [self.peopleFilter setStickerParams:parames];
            secondFilter = self.peopleFilter;
        }else if(i == 1){
            if(!self.peopleFilter2){
                self.peopleFilter2 = [GPUImagePeopleFilter new];
            }
            [secondFilter addTarget:self.peopleFilter2];
            [self.peopleFilter2 setStickerParams:parames];
            secondFilter = self.peopleFilter2;
        }else if(i == 2){
            if(!self.peopleFilter3){
                self.peopleFilter3 = [GPUImagePeopleFilter new];
            }
            [secondFilter addTarget:self.peopleFilter3];
            [self.peopleFilter3 setStickerParams:parames];
            secondFilter = self.peopleFilter3;
        }else if(i == 3){
            if(!self.peopleFilter4){
                self.peopleFilter4 = [GPUImagePeopleFilter new];
            }
            [secondFilter addTarget:self.peopleFilter4];
            [self.peopleFilter4 setStickerParams:parames];
            secondFilter = self.peopleFilter4;
        }
        i++;
    }
    
    [videoCamera addTarget:self.firstFilter];
    [self.myFilter setFilter:[NSIndexPath indexPathForItem:groupFilterIndex inSection:groupCount]];
    if(self.myFilter.firstFilter){
        [secondFilter addTarget:self.myFilter.firstFilter];
    }else{
        [secondFilter addTarget:self.myFilter.lastFilter];
    }
    [self.myFilter.lastFilter addTarget:self.primaryView];
    
}


-(void)pushedSticker:(id)sender{
    UIView *view = sender;
    NSInteger index = [view.superview.subviews indexOfObject:view];
    self.selectedSticker = index;
    [self resetFilters];
}

#pragma mark - Face Detection Delegate Callback
- (void)willOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer{
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    NSLog(@" willOutput %f",now);
    
    [videoCamera removeAllTargets];
    [self.peopleFilter removeAllTargets];
    [self.peopleFilter2 removeAllTargets];
    [self.peopleFilter3 removeAllTargets];
    [self.peopleFilter4 removeAllTargets];
    [self.myFilter.firstFilter removeAllTargets];
    [self.myFilter.lastFilter removeAllTargets];
    [self.lookImg removeAllTargets];
    [self.lookImg2 removeAllTargets];
    [self.lookImg3 removeAllTargets];
    [self.lookImg4 removeAllTargets];
    int i = 0;
    for (NSDictionary *item in self.stickerConfig[@"items"]) {
        NSString *path = [[NSString alloc] initWithFormat:@"%@/%@",self.stickerBasePath,item[@"folderName"]];
        int index = self.stickerFrameIndex % [item[@"frames"] intValue];
        NSString *fileName = [[NSString alloc] initWithFormat:@"%@/%@_%03d.png",path,item[@"folderName"],index];
        GPUImagePicture *lookImg = [[GPUImagePicture alloc] initWithImage:[UIImage imageWithContentsOfFile:fileName]];
        if(i == 0){
            self.lookImg = lookImg;
            [self.lookImg addTarget:self.peopleFilter atTextureLocation:1];
            [self.lookImg processImage];
        }else if(i == 1){
            self.lookImg2 = lookImg;
            [self.lookImg2 addTarget:self.peopleFilter2 atTextureLocation:1];
            [self.lookImg2 processImage];
        }else if(i == 2){
            self.lookImg3 = lookImg;
            [self.lookImg3 addTarget:self.peopleFilter3 atTextureLocation:1];
            [self.lookImg3 processImage];
        }else if(i == 3){
            self.lookImg4 = lookImg;
            [self.lookImg4 addTarget:self.peopleFilter4 atTextureLocation:1];
            [self.lookImg4 processImage];
        }
        i++;
    }
    GPUImageFilter *peopleFilter;
    if(i == 1){
        peopleFilter = self.peopleFilter;
    }else if(i == 2){
        peopleFilter = self.peopleFilter2;
    }else if(i == 3){
        peopleFilter = self.peopleFilter3;
    }else if(i == 4){
        peopleFilter = self.peopleFilter4;
    }
    
    if(self.myFilter.firstFilter){
        [peopleFilter addTarget:self.myFilter.firstFilter];
    }else{
        [peopleFilter addTarget:self.myFilter.lastFilter];
    }
    [self.myFilter.lastFilter addTarget:self.primaryView];
    [videoCamera addTarget:self.firstFilter];
    
    self.stickerFrameIndex ++;
    
    if (!faceThinking) {
        [self grepFacesForSampleBuffer:sampleBuffer];
    }else{
        NSLog(@"faceThinking");
    }
}

- (void)grepFacesForSampleBuffer:(CMSampleBufferRef)sampleBuffer{
    faceThinking = TRUE;
    
    CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    uint8_t *lumaBuffer  = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    
    size_t bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer,0);
    size_t width  = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    
    CGColorSpaceRef grayColorSpace = CGColorSpaceCreateDeviceGray();
    
    CGContextRef context=CGBitmapContextCreate(lumaBuffer, width, height, 8, bytesPerRow, grayColorSpace,0);
    CGImageRef cgImage = CGBitmapContextCreateImage(context);
    //self.testImgView.image = [[UIImage alloc] initWithCGImage:cgImage];
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    IFlyFaceDirectionType faceOrientation = [self faceImageOrientation];
    
    IFlyFaceImage* faceImage=[[IFlyFaceImage alloc] init];
    
    
    CGDataProviderRef provider = CGImageGetDataProvider(cgImage);
    
    faceImage.data= (__bridge_transfer NSData*)CGDataProviderCopyData(provider);
    faceImage.width=width;
    faceImage.height=height;
    faceImage.direction=faceOrientation;
    
    CGImageRelease(cgImage);
    CGContextRelease(context);
    CGColorSpaceRelease(grayColorSpace);
    NSString *strResult = [[IFlyFaceDetector sharedInstance] trackFrame:faceImage.data withWidth:faceImage.width height:faceImage.height direction:(int)faceImage.direction];
    
//    NSLog(@"result hahahahaha :%@",strResult);
    
//    CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
//    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
//    
//    uint8_t *lumaBuffer  = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
//    
//    size_t bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer,0);
//    size_t width  = CVPixelBufferGetWidth(pixelBuffer);
//    size_t height = CVPixelBufferGetHeight(pixelBuffer);
////    size_t width  = 640;
////    size_t height = 480;
//    CGColorSpaceRef grayColorSpace = CGColorSpaceCreateDeviceGray();
//    
//    CGContextRef context = CGBitmapContextCreate(lumaBuffer, width, height, 8, bytesPerRow, grayColorSpace,0);
//    CGContextTranslateCTM(context,0, 0);
//    CGContextScaleCTM(context, 0.64,0.64);
//    CGContextSaveGState(context);
//    
//    CGImageRef cgImage = CGBitmapContextCreateImage(context);
//    //self.testImgView.image = [[UIImage alloc] initWithCGImage:cgImage];
//    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
//    
////    self.testImgView.image = [[UIImage alloc] initWithCGImage:cgImage];
//    
////    UIImage *image = [UIImage imageWithCGImage:cgImage scale:(720.0/480.0) orientation:UIImageOrientationUp];
//    
//    NSLog(@"size %zu", CGImageGetWidth(cgImage));
//    self.testImgView.image = [[UIImage alloc] initWithCGImage:cgImage];
//    [videoCamera stopCameraCapture];
//    IFlyFaceDirectionType faceOrientation = [self faceImageOrientation];
//    
//    IFlyFaceImage* faceImage=[[IFlyFaceImage alloc] init];
//    
//    
//    CGDataProviderRef provider = CGImageGetDataProvider(cgImage);
//    
//    faceImage.data= (__bridge_transfer NSData*)CGDataProviderCopyData(provider);
//    faceImage.width=width;
//    faceImage.height=height;
//    faceImage.direction=faceOrientation;
//    
//    CGImageRelease(cgImage);
//    CGContextRelease(context);
//    CGColorSpaceRelease(grayColorSpace);
//    NSString *strResult = [[IFlyFaceDetector sharedInstance] trackFrame:faceImage.data withWidth:faceImage.width height:faceImage.height direction:(int)faceImage.direction];
//    NSLog(@"result hahahahaha :%@",strResult);
    
//    获取灰度图像数据
//    CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
//    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
//    CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate);
//    CIImage *ciImage = [[CIImage alloc] initWithCVPixelBuffer:pixelBuffer options:(__bridge NSDictionary *)attachments];
//    if (attachments)
//        CFRelease(attachments);
//    
//    CIFilter *filter = [CIFilter filterWithName:@"CIColorControls"];
//    [filter setValue:ciImage forKey:kCIInputImageKey];
//    [filter setValue:@(0.0) forKey:kCIInputSaturationKey];
//    
//    CIImage *outputImage = filter.outputImage;
//    CGImageRef cgImage = [self.ciContext createCGImage:outputImage fromRect:outputImage.extent];
//    ciImage = [[ciImage imageByApplyingTransform:CGAffineTransformMakeScale(480.0/750.0,480.0/750.0)] imageByCroppingToRect:CGRectMake((480.0/750.0*1280 - 640.0)/2.0, 0, 640.0, 480.0)];
    
//    NSUInteger bytesPerRow = 4 * sizeof(float) * 640.0;
//    float* rawData = (float*)malloc(bytesPerRow * 480.0);
//    CGColorSpaceRef grayColorSpace = CGColorSpaceCreateDeviceGray();
//    CGContextRef context = CGBitmapContextCreate(rawData, 640.0, 480.0, 8, bytesPerRow, grayColorSpace,0);
//    
//    CGImageRef ref = [self.ciContext createCGImage:ciImage fromRect:ciImage.extent];
//    CGContextDrawImage(context, CGRectMake(0, 0, 640.0, 480.0),ref);
//
//    CGImageRef cgImage = CGBitmapContextCreateImage(context);
//    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);

//    IFlyFaceDirectionType faceOrientation = [self faceImageOrientation];
//    IFlyFaceImage *faceImage=[[IFlyFaceImage alloc] init];
//    if(!faceImage){
//        return;
//    }
// 
//    self.testImgView.image = [[UIImage alloc] initWithCGImage:cgImage];
//    NSLog(@"w h %@",NSStringFromCGSize(self.testImgView.image.size));
//    
////    [videoCamera stopCameraCapture];
//    size_t width  = CVPixelBufferGetWidth(pixelBuffer);
//    size_t height = CVPixelBufferGetHeight(pixelBuffer);
//    CGDataProviderRef provider = CGImageGetDataProvider(cgImage);
//    faceImage.data= (__bridge_transfer NSData*)CGDataProviderCopyData(provider);
//    faceImage.width = width;
//    faceImage.height = height;
//    faceImage.direction = faceOrientation;
//    
//    CGImageRelease(cgImage);
////    CGImageRelease(ref);
////    CGContextRelease(context);
////    CGColorSpaceRelease(grayColorSpace);
//    NSString *strResult = [self.Itracker trackFrame:faceImage.data withWidth:faceImage.width height:faceImage.height direction:(int)faceImage.direction];
//    NSLog(@"result:%@",strResult);
//    
////    此处清理图片数据，以防止因为不必要的图片数据的反复传递造成的内存卷积占用。
//    faceImage.data=nil;
 
    [self GPUVCWillOutputFeatures:strResult :faceImage];
    faceImage = nil;
    faceThinking = FALSE;
}

- (void)GPUVCWillOutputFeatures:(NSString*)result :(IFlyFaceImage *)faceImg
{
    
    NSError* error;
    NSData* resultData=[result dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary* faceDic=[NSJSONSerialization JSONObjectWithData:resultData options:NSJSONReadingMutableContainers error:&error];
    resultData=nil;
    if(!faceDic){
        return;
    }
    
    NSString* faceRet=[faceDic objectForKey:KCIFlyFaceResultRet];
    NSArray* faceArray=[faceDic objectForKey:KCIFlyFaceResultFace];
    faceDic=nil;
    
    int ret=0;
    if(faceRet){
        ret=[faceRet intValue];
    }
    //没有检测到人脸或发生错误
    if (ret || !faceArray || [faceArray count]<1) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSDictionary *parames = @{ @"count" : @"0"};
            [self.peopleFilter setStickerParams:parames];
            faceThinking = FALSE;
            return;
        });
        return;
    }
    
    //检测到人脸
    
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
//    NSLog(@" beginTime %ld %f %f ",(long)self.stickerFrameIndex,now,  now - self.beginTime);
    
    NSMutableDictionary *template = [[NSMutableDictionary alloc] init];
    [template setObject:[NSMutableArray new] forKey:@"count"];
    [template setObject:[NSMutableArray new] forKey:@"angle"];
    [template setObject:[NSMutableArray new] forKey:@"point"];
    [template setObject:[NSMutableArray new] forKey:@"size"];
    
    NSMutableArray *faceParameArray = [[NSMutableArray alloc] initWithObjects:[template mutableDeepCopy],[template mutableDeepCopy],[template mutableDeepCopy],[template mutableDeepCopy], nil];
    NSMutableDictionary *faceParames = [faceParameArray objectAtIndex:0];
    faceParames[@"count"] = [[NSString alloc] initWithFormat:@"%d",3];
    
    NSInteger currentFeature = 0;
    NSInteger faceCount = [faceArray count];
    NSMutableArray *arrPersons = [NSMutableArray array] ;
    
    for(id faceInArr in faceArray){
        if(!faceInArr || ![faceInArr isKindOfClass:[NSDictionary class]]){
            continue;
        }
        
        NSDictionary* positionDic=[faceInArr objectForKey:KCIFlyFaceResultPosition];
        NSString* rectString=[self praseDetect:positionDic OrignImage: faceImg];
        positionDic=nil;
        
        NSDictionary* landmarkDic=[faceInArr objectForKey:KCIFlyFaceResultLandmark];
        NSMutableDictionary *strPoints=[self praseAlign:landmarkDic OrignImage:faceImg];
        landmarkDic=nil;
        
        CGFloat bottom =[[positionDic objectForKey:KCIFlyFaceResultBottom] floatValue];
        CGFloat top=[[positionDic objectForKey:KCIFlyFaceResultTop] floatValue];
        CGFloat left=[[positionDic objectForKey:KCIFlyFaceResultLeft] floatValue];
        CGFloat right=[[positionDic objectForKey:KCIFlyFaceResultRight] floatValue];
        float cx = (left+right)/2;
        float cy = (top + bottom)/2;
        float w = right - left;
        float h = bottom - top;
        float ncx = cy ;
        float ncy = cx ;
        
        CGRect faceRect = CGRectMake(ncx-w/2 ,ncy-w/2 , w, h);
        
        CGFloat temp = faceRect.size.width;
        faceRect.size.width = faceRect.size.height;
        faceRect.size.height = temp;
        temp = faceRect.origin.x;
        faceRect.origin.x = faceRect.origin.y;
        faceRect.origin.y = temp;
        
        CGFloat widthScaleBy = SCREEN_WIDTH  / 720.0;
        CGFloat heightScaleBy = SCREEN_HEIGHT / 1280.0;
        faceRect.size.width *= widthScaleBy;
        faceRect.size.height *= heightScaleBy;
        faceRect.origin.x *= widthScaleBy;
        faceRect.origin.y *= heightScaleBy;
        
        int i = 0;
        for (NSDictionary *item in self.stickerConfig[@"items"]) {
            CGSize stickSize = CGSizeMake([item[@"width"] floatValue],[item[@"height"] floatValue]);
            int stickType = [item[@"type"] intValue];
            UIEdgeInsets insert = UIEdgeInsetsFromString(item[@"insert"]);
            CGPoint sizePoint = CGPointMake(faceRect.size.width / SCREEN_WIDTH, faceRect.size.width * (stickSize.height/stickSize.width)/SCREEN_HEIGHT);
            CGPoint center =  CGPointMake((faceRect.origin.x + faceRect.size.width/2) / SCREEN_WIDTH, (faceRect.origin.y + faceRect.size.height/2) / SCREEN_HEIGHT - (insert.top - insert.bottom) * sizePoint.y );
            
            
            CGPoint leftPoint = CGPointFromString(strPoints[@"left_eye_left_corner"]);
            CGPoint rightPoint = CGPointFromString(strPoints[@"right_eye_right_corner"]);
            CGPoint mouthPoint = CGPointFromString(strPoints[@"mouth_middle"]);
            int xDistance = ABS(rightPoint.x - leftPoint.x);
            int yDistance = ABS(rightPoint.y - leftPoint.y);
            CGFloat w =  sqrtf(xDistance * xDistance + yDistance * yDistance) * [item[@"scale"] floatValue];
           // CGFloat w = MAX(xDistance, yDistance) * [item[@"scale"] floatValue];
            CGPoint eayCenter = CGPointMake((leftPoint.x + rightPoint.x) / 2.0  , (leftPoint.y + rightPoint.y)/2.0);
            
           
            NSLog(@"left %@, right %@ w %f ",NSStringFromCGPoint(leftPoint), NSStringFromCGPoint(rightPoint), w);
            
            sizePoint = CGPointMake(w / SCREEN_WIDTH, w * (stickSize.height/stickSize.width)/SCREEN_HEIGHT);
            
            if(stickType == 1){
                center =  CGPointMake(mouthPoint.x / SCREEN_WIDTH + (insert.left - insert.right) * sizePoint.x, mouthPoint.y / SCREEN_HEIGHT + (insert.top - insert.bottom) * sizePoint.y );
            }
            if(stickType == 2){
                center = CGPointMake(eayCenter.x / SCREEN_WIDTH , eayCenter.y / SCREEN_HEIGHT);
            }
            
            NSMutableDictionary *faceParames = [faceParameArray objectAtIndex:i];
            [faceParames[@"point"] addObject:NSStringFromCGPoint(center)];
            faceParames[@"count"] = [[NSString alloc] initWithFormat:@"%ld",(long)faceCount];
            
            //            if(!isUsingFrontFacingCamera){
            //            [faceParames[@"angle"] addObject:NSStringFromCGPoint(CGPointMake(ff.faceAngle/90.0, 1.0))];
            //            }else{
            //                [faceParames[@"angle"] addObject:NSStringFromCGPoint(CGPointMake(ff.faceAngle/-90.0, 1.0))];
            //            }
//             CGFloat rotationAngle = atan((leftPoint.y - rightPoint.y) / (leftPoint.x - rightPoint.x));
//            NSLog(@"rotationAngle %f",rotationAngle);
           // [faceParames[@"angle"] addObject:NSStringFromCGPoint(CGPointMake( 1.0 - rotationAngle / M_PI_2, 1.0))];
            CGFloat a = ABS(eayCenter.y - mouthPoint.y);
            CGFloat b = ABS(eayCenter.x - mouthPoint.x);
            CGFloat c = sqrtf(a * a + b * b);
            //            if(ABS(eayCenter.y - mouthPoint.y) > ABS(eayCenter.x - mouthPoint.x)){
//            rotationAngle = atan(ABS(eayCenter.y - mouthPoint.y) / ABS(eayCenter.x - mouthPoint.x));
            //            }else{
            //                rotationAngle = atan(ABS(eayCenter.y - mouthPoint.y) / ABS(eayCenter.x - mouthPoint.x));
            //            }
            [faceParames[@"angle"] addObject:NSStringFromCGPoint(CGPointMake(b/c, a/c))];
            NSLog(@"angle %@", NSStringFromCGPoint(CGPointMake(b/c, a/c)));
            [faceParames[@"size"] addObject:NSStringFromCGPoint(sizePoint)];
            i++;
        }
        
        currentFeature++;
    }
    
    faceArray=nil;
    
    int i = 0;
    for (NSDictionary *item in self.stickerConfig[@"items"]) {
        if(i == 0){
            //            NSLog(@" item %d",[faceParameArray[i][@"count"] intValue]);
            [self.peopleFilter setStickerParams:faceParameArray[i]];
        }else if(i == 1){
            [self.peopleFilter2 setStickerParams:faceParameArray[i]];
        }else if(i == 2){
            [self.peopleFilter3 setStickerParams:faceParameArray[i]];
        }else if(i == 3){
            [self.peopleFilter4 setStickerParams:faceParameArray[i]];
        }
        i++;
    }
    //      NSDictionary *parames = @{
    //                                @"count" : @"1",
    //                                @"angle" : @[NSStringFromCGPoint(CGPointMake(0.0, 0.5))],
    //                                @"point" : @[NSStringFromCGPoint(CGPointMake(0.5, 0.5))], //center
    //                                @"size" : @[NSStringFromCGPoint(CGPointMake(0.5, 0.5))],
    //                                };
    //      [self.peopleFilter setStickerParams:parames];
}
//        dispatch_async(dispatch_get_main_queue(), ^{
//
//        CGRect previewBox = self.view.frame;
//
//        if (featureArray == nil && faceView) {
//            [faceView removeFromSuperview];
//            faceView = nil;
//        }
//        [faceView removeFromSuperview];
//        [leftEye removeFromSuperview];
//        [leftEyeView removeFromSuperview];
//        [mouth removeFromSuperview];
//
//        for ( CIFaceFeature *faceFeature in featureArray) {
//            CGFloat faceWidth = faceFeature.bounds.size.height;
//            CGRect faceRect = [faceFeature bounds];
//
//            // flip preview width and height
//            CGFloat temp = faceRect.size.width;
//            faceRect.size.width = faceRect.size.height;
//            faceRect.size.height = temp;
//            temp = faceRect.origin.x;
//            faceRect.origin.x = faceRect.origin.y;
//            faceRect.origin.y = temp;
//            // scale coordinates so they fit in the preview box, which may be scaled
//            CGFloat widthScaleBy = previewBox.size.width / clap.size.height;
//            CGFloat heightScaleBy = previewBox.size.height / clap.size.width;
//            faceRect.size.width *= widthScaleBy;
//            faceRect.size.height *= heightScaleBy;
//            faceRect.origin.x *= widthScaleBy;
//            faceRect.origin.y *= heightScaleBy;
//
//            faceRect = CGRectOffset(faceRect, previewBox.origin.x, previewBox.origin.y);
//
//            if (faceView) {
//                [faceView removeFromSuperview];
//                faceView =  nil;
//            }
//
//            // create a UIView using the bounds of the face
//            faceView = [[UIView alloc] initWithFrame:faceRect];
//
//            // add a border around the newly created UIView
//            faceView.layer.borderWidth = 1;
//            faceView.layer.borderColor = [[UIColor redColor] CGColor];
//
//            // add the new view to create a box around the face
//            [self.view addSubview:faceView];
//
//            if(faceFeature.hasLeftEyePosition)
//            {
//                // create a UIView with a size based on the width of the face
//                leftEyeView = [[UIView alloc] initWithFrame:CGRectMake(faceFeature.leftEyePosition.y * widthScaleBy, faceFeature.leftEyePosition.x * heightScaleBy, faceWidth*0.3 * widthScaleBy, faceWidth * 0.3 *heightScaleBy )];
//                // change the background color of the eye view
//                [leftEyeView setBackgroundColor:[[UIColor blueColor] colorWithAlphaComponent:0.3]];
//                // set the position of the leftEyeView based on the face
////                [leftEyeView setCenter:faceFeature.leftEyePosition];
//                // round the corners
////                leftEyeView.layer.cornerRadius = faceWidth*0.15;
//                // add the view to the window
//                [self.view addSubview:leftEyeView];
//            }
//
//            if(faceFeature.hasRightEyePosition)
//            {
//                // create a UIView with a size based on the width of the face
//                leftEye = [[UIView alloc] initWithFrame:CGRectMake(faceFeature.rightEyePosition.x-faceWidth*0.15, faceFeature.rightEyePosition.y-faceWidth*0.15, faceWidth*0.3, faceWidth*0.3)];
//                // change the background color of the eye view
//                [leftEye setBackgroundColor:[[UIColor blueColor] colorWithAlphaComponent:0.3]];
//                // set the position of the rightEyeView based on the face
//                [leftEye setCenter:faceFeature.rightEyePosition];
//                // round the corners
//                leftEye.layer.cornerRadius = faceWidth*0.15;
//                // add the new view to the window
//                [self.view addSubview:leftEye];
//            }
//
//            if(faceFeature.hasMouthPosition)
//            {
//                // create a UIView with a size based on the width of the face
//                mouth = [[UIView alloc] initWithFrame:CGRectMake(faceFeature.mouthPosition.x-faceWidth*0.2, faceFeature.mouthPosition.y-faceWidth*0.2, faceWidth*0.4, faceWidth*0.4)];
//                // change the background color for the mouth to green
//                [mouth setBackgroundColor:[[UIColor greenColor] colorWithAlphaComponent:0.3]];
//                // set the position of the mouthView based on the face
//                [mouth setCenter:faceFeature.mouthPosition];
//                // round the corners
//                mouth.layer.cornerRadius = faceWidth*0.2;
//                // add the new view to the window
//                [self.view addSubview:mouth];
//            }
//
//
//        }
//    });

-(NSMutableDictionary *)praseAlign:(NSDictionary *)landmarkDic OrignImage:(IFlyFaceImage*)faceImg{
    if(!landmarkDic){
        return nil;
    }
    
    // 判断摄像头方向
    BOOL isFrontCamera= isUsingFrontFacingCamera;
    
    // scale coordinates so they fit in the preview box, which may be scaled
    CGFloat widthScaleBy = SCREEN_WIDTH / faceImg.height;
    CGFloat heightScaleBy = SCREEN_HEIGHT / faceImg.width;
    
    NSMutableDictionary *arrStrPoints = [NSMutableDictionary new] ;
    NSEnumerator *keys = [landmarkDic keyEnumerator];
    for(id key in keys){
        id attr=[landmarkDic objectForKey:key];
        if(attr && [attr isKindOfClass:[NSDictionary class]]){
            id attr=[landmarkDic objectForKey:key];
            CGFloat x=[[attr objectForKey:KCIFlyFaceResultPointX] floatValue];
            CGFloat y=[[attr objectForKey:KCIFlyFaceResultPointY] floatValue];
            
            CGPoint p = CGPointMake(y,x);
            if(!isFrontCamera){
                p=pSwap(p);
                p=pRotate90(p, faceImg.height, faceImg.width);
            }
            p=pScale(p, widthScaleBy, heightScaleBy);
            [arrStrPoints setObject:NSStringFromCGPoint(p) forKey:key];
        }
    }
    return arrStrPoints;
}

-(NSString*)praseDetect:(NSDictionary* )positionDic OrignImage:(IFlyFaceImage*)faceImg{
    if(!positionDic){
        return nil;
    }
    
    // 判断摄像头方向
    BOOL isFrontCamera = isUsingFrontFacingCamera;
    
    // scale coordinates so they fit in the preview box, which may be scaled
    CGFloat widthScaleBy = SCREEN_WIDTH / faceImg.height;
    CGFloat heightScaleBy = SCREEN_HEIGHT / faceImg.width;
    
    CGFloat bottom =[[positionDic objectForKey:KCIFlyFaceResultBottom] floatValue];
    CGFloat top=[[positionDic objectForKey:KCIFlyFaceResultTop] floatValue];
    CGFloat left=[[positionDic objectForKey:KCIFlyFaceResultLeft] floatValue];
    CGFloat right=[[positionDic objectForKey:KCIFlyFaceResultRight] floatValue];
    
    float cx = (left+right)/2;
    float cy = (top + bottom)/2;
    float w = right - left;
    float h = bottom - top;
    
    float ncx = cy ;
    float ncy = cx ;
    
    CGRect rectFace = CGRectMake(ncx-w/2 ,ncy-w/2 , w, h);
    
    if(!isFrontCamera){
        rectFace=rSwap(rectFace);
        rectFace=rRotate90(rectFace, faceImg.height, faceImg.width);
    }
    
    rectFace=rScale(rectFace, widthScaleBy, heightScaleBy);
    return NSStringFromCGRect(rectFace);
}

-(IFlyFaceDirectionType)faceImageOrientation{
    
    IFlyFaceDirectionType faceOrientation = IFlyFaceDirectionTypeLeft;
 
    BOOL isFrontCamera = isUsingFrontFacingCamera;
    
    switch (self.interfaceOrientation) {
        case UIDeviceOrientationPortrait:{//
            faceOrientation=IFlyFaceDirectionTypeLeft;
        }
            break;
        case UIDeviceOrientationPortraitUpsideDown:{
            faceOrientation=IFlyFaceDirectionTypeRight;
        }
            break;
        case UIDeviceOrientationLandscapeRight:{
            faceOrientation=isFrontCamera?IFlyFaceDirectionTypeUp:IFlyFaceDirectionTypeDown;
        }
            break;
        default:{//
            faceOrientation=isFrontCamera?IFlyFaceDirectionTypeDown:IFlyFaceDirectionTypeUp;
        }
            
            break;
    }
    
    return faceOrientation;
}

- (void)viewWillDisappear:(BOOL)animated{
    [videoCamera stopCameraCapture];
    [super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */

@end