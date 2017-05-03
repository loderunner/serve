//
//  Caddyfile.h
//  Serve
//
//  Created by Charles Francoise on 30/04/2017.
//  Copyright © 2017 Charles Francoise. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Server;

@interface Caddy : NSObject

+ (NSURL*)caddyfileURLForServerId:(NSString*)serverId;
+ (NSURL*)accessLogURLForServerId:(NSString*)serverId;
+ (NSURL*)errorLogURLForServerId:(NSString*)serverId;

+ (BOOL)writeCaddyfileForServer:(Server*)server;
+ (Server*)readCaddyfileForServerId:(NSString*)serverId;
+ (NSArray<Server*>*)readAllCaddyFiles;

@end

