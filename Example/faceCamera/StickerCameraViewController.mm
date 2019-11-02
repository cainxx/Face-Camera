//
//  StickerCameraViewController.m
//  faceCamera
//
//  Created by cain on 16/3/2.
//  Copyright © 2016年 cain. All rights reserved.
//

#import "StickerCameraViewController.h"
#import "GPUImageStickerFilter.h"
#import "GPUImagePeopleFilter.h"
#import "GPUImageMeshFilter.h"
#import "GPUImageFilter.h"
#import "GPUFaceImageFilter.h"
#import "GPUImageBlendFilter.h"
#import "VideoCamera.h"
#import "RecordButton.h"

#import <CoreVideo/CVPixelBuffer.h>
#import <opencv2/opencv.hpp>
#include <iostream>
#include "FaceDetect.h"
#import <opencv2/videoio/cap_ios.h>
#import <opencv2/imgcodecs/ios.h>

#define ACTIVE_STICKER_TAG 10001
#define ICON_TAG 10002

typedef enum{
    EayCenter,
    LeftEayCenter,
    RightEayCenter,
    MouthMidPoint,
    MouthLeft,
    MouthRight,
    NoseBottom,
    MouthTop,
    MouthBottom,
}Position;

@interface StickerCameraViewController ()<GPUImageVideoCameraDelegate,AVCaptureMetadataOutputObjectsDelegate>{
    UIView *faceView;
    UIView *leftEyeView;
    UIView *leftEye;
    UIView *mouth;
}

@property (weak, nonatomic) IBOutlet UIView *cameraView;
@property (weak, nonatomic) IBOutlet UIButton *switchCamera;
@property (weak, nonatomic) IBOutlet RecordButton *recordButton;
@property (weak, nonatomic) IBOutlet UIButton *stickerButton;
@property (weak, nonatomic) IBOutlet UIButton *ratioButton;

@property (weak, nonatomic) IBOutlet UIView *stickerListView;
@property (weak, nonatomic) IBOutlet UIScrollView *stickerScrollView;
@property (weak, nonatomic) IBOutlet UIScrollView *stickerTabBarView;
@property (weak, nonatomic) IBOutlet UILabel *hintLabel;
@property (weak, nonatomic) IBOutlet UIView *bottomView;

@property BOOL isFrontCamera;
@property VideoCamera *videoCamera;

@property GPUImageView *GPUView;
@property GPUImagePicture *mainStickerImg;
@property GPUImagePicture *faceWidgetImg1;
@property GPUImagePicture *faceWidgetImg2;
@property GPUImagePicture *faceWidgetImg3;
@property GPUImagePicture *faceWidgetImg4;
@property GPUImagePicture *faceWidgetImg5;
@property GPUImagePicture *faceWidgetImg6;
@property GPUImagePicture *skinImg;
@property GPUImagePicture *placeholderImg;

@property GPUImageCropFilter *cropFilter;
@property GPUImagePeopleFilter *faceWidgetFilter;
@property GPUImagePeopleFilter *faceWidgetFilter2;
@property GPUImagePeopleFilter *faceWidgetFilter3;
@property GPUImagePeopleFilter *faceWidgetFilter4;
@property GPUImagePeopleFilter *faceWidgetFilter5;
@property GPUImagePeopleFilter *faceWidgetFilter6;
@property GPUImageStickerFilter *backgroundFilter;
@property GPUImageFilter *stickerAttachFilter;
@property GPUImageMeshFilter *meshFilter;
@property GPUImageBlendFilter *blendfilter;

@property GPUImageFilter *firstFilter;
@property GPUImageFilter *laseFilter;

@property NSString *sessionPreset;
@property NSArray *stickerData;
@property NSTimeInterval beginTime;
@property NSTimeInterval lastUpStickerTime;
@property NSTimeInterval lastDetectorFaceTime;
@property NSInteger stickerFrameIndex;
@property NSInteger mouthStickerFrameIndex;
@property NSInteger selectedSticker;
@property (retain, atomic)NSDictionary *stickerConfig;
@property (retain, atomic)NSString *stickerPath;

@property CGSize cameraSize;
@property (nonatomic) NSTimer *progressTimer;
@property CGFloat progress;

@property NSArray *stickersData;
@property NSMutableDictionary *gpuImagesCache;

@property UIView *actionStickerView;
@property BOOL detectoredFace;

@property UIImageView *faceAlertView;
@property NSURL *movieURL;
@property GPUImageMovieWriter *movieWriter;
@property FaceDetect *facear;
@property GPUFaceImageFilter *faceFilter;

@property BOOL mouthOpening;
@property CGFloat xcrop;
@property CGFloat xoffect;

@end

@implementation StickerCameraViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    @weakify(self);
    self.hideTabBar = YES;
    self.hideNavigationBar = YES;
    self.lastUpStickerTime = [NSDate timeIntervalSinceReferenceDate];
    self.gpuImagesCache = [NSMutableDictionary new];
    
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)];
    [self.recordButton addGestureRecognizer:longPress];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)];
    [self.recordButton addGestureRecognizer:tap];
    self.recordButton.buttonStyle = recordButton;

    self.sessionPreset = AVCaptureSessionPreset1280x720;
    self.cameraSize = CGSizeMake(720,1280);
    self.isFrontCamera = YES;
    self.videoCamera = [[VideoCamera alloc] initWithSessionPreset:self.sessionPreset cameraPosition:AVCaptureDevicePositionFront useYuv:NO];
    self.videoCamera.outputImageOrientation = UIInterfaceOrientationLandscapeLeft;
    [self.videoCamera setDelegate:self];
    
    self.GPUView = [[GPUImageView alloc] initWithFrame:CGRectMake(0, 0, SCREEN_WIDTH , SCREEN_HEIGHT)];
    self.GPUView.backgroundColor = [UIColor colorWithARGBHex:0x00ffffff];
    [self.cameraView addSubview:self.GPUView];
    
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(doubleTap:)];
    [doubleTap setNumberOfTapsRequired:2];
    [self.GPUView addGestureRecognizer:doubleTap];
    
    [self configSticker];
    
    self.faceWidgetFilter = [GPUImagePeopleFilter new];
    self.meshFilter = [[GPUImageMeshFilter alloc] init];
    self.meshFilter.screenRatio = 2.0;
    [self.meshFilter setItems:nil];
    self.blendfilter = [[GPUImageBlendFilter alloc] init];
    self.cropFilter = [[GPUImageCropFilter alloc] init];
    self.cropFilter.cropRegion = CGRectMake(0, 0, 1.0, 1.0);
    self.firstFilter = self.cropFilter;

    self.switchCamera.rac_command = [[RACCommand alloc] initWithSignalBlock:^RACSignal *(id input) {
        @strongify(self);
        [self.videoCamera rotateCamera];
        AVCaptureDevicePosition currentCameraPosition = [self.videoCamera cameraPosition];
        self.isFrontCamera = false;
        if (currentCameraPosition != AVCaptureDevicePositionBack){
            self.isFrontCamera = TRUE;
            self.videoCamera.outputImageOrientation = UIInterfaceOrientationLandscapeLeft;
        }else{
            self.videoCamera.outputImageOrientation = UIInterfaceOrientationLandscapeRight;
        }
        return [RACSignal empty];
    }];
    
    self.ratioButton.rac_command = [[RACCommand alloc] initWithSignalBlock:^RACSignal *(id input) {
        @strongify(self);
        [self.view layoutIfNeeded];
        self.movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL: self.movieURL size:self.cameraSize];
        self.videoCamera.audioEncodingTarget = self.movieWriter;
        return [RACSignal empty];
    }];

    self.stickerButton.rac_command = [[RACCommand alloc] initWithSignalBlock:^RACSignal *(id input) {
        @strongify(self);
        self.stickerListView.hidden = false;
        for (NSLayoutConstraint *constraint in self.view.constraints) {
            if (constraint.firstAttribute == NSLayoutAttributeTop) {
                if(constraint.secondItem == self.stickerListView){
                    constraint.constant = 0;
                }else if(constraint.secondItem == self.bottomView){
                    constraint.constant = -230;
                }
            }
        }
        [UIView animateWithDuration:0.2 animations:^{
            @strongify(self);
            [self.view layoutIfNeeded];
        }];
        return [RACSignal empty];
    }];
    
    self.view.userInteractionEnabled = YES;
    UITapGestureRecognizer *singleTap = [UITapGestureRecognizer new];
    [self.GPUView addGestureRecognizer:singleTap];
    [singleTap.rac_gestureSignal subscribeNext:^(UIPanGestureRecognizer *gesture) {
        @strongify(self);
        for (NSLayoutConstraint *constraint in self.view.constraints) {
            if (constraint.firstAttribute == NSLayoutAttributeTop) {
                if(constraint.secondItem == self.stickerListView){
                    constraint.constant = -260;
                }else if(constraint.secondItem == self.bottomView){
                    constraint.constant = 0;
                }
            }
        }
        [UIView animateWithDuration:0.2 animations:^{
            @strongify(self);
            [self.view layoutIfNeeded];
        }];
    }];
    
    self.faceWidgetFilter = [GPUImagePeopleFilter new];
    self.faceWidgetFilter.imgSize = self.cameraSize;
    self.faceWidgetFilter2 = [GPUImagePeopleFilter new];
    self.faceWidgetFilter2.imgSize = self.cameraSize;
    self.faceWidgetFilter3 = [GPUImagePeopleFilter new];
    self.faceWidgetFilter3.imgSize = self.cameraSize;
    self.faceWidgetFilter4 = [GPUImagePeopleFilter new];
    self.faceWidgetFilter4.imgSize = self.cameraSize;
    self.faceWidgetFilter5 = [GPUImagePeopleFilter new];
    self.faceWidgetFilter5.imgSize = self.cameraSize;
    self.faceWidgetFilter6 = [GPUImagePeopleFilter new];
    self.faceWidgetFilter6.imgSize = self.cameraSize;
    self.backgroundFilter = [GPUImageStickerFilter new];
    
    self.facear =[[FaceDetect alloc] init :false];
    self.skinImg = [[GPUImagePicture alloc] initWithImage:[UIImage imageNamed:@"empty.png"]];
    self.faceFilter = [[GPUFaceImageFilter alloc] init];
    [self.meshFilter setItems:nil];
    self.placeholderImg = [[GPUImagePicture alloc] initWithImage:[UIImage imageNamed:@"empty.png"]];
}

-(void)viewWillAppear:(BOOL)animated{
    self.recordButton.isRecordMode = YES;
    AVAudioSessionRecordPermission audioPermission = [AVAudioSession sharedInstance].recordPermission;
    AVAuthorizationStatus camPermission = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if(camPermission == AVAuthorizationStatusDenied){
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"permission_alert_title".localized message:@"permission_alert_message".localized preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"permission_alert_ok".localized style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSURL *settingsUrl = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
            [[UIApplication sharedApplication] openURL:settingsUrl];
        }]];
        [self presentViewController:alert animated:YES completion:^{
            
        }];
    }
    if(audioPermission == AVAudioSessionRecordPermissionUndetermined){
        [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
            
        }];
    }

    NSString *time = TimeStamp;
    NSString *path = [NSString stringWithFormat: @"Movie_%@.m4v", time];
    NSString *moviePath = [NSTemporaryDirectory() stringByAppendingPathComponent:path];
    unlink([moviePath UTF8String]);
    self.movieURL        = [NSURL fileURLWithPath:moviePath];
    self.movieWriter     = [[GPUImageMovieWriter alloc] initWithMovieURL: self.movieURL size:self.cameraSize];
    self.videoCamera.audioEncodingTarget = self.movieWriter;
    [self.videoCamera startCameraCapture];
    [self resetFilters];
    [super viewWillAppear:animated];
}

-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
}

-(void)configSticker{
    self.bottomView.userInteractionEnabled = YES;
    self.stickerScrollView.delegate = self;
    self.stickerTabBarView.backgroundColor = [UIColor colorWithRGBHex:0x272a31];
    [self.stickerTabBarView removeAllSubviews];
    [self.stickerScrollView removeAllSubviews];
    self.stickerScrollView.pagingEnabled = YES;
    
    int i =0;
    int row = 5;
    int w = SCREEN_WIDTH / row;

    self.stickersData = @[
        @{
            @"icon":@"skin_pierrot.png",
            @"stickers":@[
                @{@"icon":@"skin_beard.png" ,@"path":@"stickers/skin_beard"},
                @{@"icon":@"skin_butterfly.png" ,@"path":@"stickers/skin_butterfly"},
                @{@"icon":@"skin_cat.png" ,@"path":@"stickers/skin_cat"},
                @{@"icon":@"skin_pierrot.png" ,@"path":@"stickers/skin_pierrot"},
                @{@"icon":@"skin_hlquinn.png" ,@"path":@"stickers/skin_hlquinn"},
                @{@"icon":@"100009.png" ,@"path":@"stickers/100009"},
                @{@"icon":@"bear.png" ,@"path":@"stickers/simplebear"},
                @{@"icon":@"joker.png" ,@"path":@"stickers/joker"},
                @{@"icon":@"100104.png" ,@"path":@"stickers/100104"},
                @{@"icon":@"100106.png" ,@"path":@"stickers/100106"},
                @{@"icon":@"100107.png" ,@"path":@"stickers/100107"},
                @{@"icon":@"100108.png" ,@"path":@"stickers/100108"},
                @{@"icon":@"100016.png" ,@"path":@"stickers/100016"},
                @{@"icon":@"100101.png" ,@"path":@"stickers/100101"},
            ]
        },
        @{
            @"icon":@"100109.png",
            @"stickers":@[
                @{@"icon":@"100104.png" ,@"path":@"stickers/100104"},
                @{@"icon":@"100106.png" ,@"path":@"stickers/100106"},
                @{@"icon":@"100107.png" ,@"path":@"stickers/100107"},
                @{@"icon":@"100108.png" ,@"path":@"stickers/100108"},
                @{@"icon":@"100016.png" ,@"path":@"stickers/100016"},
                @{@"icon":@"100101.png" ,@"path":@"stickers/100101"},
            ]
        },
    ];
    for (NSDictionary *cat in self.stickersData) {
        UIButton *catButton = [[UIButton alloc] initWithFrame:CGRectMake(i * 60, 0, 50, 40)];
        if(i == 0){
            catButton.selected = YES;
        }
        UIImage *icon = [UIImage imageNamed:cat[@"icon"]];
        catButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
        [catButton setImage:icon forState:UIControlStateSelected];
        [catButton setImage:[Utils convertImageToGrayScale:icon] forState:UIControlStateNormal];
        [catButton addTarget:self action:@selector(catButtonTap:) forControlEvents:UIControlEventTouchUpInside];
        
        [self.stickerTabBarView addSubview:catButton];
        UIScrollView *catStickersScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(i * SCREEN_WIDTH, 0, SCREEN_WIDTH, self.stickerScrollView.height)];
        [self.stickerScrollView addSubview:catStickersScrollView];
        int j = 0;
        for (NSDictionary *sticker in cat[@"stickers"]) {
            UIView *stickerView = [[UIView alloc] initWithFrame:CGRectMake(j%row * w, (j)/row * w, w, w)];
            UIImageView *iconImg = [[UIImageView alloc] initWithFrame:CGRectMake(10, 10, w - 20, w-20)];
            iconImg.contentMode = UIViewContentModeScaleAspectFit;
            iconImg.tag = ICON_TAG;
            iconImg.image = [UIImage imageNamed:sticker[@"icon"]];
            [stickerView addSubview:iconImg];
            @weakify(self);
            __block UIView *_stickerView = stickerView;
            __block NSDictionary *_sticker = sticker;
            [catStickersScrollView addSubview:stickerView];
            stickerView.userInteractionEnabled = YES;
            UITapGestureRecognizer *singleTap = [UITapGestureRecognizer new];
            [singleTap.rac_gestureSignal subscribeNext:^(UIPanGestureRecognizer *gesture) {
                @strongify(self);
                [self stickerTap:_stickerView :_sticker];
            }];
            [stickerView addGestureRecognizer:singleTap];
            j++;
        }
        catStickersScrollView.contentSize = CGSizeMake(SCREEN_WIDTH, (j + row - 1)/row * w);
        i++;
    }
    [self.stickerScrollView setContentSize:CGSizeMake(i * SCREEN_WIDTH, 0)];
    [self.stickerTabBarView setContentSize:CGSizeMake(i * 60, 40)];
    
    self.faceAlertView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, SCREEN_WIDTH*0.8, SCREEN_WIDTH*0.8)];
    self.faceAlertView.image = [UIImage imageNamed:@"area_face"];
    self.faceAlertView.contentMode = UIViewContentModeScaleAspectFit;
    self.faceAlertView.center = self.view.center;
    self.faceAlertView.hidden = YES;
    [self.view insertSubview:self.faceAlertView belowSubview:self.bottomView];
}

-(void)catButtonTap:(UIButton *)catButton{
    NSInteger i = [[[catButton superview] subviews] indexOfObject:catButton];
    [self.stickerScrollView setContentOffset:CGPointMake(i * SCREEN_WIDTH, 0) animated:YES];
    for (UIButton *bt in [self.stickerTabBarView subviews]) {
        if([bt isKindOfClass:[UIButton class]]){
            bt.selected = NO;
        }
    }
    catButton.selected = YES;
}

-(void)stickerTap:(UIView *)tapView :(NSDictionary *)sticker{
    NSString *stickerPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:sticker[@"path"]];
     
    self.hintLabel.hidden = YES;
    self.faceAlertView.hidden = YES;
    if([stickerPath isEqualToString:self.stickerPath]){
        return;
    }
    
    NSDictionary *config = [[Utils readJson:[[NSString alloc] initWithFormat:@"%@/config.json",stickerPath]] mutableCopy];
    if(!config){
        return;
    }
    
    [self clearFilters];
    self.stickerConfig = config;
    self.stickerPath = stickerPath;
    UIView *activeView = [self.view viewWithTag:ACTIVE_STICKER_TAG];
    if(activeView){
        [activeView viewWithTag:ICON_TAG].layer.borderWidth = 0;
        activeView.tag = 0;
    }
    tapView.tag = ACTIVE_STICKER_TAG;
    [tapView viewWithTag:ICON_TAG].layer.borderWidth = 2;
    [tapView viewWithTag:ICON_TAG].layer.borderColor = [UIColor whiteColor].CGColor;
   
    self.laseFilter = self.firstFilter;
    [self.videoCamera addTarget:self.firstFilter];

    for (NSString *key in [self.gpuImagesCache allKeys]) {
        GPUImagePicture *gpuImg = [self.gpuImagesCache objectForKey:key];
        [gpuImg removeAllTargets];
        [[gpuImg framebufferForOutput] unlock];
        [gpuImg removeOutputFramebuffer];
    }
    [self.gpuImagesCache removeAllObjects];
    
    NSDictionary *parames = @{@"count" : @"0"};

    int i = 0;
    self.backgroundFilter.fcount = 0;
    self.mainStickerImg = self.placeholderImg;
    [self.mainStickerImg addTarget:self.backgroundFilter atTextureLocation:1];

    self.faceWidgetImg1 = self.placeholderImg;
    self.faceWidgetImg2 = self.placeholderImg;
    self.faceWidgetImg3 = self.placeholderImg;
    self.faceWidgetImg4 = self.placeholderImg;
    self.faceWidgetImg5 = self.placeholderImg;
    self.faceWidgetImg6 = self.placeholderImg;
    [self.placeholderImg processImage];
    self.hintLabel.hidden = YES;
    for (NSDictionary *item in self.stickerConfig[@"items"]) {
        if([item[@"position"] intValue] == 10){
            self.laseFilter = self.backgroundFilter;
            UIEdgeInsets insert = UIEdgeInsetsFromString(item[@"insert"]);
            self.backgroundFilter.size = CGSizeMake(1.0, [item[@"height"] floatValue]/[item[@"width"] floatValue] * SCREEN_WIDTH / SCREEN_HEIGHT);
            self.backgroundFilter.point = CGPointMake(0.5, 0.5 + (insert.top - insert.bottom) * self.backgroundFilter.size.height);
            self.backgroundFilter.fcount = 1;
            continue;
        }
        
        if(i == 0){
            [self.faceWidgetFilter setStickerParams:parames];
            [self.laseFilter addTarget:self.faceWidgetFilter];
            self.laseFilter = self.faceWidgetFilter;
            [self.faceWidgetImg1 addTarget:self.laseFilter atTextureLocation:1];
        }
        else if(i == 1){
            [self.laseFilter addTarget:self.faceWidgetFilter2];
            [self.faceWidgetFilter2 setStickerParams:parames];
            self.laseFilter = self.faceWidgetFilter2;
            [self.faceWidgetImg2 addTarget:self.faceWidgetFilter2 atTextureLocation:1];
        }
        else if(i == 2){
            [self.laseFilter addTarget:self.faceWidgetFilter3];
            [self.faceWidgetFilter3 setStickerParams:parames];
            self.laseFilter = self.faceWidgetFilter3;
            [self.faceWidgetImg3 addTarget:self.faceWidgetFilter3 atTextureLocation:1];
        }
        else if(i == 3){
            [self.laseFilter addTarget:self.faceWidgetFilter4];
            [self.faceWidgetFilter4 setStickerParams:parames];
            self.laseFilter = self.faceWidgetFilter4;
            [self.faceWidgetImg4 addTarget:self.faceWidgetFilter4 atTextureLocation:1];
        }
        else if(i == 4){
            [self.laseFilter addTarget:self.faceWidgetFilter5];
            [self.faceWidgetFilter5 setStickerParams:parames];
            self.laseFilter = self.faceWidgetFilter5;
            [self.faceWidgetImg5 addTarget:self.faceWidgetFilter5 atTextureLocation:1];
        }else if(i == 5){
            [self.laseFilter addTarget:self.faceWidgetFilter6];
            [self.faceWidgetFilter6 setStickerParams:parames];
            self.laseFilter = self.faceWidgetFilter6;
            [self.faceWidgetImg6 addTarget:self.faceWidgetFilter6 atTextureLocation:1];
        }
        i++;
    }

    if(![Utils isEmpty:self.stickerConfig[@"skins"]]){
        NSDictionary *skin = self.stickerConfig[@"skins"][0];
        NSString *folderName = skin[@"folderName"];
        NSString *idxFile = [[NSString alloc] initWithFormat:@"%@/%@/%@.idx",self.stickerPath,folderName,folderName];
        NSString *crdFile = [[NSString alloc] initWithFormat:@"%@/%@/%@.crd",self.stickerPath,folderName,folderName];
        NSString *pngFile = [[NSString alloc] initWithFormat:@"%@/%@/%@_000.png",self.stickerPath,folderName,folderName];
        [self.skinImg removeAllTargets];
        if([[NSFileManager defaultManager] fileExistsAtPath:pngFile]){
            self.skinImg = [[GPUImagePicture alloc] initWithImage:[UIImage imageWithContentsOfFile:pngFile]];
            [self.faceFilter updateWith:crdFile :idxFile];
            [self.laseFilter addTarget:self.faceFilter atTextureLocation:0];
            [self.laseFilter addTarget:self.blendfilter atTextureLocation:0];
            [self.skinImg addTarget:self.faceFilter atTextureLocation:1];
            [self.skinImg processImage];
            [self.faceFilter addTarget:self.blendfilter atTextureLocation:1];
            self.laseFilter = self.blendfilter;
        }
    }

    [self.laseFilter addTarget:self.meshFilter];
    self.laseFilter = self.meshFilter;

    [self.videoCamera addTarget:self.firstFilter];
    [self.laseFilter addTarget:self.GPUView];
}

#pragma mark - Face Detection Delegate Callback
- (void)willOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer{
    if(!self.stickerPath){
        return;
    }
    
    [self grepFacesForSampleBuffer:sampleBuffer];

    if(!self.detectoredFace){
        return;
    }
    
    int i = 0;
    for (NSDictionary *item in self.stickerConfig[@"items"]) {
        NSInteger useFrameIndex = self.stickerFrameIndex;
        if([item[@"type"] integerValue] == 1 ){
            if(self.mouthOpening){
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.hintLabel.hidden = YES;
                });
                
                useFrameIndex = self.mouthStickerFrameIndex;
                self.mouthStickerFrameIndex++;
                if(self.mouthStickerFrameIndex > [item[@"frames"] intValue]){
                    self.mouthOpening = false;
                    self.mouthStickerFrameIndex = 0;
                }
            }
            if(!self.mouthOpening){
                [self.faceWidgetImg1 removeAllTargets];
                self.faceWidgetImg1 = self.placeholderImg;
                [self.faceWidgetImg1 addTarget:self.faceWidgetFilter atTextureLocation:1];
                [self.faceWidgetImg1 processImage];
                i++;
                continue;
            }
        }

        NSString *path = [[NSString alloc] initWithFormat:@"%@/%@",self.stickerPath,item[@"folderName"]];
        int index = useFrameIndex % [item[@"frames"] intValue];
        NSString *fileName = [[NSString alloc] initWithFormat:@"%@/%@_%03d.png",path,item[@"folderName"],index];
        GPUImagePicture *itemImg;
        if(![self.gpuImagesCache objectForKey:fileName]){
            if([[NSFileManager defaultManager] fileExistsAtPath:fileName]){
                itemImg = [[GPUImagePicture alloc] initWithImage:[UIImage imageWithContentsOfFile:fileName]];
            }
            if(!itemImg){
                continue;
            }
            [self.gpuImagesCache setObject:itemImg forKey:fileName];
        }
        itemImg = [self.gpuImagesCache objectForKey:fileName];
        if([item[@"position"] intValue] >= 10){
            self.mainStickerImg = itemImg;
            [self.mainStickerImg addTarget:self.backgroundFilter atTextureLocation:1];
            [self.mainStickerImg processImage];
            continue;
        }
        if(i == 0){
            [self.faceWidgetImg1 removeAllTargets];
            self.faceWidgetImg1 = itemImg;
            [self.faceWidgetImg1 addTarget:self.faceWidgetFilter atTextureLocation:1];
            [self.faceWidgetImg1 processImage];
        }else if(i == 1){
            [self.faceWidgetImg2 removeAllTargets];
            self.faceWidgetImg2 = itemImg;
            [self.faceWidgetImg2 addTarget:self.faceWidgetFilter2 atTextureLocation:1];
            [self.faceWidgetImg2 processImage];
        }else if(i == 2){
            [self.faceWidgetImg3 removeAllTargets];
            self.faceWidgetImg3 = itemImg;
            [self.faceWidgetImg3 addTarget:self.faceWidgetFilter3 atTextureLocation:1];
            [self.faceWidgetImg3 processImage];
        }else if(i == 3){
            [self.faceWidgetImg4 removeAllTargets];
            self.faceWidgetImg4 = itemImg;
            [self.faceWidgetImg4 addTarget:self.faceWidgetFilter4 atTextureLocation:1];
            [self.faceWidgetImg4 processImage];
        }else if(i == 4){
            [self.faceWidgetImg5 removeAllTargets];
            self.faceWidgetImg5 = itemImg;
            [self.faceWidgetImg5 addTarget:self.faceWidgetFilter5 atTextureLocation:1];
            [self.faceWidgetImg5 processImage];
        }else if(i == 5){
            [self.faceWidgetImg6 removeAllTargets];
            self.faceWidgetImg6 = itemImg;
            [self.faceWidgetImg6 addTarget:self.faceWidgetFilter6 atTextureLocation:1];
            [self.faceWidgetImg6 processImage];
        }
        i++;
    }
    self.stickerFrameIndex ++;
}

- (void)grepFacesForSampleBuffer:(CMSampleBufferRef)sampleBuffer{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress( imageBuffer, 0 );
    void* bufferAddress;
    size_t width;
    size_t height;
    size_t bytesPerRow;
    int format_opencv;
    format_opencv = CV_8UC4;
 
    bufferAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    width = CVPixelBufferGetWidth(imageBuffer);
    height = CVPixelBufferGetHeight(imageBuffer);
    bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    
    cv::Mat image((int)height, (int)width, format_opencv, bufferAddress, bytesPerRow);
    CVPixelBufferUnlockBaseAddress( imageBuffer, 0 );
 
    float scale = 0.35;
    if(self.isFrontCamera){
        scale = 0.3;
    }
    
    cv::resize(image(cv::Rect(0,160,720,960)),image,cv::Size(scale*image.cols,scale*image.cols * 1.33),0 ,0 ,cv::INTER_NEAREST);
    __block cv::Mat_<uint8_t> gray_image;
    cv::cvtColor(image, gray_image, CV_BGR2GRAY);
 
    NSArray *faces = [self.facear landmark:gray_image scale:scale lowModel:false isFrontCamera:self.isFrontCamera];
    gray_image.release();
    [self GPUVCWillOutputFeatures:faces];
}

- (void)GPUVCWillOutputFeatures:(NSArray *)faceArray
{
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    
    if (!faceArray || [faceArray count]<1) {
        NSDictionary *parames = @{ @"count" : @"0"};
        [self.faceWidgetFilter setStickerParams:parames];
        [self.faceWidgetFilter2 setStickerParams:parames];
        [self.faceWidgetFilter3 setStickerParams:parames];
        [self.faceWidgetFilter4 setStickerParams:parames];
        [self.faceWidgetFilter5 setStickerParams:parames];
        [self.faceWidgetFilter6 setStickerParams:parames];
        [self.meshFilter setItems:nil];
        self.backgroundFilter.fcount = 0;
        self.detectoredFace = NO;
        if((now - self.lastDetectorFaceTime) > 0.5){
            dispatch_async(dispatch_get_main_queue(), ^{
                self.faceAlertView.hidden = NO;
            });
        }
        self.faceFilter.items = nil;
        self.mouthOpening = NO;
        self.mouthStickerFrameIndex = 0;
        return;
    }

    self.lastDetectorFaceTime = now;
    if(self.faceAlertView.hidden == NO){
        dispatch_async(dispatch_get_main_queue(), ^{
           self.faceAlertView.hidden = YES;
        });
    }
    
    self.detectoredFace = YES;
    self.backgroundFilter.fcount = 1;
 
    NSMutableDictionary *ftemplate = [[NSMutableDictionary alloc] init];
    [ftemplate setObject:@"0" forKey:@"count"];
    [ftemplate setObject:[NSMutableArray new]  forKey:@"angle"];
    [ftemplate setObject:[NSMutableArray new] forKey:@"point"];
    [ftemplate setObject:[NSMutableArray new] forKey:@"size"];
    
    NSMutableArray *faceParameArray = [[NSMutableArray alloc] initWithObjects:[ftemplate mutableDeepCopy],[ftemplate mutableDeepCopy],[ftemplate mutableDeepCopy],[ftemplate mutableDeepCopy],[ftemplate mutableDeepCopy],[ftemplate mutableDeepCopy], nil];
    
    NSInteger currentFeature = 0;
    NSInteger faceCount = [faceArray count];
    NSMutableArray *meshItems = [NSMutableArray new];
    NSMutableArray *skinItems = [NSMutableArray new];
 
    for(NSDictionary *faceInArr in faceArray){
        NSMutableArray *item = [NSMutableArray new];
        CGRect faceRect = CGRectFromString(faceInArr[@"rect"]);
        faceRect.size.width = faceRect.size.width * 0.62;
        faceRect.size.height = faceRect.size.width * 0.62;
        
        NSInteger face[136];
        for (int i =0; i < 136; i++) {
            if(i < 120){
                face[i] = [[faceInArr[@"shape"] objectAtIndex:i] integerValue];
            }else if(i == 120 || i == 121 || i == 128 ||  i == 129){
                face[i] = 0;
                continue;
            }else if (i > 129 ){
                face[i] = [[faceInArr[@"shape"] objectAtIndex:(i-4)] integerValue];
            }else if (i > 121 ){
                face[i] = [[faceInArr[@"shape"] objectAtIndex:(i-2)] integerValue];
            }
            if(i % 2 != 0){
                face[i] +=(160 - self.xoffect);
            }
        }
        int i=0;
 
        CGPoint p27 = CGPointMake(face[27*2], face[27*2+1]);
        CGPoint p30 = CGPointMake(face[30*2], face[30*2+1]);
        CGPoint p33 = CGPointMake(face[33*2], face[33*2+1]);
        CGPoint leftEayCenter = [self midPointWithIndex:36 :39 :face];
        CGPoint rightEayCenter = [self midPointWithIndex:42 :45 :face];
        CGPoint mouthMidPoint = [self midPointWithIndex:51 :57 :face];
        CGPoint mouthLeft = CGPointMake(face[48*2], face[48*2+1]);
        CGPoint mouthRight =CGPointMake(face[54*2], face[54*2+1]);
        CGPoint noseBottom =CGPointMake(face[30*2], face[30*2+1]);
        CGPoint mouthTop = CGPointMake(face[51*2], face[51*2+1]);
        CGPoint mouthBottom = CGPointMake(face[57*2], face[57*2+1]);
        CGPoint eayCenter = p27;
        
        CGFloat b = rightEayCenter.y - leftEayCenter.y;
        CGFloat a = rightEayCenter.x - leftEayCenter.x;
        CGFloat c = sqrtf(a * a + b * b);
        CGPoint angle;
        
        angle = CGPointMake((b/c),a/c);
        float sin = angle.x;
        float cos = angle.y;
        float rad = asin(sin);
 
        NSInteger faceW;
        faceW = faceRect.size.width;
 
        CGFloat mouthW = [self distance:mouthLeft :mouthRight];
        CGFloat noseH = [self distance:p27 :p30];
        
        CGPoint t = [self rotation:CGPointMake(mouthLeft.x + mouthW*0.08, mouthLeft.y) :mouthLeft :sin :cos];
        face[120] = t.x;
        face[121] = t.y;
        t = [self rotation:CGPointMake(mouthRight.x - mouthW*0.08, mouthRight.y) :mouthRight :sin :cos];
        face[128] = t.x;
        face[129] = t.y;
 
        CGPoint p62 = CGPointMake(face[62*2], face[62*2+1]);
        CGPoint p66 = CGPointMake(face[66*2], face[66*2+1]);
        if([self distance:p62 :p66]/mouthW > 0.3 && !self.mouthOpening){
            self.mouthOpening = YES;
        }
        
        //膨胀外轮廓
        i = 0;
        float length = faceW * 0.02;
        for(int i= 0; i < 34;i += 2){
            CGPoint pot = CGPointMake(face[i], face[i+1]);
            float distance = [self distance:pot :p33];
            face[i] = pot.x + (pot.x - p33.x) / distance * length;
            face[i+1] = pot.y + (pot.y - p33.y) / distance * length;
        }
        
        //外轮廓
        for (int i = 0; i < 32; i+=2) {
            int j = i / 2;
            CGPoint pot = CGPointMake(face[j*2], face[j*2+1]);
            CGPoint npot = CGPointMake(face[j*2+2], face[j*2+3]);
            item[i] = [NSValue valueWithCGPoint:CGPointMake(pot.x, pot.y)];
            item[i+1] = [NSValue valueWithCGPoint:[self midPoint:pot :npot]];
        }

        item[32] = [NSValue valueWithCGPoint:CGPointMake(face[32], face[33])];
        //中心部位
        for (int i = 17; i < 64; i++) {
            int j = i + 16;
            item[j] = [NSValue valueWithCGPoint:CGPointMake(face[i*2], face[i*2+1])];
        }
        //眉毛下
        NSInteger offset = (int)(noseH * 0.10);
        for (int i = 0; i < 4; i++) {
            int j = i + 18;
            CGPoint m = CGPointMake(face[j*2], face[j*2+1]);
            NSInteger useOffset = offset;
            if(i == 3){
                useOffset = offset / 1.3;
            }
            item[64+i] = [NSValue valueWithCGPoint:[self rotation:CGPointMake(m.x, m.y + useOffset) :m :sin :cos]];
        }
        for (int i = 0; i < 4; i++) {
            int j = i + 22;
            CGPoint m = CGPointMake(face[j*2], face[j*2+1]);
            NSInteger useOffset = offset;
            if(i == 3){
                useOffset = offset / 1.3;
            }
            item[68+i] = [NSValue valueWithCGPoint:[self rotation:CGPointMake(m.x, m.y + useOffset) :m :sin :cos]];
        }
        
        //左眼中心
        item[72] = [NSValue valueWithCGPoint:[self midPointWithIndex:37 :38 :face]];
        item[73] = [NSValue valueWithCGPoint:[self midPointWithIndex:40 :41 :face]];
        item[74] = [NSValue valueWithCGPoint:[self midPointWithIndex:36 :39 :face]];
        item[75] = [NSValue valueWithCGPoint:[self midPointWithIndex:43 :44 :face]];
        item[76] = [NSValue valueWithCGPoint:[self midPointWithIndex:47 :46 :face]];
        item[77] = [NSValue valueWithCGPoint:[self midPointWithIndex:42 :45 :face]];
        
        //鼻子上部左右
        item[78] = [NSValue valueWithCGPoint:[self midPointWithIndex:39 :27 :face]];
        item[79] = [NSValue valueWithCGPoint:[self midPointWithIndex:42 :27 :face]];
        CGPoint p29 = CGPointMake(face[29*2], face[29*2+1]);
        CGPoint p31 = CGPointMake(face[31*2], face[31*2+1]);
        CGPoint p35 = CGPointMake(face[35*2], face[35*2+1]);

        item[80] = [NSValue valueWithCGPoint:[self rotation:CGPointMake(p29.x - noseH/6., p29.y + noseH/12.) :p29 :sin :cos]];
        item[81] = [NSValue valueWithCGPoint:[self rotation:CGPointMake(p29.x + noseH/6, p29.y + noseH/12.) :p29 :sin :cos]];
        item[82] = [NSValue valueWithCGPoint:[self rotation:CGPointMake(p31.x - noseH /16., p31.y - noseH / 16.) :p31 :sin :cos]];
        item[83] = [NSValue valueWithCGPoint:[self rotation:CGPointMake(p35.x + noseH /16., p35.y - noseH / 16.) :p35 :sin :cos]];
        
        for (int i = 0; i < 20; i++) {
            int j = i + 48;
            item[84+i] = [NSValue valueWithCGPoint:CGPointMake(face[j*2], face[j*2+1])];
        }
        
        //眼睛下侧两点
        item[104] = [NSValue valueWithCGPoint:[self midPointWithIndex:38 :41 :face]];
        item[105] = [NSValue valueWithCGPoint:[self midPointWithIndex:44 :47 :face]];
        //脸颊两侧
        CGPoint p2 = CGPointMake(face[2*2], face[2*2+1]);
        CGPoint p14 = CGPointMake(face[14*2], face[14*2+1]);
        CGPoint pot = CGPointMake(p31.x - [self distance:p31 :p2] / 1.5, p31.y);
        item[106] = [NSValue valueWithCGPoint:[self rotation:pot :p31 :sin :cos]];
        pot = CGPointMake(p35.x + [self distance:p35 :p14] / 1.5, p35.y);
        item[107] = [NSValue valueWithCGPoint:[self rotation:pot :p35 :sin :cos]];
        //额头
        CGPoint p17 = CGPointMake(face[17*2], face[17*2+1]);
        CGPoint p19 = CGPointMake(face[19*2], face[19*2+1]);
        CGPoint p20 = CGPointMake(face[20*2], face[20*2+1]);
        CGPoint p23 = CGPointMake(face[23*2], face[23*2+1]);
        CGPoint p24 = CGPointMake(face[24*2], face[24*2+1]);

        CGPoint p26 = CGPointMake(face[26*2], face[26*2+1]);
        CGPoint p39 = CGPointMake(face[39*2], face[39*2+1]);
        CGPoint p42 = CGPointMake(face[42*2], face[42*2+1]);
        
        CGPoint p110 = [self midPoint:p39 :p42];
        p110.y -= faceW * 0.8;
 
        item[108] = [NSValue valueWithCGPoint:[self rotation:CGPointMake(p17.x , p110.y) :p27 :sin :cos]];
        item[109] = [NSValue valueWithCGPoint:[self rotation:CGPointMake((p19.x + p20.x) / 2., p110.y) :p27 :sin :cos]];
        item[110] = [NSValue valueWithCGPoint:[self rotation:p110 :p27 :sin :cos]];
        item[111] = [NSValue valueWithCGPoint:[self rotation:CGPointMake((p23.x + p24.x) / 2., p110.y) :p27 :sin :cos]];
        item[112] = [NSValue valueWithCGPoint:[self rotation:CGPointMake(p26.x, p110.y) :p27 :sin :cos]];

        i = 0;
        float halfW = self.cameraSize.width /2.;
        float halfH = self.cameraSize.height /2.;
        NSMutableArray *formatedFace = [NSMutableArray new];
        for(NSValue *val in item) {
            CGPoint pot = [val CGPointValue];
            formatedFace[i] = [NSValue valueWithCGPoint:CGPointMake((pot.x - halfW)/halfW,(pot.y - halfH)/halfH)];
            i++;
        }
        
        formatedFace[113] = [NSValue valueWithCGPoint:CGPointMake(-1.,-1.)];
        formatedFace[114] = [NSValue valueWithCGPoint:CGPointMake(0.,-1.)];
        formatedFace[115] = [NSValue valueWithCGPoint:CGPointMake(1.,-1.)];
        formatedFace[116] = [NSValue valueWithCGPoint:CGPointMake(-1.,0.)];
        formatedFace[117] = [NSValue valueWithCGPoint:CGPointMake(1.,0.)];
        formatedFace[118] = [NSValue valueWithCGPoint:CGPointMake(-1.,1.)];
        formatedFace[119] = [NSValue valueWithCGPoint:CGPointMake(0.,1.)];
        formatedFace[120] = [NSValue valueWithCGPoint:CGPointMake(1.,1.)];
        [skinItems addObject:formatedFace];

        if(![Utils isEmpty:self.stickerConfig[@"meshs"]]){
            float halfW = self.cameraSize.width / 2.;
            float halfH = self.cameraSize.height / 2;
            float faceDegree = rad;
            float radius = faceRect.size.width / self.cameraSize.width;
            float faceRatio = 0.1;
            
            for (NSDictionary *item in self.stickerConfig[@"meshs"]) {
                UIEdgeInsets insert = UIEdgeInsetsFromString(item[@"insert"]);
                float itemRadius = radius * [item[@"radius"] floatValue] * 2;
                CGPoint point;
                switch ([item[@"position"] intValue]) {
                    case EayCenter:
                        point = eayCenter;
                        break;
                    case LeftEayCenter:
                        point = leftEayCenter;
                        break;
                    case RightEayCenter:
                        point = rightEayCenter;
                        break;
                    case MouthMidPoint:
                        point = mouthMidPoint;
                        break;
                    case MouthLeft:
                        point = mouthLeft;
                        break;
                    case MouthRight:
                        point = mouthRight;
                        break;
                    case NoseBottom:
                        point = noseBottom;
                        break;
                    case MouthTop:
                        point = mouthTop;
                        break;
                    case MouthBottom:
                        point = mouthBottom;
                        break;
                    default:
                        break;
                }
                
                CGPoint offsetSize = CGPointMake(insert.left * faceRect.size.width, insert.top * faceRect.size.height);
                CGPoint itemPoint;
                CGPoint itemSize = offsetSize;
                itemSize.x = (cos * offsetSize.x - sin * offsetSize.y);
                itemSize.y = (sin * offsetSize.x + cos * offsetSize.y);
                itemPoint = CGPointMake((point.x - itemSize.x - halfW)/halfW,(point.y - itemSize.y - halfH)/halfH );
                [meshItems addObject:[MeshItem itemWith:[item[@"type"] intValue] :[item[@"strength"] floatValue] :itemPoint : itemRadius :[item[@"direction"] intValue] :faceDegree :faceRatio]];
            }
        }
        
        i = 0;
        if([Utils isEmpty:self.stickerConfig[@"items"]]){
            continue;
        }
        
        for (NSDictionary *item in self.stickerConfig[@"items"]) {
            if([item[@"position"] intValue] >= 10){
                continue;
            }
            NSMutableDictionary *faceParames = [faceParameArray objectAtIndex:i];
            faceParames[@"count"] = @(faceCount);
            CGSize stickSize = CGSizeMake([item[@"width"] floatValue],[item[@"height"] floatValue]);
            int position = [item[@"position"] intValue];
            UIEdgeInsets insert = UIEdgeInsetsFromString(item[@"insert"]);
            CGPoint sizePoint;
            CGPoint center = CGPointMake(face[30*2], face[30*2+1]);
            
            CGFloat w = faceRect.size.width * [item[@"scale"] floatValue];
            sizePoint = CGPointMake(w / self.cameraSize.width, w * (stickSize.height/stickSize.width)/self.cameraSize.height);
            [faceParames[@"size"] addObject:NSStringFromCGPoint(sizePoint)];
            [faceParames[@"angle"] addObject:NSStringFromCGPoint(angle)];
            
            switch (position) {
                case EayCenter:
                    center = eayCenter;
                    break;
                case LeftEayCenter:
                    center = leftEayCenter;
                    break;
                case RightEayCenter:
                    center = rightEayCenter;
                    break;
                case MouthMidPoint:
                    center = mouthMidPoint;
                    break;
                case MouthLeft:
                    center = mouthLeft;
                    break;
                case MouthRight:
                    center = mouthRight;
                    break;
                case NoseBottom:
                    center = noseBottom;
                    break;
                case MouthTop:
                    center = mouthTop;
                    break;
                case MouthBottom:
                    center = mouthBottom;
                    break;
                default:
                    break;
            }
            
            CGPoint offsetSize = CGPointMake((insert.left - insert.right) * sizePoint.x, (insert.top - insert.bottom) * sizePoint.y);
            CGPoint firstCenter = CGPointMake(center.x / self.cameraSize.width, center.y / self.cameraSize.height);
            
            CGPoint finalCenter = CGPointMake(0.5, 0.5);
            finalCenter.x = firstCenter.x + (cos * offsetSize.x - sin * offsetSize.y) * (self.cameraSize.height / self.cameraSize.width);
            finalCenter.y = firstCenter.y + (sin * offsetSize.x + cos * offsetSize.y);
            [faceParames[@"point"] addObject:NSStringFromCGPoint(finalCenter)];
            i++;
        }
        currentFeature++;
    }
 
    self.faceFilter.items = skinItems;
    [self.meshFilter setItems:meshItems];
    faceArray=nil;
    int i = 0;
    for (NSDictionary *item in self.stickerConfig[@"items"]) {
        if([item[@"position"] intValue] >= 10){
            continue;
        }
        if(i == 0){
            [self.faceWidgetFilter setStickerParams:faceParameArray[i]];
        }else if(i == 1){
            [self.faceWidgetFilter2 setStickerParams:faceParameArray[i]];
        }else if(i == 2){
            [self.faceWidgetFilter3 setStickerParams:faceParameArray[i]];
        }else if(i == 3){
            [self.faceWidgetFilter4 setStickerParams:faceParameArray[i]];
        }else if(i == 4){
            [self.faceWidgetFilter5 setStickerParams:faceParameArray[i]];
        }else if(i == 5){
            [self.faceWidgetFilter6 setStickerParams:faceParameArray[i]];
        }
        i++;
    }
}

-(CGPoint)midPoint:(CGPoint)p1 :(CGPoint)p2 {
    return CGPointMake((p1.x + p2.x) / 2.0f, (p1.y + p2.y) / 2.0f);
}

-(CGPoint)midPointWithIndex:(NSInteger)index1 :(NSInteger)index2 :(NSInteger[])points {
    return CGPointMake((points[index1 * 2] + points[index2 * 2]) / 2.0f, (points[index1 * 2 + 1] + points[index2 * 2 + 1]) / 2.0f);
}

-(CGPoint)rotation:(CGPoint)point :(CGPoint)centerPoint :(CGFloat)sin :(CGFloat)cos {
    CGPoint p = CGPointMake(point.x - centerPoint.x, point.y - centerPoint.y);
    point.x = centerPoint.x + (cos * p.x - sin * p.y) ;
    point.y = centerPoint.y + (sin * p.x + cos * p.y);
    return point;
}

-(CGFloat)distance:(CGPoint)point :(CGPoint)point2 {
    CGFloat b = point.y - point2.y;
    CGFloat a = point.x - point2.x;
    CGFloat c = sqrtf(a * a + b * b);
    return c;
}

//Recognizer
-(void)doubleTap:(UISwipeGestureRecognizer *)sender{
    [self.switchCamera sendActionsForControlEvents:UIControlEventTouchUpInside];
}

- (void)tap:(UITapGestureRecognizer*)gesture {
    if ( gesture.state == UIGestureRecognizerStateBegan ) {
        self.recordButton.isRecordMode = NO;
        self.recordButton.recording = YES;
    }else if ( gesture.state == UIGestureRecognizerStateEnded ) {
        self.recordButton.recording = NO;
        self.recordButton.isRecordMode = YES;
        [self.laseFilter useNextFrameForImageCapture];
        UIImage *img = [self.laseFilter imageFromCurrentFramebuffer];
        UIImage *recordImg = [self.laseFilter imageByFilteringImage:img];
    }
}

- (void)longPress:(UILongPressGestureRecognizer*)gesture {
    if ( gesture.state == UIGestureRecognizerStateBegan ) {
        self.recordButton.recording = YES;
        [self.progressTimer invalidate];
        self.progressTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(updateProgress) userInfo:nil repeats:YES];
        [self startRecording];
    }else if ( gesture.state == UIGestureRecognizerStateEnded ) {
        [self stop];
    }
}

//record
- (void) startRecording
{
    [self.laseFilter addTarget:self.movieWriter];
    [self.movieWriter startRecording];
}

-(void) updateProgress {
    CGFloat maxDuration = 20;
    self.progress = self.progress + (0.05 / maxDuration);
    self.recordButton.progress = self.progress;
    if (self.progress >= 1) {
        [self stop];
    }
}

-(void)stop {
    self.progress = 0;
    self.recordButton.progress = 0;
    self.recordButton.recording = NO;
    [self.progressTimer invalidate];
    [self.movieWriter finishRecording];
}


-(void)resetFilters{
    [self clearFilters];
    [self.firstFilter addTarget:self.GPUView];
    [self.videoCamera addTarget:self.firstFilter];
}
 
-(void)clearFilters{
    [self.faceWidgetFilter removeAllTargets];
    [self.faceWidgetFilter2 removeAllTargets];
    [self.faceWidgetFilter3 removeAllTargets];
    [self.faceWidgetFilter4 removeAllTargets];
    [self.faceWidgetFilter5 removeAllTargets];
    [self.faceWidgetFilter6 removeAllTargets];
    [self.backgroundFilter removeAllTargets];
    [self.cropFilter removeAllTargets];
    [self.faceFilter removeAllTargets];
    [self.faceWidgetImg1 removeAllTargets];
    [self.faceWidgetImg2 removeAllTargets];
    [self.faceWidgetImg3 removeAllTargets];
    [self.faceWidgetImg4 removeAllTargets];
    [self.faceWidgetImg5 removeAllTargets];
    [self.faceWidgetImg6 removeAllTargets];
    [self.mainStickerImg removeAllTargets];
    [self.skinImg removeAllTargets];
    [[self.skinImg framebufferForOutput] unlock];
    [self.skinImg removeOutputFramebuffer];
    [self.videoCamera removeAllTargets];
    [self.firstFilter removeAllTargets];
    [self.laseFilter removeAllTargets];
    [self.cropFilter removeAllTargets];
    [self.meshFilter removeAllTargets];
    self.mouthOpening = false;
}


//UIScrollViewDelegate
-(void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView{
    if([scrollView isEqual:self.stickerScrollView]){
        int index = self.stickerScrollView.contentOffset.x / SCREEN_WIDTH;
        int i = 0;
        for (UIButton *bt in [self.stickerTabBarView subviews]) {
            if([bt isKindOfClass:[UIButton class]]){
                bt.selected = NO;
            }
            if(index == i){
                bt.selected = YES;
            }
            i++;
        }
    }
}

//AVCaptureMetadataOutputObjectsDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection{

}


//
- (void)viewDidDisappear:(BOOL)animated{
    [self.videoCamera removeAllTargets];
    [self.videoCamera stopCameraCapture];
    [super viewDidDisappear:animated];
}

-(void)dealloc{
    [self.videoCamera removeAllTargets];
    [self clearFilters];
    self.stickerScrollView.delegate = nil;
    self.videoCamera = nil;
    [self.firstFilter removeAllTargets];
    self.firstFilter = nil;
    [self.cropFilter removeAllTargets];
    self.cropFilter = nil;
    [self.meshFilter removeAllTargets];
    self.meshFilter = nil;
    for (NSString *key in [self.gpuImagesCache allKeys]) {
        GPUImagePicture *gpuPic = [self.gpuImagesCache objectForKey:key];
        [gpuPic removeAllTargets];
        [[gpuPic framebufferForOutput] unlock];
        [gpuPic removeOutputFramebuffer];
    }
    [self.gpuImagesCache removeAllObjects];
    self.faceWidgetImg1 = nil;
    [self.meshFilter removeAllTargets];
    self.meshFilter = nil;
    [self.faceFilter removeAllTargets];
    self.faceFilter = nil;
    [[GPUImageContext sharedFramebufferCache] purgeAllUnassignedFramebuffers];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
