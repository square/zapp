//
//  ZappMessageController.m
//  Zapp
//
//  Created by Zach Margolis on 10/5/11.
//  Copyright (c) 2011 Square, Inc. All rights reserved.
//

#import "ZappMessageController.h"
#import "ZappBuild.h"
#import "ZappRepository.h"


NSString *const EchoCommand = @"echo";
NSString *const SendmailCommand = @"sendmail";


@interface ZappMessageController ()

@property (nonatomic, retain) ZappMailConfiguration *mailConfiguration;

- (void)sendEmailFromRepository:(ZappRepository*)repository withSubject:(NSString *)subject headers:(NSDictionary *)headers body:(NSString *)body;

@end


@implementation ZappMessageController

@synthesize mailConfiguration;

#pragma mark Public Methods

- (void)sendMessageForLatestBuildInRepository:(ZappRepository *)repository;
{
    
}

- (void)sendMessageForBuild:(ZappBuild *)build;
{
    // get the log since the last build
    // last red red-green or last green-red
    NSString *oldRevision = nil;
    
    NSString *delta = oldRevision ? [NSString stringWithFormat:@"%@..%@", oldRevision, build.latestRevision] : @"HEAD^..HEAD";
    NSString *format = [NSString stringWithFormat:@"--format=\"%@%%h %%s (%%an)\"", build.repository.remoteURL.absoluteString];
    
    NSArray *logCommand = [NSArray arrayWithObjects:GitCommand, @"log", delta, format, nil];
    
    [build.repository runCommand:GitCommand withArguments:logCommand completionBlock:^(NSString *gitLogOutput) {
        
        NSString *subject = [NSString stringWithFormat:ZappLocalizedString(@"ZAPP: Latest Build %@ %@"), build.abbreviatedLatestRevision, [build.statusDescription uppercaseString]];
        
        NSString *beginString = ZappLocalizedString(@"===== BEGIN TRANSMISSION =====");
        NSString *latestBuildString = ZappLocalizedString(@"Latest build:");
        NSString *latestBuildStatusString = [NSString stringWithFormat:@"%@ %@", build.abbreviatedLatestRevision, [build.statusDescription uppercaseString]];
        
        NSString *endString = ZappLocalizedString(@"====== END TRANSMISSION ======");
        
        NSString *message = [[NSArray arrayWithObjects:beginString, latestBuildString, latestBuildStatusString, @"", gitLogOutput, endString, nil] componentsJoinedByString:@"\n"];
        
        [self sendEmailFromRepository:build.repository withSubject:subject headers:nil body:message];
    }];
}

#pragma mark Private Methods

- (void)sendEmailFromRepository:(ZappRepository*)repository withSubject:(NSString *)subject headers:(NSDictionary *)headers body:(NSString *)body;
{
    NSString *subjectHeaderLine = [NSString stringWithFormat:@"Subject: %@", subject];
    NSString *combinedHeadersAndMessage = [[NSArray arrayWithObjects:subjectHeaderLine, body, nil] componentsJoinedByString:@"\n"];
    
    NSString *toAddress = @"";
    NSArray *arguments = [NSArray arrayWithObjects:combinedHeadersAndMessage, @"|", SendmailCommand, @"-v", toAddress, nil];
    [repository runCommand:EchoCommand withArguments:arguments completionBlock:^(NSString *output) {
        
    }];
}
     
@end
