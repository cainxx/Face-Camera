 
#import "FaceDetect.h"
#import <UIKit/UIKit.h>

struct Configuration
{
    double wait_time;
    std::string model_pathname;
    std::string params_pathname;
    int tracking_threshold;
    std::string window_title;
    bool verbose;
    
    int circle_radius;
    int circle_thickness;
    int circle_linetype;
    int circle_shift;
};

@interface FaceDetect()
@property NSMutableDictionary *historyResult;
@end

@implementation FaceDetect{
    FACETRACKER::FaceAR *tracker;
    FACETRACKER::FaceAR *tracker2;
    FACETRACKER::myFaceARParams *tracker_params;
    FACETRACKER::myFaceARParams *tracker_params2;
    Configuration cfg;
    FACETRACKER::FDet fdet;
    int frame_number;
}

-(id) init :(BOOL)lowModel
{
    self = [super init];
    NSString *location = [[NSBundle mainBundle] resourcePath];
    cfg.wait_time = 0;
    cfg.model_pathname = [location UTF8String] + std::string("/model/faceModel");
    cfg.params_pathname = [location UTF8String] + std::string("/model/params");;
    cfg.tracking_threshold = 1;
    cfg.window_title = "";
    cfg.verbose = false;
    cfg.circle_radius = 3;
    cfg.circle_thickness = 2;
    cfg.circle_linetype = 8;
    cfg.circle_shift = 0;
    
    tracker = FACETRACKER::LoadFaceAR(cfg.model_pathname.c_str());
    tracker2 = FACETRACKER::LoadFaceAR(cfg.model_pathname.c_str());
//    tracker2 = tracker;
    tracker_params =(FACETRACKER::myFaceARParams *)FACETRACKER::LoadFaceARParams(cfg.params_pathname.c_str());
    tracker_params->init_type = 0;
    tracker_params->track_type = 1;
    tracker_params->itol = 10;
    tracker_params->ftol = 0.1;
 
    tracker_params->track_wSize[0] = 10;
    tracker_params->init_wSize[0] = 10;
    tracker_params->init_wSize[1] = 6;
    tracker_params->init_wSize[2] = 0;
    tracker_params->check_health = true;
    
    tracker_params->atm_scale = 0.5;
    tracker_params->atm_thresh = 100;
    tracker_params->atm_ntemp = 2;
   
    tracker_params2 = new FACETRACKER::myFaceARParams(*tracker_params);
    tracker_params2->track_type = 0;
    
 
    fdet = FACETRACKER::FDet();
    fdet.classifier = cv::CascadeClassifier([location UTF8String] + std::string("/model/haarcascade_frontalface_alt.xml"));
    
    tracker_params2 = tracker_params;
    self.historyResult = [NSMutableDictionary new];
    self.historyResult[@"0"] = [NSMutableArray new];
    self.historyResult[@"1"] = [NSMutableArray new];
    return self;
}

-(NSArray *) landmark:(cv::Mat)captured_image scale:(float)scale lowModel:(bool)lowModel isFrontCamera:(bool)isFrontCamera
{
    
    __block cv::Mat_<uint8_t> gray_image;
        gray_image = captured_image;
    
    dispatch_queue_t globalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    int64 e1, e2;float t;
    e1 = cv::getTickCount();
    __block int result1 = 0;
    __block int result2 = 0;
    cv::Rect R1 ,R2 ,trackerRect1,trackerRect2;
    R1 = ((FACETRACKER::myFaceAR *)tracker)->R;
    R2 = ((FACETRACKER::myFaceAR *)tracker2)->R;

    if((R1.width <= 0 && R2.width <= 0) || (frame_number % 20 == 0 && (R1.width <= 0 || R2.width <= 0))){
        int scanFaceSize = 70;

        std::vector<cv::Rect> face_detections = fdet.detectAll(gray_image,scanFaceSize);
        cv::Rect R;
        for( size_t face = 0; face < face_detections.size(); ++face){
            R = face_detections[face];
            cv::Rect R3 = R & R1;
            cv::Rect R4 = R & R2;
            if( R3.width > 0 || R4.width > 0){
                continue;
            }
            if(R1.width == 0){
                R1 = trackerRect1 = R;
            }else if(R2.width == 0){
                R2 = trackerRect2 = R;
            }
        }
    }
 
    if([self.historyResult[@"0"] count] > 0 && [[self.historyResult[@"0"] objectAtIndex:0] intValue] == 10 && frame_number % 2 == 0){
        tracker_params->itol = 5;
    }else{
        tracker_params->itol = 10;
    }

    dispatch_apply(2, globalQueue, ^(size_t i) {
        if(i == 0 && R1.width > 0){
            result1 = ((FACETRACKER::myFaceAR *)tracker)->trackerWithRect(gray_image,tracker_params,trackerRect1);
        }
        if(i == 1 && R2.width > 0){
            result2 = ((FACETRACKER::myFaceAR *)tracker2)->trackerWithRect(gray_image,tracker_params2,trackerRect2);
        }
    });
 
    e2 = cv::getTickCount();
    t = (e2 - e1)/cv::getTickFrequency();

    frame_number++;
    std::vector<cv::Point_<double> > shape1;
    std::vector<cv::Point_<double> > shape2;
    if (result1 >= cfg.tracking_threshold) {
        shape1 = tracker->getShape();
        [self.historyResult[@"0"] insertObject:@(result1) atIndex:0];
    }else{
        [self.historyResult[@"0"] removeAllObjects];
    }
    if(result2 >= cfg.tracking_threshold) {
        shape2 = tracker2->getShape();
        [self.historyResult[@"1"] insertObject:@(result2) atIndex:0];
    }else{
        [self.historyResult[@"1"] removeAllObjects];
    }
    
    NSMutableArray *points = [NSMutableArray new];
    if(shape1.size() > 0){
        NSMutableDictionary *item = [NSMutableDictionary new];
        item[@"shape"] = [NSMutableArray new];
        item[@"rect"] = NSStringFromCGRect(CGRectMake(R1.x/scale, R1.y/scale, R1.width/scale, R1.height/scale));
        for (size_t i = 0; i < shape1.size(); i++) {
            [item[@"shape"] addObject:@(shape1[i].x/scale) ];
            [item[@"shape"] addObject:@(shape1[i].y/scale) ];
        }
        [points addObject:item];
    }
    if(shape2.size() > 0){
        NSMutableDictionary *item = [NSMutableDictionary new];
        item[@"shape"] = [NSMutableArray new];
        item[@"rect"] = NSStringFromCGRect(CGRectMake(R2.x/scale, R2.y/scale, R2.width/scale, R2.height/scale));
        for (size_t i = 0; i < shape2.size(); i++) {
            [item[@"shape"] addObject:@(shape2[i].x/scale) ];
            [item[@"shape"] addObject:@(shape2[i].y/scale) ];
        }
        [points addObject:item];
    }
    
    return points;
}

-(void)dealloc{
    delete tracker;
    delete tracker2;
    delete tracker_params;
}

@end
