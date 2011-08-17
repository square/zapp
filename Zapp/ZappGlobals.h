//
//  ZappGlobals.h
//  Zapp
//
//  Created by Jim Puls on 7/30/11.
//  Copyright 2011 Square, Inc. All rights reserved.
//

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
