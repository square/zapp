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

@interface NSString (ZappContainsString)
- (BOOL)containsString:(NSString *)string;
@end

@implementation NSString (ZappContainsString)
- (BOOL)containsString:(NSString *)string
{
    return ([self rangeOfString:string].location != NSNotFound);
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
            NSString *failureSummary = [NSString stringWithFormat:@"%@\n%@", scenarioDescription, scenarioFailingErrorString];
            [retVal addObject:failureSummary];
        }
    }

    return retVal;
}

@end
