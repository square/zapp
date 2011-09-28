//
//  ZappRepository.h
//  Zapp
//
//  Created by Jim Puls on 8/5/11.
//  Licensed to Square, Inc. under one or more contributor license agreements.
//  See the LICENSE file distributed with this work for the terms under
//  which Square, Inc. licenses this file to you.

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


extern NSString *const GitCommand;
extern NSString *const XcodebuildCommand;
extern NSString *const GitFetchSubcommand;


@class ZappBuild;


@interface ZappRepository : NSManagedObject

+ (NSOperationQueue *)sharedBackgroundQueue;

@property (nonatomic, strong) NSString *abbreviation;
@property (nonatomic, strong) NSSet *builds;
@property (nonatomic, strong, readonly) NSArray *branches;
@property (nonatomic) BOOL clonedAlready;
@property (nonatomic, strong) NSString *lastBranch;
@property (nonatomic, strong) NSDictionary *lastPlatform;
@property (nonatomic, strong) NSString *lastScheme;
@property (nonatomic) ZappBuildStatus latestBuildStatus;
@property (nonatomic, strong) NSURL *localURL;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong, readonly) NSArray *platforms;
@property (nonatomic, strong) NSURL *remoteURL;
@property (nonatomic, strong, readonly) NSArray *schemes;
@property (nonatomic, strong, readonly) NSString *workspacePath;
@property (nonatomic, readonly) NSImage *statusImage;
@property (nonatomic, strong, readonly) NSFetchRequest *latestBuildsFetchRequest;

- (ZappBuild *)createNewBuild;
- (void)runCommand:(NSString *)command withArguments:(NSArray *)arguments completionBlock:(ZappOutputBlock)block;
- (int)runCommandAndWait:(NSString *)command withArguments:(NSArray *)arguments errorOutput:(NSString **)errorString outputBlock:(void (^)(NSString *))block;

@end


@interface ZappRepository (CoreDataGeneratedAccessors)

- (void)addBuildsObject:(ZappBuild *)value;
- (void)removeBuildsObject:(ZappBuild *)value;
- (void)addBuilds:(NSSet *)values;
- (void)removeBuilds:(NSSet *)values;

@end
