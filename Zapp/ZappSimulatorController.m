//
//  ZappSimulatorController.m
//  Zapp
//
//  Created by Jim Puls on 8/16/11.
//  Licensed to Square, Inc. under one or more contributor license agreements.
//  See the LICENSE file distributed with this work for the terms under
//  which Square, Inc. licenses this file to you.

#import "ZappSimulatorController.h"
#import "ZappVideoController.h"
#include <sys/stat.h>

@interface ZappSimulatorController ()

@property (copy) ZappResultBlock completionBlock;
@property (strong) NSFileHandle *fileHandle;
@property (strong) DTiPhoneSimulatorSession *session;
@property (copy) ZappOutputBlock outputBlock;
@property NSInteger consecutiveBlankReads;
@property BOOL hasSuccessfulRead;
@property (strong) ZappVideoController *videoController;
@property (weak) NSOperationQueue *callingQueue;

- (void)readNewOutput;
- (void)clearSession;

@end

@implementation ZappSimulatorController

@synthesize appURL;
@synthesize arguments;
@synthesize callingQueue;
@synthesize completionBlock;
@synthesize consecutiveBlankReads;
@synthesize environment;
@synthesize fileHandle;
@synthesize hasSuccessfulRead;
@synthesize platform;
@synthesize sdk;
@synthesize session;
@synthesize simulatorOutputPath;
@synthesize outputBlock;
@synthesize videoController;
@synthesize videoOutputURL;

- (BOOL)launchSessionWithOutputBlock:(ZappOutputBlock)theOutputBlock completionBlock:(ZappResultBlock)theCompletionBlock;
{
    NSAssert(![NSThread isMainThread], @"%s called from main thread", _cmd);
    NSString *path = self.appURL.path;
    DTiPhoneSimulatorApplicationSpecifier *specifier = [DTiPhoneSimulatorApplicationSpecifier specifierWithApplicationPath:path];
    if (!specifier) {
        NSLog(@"Could not load application specifier for '%@'", path);
        return NO;
    }
    
    self.outputBlock = theOutputBlock;
    self.completionBlock = theCompletionBlock;
    self.callingQueue = [NSOperationQueue currentQueue];
    self.hasSuccessfulRead = NO;
    self.consecutiveBlankReads = 0;
    
    DTiPhoneSimulatorSystemRoot *simulator = [DTiPhoneSimulatorSystemRoot rootWithSDKVersion:self.sdk];
    DTiPhoneSimulatorSessionConfig *config = [DTiPhoneSimulatorSessionConfig new];
    
    config.applicationToSimulateOnStart = specifier;
    config.simulatedSystemRoot = simulator;
    config.simulatedDeviceFamily = [NSNumber numberWithInteger:self.platform];
    config.simulatedApplicationShouldWaitForDebugger = NO;
    config.simulatedApplicationLaunchArgs = self.arguments;
    config.simulatedApplicationLaunchEnvironment = self.environment;
    config.localizedClientName = [[NSRunningApplication currentApplication] localizedName];
    config.simulatedApplicationStdOutPath = self.simulatorOutputPath;
    config.simulatedApplicationStdErrPath = self.simulatorOutputPath;
    
    self.session = [DTiPhoneSimulatorSession new];
    session.delegate = self;

    self.fileHandle = [NSFileHandle fileHandleForReadingAtPath:self.simulatorOutputPath];
    [fileHandle seekToEndOfFile];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    NSURL *simulatorAppsURL = [[fileManager URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:&error] URLByAppendingPathComponent:@"iPhone Simulator/4.3.2/Applications"];
    NSAssert(!error, @"Got an error finding the simulator applications folder");

    if ([fileManager fileExistsAtPath:simulatorAppsURL.path]) {
        [fileManager removeItemAtURL:simulatorAppsURL error:&error];
        NSAssert(!error, @"Got an error deleting the simulator applications folder");
    }

    NSURL *simulatorURL = [NSURL fileURLWithPath:simulator.sdkRootPath];
    simulatorURL = [[simulatorURL URLByDeletingLastPathComponent] URLByDeletingLastPathComponent];
    simulatorURL = [[simulatorURL URLByAppendingPathComponent:@"Applications"] URLByAppendingPathComponent:@"iPhone Simulator.app"];
    
    [[NSOperationQueue mainQueue] addOperationWithBlock:^() {
        NSError *error = nil;
        [[NSWorkspace sharedWorkspace] launchApplicationAtURL:simulatorURL options:NSWorkspaceLaunchDefault configuration:nil error:&error];
        if (![session requestStartWithConfig:config timeout:30.0 error:&error]) {
            NSLog(@"Could not start simulator session: %@", error);
            return;
        }
        
        NSArray *runningApplications = [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.apple.iphonesimulator"];
        NSRunningApplication *simulator = [runningApplications lastObject];
        [simulator activateWithOptions:(NSApplicationActivateAllWindows | NSApplicationActivateIgnoringOtherApps)];
        
        [self readNewOutput];
    }];
    
    return YES;
}

#pragma mark DTiPhoneSimulatorSessionDelegate

- (void)session:(DTiPhoneSimulatorSession *)session didStart:(BOOL)started withError:(NSError *)error {
    if (self.videoOutputURL) {
        NSLog(@"started: %@", error);
        self.videoController = [ZappVideoController new];
        self.videoController.outputURL = self.videoOutputURL;
        [self.videoController start];
    }
}

- (void)session:(DTiPhoneSimulatorSession *)session didEndWithError:(NSError *)error {
    NSLog(@"ended: %@", error);
    [self clearSession];
    [self.callingQueue addOperationWithBlock:^{
        self.completionBlock(error != nil);
    }];
}

#pragma mark Private methods

+ (void)killSimulator;
{
    NSTask *killTask = [NSTask new];
    killTask.launchPath = @"/usr/bin/killall";
    killTask.arguments = [NSArray arrayWithObject:@"iPhone Simulator"];
    [killTask launch];
    [killTask waitUntilExit];
}

- (void)clearSession;
{
    self.session.delegate = nil;
    self.session = nil;    
    [self.videoController stop];
    self.videoController = nil;
    [ZappSimulatorController killSimulator];
}

- (void)readNewOutput;
{
    if (!self.session) {
        return;
    }
    
    NSData *outputData = [self.fileHandle readDataToEndOfFile];
    if (outputData.length) {
        self.outputBlock([[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding]);
        self.consecutiveBlankReads = 0;
        self.hasSuccessfulRead = YES;
    } else {
        self.consecutiveBlankReads++;
        if (self.consecutiveBlankReads > 30) {
            if (self.hasSuccessfulRead) {
                [self session:self.session didEndWithError:[NSError errorWithDomain:NSStringFromClass([self class]) code:1 userInfo:nil]];
            } else {
                [self session:self.session didEndWithError:[NSError errorWithDomain:NSStringFromClass([self class]) code:2 userInfo:nil]];
            }
        }
    }
    if (self.session) {
        [self performSelector:@selector(readNewOutput) withObject:nil afterDelay:1.0];
    } else {
        [self.fileHandle closeFile];
    }

}

@end
