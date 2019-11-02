//
//  MeshItem.h
//  faceCamera
//
//  Created by cain on 16/6/19.
//  Copyright © 2016年 cain. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MeshItem : NSObject

@property int type;
@property float strength;
@property CGPoint point;
@property float radius;
@property int direction;
@property float faceDegree;
@property float faceRatio;

+ (MeshItem *) itemWith:(int)type :(float)strength :(CGPoint)point :(float)radius :(int)direction :(float)faceDegree :(float)faceRatio;

@end
