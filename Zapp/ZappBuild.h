//
//  ZappBuild.h
//  Zapp
//
//  Created by Jim Puls on 8/5/11.
//  Copyright (c) 2011 Square, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


typedef enum {
    ZappBuildStatusPending,
    ZappBuildStatusRunning,
    ZappBuildStatusSucceeded,
    ZappBuildStatusFailed,
    ZappBuildStatusCount
} ZappBuildStatus;


@class ZappRepository;

@interface ZappBuild : NSManagedObject

@property (nonatomic, strong) NSString *commitLog;
@property (nonatomic, readonly) NSString *description;
@property (nonatomic, copy) NSDate *endDate;
@property (nonatomic) NSTimeInterval endTimestamp;
@property (nonatomic, strong) NSString *latestRevision;
@property (nonatomic, strong, readonly) NSArray *logLines;
@property (nonatomic, strong) NSString *platform;
@property (nonatomic, strong) ZappRepository *repository;
@property (nonatomic, strong) NSString *scheme;
@property (nonatomic, copy) NSDate *startDate;
@property (nonatomic) NSTimeInterval startTimestamp;
@property (nonatomic) ZappBuildStatus status;
@property (nonatomic, readonly) NSString *statusDescription;

- (void)startWithCompletionBlock:(void (^)(void))completionBlock;

@end
