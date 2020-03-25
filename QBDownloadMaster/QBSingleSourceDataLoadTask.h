//
//  ZZSingleSourceDataLoadManager.h
//  TestUI
//
//  Created by 秦彬 on 2019/1/4.
//  Copyright © 2019年 秦彬. All rights reserved.
//

#import <Foundation/Foundation.h>
#define ZZFailureLoadNotithfaction @"failureLoadNotithfactionName"

NS_ASSUME_NONNULL_BEGIN

@interface QBSingleSourceDataLoadTask : NSObject

- (instancetype)initWithFilePath:(NSString *)filePath url:(NSURL *)url;

- (void)startDownload;

- (void)peause;

- (void)cancel;

@property (nonatomic,copy)NSString *singleTaskId;

@property (nonatomic,copy)NSString *filePath;

@property (nonatomic,assign)unsigned long long alreadyDownloadLength;

@property (nonatomic)void (^failure)(NSError *error);

@property (nonatomic)void (^didFinishLoad)(void);

@property (nonatomic)void (^didRecieveDataSize)(unsigned long long recievedSize);

@end

NS_ASSUME_NONNULL_END
