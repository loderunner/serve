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

#include <sys/sysctl.h>

NSString* const CaddyDidServerStatusChangeNotification = @"CaddyDidServerStatusChangeNotification";
NSString* const CaddyDidServerStatusChangeServerIdKey = @"CaddyDidServerStatusChangeServerIdKey";
NSString* const CaddyDidServerStatusChangeStatusKey = @"CaddyDidServerStatusChangeStatusKey";

NSString* const CaddyfileFileName = @"Caddyfile";
NSString* const AccessLogFileName = @"access.log";
NSString* const ErrorLogFileName = @"error.log";
NSString* const PidfileFileName = @"Caddy.pid";

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

- (NSURL*)pidfileURLForServerId:(NSString*)serverId
{
    return [NSURL fileURLWithPathComponents:@[ [self applicationSupportDirectory].path,
                                               serverId,
                                               PidfileFileName]];
}

- (void)writeCaddyfileForServer:(Server *)server
{
    dispatch_async(_queue, ^() {
        NSFileManager* fileManager = [NSFileManager defaultManager];
        
        NSString* directoryPath = [self.applicationSupportDirectory URLByAppendingPathComponent:server.serverId].path;
        [fileManager createDirectoryAtPath:directoryPath
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:NULL];
        DDLogDebug(@"Created directory: %@", directoryPath);
        
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
        
        NSString* caddyfilePath = [self caddyfileURLForServerId:server.serverId].path;
        BOOL res =  [fileManager createFileAtPath:caddyfilePath
                                         contents:[caddyfileContents dataUsingEncoding:NSUTF8StringEncoding]
                                       attributes:nil];
        if (res)
        {
            DDLogDebug(@"Wrote Caddyfile: %@", caddyfilePath);
        }
        else
        {
            DDLogError(@"Couldn't write Caddyfile: %@", caddyfilePath);
        }
    });
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

- (void)deleteFilesForServerId:(NSString *)serverId
{
    NSURL* serverDirectory = [self.applicationSupportDirectory URLByAppendingPathComponent:serverId];
    
    NSFileManager* fileManager = [NSFileManager defaultManager];
    
    NSError* error = nil;
    if (![fileManager removeItemAtURL:serverDirectory
                                error:&error])
    {
        DDLogError(@"Failed to delete server directory: %@", serverDirectory);
        DDLogDebug(@"%@", error.localizedDescription);
    }
}

- (void)moveServerDirectoryFromServerId:(NSString *)oldServerId to:(NSString *)serverId
{
    NSURL* oldServerDirectory = [self.applicationSupportDirectory URLByAppendingPathComponent:oldServerId];
    NSURL* serverDirectory = [self.applicationSupportDirectory URLByAppendingPathComponent:serverId];
    
    NSFileManager* fileManager = [NSFileManager defaultManager];
    
    NSError* error = nil;
    if (![fileManager moveItemAtURL:oldServerDirectory
                              toURL:serverDirectory
                              error:&error])
    {
        DDLogError(@"Failed to rename server directory: %@ to %@", oldServerDirectory, serverDirectory);
        DDLogDebug(@"%@", error.localizedDescription);
    }
}

- (void)startServer:(Server *)server
{
    dispatch_async(_queue, ^() {
        NSString* serverId = server.serverId;
        if (_tasks[server.serverId] != nil)
        {
            return;
        }
        
        NSTask* serverTask = [[NSTask alloc] init];
        serverTask.launchPath = [[NSBundle mainBundle] pathForAuxiliaryExecutable:@"caddy"];
        serverTask.arguments = @[ @"-conf", [self caddyfileURLForServerId:serverId].path,
                                  @"-pidfile", [self pidfileURLForServerId:serverId].path ];
        serverTask.currentDirectoryPath = [self applicationSupportDirectory].path;
        
        _tasks[serverId] = serverTask;
        
        serverTask.terminationHandler = ^(NSTask * _Nonnull serverTask) {
            DDLogInfo(@"Server terminated: %@", server.serverId);
            dispatch_async(_queue, ^() {
                _tasks[serverId] = nil;
                [[NSNotificationCenter defaultCenter] postNotificationName:CaddyDidServerStatusChangeNotification
                                                                    object:self
                                                                  userInfo:@{ CaddyDidServerStatusChangeServerIdKey : serverId,
                                                                              CaddyDidServerStatusChangeStatusKey : @NO }];
            });
        };
        
        [serverTask launch];
        DDLogInfo(@"Launched server %@ (port: %d)", server.serverId, server.port);
        
        [[NSNotificationCenter defaultCenter] postNotificationName:CaddyDidServerStatusChangeNotification
                                                            object:self
                                                          userInfo:@{ CaddyDidServerStatusChangeServerIdKey : serverId,
                                                                      CaddyDidServerStatusChangeStatusKey : @YES }];
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

- (void)killAllServers
{
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
            NSURL* pidfileURL = [serverURL URLByAppendingPathComponent:PidfileFileName];
            NSString* pidString = [NSString stringWithContentsOfURL:pidfileURL
                                                           encoding:NSUTF8StringEncoding
                                                              error:NULL];
            if (pidString != nil)
            {
                pid_t pid = (pid_t)pidString.integerValue;
                
                int mib[4];
                mib[0] = CTL_KERN;
                mib[1] = KERN_PROC;
                mib[2] = KERN_PROC_PID;
                mib[3] = pid;
                
                size_t bufSize;
                int res = sysctl(mib, 4, NULL, &bufSize, NULL, 0);
                if (res < 0)
                {
                    DDLogError(@"Failure calling sysctl");
                    continue;
                }
                else if (bufSize == 0)
                {
                    DDLogInfo(@"No such process.");
                    //[fileManager removeItemAtURL:pidfileURL error:NULL];
                    continue;
                }
                
                size_t numEntries = (bufSize / sizeof(struct kinfo_proc));
                struct kinfo_proc* procInfo = (struct kinfo_proc *)malloc(bufSize);
                
                res = sysctl(mib, 4, procInfo, &bufSize, NULL, 0);
                if (res < 0)
                {
                    DDLogError(@"Failure calling sysctl");
                    continue;
                }
                
                struct kinfo_proc* kp = procInfo;
                size_t i;
                for (i = 0; i < numEntries; i++)
                {
                    if (kp->kp_proc.p_pid == pid)
                    {
                        break;
                    }
                    kp++;
                }
                
                if (i == numEntries)
                {
                    DDLogInfo(@"No such process.");
                    //[fileManager removeItemAtURL:pidfileURL error:NULL];
                    continue;
                }
                
                NSString* command = [NSString stringWithUTF8String:kp->kp_proc.p_comm];
                DDLogDebug(@"Process command: %@", command);
                
                if ([command isEqualToString:@"caddy"])
                {
                    kill(pid, SIGTERM);
                }
                
                free(procInfo);
            }
        }
    }
}

- (CaddyStatus)statusForServerWithId:(NSString *)serverId
{
    __block CaddyStatus status;
    dispatch_sync(_queue, ^{
        NSTask* serverTask = _tasks[serverId];
        status = serverTask.running ? CaddyStatusRunning : CaddyStatusStopped;
    });
    return status;
}

@end
