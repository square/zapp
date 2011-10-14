//
//  ZappRepository.m
//  Zapp
//
//  Created by Jim Puls on 8/5/11.
//  Licensed to Square, Inc. under one or more contributor license agreements.
//  See the LICENSE file distributed with this work for the terms under
//  which Square, Inc. licenses this file to you.

#import "ZappRepository.h"
#import "ZappSSHURLFormatter.h"


static NSOperationQueue *ZappRepositoryBackgroundQueue = nil;
NSString *const GitCommand = @"/usr/bin/git";
NSString *const XcodebuildCommand = @"/Developer/usr/bin/xcodebuild";
NSString *const GitFetchSubcommand = @"fetch";

@interface ZappRepository ()

@property (nonatomic, strong, readwrite) NSArray *branches;
@property (nonatomic, strong) NSMutableSet *enqueuedCommands;
@property (nonatomic, strong, readwrite) NSArray *platforms;
@property (nonatomic, strong, readwrite) NSArray *schemes;
@property (nonatomic, strong, readwrite) NSFetchRequest *latestBuildsFetchRequest;

- (void)registerObservers;
- (void)unregisterObservers;

@end

@implementation ZappRepository

@dynamic abbreviation;
@dynamic builds;
@dynamic clonedAlready;
@dynamic lastBranch;
@dynamic lastPlatform;
@dynamic lastScheme;
@dynamic latestBuildStatus;
@dynamic localURL;
@dynamic name;
@dynamic remoteURL;

@synthesize branches;
@synthesize enqueuedCommands;
@synthesize platforms;
@synthesize schemes;
@synthesize latestBuildsFetchRequest;

#pragma mark Class methods

+ (void)initialize;
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        ZappRepositoryBackgroundQueue = [NSOperationQueue new];
    });
}

+ (NSOperationQueue *)sharedBackgroundQueue;
{
    return ZappRepositoryBackgroundQueue;
}

#pragma mark Derived properties

- (NSArray *)branches;
{
    if (!branches && ![self.enqueuedCommands containsObject:@"branches"] && self.clonedAlready) {
        [self.enqueuedCommands addObject:@"branches"];
        [self runCommand:GitCommand withArguments:[NSArray arrayWithObjects:@"branch", @"-a", nil] completionBlock:^(NSString *output) {
            NSMutableArray *newBranches = [NSMutableArray array];
            NSRegularExpression *branchRegex = [NSRegularExpression regularExpressionWithPattern:@"^\\s+remotes/(.+)$" options:NSRegularExpressionAnchorsMatchLines error:NULL];
            [branchRegex enumerateMatchesInString:output options:0 range:NSMakeRange(0, output.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
                [newBranches addObject:[output substringWithRange:[result rangeAtIndex:1]]];
            }];
            self.branches = newBranches;
            if (!self.lastBranch) {
                if ([branches containsObject:@"origin/master"]) {
                    self.lastBranch = @"origin/master";
                } else {
                    self.lastBranch = [branches objectAtIndex:0];
                }
            }
            [self.enqueuedCommands removeObject:@"branches"];
        }];
    }
    return branches;
}

+ (NSSet *)keyPathsForValuesAffectingBranches;
{
    return [NSSet setWithObjects:@"localURL", @"clonedAlready", nil];
}

- (NSArray *)platforms;
{
    if (!platforms && ![self.enqueuedCommands containsObject:@"platforms"] && self.clonedAlready) {
        [self.enqueuedCommands addObject:@"platforms"];
        [self runCommand:XcodebuildCommand withArguments:[NSArray arrayWithObject:@"-showsdks"] completionBlock:^(NSString *output) {
            NSRegularExpression *platformRegex = [NSRegularExpression regularExpressionWithPattern:@"Simulator - iOS (\\S+)" options:0 error:NULL];
            NSMutableArray *newPlatforms = [NSMutableArray array];
            [platformRegex enumerateMatchesInString:output options:0 range:NSMakeRange(0, output.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
                NSString *version = [output substringWithRange:[result rangeAtIndex:1]];
                [newPlatforms addObject:[NSDictionary dictionaryWithObjectsAndKeys:version, @"version", @"iphone", @"device", [NSString stringWithFormat:ZappLocalizedString(@"iPhone %@ Simulator"), version], @"description", nil]];
                [newPlatforms addObject:[NSDictionary dictionaryWithObjectsAndKeys:version, @"version", @"ipad", @"device", [NSString stringWithFormat:ZappLocalizedString(@"iPad %@ Simulator"), version], @"description", nil]];
            }];
            self.platforms = newPlatforms;
            if (!self.lastPlatform) {
                self.lastPlatform = [self.platforms lastObject];
            }
            [self.enqueuedCommands removeObject:@"platforms"];
        }];
    }
    return platforms;
}

+ (NSSet *)keyPathsForValuesAffectingPlatforms;
{
    return [NSSet setWithObjects:@"localURL", @"clonedAlready", nil];
}

- (NSArray *)schemes;
{
    if (!schemes && ![self.enqueuedCommands containsObject:@"schemes"] && self.clonedAlready) {
        [self.enqueuedCommands addObject:@"schemes"];
        [self runCommand:XcodebuildCommand withArguments:[NSArray arrayWithObject:@"-list"] completionBlock:^(NSString *output) {
            NSRange schemeRange = [output rangeOfString:@"Schemes:\n"];
            if (schemeRange.location == NSNotFound) {
                [self.enqueuedCommands removeObject:@"schemes"];
                return;
            }
            NSMutableArray *newSchemes = [NSMutableArray array];
            NSUInteger start = schemeRange.location + schemeRange.length;
            NSRegularExpression *schemeRegex = [NSRegularExpression regularExpressionWithPattern:@"^\\s+(.+)$" options:NSRegularExpressionAnchorsMatchLines error:NULL];
            [schemeRegex enumerateMatchesInString:output options:0 range:NSMakeRange(start, output.length - start) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
                [newSchemes addObject:[output substringWithRange:[result rangeAtIndex:1]]];
            }];
            self.schemes = newSchemes;
            if (!self.lastScheme) {
                self.lastScheme = [self.schemes lastObject];
            }
            [self.enqueuedCommands removeObject:@"schemes"];
        }];
    }
    return schemes;
}

+ (NSSet *)keyPathsForValuesAffectingSchemes;
{
    return [NSSet setWithObjects:@"localURL", @"clonedAlready", nil];
}

- (NSImage *)statusImage;
{
    return [NSImage imageNamed:self.latestBuildStatus == ZappBuildStatusSucceeded ? @"greencircle" : @"redtriangle"];
}

+ (NSSet *)keyPathsForValuesAffectingStatusImage;
{
    return [NSSet setWithObject:@"latestBuildStatus"];
}

- (NSFetchRequest *)latestBuildsFetchRequest;
{
    if (!latestBuildsFetchRequest) {
        self.latestBuildsFetchRequest = [NSFetchRequest new];
        latestBuildsFetchRequest.entity = [NSEntityDescription entityForName:@"Build" inManagedObjectContext:self.managedObjectContext];
        latestBuildsFetchRequest.predicate = [NSPredicate predicateWithFormat:@"repository = %@ AND status != %d", self, ZappBuildStatusPending];
        latestBuildsFetchRequest.sortDescriptors = [NSArray arrayWithObject:[[NSSortDescriptor alloc] initWithKey:@"startTimestamp" ascending:NO]];
        latestBuildsFetchRequest.fetchLimit = 10;
    }
    return latestBuildsFetchRequest;
}

#pragma mark ZappRepository

- (ZappBuild *)createNewBuild;
{
    ZappBuild *build = [NSEntityDescription insertNewObjectForEntityForName:@"Build" inManagedObjectContext:self.managedObjectContext];
    [self willChangeValueForKey:@"latestBuild"];
    [self addBuildsObject:build];
    [self didChangeValueForKey:@"latestBuild"];
    NSError *error = nil;
    [self.managedObjectContext save:&error];
    NSAssert(!error, @"Failed to save managed object context");
    return build;
}

- (int)runCommandAndWait:(NSString *)command withArguments:(NSArray *)arguments standardInput:(id)standardInput errorOutput:(NSString **)errorString outputBlock:(void (^)(NSString *))block;
{
    NSAssert(![NSThread isMainThread], @"Can only run command and wait from a background thread");
    NSTask *task = [NSTask new];
    
    NSPipe *outPipe = [NSPipe new];
    NSFileHandle *outHandle = [outPipe fileHandleForReading];
    [task setStandardOutput:outPipe];
    
    NSPipe *errorPipe = [NSPipe new];
    NSFileHandle *errorHandle = [errorPipe fileHandleForReading];
    [task setStandardError:errorPipe];
    
    NSData *inData = nil;
    [task setLaunchPath:command];
    [task setArguments:arguments];
    [task setCurrentDirectoryPath:self.localURL.path];
    
    if (standardInput) {
        [task setStandardInput:standardInput];
    }
    
    [task launch];
    
    while ((inData = [outHandle availableData]) && [inData length]) {
        NSString *inString = [[NSString alloc] initWithData:inData encoding:NSUTF8StringEncoding];
        block(inString);
    }
    
    [task waitUntilExit];
    
    NSData *errorData = [errorHandle readDataToEndOfFile];
    if (errorString) {
        *errorString = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding];
    }
    
    if ([arguments containsObject:GitFetchSubcommand]) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            // After a fetch, clear our branches so that we re-populate the UI.
            self.branches = nil;
        }];
    }
    
    return [task terminationStatus];
}

- (void)runCommand:(NSString *)command withArguments:(NSArray *)arguments completionBlock:(void (^)(NSString *))block;
{
    [self runCommand:command withArguments:arguments standardInput:nil completionBlock:block];
}

- (void)runCommand:(NSString *)command withArguments:(NSArray *)arguments standardInput:(id)standardInput completionBlock:(void (^)(NSString *))block;
{
    NSAssert([NSThread isMainThread], @"Can only spawn a command from the main thread");
    if (!self.localURL) {
        self.clonedAlready = NO;
        return;
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDirectory = NO;
    if (![fileManager fileExistsAtPath:self.localURL.path isDirectory:&isDirectory] || !isDirectory) {
        self.clonedAlready = NO;
        return;
    }
    
    [ZappRepositoryBackgroundQueue addOperationWithBlock:^() {
        NSString *errorString = nil;
        
        NSMutableString *finalString = [NSMutableString string];
        [self runCommandAndWait:command withArguments:arguments standardInput:standardInput errorOutput:&errorString outputBlock:^(NSString *inString) {
            [finalString appendString:inString];
        }];
        
        if ([command isEqualToString:GitCommand] && errorString.length) {
            if ([errorString rangeOfString:@"Not a git repository"].location != NSNotFound) {
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    self.clonedAlready = NO;
                }];
                return;
            }
        }
        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            self.clonedAlready = YES;
            block([finalString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]);
        }];
    }];
}

#pragma mark NSManagedObject

- (void)awakeFromFetch;
{
    [super awakeFromFetch];
    [self registerObservers];
    self.enqueuedCommands = [NSMutableSet set];
}

- (void)awakeFromInsert;
{
    [super awakeFromInsert];
    [self registerObservers];
    self.enqueuedCommands = [NSMutableSet set];
}

- (void)didTurnIntoFault;
{
    self.enqueuedCommands = nil;
    [self unregisterObservers];
    [super didTurnIntoFault];
}

#pragma mark NSKeyValueObserving

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context;
{
    if ([keyPath isEqualToString:@"localURL"]) {
        [self runCommand:GitCommand withArguments:[NSArray arrayWithObjects:@"remote", @"-v", nil] completionBlock:^(NSString *output) {
            NSRegularExpression *remotePattern = [[NSRegularExpression alloc] initWithPattern:@"^\\w+\\s+(\\S+)\\s+" options:0 error:NULL];
            ZappSSHURLFormatter *formatter = [[ZappSSHURLFormatter alloc] init];
            [remotePattern enumerateMatchesInString:output options:NSMatchingAnchored range:NSMakeRange(0, output.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
                NSURL *newRemoteURL = nil;
                if ([formatter getObjectValue:&newRemoteURL forString:[output substringWithRange:[result rangeAtIndex:1]] errorDescription:NULL]) {
                    self.remoteURL = newRemoteURL;
                    *stop = YES;
                }
            }];
        }];
    } else if ([keyPath isEqualToString:@"name"]) {
        self.abbreviation = [[self.name lowercaseString] stringByReplacingOccurrencesOfString:@" " withString:@"-"];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark Private methods

- (void)registerObservers;
{
    [self addObserver:self forKeyPath:@"localURL" options:NSKeyValueObservingOptionNew context:NULL];
    [self addObserver:self forKeyPath:@"name" options:NSKeyValueObservingOptionNew context:NULL];
}

- (void)unregisterObservers;
{
    [self removeObserver:self forKeyPath:@"localURL"];
    [self removeObserver:self forKeyPath:@"name"];
}

@end
