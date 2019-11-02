//
//  GPUImagePeopleFilter.m
//  faceCamera
//
//  Created by cain on 16/3/3.
//  Copyright © 2016年 cain. All rights reserved.
//

#import "GPUImagePeopleFilter.h"

@implementation GPUImagePeopleFilter

NSString *const kPeopleShaderString = SHADER_STRING
(
 precision highp float;
  varying highp vec2 textureCoordinate;
  
  uniform sampler2D inputImageTexture;
  uniform sampler2D inputImageTexture2;
  uniform vec2 imgSize;
  uniform int faceCnt;
  uniform vec2 alignPoint0;
  uniform vec2 alignPoint1;
  uniform vec2 alignPoint2;
  uniform vec2 alignPoint3;
  uniform vec2 alignPoint4;
  
  uniform vec2 size0;
  uniform vec2 size1;
  uniform vec2 size2;
  uniform vec2 size3;
  uniform vec2 size4;
  
  uniform vec2 angle0;
  uniform vec2 angle1;
  uniform vec2 angle2;
  uniform vec2 angle3;
  uniform vec2 angle4;
  
  
  vec4 blendNormal(vec4 c1, vec4 c2)
 {
     vec4 outputColor;
     outputColor.r = c1.r + c2.r * c2.a * (1.0 - c1.a);
     outputColor.g = c1.g + c2.g * c2.a * (1.0 - c1.a);
     outputColor.b = c1.b + c2.b * c2.a * (1.0 - c1.a);
     outputColor.a = c1.a + c2.a * (1.0 - c1.a);
     return outputColor;
 }
  
  void main(){
      
      gl_FragColor = texture2D(inputImageTexture, textureCoordinate);
      
      if (faceCnt < 1) {
          return;
      }
      
      float x_a = imgSize.x;
      float y_a = imgSize.y;
      
      vec2 rotateCoord = vec2(0.0,0.0);
      vec2 scrPix = vec2(textureCoordinate.x*x_a,textureCoordinate.y*y_a);
      
      
      vec2 pngSize = vec2(size0.x * x_a, size0.y * y_a);
      vec2 png_center = pngSize * 0.5;
      vec2 target_pix = vec2(alignPoint0.x*x_a,alignPoint0.y*y_a);
      
      
      rotateCoord.x = angle0.y*scrPix.x+angle0.x*scrPix.y;
      rotateCoord.y = angle0.y*scrPix.y-angle0.x*scrPix.x;
      
      
      vec2 weiyi = vec2(0.0,0.0);
      weiyi.x = angle0.y*target_pix.x+angle0.x*target_pix.y;
      weiyi.y = angle0.y*target_pix.y-angle0.x*target_pix.x;
      rotateCoord = rotateCoord + png_center - weiyi;
      
      vec4 c1 = vec4(0.0);
      vec2 realCoord = vec2(rotateCoord.x/pngSize.x,rotateCoord.y/pngSize.y);
      if (realCoord.x > 0.0 && realCoord.y > 0.0 && realCoord.x < 1.0 && realCoord.y < 1.0)
      {
          c1 = texture2D(inputImageTexture2, realCoord);
      }
      
      gl_FragColor = blendNormal(c1, gl_FragColor);
      
      
      
      if (faceCnt>=2)
      {
          
          pngSize = vec2(size1.x * x_a, size1.y * y_a);
          png_center = pngSize * 0.5;
          target_pix = vec2(alignPoint1.x*x_a,alignPoint1.y*y_a);
          
          
          rotateCoord.x = angle1.y*scrPix.x+angle1.x*scrPix.y;
          rotateCoord.y = angle1.y*scrPix.y-angle1.x*scrPix.x;
          
          weiyi.x = angle1.y*target_pix.x+angle1.x*target_pix.y;
          weiyi.y = angle1.y*target_pix.y-angle1.x*target_pix.x;
          
          rotateCoord = rotateCoord + png_center - weiyi;
          
          realCoord = vec2(rotateCoord.x/pngSize.x,rotateCoord.y/pngSize.y);
          if (realCoord.x > 0.0 && realCoord.y > 0.0 && realCoord.x < 1.0 && realCoord.y < 1.0)
          {
              c1 = texture2D(inputImageTexture2, realCoord);
          }
          
          gl_FragColor = blendNormal(c1, gl_FragColor);
      }
      
  
  }
 );


- (id)init;
{
    if (!(self = [super initWithFragmentShaderFromString:kPeopleShaderString]))
    {
        return nil;
    }
    p_faceCount = [filterProgram uniformIndex:@"faceCnt"];
    p_size0 = [filterProgram uniformIndex:@"size0"];
    p_size1 = [filterProgram uniformIndex:@"size1"];
    p_size2 = [filterProgram uniformIndex:@"size2"];
    p_size3 = [filterProgram uniformIndex:@"size3"];
    p_size4 = [filterProgram uniformIndex:@"size4"];
 
    p_targetPoint0 = [filterProgram uniformIndex:@"alignPoint0"];
    p_targetPoint1 = [filterProgram uniformIndex:@"alignPoint1"];
    p_targetPoint2 = [filterProgram uniformIndex:@"alignPoint2"];
    p_targetPoint3 = [filterProgram uniformIndex:@"alignPoint3"];
    p_targetPoint4 = [filterProgram uniformIndex:@"alignPoint4"];
 
    p_angle0 = [filterProgram uniformIndex:@"angle0"];
    p_angle1 = [filterProgram uniformIndex:@"angle1"];
    p_angle2 = [filterProgram uniformIndex:@"angle2"];
    p_angle3 = [filterProgram uniformIndex:@"angle3"];
    p_angle4 = [filterProgram uniformIndex:@"angle4"];
 
    [self setInteger:0 forUniform:p_faceCount program:filterProgram];
    return self;
}

-(void)setImgSize:(CGSize)imgSize{
    [self setSize:imgSize forUniformName:@"imgSize"];
}

-(void)setStickerParams:(NSDictionary *)params{
    [self setInteger:[params[@"count"] intValue] forUniform:p_faceCount program:filterProgram];
    int i = 0;
    for (NSString *str in params[@"angle"]) {
        CGSize size = CGSizeFromString(str);
        switch (i) {
            case 0:
                [self setSize:size forUniform:p_angle0 program:filterProgram];
                break;
            case 1:
                [self setSize:size forUniform:p_angle1 program:filterProgram];
                break;
            case 2:
                [self setSize:size forUniform:p_angle2 program:filterProgram];
                break;
            case 3:
                [self setSize:size forUniform:p_angle3 program:filterProgram];
                break;
            case 4:
                [self setSize:size forUniform:p_angle4 program:filterProgram];
                break;
            default:
                break;
        }
        i++;
    }
    i = 0;
    for (NSString *str in params[@"point"]) {
        CGSize size = CGSizeFromString(str);
        switch (i) {
            case 0:
                [self setSize:size forUniform:p_targetPoint0 program:filterProgram];
                break;
            case 1:
                [self setSize:size forUniform:p_targetPoint1 program:filterProgram];
                break;
            case 2:
                [self setSize:size forUniform:p_targetPoint2 program:filterProgram];
                break;
            case 3:
                [self setSize:size forUniform:p_targetPoint3 program:filterProgram];
                break;
            case 4:
                [self setSize:size forUniform:p_targetPoint4 program:filterProgram];
                break;
            default:
                break;
        }
        i++;
    }
    i = 0;
    for (NSString *str in params[@"size"]) {
        CGSize size = CGSizeFromString(str);
        switch (i) {
            case 0:
                [self setSize:size forUniform:p_size0 program:filterProgram];
                break;
            case 1:
                [self setSize:size forUniform:p_size1 program:filterProgram];
                break;
            case 2:
                [self setSize:size forUniform:p_size2 program:filterProgram];
                break;
            case 3:
                [self setSize:size forUniform:p_size3 program:filterProgram];
                break;
            case 4:
                [self setSize:size forUniform:p_size4 program:filterProgram];
                break;
            default:
                break;
        }
        i++;
    }
    
}


@end
