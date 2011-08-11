//
//  ZappAppDelegate.m
//  Zapp
//
//  Created by Jim Puls on 7/30/11.
//  Copyright 2011 Square, Inc. All rights reserved.
//

#import "ZappAppDelegate.h"
#import "ZappBackgroundView.h"
#import "ZappRepositoriesController.h"
#import "ZappSSHURLFormatter.h"
#import "iPhoneSimulatorRemoteClient.h"


@interface ZappAppDelegate ()

@property (nonatomic, strong) NSMutableOrderedSet *buildQueue;
@property (nonatomic, readonly) ZappRepository *selectedRepository;

- (void)hideProgressPanel;
- (void)scheduleBuildForRepository:(ZappRepository *)repository;
- (void)showProgressPanelWithMessage:(NSString *)message;
- (void)updateSourceListBackground:(NSNotification *)notification;

@end


@implementation ZappAppDelegate

@synthesize buildQueue;
@synthesize buildsController;
@synthesize logController;
@synthesize platformPopup;
@synthesize progressIndicator;
@synthesize progressLabel;
@synthesize progressPanel;
@synthesize repositoriesController;
@synthesize schemePopup;
@synthesize searchBackgroundView;
@synthesize sourceListBackgroundView;
@synthesize sourceListView;
@synthesize window;

#pragma mark Accessors

- (ZappRepository *)selectedRepository;
{
    return [[self.repositoriesController selectedObjects] lastObject];
}

#pragma mark UI Actions

- (IBAction)build:(id)sender;
{
    [self scheduleBuildForRepository:self.selectedRepository];
}

- (IBAction)chooseLocalPath:(id)sender;
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    openPanel.canChooseFiles = NO;
    openPanel.canChooseDirectories = YES;
    openPanel.canCreateDirectories = YES;
    [openPanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            ZappRepository *currentRepository = [self.repositoriesController.selectedObjects lastObject];
            currentRepository.localURL = openPanel.URL;
        }
    }];
}

- (IBAction)clone:(id)sender;
{
    ZappRepository *repository = self.selectedRepository;
    ZappSSHURLFormatter *formatter = [ZappSSHURLFormatter new];
    NSString *formattedURL = [formatter stringForObjectValue:repository.remoteURL];
    [self showProgressPanelWithMessage:[NSString stringWithFormat:ZappLocalizedString(@"Cloning %@…"), formattedURL]];
    [repository runCommand:GitCommand withArguments:[NSArray arrayWithObjects:@"clone", formattedURL, repository.localURL.path, nil] completionBlock:^(NSString *output) {
        [self hideProgressPanel];
        [self scheduleBuildForRepository:repository];
    }];
}

#pragma mark NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification;
{
    [self updateSourceListBackground:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateSourceListBackground:) name:NSApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateSourceListBackground:) name:NSApplicationDidResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(contextDidChange:) name:NSManagedObjectContextObjectsDidChangeNotification object:nil];
    self.buildQueue = [NSMutableOrderedSet orderedSet];
    
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"endTimestamp" ascending:NO];
    self.buildsController.sortDescriptors = [NSArray arrayWithObject:sortDescriptor];

    self.searchBackgroundView.backgroundGradient = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithDeviceWhite:0.929 alpha:1.0] endingColor:[NSColor colorWithDeviceWhite:0.851 alpha:1.0]];
    self.searchBackgroundView.borderWidth = 1.0;
    self.searchBackgroundView.borderColor = [NSColor colorWithDeviceWhite:0.75 alpha:1.0];
    [self.searchBackgroundView setNeedsDisplay:YES];
}

#pragma mark Private methods

- (void)contextDidChange:(NSNotification *)notification;
{
    NSManagedObjectContext *context = notification.object;

    NSSet *insertedObjects = [notification.userInfo objectForKey:NSInsertedObjectsKey];
    ZappRepository *newRepository = [insertedObjects anyObject];
    if (insertedObjects && [newRepository isKindOfClass:[ZappRepository class]]) {
        // No need to save a new repository, turn on editing instead
        NSInteger row = [[self.repositoriesController arrangedObjects] indexOfObject:newRepository];
        [self.sourceListView editColumn:0 row:row withEvent:nil select:YES];
    } else {
        NSError *error = nil;
        [context save:&error];
        if (error) {
            NSLog(@"error saving context: %@", error);
        }
    }
}

- (void)hideProgressPanel;
{
    [self.progressPanel orderOut:nil];
    [[NSApplication sharedApplication] endSheet:self.progressPanel];
}

- (void)scheduleBuildForRepository:(ZappRepository *)repository;
{
    ZappBuild *build = [repository createNewBuild];
    [self.buildQueue addObject:build];
    [repository runCommand:GitCommand withArguments:[NSArray arrayWithObjects:@"rev-parse", @"HEAD", nil] completionBlock:^(NSString *revision) {
        build.latestRevision = revision;
        // At some point, serialize this queue-style
        [build startWithCompletionBlock:^{
            [self.buildQueue removeObject:build];
        }];
    }];
}

- (void)showProgressPanelWithMessage:(NSString *)message;
{
    self.progressLabel.stringValue = message;
    [self.progressIndicator startAnimation:nil];
    [[NSApplication sharedApplication] beginSheet:self.progressPanel modalForWindow:self.window modalDelegate:nil didEndSelector:nil contextInfo:NULL];
}

- (void)updateSourceListBackground:(NSNotification *)notification;
{
    NSApplication *application = [NSApplication sharedApplication];
    if ([application isActive]) {
        self.sourceListBackgroundView.backgroundColor = [NSColor colorWithDeviceRed:0.824 green:0.851 blue:0.882 alpha:1.0];
    } else {
        self.sourceListBackgroundView.backgroundColor = [NSColor windowBackgroundColor];
    }
    [self.sourceListBackgroundView setNeedsDisplay:YES];
}

@end
