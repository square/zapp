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


@interface ZappMessageController ()

- (BOOL)sendEmailWithSubject:(NSString *)subject headers:(NSDictionary *)headers body:(NSString *)body error:(out NSError **)error;

@end


@implementation ZappMessageController

#pragma mark Initialization

+ (id)sharedInstance;
{
    static ZappMessageController *sharedInstance;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[ZappMessageController alloc] init];
    });
    
    return nil;
}

#pragma mark Public Methods

- (void)sendMessageForLatestBuildInRepository:(ZappRepository *)repository;
{
    
}

- (void)sendMessageForBuild:(ZappBuild *)build;
{
    // get the long since the last build
    // current sha + author
    
    NSString *oldRevision = nil;
    
    
    // since last build
    // last red red-green or last green-red
    
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
        
        [self sendEmailWithSubject:subject headers:nil body:message error:nil];
/*
 ===== BEGIN TRANSMISSION =====
 
 Latest build:
 a895jf9 SUCCESS
 
 Intermediate commits:
 aaf8d5f Author: Some commit message (8 hours ago)
 88486a3 Author + Author: Another commit message. (8 days ago)
 19a938f Author: The same one as before (8 days ago)
 21ab6e4 Author: A new commit message (8 days ago)
 
 ====== END TRANSMISSION ======
*/
    }];
}
     
#pragma mark Private Methods

- (BOOL)sendEmailWithSubject:(NSString *)subject headers:(NSDictionary *)headers body:(NSString *)body error:(out NSError **)error;
{
    return YES;
}
     
@end
