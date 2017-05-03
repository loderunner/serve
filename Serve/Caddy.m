//
//  Caddyfile.m
//  Serve
//
//  Created by Charles Francoise on 30/04/2017.
//  Copyright © 2017 Charles Francoise. All rights reserved.
//

#import "Caddy.h"

#import "Caddyfile.h"
#import "Server.h"

NSString* const CaddyfileFileName = @"Caddyfile";
NSString* const AccessLogFileName = @"access.log";
NSString* const ErrorLogFileName = @"error.log";

extern inline NSString* quotePath(NSString* path)
{
    if ([path rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet]].location != NSNotFound)
    {
        path = [NSString stringWithFormat:@"\"%@\"", path];
    }
    return path;
}

@interface Caddy ()

@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) NSMutableDictionary<NSString*, NSTask*>* tasks;

@end

@implementation Caddy

- (instancetype)init
{
    self = [super init];
    if (self) {
        _queue = dispatch_queue_create("Caddy server queue", DISPATCH_QUEUE_SERIAL);
        _tasks = [NSMutableDictionary dictionary];
    }
    return self;
}

- (NSURL*)applicationSupportDirectory
{
    NSArray<NSString*>* applicationSupportPath = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                                                     NSUserDomainMask,
                                                                                     YES);
    return [NSURL fileURLWithPathComponents:@[ applicationSupportPath[0],
                                               [[NSBundle mainBundle] infoDictionary][(__bridge NSString*)kCFBundleNameKey] ]];
}

- (NSURL *)caddyfileURLForServerId:(NSString *)serverId
{
    return [NSURL fileURLWithPathComponents:@[ [self applicationSupportDirectory].path,
                                                serverId,
                                                CaddyfileFileName]];
}

- (NSURL *)accessLogURLForServerId:(NSString *)serverId
{
    return [NSURL fileURLWithPathComponents:@[ [self applicationSupportDirectory].path,
                                               serverId,
                                               AccessLogFileName]];
}

- (NSURL *)errorLogURLForServerId:(NSString *)serverId
{
    return [NSURL fileURLWithPathComponents:@[ [self applicationSupportDirectory].path,
                                               serverId,
                                               ErrorLogFileName]];
}

- (BOOL)writeCaddyfileForServer:(Server *)server
{
    NSFileManager* fileManager = [NSFileManager defaultManager];
    
    [fileManager createDirectoryAtPath:[[self caddyfileURLForServerId:server.serverId] URLByDeletingLastPathComponent].path
           withIntermediateDirectories:YES
                            attributes:nil
                                 error:NULL];
    
    NSMutableString* caddyfileContents = [NSMutableString string];
    
    {
        // Write site address
        NSString* siteAddressString = [NSString stringWithFormat:@"localhost:%d\n", server.port];
        [caddyfileContents appendString:siteAddressString];
    }
    
    {
        // Write root directory directive
        NSString* rootDirectoryString = [NSString stringWithFormat:@"root %@\n", quotePath(server.location.path)];
        [caddyfileContents appendString:rootDirectoryString];
    }
    
    {
        // Write access log directive
        NSString* accessLogString = [NSString stringWithFormat:@"log %@\n", quotePath([self accessLogURLForServerId:server.serverId].path)];
        [caddyfileContents appendString:accessLogString];
    }
    
    {
        // Write error log directive
        NSString* errorLogString = [NSString stringWithFormat:@"errors %@\n", quotePath([self errorLogURLForServerId:server.serverId].path)];
        [caddyfileContents appendString:errorLogString];
    }
    
    return [fileManager createFileAtPath:[self caddyfileURLForServerId:server.serverId].path
                                contents:[caddyfileContents dataUsingEncoding:NSUTF8StringEncoding]
                              attributes:nil];
}

- (Server *)readCaddyfileForServerId:(NSString *)serverId
{
    NSString* caddyfileContents = [NSString stringWithContentsOfURL:[self caddyfileURLForServerId:serverId]
                                                           encoding:NSUTF8StringEncoding
                                                              error:NULL];
    
    if (caddyfileContents == nil)
    {
        return nil;
    }
    
    __block NSURL* location;
    __block NSNumber* port = 0;
    __block BOOL firstLine = YES;
    [caddyfileContents enumerateLinesUsingBlock:^(NSString * _Nonnull line, BOOL * _Nonnull stop) {
        if (firstLine)
        {
            NSArray<NSDictionary*>* labels = parseLabelList(line);
            if (labels.count > 0)
            {
                port = labels.firstObject[@"port"];
            }
            firstLine = NO;
        }
        else
        {
            NSDictionary* entry = parseEntry(line);
            if ((entry != nil) && ([entry[@"directive"] isEqualToString:@"root"]))
            {
                location = [NSURL fileURLWithPath:entry[@"location"]];
            }
        }
    }];
    
    // Condition for a valid server. port can be 0 and serverId is assumed nonnull
    if (location != nil)
    {
        return [Server serverWithId:serverId
                           location:location
                            andPort:port.integerValue];
    }
    else
    {
        return nil;
    }
}

- (NSArray<Server *> *)readAllCaddyFiles
{
    NSMutableArray<Server*>* servers = [NSMutableArray array];
    
    NSFileManager* fileManager = [NSFileManager defaultManager];
    
    NSArray<NSURL*>* directoryContents = [fileManager contentsOfDirectoryAtURL:[self applicationSupportDirectory]
                                                    includingPropertiesForKeys:@[ NSURLIsDirectoryKey ]
                                                                       options:NSDirectoryEnumerationSkipsSubdirectoryDescendants
                                                                         error:NULL];
    
    for (NSURL* serverURL in directoryContents)
    {
        NSNumber* isDirectory;
        BOOL success = [serverURL getResourceValue:&isDirectory
                                            forKey:NSURLIsDirectoryKey
                                             error:NULL];
        if (success && [isDirectory boolValue])
        {
            Server* server = [self readCaddyfileForServerId:serverURL.lastPathComponent];
            if (server != nil)
            {
                [servers addObject:server];
            }
        }
    }
    
    return servers;
}

- (void)startServer:(Server *)server
{
    dispatch_async(_queue, ^() {
        NSString* serverId = server.serverId;
        
        NSTask* serverTask = [[NSTask alloc] init];
        serverTask.launchPath = [[NSBundle mainBundle] pathForAuxiliaryExecutable:@"caddy"];
        serverTask.arguments = @[ @"-conf", [self caddyfileURLForServerId:serverId].path ];
        serverTask.currentDirectoryPath = [self applicationSupportDirectory].path;
        
        _tasks[serverId] = serverTask;
        
        serverTask.terminationHandler = ^(NSTask * _Nonnull serverTask) {
            dispatch_async(_queue, ^() {
                _tasks[serverId] = nil;
            });
        };
        
        [serverTask launch];
    });
}

- (void)stopServerWithId:(NSString *)serverId
{
    dispatch_async(_queue, ^() {
        NSTask* serverTask = _tasks[serverId];
        if (serverTask != nil)
        {
            [serverTask terminate];
        }
    });
}

- (BOOL)statusForServerWithId:(NSString *)serverId
{
    NSTask* serverTask = _tasks[serverId];
    return serverTask.running;
}

@end
