//
//  ZappRepositoriesController.m
//  Zapp
//
//  Created by Jim Puls on 8/4/11.
//  Copyright 2011 Square, Inc. All rights reserved.
//

#import "ZappRepositoriesController.h"


@implementation ZappRepositoriesController

#pragma mark NSObjectController

- (id)newObject;
{
    ZappRepository *newObject = [super newObject];
    newObject.name = ZappLocalizedString(@"New Repository");
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
