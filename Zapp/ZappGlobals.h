//
//  ZappGlobals.h
//  Zapp
//
//  Created by Jim Puls on 7/30/11.
//  Licensed to Square, Inc. under one or more contributor license agreements.
//  See the LICENSE file distributed with this work for the terms under
//  which Square, Inc. licenses this file to you.

#ifndef Zapp_ZappGlobals_h
#define Zapp_ZappGlobals_h

#define ZappLocalizedString(str) NSLocalizedString(str, str)
#define ZAPP_WEB_PORT 1729

typedef enum {
    ZappBuildStatusPending,
    ZappBuildStatusRunning,
    ZappBuildStatusSucceeded,
    ZappBuildStatusFailed,
    ZappBuildStatusCount
} ZappBuildStatus;

typedef enum {
    ZappNotificationOptionNever,
    ZappNotificationOptionAlways,
    ZappNotificationOptionSmart,
    ZappNotificationOptionCount
} ZappNotificationOption;

typedef void (^ZappOutputBlock)(NSString *output);
typedef void (^ZappIntermediateOutputBlock)(NSString *output, BOOL *stop);
typedef void (^ZappResultBlock)(int exitCode);

#endif
