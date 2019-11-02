 
#import <Foundation/Foundation.h>

#include <opencv2/videoio/videoio.hpp>
#include <opencv2/videoio/videoio_c.h>
#include <opencv2/imgproc.hpp>
#include <opencv2/highgui/highgui.hpp>
#include "FaceAR.hpp"
#include "myFaceAR.h"

@interface FaceDetect : NSObject

-(id) init :(BOOL)lowModel;

 
-(NSArray *) landmark:(cv::Mat)captured_image scale:(float)scale lowModel:(bool)lowModel isFrontCamera:(bool)isFrontCamera;


@end
