//
//  MainWindow.m
//  Scribbler
//
//  Created by Clemens Sagmeister on 21.04.10.
//  Copyright 2010 Apple Inc. All rights reserved.
//

#import "MainWindow.h"

@implementation MainWindow

pascal OSStatus getCarbonEvent (EventHandlerCallRef nextHandler, EventRef theEvent, void* userData)
{
	NSLog(@"got the carbon Event!");
	return noErr;
}

- (id)initWithContentRect:(NSRect)contentRect styleMask:(NSUInteger)aStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag
{
    if (![super initWithContentRect:[[NSScreen mainScreen] frame] styleMask:NSBorderlessWindowMask backing:bufferingType defer:flag])
		return nil;
	
	[self setLevel:/*CGShieldingWindowLevel()];*/NSFloatingWindowLevel];
	[self setBackgroundColor:[NSColor clearColor]];
	[self setOpaque:NO];

	// uncomment next line to overrule OS menubars
	//[self setLevel:NSMainMenuWindowLevel + 1];
	
	controller = [[SketchController alloc] initWithMainWindow:self];
	
	isVisible = NO;
	
	WindowRef theWindow;
	theWindow = [self windowRef];
	
	EventTargetRef theTarget;
	theTarget = GetWindowEventTarget(theWindow);
	
	EventTypeSpec eventType;
	eventType.eventClass = kEventClassTablet;
	eventType.eventKind  = kEventTabletProximity;
	
	EventHandlerUPP handlerUPP;
	handlerUPP = NewEventHandlerUPP(getCarbonEvent);
	
	InstallEventHandler(theTarget, handlerUPP, 1, &eventType, NULL, NULL);
	
    return self;
}

- (void) showHide:(id)sender {
	
	[controller showHide];
}

- (void)toggleSticky:(id)sender {
	
	[controller setIsSticky:![controller isSticky]];
	
	// if sticky is activated again refresh scrollingInfos
	if([controller isSticky])
		[controller refreshScrollingInfos];
}

- (void) openFinder:(id)sender {
	[[NSWorkspace sharedWorkspace] launchApplication:@"Finder"];
}

- (void) actionQuit:(id)sender {
	[NSApp terminate:sender];
}

- (void) showGlassPane:(BOOL)flag {
	isVisible = flag;
	[controller setClickThrough: !flag];
	if(flag) {
		[NSApp activateIgnoringOtherApps:YES];
		[self makeKeyAndOrderFront:nil];
	}
}

- (void) setPenColor:(id)sender
{
	NSLog(@"Select %@", [sender title]);
	
	if ([[sender title] isEqualToString:@"White"]) {
		[controller setSelectedColor:[NSColor whiteColor]];
		return;
	}
	if ([[sender title] isEqualToString:@"Red"]) {
		[controller setSelectedColor:[NSColor redColor]];
		return;
	}
	if ([[sender title] isEqualToString:@"Green"]) {
		[controller setSelectedColor:[NSColor greenColor]];
		return;
	}
	if ([[sender title] isEqualToString:@"Blue"]) {
		[controller setSelectedColor:[NSColor blueColor]];
		return;
	}
	if ([[sender title] isEqualToString:@"Black"]) {
		[controller setSelectedColor:[NSColor blackColor]];
		return;
	}
}

- (void)dealloc
{
	[controller release];
	[super dealloc];
}

@synthesize startDragPoint, endDragPoint, controller, isVisible;

@end
