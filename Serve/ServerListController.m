//
//  ServerListController.m
//  Serve
//
//  Created by Charles Francoise on 23/04/2017.
//  Copyright © 2017 Charles Francoise. All rights reserved.
//

#import "ServerListController.h"
#import "Server.h"
#import "Caddy.h"

NSString* const ServerListColumnLocation = @"ServerListColumnLocation";
NSString* const ServerListColumnPort = @"ServerListColumnPort";
NSString* const ServerListColumnStatus = @"ServerListColumnStatus";

NSString* const ServerListKey = @"ServerList";

static NSCharacterSet* ValidCharacterSet;

@interface ServerListController ()

@property (nonatomic, strong) NSMutableArray<Server*>* servers;
@property (nonatomic, strong) Caddy* caddy;

@end

@implementation ServerListController

@dynamic serverCount;

+ (void)initialize
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        ValidCharacterSet = [NSMutableCharacterSet lowercaseLetterCharacterSet];
        [(NSMutableCharacterSet*)ValidCharacterSet addCharactersInString:@"-"];
    });
}

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _caddy = [[Caddy alloc] init];
        _servers = [NSMutableArray arrayWithArray:[_caddy readAllCaddyFiles]];
    }
    return self;
}

- (NSUInteger)serverCount
{
    return _servers.count;
}

- (void)addServerWithLocation:(NSURL *)location andPort:(in_port_t)port
{
    NSString* serverId = [self serverIdForLocation:location];
    
    Server* server = [Server serverWithId:serverId
                                 location:location
                                  andPort:port];
    [_servers addObject:server];
    
    [_serverListTableView reloadData];
    [_serverListTableView editColumn:0
                                 row:(_servers.count - 1)
                           withEvent:nil
                              select:YES];
}

- (void)startServers
{
    [_serverListTableView.selectedRowIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
        [_caddy startServer:_servers[idx]];
    }];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return self.serverCount;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if ([tableColumn.identifier isEqualToString:ServerListColumnLocation])
    {
        NSTableCellView* tableCellView = [tableView makeViewWithIdentifier:ServerListColumnLocation
                                                             owner:self];
        tableCellView.textField.stringValue = _servers[row].location.path ?: @"";
        return tableCellView;
    }
    else if ([tableColumn.identifier isEqualToString:ServerListColumnPort])
    {
        NSTableCellView* tableCellView = [tableView makeViewWithIdentifier:ServerListColumnPort
                                                             owner:self];
        in_port_t port = _servers[row].port;
        tableCellView.textField.stringValue = (port > 0) ? [NSString stringWithFormat:@"%d", port] : @"";
        return tableCellView;
    }
    else if ([tableColumn.identifier isEqualToString:ServerListColumnStatus])
    {
        NSTableCellView* tableCellView = [tableView makeViewWithIdentifier:ServerListColumnStatus
                                                             owner:self];
        tableCellView.imageView.image = [NSImage imageNamed:NSImageNameStatusAvailable];
        return tableCellView;
    }
    else
    {
        return nil;
    }
}

- (void)controlTextDidEndEditing:(NSNotification *)obj
{
    NSDictionary* userInfo = obj.userInfo;
    NSTextView* textView = userInfo[@"NSFieldEditor"];
    
    NSInteger row = [_serverListTableView rowForView:textView];
    
    if (row != -1)
    {
        BOOL updated = NO;
        Server* server = _servers[row];
        
        NSInteger column = [_serverListTableView columnForView:textView];
        NSTableColumn* tableColumn = _serverListTableView.tableColumns[column];
        
        if ([tableColumn.identifier isEqualToString:ServerListColumnLocation])
        {
            NSURL* location = [NSURL fileURLWithPath:textView.string];
            if (![location isEqual:server.location])
            {
                server.location = location;
                server.serverId = [self serverIdForLocation:location];
                updated = YES;
            }
        }
        else if ([tableColumn.identifier isEqualToString:ServerListColumnPort])
        {
            in_port_t port = textView.string.integerValue;
            if (port != server.port)
            {
                server.port = port;
                updated = YES;
            }
        }
        
        if (updated)
        {
            [_serverListTableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row]
                                            columnIndexes:[NSIndexSet indexSetWithIndex:column]];
            [_caddy writeCaddyfileForServer:server];
        }
    }
}

- (NSString*)serverIdForLocation:(NSURL*) location
{
    NSString* baseServerId = [location.lastPathComponent lowercaseString];
    [[baseServerId componentsSeparatedByCharactersInSet:ValidCharacterSet] componentsJoinedByString:@"-"];
    
    // Search for existing server with this id, if found append incrementing number to end
    __block NSString* serverId = baseServerId;
    BOOL (^predicate)(Server * _Nonnull, NSUInteger, BOOL * _Nonnull) = ^BOOL(Server * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        return [serverId isEqualToString:obj.serverId];
    };
    int num = 2;
    while ([_servers indexOfObjectPassingTest:predicate] != NSNotFound)
    {
        serverId = [baseServerId stringByAppendingFormat:@"-%d", num];
        num++;
    }
    
    return serverId;
}

@end
