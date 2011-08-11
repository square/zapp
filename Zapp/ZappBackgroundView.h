//
//  ZappBackgroundView.h
//  Zapp
//
//  Created by Jim Puls on 8/4/11.
//  Copyright 2011 Square, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface ZappBackgroundView : NSView

@property (nonatomic, strong) NSColor *backgroundColor;
@property (nonatomic, strong) NSGradient *backgroundGradient;
@property (nonatomic, strong) NSColor *borderColor;
@property (nonatomic) CGFloat borderWidth;

@end
