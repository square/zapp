//
//  ZappRepository.h
//  Zapp
//
//  Created by Jim Puls on 8/5/11.
//  Copyright (c) 2011 Square, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


extern NSString *const GitCommand;
extern NSString *const XcodebuildCommand;


@class ZappBuild;


@interface ZappRepository : NSManagedObject

+ (NSOperationQueue *)sharedBackgroundQueue;

@property (nonatomic, strong) NSSet *builds;
@property (nonatomic, getter = isClonedAlready) BOOL clonedAlready;
@property (nonatomic, strong) NSString *lastPlatform;
@property (nonatomic, strong) NSString *lastScheme;
@property (nonatomic, readonly) ZappBuild *latestBuild;
@property (nonatomic, strong) NSURL *localURL;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong, readonly) NSArray *platforms;
@property (nonatomic, strong) NSURL *remoteURL;
@property (nonatomic, strong, readonly) NSArray *schemes;
@property (nonatomic, readonly) NSImage *statusImage;

- (ZappBuild *)createNewBuild;
- (void)runCommand:(NSString *)command withArguments:(NSArray *)arguments completionBlock:(void (^)(NSString *))block;

@end


@interface ZappRepository (CoreDataGeneratedAccessors)

- (void)addBuildsObject:(ZappBuild *)value;
- (void)removeBuildsObject:(ZappBuild *)value;
- (void)addBuilds:(NSSet *)values;
- (void)removeBuilds:(NSSet *)values;

@end
