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

@implementation Server

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

@end
