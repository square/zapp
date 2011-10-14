//
//  ZappBuild.m
//  Zapp
//
//  Created by Jim Puls on 8/5/11.
//  Licensed to Square, Inc. under one or more contributor license agreements.
//  See the LICENSE file distributed with this work for the terms under
//  which Square, Inc. licenses this file to you.

#import "ZappBuild.h"
#import "ZappSimulatorController.h"


@interface ZappBuild ()

@property (nonatomic, strong, readwrite) NSArray logLines;
@property (nonatomic, strong) ZappSimulatorController *simulatorController;

- (void)appendLogLines:(NSString *)newLogLinesString;
- (NSURL *)appSupportURLWithExtension:(NSString *)extension;

@end

@implementation ZappBuild

@dynamic branch;
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
        [self.repository runCommand:GitCommand withArguments:[NSArray arrayWithObjects:@"log", @"--pretty=oneline", @"-1", self.latestRevision, nil] completionBlock:^(NSString *newLog) {
            self.commitLog = newLog;
        }];
    }
    return commitLog;
}

#pragma mark Derived properties

- (NSURL *)appSupportURLWithExtension:(NSString *)extension;
{
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    NSArray *supportURLs = [fileManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask];
    NSURL *storageURL = [[supportURLs objectAtIndex:0] URLByAppendingPathComponent:[[NSRunningApplication currentApplication] localizedName]];
    NSString *uniqueID = [[[[self objectID] URIRepresentation] path] stringByReplacingOccurrencesOfString:@"/" withString:@"-"];
    return [storageURL URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", uniqueID, extension]];
}

- (NSURL *)buildLogURL;
{
    return [self appSupportURLWithExtension:@"log"];
}

- (NSURL *)buildVideoURL;
{
    return [self appSupportURLWithExtension:@"mov"];
}

- (NSString *)feedDescription;
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
    [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
    
    NSString *revision = [self.latestRevision substringToIndex:MIN(6, self.latestRevision.length)];
    
    NSString *statusDescription = nil;
    switch (self.status) {
        case ZappBuildStatusPending: statusDescription = ZappLocalizedString(@"pending"); break;
        case ZappBuildStatusRunning: statusDescription = ZappLocalizedString(@"running"); break;
        case ZappBuildStatusFailed: statusDescription = ZappLocalizedString(@"failure"); break;
        case ZappBuildStatusSucceeded: statusDescription = ZappLocalizedString(@"success"); break;
        default: break;
    }

    
    return [NSString stringWithFormat:@"Built %@ on %@: %@", revision, [dateFormatter stringFromDate:self.startDate], statusDescription];
}

+ (NSSet *)keyPathsForValuesAffectingFeedDescription;
{
    return [NSSet setWithObjects:@"startTimestamp", @"status", @"latestRevision", nil];
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
    self.branch = self.repository.lastBranch;
    
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
        
        BOOL (^runGitCommandWithArguments)(NSArray *) = ^(NSArray *arguments) {
            NSString *errorOutput = nil;
            NSLog(@"running %@ %@", GitCommand, [arguments componentsJoinedByString:@" "]);
            int exitStatus = [repository runCommandAndWait:GitCommand withArguments:arguments errorOutput:&errorOutput outputBlock:^(NSString *output) {
                [fileHandle writeData:[output dataUsingEncoding:NSUTF8StringEncoding]];
                [self appendLogLines:output];
            }];
            [fileHandle writeData:[errorOutput dataUsingEncoding:NSUTF8StringEncoding]];
            [self appendLogLines:errorOutput];
            if (exitStatus > 0) {
                callCompletionBlock(exitStatus);
                return NO;
            }
            return YES;
        };
        
        // Step 1: Update
        if (!runGitCommandWithArguments([NSArray arrayWithObjects:GitFetchSubcommand, @"--prune", nil])) { return; }
        if (!runGitCommandWithArguments([NSArray arrayWithObjects:@"checkout", self.branch, nil])) { return; }
        if (!runGitCommandWithArguments([NSArray arrayWithObjects:@"submodule", @"sync", nil])) { return; }
        if (!runGitCommandWithArguments([NSArray arrayWithObjects:@"submodule", @"update", @"--init", nil])) { return; }
        [repository runCommandAndWait:GitCommand withArguments:[NSArray arrayWithObjects:@"rev-parse", @"HEAD", nil] errorOutput:&errorOutput outputBlock:^(NSString *output) {
            [[NSOperationQueue mainQueue] addOperationWithBlock:^() {
                self.latestRevision = [output stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            }];
        }];

        // Step 2: Build
        NSArray *buildArguments = [NSArray arrayWithObjects:@"-sdk", [NSString stringWithFormat:@"iphonesimulator%@", [self.platform objectForKey:@"version"]], @"-scheme", self.scheme, @"ARCHS=i386", @"ONLY_ACTIVE_ARCH=NO", @"DSTROOT=build", @"install", nil];
        NSRegularExpression *appPathRegex = [NSRegularExpression regularExpressionWithPattern:@"^SetMode .+? \"([^\"]+\\.app)\"" options:NSRegularExpressionAnchorsMatchLines error:nil];
        exitStatus = [repository runCommandAndWait:XcodebuildCommand withArguments:buildArguments errorOutput:&errorOutput outputBlock:^(NSString *output) {
            [fileHandle writeData:[output dataUsingEncoding:NSUTF8StringEncoding]];
            [self appendLogLines:output];
            [appPathRegex enumerateMatchesInString:output options:0 range:NSMakeRange(0, output.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
                appPath = [output substringWithRange:[result rangeAtIndex:1]];
                *stop = YES;
            }];
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
        NSString __block *lastOutput = nil;
        NSRegularExpression *failureRegex = [NSRegularExpression regularExpressionWithPattern:@"KIF TESTING FINISHED: (\\d+) failure" options:0 error:NULL];
        self.simulatorController = [ZappSimulatorController new];
        self.simulatorController.sdk = [self.platform objectForKey:@"version"];
        self.simulatorController.platform = [[self.platform objectForKey:@"device"] isEqualToString:@"ipad"] ? ZappSimulatorControllerPlatformiPad : ZappSimulatorControllerPlatformiPhone;
        self.simulatorController.appURL = [self.repository.localURL URLByAppendingPathComponent:appPath];
        self.simulatorController.environment = [NSDictionary dictionaryWithObjectsAndKeys:@"1", @"KIF_AUTORUN", nil];
        self.simulatorController.simulatorOutputPath = self.buildLogURL.path;
        self.simulatorController.videoOutputURL = self.buildVideoURL;
        [self.simulatorController launchSessionWithOutputBlock:^(NSString *output) {
            [self appendLogLines:output];
            lastOutput = output;
            [failureRegex enumerateMatchesInString:output options:0 range:NSMakeRange(0, output.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
                failureCount = [output substringWithRange:[result rangeAtIndex:1]];
                *stop = YES;
            }];
        } completionBlock:^(int exitCode) {
            // exitCode is probably always going to be 0 (success) coming from the simulator. Use the failure count as our status instead.
            NSLog(@"Simulator exited with code %d, failure count is %@. Last output is %@", exitCode, failureCount, lastOutput);
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
