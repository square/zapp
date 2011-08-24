//
//  ZappWebServer.h
//  Zapp
//
//  Created by Jim Puls on 8/21/11.
//  Copyright (c) 2011 Square, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ZappWebServer : NSObject

+ (id)start;

@property (strong) NSManagedObjectContext *managedObjectContext;

@end
