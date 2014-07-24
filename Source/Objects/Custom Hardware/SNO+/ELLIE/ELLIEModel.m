//
//  ELLIEModel.m
//  Orca
//
//  Created by Chris Jones on 01/04/2014.
//
//

/*TODO:
        - Check the standard run name doesn't already exsists in the DB
        - read from and write to the local couch DB for both smellie and tellie
        - fix the intensity steps in SMELLIE such that negative values cannot be considered
        - add the TELLIE GUI Information
        - add the sockets for TELLIE to communicate with itself
        - add the AMELLIE GUI
        - make sure old files cannot be overridden 
        - add the configuration files GUI for all the ELLIE systems (LOW PRIORITY)
        - add the Emergency stop button 
        - make the SMELLIE Control functions private (eventually)
*/

#import "ELLIEModel.h"
#import "ORTaskSequence.h"
#import "ORCouchDB.h"
#import "SNOPModel.h"
#import "ORRunModel.h"
#import "SNOPController.h"
#import "ORMTCModel.h"
#import "ORRunController.h"

//tags to define that an ELLIE run file has been updated
#define kSmellieRunDocumentAdded   @"kSmellieRunDocumentAdded"
#define kSmellieRunDocumentUpdated   @"kSmellieRunDocumentUpdated"
#define kTellieRunDocumentAdded   @"kTellieRunDocumentAdded"
#define kTellieRunDocumentUpdated   @"kTellieRunDocumentUpdated"
#define kAmellieRunDocumentAdded   @"kAmellieRunDocumentAdded"
#define kAmellieRunDocumentUpdated   @"kAmellieRunDocumentUpdated"
#define kSmellieRunHeaderRetrieved   @"kSmellieRunHeaderRetrieved"
#define kSmellieConfigHeaderRetrieved @"kSmellieConfigHeaderRetrieved"

//sub run information tags
#define kSmellieSubRunDocumentAdded @"kSmellieSubRunDocumentAdded"

NSString* ELLIEAllLasersChanged = @"ELLIEAllLasersChanged";
NSString* ELLIEAllFibresChanged = @"ELLIEAllFibresChanged";
NSString* smellieRunDocsPresent = @"smellieRunDocsPresent";
NSString* ORELLIERunFinished = @"ORELLIERunFinished";


@interface ELLIEModel (private)
-(void) _pushEllieCustomRunToDB:(NSString*)aCouchDBName runFiletoPush:(NSMutableDictionary*)customRunFile;
-(void) _pushEllieConfigDocToDB:(NSString*)aCouchDBName runFiletoPush:(NSMutableDictionary*)customRunFile;
-(NSString*) stringDateFromDate:(NSDate*)aDate;
-(void) _pushSmellieRunDocument;
//-(void) _pushSmellieConfigDocument;
@end

@implementation ELLIEModel

@synthesize smellieRunSettings;
@synthesize exampleTask;
@synthesize smellieRunHeaderDocList;
@synthesize smellieSubRunInfo,
smellieDBReadInProgress = _smellieDBReadInProgress;

- (void) setUpImage
{
    [self setSmellieDBReadInProgress:NO];
    [self setImage:[NSImage imageNamed:@"ellie"]];
}

- (void) makeMainController
{
    [self linkToController:@"ELLIEController"];
    
}

- (void) wakeUp
{
    if([self aWake])return;
    [super wakeUp];
}

- (void) sleep
{
	[super sleep];
}

-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    
	[super dealloc];
}

- (void) registerNotificationObservers
{
    //[super registerNotificationObservers];
    
    NSNotificationCenter* notifyCenter = [NSNotificationCenter defaultCenter];
    
    //we don't want this notification
	[notifyCenter removeObserver:self name:NSWindowDidResignKeyNotification object:nil];
    
    
}

- (void) fetchSmellieConfigurationInformation
{ 
    //this is dependant upon the current couchDB view that exsists within the database
    NSString *requestString = [NSString stringWithFormat:@"_design/smellieMainQuery/_view/pullEllieConfigHeaders"];
    
    [[self generalDBRef:@"smellie"] getDocumentId:requestString tag:kSmellieConfigHeaderRetrieved];
    
    [self setSmellieDBReadInProgress:YES];
    [self performSelector:@selector(smellieDocumentsRecieved) withObject:nil afterDelay:10.0];
    
}

//complete this after the smellie documents have been recieved
-(void)smellieDocumentsRecieved
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(smellieDocumentsRecieved) object:nil];
    if (![self smellieDBReadInProgress]) { //killed already
        return;
    }
    
    [self setSmellieDBReadInProgress:NO];
    
}

- (ORCouchDB*) generalDBRef:(NSString*)aCouchDb
{
    //Collect a series of objects from the SNOPModel
    NSArray*  objs = [[[NSApp delegate] document] collectObjectsOfClass:NSClassFromString(@"SNOPModel")];
    
    //Initialise the SNOPModel
    SNOPModel* aSnotModel = [objs objectAtIndex:0];
    
	return [ORCouchDB couchHost:[aSnotModel orcaDBIPAddress]
                           port:[aSnotModel orcaDBPort]
                       username:[aSnotModel orcaDBUserName]
                            pwd:[aSnotModel orcaDBPassword]
                       database:aCouchDb
                       delegate:aSnotModel];
}

//This calls a python script but can only take two command line arguments 
-(NSString*)callPythonScript:(NSString*)pythonScriptFilePath withCmdLineArgs:(NSArray*)commandLineArgs
{
    if([commandLineArgs count] != 3){
        NSLog(@"Three command line arguments are required!");
        return nil;
    }
    
    NSTask *task;
    task = [[NSTask alloc] init];
    [task setLaunchPath: @"/usr/bin/python"]; // Tell the task to execute the ssh command
    [task setArguments: [NSArray arrayWithObjects: pythonScriptFilePath, [commandLineArgs objectAtIndex:0],[commandLineArgs objectAtIndex:1],[commandLineArgs objectAtIndex:2],nil]];
    
    NSPipe *pipe;
    pipe = [NSPipe pipe];
    [task setStandardOutput: pipe];
    NSFileHandle *file;
    file = [pipe fileHandleForReading]; // This file handle is a reference to the output of the ssh command
    
    @try{
        [task launch];
    }
    @catch (NSException *e) {
        NSLog(@"SMELLIE Connection Error: %@",e);
    }
    @finally {
        //do something here
    }
    
    NSData *data;
    data = [file readDataToEndOfFile];
    
    NSString *responseFromCmdLine;
    responseFromCmdLine = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding]; // This string now contains the entire output of the ssh command.
    
    [task release];
    return [responseFromCmdLine autorelease];
}


//used to create the timestamp in the couchDB files 
- (NSString*) stringDateFromDate:(NSDate*)aDate
{
    NSDateFormatter* snotDateFormatter = [[NSDateFormatter alloc] init];
    [snotDateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'SS'Z'"];
    snotDateFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    NSDate* strDate;
    if (!aDate)
        strDate = [NSDate date];
    else
        strDate = aDate;
    NSString* result = [snotDateFormatter stringFromDate:strDate];
    [snotDateFormatter release];
    strDate = nil;
    return [[result retain] autorelease];
}

//Push the information from the GUI into a couchDB database
-(void) _pushEllieCustomRunToDB:(NSString*)aCouchDBName runFiletoPush:(NSMutableDictionary*)customRunFile
{
    NSAutoreleasePool* runDocPool = [[NSAutoreleasePool alloc] init];
    NSMutableDictionary* runDocDict = [NSMutableDictionary dictionaryWithCapacity:100];
    
    //Collect a series of objects from the SNOPModel
    NSArray*  objs = [[[NSApp delegate] document] collectObjectsOfClass:NSClassFromString(@"SNOPModel")];
    
    //Initialise the SNOPModel
    SNOPModel* aSnotModel = [objs objectAtIndex:0];
    
    NSString* docType = [NSMutableString stringWithFormat:@"%@%@",aCouchDBName,@"_run"];
    
    NSLog(@"document_type: %@",docType);
    
    [runDocDict setObject:docType forKey:@"doc_type"];
    [runDocDict setObject:[self stringDateFromDate:nil] forKey:@"time_stamp"];
    [runDocDict setObject:customRunFile forKey:@"run_info"];
            
    //self.runDocument = runDocDict;
    [[aSnotModel orcaDbRefWithEntryDB:aSnotModel withDB:aCouchDBName] addDocument:runDocDict tag:kSmellieRunDocumentAdded];
    
    [runDocPool release];
}

-(void) _pushSmellieRunDocument
{
    NSAutoreleasePool* runDocPool = [[NSAutoreleasePool alloc] init];
    NSMutableDictionary* runDocDict = [NSMutableDictionary dictionaryWithCapacity:100];
    
    //Collect a series of objects from the SNOPModel
    NSArray*  objs = [[[NSApp delegate] document] collectObjectsOfClass:NSClassFromString(@"SNOPModel")];
    SNOPModel* aSnotModel = [objs objectAtIndex:0];
    
    NSArray*  objs3 = [[[NSApp delegate] document] collectObjectsOfClass:NSClassFromString(@"ORRunModel")];
    runControl = [objs3 objectAtIndex:0];
    
    NSString* docType = [NSMutableString stringWithFormat:@"smellie_run_information"];

    [runDocDict setObject:docType forKey:@"doc_type"];
    [runDocDict setObject:[self stringDateFromDate:nil] forKey:@"time_stamp"];
    NSNumber *smellieConfigurationVersion = [self fetchRecentVersion];
    [runDocDict setObject:smellieConfigurationVersion forKey:@"configuration_version"];
    [runDocDict setObject:[NSNumber numberWithInt:[runControl runNumber]] forKey:@"run_number"];
    [runDocDict setObject:smellieSubRunInfo forKey:@"sub_run_info"];
    
    //self.runDocument = runDocDict;
    [[aSnotModel orcaDbRefWithEntryDB:aSnotModel withDB:@"smellie"] addDocument:runDocDict tag:kSmellieSubRunDocumentAdded];
    
    [runDocPool release];
}

-(void) _pushEllieConfigDocToDB:(NSString*)aCouchDBName runFiletoPush:(NSMutableDictionary*)customRunFile
{
    NSAutoreleasePool* configDocPool = [[NSAutoreleasePool alloc] init];
    NSMutableDictionary* configDocDic = [NSMutableDictionary dictionaryWithCapacity:100];
    
    //Collect a series of objects from the SNOPModel
    NSArray*  objs = [[[NSApp delegate] document] collectObjectsOfClass:NSClassFromString(@"SNOPModel")];
    
    //Initialise the SNOPModel
    SNOPModel* aSnotModel = [objs objectAtIndex:0];
    
    NSString* docType = [NSMutableString stringWithFormat:@"%@%@",aCouchDBName,@"_configuration"];
    
    NSLog(@"document_type: %@",docType);
    
    [configDocDic setObject:docType forKey:@"doc_type"];
    [configDocDic setObject:[self stringDateFromDate:nil] forKey:@"time_stamp"];
    [configDocDic setObject:customRunFile forKey:@"configuration_info"];

    //self.runDocument = runDocDict;
    [[aSnotModel orcaDbRefWithEntryDB:aSnotModel withDB:aCouchDBName] addDocument:configDocDic tag:kSmellieRunDocumentAdded];
    
    [configDocPool release];
}

-(void) smellieDBpush:(NSMutableDictionary*)dbDic
{
    [self _pushEllieCustomRunToDB:@"smellie" runFiletoPush:dbDic];
}

-(void) smellieConfigurationDBpush:(NSMutableDictionary*)dbDic
{
    [self _pushEllieConfigDocToDB:@"smellie" runFiletoPush:dbDic];
}

- (void) couchDBResult:(id)aResult tag:(NSString*)aTag op:(id)anOp
{
	@synchronized(self){
		if([aResult isKindOfClass:[NSDictionary class]]){
			NSString* message = [aResult objectForKey:@"Message"];
			if(message){
				[aResult prettyPrint:@"CouchDB Message:"];
			}
            
            //Look through all of the possible tags for ellie couchDB results 
            
            //This is called when smellie run header is queried from CouchDB
            if ([aTag isEqualToString:kSmellieRunHeaderRetrieved])
            {
                NSLog(@"here\n");
                NSLog(@"Object: %@\n",aResult);
                NSLog(@"result: %@\n",[aResult objectForKey:@"run_name"]);
                //[self parseSmellieRunHeaderDoc:aResult];
            }
            
            else if ([aTag isEqualToString:kSmellieConfigHeaderRetrieved])
            {
                NSLog(@"Smellie configuration file Object: %@\n",aResult);
                //[self parseSmellieConfigHeaderDoc:aResult];
            }
            
            //If no tag is found for the query result
			else {
                NSLog(@"No Tag assigned to that query/couchDB View \n");
                NSLog(@"Object: %@\n",aResult);
            }
		}
        
		else if([aResult isKindOfClass:[NSArray class]]){
            [aResult prettyPrint:@"CouchDB"];
		}
        
		else {
			//no docs found 
		}
	}
}

-(void)startSmellieRunInBackground:(NSDictionary*)smellieSettings
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [self performSelectorOnMainThread:@selector(startSmellieRun:) withObject:smellieSettings waitUntilDone:NO];
    [pool release];
    
}

//SMELLIE Control Functions
-(void)setSmellieSafeStates
{
    NSArray * setSafeStates = @[@"30",@"0",@"0"]; //30 is the flag for setting smellie to its safe states
    [self callPythonScript:@"/Users/snotdaq/Desktop/orca-python/smellie/smellieConnection.py" withCmdLineArgs:setSafeStates];
}

-(void)setLaserSwitch:(NSString*)laserSwitchChannel
{
    NSArray * setLaserSwitchFlagAndArgument = @[@"2050",laserSwitchChannel,@"0"]; //30 is the flag for setting smellie to its safe states
    [self callPythonScript:@"/Users/snotdaq/Desktop/orca-python/smellie/smellieConnection.py" withCmdLineArgs:setLaserSwitchFlagAndArgument];
}

-(void)setFibreSwitch:(NSString*)fibreSwitchInputChannel withOutputChannel:(NSString*)fibreSwitchOutputChannel
{
    NSString * argumentStringFS = [NSString stringWithFormat:@"%@s%@",fibreSwitchInputChannel,fibreSwitchOutputChannel];
    //NSLog(@"fibre switch argument %@",argumentStringFS);
    NSArray * setFibreSwitchFlagAndArgument = @[@"40",argumentStringFS,@"0"];
    [self callPythonScript:@"/Users/snotdaq/Desktop/orca-python/smellie/smellieConnection.py" withCmdLineArgs:setFibreSwitchFlagAndArgument];
}

-(void)setLaserIntensity:(NSString*)laserIntensity
{
    NSArray * setLaserIntensityFlagAndArgument = @[@"50",laserIntensity,@"0"]; //30 is the flag for setting smellie to its safe states
    [self callPythonScript:@"/Users/snotdaq/Desktop/orca-python/smellie/smellieConnection.py" withCmdLineArgs:setLaserIntensityFlagAndArgument];
}

-(void)setLaserSoftLockOn
{
    NSArray * softLockOnFlag = @[@"60",@"0",@"0"]; //30 is the flag for setting smellie to its safe states
    [self callPythonScript:@"/Users/snotdaq/Desktop/orca-python/smellie/smellieConnection.py" withCmdLineArgs:softLockOnFlag];
}

-(void)setLaserSoftLockOff
{
    NSArray * softLockOffFlag = @[@"70",@"0",@"0"]; //30 is the flag for setting smellie to its safe states
    [self callPythonScript:@"/Users/snotdaq/Desktop/orca-python/smellie/smellieConnection.py" withCmdLineArgs:softLockOffFlag];
}

-(void)setLaserFrequency20Mhz
{
    NSArray * frequencyTestingModeFlag = @[@"90",@"0",@"0"]; 
    [self callPythonScript:@"/Users/snotdaq/Desktop/orca-python/smellie/smellieConnection.py" withCmdLineArgs:frequencyTestingModeFlag];
}

-(void)setSmellieMasterMode:(NSString*)triggerFrequency withNumOfPulses:(NSString*)numOfPulses
{
    NSString * argumentString = [NSString stringWithFormat:@"%@s%@",triggerFrequency,numOfPulses];
    NSArray * smellieMasterModeFlag = @[@"80",argumentString,@"0"]; //30 is the flag for setting smellie to its safe states
    [self callPythonScript:@"/Users/snotdaq/Desktop/orca-python/smellie/smellieConnection.py" withCmdLineArgs:smellieMasterModeFlag];
}

-(void)sendCustomSmellieCmd:(NSString*)customCmd withArgument1:(NSString*)customArgument1 withArgument2:(NSString*)customArgument2
{
    //Make sure all the arguments default to a safe value if not specified
    if([customCmd isEqualToString:nil]){
        customCmd = @"0";
    }
    
    if([customArgument1 isEqualToString:nil] || [customArgument1 isEqualToString:@""]){
        customArgument1 = @"0";
    }
    
    if([customArgument2 isEqualToString:nil] || [customArgument2 isEqualToString:@""]){
        customArgument2 = @"0";
    }
        
    NSArray * smellieCustomCmd = @[customCmd,customArgument1,customArgument2];
    [self callPythonScript:@"/Users/snotdaq/Desktop/orca-python/smellie/smellieConnection.py" withCmdLineArgs:smellieCustomCmd];
    
}

-(void)testFunction
{
    NSArray*  objs3 = [[[NSApp delegate] document] collectObjectsOfClass:NSClassFromString(@"ORRunModel")];
    runControl = [objs3 objectAtIndex:0];
    
    [runControl performSelector:@selector(haltRun)withObject:nil afterDelay:.1];
    
    
}

-(NSNumber*) fetchRecentVersion
{
    //Collect a series of objects from the SNOPModel
    NSArray*  objs = [[[NSApp delegate] document] collectObjectsOfClass:NSClassFromString(@"SNOPModel")];
    //Initialise the SNOPModel
    SNOPModel* aSnotModel = [objs objectAtIndex:0];
    
    NSString *urlString = [NSString stringWithFormat:@"http://%@:%u/smellie/_design/smellieMainQuery/_view/fetchMostRecentConfigVersion?descending=True&limit=1",[aSnotModel orcaDBIPAddress],[aSnotModel orcaDBPort]];
    NSURL *url = [NSURL URLWithString:urlString];
    NSNumber *currentVersionNumber;
    NSData *data = [NSData dataWithContentsOfURL:url];
    NSString *ret = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSError *error =  nil;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:[ret dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
    if(!error){
        @try{
            //format the json response
            NSString *stringValueOfCurrentVersion = [NSString stringWithFormat:@"%@",[[[json valueForKey:@"rows"] valueForKey:@"value"]objectAtIndex:0]];
            currentVersionNumber = [NSNumber numberWithInt:[stringValueOfCurrentVersion intValue]];
            //NSLog(@"parsedNumber%@",currentVersionNumber);
            //NSLog(@"parsedString %@",stringValueOfCurrentVersion);
            //NSLog(@"valueforkey2=%@", [[json valueForKey:@"rows"] valueForKey:@"value"]);
        }
        @catch (NSException *e) {
            NSLog(@"Error in fetching the SMELLIE CONFIGURATION FILE: %@ . Please fix this before changing the configuration file",e);
        }
    }
    else{
        NSLog(@"Error querying couchDB, please check the connection is correct %@",error);
    }
    
    return currentVersionNumber;
}

-(NSMutableDictionary*) fetchCurrentConfigurationForVersion:(NSNumber*)currentVersion
{
    NSArray*  objs = [[[NSApp delegate] document] collectObjectsOfClass:NSClassFromString(@"SNOPModel")];
    SNOPModel* aSnotModel = [objs objectAtIndex:0];
    //NSDictionary* currentConfig;
    
    NSString *urlString = [NSString stringWithFormat:@"http://%@:%u/smellie/_design/smellieMainQuery/_view/pullEllieConfigHeaders?key=[%i]&limit=1",[aSnotModel orcaDBIPAddress],[aSnotModel orcaDBPort],[currentVersion intValue]];
    
    NSURL *url = [NSURL URLWithString:urlString];
    NSData *data = [NSData dataWithContentsOfURL:url];
    NSString *ret = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSError *error =  nil;
    NSMutableDictionary *currentConfig = [NSJSONSerialization JSONObjectWithData:[ret dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
    if(!error){
        //NSLog(@"sucessful query");
    }
    else{
        NSLog(@"Error querying couchDB, please check the connection is correct %@",error);
    }
    
    return [[[[currentConfig objectForKey:@"rows"]  objectAtIndex:0] objectForKey:@"value"] objectForKey:@"configuration_info"];
}

-(void)startSmellieRun:(NSDictionary*)smellieSettings
{
    NSLog(@"SMELLIE_RUN:Starting SMELLIE Run\n");
    
    NSNumber *currentConfigurationVersion = [[NSNumber alloc] initWithInt:0];
    currentConfigurationVersion = [self fetchRecentVersion];
    
    //fetch the data associated with the current configuration
    NSMutableDictionary *configForSmellie = [[NSMutableDictionary alloc] initWithCapacity:10];
    configForSmellie = [[self fetchCurrentConfigurationForVersion:currentConfigurationVersion] mutableCopy];
    
    NSMutableDictionary *laserHeadToSepiaMapping = [[NSMutableDictionary alloc] initWithCapacity:10];
    
    for(int laserHeadIndex =0; laserHeadIndex < 6; laserHeadIndex++){
        
        for (id specificConfigValue in configForSmellie){
            if([specificConfigValue isEqualToString:[NSString stringWithFormat:@"laserInput%i",laserHeadIndex]]){
                
                NSString *laserHeadConnected = [NSString stringWithFormat:@"%@",[[configForSmellie objectForKey:specificConfigValue] objectForKey:@"laserHeadConnected"]];
                
                [laserHeadToSepiaMapping setObject:[NSString stringWithFormat:@"%i",laserHeadIndex] forKey:laserHeadConnected];
            }
        }
    } //end of looping through each laserHeadIndex
    
    
    NSMutableDictionary *laserToInputFibreMapping = [[NSMutableDictionary alloc] initWithCapacity:10];
    
    for(int inputChannelIndex =0; inputChannelIndex < 6; inputChannelIndex++){

        for (id specificConfigValue in configForSmellie){
            if([specificConfigValue isEqualToString:[NSString stringWithFormat:@"laserInput%i",inputChannelIndex]]){
                
                //NSString *fibreSwitchInputConnected = [NSString stringWithFormat:@"%@",[[configForSmellie objectForKey:specificConfigValue] objectForKey:@"fibreSwitchInputConnected"]];
                
                //NSString* updatedFibreReference = [fibreSwitchInputConnected stringByReplacingOccurrencesOfString:@"Channel" withString:@""];
                
                NSString* laserHeadReference = [NSString stringWithFormat:@"%@",[[configForSmellie objectForKey:specificConfigValue] objectForKey:@"laserHeadConnected"]];

                [laserToInputFibreMapping setObject:[NSString stringWithFormat:@"%i",inputChannelIndex] forKey:laserHeadReference];
            }
        }

    }
    
    NSMutableDictionary *fibreSwitchOutputToFibre = [[NSMutableDictionary alloc] initWithCapacity:10];
    
    for(int outputChannelIndex =1; outputChannelIndex < 13; outputChannelIndex++){
        
        for (id specificConfigValue in configForSmellie){
            if([specificConfigValue isEqualToString:[NSString stringWithFormat:@"Channel%i",outputChannelIndex]]){
                
                NSString *fibreReference = [NSString stringWithFormat:@"%@",[[configForSmellie objectForKey:specificConfigValue] objectForKey:@"detectorFibreReference"]];
                
                [fibreSwitchOutputToFibre setObject:[NSString stringWithFormat:@"%i",outputChannelIndex] forKey:fibreReference];
            }
        }
    }
    
    BOOL slaveMode,masterMode;
    NSString *operationMode = [NSString stringWithFormat:@"%@",[smellieSettings objectForKey:@"operation_mode"]];
    if([operationMode isEqualToString:@"Slave Mode"]){
        slaveMode = YES;
        masterMode = NO;
    }
    else if([operationMode isEqualToString:@"Master Mode"]){
        slaveMode = NO;
        masterMode = YES;
    }
    else{
        slaveMode = NO;
        masterMode = NO;
    }
    NSLog(@"SMELLIE_RUN:Running in %@\n",operationMode);
    NSLog(@"SMELLIE_RUN:Checking Connection to SMELLIE\n");
    NSLog(@"SMELLIE_RUN:Setting SMELLIE into Safe States before starting a Run\n");
    [self setSmellieSafeStates];
    
    //Extract the min intensity
    NSNumber * minLaserObj = [smellieSettings objectForKey:@"min_laser_intensity"];
    int minLaserIntensity = [minLaserObj intValue];
    
    //Extract the min intensity
    NSNumber * maxLaserObj = [smellieSettings objectForKey:@"max_laser_intensity"];
    int maxLaserIntensity = [maxLaserObj intValue];
    
    NSNumber * numOfIntensitySteps = [smellieSettings objectForKey:@"num_intensity_steps"];

    //Extract the lasers to be fired into an array
    NSMutableDictionary * laserArray = [[NSMutableDictionary alloc] init];
    [laserArray setObject:[smellieSettings objectForKey:@"375nm_laser_on"] forKey:@"375nm" ];
    [laserArray setObject:[smellieSettings objectForKey:@"405nm_laser_on"] forKey:@"405nm" ];
    [laserArray setObject:[smellieSettings objectForKey:@"440nm_laser_on"] forKey:@"440nm" ];
    [laserArray setObject:[smellieSettings objectForKey:@"500nm_laser_on"] forKey:@"500nm" ];
    
    //Extract the fibres to be fired into an array
    NSMutableDictionary *fibreArray = [[NSMutableDictionary alloc] init];
    [fibreArray setObject:[smellieSettings objectForKey:@"FS007"] forKey:@"FS007" ];
    [fibreArray setObject:[smellieSettings objectForKey:@"FS107"] forKey:@"FS107" ];
    [fibreArray setObject:[smellieSettings objectForKey:@"FS207"] forKey:@"FS207" ];
    [fibreArray setObject:[smellieSettings objectForKey:@"FS025"] forKey:@"FS025" ];
    [fibreArray setObject:[smellieSettings objectForKey:@"FS125"] forKey:@"FS125" ];
    [fibreArray setObject:[smellieSettings objectForKey:@"FS225"] forKey:@"FS225" ];
    [fibreArray setObject:[smellieSettings objectForKey:@"FS037"] forKey:@"FS037" ];
    [fibreArray setObject:[smellieSettings objectForKey:@"FS137"] forKey:@"FS137" ];
    [fibreArray setObject:[smellieSettings objectForKey:@"FS237"] forKey:@"FS237" ];
    [fibreArray setObject:[smellieSettings objectForKey:@"FS055"] forKey:@"FS055" ];
    [fibreArray setObject:[smellieSettings objectForKey:@"FS155"] forKey:@"FS155" ];
    [fibreArray setObject:[smellieSettings objectForKey:@"FS255"] forKey:@"FS255" ];
    
    smellieSubRunInfo = [[NSMutableArray alloc] initWithCapacity:100];
    
    //get the MTC Object (but only use in Slave Mode)
    NSArray*  objsMTC = [[[NSApp delegate] document] collectObjectsOfClass:NSClassFromString(@"ORMTCModel")];
    ORMTCModel* theMTCModel = [objsMTC objectAtIndex:0];
    [theMTCModel stopMTCPedestalsFixedRate]; //stop any pedestals that are currently running
    
    //get the run controller
    NSArray*  objs3 = [[[NSApp delegate] document] collectObjectsOfClass:NSClassFromString(@"ORRunModel")];
    runControl = [objs3 objectAtIndex:0];

    //start the run controller
    [runControl performSelectorOnMainThread:@selector(startRun) withObject:nil waitUntilDone:YES];

    //fire some pedestals but only in slave mode. The pedestals are used to trigger the SMELLIE lasers
    if(slaveMode){
        NSLog(@"SMELLIE_RUN:Intensity:Firing Pedestals\n");
        [theMTCModel fireMTCPedestalsFixedRate];
    }
    
    BOOL endOfRun = NO;
    int laserLoopInt = 0;
    for(id laserKey in laserArray){
        
        if(endOfRun == YES){
            break; //if the end of the run is reached then break the run loop
        }
        
        //Only loop through fibres that are included in the run
        if([[laserArray objectForKey:laserKey] intValue] != 1){
            continue;
        }
        
        //set the laser switch which corresponds to the laserHead mapping to Sepia
        NSLog(@"SMELLIE_RUN:Setting the Laser Switch to Channel:%@ which corresponds to the %@ Laser\n",[NSString stringWithFormat:@"%@",[laserHeadToSepiaMapping objectForKey:laserKey]],laserKey);
        [self setLaserSwitch:[NSString stringWithFormat:@"%@",[laserHeadToSepiaMapping objectForKey:laserKey]]];
        
        //Loop through each Fibre
        for(id fibreKey in fibreArray){
        
            if(endOfRun == YES){
                break;
            }
            
            //Only loop through fibres that are included in the run 
            if([[fibreArray objectForKey:fibreKey] intValue] != 1){
                continue;
            }
            
            //NSString *inputFibneSwitchChannel = [NSString stringWithFormat:@"%i",laserLoopInt+1];
            NSString *inputFibneSwitchChannel = [NSString stringWithFormat:@"%@",[laserToInputFibreMapping objectForKey:laserKey]];
            
            NSLog(@"SMELLIE_RUN:Setting the Fibre Switch to Input Channel:%@ from the %@ Laser and Output Channel %@\n",inputFibneSwitchChannel,laserKey,[NSString stringWithFormat:@"%@",[fibreSwitchOutputToFibre objectForKey:fibreKey]]);
            [self setFibreSwitch:inputFibneSwitchChannel withOutputChannel:[NSString stringWithFormat:@"%@",[fibreSwitchOutputToFibre objectForKey:fibreKey]]];
            [NSThread sleepForTimeInterval:1.0f];
            
            int increment = (maxLaserIntensity - minLaserIntensity)/[numOfIntensitySteps floatValue];
            //NSNumber *incrementInteger = [NSNUmber numberWithFloat:increment];
            
            //Loop through each intensity of a SMELLIE run 
            for(int intensityLoopInt = minLaserIntensity;intensityLoopInt <= maxLaserIntensity; intensityLoopInt = intensityLoopInt + increment){
            
                if([[NSThread currentThread] isCancelled]){
                    endOfRun = YES;
                    break;
                }
                
                //start a new subrun
                [runControl performSelectorOnMainThread:@selector(prepareForNewSubRun) withObject:nil waitUntilDone:YES];
                [runControl performSelectorOnMainThread:@selector(startNewSubRun) withObject:nil waitUntilDone:YES];
                
                NSString * laserIntensityAsString = [NSString stringWithFormat:@"%i",intensityLoopInt];
                NSLog(@"SMELLIE_RUN:Setting the Laser Intensity to %@ \n",laserIntensityAsString);
                [self setLaserIntensity:laserIntensityAsString];
                [NSThread sleepForTimeInterval:1.0f];
                
                //this used to be 10.0,  Slave mode in Orca requires time (unknown reason)
                
                NSMutableDictionary *valuesToFillPerSubRun = [[NSMutableDictionary alloc] initWithCapacity:100];
                [valuesToFillPerSubRun setObject:laserKey forKey:@"laser"];
                [valuesToFillPerSubRun setObject:fibreKey forKey:@"fibre"];
                [valuesToFillPerSubRun setObject:[NSNumber numberWithInt:intensityLoopInt] forKey:@"intensity"];
                [valuesToFillPerSubRun setObject:[NSNumber numberWithInt:[runControl subRunNumber]] forKey:@"sub_run_number"];
                
                if(slaveMode){
                    [self setLaserSoftLockOff];
                }
                
                //TODO: Delay the thread for a certain amount of time depending on the mode (slave/master)
                [NSThread sleepForTimeInterval:1.0f];
                if(masterMode){
                    NSString* numOfPulses = [NSString stringWithFormat:@"%@",[smellieSettings objectForKey:@"triggers_per_loop"]];
                    NSString* triggerFrequency = [NSString stringWithFormat:@"%@",[smellieSettings objectForKey:@"trigger_frequency"]];
                    NSLog(@"SMELLIE_RUN:%@ Pulses at %@ Hz \n",numOfPulses,triggerFrequency);
                    [self setSmellieMasterMode:triggerFrequency withNumOfPulses:numOfPulses];
                }
                if(slaveMode){
                    //Wait a certain amount of time for slave Mode
                    [NSThread sleepForTimeInterval:5.0f];
                }
                
                [smellieSubRunInfo addObject:valuesToFillPerSubRun];
                [valuesToFillPerSubRun release];
                
                if(!endOfRun){
                    NSLog(@"Laser:%@ ", laserKey);
                    NSLog(@"Fibre:%@ ",fibreKey);
                    NSLog(@"Intensity:%i \n",intensityLoopInt);
                }
                
                //TODO:only have this in slave mode
                if(slaveMode){
                    [self setLaserSoftLockOn];
                }
                
                [NSThread sleepForTimeInterval:1.0f];
                
            }//end of looping through each intensity setting on the smellie laser
            
        }//end of looping through each Fibre
        
        laserLoopInt = laserLoopInt + 1;
    }//end of looping through each laser
    
    //End the run
    
    //[smellieSubRun release];
    [fibreArray release];
    [laserArray release];
    
    //stop the pedestals if required 
    if(masterMode){
        [theMTCModel stopMTCPedestalsFixedRate];
    }
    NSLog(@"SMELLIE_RUN:Returning SMELLIE into Safe States after finishing a Run\n");
    [self setSmellieSafeStates];
    
    //don't know if I need this??? called in stop smellie run ???
    //[runControl performSelectorOnMainThread:@selector(haltRun) withObject:nil waitUntilDone:YES];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:ORELLIERunFinished object:self];
    
}

-(void)stopSmellieRun
{
    //Even though this is stopping in Orca it can still contine on SNODROP!
    //Need a stop run command here
    //TODO: add a try and except statement here
    NSArray*  objsMTC = [[[NSApp delegate] document] collectObjectsOfClass:NSClassFromString(@"ORMTCModel")];
    ORMTCModel* theMTCModel = [objsMTC objectAtIndex:0];
    [theMTCModel stopMTCPedestalsFixedRate];
    
    //removed this to stop splurgingb
    NSArray*  objs3 = [[[NSApp delegate] document] collectObjectsOfClass:NSClassFromString(@"ORRunModel")];
    runControl = [objs3 objectAtIndex:0];
    
    [self _pushSmellieRunDocument];
    
    [runControl performSelectorOnMainThread:@selector(haltRun) withObject:nil waitUntilDone:YES];
    
    //end the run correctly if it is still running
    
    
    //[runControl haltRun];
    //TODO: Send stop smellie run notification 
    NSLog(@"SMELLIE_RUN:Stopping SMELLIE Run\n");
}


@end
