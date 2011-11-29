//
//  ZappMessageController.m
//  Zapp
//
//  Created by Zach Margolis on 10/5/11.
//  Licensed to Square, Inc. under one or more contributor license agreements.
//  See the LICENSE file distributed with this work for the terms under
//  which Square, Inc. licenses this file to you.

#import "ZappMessageController.h"
#import "ZappBuild.h"
#import "ZappRepository.h"


#if DEBUG
NSString *const SendmailCommand = @"/bin/echo";
#else
NSString *const SendmailCommand = @"/usr/sbin/sendmail";
#endif


@interface ZappMessageController ()

+ (BOOL)shouldSendNotificationForBuild:(ZappBuild *)build;

+ (void)sendEmailFromRepository:(ZappRepository *)repository withSubject:(NSString *)subject body:(NSString *)body;

+ (BOOL)shouldIncludeFailuresSummaryInMessage;

+ (NSString *)failuresSummaryForBuild:(ZappBuild *)build;

@end


@implementation ZappMessageController

#pragma mark Public Methods

+ (void)sendMessageIfNeededForBuild:(ZappBuild *)build;
{
    if (![self shouldSendNotificationForBuild:build]) {
        return;
    }
    
    // Send the diff since the previous green build, if we have one.
    ZappBuild *previousGreenBuild = build.previousSuccessfulBuild;
    NSString *oldRevision = previousGreenBuild.latestRevision;
    
    NSString *delta = oldRevision ? [NSString stringWithFormat:@"%@..%@", oldRevision, build.latestRevision] : @"HEAD^..HEAD";
    
    NSArray *arguments = [NSArray arrayWithObjects:@"log", delta, @"--format=%h %s (%an)", @"--no-merges", nil];
    
    [build.repository runCommand:GitCommand withArguments:arguments completionBlock:^(NSString *gitLogOutput) {
        
        NSString *subject = [NSString stringWithFormat:ZappLocalizedString(@"ZAPP: %@ Build %@ %@"), build.repository.name, build.abbreviatedLatestRevision, [build.statusDescription uppercaseString]];
        
        NSString *baseURLString = [NSString stringWithFormat:@"http://%@:%d/file/", [[NSHost currentHost] name], ZAPP_WEB_PORT];
        
        NSString *beginString = ZappLocalizedString(@"===== BEGIN TRANSMISSION =====");
        NSString *latestBuildString = ZappLocalizedString(@"Latest build:");
        NSString *latestBuildStatusString = [NSString stringWithFormat:@"%@ %@", build.abbreviatedLatestRevision, [build.statusDescription uppercaseString]];
        NSString *logLinkString = [NSString stringWithFormat:@"Log: %@/%@", baseURLString, [build.buildLogURL lastPathComponent]];
        NSString *videoLinkString = [NSString stringWithFormat:@"Video: %@/%@", baseURLString, [build.buildVideoURL lastPathComponent]];
        NSString *failuresSummaryString = [self failuresSummaryForBuild:build];
        NSString *endString = ZappLocalizedString(@"====== END TRANSMISSION ======");
        
        NSString *message = [[NSArray arrayWithObjects:beginString, latestBuildString, latestBuildStatusString, @"", logLinkString, videoLinkString, @"", gitLogOutput, failuresSummaryString, endString, nil] componentsJoinedByString:@"\n"];
        
        [self sendEmailFromRepository:build.repository withSubject:subject body:message];
    }];
}

#pragma mark Private Methods

+ (void)sendEmailFromRepository:(ZappRepository *)repository withSubject:(NSString *)subject body:(NSString *)body;
{
    NSString *toAddress = [[NSUserDefaults standardUserDefaults] stringForKey:@"EmailNotificationsTo"];
    if (!toAddress.length) {
        return;
    }
    
    NSString *replyToAddress = [[NSUserDefaults standardUserDefaults] stringForKey:@"EmailNotificationsReplyTo"];
    
    NSString *subjectHeaderLine = [NSString stringWithFormat:@"Subject: %@", subject];
    NSString *toHeaderLine = [NSString stringWithFormat:@"To: %@", toAddress];
    NSString *replyToHeaderLine = [NSString stringWithFormat:@"Reply-To: %@", replyToAddress];
    NSString *combinedHeadersAndMessage = [[NSArray arrayWithObjects:subjectHeaderLine, toHeaderLine, replyToHeaderLine, body, nil] componentsJoinedByString:@"\n"];
    
    NSString *temporaryFilePath = [NSString stringWithFormat:@"%@/output-%d.msg", NSTemporaryDirectory(), rand()];
    [combinedHeadersAndMessage writeToFile:temporaryFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSFileHandle *mailFileHandle = [NSFileHandle fileHandleForReadingAtPath:temporaryFilePath];
    
    NSArray *arguments = [NSArray arrayWithObjects:@"-v", toAddress, temporaryFilePath, nil];
    NSLog(@"running %@", SendmailCommand);
    
    [repository runCommand:SendmailCommand withArguments:arguments standardInput:mailFileHandle completionBlock:^(NSString *output) {
        [[NSFileManager defaultManager] removeItemAtPath:temporaryFilePath error:nil];
    }];
}

+ (BOOL)shouldSendNotificationForBuild:(ZappBuild *)build;
{
    ZappNotificationOption notificationOption = (ZappNotificationOption)[[NSUserDefaults standardUserDefaults] integerForKey:@"EmailNotificationOption"];
    switch (notificationOption) {
        case ZappNotificationOptionAlways:
            return YES;
        case ZappNotificationOptionNever:
            return NO;
        case ZappNotificationOptionSmart:
        default:
            break;
    }
    
    // For smart builds, only send messages for red builds or green-red transitions.
    ZappBuild *previousBuild = build.previousBuild;
    
    if (build.status == ZappBuildStatusSucceeded && previousBuild.status == ZappBuildStatusSucceeded) {
        NSLog(@"Skipping message for green-green transition, %@..%@", previousBuild.abbreviatedLatestRevision, build.abbreviatedLatestRevision);
        return NO;
    }
    
    return YES;
}

+ (BOOL)shouldIncludeFailuresSummaryInMessage
{
    // TODO: Make this a user preference
    return YES;
}

+ (NSString *)failuresSummaryForBuild:(ZappBuild *)build
{
    if ([self shouldIncludeFailuresSummaryInMessage] && ZappBuildStatusFailed == build.status) {
        NSMutableString *retVal = [NSMutableString stringWithString:ZappLocalizedString(@"\nSummary of failed KIF tests:\n\n")];
        
        NSArray *failureSummaries = build.failureLogStrings;
        NSUInteger total = failureSummaries.count, currentIndex = 1;
        
        for (NSString *failureSummary in build.failureLogStrings) {
            [retVal appendFormat:@"%d of %d: %@\n", currentIndex, total, failureSummary];
            currentIndex++;
        }
        
        [retVal appendString:@"\n"];

        return retVal;
    } else {
        return @"";
    }
}

@end
