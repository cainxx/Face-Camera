//
//  MeshItem.m
//  faceCamera
//
//  Created by cain on 16/6/19.
//  Copyright © 2016年 cain. All rights reserved.
//

#import "MeshItem.h"

@implementation MeshItem

+ (MeshItem *) itemWith:(int)type :(float)strength :(CGPoint)point :(float)radius :(int)direction :(float)faceDegree :(float)faceRatio{
    MeshItem *item = [MeshItem new];
    item.type = type;
    item.strength = strength;
    item.point = point;
    item.radius = radius;
    item.direction = direction;
    item.faceDegree = faceDegree;
    item.faceRatio = faceRatio;
    return item;
}

@end
