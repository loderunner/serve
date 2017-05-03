//
//  Caddyfile.m
//  Serve
//
//  Created by Charles Francoise on 30/04/2017.
//  Copyright © 2017 Charles Francoise. All rights reserved.
//

#import "Caddy.h"

#import "Server.h"

NSString* const CaddyfileFileName = @"Caddyfile";
NSString* const AccessLogFileName = @"access.log";
NSString* const ErrorLogFileName = @"error.log";


@implementation Caddy

+ (NSURL*)directoryForServerId:(NSString*)serverId
{
    NSArray<NSString*>* applicationSupportPath = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                                                     NSUserDomainMask,
                                                                                     YES);
    return [NSURL fileURLWithPathComponents:@[ applicationSupportPath,
                                               serverId ]];
}

+ (NSURL *)caddyfileURLForServerId:(NSString *)serverId
{
    return [NSURL URLWithString:CaddyfileFileName
                  relativeToURL:[self directoryForServerId:serverId]];
}

+ (NSURL *)accessLogURLForServerId:(NSString *)serverId
{
    return [NSURL URLWithString:AccessLogFileName
                  relativeToURL:[self directoryForServerId:serverId]];
}

+ (NSURL *)errorLogURLForServerId:(NSString *)serverId
{
    return [NSURL URLWithString:ErrorLogFileName
                  relativeToURL:[self directoryForServerId:serverId]];
}

+ (BOOL)writeCaddyfileForServer:(Server *)server
{
    NSFileManager* fileManager = [NSFileManager defaultManager];
    
    [fileManager createDirectoryAtPath:[self directoryForServerId:server.serverId].path
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
        NSString* rootDirectoryString = [NSString stringWithFormat:@"root %@\n", server.location.path];
        [caddyfileContents appendString:rootDirectoryString];
    }
    
    {
        // Write access log directive
        NSString* rootDirectoryString = [NSString stringWithFormat:@"log %@\n", [self accessLogURLForServerId:server.serverId]];
        [caddyfileContents appendString:rootDirectoryString];
    }
    
    {
        // Write error log directive
        NSString* rootDirectoryString = [NSString stringWithFormat:@"error %@\n", [self errorLogURLForServerId:server.serverId]];
        [caddyfileContents appendString:rootDirectoryString];
    }
    
    return [fileManager createFileAtPath:[self caddyfileURLForServerId:server.serverId].path
                                contents:[caddyfileContents dataUsingEncoding:NSUTF8StringEncoding]
                              attributes:nil];
}

+ (Server *)readCaddyfileForServerId:(NSString *)serverId
{
    
    
    return [Server serverWithId:serverId
                       location:location
                        andPort:port];
}

@end
