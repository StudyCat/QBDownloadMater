//
//  ZZSingleSourceDataLoadManager.m
//  TestUI
//
//  Created by 秦彬 on 2019/1/4.
//  Copyright © 2019年 秦彬. All rights reserved.
//

#import "QBSingleSourceDataLoadTask.h"
#import "FFileTool.h"

@interface QBSingleSourceDataLoadTask ()<NSURLSessionDelegate, NSURLSessionDataDelegate, NSURLSessionTaskDelegate>{
    long long _tmpSize;
    long long _totalSize;
}
@property (nonatomic,retain)NSURL *url;

@property (nonatomic,retain)NSURLRequest *request;

@property (nonatomic,retain)NSOutputStream *outputStream;

@property (nonatomic,retain)NSURLSession *session;

@property (nonatomic,retain)NSURLSessionDataTask *downloadTask;

@property (nonatomic,retain)NSData *fileData;

@property (nonatomic,assign)BOOL isLoading;

@property (nonatomic,copy)NSString *loadingFilePath;

@end
@implementation QBSingleSourceDataLoadTask


- (void)dealloc{
    [self.session resetWithCompletionHandler:^{
        
        NSLog(@"释放---");
    }];
}

- (instancetype)initWithFilePath:(NSString *)filePath url:(NSURL *)url{
    self = [super init];
    if (self) {
        self.url = url;
//        self.lock = dispatch_semaphore_create(0);
        self.filePath = filePath;
        NSString *fileName = [filePath stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%@/Documents/",NSHomeDirectory()] withString:@""];
        NSString *fileNameStr = [filePath stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@".%@",fileName.pathExtension] withString:@""];
        NSArray *fileNameArr = [fileNameStr componentsSeparatedByString:@"/"];
        NSString *uuidStr;
        for (NSString *str in fileNameArr) {
            if ([self isPureInt:str]) {
                uuidStr = str;
                break;
            }
        }
        NSString *floderPath = [self createTmpFloderWithUuidStr:uuidStr];
        self.loadingFilePath = [NSString stringWithFormat:@"%@/%@",floderPath,filePath.lastPathComponent];
        
    }
    return self;
}

- (BOOL)isPureInt:(NSString*)string{
    NSScanner* scan = [NSScanner scannerWithString:string];
    int val;
    return[scan scanInt:&val] && [scan isAtEnd];
}


- (NSString *)createTmpFloderWithUuidStr:(NSString *)uuidStr{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *path = [NSString stringWithFormat:@"%@/tmp/%@",NSHomeDirectory(),uuidStr];
    BOOL isDir = NO;
    BOOL existed = [fileManager fileExistsAtPath:path isDirectory:&isDir];
    if ( !(isDir == YES && existed == YES) ) {//如果文件夹不存在
        [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return path;
}


- (void)startDownload{
//    if (self) {
    if ([FFileTool fileExists:self.filePath]) {
        if (self.didFinishLoad) {
            self.didFinishLoad();
        }
    }
    unsigned long long dataLength = 0;
    _tmpSize = 0;
    if ([FFileTool fileExists:self.loadingFilePath]) {
        [FFileTool removeFile:self.loadingFilePath];
    }
    self.session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[NSOperationQueue new]];
        // 创建请求
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.url];
        // 设置请求头
        // Range : bytes=xxx-xxx
    NSString *range = [NSString stringWithFormat:@"bytes=%llu-", dataLength];
    [request setValue:range forHTTPHeaderField:@"Range"];
    self.downloadTask = [self.session dataTaskWithRequest:request];
        
    [self.downloadTask resume];
        
//        self.isLoading = YES;
//    }
//    [self.downloadTast]
    
}

- (void)peause{
    if (self) {
        NSLog(@"暂停了");
        [self.session invalidateAndCancel];
        self.session = nil;
        
//        self.isLoading = NO;
    }
}


#pragma mark -NSURLSessionDelegate
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    NSHTTPURLResponse *httpUrlResponse = (NSHTTPURLResponse *)response;
    _totalSize = [httpUrlResponse.allHeaderFields[@"Content-Length"]longLongValue];
    NSString *contentRangeStr = httpUrlResponse.allHeaderFields[@"content-range"];
    if (contentRangeStr.length != 0) {
        _totalSize  =   [[contentRangeStr componentsSeparatedByString:@"/"].lastObject longLongValue];
    }

    //比对本地大小和总大小
    // 2.2.2.1 本地大小 == 总大小 ==>> 移动到下载完成的路径中.
    if (_tmpSize == _totalSize) {
        // 1.移动到下载完成文件夹
        [FFileTool moveFile:self.loadingFilePath toPath:self.filePath];
        // 2.取消本次请求
        completionHandler(NSURLSessionResponseCancel);
        if (self.didRecieveDataSize) {
            self.didRecieveDataSize(_tmpSize);
        }
        // 3.修改状态
        if (self.didFinishLoad) {
            self.didFinishLoad();
        }
        
        return;
    }
    // 2.2.2.2 本地大小 > 总大小  ==>> 删除本地临时缓存(因为此时缓存中是错误的)，从0字节开始下载.
    if (_tmpSize > _totalSize) {
        // 1.删除临时缓存
        [FFileTool removeFile:self.loadingFilePath];
        // 2.取消本次请求
        completionHandler(NSURLSessionResponseCancel);
        // 3.从0开始下载
        [self startDownload];
        // [self downLoadWithURL:url offset:0]; 如果删除失败,会出现继续往错误的缓存中追加数据的操作.
        return;
    }
    // 2.2.2.3 本地大小 < 总大小  ==>>  从本地大小开始下载.
    self.outputStream = [[NSOutputStream alloc] initToFileAtPath:self.loadingFilePath append:YES];
    [self.outputStream open];
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data{
//     NSLog(@"接收到数据的的时候调用 -- %@ 正在下载", [NSThread currentThread]);
//    if (self) {
        [self.outputStream write:data.bytes maxLength:data.length];
        //累加已经下载的文件数据大小
        if (self.didRecieveDataSize) {
            self.didRecieveDataSize(data.length);
        }
//    }
}


- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error{
    
    NSLog(@"接收到服务器响应的时候调用 -- %@ 结束任务", [NSThread currentThread]);
    
//    dispatch_semaphore_signal(self.lock);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.outputStream close];
        
        //    error = [NSError new];
        if (!error) {
            long long fileSize = [FFileTool fileSize:self.loadingFilePath];
#warning because response not have MD5 string to juge the file is compelete，so we only use the file size to juge the file is complete now,when we have MD5 string we can change it
            if (fileSize == _totalSize) {
                [FFileTool moveFile:self.loadingFilePath toPath:self.filePath];
                if (self.didFinishLoad) {
                    self.didFinishLoad();
                }
            }else{
                [FFileTool removeFile:self.loadingFilePath];
                if (self.failure) {
                    NSError *error = [NSError errorWithDomain:NSStringFromClass(self.class) code:1000 userInfo:@{NSLocalizedFailureReasonErrorKey : @"文件验证失败"}];
                    self.failure(error);
                }
            }
        }else{
            if (error.code  == -999) {
                if (self.failure) {
                    self.failure(error);
                }
            }else{
                if (self.failure) {
                    self.failure(error);
                }
            }
        }
    });
}

- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session{
    NSLog(@"停止接受任务");
}



@end
