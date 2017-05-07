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

static NSArray<NSURL*>* getFolderURLs(id<NSDraggingInfo> info, NSTableViewDropOperation op);

@interface ServerListController ()

@property (nonatomic, strong) NSMutableArray<Server*>* servers;
@property (nonatomic, strong) Caddy* caddy;
@property (nonatomic, assign) id notificationToken;

- (void)addServerWithLocation:(NSURL*)location andPort:(in_port_t)port atRow:(NSUInteger)row;

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
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(serverStatusDidChange:)
                                                     name:CaddyDidServerStatusChangeNotification
                                                   object:_caddy];
        
        [_caddy killAllServers];
        _servers = [NSMutableArray arrayWithArray:[_caddy readAllCaddyFiles]];
        
        _notificationToken = [[NSNotificationCenter defaultCenter] addObserverForName:NSApplicationWillTerminateNotification
                                                                               object:nil
                                                                                queue:nil
                                                                           usingBlock:^(NSNotification * _Nonnull note) {
                                                                               [_caddy killAllServers];
                                                                           }];
    }
    return self;
}

- (void)awakeFromNib
{
    [_serverListTableView registerForDraggedTypes:@[ (__bridge NSString*)kUTTypeFileURL, ServerUTI ]];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:_notificationToken];
}

- (NSUInteger)serverCount
{
    return _servers.count;
}

- (void)addServerWithLocation:(NSURL *)location andPort:(in_port_t)port
{
    [self addServerWithLocation:location
                        andPort:port
                          atRow:(_servers.count - 1)];
}

- (void)addServerWithLocation:(NSURL *)location andPort:(in_port_t)port atRow:(NSUInteger)row
{
    NSString* serverId = [self serverIdForLocation:location];
    
    Server* server = [Server serverWithId:serverId
                                 location:location
                                  andPort:port];
    [_servers addObject:server];
    
    [_serverListTableView reloadData];
    [_serverListTableView editColumn:0
                                 row:row
                           withEvent:nil
                              select:YES];
    [_caddy writeCaddyfileForServer:server];
}

- (void)removeServers
{
    [self stopServers];
    [_servers removeObjectsAtIndexes:_serverListTableView.selectedRowIndexes];
    [_serverListTableView reloadData];
}

- (void)startServers
{
    [_serverListTableView.selectedRowIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
        [_caddy startServer:_servers[idx]];
    }];
}

- (void)stopServers
{
    [_serverListTableView.selectedRowIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
        [_caddy stopServerWithId:_servers[idx].serverId];
    }];
}

- (void)serverStatusDidChange:(NSNotification*)notification
{
    NSString* serverId = notification.userInfo[CaddyDidServerStatusChangeServerIdKey];
    NSIndexSet* rows = [_servers indexesOfObjectsPassingTest:^BOOL(Server * _Nonnull server, NSUInteger idx, BOOL * _Nonnull stop) {
        return [server.serverId isEqualToString:serverId];
    }];
    dispatch_async(dispatch_get_main_queue(), ^{
        [_serverListTableView reloadDataForRowIndexes:rows
                                        columnIndexes:[NSIndexSet indexSetWithIndex:2]];
    });
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return self.serverCount;
}

- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row
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
        if ([_caddy statusForServerWithId:_servers[row].serverId])
        {
            tableCellView.imageView.image = [NSImage imageNamed:NSImageNameStatusAvailable];
        }
        else
        {
            tableCellView.imageView.image = [NSImage imageNamed:NSImageNameStatusUnavailable];
        }
        
        return tableCellView;
    }
    else
    {
        return nil;
    }
}

- (BOOL)tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
    NSArray<Server*>* pboardServers = [_servers objectsAtIndexes:rowIndexes];
    [pboard writeObjects:pboardServers];
    DDLogVerbose(@"Wrote objects to pasteboard : %@", pboardServers);
    return YES;
}

- (NSDragOperation)tableView:(NSTableView*)tableView
                validateDrop:(id<NSDraggingInfo>)info
                 proposedRow:(NSInteger)row
       proposedDropOperation:(NSTableViewDropOperation)op
{
    if (op != NSTableViewDropAbove)
    {
        return NSDragOperationNone;
    }
    
    NSPasteboard* pbboard = info.draggingPasteboard;
    
    NSArray<NSURL*>* urls = [pbboard readObjectsForClasses:@[ NSURL.class ]
                                                   options:@{ NSPasteboardURLReadingFileURLsOnlyKey : @YES,
                                                              NSPasteboardURLReadingContentsConformToTypesKey : @[ (__bridge NSString*)kUTTypeDirectory ] }];
    
    if (urls.count > 0)
    {
        return NSDragOperationCopy;
    }
    
    NSArray<Server*>* servers =  [pbboard readObjectsForClasses:@[ Server.class ]
                                                        options:nil];
    
    if (servers.count > 0)
    {
        return NSDragOperationCopy;
    }
    
    return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView*)tableView
       acceptDrop:(id<NSDraggingInfo>)info
              row:(NSInteger)row
    dropOperation:(NSTableViewDropOperation)op
{
    if (op != NSTableViewDropAbove)
    {
        return NO;
    }
    
    NSPasteboard* pbboard = info.draggingPasteboard;
    
    NSArray<NSURL*>* urls = [pbboard readObjectsForClasses:@[ NSURL.class ]
                                                   options:@{ NSPasteboardURLReadingFileURLsOnlyKey : @YES,
                                                              NSPasteboardURLReadingContentsConformToTypesKey : @[ (__bridge NSString*)kUTTypeDirectory ] }];
    
    if (urls.count > 0)
    {
        [urls enumerateObjectsUsingBlock:^(NSURL * _Nonnull url, NSUInteger idx, BOOL * _Nonnull stop) {
            [self addServerWithLocation:url
                                andPort:8000
                                  atRow:row];
        }];
        
        return YES;
    }
    
    NSArray<Server*>* pboardServers =  [pbboard readObjectsForClasses:@[ Server.class ]
                                                              options:nil];
    
    if (pboardServers.count > 0)
    {
        __block NSInteger insertRow = row;
        NSMutableArray* serversToMove = [NSMutableArray array];
        [pboardServers enumerateObjectsUsingBlock:^(Server * _Nonnull server, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([_servers containsObject:server])
            {
                [serversToMove addObject:server];
            }
            
            if (idx < insertRow)
            {
                insertRow--;
            }
        }];
        
        [_servers removeObjectsInArray:serversToMove];
        NSIndexSet* insertIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(insertRow, serversToMove.count)];
        [_servers insertObjects:serversToMove atIndexes:insertIndexes];
        
        [_serverListTableView reloadData];
        
        return YES;
    }
    
    return NO;
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
