//
//  ZappRepository.m
//  Zapp
//
//  Created by Jim Puls on 8/5/11.
//  Copyright (c) 2011 Square, Inc. All rights reserved.
//

#import "ZappRepository.h"
#import "ZappSSHURLFormatter.h"


static NSOperationQueue *ZappRepositoryBackgroundQueue = nil;
NSString *const GitCommand = @"/usr/bin/git";
NSString *const XcodebuildCommand = @"/usr/bin/xcodebuild";


@interface ZappRepository ()

@property (nonatomic, strong, readwrite) NSArray *platforms;
@property (nonatomic, strong, readwrite) NSArray *schemes;

- (void)registerObservers;
- (void)unregisterObservers;

@end

@implementation ZappRepository

@dynamic builds;
@dynamic clonedAlready;
@dynamic lastPlatform;
@dynamic lastScheme;
@dynamic localURL;
@dynamic name;
@dynamic remoteURL;

@synthesize platforms;
@synthesize schemes;

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

- (ZappBuild *)latestBuild;
{
    NSSortDescriptor *descriptor = [NSSortDescriptor sortDescriptorWithKey:@"endDate" ascending:NO];
    NSArray *descriptors = [NSArray arrayWithObject:descriptor];
    NSArray *orderedBuilds = [self.builds sortedArrayUsingDescriptors:descriptors];
    return orderedBuilds.count ? [orderedBuilds objectAtIndex:0] : nil;
}

- (NSArray *)platforms;
{
    if (!platforms) {
        [self runCommand:XcodebuildCommand withArguments:[NSArray arrayWithObject:@"-showsdks"] completionBlock:^(NSString *output) {
            NSRegularExpression *platformRegex = [NSRegularExpression regularExpressionWithPattern:@"Simulator - iOS (\\S+)" options:0 error:NULL];
            NSMutableArray *newPlatforms = [NSMutableArray array];
            [platformRegex enumerateMatchesInString:output options:0 range:NSMakeRange(0, output.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
                NSString *version = [output substringWithRange:[result rangeAtIndex:1]];
                [newPlatforms addObject:[NSDictionary dictionaryWithObjectsAndKeys:version, @"version", @"iphone", @"device", [NSString stringWithFormat:ZappLocalizedString(@"iPhone %@ Simulator"), version], @"description", nil]];
                [newPlatforms addObject:[NSDictionary dictionaryWithObjectsAndKeys:version, @"version", @"ipad", @"device", [NSString stringWithFormat:ZappLocalizedString(@"iPad %@ Simulator"), version], @"description", nil]];
            }];
            self.platforms = newPlatforms;
        }];
    }
    return platforms;
}

- (NSArray *)schemes;
{
    if (!schemes) {
        [self runCommand:XcodebuildCommand withArguments:[NSArray arrayWithObject:@"-list"] completionBlock:^(NSString *output) {
            NSRange schemeRange = [output rangeOfString:@"Schemes:\n"];
            if (schemeRange.location == NSNotFound) {
                return;
            }
            NSMutableArray *newSchemes = [NSMutableArray array];
            NSUInteger start = schemeRange.location + schemeRange.length;
            NSRegularExpression *schemeRegex = [NSRegularExpression regularExpressionWithPattern:@"^\\s+(.+)$" options:NSRegularExpressionAnchorsMatchLines error:NULL];
            [schemeRegex enumerateMatchesInString:output options:0 range:NSMakeRange(start, output.length - start) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
                [newSchemes addObject:[output substringWithRange:[result rangeAtIndex:1]]];
            }];
            self.schemes = newSchemes;
        }];
    }
    return schemes;
}

- (NSImage *)statusImage;
{
    return [NSImage imageNamed:self.latestBuild.status == ZappBuildStatusSucceeded ? @"status-available-flat-etched" : @"status-away-flat-etched"];
}

#pragma mark ZappRepository

- (ZappBuild *)createNewBuild;
{
    ZappBuild *build = [NSEntityDescription insertNewObjectForEntityForName:@"Build" inManagedObjectContext:self.managedObjectContext];
    [self willChangeValueForKey:@"builds"];
    [self addBuildsObject:build];
    [self didChangeValueForKey:@"builds"];
    return build;
}

- (void)runCommand:(NSString *)command withArguments:(NSArray *)arguments completionBlock:(void (^)(NSString *))block;
{
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
        NSTask *task = [NSTask new];

        NSPipe *outPipe = [NSPipe new];
        NSFileHandle *outHandle = [outPipe fileHandleForReading];
        [task setStandardOutput:outPipe];
        
        NSPipe *errorPipe = [NSPipe new];
        NSFileHandle *errorHandle = [errorPipe fileHandleForReading];
        [task setStandardError:errorPipe];
        
        NSData *inData = nil;
        NSMutableData *allData = [NSMutableData data];
        
        [task setLaunchPath:command];
        [task setArguments:arguments];
        [task setCurrentDirectoryPath:self.localURL.path];
        
        NSLog(@"Running git command\n%@ in\n%@", command, self.localURL);
        
        [task launch];
        
        while ((inData = [outHandle availableData]) && [inData length]) {
            [allData appendData:inData];
        }
        
        [task waitUntilExit];
        
        NSString *finalString = [[NSString alloc] initWithData:allData encoding:NSUTF8StringEncoding];
        finalString = [finalString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        NSData *errorData = [errorHandle readDataToEndOfFile];
        if (errorData.length) {
            NSString *errorString = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding];
            if ([errorString rangeOfString:@"Not a git repository"].location != NSNotFound) {
                self.clonedAlready = NO;
                return;
            }
        }
        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            self.clonedAlready = YES;
            block(finalString);
        }];
    }];
}

#pragma mark NSManagedObject

- (void)awakeFromFetch;
{
    [super awakeFromFetch];
    [self registerObservers];
}

- (void)awakeFromInsert;
{
    [super awakeFromInsert];
    [self registerObservers];
}

- (void)didTurnIntoFault;
{
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
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark Private methods

- (void)registerObservers;
{
    [self addObserver:self forKeyPath:@"localURL" options:NSKeyValueObservingOptionNew context:NULL];
}

- (void)unregisterObservers;
{
    [self removeObserver:self forKeyPath:@"localURL"];
}

@end
