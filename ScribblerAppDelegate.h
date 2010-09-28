//
//  ScribblerAppDelegate.h
//  Scribbler
//
//  Created by Clemens Sagmeister on 21.04.10.
//  Copyright 2010 Apple Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ScribblerAppDelegate : NSObject <NSApplicationDelegate> {
	NSWindow *window;
	IBOutlet NSMenu *statusMenu;
	NSStatusItem *statusItem;
	BOOL initialSwitchToKeyWindow;
	
}

@property (assign) IBOutlet NSWindow *window;
@property(readwrite, assign) BOOL initialSwitchToKeyWindow;

@end
