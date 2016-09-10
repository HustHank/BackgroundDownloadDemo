//
//  ViewController.m
//  BackgroundDownloadDemo
//
//  Created by HK on 16/9/10.
//  Copyright © 2016年 hkhust. All rights reserved.
//

#import "ViewController.h"
#import "AppDelegate.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark Method
- (IBAction)download:(id)sender {
    AppDelegate *delegate = [[UIApplication sharedApplication] delegate];
    [delegate beginDownloadWithUrl:@"http://sw.bos.baidu.com/sw-search-sp/software/797b4439e2551/QQ_mac_5.0.2.dmg"];
}

- (IBAction)pauseDownlaod:(id)sender {
    AppDelegate *delegate = [[UIApplication sharedApplication] delegate];
    [delegate pauseDownload];
}

- (IBAction)continueDownlaod:(id)sender {
    AppDelegate *delegate = [[UIApplication sharedApplication] delegate];
    [delegate continueDownload];
}


@end
