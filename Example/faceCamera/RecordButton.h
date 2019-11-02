//
//  MyButton.h
//  faceCamera
//
//  Created by cain on 16/6/14.
//  Copyright © 2016年 cain. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum{
    simpleButton,
    recordButton,
    captureButton,
    colorButton,
}ButtonStyles;

@interface RecordButton : UIButton

@property UIColor *progressColor;
@property UIColor *buttonColor;
@property (nonatomic) ButtonStyles buttonStyle;
@property (nonatomic) CGFloat progress;
@property (nonatomic) BOOL recording;
@property (nonatomic) BOOL isRecordMode;

@end
