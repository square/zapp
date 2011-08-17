//
//  ZappSimulatorController.m
//  Zapp
//
//  Created by Jim Puls on 8/16/11.
//  Copyright (c) 2011 Square, Inc. All rights reserved.
//

#import "ZappSimulatorController.h"
#include <sys/stat.h>

@interface ZappSimulatorController ()

@property (copy) ZappResultBlock completionBlock;
@property (strong) NSFileHandle *fileHandle;
@property (strong) DTiPhoneSimulatorSession *session;
@property (copy) ZappOutputBlock outputBlock;

- (void)readNewOutput;

@end

@implementation ZappSimulatorController

@synthesize appURL;
@synthesize arguments;
@synthesize completionBlock;
@synthesize environment;
@synthesize fileHandle;
@synthesize platform;
@synthesize sdk;
@synthesize session;
@synthesize simulatorOutputPath;
@synthesize outputBlock;

- (BOOL)launchSessionWithOutputBlock:(ZappOutputBlock)theOutputBlock completionBlock:(ZappResultBlock)theCompletionBlock;
{
    NSString *path = self.appURL.path;
    DTiPhoneSimulatorApplicationSpecifier *specifier = [DTiPhoneSimulatorApplicationSpecifier specifierWithApplicationPath:path];
    if (!specifier) {
        return NO;
    }
    
    self.outputBlock = theOutputBlock;
    self.completionBlock = theCompletionBlock;
    
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

    [[NSOperationQueue mainQueue] addOperationWithBlock:^() {
        NSError *error = nil;
        [session requestStartWithConfig:config timeout:30.0 error:&error];
        [self readNewOutput];
    }];
    
    return YES;
}

#pragma mark DTiPhoneSimulatorSessionDelegate

- (void)session:(DTiPhoneSimulatorSession *)session didStart:(BOOL)started withError:(NSError *)error {
    NSLog(@"started: %@", error);
}

- (void)session:(DTiPhoneSimulatorSession *)session didEndWithError:(NSError *)error {
    NSLog(@"ended: %@", error);
    self.session = nil;
    self.completionBlock(error != nil);
}

#pragma mark Private methods

- (void)readNewOutput;
{
    NSData *outputData = [self.fileHandle readDataToEndOfFile];
    self.outputBlock([[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding]);
    if (self.session) {
        [self performSelector:@selector(readNewOutput) withObject:nil afterDelay:1.0];
    } else {
        [self.fileHandle closeFile];
    }

}

@end
