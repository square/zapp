//
//  ZappLocalURLFormatter.m
//  Zapp
//
//  Created by Jim Puls on 8/5/11.
//  Licensed to Square, Inc. under one or more contributor license agreements.
//  See the LICENSE file distributed with this work for the terms under
//  which Square, Inc. licenses this file to you.

#import "ZappLocalURLFormatter.h"


@implementation ZappLocalURLFormatter

- (BOOL)getObjectValue:(__autoreleasing id *)obj forString:(NSString *)string errorDescription:(NSString *__autoreleasing *)error;
{
    NSURL *url = [NSURL fileURLWithPath:string];
    *obj = url;
    return url != nil;
}

- (NSString *)stringForObjectValue:(id)obj;
{
    if (![obj isKindOfClass:[NSURL class]]) {
        return nil;
    }
    
    return [obj path];
}

@end
