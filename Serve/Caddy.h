//
//  Caddyfile.h
//  Serve
//
//  Created by Charles Francoise on 30/04/2017.
//  Copyright © 2017 Charles Francoise. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Server;

typedef enum : NSUInteger {
    CaddyStatusStopped = 0,
    CaddyStatusRunning,
} CaddyStatus;

@interface Caddy : NSObject

- (nonnull NSURL*)caddyfileURLForServerId:(nonnull NSString*)serverId;
- (nonnull NSURL*)accessLogURLForServerId:(nonnull NSString*)serverId;
- (nonnull NSURL*)errorLogURLForServerId:(nonnull NSString*)serverId;

- (void)writeCaddyfileForServer:(nonnull Server*)server;
- (nullable Server*)readCaddyfileForServerId:(nonnull NSString*)serverId;
- (nonnull NSArray<Server*>*)readAllCaddyFiles;
- (void)deleteFilesForServerId:(nonnull NSString*)serverId;
- (void)moveServerDirectoryFromServerId:(nonnull NSString*)oldServerId
                                     to:(nonnull NSString*)serverId;

- (void)startServer:(nonnull Server*)server;
- (void)stopServerWithId:(nonnull NSString*)serverId;
- (CaddyStatus)statusForServerWithId:(nonnull NSString*)serverId;
- (void)killAllServers;

@end

extern NSString* _Nonnull const CaddyDidServerStatusChangeNotification;
extern NSString* _Nonnull const CaddyDidServerStatusChangeServerIdKey;
extern NSString* _Nonnull const CaddyDidServerStatusChangeStatusKey;
