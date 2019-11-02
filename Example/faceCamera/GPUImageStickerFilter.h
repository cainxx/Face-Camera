//
//  GPUImageStickerFilter.h
//  faceCamera
//
//  Created by cain on 16/3/12.
//  Copyright © 2016年 cain. All rights reserved.
//

#import <GPUImage/GPUImage.h>

@interface GPUImageStickerFilter : GPUImageTwoInputFilter{
    GLuint sizeUniform,pointUniform,fcountUniform;
}

@property(assign, nonatomic) CGSize size;
@property(assign, nonatomic) CGPoint point;
@property(assign, nonatomic) int fcount;

@end