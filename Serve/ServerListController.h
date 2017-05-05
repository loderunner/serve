//
//  ServerListController.h
//  Serve
//
//  Created by Charles Francoise on 23/04/2017.
//  Copyright © 2017 Charles Francoise. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ServerListController : NSObject <NSTableViewDataSource, NSTableViewDelegate>

@property (nonatomic, assign) IBOutlet NSTableView* serverListTableView;
@property (nonatomic, readonly) NSUInteger serverCount;

- (void)addServerWithLocation:(NSURL*)location andPort:(in_port_t)port;
- (void)removeServers;
- (void)startServers;
- (void)stopServers;

@end
