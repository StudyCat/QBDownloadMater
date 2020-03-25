//
//  ZZSourceDataLoadManager.h
//  ZZOnlineDressupMall
//
//  Created by 秦彬 on 2019/1/24.
//  Copyright © 2019年 wangshaosheng. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZZNetBodyModel.h"
#import "ZZHomePageSelectClothModelManager.h"
#import "ZZHomeChooseHairModelManager.h"
#import "ZZChooseShoeModelManager.h"
#import "ZZGetBatchClothDownloadInfoRequest.h"
#import "SSZipArchive.h"
#import "ZZHomeFullScreenModelManager.h"
NS_ASSUME_NONNULL_BEGIN
@class ZZSaveMaterOrBucklePramaModel;
@class ZZSourceDataLoadManager;
@protocol QBSourceDataLoadManagerDelegate <NSObject>

@optional

- (void)sourceDataLoadManager:(ZZSourceDataLoadManager *)manager didDownloadHairSuccessWithHairId:(NSString *)hairId;

@end

@interface QBSourceDataLoadManager : NSObject<SSZipArchiveDelegate>

@property (nonatomic,weak)id<ZZSourceDataLoadManagerDelegate> delegate;

+ (instancetype)sharedInstance;

- (void)cancelAllDownload;

/**
 下载任务数组  最多只能进行2个任务
 */
@property (nonatomic,retain)NSMutableArray *loadTaskArr;


@property (nonatomic,retain)NSArray *downloadIdArray;

#pragma mark - body

/**
 是否人体模型已下载

 @param bodyId 模型uuid
 @return 是否下载好了
 */
- (BOOL)isLoadBodyModelWithBodyId:(NSString *)bodyId;


/**
 下载人体模型

 @param bodyModel 人体模型业务实体对象
 @param progress 进度值
 @param complition 下载成功回调
 @param failure 下载失败回调
 */
- (void)loadDataWithBodyModel:(ZZNetBodyModel *)bodyModel progress:(void (^)(CGFloat progress))progress complition:(void (^)(NSString *modelId))complition failure:(void (^)(NSError *error))failure;


/**
 暂停下载

 @param bodyModel 人体模型业务实体对象
 */
- (void)peauseWithBodyModel:(ZZNetBodyModel *)bodyModel complition:(void(^)(void))complition;

#pragma mark - cloth
- (BOOL)isLoadClothModelWithBodyId:(NSString *)clothId;

- (void)loadDataWithClothModel:(ZZClothDownloadModel *)clothModel progress:(void (^)(CGFloat progress))progress complition:(void (^)(NSString *modelId))complition failure:(void (^)(NSError *error))failure;

- (void)peauseWithClothModel:(ZZClothDownloadModel *)clothModel complition:(void(^)(void))complition;

- (void)insertCreateWorksInDataBase:(NSDictionary *)worksDic worksId:(NSString *)worksId materInfoArr:(NSArray <ZZSaveMaterOrBucklePramaModel *>*)materInfoArr partInfoArr:(NSArray *)partInfo accInfoArr:(NSArray *)accInfoArr defaultAccess:(NSArray *)defaultAccess;

#pragma mark - cloth part
- (BOOL)isLoadClothPartWithPartModel:(ZZClothDownloadPartInfoModel *)partModel;

- (void)loadClothPartWithPartModel:(ZZClothDownloadPartInfoModel *)partModel progress:(void (^)(CGFloat progress))progress complition:(void (^)(NSString *modelId))complition failure:(void (^)(NSError *error))failure;

- (void)peauseClothPartWithPartId:(NSString *)partId complition:(void(^)(void))complition;

#pragma mark - cloth accessories
- (BOOL)accessoriesIsDidDownloadWithAccessoriesId:(NSString *)accessoriesId;

- (void)loadDataWithAccessoriesModel:(ZZClothDownloadModelAccessoriesInfo *)accessoriesModel progress:(void (^)(CGFloat progress))progress complition:(void (^)(NSString *modelId))complition failure:(void (^)(NSError *error))failure;

- (void)peauseWithAccessoriesModel:(ZZDetailMaterielModel *)accessoriesModel;

#pragma mark - cloth mater
- (BOOL)isLoadClothMaterWithMaterModel:(ZZDetailMaterielModel *)materModel;

- (void)loadClothMaterWithMaterModel:(ZZDetailMaterielModel *)materModel progress:(void (^)(CGFloat progress))progress complition:(void (^)(NSString *modelId))complition failure:(void (^)(NSError *error))failure;

- (void)peauseClothMaterWithMaterId:(NSString *)materId complition:(void(^)(void))complition;

#pragma mark - hair
- (BOOL)isLoadHairModelWithHairId:(NSString *)hairId;

//- (void)loadDataWithHairModel:(ZZDownloadHairInfoModel *)hairModel progress:(void (^)(CGFloat progress))progress complition:(void (^)(NSString *modelId))complition failure:(void (^)(NSError *error))failure;
- (void)loadDataWithHairModel:(ZZDownloadHairInfoModel *)hairModel progress:(void (^)(CGFloat progress))progress failure:(void (^)(NSError *error))failure;

- (void)peauseWithHairModel:(ZZDownloadHairInfoModel *)hairModel complition:(void(^)(void))complition;

#pragma mark - shoe
- (BOOL)isLoadShoeModelWithShoeId:(NSString *)shoeId;

- (void)loadDataWithShoeModel:(ZZDownloadShoeInfoModel *)shoeModel progress:(void (^)(CGFloat progress))progress complition:(void (^)(NSString *modelId))complition failure:(void (^)(NSError *error))failure;

- (void)peauseWithShoeModel:(ZZDownloadShoeInfoModel *)shoeModel complition:(void(^)(void))complition;

#pragma mark - action
- (BOOL)isLoadActionModelWithActionId:(NSString *)actionId;

- (void)loadDataWithActionModel:(ZZPoseModel *)actionModel progress:(void (^)(CGFloat progress))progress complition:(void (^)(NSString *modelId))complition failure:(void (^)(NSError *error))failure;

- (void)peauseWithActionModel:(ZZPoseModel *)actionModel complition:(void(^)(void))complition;

#pragma mark - 清除缓存
- (void)cleanSourceDataComplition:(void (^)(void))complition;

#pragma mark - 加入试衣篮
- (void)addBasketWithGender:(NSString *)gender goodsUuid:(NSString *)goodsUuid worksId:(NSString *)worksId success:(void (^)(void))success failure:(void (^)(NSError *error))failure;

#pragma mark - 批量获取下载信息
- (void)getBatchDownloadInfoWithPramaAry:(NSArray *)pramaAry success:(void (^)(NSArray *downloadInfoArr))success failure:(void (^)(NSError *error))failure;

#pragma mark - 批量下载衣服(穿搭)

- (void)isWearDownloadWithDetailWearModel:(ZZDetailWearModel *)detailWearModel result:(void (^)(BOOL isClothDownload,NSArray <ZZGetBatchClothDownloadInfoPramaModel *>*notLoadAry,BOOL isWearModelDownload)) result;

- (void)loadBatchClothWithClothDownloadInfoArr:(NSArray *)clothDownloadInfoArr wearId:(NSString *)wearId wearModelPath:(NSString *)wearModelPath wearModelSize:(NSString *)wearModelSize  progress:(void (^)(CGFloat progress))progress complition:(void (^)(NSString *modelId))complition failure:(void (^)(NSError *error))failure;

- (void)peauseBatchClothWithWearId:(NSString *)wearId complition:(void(^)(void))complition;

@end

NS_ASSUME_NONNULL_END
