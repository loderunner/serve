//
//  ViewController.m
//  Serve
//
//  Created by Charles Francoise on 23/04/2017.
//  Copyright © 2017 Charles Francoise. All rights reserved.
//

#import "ViewController.h"

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

- (void)addButtonClicked:(id)sender
{
    [_serverListController addServerWithLocation:nil andPort:0];
}

- (void)removeButtonClicked:(id)sender
{
    [_serverListController removeServers];
}

- (void)startButtonClicked:(id)sender
{
    [_serverListController startServers];
}

- (void)stopButtonClicked:(id)sender
{
    [_serverListController stopServers];
}

@end
