//--------------------------------------------------------
// ORMITPulserModel
// Created by Mark  A. Howe on Fri Jul 22 2005
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

#pragma mark ***Imported Files

#import "ORMITPulserModel.h"
#import "ORSerialPort.h"
#import "ORSerialPortList.h"
#import "ORSerialPort.h"
#import "ORSerialPortAdditions.h"

#pragma mark ***External Strings
NSString* ORMITPulserModelFrequencyChanged	= @"ORMITPulserModelFrequencyChanged";
NSString* ORMITPulserModelDutyCycleChanged	= @"ORMITPulserModelDutyCycleChanged";
NSString* ORMITPulserModelResistanceChanged	= @"ORMITPulserModelResistanceChanged";
NSString* ORMITPulserModelClockSpeedChanged = @"ORMITPulserModelClockSpeedChanged";
NSString* ORMITPulserModelPulserVersionChanged = @"ORMITPulserModelPulserVersionChanged";
NSString* ORMITPulserModelSerialPortChanged = @"ORMITPulserModelSerialPortChanged";
NSString* ORMITPulserModelPortNameChanged   = @"ORMITPulserModelPortNameChanged";
NSString* ORMITPulserModelPortStateChanged  = @"ORMITPulserModelPortStateChanged";
NSString* ORMITPulserLock = @"ORMITPulserLock";

@interface ORMITPulserModel (private)
- (void) sendCommand:(NSString*)aCommand;
@end

@implementation ORMITPulserModel

- (void) dealloc
{
    [portName release];
    if([serialPort isOpen]){
        [serialPort close];
    }
    [serialPort release];
	[super dealloc];
}

- (void) setUpImage
{
	[self setImage:[NSImage imageNamed:@"MITPulser"]];
}

- (void) makeMainController
{
	[self linkToController:@"ORMITPulserController"];
}

- (NSString*) helpURL
{
	return @"RS232/MITPulser.html";
}

#pragma mark ***Accessors

- (float) frequency
{
    return frequency;
}

- (void) setFrequency:(float)aFrequency
{
    [[[self undoManager] prepareWithInvocationTarget:self] setFrequency:frequency];
    frequency = aFrequency;
	float nBitsFrequency = 0;
	if ([self pulserVersion] == 0) nBitsFrequency = 3;
	if ([self pulserVersion] == 1) nBitsFrequency = 4;
	float maxFrequency = [self actualClockSpeed] / 2;
	float minFrequency = ([self actualClockSpeed] / pow(16,nBitsFrequency) / 2);
	if (frequency > maxFrequency) frequency = maxFrequency;     //  You can only be as fast as your clock
	if (frequency < minFrequency) frequency = minFrequency;     //  You only have n bits to program (go to lower clock speed)

	int frequencyTicks = 0;
	if (frequency > 0) frequencyTicks = ((1./frequency)*([self actualClockSpeed])/2.);
	frequency = ((1./frequencyTicks)*([self actualClockSpeed])/2.);  // Take care of rounding issues

    [[NSNotificationCenter defaultCenter] postNotificationName:ORMITPulserModelFrequencyChanged object:self];
}

- (int) dutyCycle
{
    return dutyCycle;
}

- (void) setDutyCycle:(int)aDutyCycle
{
    [[[self undoManager] prepareWithInvocationTarget:self] setDutyCycle:dutyCycle];
    dutyCycle = aDutyCycle;
	if (dutyCycle <= 0)  dutyCycle = 0;
	if (dutyCycle >= 50)  dutyCycle = 50;	 
    [[NSNotificationCenter defaultCenter] postNotificationName:ORMITPulserModelDutyCycleChanged object:self];
}

- (int) resistance
{
    return resistance;
}

- (void) setResistance:(int)aResistance
{
    [[[self undoManager] prepareWithInvocationTarget:self] setResistance:resistance];
    
    resistance = aResistance;
	if (resistance < 50) resistance = 50.;
	if (resistance > 1050.) resistance = 1050.;

    [[NSNotificationCenter defaultCenter] postNotificationName:ORMITPulserModelResistanceChanged object:self];
}

- (int) clockSpeed
{
    return clockSpeed;
}

- (int) pulserVersion
{
    return pulserVersion;
}


- (void) setClockSpeed:(int)aClockSpeed
{
    [[[self undoManager] prepareWithInvocationTarget:self] setClockSpeed:clockSpeed];
	clockSpeed = aClockSpeed;
    [[NSNotificationCenter defaultCenter] postNotificationName:ORMITPulserModelClockSpeedChanged object:self];
}

- (void) setPulserVersion:(int)aPulserVersion
{
    [[[self undoManager] prepareWithInvocationTarget:self] setPulserVersion:pulserVersion];
	pulserVersion = aPulserVersion;
    [[NSNotificationCenter defaultCenter] postNotificationName:ORMITPulserModelPulserVersionChanged object:self];
}


- (float) actualClockSpeed
{
	switch ([self pulserVersion]){
		case 0:
		default: 
			switch ([self clockSpeed]){
				case 0: 
				default:  return 1e+06;
				case 1:   return 1e+03;
			}
		break;
			
		case 1:	
			switch ([self clockSpeed]){
				case 0: 
				default:  return 1e+05;
				case 1:   return 1e+02;
			}
		break;
	}
}

- (BOOL) portWasOpen
{
    return portWasOpen;
}

- (void) setPortWasOpen:(BOOL)aPortWasOpen
{
    portWasOpen = aPortWasOpen;
}

- (NSString*) portName
{
    return portName;
}

- (void) setPortName:(NSString*)aPortName
{
    [[[self undoManager] prepareWithInvocationTarget:self] setPortName:portName];
    
    if(![aPortName isEqualToString:portName]){
        [portName autorelease];
        portName = [aPortName copy];    

        BOOL valid = NO;
        NSEnumerator *enumerator = [ORSerialPortList portEnumerator];
        ORSerialPort *aPort;
        while (aPort = [enumerator nextObject]) {
            if([portName isEqualToString:[aPort name]]){
                [self setSerialPort:aPort];
                if(portWasOpen){
                    [self openPort:YES];
                 }
                valid = YES;
                break;
            }
        } 
        if(!valid){
            [self setSerialPort:nil];
        }       
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:ORMITPulserModelPortNameChanged object:self];
}

- (ORSerialPort*) serialPort
{
    return serialPort;
}

- (void) setSerialPort:(ORSerialPort*)aSerialPort
{
    [aSerialPort retain];
    [serialPort release];
    serialPort = aSerialPort;

    [[NSNotificationCenter defaultCenter] postNotificationName:ORMITPulserModelSerialPortChanged object:self];
}

- (void) openPort:(BOOL)state
{
    if(state) {
        [serialPort open];
		[serialPort setSpeed:9600];
		[serialPort setParityNone];
		[serialPort setStopBits2:1];
		[serialPort setDataBits:8];
 		[serialPort commitChanges];
    }
    else      [serialPort close];
    portWasOpen = [serialPort isOpen];
    [[NSNotificationCenter defaultCenter] postNotificationName:ORMITPulserModelPortStateChanged object:self];
    
}

//put our parameters into any run header
- (NSMutableDictionary*) addParametersToDictionary:(NSMutableDictionary*)dictionary
{
    NSMutableDictionary* objDictionary = [NSMutableDictionary dictionary];
    [objDictionary setObject:NSStringFromClass([self class]) forKey:@"Class Name"];
		
    [objDictionary setObject:[NSNumber numberWithInt:pulserVersion]	forKey:@"pulserVersion"];
    [objDictionary setObject:[NSNumber numberWithInt:clockSpeed]	forKey:@"clockSpeed"];
    [objDictionary setObject:[NSNumber numberWithInt:resistance]	forKey:@"resistance"];
    [objDictionary setObject:[NSNumber numberWithInt:dutyCycle]		forKey:@"dutyCycle"];
    [objDictionary setObject:[NSNumber numberWithFloat:frequency]	forKey:@"frequency"];
	
	[dictionary setObject:objDictionary forKey:[self identifier]];
	return objDictionary;
}

#pragma mark *** Commands
- (void) loadHardware
{
	//option 1 -- send one by one
	[self sendCommand: [self clockCommand]];
	usleep(100000); //sleep 100 mSec
	[self sendCommand: [self resistanceCommand]];
	[self sendCommand: [self frequencyCommand]];
	[self sendCommand: [self dutyCycleCommand]];
	
	//option 2 -- append all once
	//NSString* bigCommand = [[NSString alloc] initWithFormat:@"%@%@%@",[self resistanceCommand],[self dutyCycleCommand],[self frequencyCommand]];
	//[self sendCommand: bigCommand];
	//[bigCommand release];
}

- (void) setPower:(BOOL)state
{
	//For the future...
	if(state == NO)  {
		NSString* powerCommand = @"";
		if([self pulserVersion] == 0) powerCommand = @"P000\rD000\r";
		else						  powerCommand = @"P0000\rD0000\r";
		[self sendCommand: powerCommand];
	}
}

- (NSString*) clockCommand
{		
    if([self pulserVersion] == 0) return [@"H" stringByAppendingFormat:@"%01x\r",clockSpeed];
	else return [@"H" stringByAppendingFormat:@"%02x\r",clockSpeed];	
}

- (NSString*) resistanceCommand
{
	float resistanceBase = 50.;
	int resistanceTicks = 0;
	if (resistance > resistanceBase) resistanceTicks = (resistance - resistanceBase)/3.9215;    
	return [@"I" stringByAppendingFormat:@"%02x\r",resistanceTicks];;
}

- (NSString*) dutyCycleCommand
{
	int dutyTicks = 0;
	int frequencyTicks = 0;
	if (frequency > 0) frequencyTicks = ((1./frequency)*([self actualClockSpeed])/2.);
	if ((dutyCycle > 0) && (dutyCycle < 50)) dutyTicks = frequencyTicks * (1. - 2.* dutyCycle / 100.);
	if (pulserVersion == 0) return [@"D" stringByAppendingFormat:@"%03x\r",dutyTicks];
	else return [@"D" stringByAppendingFormat:@"%04x\r",dutyTicks];
}

- (NSString*) frequencyCommand
{
	int frequencyTicks = 0;
	if (frequency > 0) frequencyTicks = ((1./frequency)*([self actualClockSpeed])/2.);
	if (pulserVersion == 0) return  [@"P" stringByAppendingFormat:@"%03x\r",frequencyTicks];
	else return  [@"P" stringByAppendingFormat:@"%04x\r",frequencyTicks];
}

#pragma mark ***Archival
- (id)initWithCoder:(NSCoder*)decoder
{
    self = [super initWithCoder:decoder];
    
    [[self undoManager] disableUndoRegistration];
    [self setPulserVersion:[decoder decodeIntForKey:@"pulserVersion"]];	
	[self setClockSpeed:[decoder decodeIntForKey:@"clockSpeed"]];
    [self setFrequency:	[decoder decodeFloatForKey:@"frequency"]];
    [self setDutyCycle:	[decoder decodeIntForKey:@"dutyCycle"]];
    [self setResistance:	[decoder decodeIntForKey:@"resistance"]];
    [[self undoManager] enableUndoRegistration];    
	
    return self;
}

- (void)encodeWithCoder:(NSCoder*)encoder
{
    [super encodeWithCoder:encoder];
    [encoder encodeInt:pulserVersion	forKey:@"pulserVersion"];
    [encoder encodeInt:clockSpeed	    forKey:@"clockSpeed"];
    [encoder encodeFloat:frequency	    forKey:@"frequency"];
    [encoder encodeInt:dutyCycle	    forKey:@"dutyCycle"];
    [encoder encodeInt:resistance	    forKey:@"resistance"];
}
@end

@implementation ORMITPulserModel (private)
- (void) sendCommand:(NSString*)aCommand
{
	if(aCommand == nil)return;
	
	int i;
	for(i=0;i<[aCommand length];i++){
		NSString* partToSend = [NSString stringWithFormat:@"%@",[aCommand substringWithRange:NSMakeRange(i,1)]]; 
		[serialPort writeString:partToSend];
		usleep(50000); //sleep 50 mSec
	}
}
@end