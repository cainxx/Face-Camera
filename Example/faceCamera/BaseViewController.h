//
//  BaseViewController.h
//  camera
//
//  Created by cain on 15/9/21.
//  Copyright (c) 2015年 cain. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface BaseViewController : UIViewController<UIScrollViewDelegate>{
 
}

@property bool hideNavigationBar;
@property bool hideTabBar;
@property UIScrollView *mainScrollView;


@end
