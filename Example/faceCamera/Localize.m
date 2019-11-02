//
//  Localize.m
//  faceCamera
//
//  Created by cain on 16/6/7.
//  Copyright © 2016年 cain. All rights reserved.
//

#import "Localize.h"

@implementation NSString (SK)

-(NSString *)localized{
    NSString *path = [[NSBundle mainBundle] pathForResource:[Localize currentLanguage] ofType:@"lproj"];
    NSBundle *bundle = [NSBundle bundleWithPath:path];
    if(bundle){
        return [bundle localizedStringForKey:self value:self table:nil];
    }
    path = [[NSBundle mainBundle] pathForResource:BaseBundle ofType:@"lproj"];
    bundle = [NSBundle bundleWithPath:path];
    if(bundle){
        return [bundle localizedStringForKey:self value:self table:nil];
    }
    return self;
}

-(NSString *)localizedFormat:(NSArray*) arguments{
    NSRange range = NSMakeRange(0, [arguments count]);
    NSMutableData *data = [NSMutableData dataWithLength:sizeof(id) * [arguments count]];
    [arguments getObjects:(__unsafe_unretained id *)data.mutableBytes range:range];
    NSString *result = [[NSString alloc] initWithFormat:[self localized] arguments:data.mutableBytes];
    return result;
}

@end

@implementation Localize

+(NSArray *)availableLanguages{
    return  [NSBundle mainBundle].localizations;
}

+(NSString *)currentLanguage{
    if([[NSUserDefaults standardUserDefaults] objectForKey:CurrentLanguageKey]){
        return [[NSUserDefaults standardUserDefaults] objectForKey:CurrentLanguageKey];
    }
    return [Localize defaultLanguage];
}

+(void)setCurrentLanguage:(NSString *)language{
    NSString *selectedLanguage = [[Localize availableLanguages] containsObject:language] ? language : [Localize defaultLanguage];
    if (![selectedLanguage isEqualToString:[Localize currentLanguage]]){
        [[NSUserDefaults standardUserDefaults] setObject:selectedLanguage forKey:CurrentLanguageKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

+(NSString *)defaultLanguage{
    NSString *preferredLanguage = [NSBundle mainBundle].preferredLocalizations.firstObject;
    if([[self availableLanguages] containsObject:preferredLanguage]){
        return preferredLanguage;
    }
    return DefaultLanguage;
}

+(void)resetCurrentLanguageToDefault{
    [self setCurrentLanguage:[self defaultLanguage]];
}

+(NSString *)displayNameForLanguage:(NSString *)language{
    NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:[self currentLanguage]];
    return [locale displayNameForKey:NSLocaleLanguageCode value:language];
}

@end
