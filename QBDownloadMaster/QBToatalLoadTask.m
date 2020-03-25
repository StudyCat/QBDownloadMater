//
//  ZZToatalLoadTaskManager.m
//  TestUI
//
//  Created by 秦彬 on 2019/1/4.
//  Copyright © 2019年 秦彬. All rights reserved.
//

#import "QBToatalLoadTask.h"
#import "QBSingleSourceDataLoadTask.h"
#import "FFileTool.h"

@implementation ZZloadTaskPramaModel

+ (instancetype)loadTaskPramaModelWithUrl:(NSString *)url filePath:(NSString *)filePath{
    ZZloadTaskPramaModel *model = [[self alloc] init];
    model.url = url;
    model.filePath = filePath;
    return model;
}

- (void)setFilePath:(NSString *)filePath{

    NSString *orignLastExtentionPath = filePath.pathExtension;
    NSString *changeLastExtentionPath = orignLastExtentionPath.lowercaseString;
    NSString *newFilePath = [filePath stringByReplacingOccurrencesOfString:orignLastExtentionPath withString:changeLastExtentionPath];
    _filePath = newFilePath;
}

@end

@interface QBToatalLoadTask (){
    NSURL *url;
}

@property (nonatomic,retain)NSArray *loadDataArr;

@property (nonatomic,retain)NSMutableArray *tasks;

@property (nonatomic,assign)unsigned long long currentDataLength;

@property (nonatomic,retain)NSMutableArray *finishArr;

@property (nonatomic)void (^peauseComplition)(void);

//@property (nonatomic,retain)dispatch_semaphore_t semaphore;
@end

@implementation QBToatalLoadTask

- (void)dealloc{
    NSLog(@"-----------主任务销毁");
}

- (instancetype)initWithLoadDataArr:(NSArray <NSDictionary *>*)loadDataArr oldTotalLoadTaskArr:(NSArray *)oldTotalLoadTaskArr{
    self = [super init];
    if (self) {
        NSArray *notHaveRepeatLoadDataArr = [self dealRepeatLoadData:loadDataArr oldTotalLoadTaskArr:oldTotalLoadTaskArr];
        self.loadDataArr = [self removeAlreadyDownloadTask:notHaveRepeatLoadDataArr];
        self.finishArr = [NSMutableArray array];
        [self initMangerArr];
//        self.semaphore = dispatch_semaphore_create(3);
    }
    return self;
}

/**
 对于自身下载任务数组的查重

 @param loadDataArr 新传入的下载任务
 @param oldTotalLoadTaskArr 之前正在下载池的任务数组
 @return 已经去除所有可能重复的下载任务数组
 */
- (NSArray *)dealRepeatLoadData:(NSArray *)loadDataArr oldTotalLoadTaskArr:(NSArray *)oldTotalLoadTaskArr{
    NSMutableArray *allloadDataArr = [NSMutableArray arrayWithArray:loadDataArr];
    NSMutableArray *arr = [NSMutableArray array];
    NSMutableArray *deleteArr = [NSMutableArray array];
    for (ZZloadTaskPramaModel *pramaModel in allloadDataArr) {
        if (![arr containsObject:pramaModel.filePath]) {
            [arr addObject:pramaModel.filePath];
        }else{
            [deleteArr addObject:pramaModel];
        }
    }
    [allloadDataArr removeObjectsInArray:deleteArr];
    return [self dealOldRepeatLoadData:allloadDataArr oldTotalLoadTaskArr:oldTotalLoadTaskArr];
}


/**
 与已在下载池的任务做查重比对

 @param loadDataArr 自身已经查重的任务数组
 @param oldTotalLoadTaskArr 已在下载池的任务数组
 @return  已经去除所有可能重复的下载任务数组
 */
- (NSArray *)dealOldRepeatLoadData:(NSArray *)loadDataArr oldTotalLoadTaskArr:(NSArray *)oldTotalLoadTaskArr{
    NSMutableArray *allloadDataArr = [NSMutableArray arrayWithArray:loadDataArr];
    NSMutableArray *oldAllLoadDataArr = [NSMutableArray array];
    NSMutableArray *deleteArr = [NSMutableArray array];
    for (QBToatalLoadTask *task in oldTotalLoadTaskArr) {
        NSArray *oldDataArr = [task valueForKey:@"loadDataArr"];
        [oldAllLoadDataArr addObjectsFromArray:oldDataArr];
    }
    for (ZZloadTaskPramaModel *newPramaModel in allloadDataArr) {
        for (ZZloadTaskPramaModel *oldPramaModel in oldAllLoadDataArr) {
            if ([newPramaModel.filePath isEqualToString:oldPramaModel.filePath]) {
                [deleteArr addObject:newPramaModel];
            }
        }
    }
    [allloadDataArr removeObjectsInArray:deleteArr];
    return allloadDataArr;
}

//移除已经下载好的任务
- (NSArray *)removeAlreadyDownloadTask:(NSArray *)taskArr{
    NSMutableArray *arr = [NSMutableArray arrayWithArray:taskArr];
    NSMutableArray *deleteArr = [NSMutableArray array];
    for (ZZloadTaskPramaModel *pramaModel in arr) {
        if ([FFileTool fileExists:pramaModel.filePath]) {
            [deleteArr addObject:pramaModel];
            self.currentDataLength += [FFileTool fileSize:pramaModel.filePath];
        }
    }
    [arr removeObjectsInArray:deleteArr];
    return arr;
}

- (void)initMangerArr{
    self.tasks = [NSMutableArray array];
    for (ZZloadTaskPramaModel *model in self.loadDataArr) {
        QBSingleSourceDataLoadTask *manager = [[QBSingleSourceDataLoadTask alloc] initWithFilePath:model.filePath url:[NSURL URLWithString:model.url]];
        self.currentDataLength += manager.alreadyDownloadLength;
        [self.tasks addObject:manager];
    }
}


- (void)startLoad{
       [self load];
}

- (void)load{
    if (!self || self.tasks.count == 0) {
        return;
    }
    for (QBSingleSourceDataLoadTask *task in self.tasks) {
        
        [self asynecLoadWithTask:task];
    }
}

- (void)asynecLoadWithTask:(QBSingleSourceDataLoadTask *)task{
    __weak __typeof(self)weakSelf = self;
//    dispatch_semaphore_wait(weakSelf.semaphore, DISPATCH_TIME_FOREVER);
    [task startDownload];
    __weak QBSingleSourceDataLoadTask *weakTask = task;
    [task setDidFinishLoad:^{
        if (!weakSelf) {
            return ;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (weakSelf.singleDataDidLoad) {
                weakSelf.singleDataDidLoad(weakTask.filePath);
            }
            [weakSelf.finishArr addObject:weakTask];
            if (weakSelf.finishArr.count == weakSelf.loadDataArr.count) {
                if (weakSelf.didComplition) {
                    weakSelf.didComplition();
                }
            }
        });
    }];
    [task setDidRecieveDataSize:^(unsigned long long recievedSize) {
        if (!weakSelf) {
            return ;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.currentDataLength += recievedSize;
            CGFloat progress = 1.0 * weakSelf.currentDataLength / weakSelf.totalSize;
            if (weakSelf.didReciveProgress) {
                weakSelf.didReciveProgress(progress);
            }
        });
    }];
    [task setFailure:^(NSError * _Nonnull error) {
        if (!weakSelf) {
            return ;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.finishArr addObject:weakTask];
            [weakSelf cancelLoad];
            if (weakSelf.finishArr.count == weakSelf.loadDataArr.count) {
                if (self.peauseComplition) {
                    self.peauseComplition();
                }else{
                    weakSelf.failure(error);
                }
                
                NSLog(@"已完成下载数量%ld",weakSelf.finishArr.count);
            }
        });
    }];
}

- (void)cancelLoad{
    for (QBSingleSourceDataLoadTask *task in self.tasks) {
        [task peause];
//        dispatch_semaphore_signal(self.semaphore);
    }
}


- (void)peauseComplition:(void (^)(void))complition{
    for (QBSingleSourceDataLoadTask *task in self.tasks) {
        [task peause];
//        dispatch_semaphore_signal(self.semaphore);
    }
    self.peauseComplition = complition;
}

@end
