//
//  ELLIEModel.h
//  Orca
//
//  Created by Chris Jones on 01/04/2014.
//
//

#import <Foundation/Foundation.h>
#import <ELLIEController.h>

@class ORCouchDB;

@interface ELLIEModel :  OrcaObject{
    NSMutableDictionary* smellieRunSettings;
    NSTask* exampleTask;
    NSMutableDictionary* smellieRunHeaderDocList;
}

@property (nonatomic,retain) NSMutableDictionary* smellieRunSettings;
@property (nonatomic,retain) NSTask* exampleTask;
@property (nonatomic,retain) NSMutableDictionary* smellieRunHeaderDocList;

-(void) setUpImage;
-(void) makeMainController;
-(void) wakeUp;
-(void) sleep;
-(void) dealloc;
-(void) registerNotificationObservers;
- (ORCouchDB*) generalDBRef:(NSString*)aCouchDb;

//This is called by ORCouchDB.h class as a returning delegate
- (void) couchDBResult:(id)aResult tag:(NSString*)aTag op:(id)anOp;

//-(NSMutableDictionary*) pullEllieCustomRunFromDB:(NSString*)aCouchDBName;
-(void) pullEllieCustomRunFromDB:(NSString*)aCouchDBName;

-(void) parseSmellieRunHeaderDoc:(id)aResult;

/*This function calls a python script: 
    pythonScriptFilePath - this is the python script file path
    withCmdLineArgs - these are the arguments for the python script*/
-(NSString*)callPythonScript:(NSString*)pythonScriptFilePath withCmdLineArgs:(NSArray*)commandLineArgs;

//starts a SMELLIE run with given parameters and submits the smellie run file to the database
-(void)startSmellieRun:(NSMutableDictionary*)smellieSettings;
-(void) smellieDBpush:(NSMutableDictionary*)dbDic;
-(void) exampleFunctionForPython;

@end

extern NSString* ELLIEAllLasersChanged;
extern NSString* ELLIEAllFibresChanged;
extern NSString* smellieRunDocsPresent;