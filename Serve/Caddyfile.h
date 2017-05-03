//
//  Caddyfile.h
//  Serve
//
//  Created by Charles Francoise on 03/05/2017.
//  Copyright © 2017 Charles Francoise. All rights reserved.
//

#include <Foundation/Foundation.h>



NSArray<NSDictionary*>* parseLabelList(NSString* line);
NSDictionary* parseLabel(NSString* label);
NSDictionary* parseEntry(NSString* line);
NSDictionary* parseRootArguments(NSString* arguments);

