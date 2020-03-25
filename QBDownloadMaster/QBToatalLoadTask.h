//
//  ZZToatalLoadTaskManager.h
//  TestUI
//
//  Created by 秦彬 on 2019/1/4.
//  Copyright © 2019年 秦彬. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZZloadTaskPramaModel : NSObject

@property (nonatomic,copy)NSString *url;

@property (nonatomic,copy)NSString *filePath;

@property (nonatomic,assign)unsigned long long size;

+ (instancetype)loadTaskPramaModelWithUrl:(NSString *)url filePath:(NSString *)filePath;

@end

@interface QBToatalLoadTask : NSObject
@property (nonatomic,retain)NSString *taskId;


/// 新建下载任务组，做了查重处理
/// @param loadDataArr 需要下载的任务数组
/// @param oldTotalLoadTaskArr 现在正在下载的任务数组
- (instancetype)initWithLoadDataArr:(NSArray <ZZloadTaskPramaModel *>*)loadDataArr oldTotalLoadTaskArr:(NSArray <ZZloadTaskPramaModel *>*)oldTotalLoadTaskArr;

@property (nonatomic,assign)long long totalSize;

- (void)startLoad;

- (void)peauseComplition:(void (^)(void))complition;

- (void)cancelLoad;

@property (nonatomic)void (^singleDataDidLoad)(NSString *filePath);

@property (nonatomic)void (^didReciveProgress)(CGFloat gropressFloat);

@property (nonatomic)void (^didComplition)(void);

@property (nonatomic)void (^failure)(NSError *error);
@end

NS_ASSUME_NONNULL_END
