# BackgroundDownloadDemo
一个简单的使用NSURLSession的下载Demo，包括后台下载和断点下载

##运行环境
 * Xcode7.3.1
 * iOS9.3.5

##原理如下

>从iOS7以来，苹果推出NSURLSession后，iOS现在可以实现真正的后台下载，这对我们iOSer来说是一个福音。

一个 NSURLSession 对象可以协调一个或多个 NSURLSessionTask对象，并根据 NSURLSessionTask 创建的 NSURLSessionConfiguration 实现不同的功能。使用相同的配置，你也可以创建多组具有相关任务的 NSURLSession 对象。要利用后台传输服务，你将会使用 [NSURLSessionConfiguration backgroundSessionConfiguration] 来创建一个会话配置。添加到后台会话的任务在外部进程运行，即使应用程序被挂起，崩溃，或者被杀死，它依然会运行。

下面我们来看看如何使用NSURLSession

####下载用到的委托方法
1. AppDelegate委托方法
```
//在应用处于后台，且后台任务下载完成时回调
- (void)application:(UIApplication *)application
handleEventsForBackgroundURLSession:(NSString *)identifier 
 completionHandler:(void (^)())completionHandler;
```
2. NSURLSession委托方法
```
/* 在任务下载完成、下载失败
  * 或者是应用被杀掉后，重新启动应用并创建相关identifier的Session时调用
  */
- (void)URLSession:(NSURLSession *)session
                 task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error;
```
```
/* 应用在后台，而且后台所有下载任务完成后，
 * 在所有其他NSURLSession和NSURLSessionDownloadTask委托方法执行完后回调，
 * 可以在该方法中做下载数据管理和UI刷新
  */
 - (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session;
 ```
*注：最好将handleEventsForBackgroundURLSession中completionHandler保存，在该方法中待所有载数据管理和UI刷新做完后，再调用completionHandler()*

2. NSURLSessionDownloadTask委托方法
```
/* 下载过程中调用，用于跟踪下载进度
 * bytesWritten为单次下载大小
 * totalBytesWritten为当当前一共下载大小
 * totalBytesExpectedToWrite为文件大小
 */
 - (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite;
```
```
/* 下载恢复时调用
 * 在使用downloadTaskWithResumeData:方法获取到对应NSURLSessionDownloadTask，
 * 并该task调用resume的时候调用
  */
 - (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
 didResumeAtOffset:(int64_t)fileOffset
expectedTotalBytes:(int64_t)expectedTotalBytes;
```
```
//下载完成时调用
 - (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location;
```
*注:在URLSession:downloadTask:didFinishDownloadingToURL方法中，location只是一个磁盘上该文件的临时 URL，只是一个临时文件，需要自己使用NSFileManager将文件写到应用的目录下（一般来说这种可以重复获得的内容应该放到cache目录下），因为当你从这个委托方法返回时，该文件将从临时存储中删除。*

####创建后台下载的操作步骤

后台传输的的实现也十分简单，简单说分为三个步骤：
1. 创建后台下载用的NSURLSession对象，设置为后台下载类型；
2. 向这个对象中加入对应的传输的NSURLSessionTask，并开始下载；
3. 在AppDelegate里实现handleEventsForBackgroundURLSession，以刷新UI及通知系统传输结束。
4. 实现NSURLSessionDownloadDelegate中必要的代理

####下面用代码来说明描述后台下载的流程
*首先，我们看下后台下载的时序图*
![后台下载时序图](http://upload-images.jianshu.io/upload_images/809937-7e5c0ffd2628c8ce.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

***具体代码实现***
1. 创建一个后台下载对象
用dispatch_once创建一个用于后台下载对象，目的是为了保证identifier的唯一，文档不建议对于相同的标识符 (identifier) 创建多个会话对象。这里创建并配置了NSURLSession，将通过backgroundSessionConfiguration其指定为后台session并设定delegate。
```
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
```

2. 向其中加入对应的传输用的NSURLSessionTask，并调用resume启动下载。
```
 - (void)beginDownloadWithUrl:(NSString *)downloadURLString {
    NSURL *downloadURL = [NSURL URLWithString:downloadURLString];
    NSURLRequest *request = [NSURLRequest requestWithURL:downloadURL];
    NSURLSession *session = [self backgroundURLSession];
    NSURLSessionDownloadTask *downloadTask = [session downloadTaskWithRequest:request];
    [downloadTask resume];
}
```

3.  在appDelegate中实现handleEventsForBackgroundURLSession，要注意的是，***需要在handleEventsForBackgroundURLSession中必须重新建立一个后台 session 的参照（可以用之前dispatch_once创建的对象），否则 
NSURLSessionDownloadDelegate 和 NSURLSessionDelegate 方法会因为没有 对 session 的 delegate 设置而不会被调用。***
然后保存completionHandler()。
```
 - (void)application:(UIApplication *)application
handleEventsForBackgroundURLSession:(NSString *)identifier 
 completionHandler:(void (^)())completionHandler {
       NSURLSession *backgroundSession = [self backgroundURLSession];
       NSLog(@"Rejoining session with identifier %@ %@", identifier, backgroundSession);
       // 保存 completion handler 以在处理 session 事件后更新 UI
       [self addCompletionHandler:completionHandler forSession:identifier];    
}
 - (void)addCompletionHandler:(CompletionHandlerType)handler 
  forSession:(NSString *)identifier {
        if ([self.completionHandlerDictionary objectForKey:identifier]) {
           NSLog(@"Error: Got multiple handlers for a single session identifier.  This should not happen.\n");
        }
        [self.completionHandlerDictionary setObject:handler forKey:identifier];
}
```
*注：handleEventsForBackgroundURLSession方法是在后台下载的所有任务完成后才会调用。如果当后台传输完成时，如果应用程序已经被杀掉，iOS将会在后台启动该应用程序，下载相关的委托方法会在 
application:didFinishLaunchingWithOptions:方法被调用之后被调用。*
4. 实现URLSessionDidFinishEventsForBackgroundURLSession，待所有数据处理完成，UI刷新之后在改方法中在调用之前保存的completionHandler()。
```
//NSURLSessionDelegate委托方法，会在NSURLSessionDownloadDelegate委托方法后执行
 - (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session {
        NSLog(@"Background URL session %@ finished events.\n", session);
        if (session.configuration.identifier) {
            // 调用在 -application:handleEventsForBackgroundURLSession: 中保存的 handler
            [self callCompletionHandlerForSession:session.configuration.identifier];
        }
}
 - (void)callCompletionHandlerForSession:(NSString *)identifier {
        CompletionHandlerType handler = [self.completionHandlerDictionary objectForKey: identifier];
        if (handler) {
           [self.completionHandlerDictionary removeObjectForKey: identifier];
           NSLog(@"Calling completion handler for session %@", identifier);
            handler();
        }
}
```
5. 在此，后台下载的基本功能已经具备了，如果还需要监听下载进度和对下载完成数据进行处理，则需要实现上面提到的委托方法
`URLSession:downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite:`和`URLSession:downloadTask:didFinishDownloadingToURL:`

####关于断点下载
对于断点下载需要考虑几个问题：
1. 如何暂停下载，暂停后，如何继续下载？
* 下载失败后，如何恢复下载？
* 应用被用户杀掉后，如何恢复之前的下载？

针对这几个问题，我们一个来分析
* 如何暂停下载，暂停后，如何继续下载？
 有两种方法
 * 第一种，使用cancelByProducingResumeData
```
    /* 对某一个NSURLSessionDownloadTask取消下载，取消后会回调给我们 resumeData，
    * resumeData包含了下载任务的一些状态，之后可以用户恢复下载
   */
   - (void)cancelByProducingResumeData:(void (^)(NSData * resumeData))completionHandler;
```
调用该方法会触发以下方法，会附带resumeData，用于恢复。
```
    - (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error 
```
对应恢复方法
```
//通过之前保存的resumeData，获取断点的NSURLSessionTask，调用resume恢复下载
NSURLSessionDownloadTask *task = [[self backgroundURLSession] downloadTaskWithResumeData:resumeData];
[task resume];
```
 * 第二种，使用NSURLSessionDownloadTask的suspend方法
```
//暂停
[self.downloadTask suspend];
//恢复
[self.downloadTask resume];
```
*通过以上的两个方法，就可以实现下载的暂停与恢复下载了*
* 下载失败后，如何恢复下载？
下载失败后，可以通过以下代码来恢复下载
```
  /* 该方法下载成功和失败都会回调，只是失败的是error是有值的，
  * 在下载失败时，error的userinfo属性可以通过NSURLSessionDownloadTaskResumeData
  * 这个key来取到resumeData(和上面的resumeData是一样的)，再通过resumeData恢复下载
  */
 - (void)URLSession:(NSURLSession *)sessiona
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {
    if (error) {
        // check if resume data are available
        if ([error.userInfo objectForKey:NSURLSessionDownloadTaskResumeData]) {
            NSData *resumeData = [error.userInfo objectForKey:NSURLSessionDownloadTaskResumeData];
            NSURLSessionTask *task = [[self backgroundURLSession] downloadTaskWithResumeData:resumeData];
            [task resume];
        }
    }
}
```
* 应用被用户杀掉后，如何恢复之前的下载？
在应用被杀掉前，iOS系统保存应用下载sesson的信息，在重新启动应用，并且创建和之前相同identifier的session时（苹果通过identifier找到对应的session数据），iOS系统会对之前下载中的任务进行依次回调`URLSession:task:didCompleteWithError:`方法，之后可以使用上面提到的*下载失败*时的处理方法进行恢复下载

知道这些后，看下前台下载的时序图对整个下载流程就了解了。
![前台下载时序图.png](http://upload-images.jianshu.io/upload_images/809937-76c08aaba0884af7.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

关于Session的生命周期，可以阅读 Apple 的[ Life Cycle of a URL Session with Custom Delegates ](https://developer.apple.com/library/ios/documentation/cocoa/Conceptual/URLLoadingSystem/NSURLSessionConcepts/NSURLSessionConcepts.html#//apple_ref/doc/uid/10000165i-CH2-SW42)文档，它讲解了所有类型的会话任务的完整生命周期。
###后台下载的配置和限制

NSURLSessionConfiguration 允许你设置默认的HTTP头，配置缓存策略，限制使用蜂窝数据等等。其中一个选项是discretionary标志，这个标志允许系统为分配任务进行性能优化。这意味着只有当设备有足够电量时，设备才通过 Wifi 进行数据传输。如果电量低，或者只仅有一个蜂窝连接，传输任务是不会运行的。后台传输总是在 discretionary模式下运行。timeoutIntervalForResource属性，支持资源超时特性。你可以使用这个特性指定你允许完成一个传输所需的最长时间。内容只在有限的时间可用，或者在用户只有有限Wifi带宽的时间内无法下载或上传资源的情况下，你也可以使用这个特性。

最后，我们来说一说使用后台会话的几个限制。作为一个必须实现的委托，您不能对NSURLSession使用简单的基于 block的回调方法。后台启动应用程序，是相对耗费较多资源的，所以总是采用HTTP重定向。后台传输服务只支持HTTP和HTTPS，你不能使用自定义的协议。系统会根据可用的资源进行优化，在任何时候你都不能强制传输任务在后台进行。

另外，要注意的是在后台会话中，NSURLSessionDataTasks 是完全不支持的，你应该只出于短期的，小请求为目的使用这些任务，而不是用来下载或上传。其中发现一些需要注意的点，记录下来。

具体详情可以见[简书](http://www.jianshu.com/p/1211cf99dfc3)
