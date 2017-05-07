//
//  Server.h
//  Serve
//
//  Created by Charles Francoise on 24/04/2017.
//  Copyright © 2017 Charles Francoise. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sys/socket.h>

@interface Server : NSObject <NSPasteboardWriting, NSPasteboardReading>

@property (nonatomic, strong) NSURL* location;
@property (nonatomic, assign) in_port_t port;
@property (nonatomic, strong) NSString* serverId;

+ (instancetype)serverWithId:(NSString*)serverId
                    location:(NSURL*)location
                      andPort:(in_port_t)port;
+ (instancetype)serverWithDictionary:(NSDictionary*)dictionary;

- (instancetype)initWithId:(NSString*)serverId
                  location:(NSURL*)location
                   andPort:(in_port_t)port;
- (instancetype)initWithDictionary:(NSDictionary*)dictionary;
- (NSDictionary*)dictionaryRepresentation;

@end

extern NSString* const ServerUTI;
