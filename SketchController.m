//
//  SketchController.m
//  Scribbler
//
//  Created by Thomas Nägele on 20.05.10.
//  Copyright 2010 xonic. All rights reserved.
//

#import "SketchController.h"

id refToSelf; // declaration of a reference to self - to access class functions in outter c methods

@implementation SketchController

@synthesize activeSketchView, selectedColor, mainWindow, activeTabletID, isSticky, activeWindow, penIsNearTablet, mouseMode;



- (id) initWithMainWindow:(MainWindow *)theMainWindow
{
	if(![super init])
		return nil;
	
	if(theMainWindow == nil){
		NSLog(@"SketchController/initWithMainWindow:theMainWindow - ERROR: theMainWindow was nil");
		[self release];
		return nil;
	}
	
	mainWindow = [theMainWindow retain];
	
	// setup our color palette
	colorPalette = [[ColorController alloc] init];
	
	// setup our known tablets list
	tablets = [[NSMutableDictionary alloc] init];
	
	// Set the default Color to red
	selectedColor = [NSColor colorWithDeviceHue:0 saturation:1 brightness:1 alpha:1];
	
	// initialize array for list of windows
	windowModelList = [[NSMutableDictionary alloc] init];
	
	// initialize point variables for capture dragging
	startDragPoint = [[PointModel alloc] initWithDoubleX:-1 andDoubleY:-1];
	endDragPoint   = [[PointModel alloc] initWithDoubleX:-1 andDoubleY:-1];
	
	erase = NO;
	
	mouseMode = NO;
	penIsNearTablet = NO;
	
	isSticky = YES;
	
	activeTabletID = [[NSNumber alloc] init];
	
	activeScrollArea = NULL;
	

	
	// Start watching global events to figure out when to show the pane	
	[NSEvent addGlobalMonitorForEventsMatchingMask:
	 (NSLeftMouseDraggedMask | NSKeyDownMask | NSKeyUpMask | NSTabletProximityMask | NSMouseEnteredMask | NSLeftMouseDownMask | NSOtherMouseDownMask | NSRightMouseDown | NSOtherMouseDownMask)
										   handler:^(NSEvent *incomingEvent) {
											   
											   NSLog(@"GLOBAL EVENT--------------------------------------------------------GLOBAL EVENT");
											   
											   if ([activeSketchView clickThrough]) {
												   [activeSketchView updateKeyWindowBounds];
												   [activeSketchView setNeedsDisplay:YES];
											   }
											   
											   // Check whether the pen is near the tablet
											   if ([incomingEvent type] == NSTabletProximity) {
												   penIsNearTablet = [incomingEvent isEnteringProximity];
												   activeTabletID = [NSNumber numberWithInt:[incomingEvent systemTabletID]];
												   
												   if([incomingEvent isEnteringProximity]){
													   
													   NSLog(@"the tablet id is: %d", [incomingEvent systemTabletID]);
													   NSLog(@"the pointer unique id is: %d", [incomingEvent uniqueID]);
													   
													   selectedColor = [colorPalette getColorForPointerID:[NSNumber numberWithInt:[incomingEvent uniqueID]]];
													   
													   // check for tablet and pen id
													   NSNumber *theTabletID = [NSNumber numberWithInt:[incomingEvent systemTabletID]];
													   NSNumber *thePenID	 = [NSNumber numberWithInt:[incomingEvent uniqueID]];
													   
													   // this is a new tablet, create an object for it
													   if([tablets objectForKey:[theTabletID stringValue]] == nil)
													   {
														   TabletModel *newTablet = [[TabletModel alloc] initWithTabletID:theTabletID andColor:[colorPalette getColorFromPalette]];
														   [tablets setObject:newTablet forKey:[theTabletID stringValue]];
														   
														   [newTablet release];
													   }
													   
													   // the pen is new to the tablet, register it
													   if (![[tablets objectForKey:[theTabletID stringValue]] isPenRegistered:thePenID]) 
														   [[tablets objectForKey:[theTabletID stringValue]] registerPen:thePenID];
													   
													   // finally get the color for the pen
													   //selectedColor = [[tablets objectForKey:[theTabletID stringValue]] getColorForPen:thePenID];												   
												   } 

											   }
											   
											   if (penIsNearTablet) {
												   [activeSketchView setDrawWindowBounds:YES];
												   [activeSketchView setNeedsDisplay:YES];
											   } else {
												   [activeSketchView setDrawWindowBounds:NO];
												   [activeSketchView setNeedsDisplay:YES];
											   }

											   // ------------------------------------------------------------------------------- //
											   // GLOBAL - KEY EVENTS
											   // ------------------------------------------------------------------------------- //
											   
											   if([incomingEvent type] == NSKeyDown || [incomingEvent type] == NSKeyUp){
												   
												   // ------------------------------------------------------------------------------- //
												   // GLOBAL - MOUSE MODE
												   // ------------------------------------------------------------------------------- //
												   
												   // Enter mouse mode
												   if((((([incomingEvent modifierFlags] & NSCommandKeyMask) && 
														 ([incomingEvent modifierFlags] & NSShiftKeyMask)) && 
														([incomingEvent keyCode] == 10)) &&
													   ([incomingEvent type] == NSKeyUp)) && !mouseMode){
													   
													   if ([mainWindow isVisible]) {
														   [mainWindow showGlassPane:NO];
													   }
													   mouseMode = YES;

													   [activeSketchView updateKeyWindowBounds];
													   [activeSketchView setDrawWindowBounds:NO];
													   //[activeSketchView setDrawMouseModeBounds:YES];
													   [activeSketchView setNeedsDisplay:YES];
													   NSLog(@"MouseMode ON");

													   return;
												   } 
												   
												   // Exit mouse mode
												   if((((([incomingEvent modifierFlags] & NSCommandKeyMask) && 
														 ([incomingEvent modifierFlags] & NSShiftKeyMask)) && 
													  	 ([incomingEvent keyCode] == 10)) &&
														 ([incomingEvent type] == NSKeyUp)) && mouseMode){
													   
													   if (penIsNearTablet) {
														   NSLog(@"penIsNearTablet == YES");
														   [activeSketchView updateKeyWindowBounds];
														   [activeSketchView setDrawWindowBounds:YES];
														   //[activeSketchView setDrawMouseModeBounds:NO];
														   [activeSketchView setNeedsDisplay:YES];
														   [mainWindow showGlassPane:YES];
													   } else {
														    NSLog(@"penIsNearTablet == NO");
													   }

													   mouseMode = NO; 
													   NSLog(@"MouseMode OFF");
													   return;
												   }
												   
												   // ------------------------------------------------------------------------------- //
												   // GLOBAL - SCREENSHOT
												   // ------------------------------------------------------------------------------- //
												   
												   // The user pressed cmd+alt+ctrl+shift+S or the according tablet button
												   if(((([incomingEvent modifierFlags] & NSCommandKeyMask) && 
														([incomingEvent modifierFlags] & NSShiftKeyMask) && 
														([incomingEvent modifierFlags] & NSControlKeyMask) &&
														([incomingEvent modifierFlags] & NSAlternateKeyMask) &&
													    ([incomingEvent keyCode] == 1)) &&
													    ([incomingEvent type] == NSKeyUp))){
													   
													   if ([mainWindow isVisible]) {
														   ScreenShotController *screenGrabber = [[ScreenShotController alloc] init];
														   [screenGrabber grabScreenShotFromView:activeSketchView];
														   [screenGrabber release];
														   return;
													   } else {
														   [mainWindow showGlassPane:YES];
														   ScreenShotController *screenGrabber = [[ScreenShotController alloc] init];
														   [screenGrabber grabScreenShotFromView:activeSketchView];
														   [screenGrabber release];
														   [mainWindow showGlassPane:NO];
														   return;
													   }
												   }
												   
												   // ------------------------------------------------------------------------------- //
												   // GLOBAL - DELETE ALL PATHS
												   // ------------------------------------------------------------------------------- //
												   
												   // The user pressed cmd+alt+ctrl+shift+R or the according tablet button
												   if(((([incomingEvent modifierFlags] & NSCommandKeyMask) && 
														([incomingEvent modifierFlags] & NSShiftKeyMask) && 
														([incomingEvent modifierFlags] & NSControlKeyMask) &&
														([incomingEvent modifierFlags] & NSAlternateKeyMask) &&
													    ([incomingEvent keyCode] == 15)) &&
													    ([incomingEvent type] == NSKeyUp))){
													   
													   [[activeSketchView sketchModel] removeAllPathsForTablet:activeTabletID];
													   [activeSketchView setNeedsDisplay:YES];
													   return;
												   }
											   }
											   
											   // ------------------------------------------------------------------------------- //
											   // GLOBAL - VISIBILITY OF WINDOW BOUNDS
											   // ------------------------------------------------------------------------------- //
											   
											   if (penIsNearTablet && !mouseMode) {
												   [activeSketchView setDrawWindowBounds:YES];
												   [activeSketchView setNeedsDisplay:YES];
											   } else {
												   [activeSketchView setDrawWindowBounds:NO];
												   [activeSketchView setNeedsDisplay:YES];
											   }
											   
											   
												NSLog(@"----------------------- GLOBAL");
												NSLog(@"the event type is %d", [incomingEvent type]);
												if([incomingEvent type] == NSLeftMouseDown)
												NSLog(@"clickCount = %d", [incomingEvent clickCount]);
												if([incomingEvent type] == NSKeyDown || [incomingEvent type] == NSKeyUp)
												NSLog(@"modifierFlags: %d, keycode: %d", [incomingEvent modifierFlags], [incomingEvent keyCode]);
												if(mouseMode)
												NSLog(@"mouseMode = YES");
												else  
												NSLog(@"mouseMode = NO");
												if ([incomingEvent modifierFlags] & NSCommandKeyMask)
												NSLog(@"Command Key pressed");
												if ([incomingEvent modifierFlags] & NSAlternateKeyMask)
												NSLog(@"Alt Key pressed");
												if ([incomingEvent modifierFlags] & NSControlKeyMask)
												NSLog(@"Control Key pressed");
												if ([incomingEvent modifierFlags] & NSShiftKeyMask)
												NSLog(@"Shift Key pressed");
												NSLog(@"------------------------------");
												NSLog(@"");
												
											   
											   // ------------------------------------------------------------------------------- //
											   // GLOBAL - CHANGING KEY WINDOW
											   // ------------------------------------------------------------------------------- //
											   
											   // if change of keyWindow happens (this could only happen with a mouseDown event)
											   if ([incomingEvent type] == NSLeftMouseDown) {
												   NSLog(@"== MouseDown ==");
												   if ([incomingEvent subtype] != NSTabletPointEventSubtype && [incomingEvent subtype] != NSTabletProximityEventSubtype) {
													   [self keyWindowHandler];
												   }
												   
												   // Special case: if pen acts like mouse we would miss the above if-block
												   if (mouseMode) {
													   [self keyWindowHandler];
												   }
												   
												   // save windowposition in case of dragging
												   [startDragPoint initWithNSPoint:[self getKeyWindowBounds:[self getCurrentKeyWindowInfos]].origin];
											   }
											   
											   // ------------------------------------------------------------------------------- //
											   // GLOBAL - DRAWING
											   // ------------------------------------------------------------------------------- //
											   
											   // if tabletpen is near the tablet
											   if ([incomingEvent type] == NSTabletProximity && !mouseMode) {
												   
												   [mainWindow showGlassPane:[incomingEvent isEnteringProximity]];
												   
												   // Ignore the rest if pointing device exited proximity
												   if([incomingEvent isEnteringProximity]){
													   
													   // Check whether the user is drawing or erasing
													   if([incomingEvent pointingDeviceType] == NSEraserPointingDevice){
														   NSLog(@"Found Eraser");
														   erase = YES;
														   [activeSketchView setErase:YES];
													   } else {
														   NSLog(@"Found Pen");
														   erase = NO;
														   [activeSketchView setErase:NO];
													   }
												   }
											   }
											   
											   // ------------------------------------------------------------------------------- //
											   // GLOBAL - MOVING KEY WINDOW
											   // ------------------------------------------------------------------------------- //
											   
											   if ([incomingEvent type] == NSLeftMouseDragged && isSticky) {
												   												   
												   // check if we aren't accidentely on the scribbler window - if so don't handle dragging!
												   // (this can happen if the user's pen diverges too fast from tablet and comes close again immediately)
												   if (![[self getKeyWindowsApplicationName:[self getCurrentKeyWindowInfos]] isEqualToString:@"Scribbler"]) {
													   
													   // check whether there are paths to reposition
													   if([[[activeSketchView sketchModel] smoothedPaths] count] > 0){
													   
														   // renew scrollPositions
														   [activeWindow initScrollPositionsOfWindow];
													   
														   // save current windowposition
														   [endDragPoint initWithNSPoint:[self getKeyWindowBounds:[self getCurrentKeyWindowInfos]].origin];
													   
														   // calculate delta offset from startdragpoint (=window position @mouseDown) to enddragpoint (=current windowposition)
														   PointModel *delta = [[PointModel alloc] initWithDoubleX:[endDragPoint x]-[startDragPoint x] andDoubleY:[endDragPoint y]-[startDragPoint y]];
													   
														   // look if window was repositioned
														   if ([delta x]>0 || [delta x]<0 || [delta y]>0 || [delta y]<0) {
														   
															   // call function to reposition all paths with delta
															   [[activeSketchView sketchModel] repositionPaths:delta];
														   
															   // reset startpoint
															   [startDragPoint initWithNSPoint:[endDragPoint myNSPoint]];
														   
															   // repaint sketchView
															   [activeSketchView updateKeyWindowBounds];
															   [activeSketchView setNeedsDisplay:YES];
														   
															   // tell activeWindow that window was repositioned
															   [activeWindow setWindowWasRepositioned: YES];
															   NSLog(@"setWindowWasRepositioned: YES");
															   NSLog(@"currentAppName=%@",[self getKeyWindowsApplicationName:[self getCurrentKeyWindowInfos]]);
														   }
														   else {
															   // tell activeWindow that window was repositioned
															   [activeWindow setWindowWasRepositioned: NO];
															   NSLog(@"setWindowWasRepositioned: NO");
														   }
													   }	
												   }
											   }
											   
										   }]; 
	
	// watch out for scrolling events and handle them 
	[NSEvent addGlobalMonitorForEventsMatchingMask: 
	 (NSLeftMouseDraggedMask | NSScrollWheelMask | NSLeftMouseUpMask) handler:^(NSEvent *incomingEvent) {
		 
		 // check after each mouseUp if in the window was a scrolling event 
		 // + check for scrollWheel activity
		 NSEventType eventType = [incomingEvent type];
		 
		 if (eventType == NSLeftMouseUp || eventType == NSScrollWheel || eventType == NSLeftMouseDragged) {
			 
			 // if we can load AXData
			 if ([activeWindow loadAccessibilityData]) {
				 
				 BOOL wasScrolled = NO;
				 if ([activeWindow windowWasRepositioned]) {
					 NSLog(@"windowWasRepositioned:YES");
				 }
				 
				 // if window was scrolled
				 if (![activeWindow windowWasRepositioned]) {
					 NSLog(@"windowWasRepositioned:NO");					 
					 // get scrollArea
					 //NSLog(@"we're scrolling for app:%@",[activeWindow getTitleOfFocusedWindow]);
					 AXUIElementRef focusedUIElement = (AXUIElementRef)[activeWindow getUIElementUnderMouse];
					 AXUIElementRef parentOfUIElement = (AXUIElementRef)[activeWindow getParentOfUIElement:focusedUIElement];
					 //NSLog(@"searching scrollArea up from uiElement=%@",[activeWindow getTitleOfUIElement:focusedUIElement]);
					 AXUIElementRef scrollArea = (AXUIElementRef)[activeWindow getScrollAreaFromWhichUIElementIsChildOf:focusedUIElement];					 
					 SRUIElementType parentType = [activeWindow getTypeOfUIElement:parentOfUIElement];
					 SRUIElementType type = [activeWindow getTypeOfUIElement:scrollArea];
					 
					 // in case of the leftMouseUp or leftMouseDragged event check if click was on a scrollBar
					 // + in case of the scrollWheel event check if corresponding scrollArea was found
					 // + in case of a 
					 if ((parentType == SRUIElementIsPartOfAScrollbar && eventType == NSLeftMouseUp) || 
						 (type == SRUIElementIsScrollArea && eventType == NSScrollWheel) ||
						 (type == SRUIElementIsScrollArea && eventType == NSLeftMouseDragged) /*|| 
						 (parentType == SRUIElementHasNoRelevance && eventType == NSLeftMouseDragged)*/) {
						 
						 /*NSLog(@"== type:%d ==",type);
						 
						 if (parentType == SRUIElementHasNoRelevance && activeScrollArea != NULL) {
							 scrollArea = (AXUIElementRef)activeScrollArea;
							 NSLog(@"== scrollArea changed ==");
						 }*/
						 
						 // ensure that we've got the scrollArea
						 type = [activeWindow getTypeOfUIElement:scrollArea];
						 
						 if (type == SRUIElementIsScrollArea) {
							 // find the member of the scrollArea in order to get the current scrollPosition
							 AXUIElementRef member = (AXUIElementRef)[activeWindow getMemberFromScrollArea:scrollArea];
							 // ensure that we've got a member
							 if (member != nil) {
								 NSString *currentUID = [activeWindow getUIDofScrollArea:scrollArea];
								 NSValue *boundsBeforeValue = [lastScrollBounds objectForKey:currentUID];
								 
								 if (boundsBeforeValue) {
									 NSRect boundsBefore = [boundsBeforeValue rectValue];
									 NSRect boundsNow = [activeWindow getBoundsOfUIElement:member];
									 NSLog(@"positionBefore=(%f,%f)",boundsBefore.origin.x,boundsBefore.origin.y);
									 NSLog(@"positionNow   =(%f,%f)",boundsNow.origin.x,boundsNow.origin.y);
									 NSPoint lastMovingDiff;
									 // calc the movingChange
									 lastMovingDiff.x = boundsNow.origin.x-boundsBefore.origin.x;
									 lastMovingDiff.y = boundsNow.origin.y-boundsBefore.origin.y;
									 NSLog(@"lastMovingDiff=(%f,%f)",lastMovingDiff.x,lastMovingDiff.y);
									 
									 lastMovingDiff.x-=kumMovingDelta.x;
									 lastMovingDiff.y-=kumMovingDelta.y;
									 
									 if ((lastMovingDiff.x>0 || lastMovingDiff.x<0 || lastMovingDiff.y>0 || lastMovingDiff.y<0) && isSticky) {
										 
										 // generate the delta
										 PointModel *delta = [[PointModel alloc] initWithDoubleX:lastMovingDiff.x andDoubleY:lastMovingDiff.y];
										 NSLog(@"         delta=(%f,%f)",[delta x],[delta y]);
										 // call function to reposition all paths with delta
										 [[activeSketchView sketchModel] repositionPaths:delta];
										 // repaint sketchView
										 [activeSketchView setNeedsDisplay:YES];
										 
										 // save lastMovingDiff
										 kumMovingDelta.x+=lastMovingDiff.x;
										 kumMovingDelta.y+=lastMovingDiff.y;
										 NSLog(@"kumMovingDelta=(%f,%f)",kumMovingDelta.x,kumMovingDelta.y);
										 
										 wasScrolled = YES;
										 
										 /*if (eventType == NSLeftMouseDragged) {
											 NSLog(@"== MouseDragged ==");
											 activeScrollArea = (id)scrollArea;
										 }*/
									 }
								 }
							 }
						 }
					 }
					 /*else {
						 NSLog(@"type=%d focusedUIElement=%@",type,[activeWindow getTitleOfUIElement:focusedUIElement]);
					 }*/

				 }	
				 
				 /*if (eventType == NSLeftMouseUp) {
					 NSLog(@"== MouseUp ==");
					 activeScrollArea = NULL;
				 }*/
				
				 if(!wasScrolled && eventType == NSLeftMouseUp) {
					 [self refreshScrollingInfos];
				 }
				
			 }
			 else {
				 kumMovingDelta = NSZeroPoint;
				 [activeWindow setWindowWasRepositioned:NO];
			 }

		 }		 
	 }];
	
	// Start watching local events to figure out when to hide the pane	
	[NSEvent addLocalMonitorForEventsMatchingMask:
	 (NSOtherMouseDownMask | NSRightMouseDownMask | NSMouseMovedMask | NSKeyDownMask | NSKeyUpMask | NSTabletProximityMask)// | NSTabletPointMask)
										  handler:^(NSEvent *incomingEvent) {
											  
											  NSEvent *result = incomingEvent;
											  
											  NSLog(@"LOCAL EVENT----------------------------------------------------------LOCAL EVENT");
											  
											  // ------------------------------------------------------------------------------- //
											  // LOCAL - PROXIMITY EVENT
											  // ------------------------------------------------------------------------------- //
											  
											  // Check whether the pen is near the tablet
											  if ([incomingEvent type] == NSTabletProximity) {
												  penIsNearTablet = [incomingEvent isEnteringProximity];
												  activeTabletID = [NSNumber numberWithInt:[incomingEvent systemTabletID]];
												  
												  if([incomingEvent isEnteringProximity]){
													  //NSLog(@"the tablet id is: %d", [incomingEvent systemTabletID]);
													  //NSLog(@"the pointer unique id is: %d", [incomingEvent uniqueID]);
													  
													  selectedColor = [colorPalette getColorForPointerID:[NSNumber numberWithInt:[incomingEvent uniqueID]]];
													  
													  // check for tablet and pen id
													  NSNumber *theTabletID = [NSNumber numberWithInt:[incomingEvent systemTabletID]];
													  NSNumber *thePenID	 = [NSNumber numberWithInt:[incomingEvent uniqueID]];
													  
													  // this is a new tablet, create an object for it
													  if([tablets objectForKey:[theTabletID stringValue]] == nil)
													  {
														  TabletModel *newTablet = [[TabletModel alloc] initWithTabletID:theTabletID andColor:[colorPalette getColorFromPalette]];
														  [tablets setObject:newTablet forKey:[theTabletID stringValue]];
													  }
													  
													  // the pen is new to the tablet, register it
													  if (![[tablets objectForKey:[theTabletID stringValue]] isPenRegistered:thePenID]) 
														  [[tablets objectForKey:[theTabletID stringValue]] registerPen:thePenID];
													  
													  // finally get the color for the pen
													  //selectedColor = [[tablets objectForKey:[theTabletID stringValue]] getColorForPen:thePenID];
												  }												  
											  }		
											  
											  // ------------------------------------------------------------------------------- //
											  // LOCAL - UNDO
											  // ------------------------------------------------------------------------------- //
											  
											  if ([incomingEvent type] == NSRightMouseDown) {
												  NSLog(@"systemtabletID = %d", [incomingEvent systemTabletID]);
												  [[activeSketchView sketchModel] undoForTablet:activeTabletID];
												  [activeSketchView setNeedsDisplay:YES];
												  return result;
											  }
											  
											  // ------------------------------------------------------------------------------- //
											  // LOCAL - REDO
											  // ------------------------------------------------------------------------------- //
											  
											  if ([incomingEvent type] == NSOtherMouseDown) {
												  [[activeSketchView sketchModel] redoForTablet:activeTabletID];
												  [activeSketchView setNeedsDisplay:YES];
												  return result;
											  }
											  
											  
											  // ------------------------------------------------------------------------------- //
											  // LOCAL - KEY EVENTS
											  // ------------------------------------------------------------------------------- //
											  
											  if([incomingEvent type] == NSKeyDown || [incomingEvent type] == NSKeyUp){
												  
												  // ------------------------------------------------------------------------------- //
												  // LOCAL - MOUSE MODE
												  // ------------------------------------------------------------------------------- //
												  
												  // Enter mouse mode
												  if((((([incomingEvent modifierFlags] & NSCommandKeyMask) && 
													    ([incomingEvent modifierFlags] & NSShiftKeyMask)) && 
													   ([incomingEvent keyCode] == 10)) &&
													  ([incomingEvent type] == NSKeyUp)) && !mouseMode){
													  
													  if ([mainWindow isVisible]) {
														  [mainWindow showGlassPane:NO];
													  }
													  mouseMode = YES;
													  [activeSketchView updateKeyWindowBounds];
													  [activeSketchView setDrawWindowBounds:NO];
													  //[activeSketchView setDrawMouseModeBounds:YES];
													  [activeSketchView setNeedsDisplay:YES];
													  NSLog(@"MouseMode ON");

													  return result;
												  } 
												  
												  // Exit mouse mode
												  if((((([incomingEvent modifierFlags] & NSCommandKeyMask) && 
													    ([incomingEvent modifierFlags] & NSShiftKeyMask)) && 
													   ([incomingEvent keyCode] == 10)) &&
													  ([incomingEvent type] == NSKeyUp)) && mouseMode){
													  
													  if (penIsNearTablet) {
														  NSLog(@"penIsNearTablet == YES");
														  [activeSketchView updateKeyWindowBounds];
														  [activeSketchView setDrawWindowBounds:YES];
														  //[activeSketchView setDrawMouseModeBounds:NO];
														  [activeSketchView setNeedsDisplay:YES];
														  [mainWindow showGlassPane:YES];
													  }else {
														  NSLog(@"penIsNearTablet == NO");
													  }

													  mouseMode = NO; 
													  NSLog(@"MouseMode OFF");

													  return result;
												  }
												  
												  // ------------------------------------------------------------------------------- //
												  // LOCAL - SCREENSHOT
												  // ------------------------------------------------------------------------------- //
												  
												  // The user pressed cmd+alt+ctrl+shift+S or the according tablet button
												  if(((((([incomingEvent modifierFlags] & NSCommandKeyMask) && 
														 ([incomingEvent modifierFlags] & NSShiftKeyMask)) && 
														 ([incomingEvent modifierFlags] & NSControlKeyMask)) &&
													   	 ([incomingEvent modifierFlags] & NSAlternateKeyMask)) &&
													  	 ([incomingEvent keyCode] == 1)) &&
													 	 ([incomingEvent type] == NSKeyUp)){
													  
													  if ([mainWindow isVisible]) {
														  ScreenShotController *screenGrabber = [[ScreenShotController alloc] init];
														  [screenGrabber grabScreenShotFromView:activeSketchView];
														  [screenGrabber release];
														  return result;
													  } else {
														  [mainWindow showGlassPane:YES];
														  ScreenShotController *screenGrabber = [[ScreenShotController alloc] init];
														  [screenGrabber grabScreenShotFromView:activeSketchView];
														  [screenGrabber release];
														  [mainWindow showGlassPane:NO];
														  return result;
													  }
												  }
												  
												  // ------------------------------------------------------------------------------- //
												  // LOCAL - DELETE ALL PATHS
												  // ------------------------------------------------------------------------------- //
												  
												  // The user pressed cmd+alt+ctrl+shift+R or the according tablet button
												  if(((([incomingEvent modifierFlags] & NSCommandKeyMask) && 
													   ([incomingEvent modifierFlags] & NSShiftKeyMask) && 
													   ([incomingEvent modifierFlags] & NSControlKeyMask) &&
													   ([incomingEvent modifierFlags] & NSAlternateKeyMask) &&
													   ([incomingEvent keyCode] == 15)) &&
													  ([incomingEvent type] == NSKeyUp))){
													  
													  [[activeSketchView sketchModel] removeAllPathsForTablet:activeTabletID];
													  [activeSketchView setNeedsDisplay:YES];
													  return result;
												  }
											  }
											  
											  // ------------------------------------------------------------------------------- //
											  // LOCAL - VISIBILITY OF WINDOW BOUNDS
											  // ------------------------------------------------------------------------------- //
											  
											  if (penIsNearTablet && !mouseMode) {
												  [activeSketchView setDrawWindowBounds:YES];
												  [activeSketchView setNeedsDisplay:YES];
											  } else {
												  [activeSketchView setDrawWindowBounds:NO];
												  [activeSketchView setNeedsDisplay:YES];
											  }
											  
											/*
											  NSLog(@"------------------------ LOCAL");
											  NSLog(@"the event type is %d", [incomingEvent type]);
											  if([incomingEvent type] == NSLeftMouseDown)
												  NSLog(@"clickCount = %d", [incomingEvent clickCount]);
											  if([incomingEvent type] == NSKeyDown || [incomingEvent type] == NSKeyUp)
												  NSLog(@"modifierFlags: %d, keycode: %d", [incomingEvent modifierFlags], [incomingEvent keyCode]);
											  if(mouseMode)
												  NSLog(@"mouseMode = YES");
											  else  
												  NSLog(@"mouseMode = NO");
											  if ([incomingEvent modifierFlags] & NSCommandKeyMask)
												  NSLog(@"Command Key pressed");
											  if ([incomingEvent modifierFlags] & NSAlternateKeyMask)
												  NSLog(@"Alt Key pressed");
											  if ([incomingEvent modifierFlags] & NSControlKeyMask)
												  NSLog(@"Control Key pressed");
											  if ([incomingEvent modifierFlags] & NSShiftKeyMask)
												  NSLog(@"Shift Key pressed");
											  NSLog(@"------------------------------");
											  NSLog(@"");
											  */
											  /*
											   NSLog(@"------------------------ LOCAL");
											   NSLog(@"the event type is %d", [incomingEvent type]);
											   if([incomingEvent type] == NSLeftMouseDown)
											   NSLog(@"clickCount = %d", [incomingEvent clickCount]);
											   if([incomingEvent type] == NSKeyDown || [incomingEvent type] == NSKeyUp)
											   NSLog(@"modifierFlags: %d, keycode: %d", [incomingEvent modifierFlags], [incomingEvent keyCode]);
											   if(mouseMode)
											   NSLog(@"mouseMode = YES");
											   else  
											   NSLog(@"mouseMode = NO");
											   if ([incomingEvent modifierFlags] & NSCommandKeyMask)
											   NSLog(@"Command Key pressed");
											   if ([incomingEvent modifierFlags] & NSAlternateKeyMask)
											   NSLog(@"Alt Key pressed");
											   if ([incomingEvent modifierFlags] & NSControlKeyMask)
											   NSLog(@"Control Key pressed");
											   if ([incomingEvent modifierFlags] & NSShiftKeyMask)
											   NSLog(@"Shift Key pressed");
											   NSLog(@"------------------------------");
											   NSLog(@"");
											   */
											  
											  // ------------------------------------------------------------------------------- //
											  // LOCAL - DRAWING
											  // ------------------------------------------------------------------------------- //
											  
											  // if tabletpen is near the tablet
											  if ([incomingEvent type] == NSTabletProximity && !mouseMode){
												  
												  [mainWindow showGlassPane:[incomingEvent isEnteringProximity]];
												  
												  // Ignore the rest if pointing device exited proximity
												  if([incomingEvent isEnteringProximity]){

													  // Check whether the user is drawing or erasing
													  if([incomingEvent pointingDeviceType] == NSEraserPointingDevice){
														  //NSLog(@"Found Eraser");
														  erase = YES;
														  [activeSketchView setErase:YES];
													  } else {
														  //NSLog(@"Found Pen");
														  erase = NO;
														  [activeSketchView setErase:NO];
													  }
												  }
											  }
											  
											  return result;
										  }]; 
	
	
	// start the notificationCenter to catch windowActivation Events
	[[[NSWorkspace sharedWorkspace]
	  notificationCenter] addObserver:self	 
	 selector:@selector(anAppWasActivated:)
	 name:nil 
	 object:nil];
	
	// save reference from self
	refToSelf = self;
	
	return self;	
}

#pragma mark Events

- (void) handleMouseDownAt:(NSPoint)inputPoint from:(SketchView *)sender
{
	// Drawing or Erasing?
	if (!erase){
		// Create a new Path
		[[sender sketchModel] createNewPathAt:inputPoint withColor:selectedColor];
	} else {
		// Remove intersecting Path
		[[sender sketchModel] removePathIntersectingWith:inputPoint forTablet:activeTabletID];
	}
	[sender setNeedsDisplay:YES];
}

- (void) handleMouseDraggedAt:(NSPoint)inputPoint from:(SketchView *)sender
{
	// Drawing or Erasing?
	if (!erase){
		// Continue current Path
		[[sender sketchModel] addPointToCurrentPath:inputPoint];
	} else {
		// Remove intersecting Path
		[[sender sketchModel] removePathIntersectingWith:inputPoint forTablet:activeTabletID];
	}
	[sender setNeedsDisplay:YES];
}

- (void) handleMouseUpAt:(NSPoint)inputPoint from:(SketchView *)sender
{
	// Drawing or Erasing?
	if (!erase){
		// Conclude Path and save it
		[[sender sketchModel] addPointToCurrentPath:inputPoint];
		[[sender sketchModel] saveCurrentPathWithOwner:activeTabletID];
	} else {
		// Remove intersecting Path
		[[sender sketchModel] removePathIntersectingWith:inputPoint forTablet:activeTabletID];
	}
	[sender setNeedsDisplay:YES];
}

#pragma mark SketchView Visibility

- (void) setClickThrough:(BOOL)flag
{
	[activeSketchView setClickThrough:flag];
	[activeSketchView setNeedsDisplay:YES];
}

- (void) showHide
{
	if ([activeSketchView draw]) {
		[activeSketchView setDraw:NO];
		[activeSketchView setNeedsDisplay:YES];
	} else {
		[activeSketchView setDraw:YES];
		[activeSketchView setNeedsDisplay:YES];
	}
	
}

#pragma mark KeyWindow Functions

- (NSMutableDictionary*)getCurrentKeyWindowInfos
{
	//get info about the currently active application
	NSWorkspace* workspace            = [NSWorkspace sharedWorkspace];
	NSDictionary* currentAppInfo      = [workspace activeApplication];
	
	//get the PSN of the current app
	UInt32 lowLong                    = [[currentAppInfo objectForKey:@"NSApplicationProcessSerialNumberLow"] longValue];
	UInt32 highLong                   = [[currentAppInfo objectForKey:@"NSApplicationProcessSerialNumberHigh"] longValue];
	ProcessSerialNumber currentAppPSN = {highLong,lowLong};
	
	//grab window information from the window server
	CFArrayRef windowList             = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID);
	ProcessSerialNumber myPSN         = {kNoProcess, kNoProcess};
	
	//loop through the windows, the window list is ordered from front to back
	for (NSMutableDictionary* entry in (NSArray*) windowList)
	{
		int pid = [[entry objectForKey:(id)kCGWindowOwnerPID] intValue];
		GetProcessForPID(pid, &myPSN);
		
		//if the process of the current window in the list matches our process, get the front window number
		if(myPSN.lowLongOfPSN == currentAppPSN.lowLongOfPSN && myPSN.highLongOfPSN == currentAppPSN.highLongOfPSN)
		{
			[entry retain]; 
			CFRelease(windowList);
			//return because we found front window
			return entry;
		}
	}
	
	return 0;
}

- (NSNumber*) getKeyWindowID: (NSMutableDictionary*)windowInfos
{
	return [NSNumber numberWithInt:[[windowInfos objectForKey:(id)kCGWindowNumber] intValue]];
}

- (int) getProcessID: (NSMutableDictionary*)windowInfos
{
	return [[windowInfos objectForKey:(id)kCGWindowOwnerPID] intValue];
}

- (NSString*) getKeyWindowsApplicationName: (NSMutableDictionary*)windowInfos
{
	return [windowInfos objectForKey:(id)kCGWindowOwnerName];
}

- (NSRect) getKeyWindowBounds: (NSMutableDictionary*) windowInfos
{
	CGRect rect;
	CFDictionaryRef ref = (CFDictionaryRef)[windowInfos objectForKey:(id)kCGWindowBounds];
	CGRectMakeWithDictionaryRepresentation(ref, &rect);
	
	return *(NSRect *)&rect;
}

- (void) keyWindowHandler
{
	//NSLog(@"--- keyWindowHandler ---");
	
	// get current key window infos
	NSMutableDictionary* currentInfos = [self getCurrentKeyWindowInfos];
	// get keyWindowID
	NSNumber* keyID = [self getKeyWindowID:currentInfos];
	// get keyWindow App Name
	NSString* appName = [self getKeyWindowsApplicationName:currentInfos];
	// get processID
	int pid = [self getProcessID:currentInfos];
	
	if (keyID == nil) {
		NSLog(@"returned from keyWindowHandler because keyID was nil!");
		return;
	}
	
	// check if we accidentely have scribbler as key or a unTitled app, like the dock
	if ([appName isEqualToString:@"Scribbler"] /*|| appName==NULL*/) {
		NSLog(@"returned from keyWindowHandler because the window was scribbler or an app without window!");
		return;
	}
	
	// check if the key is on no menuBar
	if ([activeWindow loadAccessibilityData]) {
		AXUIElementRef focusedUIElement = (AXUIElementRef)[activeWindow getUIElementUnderMouse];
		if(![activeWindow isUIElementChildOfWindow:focusedUIElement]) {
			NSLog(@"returned from keyWindowHandler because of no window!");
			return;
		}
	}
	
	// lookup if there is an arrayEntry for this ID
	if ([windowModelList objectForKey:keyID] == nil) {
		
		// create the new classes for the window
		SketchModel *newModel  = [[SketchModel alloc] initWithController:self andWindow:mainWindow];
		WindowModel *newWindow = [[WindowModel alloc] initWithController:self];
		
		// the view is being created by the TabModel itself
		// so we just query the view from the model
		SketchView  *newView   = [[[newWindow activeSubWindow] view] retain];
		
		// add to our list
		[windowModelList setObject:newWindow forKey:keyID];
		activeWindow = newWindow;
		
		//NSLog(@"added window %@ from app %@ with id %@ to array",[windowModelList objectForKey:keyID],appName,keyID);
		NSLog(@"we have now %d windows in our windowModelList", [windowModelList count]);
		NSLog(@"added window %@ from app %@ with id %@ to array",[windowModelList objectForKey:keyID],appName,keyID);
		
		// set as active
		activeSketchView = [newView retain];
		[mainWindow setContentView:activeSketchView];
		
		// register keyWindow for accessibility notifications (to get notifications even if the user switch to another window via exposé)
		[self registerForAccessibilityEvents:pid];
		
		// free your mind... uhm... memory
		[newModel  release];
		[newView   release];
		[newWindow release];
	}
	else {
		// switch to other view
		
		if (activeSketchView != [[[windowModelList objectForKey:keyID] activeSubWindow] view]) {
			activeSketchView = [[[windowModelList objectForKey:keyID] activeSubWindow] view];
			[mainWindow setContentView:activeSketchView];
			
			activeWindow = [windowModelList objectForKey:keyID];
			NSLog(@"in Array: switched to window %@ with id %@", activeSketchView, keyID);
			//[keyID release];
		}
		
	}
}

- (void)anAppWasActivated:(NSNotification *)notification
{
	// if an other application was activated (eg. via exposé or appSwitcher)
	if ([[notification name] isEqualToString:@"NSWorkspaceDidActivateApplicationNotification"]) {
		// call keyWindowHandler, but only if it wasn't scribbler itself which was activated
		if( ![[self getKeyWindowsApplicationName: [self getCurrentKeyWindowInfos]] isEqualToString:[[NSRunningApplication currentApplication] localizedName]] )
			[self keyWindowHandler];
	}
}

- (void) registerForAccessibilityEvents:(int) pid {
	// pid can be NULL(0) if the application is only in dock (minimized or inactive)
	// and application was reached via the appSwitcher
	if (pid!=0) {
		AXUIElementRef sys = AXUIElementCreateApplication(pid);
		AXError err;
		AXObserverRef observer;
		err = AXObserverCreate (pid, callback, &observer);
		err = AXObserverAddNotification(observer, sys, kAXFocusedWindowChangedNotification, NULL);
		CFRunLoopAddSource ([[NSRunLoop currentRunLoop] getCFRunLoop], AXObserverGetRunLoopSource(observer), kCFRunLoopDefaultMode);
	}
	
	// TODO: if an app was reached via the appSwitcher but is only in dock - a view is created for the dock
	//		 how should scribbler handle the situation in order to ensure user satisfaction?
	// NOTE: offer feedback to user with a short visual notification to which window the user will be drawing. eg. showing
	//		 windowBounds for a second with fadeout when proximity event occurs (only first time after keyWindow has changed)
}

- (void) refreshScrollingInfos {
	NSLog(@"save all window scrollBounds");
	[activeWindow loadAccessibilityData];
	[activeWindow initScrollPositionsOfWindow];
	lastScrollBounds = [activeWindow getScrollingInfosOfCurrentWindow];
	kumMovingDelta = NSZeroPoint;
	[activeWindow setWindowWasRepositioned:NO];
}

@end


static void callback (AXObserverRef observer, AXUIElementRef element, CFStringRef notification, void *refcon)
{
	[refToSelf anAppWasActivated:[NSNotification notificationWithName:@"NSWorkspaceDidActivateApplicationNotification" 
															   object:refToSelf 
															 userInfo:nil]];	
}
