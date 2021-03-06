//
//  ORCouchDBController.m
//  Orca
//
//  Created by Mark Howe on 10/18/06.
//  Copyright 2006 CENPA, University of Washington. All rights reserved.
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


#import "ORCouchDBController.h"
#import "ORCouchDBModel.h"
#import "ORCouchDB.h"
#import "ORValueBarGroupView.h"

@interface ORCouchDBController (private)
- (void) createActionDidEnd:(id)sheet returnCode:(int)returnCode contextInfo:(id)userInfo;
- (void) deleteActionDidEnd:(id)sheet returnCode:(int)returnCode contextInfo:(id)userInfo;
- (void) stealthActionDidEnd:(id)sheet returnCode:(int)returnCode contextInfo:(id)userInfo;
- (void) historyActionDidEnd:(id)sheet returnCode:(int)returnCode contextInfo:(id)userInfo;
@end

@implementation ORCouchDBController

#pragma mark •••Initialization
-(id)init
{
    self = [super initWithWindowNibName:@"CouchDB"];
    return self;
}

- (void) dealloc
{
	[[[ORCouchDBQueue sharedCouchDBQueue] queue] removeObserver:self forKeyPath:@"operationCount"];
	[super dealloc];
}

-(void) awakeFromNib
{
	[super awakeFromNib];
	[[[ORCouchDBQueue sharedCouchDBQueue]queue] addObserver:self forKeyPath:@"operationCount" options:0 context:NULL];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object 
                         change:(NSDictionary *)change context:(void *)context
{
	NSOperationQueue* queue = [[ORCouchDBQueue sharedCouchDBQueue] queue];
    if (object == queue && [keyPath isEqual:@"operationCount"]) {
		NSNumber* n = [NSNumber numberWithInt:[[[ORCouchDBQueue queue] operations] count]];
		[self performSelectorOnMainThread:@selector(setQueCount:) withObject:n waitUntilDone:NO];
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
	
}

- (void) setQueCount:(NSNumber*)n
{
	queueCount = [n intValue];
	[queueValueBar setNeedsDisplay:YES];
}

- (double) doubleValue
{
	return queueCount;
}

#pragma mark •••Registration
- (void) registerNotificationObservers
{
    NSNotificationCenter* notifyCenter = [NSNotificationCenter defaultCenter];
    
    [super registerNotificationObservers];
    
    [notifyCenter addObserver : self
                     selector : @selector(remoteHostNameChanged:)
                         name : ORCouchDBRemoteHostNameChanged
                       object : model];
    
    [notifyCenter addObserver : self
                     selector : @selector(localHostNameChanged:)
                         name : ORCouchDBLocalHostNameChanged
                       object : model];
    
    [notifyCenter addObserver : self
                     selector : @selector(userNameChanged:)
                         name : ORCouchDBUserNameChanged
                       object : model];
	
    [notifyCenter addObserver : self
                     selector : @selector(passwordChanged:)
                         name : ORCouchDBPasswordChanged
                       object : model];

    [notifyCenter addObserver : self
                     selector : @selector(portChanged:)
                         name : ORCouchDBPortNumberChanged
                       object : model];
    
    [notifyCenter addObserver : self
                     selector : @selector(couchDBLockChanged:)
                         name : ORCouchDBLock
                       object : nil];
	
    [notifyCenter addObserver : self
                     selector : @selector(couchDBLockChanged:)
                         name : ORRunStatusChangedNotification
                       object : nil];
	
    [notifyCenter addObserver : self
                     selector : @selector(stealthModeChanged:)
                         name : ORCouchDBModelStealthModeChanged
						object: model];
	
    [notifyCenter addObserver : self
                     selector : @selector(dataBaseInfoChanged:)
                         name : ORCouchDBModelDBInfoChanged
						object: model];	
	
    [notifyCenter addObserver : self
                     selector : @selector(keepHistoryChanged:)
                         name : ORCouchDBModelKeepHistoryChanged
						object: model];
    
    [notifyCenter addObserver : self
                     selector : @selector(replicationRunningChanged:)
                         name : ORCouchDBModelReplicationRunningChanged
						object: model];
    
    [notifyCenter addObserver : self
                     selector : @selector(usingUpdateHandlerChanged:)
                         name : ORCouchDBModelUsingUpdateHandleChanged
						object: model];
}

- (void) updateWindow
{
	[super updateWindow];
	[self remoteHostNameChanged:nil];
	[self localHostNameChanged:nil];
	[self userNameChanged:nil];
	[self passwordChanged:nil];
	[self portChanged:nil];
	[self dataBaseNameChanged:nil];
    [self couchDBLockChanged:nil];
	[self stealthModeChanged:nil];
	[self keepHistoryChanged:nil];
	[self replicationRunningChanged:nil];
	[self usingUpdateHandlerChanged:nil];
}

- (void) usingUpdateHandlerChanged:(NSNotification*)aNote
{
	[usingUpdateHandlerField setStringValue: [model usingUpdateHandler]?@"Using Update Handler":@""];
}


- (void) replicationRunningChanged:(NSNotification*)aNote
{
	[replicationRunningTextField setStringValue: [model replicationRunning]?@"Replicating":@"NOT Replicating"];
}

- (void) keepHistoryChanged:(NSNotification*)aNote
{
	[keepHistoryCB setIntValue: [model keepHistory]];
	[keepHistoryStatusField setStringValue:([model keepHistory] & ![model stealthMode])?@"":@"Disabled"];
}

- (void) stealthModeChanged:(NSNotification*)aNote
{
	[stealthModeButton setIntValue: [model stealthMode]];
	[dbStatusField setStringValue:![model stealthMode]?@"":@"Disabled"];
	[keepHistoryStatusField setStringValue:([model keepHistory] & ![model stealthMode])?@"":@"Disabled"];
}

- (void) remoteHostNameChanged:(NSNotification*)aNote
{
	if([model remoteHostName])[remoteHostNameField setStringValue:[model remoteHostName]];
}

- (void) localHostNameChanged:(NSNotification*)aNote
{
	if([model localHostName])[localHostNameField   setStringValue:[model localHostName]];
}

- (void) userNameChanged:(NSNotification*)aNote
{
	if([model userName])[userNameField setStringValue:[model userName]];
}

- (void) passwordChanged:(NSNotification*)aNote
{
	if([model password])[passwordField setStringValue:[model password]];
}

- (void) portChanged:(NSNotification*)aNote
{
    [portField setIntegerValue:[model portNumber]];
}

- (void) dataBaseNameChanged:(NSNotification*)aNote
{
	[dataBaseNameField setStringValue:[model databaseName]];
	[historyDataBaseNameField setStringValue:[model historyDatabaseName]];
}

- (void) couchDBLockChanged:(NSNotification*)aNote
{
    BOOL locked = [gSecurity isLocked:ORCouchDBLock];
    [couchDBLockButton setState: locked];
    
    [remoteHostNameField setEnabled:!locked];
    [localHostNameField setEnabled:!locked];
    [userNameField setEnabled:!locked];
    [passwordField setEnabled:!locked];
    [portField setEnabled:!locked];
    [keepHistoryCB setEnabled:!locked];
    [stealthModeButton setEnabled:!locked];
}

- (void) checkGlobalSecurity
{
    BOOL secure = [gSecurity globalSecurityEnabled];
    [gSecurity setLock:ORCouchDBLock to:secure];
    [couchDBLockButton setEnabled: secure];
}

- (void) dataBaseInfoChanged:(NSNotification*)aNote
{
	NSDictionary* dbInfo = [model dBInfo];
	unsigned long dbSize = [[dbInfo objectForKey:@"disk_size"] unsignedLongValue];
	if(dbSize > 1000000000)[dbSizeField setStringValue:[NSString stringWithFormat:@"%.2f GB",dbSize/1000000000.]];
	else if(dbSize > 1000000)[dbSizeField setStringValue:[NSString stringWithFormat:@"%.2f MB",dbSize/1000000.]];
	else if(dbSize > 1000)[dbSizeField setStringValue:[NSString stringWithFormat:@"%.1f KB",dbSize/1000.]];
	else [dbSizeField setStringValue:[NSString stringWithFormat:@"%lu Bytes",dbSize]];

	dbInfo = [model dBHistoryInfo];
	dbSize = [[dbInfo objectForKey:@"disk_size"] unsignedLongValue];
	if(dbSize > 1000000000)[dbHistorySizeField setStringValue:[NSString stringWithFormat:@"%.2f GB",dbSize/1000000000.]];
	else if(dbSize > 1000000)[dbHistorySizeField setStringValue:[NSString stringWithFormat:@"%.2f MB",dbSize/1000000.]];
	else if(dbSize > 1000)[dbHistorySizeField setStringValue:[NSString stringWithFormat:@"%.1f KB",dbSize/1000.]];
	else [dbHistorySizeField setStringValue:[NSString stringWithFormat:@"%lu Bytes",dbSize]];
	
}

#pragma mark •••Actions

- (IBAction) startReplicationAction:(id)sender
{
    [model createRemoteDataBases];
	[model startReplication];
}
- (IBAction) createRemoteDBAction:(id)sender
{
	[model createRemoteDataBases];
}

- (IBAction) keepHistoryAction:(id)sender
{
	
    if([model keepHistory]){
        NSString* s = [NSString stringWithFormat:@"Really DOs NOT keep a history: %@?\n",[model databaseName]];
        NSBeginAlertSheet(s,
                          @"Cancel",
                          @"Yes, Disable History",
                          nil,[self window],
                          self,
                          @selector(historyActionDidEnd:returnCode:contextInfo:),
                          nil,
                          nil,@"There will be NO history (only run status) kept if you deactivate this option.");
    }
    else [model setKeepHistory:YES];

}

- (IBAction) stealthModeAction:(id)sender
{
    if(![model stealthMode]){
        NSString* s = [NSString stringWithFormat:@"Really disable the database: %@?\n",[model databaseName]];
        NSBeginAlertSheet(s,
                          @"Cancel",
                          @"Yes, Disable Database",
                          nil,[self window],
                          self,
                          @selector(stealthActionDidEnd:returnCode:contextInfo:),
                          nil,
                          nil,@"There will be NO values automatically put in to the database if you activate this option.");
    }
    else [model setStealthMode:NO];
}

- (IBAction) couchDBLockAction:(id)sender
{
    [gSecurity tryToSetLock:ORCouchDBLock to:[sender intValue] forWindow:[self window]];
}

- (IBAction) remoteHostNameAction:(id)sender
{
	[model setRemoteHostName:[sender stringValue]];
}

- (IBAction) localHostNameAction:(id)sender
{
	[model setLocalHostName:[sender stringValue]];
}

- (IBAction) userNameAction:(id)sender
{
	[model setUserName:[sender stringValue]];
}

- (IBAction) passwordAction:(id)sender
{
	[model setPassword:[sender stringValue]];
}

- (IBAction) portAction:(id)sender
{
	[model setPortNumber:[sender integerValue]];
}

- (IBAction) createAction:(id)sender
{
	[self endEditing];
	NSString* s = [NSString stringWithFormat:@"Really try to create a database named %@?\n",[model databaseName]];
	NSBeginAlertSheet(s,
                      @"Cancel",
                      @"Yes, Create Database",
                      nil,[self window],
                      self,
                      @selector(createActionDidEnd:returnCode:contextInfo:),
                      nil,
                      nil,@"If the database already exists, this operation will do no harm.");
	
}
- (IBAction) deleteAction:(id)sender
{
	[self endEditing];
	NSString* s = [NSString stringWithFormat:@"Really delete a database named %@?\n",[model databaseName]];
	NSBeginAlertSheet(s,
                      @"Cancel",
                      @"Yes, Delete Database",
                      nil,[self window],
                      self,
                      @selector(deleteActionDidEnd:returnCode:contextInfo:),
                      nil,
                      nil,@"If the database doesn't exist, this operation will do no harm.");
	
}

- (IBAction) listAction:(id)sender
{
	[model listDatabases];
}

- (IBAction) listTasks:(id)sender
{
	[model getRemoteInfo:YES];
}

- (IBAction) infoAction:(id)sender
{
	[model databaseInfo:YES];
}

- (IBAction) compactAction:(id)sender
{
	[model compactDatabase];
}

@end

@implementation ORCouchDBController (private)
- (void) createActionDidEnd:(id)sheet returnCode:(int)returnCode contextInfo:(id)userInfo
{
	if(returnCode == NSAlertAlternateReturn){		
		[model createDatabase];
	}
}

- (void) deleteActionDidEnd:(id)sheet returnCode:(int)returnCode contextInfo:(id)userInfo
{
	if(returnCode == NSAlertAlternateReturn){		
		[model deleteDatabase];
	}
}

- (void) stealthActionDidEnd:(id)sheet returnCode:(int)returnCode contextInfo:(id)userInfo
{
	if(returnCode == NSAlertAlternateReturn){
		[model setStealthMode:YES];
	}
    else [model setStealthMode:NO];
}
- (void) historyActionDidEnd:(id)sheet returnCode:(int)returnCode contextInfo:(id)userInfo
{
	if(returnCode == NSAlertAlternateReturn){
		[model setKeepHistory:NO];
	}
    else [model setKeepHistory:YES];
    
}

@end

