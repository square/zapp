//
//  ZappSimulatorController.h
//  Zapp
//
//  Created by Jim Puls on 8/16/11.
//  Licensed to Square, Inc. under one or more contributor license agreements.
//  See the LICENSE file distributed with this work for the terms under
//  which Square, Inc. licenses this file to you.

#import <Foundation/Foundation.h>
#import "iPhoneSimulatorRemoteClient.h"

typedef enum {
    ZappSimulatorControllerPlatformiPhone = 1,
    ZappSimulatorControllerPlatformiPad = 2
} ZappSimulatorControllerPlatform;

@interface ZappSimulatorController : NSObject <DTiPhoneSimulatorSessionDelegate>

@property (strong) NSURL *appURL;
@property (strong) NSArray *arguments;
@property (strong) NSDictionary *environment;
@property ZappSimulatorControllerPlatform platform;
@property (strong) NSString *sdk;
@property (strong) NSString *simulatorOutputPath;
@property (strong) NSURL *videoOutputURL;

- (BOOL)launchSessionWithOutputBlock:(ZappOutputBlock)theOutputBlock completionBlock:(ZappResultBlock)theCompletionBlock;

@end
