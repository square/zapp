//
//  ZappAppDelegate.h
//  Zapp
//
//  Created by Jim Puls on 7/30/11.
//  Copyright 2011 Square, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ZappAppDelegate : NSObject <NSApplicationDelegate> {
    NSWindow *_window;
}

@property (strong) IBOutlet NSWindow *window;

@end
