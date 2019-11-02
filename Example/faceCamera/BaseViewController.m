//
//  BaseViewController.m
//  camera
//
//  Created by cain on 15/9/21.
//  Copyright (c) 2015年 cain. All rights reserved.
//

#import "BaseViewController.h"


@interface BaseViewController ()


@end

@implementation BaseViewController

- (void)viewDidLoad {
    self.automaticallyAdjustsScrollViewInsets = NO;
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    if(self.hideNavigationBar){
        [self.navigationController setNavigationBarHidden:YES animated:YES ];
    }else{
        [self.navigationController setNavigationBarHidden:NO animated:NO];
    }
}

-(void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
}


-(BOOL)hidesBottomBarWhenPushed{
    return YES;
}

- (void)setTabBarVisible:(BOOL)visible animated:(BOOL)animated withScrollView:(UIScrollView *)scrollView{
    if([self hidesBottomBarWhenPushed]){
        return;
    }
    if ([self tabBarIsVisible] == visible) return;
    if(visible){
        self.tabBarController.tabBar.hidden = NO;
    }
    
    CGRect frame = self.tabBarController.tabBar.frame;
    CGFloat height = frame.size.height;
    CGFloat offsetY = (visible)? -height : height;
    // zero duration means no animation
    CGFloat duration = (animated)? 0.3 : 0.0;
    [UIView animateWithDuration:duration animations:^{
        self.tabBarController.tabBar.frame = CGRectOffset(frame, 0, offsetY);
    }completion:^(BOOL finished) {
 
    }];
}

- (BOOL)tabBarIsVisible {
    return self.tabBarController.tabBar.frame.origin.y < CGRectGetMaxY(self.view.frame);
}
 
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
