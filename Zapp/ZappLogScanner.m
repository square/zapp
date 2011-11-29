//
//  ZappLogScanner.m
//  Zapp
//
//  Created by Lawrence Forooghian on 28/11/2011.
//  Copyright (c) 2011 Lawrence Forooghian. All rights reserved.
//

#import "ZappLogScanner.h"

#define kBeginScenarioString @"BEGIN SCENARIO"
#define kFailingErrorString @"FAILING ERROR:"

@interface NSString (ZappLogScanner)
- (BOOL)containsString:(NSString *)string;
- (NSString *)stringByRemovingKIFLogArtifacts;
@end

@implementation NSString (ZappLogScanner)
- (BOOL)containsString:(NSString *)string
{
    return ([self rangeOfString:string].location != NSNotFound);
}

// This takes, for example, "2011-11-29 10:27:01.855 MyApp Functional Tests[54441:12203] Test that the login screen is shown when the login button is tapped"
// to "Test that the login screen is shown when the login button is tapped".
- (NSString *)stringByRemovingKIFLogArtifacts
{
    NSError *error = nil;
    NSRegularExpression *kifLogArtifactsRegexp = [NSRegularExpression regularExpressionWithPattern:@"^\\d{4}-\\d{2}-\\d{2} (?:\\d{2}:){2}\\d{2}\\.\\d+ .*\\[\\d+:\\d+\\] (.*)$" 
                                                                                           options:0 
                                                                                             error:&error];
    NSString *retVal = nil;
    
    if (!error)
    {
        NSTextCheckingResult *matchResult = [kifLogArtifactsRegexp firstMatchInString:self 
                                                                              options:0 
                                                                                range:NSMakeRange(0, self.length)];
        
        if (matchResult.range.location != NSNotFound)
        {
            retVal = [self substringWithRange:[matchResult rangeAtIndex:1]];
        }
    }
    
    return retVal;
}
@end

@implementation ZappLogScanner

@synthesize logLines = logLines_;

- (NSArray *)arrayOfKIFFailureSummaries
{
    NSMutableArray *retVal = [NSMutableArray array];

    NSString *scenarioDescription = nil, *scenarioFailingErrorString = nil;
    BOOL nextLineIsScenarioDescription = NO;

    for (NSString *logLine in self.logLines) {
        if (nextLineIsScenarioDescription) {
            scenarioDescription = logLine;
            nextLineIsScenarioDescription = NO;
        }

        if ([logLine containsString:kBeginScenarioString]) {
            // Scenario description comes after the 'BEGIN SCENARIO' log message
            nextLineIsScenarioDescription = YES;
        }

        if ([logLine containsString:kFailingErrorString]) {
            scenarioFailingErrorString = logLine;
            
            NSString *failureSummary = [NSString stringWithFormat:@"%@\n%@",
                                        [scenarioDescription stringByRemovingKIFLogArtifacts], 
                                        [scenarioFailingErrorString stringByRemovingKIFLogArtifacts]];
            [retVal addObject:failureSummary];
        }
    }

    return retVal;
}

@end
