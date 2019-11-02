//
//  GPUImagePeopleFilter.h
//  faceCamera
//
//  Created by cain on 16/3/3.
//  Copyright © 2016年 cain. All rights reserved.
//

#import <GPUImage/GPUImage.h>

@interface GPUImagePeopleFilter : GPUImageTwoInputFilter{
    int intensityUniform;
    int p_size0;
    int p_size1;
    int p_size2;
    int p_size3;
    int p_size4;
    int p_targetPoint0;
    int p_targetPoint1;
    int p_targetPoint2;
    int p_targetPoint3;
    int p_targetPoint4;
    int p_angle0;
    int p_angle1;
    int p_angle2;
    int p_angle3;
    int p_angle4;
    int p_faceCount;
}

@property (nonatomic)CGSize imgSize;

-(void)setStickerParams:(NSDictionary *)params;

@end
