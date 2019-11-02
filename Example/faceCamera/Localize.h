//
//  Localize.h
//  faceCamera
//
//  Created by cain on 16/6/7.
//  Copyright © 2016年 cain. All rights reserved.
//

#import <Foundation/Foundation.h>

#define CurrentLanguageKey @"currentLanguageKey"
#define DefaultLanguage  @"en"
#define BaseBundle  @"Base"

@interface NSString(SK)

-(NSString *)localized;
-(NSString *)localizedFormat:(NSArray*) arguments;

@end

@interface Localize : NSObject

+(NSArray *)availableLanguages;
+(NSString *)currentLanguage;
+(void)setCurrentLanguage:(NSString*)language;
+(NSString *)defaultLanguage;
+(void)resetCurrentLanguageToDefault;
+(NSString *)displayNameForLanguage:(NSString *)language;

@end
