//
//  Uitls.h
//  showker
//
//  Created by cain on 14-5-19.
//  Copyright (c) 2014年 cain. All rights reserved.
//

#define PICS_TAGID 2000
#define MYAPPID 1130177039
#define appDomain @"http://120.24.171.134/";

#import <Foundation/Foundation.h>

#define VERSION [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]
#define TimeStamp [NSString stringWithFormat:@"%d",(int)[[NSDate date] timeIntervalSince1970]]
#define RANDOM_FLOAT(MIN,MAX) (((CGFloat)arc4random() / 0x100000000) * (MAX - MIN) + MIN);

#define SCREEN_WIDTH [[UIScreen mainScreen] bounds].size.width
#define SCREEN_HEIGHT [[UIScreen mainScreen] bounds].size.height
#define SCREEM_4_3 (SCREEN_WIDTH/SCREEN_HEIGHT) > 0.6

#define SCALE [UIScreen mainScreen].scale
#define NAVIGATIONBAR_HEIGHT  64
#define TABBAR_HEIGHT  49


@interface Utils : NSObject

+(BOOL)isEmpty:(id)value;
+(NSString *)trim:(NSString *)string;
+(NSDictionary *)readJson:(NSString *)path;
+(UIImage *)convertImageToGrayScale:(UIImage *)image;

@end
