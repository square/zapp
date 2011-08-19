//
//  ZappBuild.m
//  Zapp
//
//  Created by Jim Puls on 8/5/11.
//  Copyright (c) 2011 Square, Inc. All rights reserved.
//

#import "ZappBuild.h"
#import "ZappSimulatorController.h"


@interface ZappBuild ()

@property (nonatomic, readonly) NSURL *buildLogURL;
@property (nonatomic, strong, readwrite) NSArray logLines;
@property (nonatomic, strong) ZappSimulatorController *simulatorController;

- (void)appendLogLines:(NSString *)newLogLinesString;

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
@synthesize simulatorController;

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
    
    NSArray *buildArguments = [NSArray arrayWithObjects:@"-workspace", self.repository.workspacePath, @"-sdk", [NSString stringWithFormat:@"iphonesimulator%@", [self.platform objectForKey:@"version"]], @"-scheme", self.scheme, @"ARCHS=i386", @"ONLY_ACTIVE_ARCH=NO", @"DSTROOT=build", @"install", nil];
    
    self.logLines = nil;
    ZappRepository *repository = self.repository;
    void (^callCompletionBlock)(int) = ^(int exitStatus) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^() {
            self.status = exitStatus != 0 ? ZappBuildStatusFailed : ZappBuildStatusSucceeded;
            NSLog(@"build complete, exit status %d", exitStatus);
            self.endDate = [NSDate date];
            self.repository.latestBuildStatus = self.status;
            completionBlock();
        }];
    };

    [[ZappRepository sharedBackgroundQueue] addOperationWithBlock:^() {
        NSString *errorOutput = nil;
        NSError *error = nil;
        [[NSFileManager defaultManager] createFileAtPath:self.buildLogURL.path contents:[NSData data] attributes:nil];
        NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingToURL:self.buildLogURL error:&error];
        NSString __block *appPath = nil;
        int exitStatus = 0;
        
        // Step 1: Build
        exitStatus = [repository runCommandAndWait:GitCommand withArguments:[NSArray arrayWithObject:@"pull"] errorOutput:&errorOutput outputBlock:^(NSString *output) {
            [fileHandle writeData:[output dataUsingEncoding:NSUTF8StringEncoding]];
            [self appendLogLines:output];
        }];
        [fileHandle writeData:[errorOutput dataUsingEncoding:NSUTF8StringEncoding]];
        [self appendLogLines:errorOutput];
        if (exitStatus > 0) {
            callCompletionBlock(exitStatus);
            return;
        }
        exitStatus = [repository runCommandAndWait:GitCommand withArguments:[NSArray arrayWithObjects:@"submodule", @"update", @"--init", nil] errorOutput:&errorOutput outputBlock:^(NSString *output) {
            [fileHandle writeData:[output dataUsingEncoding:NSUTF8StringEncoding]];
            [self appendLogLines:output];
        }];
        [fileHandle writeData:[errorOutput dataUsingEncoding:NSUTF8StringEncoding]];
        [self appendLogLines:errorOutput];
        if (exitStatus > 0) {
            callCompletionBlock(exitStatus);
            return;
        }
        exitStatus = [repository runCommandAndWait:GitCommand withArguments:[NSArray arrayWithObjects:@"rev-parse", @"HEAD", nil] errorOutput:&errorOutput outputBlock:^(NSString *output) {
            [[NSOperationQueue mainQueue] addOperationWithBlock:^() {
                self.latestRevision = [output stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            }];
        }];

        // Step 2: Build
        exitStatus = [repository runCommandAndWait:XcodebuildCommand withArguments:buildArguments errorOutput:&errorOutput outputBlock:^(NSString *output) {
            [fileHandle writeData:[output dataUsingEncoding:NSUTF8StringEncoding]];
            [self appendLogLines:output];
            if (!appPath) {
                NSRange appPathRange = [output rangeOfString:@"\"([^\"]+)\\.app\"" options:NSRegularExpressionSearch];
                if (appPathRange.location != NSNotFound) {
                    appPathRange.location++;
                    appPathRange.length -= 2;
                    appPath = [output substringWithRange:appPathRange];
                }
            }
        }];
        [fileHandle writeData:[errorOutput dataUsingEncoding:NSUTF8StringEncoding]];
        [fileHandle closeFile];
        [self appendLogLines:errorOutput];
        if (exitStatus > 0) {
            callCompletionBlock(exitStatus);
            return;
        }
        
        // Step 3: Run
        NSString __block *failureCount = nil;
        NSRegularExpression *failureRegex = [NSRegularExpression regularExpressionWithPattern:@"KIF TESTING FINISHED: (\\d+) failure" options:0 error:NULL];
        self.simulatorController = [ZappSimulatorController new];
        self.simulatorController.sdk = [self.platform objectForKey:@"version"];
        self.simulatorController.platform = [[self.platform objectForKey:@"device"] isEqualToString:@"ipad"] ? ZappSimulatorControllerPlatformiPad : ZappSimulatorControllerPlatformiPhone;
        self.simulatorController.appURL = [self.repository.localURL URLByAppendingPathComponent:appPath];
        self.simulatorController.environment = [NSDictionary dictionaryWithObjectsAndKeys:@"1", @"KIF_AUTORUN", @"item", @"KIF_SCENARIO_FILTER", nil];
        self.simulatorController.simulatorOutputPath = self.buildLogURL.path;
        [self.simulatorController launchSessionWithOutputBlock:^(NSString *output) {
            [self appendLogLines:output];
            [failureRegex enumerateMatchesInString:output options:0 range:NSMakeRange(0, output.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
                failureCount = [output substringWithRange:[result rangeAtIndex:1]];
                *stop = YES;
            }];
        } completionBlock:^(int exitCode) {
            // exitCode is probably always going to be 0 (success) coming from the simulator. Use the failure count as our status instead.
            exitCode = failureCount ? [failureCount intValue] : -1;
            self.simulatorController = nil;
            callCompletionBlock(exitCode);
        }];
    }];
}

#pragma mark Private methods

- (void)appendLogLines:(NSString *)newLogLinesString;
{
    NSArray *newLogLines = [newLogLinesString componentsSeparatedByString:@"\n"];
    void (^mainQueueBlock)(void) = ^{
        NSMutableArray *mutableLogLines = (NSMutableArray *)self.logLines;
        [self willChangeValueForKey:@"logLines"];
        if (![mutableLogLines isKindOfClass:[NSMutableArray class]]) {
            mutableLogLines = [NSMutableArray arrayWithArray:self.logLines];
            self.logLines = mutableLogLines;
        }
        for (NSString *line in newLogLines) {
            if (line.length > 0) {
                [mutableLogLines addObject:line];
            }
        }
        [self didChangeValueForKey:@"logLines"];
    };
    if ([[NSOperationQueue currentQueue] isEqual:[NSOperationQueue mainQueue]]) {
        mainQueueBlock();
    } else {
        [[NSOperationQueue mainQueue] addOperationWithBlock:mainQueueBlock];
    }
}

@end
