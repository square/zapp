//
//  ZappRSSServer.m
//  Zapp
//
//  Created by Jim Puls on 8/21/11.
//  Copyright (c) 2011 Square, Inc. All rights reserved.
//

#import "ZappRSSServer.h"


@interface ZappRSSServer ()

@property (strong) NSFileHandle *listenHandle;
@property (strong) NSSocketPort *socketPort;

- (void)listenOnPort:(unsigned short)port;
- (void)respondToRequest:(CFHTTPMessageRef)request onHandle:(NSFileHandle *)handle;

@end


@implementation ZappRSSServer

@synthesize managedObjectContext;
@synthesize listenHandle;
@synthesize socketPort;

+ (id)start;
{
    static ZappRSSServer *server = nil;
    NSAssert([NSThread isMainThread], @"ZappRSSServer can only start on the main thread.");
    NSAssert(!server, @"ZappRSSServer can only start once.");
    server = [self new];
    [server listenOnPort:1729];
    return server;
}

- (void)listenOnPort:(unsigned short)port;
{
    self.socketPort = [[NSSocketPort alloc] initWithTCPPort:port];
    if (!socketPort) {
        NSLog(@"Zapp failed to listen on port %d", port);
        return;
    }
    self.listenHandle = [[NSFileHandle alloc] initWithFileDescriptor:[socketPort socket] closeOnDealloc:YES];
    [[NSNotificationCenter defaultCenter] addObserverForName:NSFileHandleConnectionAcceptedNotification object:self.listenHandle queue:[NSOperationQueue currentQueue] usingBlock:^(NSNotification *note) {
        NSLog(@"new connection");
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
    NSError *error = nil;
    NSData *bodyData = [NSData data];
    NSInteger status = 200;
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm'Z'";
    dateFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];

    NSURL *requestURL = (__bridge_transfer NSURL *)CFHTTPMessageCopyRequestURL(request);
    if ([requestURL.path isEqualToString:@"/cc.xml"]) {
        NSFetchRequest *repositoriesFetchRequest = [NSFetchRequest new];
        repositoriesFetchRequest.entity = [NSEntityDescription entityForName:@"Repository" inManagedObjectContext:self.managedObjectContext];
        NSArray *repositories = [self.managedObjectContext executeFetchRequest:repositoriesFetchRequest error:&error];
        if (error) {
            status = 500;
        } else {
            NSXMLElement *root = [NSXMLElement elementWithName:@"Projects"];
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
    } else {
        NSArray *components = [requestURL.path componentsSeparatedByString:@"/"];
        NSString *abbreviation = [components objectAtIndex:components.count - 2];
        ZappRepository *repository = [[self.managedObjectContext executeFetchRequest:[self repositoriesFetchRequestForAbbreviation:abbreviation] error:&error] lastObject];
        NSArray *builds = [self.managedObjectContext executeFetchRequest:repository.latestBuildsFetchRequest error:&error];
        if (error) {
            status = 500;
        } else {
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
                [link setAttributesWithDictionary:[NSDictionary dictionaryWithObject:@"" forKey:@"href"]];
                [entry addChild:link];
                [entry addChild:[NSXMLElement elementWithName:@"published" stringValue:[dateFormatter stringFromDate:build.startDate]]];
                [entry addChild:[NSXMLElement elementWithName:@"updated" stringValue:[dateFormatter stringFromDate:build.endDate]]];
            }];
            NSXMLDocument *document = [[NSXMLDocument alloc] initWithRootElement:root];
            bodyData = [document XMLDataWithOptions:NSXMLNodePrettyPrint];
        }
    }

    CFHTTPMessageRef response = CFHTTPMessageCreateResponse(kCFAllocatorDefault, status, NULL, kCFHTTPVersion1_1);
    CFHTTPMessageSetHeaderFieldValue(response, CFSTR("Content-Type"), CFSTR("application/atom+xml;charset=UTF-8"));
    CFHTTPMessageSetHeaderFieldValue(response, CFSTR("Connection"), CFSTR("close"));
    CFHTTPMessageSetBody(response, (__bridge CFDataRef)bodyData);
    NSData *responseData = (__bridge_transfer NSData *)CFHTTPMessageCopySerializedMessage(response);
    [handle writeData:responseData];
    CFRelease(response);
}

@end
