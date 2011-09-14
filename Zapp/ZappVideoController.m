//
//  ZappVideoController.m
//  Zapp
//
//  Created by Jim Puls on 8/24/11.
//  Copyright (c) 2011 Square, Inc. All rights reserved.
//

#import "ZappVideoController.h"
#import <AVFoundation/AVFoundation.h>

@interface ZappVideoController () <AVCaptureFileOutputRecordingDelegate>

@property (strong) AVCaptureSession *captureSession;

@end

@implementation ZappVideoController

@synthesize outputURL;
@synthesize captureSession;

- (void)start;
{
    if (!self.outputURL) {
        return;
    }
    
    CGDirectDisplayID displayID = 0;
    CGWindowID windowID = 0;
    NSArray *windowList = objc_retainedObject(CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID));
    CGRect windowRect;
    for (NSDictionary *info in windowList) {
        if ([[info objectForKey:(NSString *)kCGWindowOwnerName] isEqualToString:@"iOS Simulator"] && ![[info objectForKey:(NSString *)kCGWindowName] isEqualToString:@""]) {
            windowID = [[info objectForKey:(NSString *)kCGWindowNumber] unsignedIntValue];
            CGRectMakeWithDictionaryRepresentation((CFDictionaryRef)objc_unretainedPointer([info objectForKey:(NSString *)kCGWindowBounds]), &windowRect);
            CGGetDisplaysWithRect(windowRect, 1, &displayID, NULL);
        }
    }
    if (windowID) {
        AVCaptureScreenInput *input = [[AVCaptureScreenInput alloc] initWithDisplayID:displayID];
        CGRect displayBounds = CGDisplayBounds(displayID);
        input.cropRect = CGRectMake(windowRect.origin.x - displayBounds.origin.x, displayBounds.size.height - displayBounds.origin.y - windowRect.origin.y - windowRect.size.height, windowRect.size.width, windowRect.size.height);
        AVCaptureMovieFileOutput *output = [[AVCaptureMovieFileOutput alloc] init];
        self.captureSession = [[AVCaptureSession alloc] init];
        [self.captureSession startRunning];
        [self.captureSession addInput:input];
        [self.captureSession addOutput:output];
        [output startRecordingToOutputFileURL:self.outputURL recordingDelegate:self];
    }    
}

- (void)stop;
{
    [self.captureSession stopRunning];
    self.captureSession = nil; 
}

#pragma mark AVCaptureFileOutputRecordingDelegate

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections;
{
}

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error;
{
}

@end
