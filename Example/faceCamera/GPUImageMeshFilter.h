//
//  GPUImageMeshFilter.h
//  faceCamera
//
//  Created by cain on 16/6/16.
//  Copyright © 2016年 cain. All rights reserved.
//

#import <GPUImage/GPUImage.h>
#import "MSTransform.h"
#import "MeshItem.h"

struct MeshItemAttr{
    int type;
    float strength;
    CGPoint point;
    float radius;
    int direction;
    float faceDegree;
    float faceRatio;
};

@interface GPUImageMeshFilter : GPUImageFilter{
    GLuint _indexBuffer;
    GLuint _vertexBuffer;
    
    GLsizeiptr _indexBufferCapacity;
    GLsizeiptr _vertexBufferCapacity;
}

@property (nonatomic, readonly) GLuint VAO;
@property (nonatomic, readonly) GLsizei indiciesCount;
@property (nonatomic) NSMutableArray *items;
@property (nonatomic) CGFloat screenRatio;
@property (nonatomic) BCPoint3D lightDirection;

@property (nonatomic) float diffuseLightFactor;
@property (nonatomic) CATransform3D supplementaryTransform;
@property (nonatomic, copy) MSTransform *meshTransform;

@end
