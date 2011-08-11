//
//  ZappSSHURLFormatter.m
//  Zapp
//
//  Created by Jim Puls on 8/5/11.
//  Copyright 2011 Square, Inc. All rights reserved.
//

#import "ZappSSHURLFormatter.h"


@implementation ZappSSHURLFormatter

- (BOOL)getObjectValue:(__autoreleasing id *)obj forString:(NSString *)string errorDescription:(NSString *__autoreleasing *)error;
{
    NSURL __block *url = [NSURL URLWithString:string];
    if (!url) {
        NSError *error = nil;
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^([^@]*)@?([^:]+):(.+)$" options:0 error:&error];
        if (error) {
            return NO;
        }
        [regex enumerateMatchesInString:string options:0 range:NSMakeRange(0, string.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
            NSString *user = [string substringWithRange:[result rangeAtIndex:1]];
            NSString *host = [string substringWithRange:[result rangeAtIndex:2]];
            NSString *path = [string substringWithRange:[result rangeAtIndex:3]];
            url = [NSURL URLWithString:[NSString stringWithFormat:@"ssh://%@@%@/%@", user, host, path]];
            *stop = YES;
        }];
    }
    *obj = url;
    return url != nil;
}

- (NSString *)stringForObjectValue:(id)obj;
{
    if (![obj isKindOfClass:[NSURL class]]) {
        return nil;
    }
    
    if (![[obj scheme] isEqualToString:@"ssh"]) {
        return [obj absoluteString];
    }
    
    return [NSString stringWithFormat:@"%@@%@:%@", [obj user], [obj host], [obj path]];
}

@end
