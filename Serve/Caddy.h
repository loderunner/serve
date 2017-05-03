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

- (nonnull NSURL*)caddyfileURLForServerId:(nonnull NSString*)serverId;
- (nonnull NSURL*)accessLogURLForServerId:(nonnull NSString*)serverId;
- (nonnull NSURL*)errorLogURLForServerId:(nonnull NSString*)serverId;

- (BOOL)writeCaddyfileForServer:(nonnull Server*)server;
- (nullable Server*)readCaddyfileForServerId:(nonnull NSString*)serverId;
- (nonnull NSArray<Server*>*)readAllCaddyFiles;

- (void)startServer:(nonnull Server*)server;
- (void)stopServerWithId:(nonnull NSString*)serverId;
- (BOOL)statusForServerWithId:(nonnull NSString*)serverId;

@end

