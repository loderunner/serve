//
//  Server.m
//  Serve
//
//  Created by Charles Francoise on 24/04/2017.
//  Copyright © 2017 Charles Francoise. All rights reserved.
//

#import "Server.h"

NSString* const ServerIdKey = @"id";
NSString* const ServerLocationKey = @"location";
NSString* const ServerPortKey = @"port";

NSString* const ServerUTI = @"io.github.loderunner.serve.server";

static NSArray<NSString*>* PasteboardTypes;

@implementation Server

+ (void)initialize
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (PasteboardTypes == nil)
        {
            PasteboardTypes = @[ ServerUTI ];
        }
    });
}

+ (instancetype)serverWithId:(NSString*)serverId
                    location:(NSURL *)location
                     andPort:(in_port_t)port
{
    return [[self alloc] initWithId:serverId
                           location:location
                            andPort:port];
}

+ (instancetype)serverWithDictionary:(NSDictionary*)dictionary
{
    return [[self alloc] initWithDictionary:dictionary];
}

- (instancetype)init
{
    return [self initWithId:nil
                   location:nil
                    andPort:0];
}

- (instancetype)initWithId:(NSString*)serverId location:(NSURL *)location andPort:(in_port_t)port
{
    self = [super init];
    if (self != nil)
    {
        _serverId = serverId;
        _location = location;
        _port = port;
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary*)dictionary
{
    NSString* serverId = dictionary[ServerIdKey];
    if (serverId == nil || ![serverId isKindOfClass:NSString.class])
    {
        return nil;
    }
    
    NSURL* location;
    NSString* path = dictionary[ServerLocationKey];
    if (path == nil || ![path isKindOfClass:NSString.class])
    {
        return nil;
    }
    else
    {
        location = [NSURL fileURLWithPath:path];
        if (location == nil)
        {
            return nil;
        }
    }
    
    in_port_t port;
    NSNumber* portNumber = dictionary[ServerPortKey];
    if (portNumber == nil || ![portNumber isKindOfClass:NSNumber.class])
    {
        return nil;
    }
    else
    {
        port = portNumber.unsignedShortValue;
    }
    
    return [self initWithId:serverId
                   location:location
                    andPort:port];
}

- (NSDictionary*)dictionaryRepresentation
{
    return @{ ServerIdKey: _serverId,
              ServerLocationKey : _location.path,
              ServerPortKey : @(_port) };
}

- (NSArray<NSString *> *)writableTypesForPasteboard:(NSPasteboard *)pasteboard
{
    return PasteboardTypes;
}
- (nullable id)pasteboardPropertyListForType:(NSString *)type
{
    return self.dictionaryRepresentation;
}

+ (NSArray<NSString *> *)readableTypesForPasteboard:(NSPasteboard *)pasteboard
{
    return PasteboardTypes;
}

+ (NSPasteboardReadingOptions)readingOptionsForType:(NSString *)type pasteboard:(NSPasteboard *)pasteboard
{
    return NSPasteboardReadingAsPropertyList;
}


- (id)initWithPasteboardPropertyList:(id)propertyList ofType:(NSString *)type
{
    if ([type isEqualToString:ServerUTI] && [propertyList isKindOfClass:NSDictionary.class])
    {
        return [self initWithDictionary:propertyList];
    }
    
    return nil;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"Server<%p> { id : %@, location : %@ } (:%d)", self, _serverId, _location.path, _port];
}

- (BOOL)isEqual:(id)object
{
    if (![object isMemberOfClass:self.class])
    {
        return NO;
    }
    
    Server* other = object;
    return ([_serverId isEqualToString:other.serverId]
            && [_location isEqual:other.location]
            && (_port == other.port));
}

- (NSUInteger)hash
{
    return (_serverId.hash ^ _location.hash ^ _port);
}

@end
