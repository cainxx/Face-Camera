    //
//  UIImageView+SK.m
//  showker
//
//  Created by cain on 14-5-21.
//  Copyright (c) 2014年 cain. All rights reserved.
//

#import "Category.h"


@implementation UIColor (GDIAdditions)

+ (UIColor *)colorWithRGBHex:(NSUInteger)hex
{
    return [UIColor colorWithRed:((float)((hex & 0xFF0000) >> 16))/255.0f
                           green:((float)((hex & 0xFF00) >> 8))/255.0f
                            blue:((float)(hex & 0xFF))/255.0 alpha:1.0];
}

+ (UIColor *)colorWithARGBHex:(NSUInteger)hex
{
    float alpha = ((float)((hex & 0xFF000000) >> 24))/255.0f;
    return [UIColor colorWithRed:((float)((hex & 0xFF0000) >> 16))/255.0f
                           green:((float)((hex & 0xFF00) >> 8))/255.0f
                            blue:((float)(hex & 0xFF))/255.0f alpha:alpha];
}

@end


@implementation NSDictionary (DeepCopy)
- (NSMutableDictionary *)mutableDeepCopy {
    NSMutableDictionary *ret = [[NSMutableDictionary alloc] initWithCapacity:[self count]];
    NSArray *keys = [self allKeys];
    for (id key in keys) {
        id oneValue = [self valueForKey:key];
        id oneCopy = nil;

        if(oneValue == (id)[NSNull null]){
            oneValue = nil;
        }else if ([oneValue respondsToSelector:@selector(mutableDeepCopy)]) {
            oneCopy = [oneValue mutableDeepCopy];
        }else if ([oneValue respondsToSelector:@selector(mutableCopy)]) {
            oneCopy = [oneValue mutableCopy];
        }
        if (oneCopy == nil) {
            oneCopy = [oneValue copy];
        }
        [ret setValue:oneCopy forKey:key];
    }
    return ret;
}

@end

@implementation NSArray (DeepCopy)
- (NSMutableArray *)mutableDeepCopy {
    NSMutableArray *newArray = [NSMutableArray arrayWithCapacity:self.count];
    id copyValue;
    for (id obj in self) {
        if(obj == (id)[NSNull null]){
            copyValue = nil;
        }else if ([obj respondsToSelector:@selector(mutableDeepCopy)]){
            copyValue = [obj mutableDeepCopy];
        }else if ([obj respondsToSelector:@selector(mutableCopy)]) {
            copyValue = [obj mutableCopy];
        }
        if (copyValue == nil) {
            copyValue = [obj copy];
        }
        [newArray addObject:copyValue];
    }
    return newArray;
}
@end

@implementation NSNumber (DeepCopy)
- (id)mutableDeepCopy{
    return [self copy];
}
@end
