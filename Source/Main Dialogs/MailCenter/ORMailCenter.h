//----------------------------------------------------------
//  ORMailCenter.m
//
//  Created by Mark Howe on Wed Mar 29, 2006.
//  Copyright  � 2002 CENPA. All rights reserved.
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



#pragma mark ���Forward Declarations
@class ORDataSet;

@interface ORMailCenter : NSWindowController
{
	IBOutlet NSForm* mailForm;
	IBOutlet NSTextView* bodyField;
	
	BOOL selfRetained;
	NSString* fileToAttach;
}

+ (id) mailCenter;
- (id)init;
- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow*)window;
- (void) windowWillClose:(NSNotification*)aNote;
- (void) sendit;

#pragma mark ���Accessors
- (void) setFileToAttach:(NSString*)aFileToAttach;
- (void) setTextBodyToRTFData:(NSData*)rtfdata;

#pragma mark ���Actions
- (IBAction) send:(id)sender;
- (void) noAddressSheetDidEnd:(id)sheet returnCode:(int)returnCode contextInfo:(id)userInfo;
- (void) noSubjectSheetDidEnd:(id)sheet returnCode:(int)returnCode contextInfo:(id)userInfo;

@end

