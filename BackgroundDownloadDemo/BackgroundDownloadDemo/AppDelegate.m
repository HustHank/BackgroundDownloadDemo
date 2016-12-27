//
//  AppDelegate.m
//  BackgroundDownloadDemo
//
//  Created by HK on 16/9/10.
//  Copyright © 2016年 hkhust. All rights reserved.
//

#import "AppDelegate.h"
#import "NSURLSession+CorrectedResumeData.h"

#define IS_IOS10ORLATER ([[[UIDevice currentDevice] systemVersion] floatValue] >= 10)

typedef void(^CompletionHandlerType)();

@interface AppDelegate () <NSURLSessionDownloadDelegate>

@property (strong, nonatomic) NSMutableDictionary *completionHandlerDictionary;
@property (strong, nonatomic) NSURLSessionDownloadTask *downloadTask;
@property (strong, nonatomic) NSURLSession *backgroundSession;
@property (strong, nonatomic) NSData *resumeData;

@property (strong, nonatomic) UILocalNotification *localNotification;

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    self.completionHandlerDictionary = @{}.mutableCopy;
    self.backgroundSession = [self backgroundURLSession];
    
    [self initLocalNotification];
    // ios8后，需要添加这个注册，才能得到授权
    if ([[UIApplication sharedApplication] respondsToSelector:@selector(registerUserNotificationSettings:)]) {
        UIUserNotificationType type =  UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound;
        UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:type
                                                                                 categories:nil];
        [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
        // 通知重复提示的单位，可以是天、周、月
        self.localNotification.repeatInterval = 0;
    } else {
        // 通知重复提示的单位，可以是天、周、月
        self.localNotification.repeatInterval = 0;
    }
    
    UILocalNotification *localNotification = [launchOptions valueForKey:UIApplicationLaunchOptionsLocalNotificationKey];
    if (localNotification) {
        [self application:application didReceiveLocalNotification:localNotification];
    }
    return YES;
}

- (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)())completionHandler {
    // 你必须重新建立一个后台 seesion 的参照
    // 否则 NSURLSessionDownloadDelegate 和 NSURLSessionDelegate 方法会因为
    // 没有 对 session 的 delegate 设定而不会被调用。参见上面的 backgroundURLSession
    NSURLSession *backgroundSession = [self backgroundURLSession];
    
    NSLog(@"Rejoining session with identifier %@ %@", identifier, backgroundSession);
    
    // 保存 completion handler 以在处理 session 事件后更新 UI
    [self addCompletionHandler:completionHandler forSession:identifier];
}

#pragma mark Save completionHandler
- (void)addCompletionHandler:(CompletionHandlerType)handler forSession:(NSString *)identifier {
    if ([self.completionHandlerDictionary objectForKey:identifier]) {
        NSLog(@"Error: Got multiple handlers for a single session identifier.  This should not happen.\n");
    }
    
    [self.completionHandlerDictionary setObject:handler forKey:identifier];
}

- (void)callCompletionHandlerForSession:(NSString *)identifier {
    CompletionHandlerType handler = [self.completionHandlerDictionary objectForKey:identifier];
    
    if (handler) {
        [self.completionHandlerDictionary removeObjectForKey: identifier];
        NSLog(@"Calling completion handler for session %@", identifier);
        
        handler();
    }
}

#pragma mark - Local Notification
- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {
    [[UIApplication sharedApplication] cancelAllLocalNotifications];
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"下载通知"
                                                    message:notification.alertBody
                                                   delegate:nil
                                          cancelButtonTitle:@"确定"
                                          otherButtonTitles:nil];
    [alert show];
    
    // 图标上的数字减1
    application.applicationIconBadgeNumber -= 1;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // 图标上的数字减1
    application.applicationIconBadgeNumber -= 1;
}

- (void)initLocalNotification {
    self.localNotification = [[UILocalNotification alloc] init];
    self.localNotification.fireDate = [[NSDate date] dateByAddingTimeInterval:5];
    self.localNotification.alertAction = nil;
    self.localNotification.soundName = UILocalNotificationDefaultSoundName;
    self.localNotification.alertBody = @"下载完成了！";
    self.localNotification.applicationIconBadgeNumber = 1;
    self.localNotification.repeatInterval = 0;
}

- (void)sendLocalNotification {
    [[UIApplication sharedApplication] scheduleLocalNotification:self.localNotification];
}


#pragma mark - backgroundURLSession
- (NSURLSession *)backgroundURLSession {
    static NSURLSession *session = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *identifier = @"com.yourcompany.appId.BackgroundSession";
        NSURLSessionConfiguration* sessionConfig = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:identifier];
        session = [NSURLSession sessionWithConfiguration:sessionConfig
                                                delegate:self
                                           delegateQueue:[NSOperationQueue mainQueue]];
    });
    
    return session;
}

#pragma mark - Public Mehtod
- (void)beginDownloadWithUrl:(NSString *)downloadURLString {
    NSURL *downloadURL = [NSURL URLWithString:downloadURLString];
    NSURLRequest *request = [NSURLRequest requestWithURL:downloadURL];
    //cancel last download task
    [self.downloadTask cancelByProducingResumeData:^(NSData * resumeData) {

    }];
    
    self.downloadTask = [self.backgroundSession downloadTaskWithRequest:request];
    [self.downloadTask resume];
}

- (void)pauseDownload {
    __weak __typeof(self) wSelf = self;
    [self.downloadTask cancelByProducingResumeData:^(NSData * resumeData) {
        __strong __typeof(wSelf) sSelf = wSelf;
        sSelf.resumeData = resumeData;
    }];
}

- (void)continueDownload {
    if (self.resumeData) {
        if (IS_IOS10ORLATER) {
            self.downloadTask = [self.backgroundSession downloadTaskWithCorrectResumeData:self.resumeData];
        } else {
            self.downloadTask = [self.backgroundSession downloadTaskWithResumeData:self.resumeData];
        }
        [self.downloadTask resume];
        self.resumeData = nil;
    }
}

- (BOOL)isValideResumeData:(NSData *)resumeData
{
    if (!resumeData || resumeData.length == 0) {
        return NO;
    }
    return YES;
}

#pragma mark - NSURLSessionDownloadDelegate
- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location {
    
    NSLog(@"downloadTask:%lu didFinishDownloadingToURL:%@", (unsigned long)downloadTask.taskIdentifier, location);
    NSString *locationString = [location path];
    NSString *finalLocation = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory , NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:[NSString stringWithFormat:@"%lufile",(unsigned long)downloadTask.taskIdentifier]];
    NSError *error;
    [[NSFileManager defaultManager] moveItemAtPath:locationString toPath:finalLocation error:&error];
    
    // 用 NSFileManager 将文件复制到应用的存储中
    // ...
    
    // 通知 UI 刷新
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
 didResumeAtOffset:(int64_t)fileOffset
expectedTotalBytes:(int64_t)expectedTotalBytes {
    
    NSLog(@"fileOffset:%lld expectedTotalBytes:%lld",fileOffset,expectedTotalBytes);
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    
    NSLog(@"downloadTask:%lu percent:%.2f%%",(unsigned long)downloadTask.taskIdentifier,(CGFloat)totalBytesWritten / totalBytesExpectedToWrite * 100);
    NSString *strProgress = [NSString stringWithFormat:@"%.2f",(CGFloat)totalBytesWritten / totalBytesExpectedToWrite];
    [self postDownlaodProgressNotification:strProgress];
}

- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session {
    NSLog(@"Background URL session %@ finished events.\n", session);
    
    if (session.configuration.identifier) {
        // 调用在 -application:handleEventsForBackgroundURLSession: 中保存的 handler
        [self callCompletionHandlerForSession:session.configuration.identifier];
    }
}

/*
 * 该方法下载成功和失败都会回调，只是失败的是error是有值的，
 * 在下载失败时，error的userinfo属性可以通过NSURLSessionDownloadTaskResumeData
 * 这个key来取到resumeData(和上面的resumeData是一样的)，再通过resumeData恢复下载
 */
- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {
    
    if (error) {
        // check if resume data are available
        if ([error.userInfo objectForKey:NSURLSessionDownloadTaskResumeData]) {
            NSData *resumeData = [error.userInfo objectForKey:NSURLSessionDownloadTaskResumeData];
            //通过之前保存的resumeData，获取断点的NSURLSessionTask，调用resume恢复下载
            self.resumeData = resumeData;
        }
    } else {
        [self sendLocalNotification];
        [self postDownlaodProgressNotification:@"1"];
    }
}

- (void)postDownlaodProgressNotification:(NSString *)strProgress {
    NSDictionary *userInfo = @{@"progress":strProgress};
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kDownloadProgressNotification object:nil userInfo:userInfo];
    });
}
@end
