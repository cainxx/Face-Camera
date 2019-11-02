//
//  RootViewController.h
//  MSCDemo
//
//  Created by iflytek on 13-6-6.
//  Copyright (c) 2013年 iflytek. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface RootViewController : UIViewController<UITableViewDelegate,UITableViewDataSource>

@property (retain, nonatomic) NSArray *functions;
@property (retain, nonatomic) IBOutlet UITextView *thumbView;
@property (retain, nonatomic) IBOutlet UITableView *tableView;

@end
