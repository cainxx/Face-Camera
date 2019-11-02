//
//  Uitls.m
//  showker
//
//  Created by cain on 14-5-19.
//  Copyright (c) 2014年 cain. All rights reserved.
//

#import "Utils.h"
#import <CommonCrypto/CommonDigest.h>

@implementation Utils

+ (UIImage *)convertImageToGrayScale:(UIImage *)image
{
    CIImage *inputImage = [CIImage imageWithCGImage:image.CGImage];
    CIContext *context = [CIContext contextWithOptions:nil];
    
    CIFilter *filter = [CIFilter filterWithName:@"CIColorControls"];
    [filter setValue:inputImage forKey:kCIInputImageKey];
    [filter setValue:@(0.0) forKey:kCIInputSaturationKey];
    
    CIImage *outputImage = filter.outputImage;
    
    CGImageRef cgImageRef = [context createCGImage:outputImage fromRect:outputImage.extent];
    
    UIImage *result = [UIImage imageWithCGImage:cgImageRef];
    CGImageRelease(cgImageRef);
    return result;
}

+(BOOL)isEmpty:(id)value{
    if(value == nil || value == Nil || value == (id)[NSNull null]){
        return YES;
    }
    if ([value respondsToSelector:@selector(count)]) {
        return [value count]<1;
    }else if ([value respondsToSelector:@selector(length)]) {
       return [value length]<1;
    }
    return NO;
}

+(NSString *)trim:(NSString *)string{
   return [string stringByTrimmingCharactersInSet:
           [NSCharacterSet whitespaceCharacterSet]];
}

+(NSDictionary *)readJson:(NSString *)path{
    if(![[NSFileManager defaultManager] fileExistsAtPath:path]){
        return nil;
    }
    NSData *data = [NSData dataWithContentsOfFile:path];
    return [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
}



@end
