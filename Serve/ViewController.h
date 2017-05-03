//
//  ViewController.h
//  Serve
//
//  Created by Charles Francoise on 23/04/2017.
//  Copyright © 2017 Charles Francoise. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ServerListController.h"

@interface ViewController : NSViewController

@property (nonatomic, assign) IBOutlet ServerListController* serverListController;

- (IBAction)addButtonClicked:(id)sender;
- (IBAction)startButtonClicked:(id)sender;

@end

