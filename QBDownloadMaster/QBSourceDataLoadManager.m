//
//  ZZSourceDataLoadManager.m
//  ZZOnlineDressupMall
//
//  Created by 秦彬 on 2019/1/24.
//  Copyright © 2019年 wangshaosheng. All rights reserved.
//

#import "ZZSourceDataLoadManager.h"
#import "ZZGetBodyListRequest.h"
#import "ZZToatalLoadTask.h"
#import "ZZJoinInBasketReqeust.h"
#import "ZZSingleSourceDataLoadTask.h"
#import "ZZDIYDesignModelManager.h"
#import "ZZHomePageSelectClothModelManager.h"
#import <objc/runtime.h>

typedef void (^hairComplitionCallback)(NSString *hairId);
@implementation ZZSourceDataLoadManager

static ZZSourceDataLoadManager *dataManager;
+ (instancetype)sharedInstance{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dataManager = [[self alloc] init];
    });
    
    return dataManager;
}

- (instancetype)init{
    self = [super init];
    if (self) {
        self.loadTaskArr = [NSMutableArray array];
    }
    return self;
}

- (void)cancelAllDownload{
    for (ZZToatalLoadTask *totalTask in self.loadTaskArr) {
        [totalTask cancelLoad];
    }
    [self.loadTaskArr removeAllObjects];
    
    objc_removeAssociatedObjects(self);
}


- (BOOL)isLoadBodyModelWithBodyId:(NSString *)bodyId{
    for (ZZBodyPathModel *pathModel in [ZZSourceDataDBManager sharedInstance].allBodyDataArr) {
        if ([pathModel.bodyId isEqualToString:bodyId]) {
            return YES;
        }
    }
    return NO;
}

- (void)loadDataWithBodyModel:(ZZNetBodyModel *)bodyModel progress:(void (^)(CGFloat progress))progress complition:(void (^)(NSString *modelId))complition failure:(void (^)(NSError *error))failure{
    NSArray *taskIdStrArr = [self.loadTaskArr valueForKey:@"taskId"];
    ZZToatalLoadTask *task;
    NSString *floderPath = [self createBodyFloderWithUuid:bodyModel.uuid];
    if (![taskIdStrArr containsObject:bodyModel.uuid]) {
        NSArray *taskPramaArr = @[[ZZloadTaskPramaModel loadTaskPramaModelWithUrl:bodyModel.jointsPath.fileUrl filePath:[NSString stringWithFormat:@"%@/body.obj",floderPath]],[ZZloadTaskPramaModel loadTaskPramaModelWithUrl:bodyModel.bddmFile.bd.fileUrl filePath:[NSString stringWithFormat:@"%@/body.bd",floderPath]],[ZZloadTaskPramaModel loadTaskPramaModelWithUrl:bodyModel.bddmFile.dm.fileUrl filePath:[NSString stringWithFormat:@"%@/body.dm",floderPath]],[ZZloadTaskPramaModel loadTaskPramaModelWithUrl:bodyModel.stickersPath.fileUrl filePath:[NSString stringWithFormat:@"%@/body.jpg",floderPath]]];
        task = [[ZZToatalLoadTask alloc] initWithLoadDataArr:taskPramaArr oldTotalLoadTaskArr:self.loadTaskArr];
        long long totalSize = bodyModel.modelPath.personImageSize.longLongValue + bodyModel.bddmFile.bd.personImageSize.longLongValue + bodyModel.bddmFile.dm.personImageSize.longLongValue + bodyModel.stickersPath.personImageSize.longLongValue;
        task.totalSize = totalSize;
        task.taskId = bodyModel.uuid;
        [[self mutableArrayValueForKey:@"loadTaskArr"] addObject:task];
    }else{
        for (ZZToatalLoadTask *subTask in self.loadTaskArr) {
            if ([subTask.taskId isEqualToString:bodyModel.uuid]) {
                task = subTask;
                break;
            }
        }
    }
    [task startLoad];
    WS(weakSelf)
    __weak ZZToatalLoadTask *weakTask = task;
    [task setDidReciveProgress:^(CGFloat gropressFloat) {
        dispatch_async(dispatch_get_main_queue(), ^{
            progress(gropressFloat);
        });
    }];
    [task setDidComplition:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong ZZToatalLoadTask *strongTask = weakTask;
            [weakSelf.loadTaskArr removeObject:strongTask];
            strongTask = nil;
            ZZBodyPathModel *pathModel = [ZZBodyPathModel new];
            pathModel.bodyPath = [NSString stringWithFormat:@"Documents/Body/%@",bodyModel.uuid];
            pathModel.bodyId = bodyModel.uuid;
            [[ZZSourceDataDBManager sharedInstance] insertBodyModel:pathModel];
            complition(bodyModel.uuid);
        });
    }];
    [task setFailure:^(NSError * _Nonnull error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong ZZToatalLoadTask *strongTask = weakTask;
//            [strongTask peauseComplition:^{
            [weakSelf.loadTaskArr removeObject:strongTask];
            strongTask = nil;
            failure(error);
//            }];
        });
    }];
}

- (void)peauseWithBodyModel:(ZZNetBodyModel *)bodyModel complition:(void(^)(void))complition{
    ZZToatalLoadTask *task;
    for (ZZToatalLoadTask *subTask in self.loadTaskArr) {
        if ([subTask.taskId isEqualToString:bodyModel.uuid]) {
            task = subTask;
            break;
        }
    }
    if (task) {
        WS(weakSelf)
        __weak ZZToatalLoadTask *weakTask = task;
        [task peauseComplition:^{
            __strong ZZToatalLoadTask *strongTask = weakTask;
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf.loadTaskArr removeObject:strongTask];
                complition();
            });
        }];
    }
}


- (NSArray *)downloadIdArray{
    return [self.loadTaskArr valueForKey:@"taskId"];
}

- (void)loadDataWithClothModel:(ZZClothDownloadModel *)clothModel progress:(void (^)(CGFloat progress))progress complition:(void (^)(NSString *modelId))complition failure:(void (^)(NSError *error))failure{
    NSArray *taskIdStrArr = [self.loadTaskArr valueForKey:@"taskId"];
    ZZToatalLoadTask *task;
    if (![taskIdStrArr containsObject:clothModel.clothID]) {
        NSArray *taskPramaArr = [self getClothloadTaskInfoWithClothModel:clothModel];
        task = [[ZZToatalLoadTask alloc] initWithLoadDataArr:taskPramaArr oldTotalLoadTaskArr:self.loadTaskArr];
        unsigned long long totalSize = 0;
        for (ZZloadTaskPramaModel *prama in taskPramaArr) {
            totalSize += prama.size;
        }
        task.totalSize = totalSize;
        task.taskId = clothModel.clothID;
        [[self mutableArrayValueForKey:@"loadTaskArr"] addObject:task];
    }else{
        for (ZZToatalLoadTask *subTask in self.loadTaskArr) {
            if ([subTask.taskId isEqualToString:clothModel.clothID]) {
                task = subTask;
                break;
            }
            
        }
    }
    [task startLoad];
    
    WS(weakSelf)
    __weak ZZToatalLoadTask *weakTask = task;
    [task setDidReciveProgress:^(CGFloat gropressFloat) {
        dispatch_async(dispatch_get_main_queue(), ^{
            progress(gropressFloat);
        });
    }];
    [task setDidComplition:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong ZZToatalLoadTask *strongTask = weakTask;
            [weakSelf.loadTaskArr removeObject:strongTask];
            strongTask = nil;
            [weakSelf insertClothModelInDataBase:clothModel];
            complition(clothModel.clothID);
        });
    }];
    [task setFailure:^(NSError * _Nonnull error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong ZZToatalLoadTask *strongTask = weakTask;
            [weakSelf.loadTaskArr removeObject:strongTask];
            strongTask = nil;
            failure(error);
        });
    }];
}

- (void)peauseWithClothModel:(ZZClothDownloadModel *)clothModel complition:(void(^)(void))complition{
    ZZToatalLoadTask *task;
    NSString *uuid = clothModel.worksId.length > 0 ? clothModel.worksId : clothModel.clothID;
    for (ZZToatalLoadTask *subTask in self.loadTaskArr) {
        if ([subTask.taskId isEqualToString:uuid]) {
            task = subTask;
            break;
        }
    }
    if (task) {
        WS(weakSelf)
        __weak ZZToatalLoadTask *weakTask = task;
        [task peauseComplition:^{
            __strong ZZToatalLoadTask *strongTask = weakTask;
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf.loadTaskArr removeObject:strongTask];
                complition();
            });
        }];
    }
}

- (BOOL)isLoadClothModelWithBodyId:(NSString *)clothId{
    for (ZZClothPathModel *clothModel in [ZZSourceDataDBManager sharedInstance].allClothDataArr) {
        if ([clothModel.clothId isEqualToString:clothId]) {
            return YES;
        }
    }
    return NO;
}

- (void)insertCreateWorksInDataBase:(NSDictionary *)worksDic worksId:(NSString *)worksId materInfoArr:(NSArray <ZZSaveMaterOrBucklePramaModel *>*)materInfoArr partInfoArr:(NSArray *)partInfo accInfoArr:(NSArray *)accInfoArr defaultAccess:(NSArray *)defaultAccess{
    ZZClothPathModel *clothPathModel = [[ZZClothPathModel alloc] init];
    clothPathModel.clothId = worksId;
    clothPathModel.clothLprjPath = @"";
    NSString *uuid;
    NSString *pastWorksId = [worksDic objectForKey:@"worksUuid"];
    if (pastWorksId.length > 0) {
        uuid = pastWorksId;
    }else{
        uuid = [worksDic objectForKey:@"goodsUuid"];
    }
    [self copyLprjFileWithPastId:uuid uuid:worksId];
    
    NSMutableArray *buttonArr = [NSMutableArray array];
    for (ZZClothDownloadModelAccessoriesInfo *dic in accInfoArr) {
        NSDictionary *accDic = [dic modelToJSONObject];
        [buttonArr addObject:accDic];
    }
    clothPathModel.button = buttonArr;
    
    NSArray *specialArr = [worksDic objectForKey:@"dyeing"];
    NSMutableArray *specialTechArr = [NSMutableArray array];
    for (NSDictionary *dic in specialArr) {
        NSMutableDictionary *singleSpecalTechDic = [NSMutableDictionary dictionaryWithDictionary:dic];
        [singleSpecalTechDic setObject:[dic objectForKey:@"resId"] forKey:@"dyeingUuid"];
        [singleSpecalTechDic setObject:[dic objectForKey:@"resPath"] forKey:@"filePath"];
        [specialTechArr addObject:singleSpecalTechDic];
    }
    clothPathModel.specialTechs = specialTechArr;
    
    NSMutableArray *fabfricArr = [NSMutableArray array];
    for (ZZDetailMaterielModel *model in materInfoArr) {
        NSDictionary *dic = [model modelToJSONObject];
        [fabfricArr addObject:dic];
    }
    clothPathModel.fabfric = fabfricArr;
    
    NSMutableArray *parCodeAry = [NSMutableArray array];
    for (ZZClothDownloadPartInfoModel *partModel in partInfo) {
        NSDictionary *partDic = [partModel modelToJSONObject];
        [parCodeAry addObject:partDic];
    }
    clothPathModel.parCodeAry = parCodeAry;
    
    clothPathModel.defaultAccessoriesList = defaultAccess;
    
    [[ZZSourceDataDBManager sharedInstance] insertClothModel:clothPathModel];
}

- (void)copyLprjFileWithPastId:(NSString *)pastId uuid:(NSString *)uuid{
    NSString *pastFielPath = [NSString stringWithFormat:@"%@/Documents/Cloth/%@/cloth.lprj",NSHomeDirectory(),pastId];
    if ([[NSFileManager defaultManager] fileExistsAtPath:pastFielPath]) {
        NSString *newFloderPath = [self createClothFloderWithUuid:uuid];
        NSString *newPath = [NSString stringWithFormat:@"%@/cloth.lprj",newFloderPath];
        [[NSFileManager defaultManager] copyItemAtPath:pastFielPath toPath:newPath error:nil];
    }
}

- (void)insertBatchClothArrInDataBase:(NSArray *)clothArr{
    for (ZZClothDownloadModel *clothModel in clothArr) {
        [self insertClothModelInDataBase:clothModel];
    }
}

- (void)insertClothModelInDataBase:(ZZClothDownloadModel *)clothModel{
    ZZClothPathModel *clothPathModel = [[ZZClothPathModel alloc] init];
    clothPathModel.clothLprjPath = [NSString stringWithFormat:@"%@/cloth.lprj",[self createClothFloderWithUuid:clothModel.clothID]];
    if (clothModel.worksId.length > 0) {
        clothPathModel.clothId  = clothModel.worksId;
    }else{
        clothPathModel.clothId  = clothModel.clothID;
    }
    
    NSMutableArray *partArr = [NSMutableArray array];
    for (ZZClothDownloadGroupPartInfoModel *groupModel in clothModel.parCodeAry) {
        for (ZZClothDownloadPartInfoModel *partInfo in groupModel.partReplaceReqs) {
            NSDictionary *dic = [partInfo modelToJSONObject];
            [partArr addObject:dic];
        }
    }
    clothPathModel.parCodeAry = partArr;
    
    NSMutableArray *FabricArr = [NSMutableArray array];
    for (ZZDetailMallMaterielGroupRespModel *groupInfoModel in clothModel.materGroupList) {
        for (ZZDetailMaterielModel *detailMater in groupInfoModel.materialDetailList) {
            NSDictionary *dic = [detailMater modelToJSONObject];
            [FabricArr addObject:dic];
        }
    }
    clothPathModel.fabfric = FabricArr;
    
    NSMutableArray *buttonArr = [NSMutableArray array];
    for (ZZClothDownloadModelGroupAccessoriesInfo *groupInfoModel in clothModel.accessoriesGroupList) {
        for (ZZClothDownloadModelAccessoriesInfo *detailAccInfo in groupInfoModel.accessoriesList) {
            NSDictionary *dic = [detailAccInfo modelToJSONObject];
            [buttonArr addObject:dic];
        }
    }
    clothPathModel.button = buttonArr;
    
    NSMutableArray *specialTechArr = [NSMutableArray array];
    for (ZZSpecialTechNetGroupModel *groupModel in clothModel.dyeingPattern) {
        for (ZZSpecialTechNetModel *model in groupModel.printingDTOList) {
            NSDictionary *dic = [model modelToJSONObject];
            [specialTechArr addObject:dic];
        }
    }
    
    NSMutableArray *defaultACCAry = [NSMutableArray array];
    for (ZZClothDownloadPartBindingModel *downloadModel in clothModel.defaultAccessoriesList) {
        NSDictionary *dic = [downloadModel modelToJSONObject];
        [defaultACCAry addObject:dic];
    }
    clothPathModel.defaultAccessoriesList = defaultACCAry;
    
    clothPathModel.specialTechs = specialTechArr;
    [[ZZSourceDataDBManager sharedInstance] insertClothModel:clothPathModel];
}

//获取批量衣服下载
- (NSArray *)getBatchClothloadTaskInfoWithArr:(NSArray <ZZClothDownloadModel *>*)clothDownloadArr wearId:(NSString *)wearId wearModelPath:(NSString *)wearModelPath wearModelSize:(NSString *)wearModelSize {
    NSMutableArray *loadInfoArr = [NSMutableArray array];
    for (ZZClothDownloadModel *downloadModel in clothDownloadArr) {
        NSArray *arr = [self getClothloadTaskInfoWithClothModel:downloadModel];
        [loadInfoArr addObjectsFromArray:arr];
    }
    NSMutableArray *result = [NSMutableArray array];
    for (ZZloadTaskPramaModel *pramaModel in loadInfoArr) {
        NSArray *urlArr = [result valueForKey:@"filePath"];
        if (![urlArr containsObject:pramaModel.filePath]) {
            [result addObject:pramaModel];
        }
    }
    if (wearModelPath.length > 0) {
        NSString *filePath = [NSString stringWithFormat:@"%@/Documents/Wear/%@.%@",NSHomeDirectory(),wearId,wearModelPath.pathExtension];
        ZZloadTaskPramaModel *wearModeParam = [ZZloadTaskPramaModel loadTaskPramaModelWithUrl:wearModelPath filePath:filePath];
        wearModeParam.size = wearModelSize.longLongValue;
        [result addObject:wearModeParam];
    }
    return result;
}

- (NSArray *)getClothloadTaskInfoWithClothModel:(ZZClothDownloadModel *)clothModel{
    NSMutableArray *loadInfoArr = [NSMutableArray array];
    NSString *clothId;
    if (clothModel.worksId.length > 0) {
        clothId = clothModel.worksId;
    }else{
        clothId = clothModel.clothID;
    }
    NSString *lprjFloder = [NSString stringWithFormat:@"%@/cloth.lprj",[self createClothFloderWithUuid:clothId]];
    ZZloadTaskPramaModel *lprjPrama = [ZZloadTaskPramaModel loadTaskPramaModelWithUrl:clothModel.clothLprjPath filePath:lprjFloder];
    
    if (clothModel.appModelFile.length > 0) {
        NSString *modePath = [NSString stringWithFormat:@"%@/cloth.mode",[self createClothFloderWithUuid:clothId]];
        ZZloadTaskPramaModel *modeParama = [ZZloadTaskPramaModel loadTaskPramaModelWithUrl:clothModel.appModelFile filePath:modePath];
        [loadInfoArr addObject:modeParama];
    }
    
    lprjPrama.size = clothModel.size.longLongValue;
    [loadInfoArr addObject:lprjPrama];
    [loadInfoArr addObjectsFromArray:[self createFabricLoadPram:clothModel.materGroupList]];
    [loadInfoArr addObjectsFromArray:[self createBuckleLoadPrama:clothModel.accessoriesGroupList]];
    [loadInfoArr addObjectsFromArray:[self createPartBindingDataLoadPrama:clothModel.parCodeAry]];
    [loadInfoArr addObjectsFromArray:[self createSpecialTechLoadPrama:clothModel.dyeingPattern]];
    [loadInfoArr addObjectsFromArray:[self createAssistBindingMaterDataLoadPrama:clothModel.materGroupList]];
    [loadInfoArr addObjectsFromArray:[self createDefaultAccessoriseDataLoadPrama:clothModel.defaultAccessoriesList]];
    
    NSMutableArray *result = [NSMutableArray array];
    for (ZZloadTaskPramaModel *pramaModel in loadInfoArr) {
        NSArray *urlArr = [result valueForKey:@"filePath"];
        if (![urlArr containsObject:pramaModel.filePath]) {
            [result addObject:pramaModel];
        }
    }
    return result;
}

- (NSArray *)createDefaultAccessoriseDataLoadPrama:(NSArray *)accArr{
    NSMutableArray *arr = [NSMutableArray array];
    for (ZZClothDownloadPartBindingModel *bindingModel in accArr) {
        if (bindingModel.resType.intValue == 4) {
            NSString * filePath = [NSString stringWithFormat:@"%@/%@.%@",self.getSpecialTechFloderPath,bindingModel.resourceUuid,bindingModel.filePath.pathExtension];
            if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
                ZZloadTaskPramaModel *fabricPrama = [ZZloadTaskPramaModel loadTaskPramaModelWithUrl:bindingModel.filePath filePath:filePath];
                fabricPrama.size = bindingModel.fileSize.longLongValue;
                [arr addObject:fabricPrama];
            }
        }else{
            NSString *fileRootPath = [self getBuckleFloderPathWithResId:bindingModel.resourceUuid];
            if (bindingModel.modelPath.length > 0) {
                NSString *modelPath = [NSString stringWithFormat:@"%@/modelPath.%@",fileRootPath,bindingModel.modelPath.pathExtension.lowercaseString];
                ZZloadTaskPramaModel *modelPathPrama = [ZZloadTaskPramaModel loadTaskPramaModelWithUrl:bindingModel.modelPath filePath:modelPath];
                modelPathPrama.size = bindingModel.modelPathSize.longLongValue;
                [arr addObject:modelPathPrama];
            }
            NSString *filePath = [NSString stringWithFormat:@"%@/file.%@",fileRootPath,bindingModel.filePath.pathExtension.lowercaseString];
            ZZloadTaskPramaModel *filePrama = [ZZloadTaskPramaModel loadTaskPramaModelWithUrl:bindingModel.filePath filePath:filePath];
            filePrama.size = bindingModel.fileSize.longLongValue;
            [arr addObject:filePrama];
        }
    }
    return arr;
}

- (NSArray *)createAssistBindingMaterDataLoadPrama:(NSArray *)materArr{
    NSMutableArray *arr = [NSMutableArray array];
    for (ZZDetailMallMaterielGroupRespModel *groupMaterInfoModel in materArr) {
        for (ZZDetailMaterielModel *materModel in groupMaterInfoModel.materialDetailList) {
            for (ZZClothDownloadAssistBindingMaterModel *bindingModel in materModel.bindingList) {
                NSString *fileRootPath = [self getBuckleFloderPathWithResId:bindingModel.assistResId];
                NSString *filePath = [NSString stringWithFormat:@"%@/file.%@",fileRootPath,bindingModel.assistResFilePath.pathExtension.lowercaseString];
                if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
                    ZZloadTaskPramaModel *fabricPrama = [ZZloadTaskPramaModel loadTaskPramaModelWithUrl:bindingModel.assistResFilePath filePath:filePath];
                    fabricPrama.size = bindingModel.assistResSize.longLongValue;
                    [arr addObject:fabricPrama];
                }
            }
        }
    }
    return arr;
}

- (NSArray *)createPartBindingDataLoadPrama:(NSArray *)partArr{
    NSMutableArray *arr = [NSMutableArray array];
    for (ZZClothDownloadGroupPartInfoModel *groupPartInfoModel in partArr) {
        for (ZZClothDownloadPartInfoModel *partModel in groupPartInfoModel.partReplaceReqs) {
            for (ZZClothDownloadPartBindingModel *bindingModel in partModel.bindingList) {
                if (bindingModel.resType.intValue == 4) {
                    NSString *filePath = [NSString stringWithFormat:@"%@/%@.%@",self.getSpecialTechFloderPath,bindingModel.resourceUuid,bindingModel.filePath.pathExtension];
                    if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
                        ZZloadTaskPramaModel *fabricPrama = [ZZloadTaskPramaModel loadTaskPramaModelWithUrl:bindingModel.filePath filePath:filePath];
                        fabricPrama.size = bindingModel.fileSize.longLongValue;
                        [arr addObject:fabricPrama];
                    }
                }else{
                    NSString *fileRootPath = [self getBuckleFloderPathWithResId:bindingModel.resourceUuid];
                    if (bindingModel.modelPath.length > 0) {
                        NSString *modelPath = [NSString stringWithFormat:@"%@/modelPath.%@",fileRootPath,bindingModel.modelPath.pathExtension.lowercaseString];
                        ZZloadTaskPramaModel *modelPathPrama = [ZZloadTaskPramaModel loadTaskPramaModelWithUrl:bindingModel.modelPath filePath:modelPath];
                        modelPathPrama.size = bindingModel.modelPathSize.longLongValue;
                        [arr addObject:modelPathPrama];
                    }
                    NSString *filePath = [NSString stringWithFormat:@"%@/file.%@",fileRootPath,bindingModel.filePath.pathExtension.lowercaseString];
                    ZZloadTaskPramaModel *filePrama = [ZZloadTaskPramaModel loadTaskPramaModelWithUrl:bindingModel.filePath filePath:filePath];
                    filePrama.size = bindingModel.fileSize.longLongValue;
                    [arr addObject:filePrama];
                }
            }
        }
    }
    return arr;
}

- (NSArray *)createFabricLoadPram:(NSArray *)FabricArr{
    NSMutableArray *arr = [NSMutableArray array];
    for (ZZDetailMallMaterielGroupRespModel *groupFabricInfoModel in FabricArr) {
        for (ZZDetailMaterielModel *fabricInfoModel in groupFabricInfoModel.materialDetailList) {
            NSString *filePath = [NSString stringWithFormat:@"%@/%@.%@",self.getFabricFloderPath,fabricInfoModel.materialImageUuid,fabricInfoModel.filePathApp.pathExtension];
            if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
                ZZloadTaskPramaModel *fabricPrama = [ZZloadTaskPramaModel loadTaskPramaModelWithUrl:fabricInfoModel.filePathApp filePath:filePath];
                fabricPrama.size = fabricInfoModel.fileSize.longLongValue;
                [arr addObject:fabricPrama];
            }
        }
    }
    return arr;
}

//- (NSArray *)create

- (NSArray *)createBuckleLoadPrama:(NSArray *)accessoriesArr{
    NSMutableArray *arr = [NSMutableArray array];
    for (ZZClothDownloadModelGroupAccessoriesInfo *groupAccessoriesInfoModel in accessoriesArr) {
        for (ZZClothDownloadModelAccessoriesInfo *accessoriesInfoModel in groupAccessoriesInfoModel.accessoriesList) {
            if (accessoriesInfoModel.isDefault.boolValue == YES) {
                NSString *fileRootPath = [self getBuckleFloderPathWithResId:accessoriesInfoModel.materialImageUuid];
                if (accessoriesInfoModel.modelPathApp.length > 0) {
                    NSString *modelPath = [NSString stringWithFormat:@"%@/modelPath.%@",fileRootPath,accessoriesInfoModel.modelPathApp.pathExtension.lowercaseString];
                    ZZloadTaskPramaModel *modelPathPrama = [ZZloadTaskPramaModel loadTaskPramaModelWithUrl:accessoriesInfoModel.modelPathApp filePath:modelPath];
                    [arr addObject:modelPathPrama];
                }
                NSString *filePath = [NSString stringWithFormat:@"%@/file.%@",fileRootPath,accessoriesInfoModel.filePathApp.pathExtension.lowercaseString];
                ZZloadTaskPramaModel *filePrama = [ZZloadTaskPramaModel loadTaskPramaModelWithUrl:accessoriesInfoModel.filePathApp filePath:filePath];
                filePrama.size = accessoriesInfoModel.size.longLongValue;
                [arr addObject:filePrama];
            }
        }
    }
    return arr;
}

- (NSArray *)createSpecialTechLoadPrama:(NSArray *)specialTechArr{
    NSMutableArray *arr = [NSMutableArray array];
    for (ZZSpecialTechNetGroupModel *groupModel in specialTechArr) {
        for (ZZSpecialTechNetModel *model in groupModel.printingDTOList) {
            NSString *filePath = [NSString stringWithFormat:@"%@/%@.%@",self.getSpecialTechFloderPath,model.dyeingUuid,model.filePath.pathExtension];
            if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
                ZZloadTaskPramaModel *bucklePrama = [ZZloadTaskPramaModel loadTaskPramaModelWithUrl:model.filePath filePath:filePath];
                bucklePrama.size = model.fileSize.longLongValue;
                [arr addObject:bucklePrama];
            }
        }
    }
    return arr;
}

#pragma mark - 批量下载衣服(穿搭)

- (void)isWearDownloadWithDetailWearModel:(ZZDetailWearModel *)detailWearModel result:(void (^)(BOOL isClothDownload,NSArray <ZZGetBatchClothDownloadInfoPramaModel *>*notLoadAry,BOOL isWearModelDownload))result{
    BOOL isDownload = YES;
    NSMutableArray *notLoadAry = [NSMutableArray array];
    for (ZZDetailWearGoodsModel *goodsModel in detailWearModel.goodsUuidList) {
        NSString *uuid;
        if (goodsModel.worksUuid.length > 0) {
            uuid = goodsModel.worksUuid;
        }else{
            uuid = goodsModel.goodsUuid;
        }
        if (isDownload == YES) {
            isDownload = [[ZZSourceDataLoadManager sharedInstance] isLoadClothModelWithBodyId:uuid];
            if (!isDownload) {
                ZZGetBatchClothDownloadInfoPramaModel *pramaModel = [[ZZGetBatchClothDownloadInfoPramaModel alloc] init];
                pramaModel.worksuuid = goodsModel.worksUuid;
                pramaModel.goodsUuid = goodsModel.goodsUuid;
                [notLoadAry addObject:pramaModel];
            }
        }else{
            BOOL isload = [[ZZSourceDataLoadManager sharedInstance] isLoadClothModelWithBodyId:uuid];
            if (!isload) {
                ZZGetBatchClothDownloadInfoPramaModel *pramaModel = [[ZZGetBatchClothDownloadInfoPramaModel alloc] init];
                pramaModel.worksuuid = goodsModel.worksUuid;
                pramaModel.goodsUuid = goodsModel.goodsUuid;
                [notLoadAry addObject:pramaModel];
            }
        }
    }
    BOOL isWearModelDownload;
    if ([self findFloderFileIsExitWithFloderPath:[NSString stringWithFormat:@"%@/Documents/Wear",NSHomeDirectory()] uuid:detailWearModel.dressMatchUuid]) {
        isWearModelDownload = YES;
    }else{
        isWearModelDownload = NO;
    }
    
    result(isDownload,notLoadAry,isWearModelDownload);
}

- (void)loadBatchClothWithClothDownloadInfoArr:(NSArray *)clothDownloadInfoArr wearId:(NSString *)wearId wearModelPath:(NSString *)wearModelPath wearModelSize:(NSString *)wearModelSize  progress:(void (^)(CGFloat progress))progress complition:(void (^)(NSString *modelId))complition failure:(void (^)(NSError *error))failure{
    NSArray *taskIdStrArr = [self.loadTaskArr valueForKey:@"taskId"];
    ZZToatalLoadTask *task;
    if (![taskIdStrArr containsObject:wearId]) {
        NSArray *taskPramaArr = [self getBatchClothloadTaskInfoWithArr:clothDownloadInfoArr wearId:wearId wearModelPath:wearModelPath wearModelSize:wearModelSize];
        task = [[ZZToatalLoadTask alloc] initWithLoadDataArr:taskPramaArr oldTotalLoadTaskArr:self.loadTaskArr];
        unsigned long long totalSize = 0;
        for (ZZloadTaskPramaModel *prama in taskPramaArr) {
            totalSize += prama.size;
        }
        task.totalSize = totalSize;
        task.taskId = wearId;
        [[self mutableArrayValueForKey:@"loadTaskArr"] addObject:task];
    }else{
        for (ZZToatalLoadTask *subTask in self.loadTaskArr) {
            if ([subTask.taskId isEqualToString:wearId]) {
                task = subTask;
                break;
            }
            
        }
    }
    [task startLoad];
    WS(weakSelf)
    __weak ZZToatalLoadTask *weakTask = task;
    [task setDidReciveProgress:^(CGFloat gropressFloat) {
        dispatch_async(dispatch_get_main_queue(), ^{
            progress(gropressFloat);
        });
    }];
    [task setDidComplition:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong ZZToatalLoadTask *strongTask = weakTask;
            [weakSelf.loadTaskArr removeObject:strongTask];
            strongTask = nil;
            [weakSelf insertBatchClothArrInDataBase:clothDownloadInfoArr];
            complition(wearId);
        });
    }];
    [task setFailure:^(NSError * _Nonnull error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong ZZToatalLoadTask *strongTask = weakTask;
            [weakSelf.loadTaskArr removeObject:strongTask];
            strongTask = nil;
            failure(error);
        });
    }];
}

- (void)peauseBatchClothWithWearId:(NSString *)wearId complition:(void(^)(void))complition{
    ZZToatalLoadTask *task;
    for (ZZToatalLoadTask *subTask in self.loadTaskArr) {
        if ([subTask.taskId isEqualToString:wearId]) {
            task = subTask;
            break;
        }
    }
    if (task) {
        WS(weakSelf)
        __weak ZZToatalLoadTask *weakTask = task;
        [task peauseComplition:^{
            __strong ZZToatalLoadTask *strongTask = weakTask;
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf.loadTaskArr removeObject:strongTask];
                complition();
            });
        }];
    }
}

#pragma mark - cloth part
- (BOOL)isLoadClothPartWithPartModel:(ZZClothDownloadPartInfoModel *)partModel{
    ZZSourceDataDBManager *DBManager = [ZZSourceDataDBManager sharedInstance];
    for (ZZClothDownloadPartBindingModel *bindingModel in partModel.bindingList) {
        if (![DBManager.allClothPropertyIdArr containsObject:bindingModel.resourceUuid]) {
            return NO;
        }
    }
    return YES;
}

- (void)loadClothPartWithPartModel:(ZZClothDownloadPartInfoModel *)partModel progress:(void (^)(CGFloat progress))progress complition:(void (^)(NSString *modelId))complition failure:(void (^)(NSError *error))failure{
    NSArray *taskIdStrArr = [self.loadTaskArr valueForKey:@"taskId"];
    ZZToatalLoadTask *task;
    if (![taskIdStrArr containsObject:partModel.parUuid]) {
        NSArray *taskPramaArr = [self createSinglePartBindingPramaArrWithPartModel:partModel];
        task = [[ZZToatalLoadTask alloc] initWithLoadDataArr:taskPramaArr oldTotalLoadTaskArr:self.loadTaskArr];
        unsigned long long totalSize = 0;
        for (ZZloadTaskPramaModel *prama in taskPramaArr) {
            totalSize += prama.size;
        }
        task.totalSize = totalSize;
        task.taskId = partModel.parUuid;
        [[self mutableArrayValueForKey:@"loadTaskArr"] addObject:task];
    }else{
        for (ZZToatalLoadTask *subTask in self.loadTaskArr) {
            if ([subTask.taskId isEqualToString:partModel.parUuid]) {
                task = subTask;
                break;
            }
            
        }
    }
    [task startLoad];
    WS(weakSelf)
    __weak ZZToatalLoadTask *weakTask = task;
    [task setDidReciveProgress:^(CGFloat gropressFloat) {
        dispatch_async(dispatch_get_main_queue(), ^{
            progress(gropressFloat);
        });
    }];
    [task setDidComplition:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong ZZToatalLoadTask *strongTask = weakTask;
            [weakSelf.loadTaskArr removeObject:strongTask];
            strongTask = nil;
            [[ZZSourceDataDBManager sharedInstance] insertClothPropertyUuids:[self getSuccessDownloadPartIdAndBindingId:partModel]];
            complition(partModel.parUuid);
        });
    }];
    [task setFailure:^(NSError * _Nonnull error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong ZZToatalLoadTask *strongTask = weakTask;
            [weakSelf.loadTaskArr removeObject:strongTask];
            strongTask = nil;
            failure(error);
        });
    }];
}

- (void)peauseClothPartWithPartId:(NSString *)partId complition:(void(^)(void))complition{
    ZZToatalLoadTask *task;
    NSString *uuid = partId;
    for (ZZToatalLoadTask *subTask in self.loadTaskArr) {
        if ([subTask.taskId isEqualToString:uuid]) {
            task = subTask;
            break;
        }
    }
    if (task) {
        WS(weakSelf)
        __weak ZZToatalLoadTask *weakTask = task;
        [task peauseComplition:^{
            __strong ZZToatalLoadTask *strongTask = weakTask;
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf.loadTaskArr removeObject:strongTask];
                complition();
            });
        }];
    }
}

- (NSArray *)createSinglePartBindingPramaArrWithPartModel:(ZZClothDownloadPartInfoModel *)partModel{
    NSMutableArray *arr = [NSMutableArray array];
    for (ZZClothDownloadPartBindingModel *bindingModel in partModel.bindingList) {
        if (bindingModel.resType.intValue == 4) {
            NSString *filePath = [NSString stringWithFormat:@"%@/%@.%@",self.getSpecialTechFloderPath,bindingModel.resourceUuid,bindingModel.filePath.pathExtension];
            if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
                ZZloadTaskPramaModel *fabricPrama = [ZZloadTaskPramaModel loadTaskPramaModelWithUrl:bindingModel.filePath filePath:filePath];
                fabricPrama.size = bindingModel.fileSize.longLongValue;
                [arr addObject:fabricPrama];
            }
        }else{
            NSString *fileRootPath = [self getBuckleFloderPathWithResId:bindingModel.resourceUuid];
            if (bindingModel.modelPath.length > 0) {
                NSString *modelPath = [NSString stringWithFormat:@"%@/modelPath.%@",fileRootPath,bindingModel.modelPath.pathExtension.lowercaseString];
                ZZloadTaskPramaModel *modelPathPrama = [ZZloadTaskPramaModel loadTaskPramaModelWithUrl:bindingModel.modelPath filePath:modelPath];
                modelPathPrama.size = bindingModel.modelPathSize.longLongValue;
                [arr addObject:modelPathPrama];
            }
            NSString *filePath = [NSString stringWithFormat:@"%@/file.%@",fileRootPath,bindingModel.filePath.pathExtension.lowercaseString];
            ZZloadTaskPramaModel *filePrama = [ZZloadTaskPramaModel loadTaskPramaModelWithUrl:bindingModel.filePath filePath:filePath];
            filePrama.size = bindingModel.fileSize.longLongValue;
            [arr addObject:filePrama];
        }
    }
    return arr;
}

- (NSArray *)getSuccessDownloadPartIdAndBindingId:(ZZClothDownloadPartInfoModel *)partModel{
    NSMutableArray *arr = [NSMutableArray array];
    [arr addObject:partModel.parUuid];
    for (ZZClothDownloadPartBindingModel *bindingModel in partModel.bindingList) {
        [arr addObject:bindingModel.resourceUuid];
    }
    return arr;
}

#pragma mark - cloth accessories
- (BOOL)accessoriesIsDidDownloadWithAccessoriesId:(NSString *)accessoriesId{
    NSArray *didDownloadIdArr = [ZZSourceDataDBManager sharedInstance].allClothPropertyIdArr;
    if ([didDownloadIdArr containsObject:accessoriesId]) {
        return YES;
    }else{
        return NO;
    }
}

- (void)loadDataWithAccessoriesModel:(ZZClothDownloadModelAccessoriesInfo *)accessoriesModel progress:(void (^)(CGFloat progress))progress complition:(void (^)(NSString *modelId))complition failure:(void (^)(NSError *error))failure{
    NSArray *taskIdStrArr = [self.loadTaskArr valueForKey:@"singleTaskId"];
    ZZToatalLoadTask *task;
    if (![taskIdStrArr containsObject:accessoriesModel.materialImageUuid]) {
        NSArray *taskPramaArr = [self getAccessoriesPramaModel:accessoriesModel];
        task = [[ZZToatalLoadTask alloc] initWithLoadDataArr:taskPramaArr oldTotalLoadTaskArr:self.loadTaskArr];
        task.taskId = accessoriesModel.materialImageUuid;
        [self.loadTaskArr addObject:task];
    }else{
        for (ZZToatalLoadTask *subTask in self.loadTaskArr) {
            if ([subTask.taskId isEqualToString:accessoriesModel.materialImageUuid]) {
                task = subTask;
                break;
            }
        }
    }
    [task startLoad];
    WS(weakSelf)
    __weak ZZToatalLoadTask *weakTask = task;
    [task setDidReciveProgress:^(CGFloat gropressFloat) {
        dispatch_async(dispatch_get_main_queue(), ^{
            progress(gropressFloat);
        });
    }];
    [task setDidComplition:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong ZZToatalLoadTask *strongTask = weakTask;
            [weakSelf.loadTaskArr removeObject:strongTask];
            strongTask = nil;
           [[ZZSourceDataDBManager sharedInstance] insertClothPropertyUuids:@[accessoriesModel.materialImageUuid]];
            complition(accessoriesModel.materialImageUuid);
        });
    }];
    [task setFailure:^(NSError * _Nonnull error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong ZZToatalLoadTask *strongTask = weakTask;
            [weakSelf.loadTaskArr removeObject:strongTask];
            strongTask = nil;
            failure(error);
        });
    }];
}

- (void)peauseWithAccessoriesModel:(ZZDetailMaterielModel *)accessoriesModel{
    ZZToatalLoadTask *task;
    NSString *uuid = accessoriesModel.materialImageUuid;
    for (ZZToatalLoadTask *subTask in self.loadTaskArr) {
        if ([subTask.taskId isEqualToString:uuid]) {
            task = subTask;
            break;
        }
    }
    if (task) {
        WS(weakSelf)
        __weak ZZToatalLoadTask *weakTask = task;
        [task peauseComplition:^{
        }];
    }
}

- (NSArray *)getAccessoriesPramaModel:(ZZClothDownloadModelAccessoriesInfo *)accessoriesModel{
    NSMutableArray *arr = [NSMutableArray array];
    NSString *fileRootPath = [self getBuckleFloderPathWithResId:accessoriesModel.materialImageUuid];
    if (accessoriesModel.modelPathApp.length > 0) {
        NSString *modelPath = [NSString stringWithFormat:@"%@/modelPath.%@",fileRootPath,accessoriesModel.modelPathApp.pathExtension.lowercaseString];
        ZZloadTaskPramaModel *modelPathPrama = [ZZloadTaskPramaModel loadTaskPramaModelWithUrl:accessoriesModel.modelPathApp filePath:modelPath];
        [arr addObject:modelPathPrama];
    }
    NSString *filePath = [NSString stringWithFormat:@"%@/file.%@",fileRootPath,accessoriesModel.filePathApp.pathExtension.lowercaseString];
    ZZloadTaskPramaModel *filePrama = [ZZloadTaskPramaModel loadTaskPramaModelWithUrl:accessoriesModel.filePathApp filePath:filePath];
    filePrama.size = accessoriesModel.size.longLongValue;
    [arr addObject:filePrama];
    return arr;
}

#pragma mark - cloth mater
- (BOOL)isLoadClothMaterWithMaterModel:(ZZDetailMaterielModel *)materModel{
    ZZSourceDataDBManager *DBManager = [ZZSourceDataDBManager sharedInstance];
    if (materModel.bindingList.count == 0) {
        return [DBManager.allClothPropertyIdArr containsObject:materModel.materialImageUuid];
    }else{
        if ([DBManager.allClothPropertyIdArr containsObject:materModel.materialImageUuid]) {
            for (ZZClothDownloadAssistBindingMaterModel *bindingModel in materModel.bindingList) {
                if (![DBManager.allClothPropertyIdArr containsObject:bindingModel.assistResId]) {
                    return NO;
                }
            }
            return YES;
        }else{
            return NO;
        }
    }
    
}

- (void)loadClothMaterWithMaterModel:(ZZDetailMaterielModel *)materModel progress:(void (^)(CGFloat progress))progress complition:(void (^)(NSString *modelId))complition failure:(void (^)(NSError *error))failure{
    NSArray *taskIdStrArr = [self.loadTaskArr valueForKey:@"taskId"];
    ZZToatalLoadTask *task;
    if (![taskIdStrArr containsObject:materModel.materialImageUuid]) {
        NSArray *taskPramaArr = [self createSingleMaterAndBindingPramaArrWithMaterModel:materModel];
        task = [[ZZToatalLoadTask alloc] initWithLoadDataArr:taskPramaArr oldTotalLoadTaskArr:self.loadTaskArr];
        unsigned long long totalSize = 0;
        for (ZZloadTaskPramaModel *prama in taskPramaArr) {
            totalSize += prama.size;
        }
        task.totalSize = totalSize;
        task.taskId = materModel.materialImageUuid;
        [[self mutableArrayValueForKey:@"loadTaskArr"] addObject:task];
    }else{
        for (ZZToatalLoadTask *subTask in self.loadTaskArr) {
            if ([subTask.taskId isEqualToString:materModel.materialImageUuid]) {
                task = subTask;
                break;
            }
            
        }
    }
    [task startLoad];
    WS(weakSelf)
    __weak ZZToatalLoadTask *weakTask = task;
    [task setDidReciveProgress:^(CGFloat gropressFloat) {
        dispatch_async(dispatch_get_main_queue(), ^{
            progress(gropressFloat);
        });
    }];
    [task setDidComplition:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong ZZToatalLoadTask *strongTask = weakTask;
            [weakSelf.loadTaskArr removeObject:strongTask];
            strongTask = nil;
            [[ZZSourceDataDBManager sharedInstance] insertClothPropertyUuids:[self getSuccessDownloadMaterIdAndBindingId:materModel]];
            complition(materModel.materialImageUuid);
        });
    }];
    [task setFailure:^(NSError * _Nonnull error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong ZZToatalLoadTask *strongTask = weakTask;
            [weakSelf.loadTaskArr removeObject:strongTask];
            strongTask = nil;
            failure(error);
        });
    }];
}

- (NSArray *)getSuccessDownloadMaterIdAndBindingId:(ZZDetailMaterielModel *)materModel{
    NSMutableArray *arr = [NSMutableArray array];
    [arr addObject:materModel.materialImageUuid];
    for (ZZClothDownloadAssistBindingMaterModel *bindingModel in materModel.bindingList) {
        [arr addObject:bindingModel.assistResId];
    }
    return arr;
}

- (void)peauseClothMaterWithMaterId:(NSString *)materId complition:(void(^)(void))complition{
    ZZToatalLoadTask *task;
    NSString *uuid = materId;
    for (ZZToatalLoadTask *subTask in self.loadTaskArr) {
        if ([subTask.taskId isEqualToString:uuid]) {
            task = subTask;
            break;
        }
    }
    if (task) {
        WS(weakSelf)
        __weak ZZToatalLoadTask *weakTask = task;
        [task peauseComplition:^{
            __strong ZZToatalLoadTask *strongTask = weakTask;
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf.loadTaskArr removeObject:strongTask];
                complition();
            });
        }];
    }
}

- (NSArray *)createSingleMaterAndBindingPramaArrWithMaterModel:(ZZDetailMaterielModel *)materModel{
    NSMutableArray *arr = [NSMutableArray array];
    for (ZZClothDownloadAssistBindingMaterModel *bindingModel in materModel.bindingList) {
        NSString *fileRootPath = [self getBuckleFloderPathWithResId:bindingModel.assistResId];
        NSString *filePath = [NSString stringWithFormat:@"%@/file.%@",fileRootPath,bindingModel.assistResFilePath.pathExtension];
        if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
            ZZloadTaskPramaModel *fabricPrama = [ZZloadTaskPramaModel loadTaskPramaModelWithUrl:bindingModel.assistResFilePath filePath:filePath];
            fabricPrama.size = bindingModel.assistResSize.longLongValue;
            [arr addObject:fabricPrama];
        }
    }
    NSString *materFilePath = [NSString stringWithFormat:@"%@/%@.%@",self.getFabricFloderPath,materModel.materialImageUuid,materModel.filePathApp.pathExtension];
    if (![[NSFileManager defaultManager] fileExistsAtPath:materFilePath]) {
        ZZloadTaskPramaModel *fabricPrama = [ZZloadTaskPramaModel loadTaskPramaModelWithUrl:materModel.filePathApp filePath:materFilePath];
        fabricPrama.size = materModel.fileSize.longLongValue;
        [arr addObject:fabricPrama];
    }
    return arr;
}

#pragma mark - hair
- (BOOL)isLoadHairModelWithHairId:(NSString *)hairId{
    for (ZZHairPathModel *pathModel in [ZZSourceDataDBManager sharedInstance].allHairDataArr) {
        if ([pathModel.hairId isEqualToString:hairId]) {
            return YES;
        }
    }
    return NO;
}

- (void)loadDataWithHairModel:(ZZDownloadHairInfoModel *)hairModel progress:(void (^)(CGFloat progress))progress failure:(void (^)(NSError *error))failure{
    NSArray *taskIdStrArr = [self.loadTaskArr valueForKey:@"taskId"];
    ZZToatalLoadTask *task;
//    NSString *floderPath = [self createHairFloderWithUuid:hairModel.uuid];
    NSString *tmpPath = [NSString stringWithFormat:@"%@/tmp/Hair%@.zip",NSHomeDirectory(),hairModel.uuid];
    
    if (![taskIdStrArr containsObject:hairModel.uuid]) {
        //放到tmp
        
        NSArray *taskPramaArr = @[[ZZloadTaskPramaModel loadTaskPramaModelWithUrl:hairModel.appPath filePath:tmpPath]];
        
        task = [[ZZToatalLoadTask alloc] initWithLoadDataArr:taskPramaArr oldTotalLoadTaskArr:self.loadTaskArr];
        task.taskId = hairModel.uuid;
        [[self mutableArrayValueForKey:@"loadTaskArr"] addObject:task];
    }else{
        for (ZZToatalLoadTask *subTask in self.loadTaskArr) {
            if ([subTask.taskId isEqualToString:hairModel.uuid]) {
                task = subTask;
                break;
            }
        }
    }
    [task startLoad];
    
    
    
    WS(weakSelf)
    __weak ZZToatalLoadTask *weakTask = task;
//    [task setDidReciveProgress:^(CGFloat gropressFloat) {
//        dispatch_async(dispatch_get_main_queue(), ^{
//            progress(gropressFloat);
//        });
//    }];
    [task setDidComplition:^{
        dispatch_async(dispatch_get_main_queue(), ^{
          [self unzipFileMethod:hairModel sourcePath:tmpPath];
        });
        
    }];
    [task setFailure:^(NSError * _Nonnull error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong ZZToatalLoadTask *strongTask = weakTask;
            //            [strongTask peauseComplition:^{
            [weakSelf.loadTaskArr removeObject:strongTask];
            strongTask = nil;
            failure(error);
            //            }];
        });
    }];
}


- (void)peauseWithHairModel:(ZZDownloadHairInfoModel *)hairModel complition:(void(^)(void))complition{
    ZZToatalLoadTask *task;
    for (ZZToatalLoadTask *subTask in self.loadTaskArr) {
        if ([subTask.taskId isEqualToString:hairModel.uuid]) {
            task = subTask;
            break;
        }
    }
    if (task) {
        WS(weakSelf)
        __weak ZZToatalLoadTask *weakTask = task;
        [task peauseComplition:^{
            __strong ZZToatalLoadTask *strongTask = weakTask;
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf.loadTaskArr removeObject:strongTask];
                complition();
            });
        }];
    }
}

#pragma mark 解压文件
-(void)unzipFileMethod:(ZZDownloadHairInfoModel *)hairModel sourcePath:(NSString*)sourcePath
{
    /*
     第一个参数:要解压的文件在哪里
     第二个参数:文件应该解压到什么地方
     */
    
//    [SSZipArchive unzipFileAtPath:@"" toDestination:@"" delegate:self uniqueId:@""];
    NSError *error;
    NSString *floderPath = [self createHairFloderWithUuid:hairModel.uuid];
//    NSString *tmpPath = [NSString stringWithFormat:@"%@/tmp/hair",NSHomeDirectory()];

    [SSZipArchive unzipFileAtPath:sourcePath toDestination:floderPath overwrite:YES password:nil error:&error delegate:self uniqueId:hairModel.uuid];
  
}

- (void)zipArchiveDidUnzipArchiveAtPath:(NSString *)path zipInfo:(unz_global_info)zipInfo unzippedPath:(NSString *)unzippedPat uniqueId:(NSString *)uniqueId {
//    NSString *blocknNameKey = [NSString stringWithFormat:@"comlitionBlockKey%@",uniqueId];
//    hairComplitionCallback callBack = objc_getAssociatedObject(self, blocknNameKey.UTF8String);
    
    ZZHairPathModel *pathModel = [ZZHairPathModel new];
    pathModel.hairPath = [NSString stringWithFormat:@"Documents/Hair/%@",uniqueId];
    pathModel.hairId = uniqueId;
    [[ZZSourceDataDBManager sharedInstance] insertHairModel:pathModel];
    ZZToatalLoadTask *task;
    for (ZZToatalLoadTask *subTask in self.loadTaskArr) {
        if ([subTask.taskId isEqualToString:uniqueId]) {
            task = subTask;
            break;
        }
    }
    
    [self.loadTaskArr removeObject:task];
    task = nil;
    
    if (self.delegate) {
        [self.delegate sourceDataLoadManager:self didDownloadHairSuccessWithHairId:uniqueId];
    }
}

#pragma mark - shoe
- (BOOL)isLoadShoeModelWithShoeId:(NSString *)shoeId{
    for (ZZShoePathModel *pathModel in [ZZSourceDataDBManager sharedInstance].allShoeDataArr) {
        if ([pathModel.shoeId isEqualToString:shoeId]) {
            return YES;
        }
    }
    return NO;
}

- (void)loadDataWithShoeModel:(ZZDownloadShoeInfoModel *)shoeModel progress:(void (^)(CGFloat progress))progress complition:(void (^)(NSString *modelId))complition failure:(void (^)(NSError *error))failure{
    NSArray *taskIdStrArr = [self.loadTaskArr valueForKey:@"taskId"];
    ZZToatalLoadTask *task;
    NSString *floderPath = [self createShoeFloderWithUuid:shoeModel.uuid];
    if (![taskIdStrArr containsObject:shoeModel.uuid]) {
        NSArray *taskPramaArr = @[[ZZloadTaskPramaModel loadTaskPramaModelWithUrl:shoeModel.filePath filePath:[NSString stringWithFormat:@"%@/shoeData.Shoes",floderPath]]];
        task = [[ZZToatalLoadTask alloc] initWithLoadDataArr:taskPramaArr oldTotalLoadTaskArr:self.loadTaskArr];
        //        long long totalSize = bodyModel.modelPath.personImageSize.longLongValue + bodyModel.bddmFile.bd.personImageSize.longLongValue + bodyModel.bddmFile.dm.personImageSize.longLongValue + bodyModel.stickersPath.personImageSize.longLongValue;
        //        task.totalSize = totalSize;
        task.taskId = shoeModel.uuid;
        [[self mutableArrayValueForKey:@"loadTaskArr"] addObject:task];
    }else{
        for (ZZToatalLoadTask *subTask in self.loadTaskArr) {
            if ([subTask.taskId isEqualToString:shoeModel.uuid]) {
                task = subTask;
                break;
            }
        }
    }
    [task startLoad];
    WS(weakSelf)
    __weak ZZToatalLoadTask *weakTask = task;
    //    [task setDidReciveProgress:^(CGFloat gropressFloat) {
    //        dispatch_async(dispatch_get_main_queue(), ^{
    //            progress(gropressFloat);
    //        });
    //    }];
    [task setDidComplition:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong ZZToatalLoadTask *strongTask = weakTask;
            [weakSelf.loadTaskArr removeObject:strongTask];
            strongTask = nil;
            ZZShoePathModel *pathModel = [ZZShoePathModel new];
            pathModel.shoePath = [NSString stringWithFormat:@"Documents/Shoe/%@",shoeModel.uuid];
            pathModel.shoeId = shoeModel.uuid;
            [[ZZSourceDataDBManager sharedInstance] insertShoeModel:pathModel];
            complition(shoeModel.uuid);
        });
    }];
    [task setFailure:^(NSError * _Nonnull error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong ZZToatalLoadTask *strongTask = weakTask;
            //            [strongTask peauseComplition:^{
            [weakSelf.loadTaskArr removeObject:strongTask];
            strongTask = nil;
            failure(error);
            //            }];
        });
    }];
}

- (void)peauseWithShoeModel:(ZZDownloadShoeInfoModel *)shoeModel complition:(void(^)(void))complition{
    ZZToatalLoadTask *task;
    for (ZZToatalLoadTask *subTask in self.loadTaskArr) {
        if ([subTask.taskId isEqualToString:shoeModel.uuid]) {
            task = subTask;
            break;
        }
    }
    if (task) {
        WS(weakSelf)
        __weak ZZToatalLoadTask *weakTask = task;
        [task peauseComplition:^{
            __strong ZZToatalLoadTask *strongTask = weakTask;
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf.loadTaskArr removeObject:strongTask];
                complition();
            });
        }];
    }
}

#pragma mark - action
- (BOOL)isLoadActionModelWithActionId:(NSString *)actionId{
    NSString *filePath = [NSString stringWithFormat:@"%@/Documents/Action",NSHomeDirectory()];
    return [self findFloderFileIsExitWithFloderPath:filePath uuid:actionId];
}

- (void)loadDataWithActionModel:(ZZPoseModel *)actionModel progress:(void (^)(CGFloat progress))progress complition:(void (^)(NSString *modelId))complition failure:(void (^)(NSError *error))failure{
    NSArray *taskIdStrArr = [self.loadTaskArr valueForKey:@"taskId"];
    ZZToatalLoadTask *task;
    NSString *filePath = [NSString stringWithFormat:@"%@/Documents/Action/%@.bvh",NSHomeDirectory(),actionModel.uuid];
    if (![taskIdStrArr containsObject:actionModel.uuid]) {
        NSArray *taskPramaArr = @[[ZZloadTaskPramaModel loadTaskPramaModelWithUrl:actionModel.moduleFile filePath:filePath]];
        task = [[ZZToatalLoadTask alloc] initWithLoadDataArr:taskPramaArr oldTotalLoadTaskArr:self.loadTaskArr];
        //        long long totalSize = bodyModel.modelPath.personImageSize.longLongValue + bodyModel.bddmFile.bd.personImageSize.longLongValue + bodyModel.bddmFile.dm.personImageSize.longLongValue + bodyModel.stickersPath.personImageSize.longLongValue;
        //        task.totalSize = totalSize;
        task.taskId = actionModel.uuid;
        task.totalSize = actionModel.moduleSize.longLongValue;
        [[self mutableArrayValueForKey:@"loadTaskArr"] addObject:task];
    }else{
        for (ZZToatalLoadTask *subTask in self.loadTaskArr) {
            if ([subTask.taskId isEqualToString:actionModel.uuid]) {
                task = subTask;
                break;
            }
        }
    }
    [task startLoad];
    WS(weakSelf)
    __weak ZZToatalLoadTask *weakTask = task;
    //    [task setDidReciveProgress:^(CGFloat gropressFloat) {
    //        dispatch_async(dispatch_get_main_queue(), ^{
    //            progress(gropressFloat);
    //        });
    //    }];
    [task setDidComplition:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong ZZToatalLoadTask *strongTask = weakTask;
            [weakSelf.loadTaskArr removeObject:strongTask];
            strongTask = nil;
            complition(actionModel.uuid);
        });
    }];
    [task setFailure:^(NSError * _Nonnull error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong ZZToatalLoadTask *strongTask = weakTask;
            //            [strongTask peauseComplition:^{
            [weakSelf.loadTaskArr removeObject:strongTask];
            strongTask = nil;
            failure(error);
            //            }];
        });
    }];
}

- (void)peauseWithActionModel:(ZZPoseModel *)actionModel complition:(void(^)(void))complition{
    ZZToatalLoadTask *task;
    for (ZZToatalLoadTask *subTask in self.loadTaskArr) {
        if ([subTask.taskId isEqualToString:actionModel.uuid]) {
            task = subTask;
            break;
        }
    }
    if (task) {
        WS(weakSelf)
        __weak ZZToatalLoadTask *weakTask = task;
        [task peauseComplition:^{
            __strong ZZToatalLoadTask *strongTask = weakTask;
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf.loadTaskArr removeObject:strongTask];
                complition();
            });
        }];
    }
}

#pragma mark - 清除缓存
- (void)cleanSourceDataComplition:(void (^)(void))complition{
    [self removeFloderWithFloderName:@"Body"];
    [self removeFloderWithFloderName:@"Cloth"];
    [self removeFloderWithFloderName:@"Hair"];
    [self removeFloderWithFloderName:@"Material"];
    [self removeFloderWithFloderName:@"Shoe"];
    [self removeFloderWithFloderName:@"SOURCEDATA.db"];
    [self removeFloderWithFloderName:@"Resource"];
    [self removeFloderWithFloderName:@"Action"];
    [self removeTmpFloderFile];
    [[NSUserDefaults standardUserDefaults] setObject:@"10001" forKey:ZZCurrentModelUuidUserDefaultKey(ZZFemalType)];
    [[NSUserDefaults standardUserDefaults] setObject:@"10000" forKey:ZZCurrentModelUuidUserDefaultKey(ZZMaleType)];
    [ZZSourceDataDBManager attemptDealloc];
    [ZZLocalDataRequest copyResourceToDocumentFile];
    complition();
}

- (void)removeFloderWithFloderName:(NSString *)floderName{
    NSString *floderPath = [NSString stringWithFormat:@"%@/Documents/%@",NSHomeDirectory(),floderName];
    BOOL isexist = [[NSFileManager defaultManager] fileExistsAtPath:floderPath];
    if (isexist) {
        [[NSFileManager defaultManager] removeItemAtPath:floderPath error:nil];
    }
}

- (void)removeTmpFloderFile{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *tmpPath = [NSString stringWithFormat:@"%@/tmp",NSHomeDirectory()];
    NSArray * dirArray = [fileManager contentsOfDirectoryAtPath:tmpPath error:nil];
    for (NSString * str in dirArray) {
        NSString *filePath = [NSString stringWithFormat:@"%@/%@",tmpPath,str];
        BOOL isexist = [[NSFileManager defaultManager] fileExistsAtPath:filePath];
        if (isexist) {
            [fileManager removeItemAtPath:filePath error:nil];
        }
    }
    
}

#pragma mark - 加入试衣篮
- (void)addBasketWithGender:(NSString *)gender goodsUuid:(NSString *)goodsUuid worksId:(NSString *)worksId success:(void (^)(void))success failure:(void (^)(NSError *error))failure{
    ZZJoinInBasketReqeust *request = [[ZZJoinInBasketReqeust alloc] init];
    request.gender = gender;
    request.goodsUuid = goodsUuid;
    request.worksUuid = worksId;
    [request startRequestWithObjectClass:NULL success:^(id  _Nonnull responseResult) {
        success();
    } failure:^(NSError * _Nonnull error) {
        failure(error);
    }];
}

#pragma mark - 创建文件夹
- (NSString *)createBodyFloderWithUuid:(NSString *)uuid{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *floderPath = [NSString stringWithFormat:@"%@/Documents/Body/%@",NSHomeDirectory(),uuid];
    BOOL isDir = NO;
    BOOL existed = [fileManager fileExistsAtPath:floderPath isDirectory:&isDir];
    if ( !(isDir == YES && existed == YES) ) {//如果文件夹不存在
        [fileManager createDirectoryAtPath:floderPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return floderPath;
}

- (NSString *)createClothFloderWithUuid:(NSString *)uuid{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *floderPath = [NSString stringWithFormat:@"%@/Documents/Cloth/%@",NSHomeDirectory(),uuid];
    BOOL isDir = NO;
    BOOL existed = [fileManager fileExistsAtPath:floderPath isDirectory:&isDir];
    if ( !(isDir == YES && existed == YES) ) {//如果文件夹不存在
        [fileManager createDirectoryAtPath:floderPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return floderPath;
}

- (NSString *)createHairFloderWithUuid:(NSString *)uuid{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *floderPath = [NSString stringWithFormat:@"%@/Documents/Hair/%@",NSHomeDirectory(),uuid];
    BOOL isDir = NO;
    BOOL existed = [fileManager fileExistsAtPath:floderPath isDirectory:&isDir];
    if ( !(isDir == YES && existed == YES) ) {//如果文件夹不存在
        [fileManager createDirectoryAtPath:floderPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return floderPath;
}

- (NSString *)createShoeFloderWithUuid:(NSString *)uuid{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *floderPath = [NSString stringWithFormat:@"%@/Documents/Shoe/%@",NSHomeDirectory(),uuid];
    BOOL isDir = NO;
    BOOL existed = [fileManager fileExistsAtPath:floderPath isDirectory:&isDir];
    if ( !(isDir == YES && existed == YES) ) {//如果文件夹不存在
        [fileManager createDirectoryAtPath:floderPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return floderPath;
}

- (NSString *)getFabricFloderPath{
    return [NSString stringWithFormat:@"%@/Documents/Material/Fabric",NSHomeDirectory()];
}

//- (NSString *)getBuckleFloderPath{
//    return [NSString stringWithFormat:@"%@/Documents/Material/Buckle",NSHomeDirectory()];
//}

- (NSString *)getBuckleFloderPathWithResId:(NSString *)resId{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *floderPath = [NSString stringWithFormat:@"%@/Documents/Material/Buckle/%@",NSHomeDirectory(),resId];
    BOOL isDir = NO;
    BOOL existed = [fileManager fileExistsAtPath:floderPath isDirectory:&isDir];
    if ( !(isDir == YES && existed == YES) ) {//如果文件夹不存在
        [fileManager createDirectoryAtPath:floderPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return floderPath;
}

- (NSString *)getSpecialTechFloderPath{
    return [NSString stringWithFormat:@"%@/Documents/Material/SpecialTech",NSHomeDirectory()];
}

#pragma mark - 批量获取下载信息
- (void)getBatchDownloadInfoWithPramaAry:(NSArray *)pramaAry success:(void (^)(NSArray *downloadInfoArr))success failure:(void (^)(NSError *error))failure{
    ZZGetBatchClothDownloadInfoRequest *request = [[ZZGetBatchClothDownloadInfoRequest alloc] init];
    request.pramaAry = pramaAry;
    [request startRequestWithObjectClass:ZZClothDownloadModel.class success:^(id  _Nonnull responseResult) {
        NSArray *downloadArr = responseResult;
        for (int i = 0; i < downloadArr.count; i ++) {
            ZZClothDownloadModel *downloadModel = downloadArr[i];
            ZZGetBatchClothDownloadInfoPramaModel *pramaModel = pramaAry[i];
            downloadModel.worksId = pramaModel.worksuuid;
        }
        NSMutableArray *arr = [NSMutableArray array];
        for (ZZClothDownloadModel *downloadModel in downloadArr) {
            for (ZZClothDownloadGroupPartInfoModel *groupPartModel in downloadModel.parCodeAry) {
                for (ZZClothDownloadPartInfoModel *partModel in groupPartModel.partReplaceReqs) {
                    partModel.groupCode = groupPartModel.groupCode;
                }
            }
            for (ZZDetailMallMaterielGroupRespModel *groupMaterModel in downloadModel.materGroupList) {
                for (ZZDetailMaterielModel *materModel in groupMaterModel.materialDetailList) {
                    materModel.groupCode = groupMaterModel.groupCode;
                }
            }
            for (ZZClothDownloadGroupAssistBindingMaterModel *assistGroupModel in downloadModel.accessoriesResourceRelations    ) {
                for (ZZClothDownloadAssistBindingMaterModel *assistModel in assistGroupModel.resourceIdRelation) {
                    assistModel.assistGroupId = assistGroupModel.assistGroupId;
                }
            }
            
            [self setDefualtAccessoriesListWithModel:downloadModel];
            
            [self deleteBindingAssistFromAccessoriesGroupList:downloadModel.accessoriesGroupList bindingList:downloadModel.accessoriesResourceRelations];
            
            [self dealBindingInfoWithModel:downloadModel];
            [arr addObject:downloadModel];
        }
        success(arr);
    } failure:^(NSError * _Nonnull error) {
        failure(error);
    }];
}

- (void)setDefualtAccessoriesListWithModel:(ZZClothDownloadModel *)downloadModel{
    NSMutableArray *defualtAccessoriesList = [NSMutableArray array];
    for (ZZClothDownloadPartBindingModel *bindingModel in downloadModel.partOtherResourceResps) {
        if ([bindingModel.partCode isEqualToString:@"0"]) {
            [defualtAccessoriesList addObject:bindingModel];
        }
    }
    downloadModel.defaultAccessoriesList = defualtAccessoriesList;
}

- (void)dealBindingInfoWithModel:(ZZClothDownloadModel *)downloadModel{
    for (ZZClothDownloadGroupPartInfoModel *groupModel in downloadModel.parCodeAry) {
        for (ZZClothDownloadPartInfoModel *partModel in groupModel.partReplaceReqs) {
            NSMutableArray *arr = [NSMutableArray array];
            for (ZZClothDownloadPartBindingModel *bindingModel in downloadModel.partOtherResourceResps) {
                if ([partModel.parCode isEqualToString:bindingModel.partCode]) {
                    [arr addObject:bindingModel];
                }
            }
            partModel.bindingList = arr;
        }
    }
    
    for (ZZClothDownloadGroupAssistBindingMaterModel *assistGroupModel in downloadModel.accessoriesResourceRelations) {
        for (ZZDetailMallMaterielGroupRespModel *materGroupModel in downloadModel.materGroupList) {
            if ([assistGroupModel.fabricGroupId isEqualToString:materGroupModel.groupCode]) {
                for (ZZDetailMaterielModel *materModel in materGroupModel.materialDetailList) {
                    NSMutableArray *arr = [NSMutableArray arrayWithArray:materModel.bindingList];
                    for (ZZClothDownloadAssistBindingMaterModel *assistModel in assistGroupModel.resourceIdRelation) {
                        if ([assistModel.fabricResId isEqualToString:materModel.materialImageUuid]) {
                            [arr addObject:assistModel];
                        }
                    }
                    materModel.bindingList = arr;
                }
            }
        }
    }
    
}

- (void)deleteBindingAssistFromAccessoriesGroupList:(NSArray *)accessoriesGroupList bindingList:(NSArray *)bindingList{
    for (ZZClothDownloadModelGroupAccessoriesInfo *accessoriesGroupInfo in accessoriesGroupList) {
        NSMutableArray *deleteArr = [NSMutableArray array];
        for (ZZClothDownloadGroupAssistBindingMaterModel *groupBindingInfo in bindingList) {
            if ([accessoriesGroupInfo.groupCode isEqualToString:groupBindingInfo.assistGroupId]) {
                for (ZZClothDownloadAssistBindingMaterModel *assistModel in groupBindingInfo.resourceIdRelation) {
                    for (ZZClothDownloadModelAccessoriesInfo *accInfo in accessoriesGroupInfo.accessoriesList) {
                        if ([assistModel.assistResId isEqualToString:accInfo.materialImageUuid]) {
                            [deleteArr addObject:accInfo];
                        }
                    }
                }
            }
        }
        NSMutableArray *accArr = [NSMutableArray arrayWithArray:accessoriesGroupInfo.accessoriesList];
        [accArr removeObjectsInArray:deleteArr];
        accessoriesGroupInfo.accessoriesList = accArr;
    }
}

#pragma mark - helper

/**
 遍历一个文件夹内是否下载了该文件

 @param path f文件夹地址
 @param uuid 文件Id （单个资源文件）
 @return 结果
 */
- (BOOL)findFloderFileIsExitWithFloderPath:(NSString *)path uuid:(NSString *)uuid{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray * dirArray = [fileManager contentsOfDirectoryAtPath:path error:nil];
    for (NSString * str in dirArray) {
        if ([str containsString:uuid]) {
            return YES;
        }
    }
    return NO;
}


@end
