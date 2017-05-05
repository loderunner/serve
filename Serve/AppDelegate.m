//
//  AppDelegate.m
//  Serve
//
//  Created by Charles Francoise on 23/04/2017.
//  Copyright © 2017 Charles Francoise. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
#ifndef DEBUG
    [DDLog addLogger:[DDASLLogger sharedInstance]];
    
    DDLogFileManagerDefault* logFileManager = [[DDLogFileManagerDefault alloc] init];
    [DDLog addLogger:[[DDFileLogger alloc] initWithLogFileManager:logFileManager]];
#endif
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return YES;
}


@end
