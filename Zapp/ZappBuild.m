//
//  ZappBuild.m
//  Zapp
//
//  Created by Jim Puls on 8/5/11.
//  Copyright (c) 2011 Square, Inc. All rights reserved.
//

#import "ZappBuild.h"


@interface ZappBuild ()

@property (nonatomic, readonly) NSURL *buildLogURL;
@property (nonatomic, strong, readwrite) NSArray logLines;

- (void)appendLogLine:(NSString *)logLine;

@end

@implementation ZappBuild

@dynamic endTimestamp;
@dynamic latestRevision;
@dynamic platform;
@dynamic repository;
@dynamic scheme;
@dynamic startTimestamp;
@dynamic status;
@synthesize commitLog;
@synthesize logLines;

#pragma mark Accessors

- (NSString *)commitLog;
{
    if (!commitLog) {
        [self.repository runCommand:GitCommand withArguments:[NSArray arrayWithObjects:@"log", @"--pretty=oneline", @"-1", nil] completionBlock:^(NSString *newLog) {
            self.commitLog = newLog;
        }];
    }
    return commitLog;
}

#pragma mark Derived properties

- (NSURL *)buildLogURL;
{
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    NSArray *supportURLs = [fileManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask];
    NSURL *storageURL = [[supportURLs objectAtIndex:0] URLByAppendingPathComponent:[[NSRunningApplication currentApplication] localizedName]];
    NSString *uuid = [[[[self objectID] URIRepresentation] path] stringByReplacingOccurrencesOfString:@"/" withString:@"-"];
    return [storageURL URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.log", uuid]];
}

- (NSString *)description;
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
    [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
    
    NSString *revision = [self.latestRevision substringToIndex:MIN(6, self.latestRevision.length)];
    
    if (self.status == ZappBuildStatusPending) {
        return [NSString stringWithFormat:@"%@: %@", self.statusDescription, revision];
    }
    
    return [NSString stringWithFormat:@"%@: %@ on %@", self.statusDescription, revision, [dateFormatter stringFromDate:self.startDate]];
}

+ (NSSet *)keyPathsForValuesAffectingDescription;
{
    return [NSSet setWithObjects:@"startTimestamp", @"status", @"latestRevision", nil];
}

- (NSDate *)endDate;
{
    return [NSDate dateWithTimeIntervalSinceReferenceDate:self.endTimestamp];
}

- (void)setEndDate:(NSDate *)endDate;
{
    self.endTimestamp = [endDate timeIntervalSinceReferenceDate];
}

+ (NSSet *)keyPathsForValuesAffectingEndDate;
{
    return [NSSet setWithObject:@"endTimestamp"];
}

- (NSArray *)logLines;
{
    [self willAccessValueForKey:@"logLines"];
    if (!logLines) {
        NSString *path = self.buildLogURL.path;
        [[ZappRepository sharedBackgroundQueue] addOperationWithBlock:^() {
            NSString *fileContents = [NSString stringWithContentsOfFile:path usedEncoding:NULL error:NULL];
            if (!fileContents) {
                return;
            }

            NSArray *newLogLines = [fileContents componentsSeparatedByString:@"\n"];
            [[NSOperationQueue mainQueue] addOperationWithBlock:^() {
                self.logLines = newLogLines;
            }];
        }];
    }
    [self didAccessValueForKey:@"logLines"];
    return logLines;
}

- (NSDate *)startDate;
{
    return [NSDate dateWithTimeIntervalSinceReferenceDate:self.startTimestamp];
}

- (void)setStartDate:(NSDate *)startDate;
{
    self.startTimestamp = [startDate timeIntervalSinceReferenceDate];
}

+ (NSSet *)keyPathsForValuesAffectingStartDate;
{
    return [NSSet setWithObject:@"startTimestamp"];
}

- (NSString *)statusDescription;
{
    switch (self.status) {
        case ZappBuildStatusPending: return ZappLocalizedString(@"Pending");
        case ZappBuildStatusRunning: return ZappLocalizedString(@"Running");
        case ZappBuildStatusFailed: return ZappLocalizedString(@"Failed");
        case ZappBuildStatusSucceeded: return ZappLocalizedString(@"Succeeded");
        default: break;
    }
    return nil;
}

+ (NSSet *)keyPathsForValuesAffectingStatusDescription;
{
    return [NSSet setWithObject:@"status"];
}

#pragma mark ZappBuild

- (void)startWithCompletionBlock:(void (^)(void))completionBlock;
{
    self.status = ZappBuildStatusRunning;
    self.startDate = [NSDate date];
    self.scheme = self.repository.lastScheme;
    self.platform = self.repository.lastPlatform;
    
    NSArray *arguments = [NSArray arrayWithObjects:@"-workspace", self.repository.workspacePath, @"-sdk", [NSString stringWithFormat:@"iphonesimulator%@", [self.platform objectForKey:@"version"]], @"-scheme", self.scheme, @"ARCHS=i386", @"ONLY_ACTIVE_ARCH=NO", nil];
    
    self.logLines = nil;
    ZappRepository *repository = self.repository;
    [[ZappRepository sharedBackgroundQueue] addOperationWithBlock:^() {
        NSString *errorOutput = nil;
        NSError *error = nil;
        [[NSFileManager defaultManager] createFileAtPath:self.buildLogURL.path contents:[NSData data] attributes:nil];
        NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingToURL:self.buildLogURL error:&error];
        NSLog(@"Opened file handle %@; error was %@", fileHandle, error);
        int exitStatus = [repository runCommandAndWait:XcodebuildCommand withArguments:arguments errorOutput:&errorOutput outputBlock:^(NSString *output) {
            [fileHandle writeData:[output dataUsingEncoding:NSUTF8StringEncoding]];
            NSArray *newLogLines = [output componentsSeparatedByString:@"\n"];
            [[NSOperationQueue mainQueue] addOperationWithBlock:^() {
                for (NSString *line in newLogLines) {
                    [self appendLogLine:line];
                }
            }];
        }];
        [fileHandle writeData:[errorOutput dataUsingEncoding:NSUTF8StringEncoding]];
        [fileHandle closeFile];
        NSArray *newLogLines = [errorOutput componentsSeparatedByString:@"\n"];
        [[NSOperationQueue mainQueue] addOperationWithBlock:^() {
            for (NSString *line in newLogLines) {
                [self appendLogLine:line];
            }
            self.status = exitStatus > 0 ? ZappBuildStatusFailed : ZappBuildStatusSucceeded;
            self.endDate = [NSDate date];
            completionBlock();
        }];
    }];
}

- (void)appendLogLine:(NSString *)logLine;
{
    if (![logLine length]) {
        return;
    }

    NSMutableArray *mutableLogLines = (NSMutableArray *)self.logLines;
    [self willChangeValueForKey:@"logLines"];
    if (![mutableLogLines isKindOfClass:[NSMutableArray class]]) {
        mutableLogLines = [NSMutableArray arrayWithArray:self.logLines];
        self.logLines = mutableLogLines;
    }
    [mutableLogLines addObject:logLine];
    [self didChangeValueForKey:@"logLines"];
}

@end
