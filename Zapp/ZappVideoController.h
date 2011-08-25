//
//  ZappVideoController.h
//  Zapp
//
//  Created by Jim Puls on 8/24/11.
//  Copyright (c) 2011 Square, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ZappVideoController : NSObject

@property (strong) NSURL *outputURL;

- (void)start;
- (void)stop;

@end
