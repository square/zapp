//
//  ZappBuild.h
//  Zapp
//
//  Created by Jim Puls on 8/5/11.
//  Licensed to Square, Inc. under one or more contributor license agreements.
//  See the LICENSE file distributed with this work for the terms under
//  which Square, Inc. licenses this file to you.

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@class ZappRepository;


@interface ZappBuild : NSManagedObject

@property (nonatomic, strong) NSString *branch;
@property (nonatomic, strong) NSString *commitLog;
@property (nonatomic, readonly) NSString *description;
@property (nonatomic, strong) NSDate *endTimestamp;
@property (nonatomic, strong) NSString *latestRevision;
@property (nonatomic, strong, readonly) NSArray *logLines;
@property (nonatomic, strong) NSDictionary *platform;
@property (nonatomic, strong) ZappRepository *repository;
@property (nonatomic, strong) NSString *scheme;
@property (nonatomic, strong) NSDate *startTimestamp;
@property (nonatomic) ZappBuildStatus status;
@property (nonatomic, readonly) NSString *statusDescription;
@property (nonatomic, readonly) NSString *feedDescription;
@property (nonatomic, readonly) NSURL *buildLogURL;
@property (nonatomic, readonly) NSURL *buildVideoURL;
@property (nonatomic, readonly) NSString *abbreviatedLatestRevision;

@property (nonatomic, readonly) ZappBuild *previousBuild;
@property (nonatomic, readonly) ZappBuild *previousSuccessfulBuild;

@property (nonatomic) double progress;
@property (nonatomic, readonly) NSString *activityTitle;

- (void)startWithCompletionBlock:(void (^)(void))completionBlock;
- (void)cancel;

@end
