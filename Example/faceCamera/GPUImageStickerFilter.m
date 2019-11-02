//
//  GPUImageStickerFilter.m
//  faceCamera
//
//  Created by cain on 16/3/12.
//  Copyright © 2016年 cain. All rights reserved.
//

#import "GPUImageStickerFilter.h"

@implementation GPUImageStickerFilter

NSString *const kImageStickShaderString = SHADER_STRING
(
  precision highp float;
  varying highp vec2 textureCoordinate;
  
  uniform sampler2D inputImageTexture;
  uniform sampler2D inputImageTexture2;
  
  uniform vec2 alignPoint;
  uniform vec2 size;
  uniform int fcount;
  
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
      
      vec4 c2 = texture2D(inputImageTexture, textureCoordinate);
      if(fcount == 0){
          gl_FragColor = c2;
          return;
      }
      
      if (textureCoordinate.x <= (alignPoint.x + size.x * 0.5) &&
          textureCoordinate.x > (alignPoint.x - size.x * 0.5) &&
          textureCoordinate.y <= (alignPoint.y + size.y * 0.5) &&
          textureCoordinate.y > (alignPoint.y - size.y * 0.5))
      {
          float x_coord = (textureCoordinate.x - alignPoint.x + size.x * 0.5) / size.x;
          float y_coord = (textureCoordinate.y - alignPoint.y + size.y * 0.5) / size.y;
          
          vec2 coordUse = vec2(x_coord, y_coord);
          
          vec4 c1 = texture2D(inputImageTexture2, coordUse);
          gl_FragColor = blendNormal(c1, c2);
      }
      else
      {
          gl_FragColor = c2;
      }
  }
);
 

- (id)init;
{
    if (!(self = [super initWithFragmentShaderFromString:kImageStickShaderString]))
    {
        return nil;
    }
    pointUniform = [filterProgram uniformIndex:@"alignPoint"];
    sizeUniform = [filterProgram uniformIndex:@"size"];
    fcountUniform = [filterProgram uniformIndex:@"fcount"];
    return self;
}

- (void)setSize:(CGSize)size
{
    _size = size;
    [self setSize:_size forUniform:sizeUniform program:filterProgram];
}

- (void)setFcount:(int)fcount
{
    _fcount = fcount;
    [self setInteger:_fcount forUniform:fcountUniform program:filterProgram];
}

-(void)setPoint:(CGPoint)point{
    _point = point;
    [self setPoint:_point forUniform:pointUniform program:filterProgram];
}

@end
