//
//  ZappWebServer.m
//  Zapp
//
//  Created by Jim Puls on 8/21/11.
//  Licensed to Square, Inc. under one or more contributor license agreements.
//  See the LICENSE file distributed with this work for the terms under
//  which Square, Inc. licenses this file to you.

#import "ZappWebServer.h"


@interface ZappWebServer ()

@property (strong) NSFileHandle *listenHandle;
@property (strong) NSSocketPort *socketPort;
@property (readonly) NSDateFormatter *dateFormatter;
@property (strong) NSManagedObjectContext *managedObjectContext;

- (void)listenOnPort:(NSNumber *)portNumber;
- (void)respondToRequest:(CFHTTPMessageRef)request onHandle:(NSFileHandle *)handle;
- (NSData *)cruiseControlXML;
- (NSData *)rssForRepositoryWithURL:(NSURL *)url;
- (NSData *)artifactForBuildWithURL:(NSURL *)url;

@end


@implementation ZappWebServer

@synthesize managedObjectContext;
@synthesize listenHandle;
@synthesize socketPort;

+ (id)startWithManagedObjectContext:(NSManagedObjectContext *)context;
{
    static ZappWebServer *server = nil;
    NSAssert([NSThread isMainThread], @"ZappRSSServer can only start on the main thread.");
    NSAssert(!server, @"ZappRSSServer can only start once.");
    server = [self new];
    [server setManagedObjectContext:context];
    [NSThread detachNewThreadSelector:@selector(listenOnPort:) toTarget:server withObject:[NSNumber numberWithUnsignedShort:1729]];
    return server;
}

- (void)listenOnPort:(NSNumber *)portNumber;
{
    unsigned short port = [portNumber unsignedShortValue];
    self.socketPort = [[NSSocketPort alloc] initWithTCPPort:port];
    if (!socketPort) {
        NSLog(@"Zapp failed to listen on port %d", port);
        return;
    }
    self.listenHandle = [[NSFileHandle alloc] initWithFileDescriptor:[socketPort socket] closeOnDealloc:YES];
    [[NSNotificationCenter defaultCenter] addObserverForName:NSFileHandleConnectionAcceptedNotification object:self.listenHandle queue:[NSOperationQueue currentQueue] usingBlock:^(NSNotification *note) {
        NSFileHandle *readHandle = [[note userInfo] objectForKey:NSFileHandleNotificationFileHandleItem];
        CFHTTPMessageRef __block request = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, YES);

        [[NSNotificationCenter defaultCenter] addObserverForName:NSFileHandleReadCompletionNotification object:readHandle queue:[NSOperationQueue currentQueue] usingBlock:^(NSNotification *readNote) {
            NSData *readData = [[readNote userInfo] objectForKey:NSFileHandleNotificationDataItem];
            CFHTTPMessageAppendBytes(request, [readData bytes], [readData length]);

            if (CFHTTPMessageIsHeaderComplete(request)) {
                [self respondToRequest:request onHandle:readHandle];
                [readHandle closeFile];
                CFRelease(request);
                request = NULL;
            } else {
                [readHandle readInBackgroundAndNotify];
            }
        }];

        [readHandle readInBackgroundAndNotify];
        [self.listenHandle acceptConnectionInBackgroundAndNotify];
    }];

    [self.listenHandle acceptConnectionInBackgroundAndNotify];
    [[NSRunLoop currentRunLoop] run];
}

- (NSFetchRequest *)repositoriesFetchRequestForAbbreviation:(NSString *)abbreviation;
{
    NSFetchRequest *repositoriesFetchRequest = [NSFetchRequest new];
    repositoriesFetchRequest.entity = [NSEntityDescription entityForName:@"Repository" inManagedObjectContext:self.managedObjectContext];
    repositoriesFetchRequest.predicate = [NSPredicate predicateWithFormat:@"abbreviation = %@", abbreviation];
    repositoriesFetchRequest.fetchLimit = 1;
    return repositoriesFetchRequest;
}

- (void)respondToRequest:(CFHTTPMessageRef)request onHandle:(NSFileHandle *)handle;
{
    NSData *bodyData = nil;
    NSInteger status = 200;
    CFStringRef type = CFSTR("application/atom+xml;charset=UTF-8");

    NSURL *requestURL = (__bridge_transfer NSURL *)CFHTTPMessageCopyRequestURL(request);
    if ([requestURL.path isEqualToString:@"/cc.xml"]) {
        bodyData = [self cruiseControlXML];
    } else if ([requestURL.path hasPrefix:@"/file"]) {
        bodyData = [self artifactForBuildWithURL:requestURL];
        type = CFSTR("text/plain;charset=UTF-8");
    } else {
        bodyData = [self rssForRepositoryWithURL:requestURL];
    }
    if (!bodyData) {
        status = 404;
    }

    CFHTTPMessageRef response = CFHTTPMessageCreateResponse(kCFAllocatorDefault, status, NULL, kCFHTTPVersion1_1);
    CFHTTPMessageSetHeaderFieldValue(response, CFSTR("Content-Type"), type);
    CFHTTPMessageSetHeaderFieldValue(response, CFSTR("Connection"), CFSTR("close"));
    CFHTTPMessageSetBody(response, (__bridge CFDataRef)bodyData);
    NSData *responseData = (__bridge_transfer NSData *)CFHTTPMessageCopySerializedMessage(response);
    [handle writeData:responseData];
    CFRelease(response);
}

- (NSDateFormatter *)dateFormatter;
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm'Z'";
    dateFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    return dateFormatter;
}

- (NSData *)cruiseControlXML;
{
    NSData *bodyData = nil;
    NSError *error = nil;
    NSFetchRequest *repositoriesFetchRequest = [NSFetchRequest new];
    repositoriesFetchRequest.entity = [NSEntityDescription entityForName:@"Repository" inManagedObjectContext:self.managedObjectContext];
    NSArray *repositories = [self.managedObjectContext executeFetchRequest:repositoriesFetchRequest error:&error];
    if (error) {
        return nil;
    } else {
        NSXMLElement *root = [NSXMLElement elementWithName:@"Projects"];
        NSDateFormatter *dateFormatter = self.dateFormatter;
        [repositories enumerateObjectsUsingBlock:^(ZappRepository *repository, NSUInteger idx, BOOL *stop) {
            NSArray *builds = [self.managedObjectContext executeFetchRequest:repository.latestBuildsFetchRequest error:nil];
            if (!builds.count) {
                return;
            }
            NSXMLElement *entry = [NSXMLElement elementWithName:@"Project"];
            [root addChild:entry];
            ZappBuild *build = [builds objectAtIndex:0];
            NSString *buildStatus = build.statusDescription;
            NSString *activity = build.status == ZappBuildStatusRunning ? @"Building" : @"Sleeping";
            NSString *lastBuildTime = [dateFormatter stringFromDate:build.endDate];
            [entry setAttributesWithDictionary:[NSDictionary dictionaryWithObjectsAndKeys:repository.abbreviation, @"name", buildStatus, @"lastBuildStatus", activity, @"activity", lastBuildTime, @"lastBuildTime", nil]];
        }];
        NSXMLDocument *document = [[NSXMLDocument alloc] initWithRootElement:root];
        bodyData = [document XMLDataWithOptions:NSXMLNodePrettyPrint];
    }
    return bodyData;
}

- (NSData *)rssForRepositoryWithURL:(NSURL *)url;
{
    NSData *bodyData = nil;
    NSError *error = nil;
    NSArray *components = [url.path componentsSeparatedByString:@"/"];
    NSString *abbreviation = [components objectAtIndex:components.count - 2];
    NSDateFormatter *dateFormatter = self.dateFormatter;
    ZappRepository *repository = [[self.managedObjectContext executeFetchRequest:[self repositoriesFetchRequestForAbbreviation:abbreviation] error:&error] lastObject];
    if (error || !repository) {
        return nil;
    }
    NSArray *builds = [self.managedObjectContext executeFetchRequest:repository.latestBuildsFetchRequest error:&error];
    if (error) {
        return nil;
    }
    NSXMLElement *root = [NSXMLElement elementWithName:@"feed" URI:@"http://www.w3.org/2005/Atom"];
    [root addChild:[NSXMLElement elementWithName:@"title" stringValue:[NSString stringWithFormat:@"%@ builds", repository.name]]];
    [builds enumerateObjectsUsingBlock:^(ZappBuild *build, NSUInteger idx, BOOL *stop) {
        if (idx == 0) {
            [root addChild:[NSXMLNode elementWithName:@"updated" stringValue:[dateFormatter stringFromDate:build.endDate]]];
        }
        NSXMLElement *entry = [NSXMLElement elementWithName:@"entry"];
        [root addChild:entry];
        [entry addChild:[NSXMLElement elementWithName:@"title" stringValue:build.feedDescription]];
        NSXMLElement *link = [NSXMLElement elementWithName:@"link"];
        NSString *urlString = [NSString stringWithFormat:@"http://%@:%@/file/%@", [url host], [url port], [build.buildLogURL lastPathComponent]];
        [link setAttributesWithDictionary:[NSDictionary dictionaryWithObject:urlString forKey:@"href"]];
        [entry addChild:link];
        [entry addChild:[NSXMLElement elementWithName:@"published" stringValue:[dateFormatter stringFromDate:build.startDate]]];
        [entry addChild:[NSXMLElement elementWithName:@"updated" stringValue:[dateFormatter stringFromDate:build.endDate]]];
    }];
    NSXMLDocument *document = [[NSXMLDocument alloc] initWithRootElement:root];
    bodyData = [document XMLDataWithOptions:NSXMLNodePrettyPrint];
    return bodyData;
}

- (NSData *)artifactForBuildWithURL:(NSURL *)url;
{
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    NSArray *supportURLs = [fileManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask];
    NSURL *storageURL = [[supportURLs objectAtIndex:0] URLByAppendingPathComponent:[[NSRunningApplication currentApplication] localizedName]];
    NSURL *artifactURL = [storageURL URLByAppendingPathComponent:[url lastPathComponent]];
    return [NSData dataWithContentsOfURL:artifactURL];
}

@end
