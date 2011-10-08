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


NSString *const SendmailCommand = @"/usr/sbin/sendmail";


@interface ZappMessageController ()

+ (void)sendEmailFromRepository:(ZappRepository*)repository withSubject:(NSString *)subject headers:(NSDictionary *)headers body:(NSString *)body;

@end


@implementation ZappMessageController

#pragma mark Public Methods

+ (void)sendMessageForBuild:(ZappBuild *)build;
{
    // get the log since the last build
    // last red red-green or last green-red
    NSString *oldRevision = nil;
    
    NSString *delta = oldRevision ? [NSString stringWithFormat:@"%@..%@", oldRevision, build.latestRevision] : @"HEAD^..HEAD";
    NSString *format = @"--format=\"%h %s (%an)\"";
    
    NSArray *arguments = [NSArray arrayWithObjects:@"log", delta, format, nil];
    
    [build.repository runCommand:GitCommand withArguments:arguments completionBlock:^(NSString *gitLogOutput) {
        
        NSString *subject = [NSString stringWithFormat:ZappLocalizedString(@"ZAPP: %@ Build %@ %@"), build.repository.name, build.abbreviatedLatestRevision, [build.statusDescription uppercaseString]];
        
        NSString *beginString = ZappLocalizedString(@"===== BEGIN TRANSMISSION =====");
        NSString *latestBuildString = ZappLocalizedString(@"Latest build:");
        NSString *latestBuildStatusString = [NSString stringWithFormat:@"%@ %@", build.abbreviatedLatestRevision, [build.statusDescription uppercaseString]];
        
        NSString *endString = ZappLocalizedString(@"====== END TRANSMISSION ======");
        
        NSString *message = [[NSArray arrayWithObjects:beginString, latestBuildString, latestBuildStatusString, @"", gitLogOutput, endString, nil] componentsJoinedByString:@"\n"];
        
        [self sendEmailFromRepository:build.repository withSubject:subject headers:nil body:message];
    }];
}

#pragma mark Private Methods

+ (void)sendEmailFromRepository:(ZappRepository*)repository withSubject:(NSString *)subject headers:(NSDictionary *)headers body:(NSString *)body;
{
    NSString *subjectHeaderLine = [NSString stringWithFormat:@"Subject: %@", subject];
    // TODO: break headers into key: value lines
    NSString *headerLines = @"";
    NSString *combinedHeadersAndMessage = [[NSArray arrayWithObjects:subjectHeaderLine, headerLines, body, nil] componentsJoinedByString:@"\n"];
    
    NSString *temporaryFilePath = [NSString stringWithFormat:@"%@/output-%d.msg", NSTemporaryDirectory(), rand()];
    [combinedHeadersAndMessage writeToFile:temporaryFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSFileHandle *mailFileHandle = [NSFileHandle fileHandleForReadingAtPath:temporaryFilePath];
    
    // TODO: get to-address from somewhere
    NSString *toAddress = @"ios-ci@squareup.com";
    NSArray *arguments = [NSArray arrayWithObjects:@"-v", toAddress, temporaryFilePath, nil];
    NSLog(@"running %@", SendmailCommand);
    
    [repository runCommand:SendmailCommand withArguments:arguments standardInput:mailFileHandle completionBlock:^(NSString *output) {
        [[NSFileManager defaultManager] removeItemAtPath:temporaryFilePath error:nil];
    }];
}
     
@end
