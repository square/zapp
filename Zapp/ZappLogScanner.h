//
//  ZappLogScanner.h
//  Zapp
//
//  Created by Lawrence Forooghian on 28/11/2011.
//  Copyright (c) 2011 Square, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ZappLogScanner : NSObject

@property (nonatomic, strong) NSArray *logLines;

// Gives an array of NSStrings, each of which describes a failed KIF scenario,
// giving its description and failing error.
@property (nonatomic, readonly) NSArray *arrayOfKIFFailureSummaries;

@end
