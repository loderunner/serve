//
//  Caddyfile.m
//  Serve
//
//  Created by Charles Francoise on 03/05/2017.
//  Copyright © 2017 Charles Francoise. All rights reserved.
//

#include "Caddyfile.h"

NSArray<NSDictionary*>* parseLabelList(NSString* line)
{
    NSDictionary* label = parseLabel(line);
    return label ? @[label] : @[];
}

NSDictionary* parseLabel(NSString* label)
{
    // <scheme>://<host>:<port></path>
    NSError* error = nil;
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"^(?:(http|https)://)?([^:/]*)?(?::(\\d+))?(/\\S*)?"
                                                                           options:0
                                                                             error:&error];
    NSTextCheckingResult* match = [regex firstMatchInString:label
                                                    options:0
                                                      range:NSMakeRange(0, label.length)];
    
    if (match == nil)
    {
        return nil;
    }
    
    NSMutableDictionary* labelDict = [NSMutableDictionary dictionaryWithCapacity:4];
    NSRange range = [match rangeAtIndex:1];
    if (range.location != NSNotFound)
    {
        labelDict[@"scheme"] = [label substringWithRange:range];
    }
    range = [match rangeAtIndex:2];
    if (range.location != NSNotFound)
    {
        labelDict[@"host"] = [label substringWithRange:range];
    }
    
    range = [match rangeAtIndex:3];
    if (range.location != NSNotFound)
    {
        labelDict[@"port"] = [label substringWithRange:range];
    }
    
    range = [match rangeAtIndex:4];
    if (range.location != NSNotFound)
    {
        labelDict[@"path"] = [label substringWithRange:range];
    }
    
    return labelDict;
}

NSDictionary* parseEntry(NSString* line)
{
    NSUInteger spaceLocation = [line rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].location;
    if (spaceLocation == NSNotFound)
    {
        return @{ @"directive" : line };
    }
    
    NSString* directive = [line substringToIndex:spaceLocation];
    if (directive == nil)
    {
        return nil;
    }
    
    NSMutableDictionary* entry = [NSMutableDictionary dictionary];
    entry[@"directive"] = directive;
    
    NSString* arguments = [[line substringFromIndex:spaceLocation] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([directive isEqualToString:@"root"])
    {
        [entry addEntriesFromDictionary:parseRootArguments(arguments)];
    }
    
    return entry;
}

NSDictionary* parseRootArguments(NSString* arguments)
{
    return @{ @"location" : arguments };
}
