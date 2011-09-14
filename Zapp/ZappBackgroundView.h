//
//  ZappBackgroundView.h
//  Zapp
//
//  Created by Jim Puls on 8/4/11.
//  Licensed to Square, Inc. under one or more contributor license agreements.
//  See the LICENSE file distributed with this work for the terms under
//  which Square, Inc. licenses this file to you.

#import <Cocoa/Cocoa.h>


@interface ZappBackgroundView : NSView

@property (nonatomic, strong) NSColor *backgroundColor;
@property (nonatomic, strong) NSGradient *backgroundGradient;
@property (nonatomic, strong) NSColor *borderColor;
@property (nonatomic) CGFloat borderWidth;

@end
