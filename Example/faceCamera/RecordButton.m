//
//  MyButton.m
//  faceCamera
//
//  Created by cain on 16/6/14.
//  Copyright © 2016年 cain. All rights reserved.
//

#import "RecordButton.h"
#import <pop/POP.h>

@interface RecordButton()

@property CALayer *circleLayer;
@property CALayer *circleBorder;
@property CAShapeLayer *progressLayer;
//@property gradientMaskLayer: CAGradientLayer!
@property CGFloat currentProgress;

@end


@implementation RecordButton

-(instancetype)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    return self;
}

-(void)setButtonStyle:(ButtonStyles)buttonStyle{
    _buttonStyle = buttonStyle;
   [self configure];
//    self.adjustsImageWhenHighlighted = NO;
//    self.showsTouchWhenHighlighted = NO;
//    [self setBackgroundImage:nil forState:UIControlStateSelected | UIControlStateHighlighted | UIControlStateNormal];
}

-(void)configure{
    
    self.buttonColor = [UIColor colorWithRGBHex:0xffffff];
    self.progressColor = [UIColor colorWithRGBHex:0xffffff];
    
    [self addTarget:self action:@selector(didTouchDown) forControlEvents:UIControlEventTouchDown];
    [self addTarget:self action:@selector(didTouchUp) forControlEvents:UIControlEventTouchUpInside];
    [self addTarget:self action:@selector(didTouchUp) forControlEvents:UIControlEventTouchUpOutside];
 
    if(self.buttonStyle == captureButton || self.buttonStyle == recordButton){
        self.backgroundColor = [UIColor clearColor];
        self.circleLayer = [[CALayer alloc] init];
        self.circleBorder = [[CALayer alloc] init];
        self.progressLayer = [[CAShapeLayer alloc] init];
        self.circleLayer.contentsScale = [[UIScreen mainScreen] scale];
        self.circleBorder.contentsScale = [[UIScreen mainScreen] scale];
        self.progressLayer.contentsScale = [[UIScreen mainScreen] scale];
        self.circleLayer.allowsEdgeAntialiasing = YES;
        self.circleBorder.allowsEdgeAntialiasing = YES;
        
        CGFloat size = self.frame.size.width / 1.2;
        self.circleLayer.backgroundColor = [UIColor whiteColor].CGColor;
        self.circleLayer.bounds = CGRectMake(0, 0, size, size);
        self.circleLayer.anchorPoint = CGPointMake(0.5, 0.5);
        self.circleLayer.position = CGPointMake(CGRectGetMidX(self.bounds),CGRectGetMidY(self.bounds));
        self.circleLayer.cornerRadius = size / 2;
        [self.layer insertSublayer:self.circleLayer atIndex:0];
        
        self.circleBorder.backgroundColor = [UIColor clearColor].CGColor;
        self.circleBorder.borderWidth = 1;
        self.circleBorder.borderColor = [UIColor whiteColor].CGColor;
        self.circleBorder.bounds = CGRectMake(1, 1, self.bounds.size.width - 2.5, self.bounds.size.height - 2.5);
        self.circleBorder.anchorPoint = CGPointMake(0.5, 0.5);
        self.circleBorder.position = CGPointMake(CGRectGetMidX(self.bounds),CGRectGetMidY(self.bounds));
        self.circleBorder.cornerRadius = self.frame.size.width / 2;
        [self.layer insertSublayer:self.circleBorder atIndex:0];
        
        CGFloat startAngle = M_PI + M_PI_2;
        CGFloat endAngle = M_PI * 3 + M_PI_2;
        CGPoint centerPoint = CGPointMake(self.frame.size.width / 2, self.frame.size.height / 2);
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path addArcWithCenter:centerPoint radius:self.frame.size.width / 2 - 4 startAngle:startAngle endAngle:endAngle clockwise:true];
        self.progressLayer.path = path.CGPath;
        self.progressLayer.backgroundColor = [UIColor clearColor].CGColor;
        self.progressLayer.fillColor = nil;
        self.progressLayer.strokeColor = [UIColor whiteColor].CGColor;
        self.progressLayer.lineWidth = 4.0;
        self.progressLayer.strokeStart = 0.0;
        self.progressLayer.strokeEnd = 0.0;
//        gradientMaskLayer.mask = progressLayer
        [self.layer insertSublayer:self.progressLayer atIndex:0];
        self.recording = NO;
    }
}

-(void)setRecording:(BOOL)recording{
    if(recording == _recording){
        return;
    }
    
    _recording = recording;
    if(self.isRecordMode){
        POPBasicAnimation *PYAnimation;
        PYAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerScaleXY];
        PYAnimation.toValue = [NSValue valueWithCGPoint:CGPointMake( recording ? 1.2 : 1.0, recording ? 1.2 : 1.0)];
        PYAnimation.duration = 0.8;
        [self.layer pop_addAnimation:PYAnimation forKey:@"pop"];
        return;
    }

    CGFloat duration = 0.2;
    CABasicAnimation *scale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
//    scale.fromValue = recording ? @(1.0) : @( self.buttonStyle == captureButton ? 0.5 : 0.88);
//    scale.toValue = recording ? @(self.buttonStyle == captureButton ? 0.5 : 0.88) : @(1.0);
    scale.fromValue = recording ? @(1.0)  : @(0.8);
    scale.toValue = recording ? @(0.8) : @(1.0) ;
    scale.duration = 0.2;
    scale.fillMode = kCAFillModeForwards;
    scale.removedOnCompletion = false;
    
    CABasicAnimation *color = [CABasicAnimation animationWithKeyPath:@"backgroundColor"];
    color.duration = duration;
    color.fillMode = kCAFillModeForwards;
    color.removedOnCompletion = false;
    color.toValue = (__bridge id _Nullable)(recording ? self.progressColor.CGColor : self.buttonColor.CGColor);
    
    CABasicAnimation *radius = [CABasicAnimation animationWithKeyPath:@"cornerRadius"];
    radius.duration = duration;
    radius.fillMode = kCAFillModeForwards;
    radius.removedOnCompletion = false;
    radius.toValue = recording ? @(5) : @(self.circleLayer.frame.size.width/2);
    
    CAAnimationGroup *circleAnimations = [CAAnimationGroup animation];
    circleAnimations.removedOnCompletion = false;
    circleAnimations.fillMode = kCAFillModeForwards;
    circleAnimations.duration = duration;
//    circleAnimations.animations = @[scale,radius];
    circleAnimations.animations = @[scale];
    
    CABasicAnimation *borderColor = [CABasicAnimation animationWithKeyPath:@"borderColor"];
    borderColor.duration = duration;
    borderColor.fillMode = kCAFillModeForwards;
    borderColor.removedOnCompletion = false;
    borderColor.toValue =  (__bridge id _Nullable)(recording ? self.progressColor.CGColor : self.buttonColor.CGColor);
    
    CABasicAnimation *borderScale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    borderScale.fromValue = recording ? @(1.0) : @(0.88);
    borderScale.toValue = recording ? @(0.88) : @(1.0);
    borderScale.duration = duration;
    borderScale.fillMode = kCAFillModeForwards;
    borderScale.removedOnCompletion = false;
    
    CAAnimationGroup *borderAnimations = [CAAnimationGroup animation];
    borderAnimations.removedOnCompletion = false;
    borderAnimations.fillMode = kCAFillModeForwards;
    borderAnimations.duration = duration;
    borderAnimations.animations = @[borderColor, borderScale];
    
    CABasicAnimation *fade = [CABasicAnimation animationWithKeyPath:@"opacity"];
    fade.fromValue = recording ? @(0.0) : @(1.0);
    fade.toValue = recording ?  @(1.0) : @(0.0);
    fade.duration = duration;
    fade.fillMode = kCAFillModeForwards;
    fade.removedOnCompletion = false;
    CABasicAnimation *progScale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    progScale.fromValue = recording ? @(1.0) : @(0.88);
    progScale.toValue = recording ? @(0.88) : @(1.0);
    progScale.duration = duration;
    progScale.fillMode = kCAFillModeForwards;
    progScale.removedOnCompletion = false;

    [self.circleLayer addAnimation:circleAnimations forKey:@"circleAnimations"];
    [self.progressLayer addAnimation:fade forKey:@"fade"];
//    [self.circleBorder addAnimation:borderAnimations forKey:@"borderAnimations"];
}

-(void)layoutSubviews{
    self.circleLayer.anchorPoint = CGPointMake(0.5, 0.5);
    self.circleLayer.position = CGPointMake(CGRectGetMidX(self.bounds),CGRectGetMidY(self.bounds));
    self.circleBorder.anchorPoint = CGPointMake(0.5, 0.5);
    self.circleBorder.position = CGPointMake(CGRectGetMidX(self.bounds),CGRectGetMidY(self.bounds));
    [super layoutSubviews];
}

-(void)didTouchDown{
    if(!self.recording){
        self.recording = YES;
    }
    if (self.buttonStyle == colorButton){
        POPBasicAnimation *anim = [self.layer pop_animationForKey:@"scalexy"];
        if(anim){
            anim.fromValue = [NSValue valueWithCGSize:CGSizeMake(0.7, 0.7)];
            anim.toValue = [NSValue valueWithCGSize:CGSizeMake(1.0, 1.0)];
            return;
        }
        anim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerScaleXY];
        anim.fromValue = [NSValue valueWithCGSize:CGSizeMake(1, 1)];
        anim.toValue = [NSValue valueWithCGSize:CGSizeMake(0.7, 0.7)];
        anim.duration = 0.1;
 
        anim.completionBlock = ^(POPAnimation *animation, BOOL finished) {
            POPSpringAnimation *anim = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerScaleXY];
            anim.fromValue = [NSValue valueWithCGSize:CGSizeMake(0.7, 0.7)];
            anim.toValue = [NSValue valueWithCGSize:CGSizeMake(1.0, 1.0)];
            anim.springBounciness=15;    // value between 0-20 default at 4
            anim.springSpeed=20;     // value between 0-20 default at 4
            [self.layer pop_addAnimation:anim forKey:@"springScalexy"];
        };
        [self.layer pop_addAnimation:anim forKey:@"scalexy"];
    }
}

-(void)didTouchUp{
//    if (self.buttonStyle == colorButton){
//        POPSpringAnimation *anim = [self.layer pop_animationForKey:@"scalexy"];
//        anim.fromValue = [NSValue valueWithCGSize:CGSizeMake(0.7, 0.7)];
//        anim.toValue = [NSValue valueWithCGSize:CGSizeMake(1.0, 1.0)];
//        anim.springBounciness=20;    // value between 0-20 default at 4
//        anim.springSpeed=3;     // value between 0-20 default at 4
//    }
//    if(self.buttonStyle != recordButton){
        return;
//    }
//    [UIView animateWithDuration:0.2 animations:^{
//        self.recording = NO;
//    }];
}

-(void)setProgress:(CGFloat)progress{
    self.progressLayer.strokeEnd = progress;
}

- (void)setSelected:(BOOL)selected {
    [super setSelected:selected];
    self.titleLabel.font = selected ? [UIFont systemFontOfSize:16] : [UIFont systemFontOfSize:13];
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
