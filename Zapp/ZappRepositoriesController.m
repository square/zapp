//
//  ZappRepositoriesController.m
//  Zapp
//
//  Created by Jim Puls on 8/4/11.
//  Licensed to Square, Inc. under one or more contributor license agreements.
//  See the LICENSE file distributed with this work for the terms under
//  which Square, Inc. licenses this file to you.

#import "ZappRepositoriesController.h"


@implementation ZappRepositoriesController

#pragma mark NSObjectController

- (id)newObject;
{
    ZappRepository *newObject = [super newObject];
    newObject.name = ZappLocalizedString(@"New Repository");
    newObject.latestBuildStatus = ZappBuildStatusSucceeded;
    return newObject;
}

#pragma mark NSObject

- (void)awakeFromNib;
{
    NSManagedObjectModel *model = [[NSManagedObjectModel alloc] initWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"Repositories" withExtension:@"momd"]];
    NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    NSArray *supportURLs = [fileManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask];
    NSURL *storageURL = [[supportURLs objectAtIndex:0] URLByAppendingPathComponent:[[NSRunningApplication currentApplication] localizedName]];
    [fileManager createDirectoryAtURL:storageURL withIntermediateDirectories:YES attributes:nil error:NULL];
    
    [coordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:[storageURL URLByAppendingPathComponent:@"Data"] options:nil error:NULL];
    self.managedObjectContext.persistentStoreCoordinator = coordinator;
    [self fetch:nil];
}

@end
