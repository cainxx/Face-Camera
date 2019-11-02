//
//  RootViewController.m
//  MSCDemo
//
//  Created by iflytek on 13-6-6.
//  Copyright (c) 2013年 iflytek. All rights reserved.
//

#import "RootViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "DemoPreDefine.h"

#import "FaceDetectorViewController.h"
#import "FaceRequestViewController.h"
#import "FaceStreamDetectorViewController.h"



@implementation RootViewController

@synthesize thumbView=_thumbView;
@synthesize tableView=_tableView;
/*
 Demo的主界面功能定义，具体内容介绍可以参考readme.txt介绍
 */
- (instancetype) init{
    if(self = [super init]){
        
    }
    return self;
}

#pragma mark - View lifecycle

- (void)viewDidLoad{
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor blackColor];
    self.title = @"讯飞人脸识别示例";
    
    //adjust the UI for iOS 7
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
    if ( IOS7_OR_LATER ){
        self.edgesForExtendedLayout = UIRectEdgeNone;
        self.extendedLayoutIncludesOpaqueBars = NO;
        self.modalPresentationCapturesStatusBarAppearance = NO;
        self.navigationController.navigationBar.translucent = NO;
    }
#endif
    
    //demo支持的功能集合
    self.functions = @[@"在线人脸识别示例",@"离线图片检测示例",@"离线视频检测示例"];
    
    
    //thumb

    self.thumbView.text =@"      人脸识别现阶段支持在线人脸注册、验证、检测、聚焦和离线图片、视频流检测。示例中有详尽的代码注释,\
    以帮助开发者快速集成SDK。";
    
    self.thumbView.textColor=[UIColor whiteColor];
    self.thumbView.backgroundColor=[UIColor blackColor];
    self.thumbView.layer.borderWidth = 1;
    self.thumbView.layer.cornerRadius = 8;
    self.thumbView.layer.borderColor=[UIColor whiteColor].CGColor;
    [self.thumbView.layer setMasksToBounds:YES];
    self.thumbView.editable = NO;
    self.thumbView.font = [UIFont systemFontOfSize:17.0f];
    [self.thumbView sizeToFit];

    
    //table

   self.tableView.delegate = self;
   self.tableView.scrollEnabled = YES;
   self.tableView.dataSource = self;
   self.tableView.backgroundColor=[UIColor blackColor];
   self.tableView.backgroundView = nil;
   [self.tableView setTableFooterView:[[UIView alloc] initWithFrame:CGRectZero]];

}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return self.functions.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        
    }
    
    NSInteger index=indexPath.row;
    NSInteger count=self.functions.count;
    if(index <count){
        cell.textLabel.text = [self.functions objectAtIndex:index];
        cell.backgroundColor=[UIColor blackColor];
        cell.textLabel.textColor=[UIColor whiteColor];
        cell.textLabel.backgroundColor=[UIColor blackColor];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    return cell ;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    switch (indexPath.row) {
        case 0:{
            FaceRequestViewController* fr=[self.storyboard instantiateViewControllerWithIdentifier:@"FaceRequestViewController"];
            [self.navigationController pushViewController:fr animated:YES];
        }
            break;
        case 1:{
            FaceDetectorViewController* fd=[self.storyboard instantiateViewControllerWithIdentifier:@"FaceDetectorViewController"];
            [self.navigationController pushViewController:fd animated:YES];
        }
            break;
        case 2:{
            FaceStreamDetectorViewController* fsd=[self.storyboard instantiateViewControllerWithIdentifier:@"FaceStreamDetectorViewController"];
            [self.navigationController pushViewController:fsd animated:YES];
        }
            break;
        default:{
            
        }
            break;
    }
}

- (void)dealloc {
    self.thumbView=nil;
    self.tableView=nil;
    self.functions=nil;
}
@end
