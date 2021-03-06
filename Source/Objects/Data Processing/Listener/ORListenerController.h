//--------------------------------------------------------
// ORListenerController
// Created by Mark  A. Howe on Mon Apr 11 2005
// Code partially generated by the OrcaCodeWizard. Written by Mark A. Howe.
// Copyright (c) 2005 CENPA, University of Washington. All rights reserved.
//-----------------------------------------------------------
//This program was prepared for the Regents of the University of 
//Washington at the Center for Experimental Nuclear Physics and 
//Astrophysics (CENPA) sponsored in part by the United States 
//Department of Energy (DOE) under Grant #DE-FG02-97ER41020. 
//The University has certain rights in the program pursuant to 
//the contract and the program should not be copied or distributed 
//outside your organization.  The DOE and the University of 
//Washington reserve all rights in the program. Neither the authors,
//University of Washington, or U.S. Government make any warranty, 
//express or implied, or assume any liability or responsibility 
//for the use of this software.
//-------------------------------------------------------------

@interface ORListenerController : OrcaObjectController
{
	IBOutlet NSTextField*   remotePortField;
	IBOutlet NSTextField*   remoteHostField;
	IBOutlet NSTextField*   connectionStatusField;
	IBOutlet NSTextField*   byteRecievedField;
	IBOutlet NSButton*      connectButton;
    IBOutlet NSButton*      lockButton;
	IBOutlet NSButton*      connectAtStartButton;
	IBOutlet NSButton*      autoReconnectButton;
}

#pragma mark ***Initialization
- (id) init;
- (void) dealloc;
- (void) awakeFromNib;

#pragma mark ***Notifications
- (void) registerNotificationObservers;
- (void) updateWindow;
- (void) remotePortChanged:(NSNotification*)note;
- (void) remoteHostChanged:(NSNotification*)note;
- (void) isConnectedChanged:(NSNotification*)note;
- (void) byteCountChanged:(NSNotification*)note;
- (void) lockChanged:(NSNotification*)aNotification;
- (void) connectAtStartChanged:(NSNotification*)note;
- (void) autoReconnectChanged:(NSNotification*)note;

#pragma mark ***Accessors

#pragma mark ***Actions
- (IBAction) lockAction:(id)sender;
- (IBAction) remotePortFieldAction:(id)sender;
- (IBAction) remoteHostFieldAction:(id)sender;
- (IBAction) connectButtonAction:(id)sender;
- (IBAction) connectAtStartAction:(id)sender;
- (IBAction) autoReconnectAction:(id)sender;
@end

