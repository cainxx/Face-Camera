//
//  GPUFaceImageFilter.h
//  faceCamera
//
//  Created by cain on 16/8/11.
//  Copyright © 2016年 cain. All rights reserved.
//

#import <GPUImage/GPUImage.h>

@interface GPUFaceImageFilter : GPUImageTwoInputFilter{
    GLuint _indexBuffer;
    GLuint _vertexBuffer;
    
    GLsizeiptr _indexBufferCapacity;
    GLsizeiptr _vertexBufferCapacity;
}

@property (nonatomic, readonly) GLuint VAO;
@property (nonatomic, readonly) GLsizei indiciesCount;
@property (nonatomic) NSMutableArray *items;
@property (nonatomic) CGFloat screenRatio;
 

// The influence of diffuse lighting on a mesh. The value of 1.0f is 100% diffuse light, no ambient
// light whatsoever. The value of 0.0f is pure ambient light. Defaults to 1.0f.
@property (nonatomic) float diffuseLightFactor;
@property (nonatomic) CATransform3D supplementaryTransform;

-(void)updateWith:(NSString *)crdFile :(NSString *)idxFile;

@end
