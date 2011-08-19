//
//  ZappAppDelegate.h
//  Zapp
//
//  Created by Jim Puls on 7/30/11.
//  Copyright 2011 Square, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class ZappBackgroundView;
@class ZappRepositoriesController;

@interface ZappAppDelegate : NSObject <NSApplicationDelegate, NSOutlineViewDelegate>

@property (nonatomic, strong) IBOutlet NSArrayController *buildsController;
@property (nonatomic, strong) IBOutlet NSArrayController *logController;
@property (nonatomic, strong) IBOutlet NSScrollView *logScrollView;
@property (nonatomic, strong) IBOutlet NSPopUpButton *platformPopup;
@property (nonatomic, strong) IBOutlet NSProgressIndicator *progressIndicator;
@property (nonatomic, strong) IBOutlet NSTextField *progressLabel;
@property (nonatomic, strong) IBOutlet NSWindow *progressPanel;
@property (nonatomic, strong) IBOutlet ZappRepositoriesController *repositoriesController;
@property (nonatomic, strong) IBOutlet ZappBackgroundView *searchBackgroundView;
@property (nonatomic, strong) IBOutlet NSPopUpButton *schemePopup;
@property (nonatomic, strong) IBOutlet ZappBackgroundView *sourceListBackgroundView;
@property (nonatomic, strong) IBOutlet NSTableView *sourceListView;
@property (nonatomic, strong) IBOutlet NSWindow *window;
@property (nonatomic, getter = isBuilding) BOOL building;

- (IBAction)build:(id)sender;
- (IBAction)chooseLocalPath:(id)sender;
- (IBAction)clone:(id)sender;

@end
