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

typedef enum {
    ZappBuildStatusPending,
    ZappBuildStatusRunning,
    ZappBuildStatusSucceeded,
    ZappBuildStatusFailed,
    ZappBuildStatusCount
} ZappBuildStatus;

typedef void (^ZappOutputBlock)(NSString *output);
typedef void (^ZappResultBlock)(int exitCode);

#endif
