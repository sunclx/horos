//
//  StructuredReport.mm
//  OsiriX
//
//  Created by Lance Pysher on 5/31/06.

/*=========================================================================
  Program:   OsiriX

  Copyright (c) OsiriX Team
  All rights reserved.
  Distributed under GNU - GPL
  
  See http://homepage.mac.com/rossetantoine/osirix/copyright.html for details.

     This software is distributed WITHOUT ANY WARRANTY; without even
     the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
     PURPOSE.
=========================================================================*/

#import "StructuredReport.h"
#import "browserController.h"
#import <AddressBook/AddressBook.h>
#import "DICOMToNSString.h"

#undef verify

#include "osconfig.h"    /* make sure OS specific configuration is included first */
#include "ofstream.h"
#include "dsrdoc.h"
#include "dcuid.h"
#include "dcfilefo.h"
#include "dsrtypes.h"


@implementation StructuredReport

- (id)initWithStudy:(id)study{
	if (self = [super init]){
		_doc = new DSRDocument();
		_study = [study retain];
		_reportHasChanged = NO;
		_isEditable = YES;
		if ([self fileExists]) {
			_reportHasChanged = NO;			
			DcmFileFormat fileformat;
			OFCondition status = fileformat.loadFile([[self srPath] UTF8String]);
			if (status.good())
				status = _doc->read(*fileformat.getDataset());

			// If we are the manfacturer we can edit.
			if (strcmp("OsiriX", _doc->getManufacturer()) == 0){
				
				//completion flag
				if (strcmp (_doc->getCompletionFlagDescription(), "COMPLETE") == 1)
					[self setComplete:YES];
				else
					[self setComplete:NO];
					
				//Verification Flag
				//if (strcmp(_doc->getVerificationFlagDescription(),"VERIFIED") == 1)
				//	[self setComplete:YES];
				//else
					[self setVerified:NO];
					
				//go to physician/observer		
				DSRCodedEntryValue codedEntryValue = DSRCodedEntryValue("121008", "DCM", "Person Observer Name");
				if (_doc->getTree().gotoNamedNode (codedEntryValue, OFTrue, OFTrue) > 0 ){
					OFString observer = _doc->getTree().getCurrentContentItem().getStringValue();
					[self setPhysician:[NSString stringWithCString:observer.c_str() encoding:NSUTF8StringEncoding]];
				}
				//go to observer / Institution
				codedEntryValue = DSRCodedEntryValue("121009", "DCM", "Person Observer's Organization Name");
				if (_doc->getTree().gotoNamedNode (codedEntryValue, OFTrue, OFTrue) > 0 ){
					OFString institution = _doc->getTree().getCurrentContentItem().getStringValue();
					[self setInstitution:[NSString stringWithCString:institution.c_str() encoding:NSUTF8StringEncoding]];
				}
				
				//go to history
				codedEntryValue = DSRCodedEntryValue("121060", "DCM", "History");
				if (_doc->getTree().gotoNamedNode (codedEntryValue, OFTrue, OFTrue) > 0){
					OFString observer = _doc->getTree().getCurrentContentItem().getStringValue();
					[self setHistory:[NSString stringWithCString:observer.c_str() encoding:NSUTF8StringEncoding]];
				}
				
				//Request
				codedEntryValue = DSRCodedEntryValue("121062", "DCM", "Request");
				if (_doc->getTree().gotoNamedNode (codedEntryValue, OFTrue, OFTrue) > 0){
					OFString request = _doc->getTree().getCurrentContentItem().getStringValue();
					[self setRequest:[NSString stringWithCString:request.c_str() encoding:NSUTF8StringEncoding]];
				}
				
				//Procedure
				codedEntryValue = DSRCodedEntryValue("121064", "DCM", "Current Procedure Descriptions");
				if (_doc->getTree().gotoNamedNode (codedEntryValue, OFTrue, OFTrue) > 0){
					codedEntryValue = DSRCodedEntryValue("121065", "DCM", "Procedure Description");
					if (_doc->getTree().gotoNamedNode (codedEntryValue, OFTrue, OFTrue) > 0){
						OFString procedureDescription = _doc->getTree().getCurrentContentItem().getStringValue();
						[self setProcedureDescription:[NSString stringWithCString:procedureDescription.c_str() encoding:NSUTF8StringEncoding]];
					}
				}
				
				//findings
				codedEntryValue = DSRCodedEntryValue("121070", "DCM", "Findings");
				if (_doc->getTree().gotoNamedNode (codedEntryValue, OFTrue, OFTrue) > 0) {
					NSMutableArray *findings = [NSMutableArray array];
					//get all the findings
					codedEntryValue = DSRCodedEntryValue("121071", "DCM", "Finding");
					if (_doc->getTree().gotoNamedNode (codedEntryValue, OFTrue, OFTrue) > 0) {
						OFString finding = _doc->getTree().getCurrentContentItem().getStringValue();
						[findings addObject: [NSDictionary dictionaryWithObject:[NSString stringWithCString:finding.c_str() encoding:NSUTF8StringEncoding]
								forKey:@"finding"]];
						// get the rest. Need a loop here
						while(_doc->getTree().gotoNextNamedNode (codedEntryValue, OFFalse) > 0) {
							finding = _doc->getTree().getCurrentContentItem().getStringValue();
							[findings addObject: [NSDictionary dictionaryWithObject:[NSString stringWithCString:finding.c_str() encoding:NSUTF8StringEncoding]
								forKey:@"finding"]];
						}
					}
					//[self setFindings:findings];
					_findings = [findings retain];
				}
				
				//Impressions
				codedEntryValue = DSRCodedEntryValue("121072", "DCM", "Impressions");
				if (_doc->getTree().gotoNamedNode (codedEntryValue, OFTrue, OFTrue) > 0) {
					NSMutableArray *impressions = [NSMutableArray array];
					//get all the impressions
					codedEntryValue = DSRCodedEntryValue("121073", "DCM", "Impression");
					if (_doc->getTree().gotoNamedNode (codedEntryValue, OFTrue, OFTrue) > 0) {
						OFString impression = _doc->getTree().getCurrentContentItem().getStringValue();
						[impressions addObject: [NSDictionary dictionaryWithObject:[NSString stringWithCString:impression.c_str() encoding:NSUTF8StringEncoding]
								forKey:@"conclusion"]];
						// get the rest. Need a loop here
						while(_doc->getTree().gotoNextNamedNode (codedEntryValue, OFFalse) > 0) {
							impression = _doc->getTree().getCurrentContentItem().getStringValue();
							[impressions addObject: [NSDictionary dictionaryWithObject:[NSString stringWithCString:impression.c_str() encoding:NSUTF8StringEncoding]
								forKey:@"conclusion"]];
							
						}

					}
					//[self setConclusions:impressions];
					_conclusions = [impressions retain];
				}
			}
			else {
				_isEditable = NO;
			}

		}
		else {
			ABPerson *me = [[ABAddressBook sharedAddressBook] me];
			[self setPhysician:[NSString stringWithFormat: @"%@^%@", [me valueForProperty:kABLastNameProperty] ,[me valueForProperty:kABFirstNameProperty]]];
			[self setInstitution:[_study valueForKey:@"institutionName"]];
			[self setRequest:[NSString stringWithFormat:@"%@ %@", [_study valueForKey:@"modality"], [_study valueForKey:@"studyName"]]];
			//Not sure what to suggest for history and technique
			   
			_doc->createNewDocument(DSRTypes::DT_BasicTextSR);
			_doc->setSpecificCharacterSet("ISO_IR 192"); //UTF 8 string encoding
			_doc->createNewSeriesInStudy([[_study valueForKey:@"studyInstanceUID"] UTF8String]);
			//Study Description
			if ([_study valueForKey:@"studyName"])
				_doc->setStudyDescription([[_study valueForKey:@"studyName"] UTF8String]);
			//Series Description
			_doc->setSeriesDescription("OsiriX Structured Report");
			//Patient Name
			if ([_study valueForKey:@"name"] )
				_doc->setPatientsName([[_study valueForKey:@"name"] UTF8String]);
			// Patient DOB
			if ([_study valueForKey:@"dateOfBirth"])
				_doc->setPatientsBirthDate([[[_study valueForKey:@"dateOfBirth"] descriptionWithCalendarFormat:@"%Y%m%d" timeZone:nil locale:nil] UTF8String]);
			//Patient Sex
			if ([_study valueForKey:@"patientSex"])
				_doc->setPatientsSex([[_study valueForKey:@"patientSex"] UTF8String]);
			//Patient ID
			NSString *patientID = [_study valueForKey:@"patientID"];
			if (patientID)
				_doc->setPatientID([patientID UTF8String]);
			//Referring Physician
			if ([_study valueForKey:@"referringPhysician"])
				_doc->setReferringPhysiciansName([[_study valueForKey:@"referringPhysician"] UTF8String]);
			//StudyID	
			if ([_study valueForKey:@"id"]) {
				NSString *studyID = [_study valueForKey:@"id"];
				_doc->setStudyID([studyID UTF8String]);
			}
			//Accession Number
			if ([_study valueForKey:@"accessionNumber"])
				_doc->setAccessionNumber([[_study valueForKey:@"accessionNumber"] UTF8String]);
			//Series Number
			_doc->setSeriesNumber("5001");
			
			_doc->setManufacturer("OsiriX");
		}	
	}
	return self;
}

- (void)dealloc{
	delete _doc;
	[_study release];
	[_findings release];
	[_conclusions release];
	[_physician release];
	[_history release];
	[_xmlDoc release];
	[_sopInstanceUID release];
	[_request release];
	[_procedureDescription release];
	[_institution release];
	[super dealloc];
}

- (NSArray *)findings{	
	if (!_findings)
		_findings = [[NSArray alloc] init];
	return _findings;
}


- (void)setFindings:(NSArray *)findings{
	[_findings release];
	_findings = [findings retain];
	_reportHasChanged = YES;
}

- (NSArray *)conclusions{
	if (!_conclusions)
		_conclusions = [[NSArray alloc] init];
	return _conclusions;
}
- (void)setConclusions:(NSArray *)conclusions{
	[_conclusions release];
	_conclusions = [conclusions retain];
	_reportHasChanged = YES;
}

- (NSString *)physician{
	return _physician;
}
- (void)setPhysician:(NSString *)physician{
	[_physician release];
	_physician = [physician retain];
	_reportHasChanged = YES;
}

- (NSString *)history{
	return _history;
}

- (void)setHistory:(NSString *)history{
	[_history release];
	_history = [history retain];
	_reportHasChanged = YES;
}

- (NSString *)request{
	return _request;
}
- (void)setRequest:(NSString *)request{
	[_request release];
	_request = [request retain];
	_reportHasChanged = YES;
}

- (NSString *)procedureDescription{
	return _procedureDescription;
}

- (void)setProcedureDescription:(NSString *)procedureDescription{
	[_procedureDescription release];
	_procedureDescription = [procedureDescription retain];
	_reportHasChanged = YES;
}
	
- (NSString *)institution{
	return _institution;
}
- (void)setInstitution:(NSString *)institution{
	[_institution release];
	_institution = [institution retain];
	_reportHasChanged = YES;
}

- (BOOL)complete{
	return _complete;
}
- (void)setComplete:(BOOL)complete{
	_complete = complete;
	_reportHasChanged = YES;
}
- (BOOL)verified{
	return _verified;
}
- (void)setVerified:(BOOL)verified{
	_verified = verified;
	_reportHasChanged = YES;
}
	
- (BOOL)fileExists{
	if ([_study valueForKey:@"reportURL"] && [[NSFileManager defaultManager] fileExistsAtPath:[_study valueForKey:@"reportURL"]])
		return YES;
	return NO;
}

- (void)checkCharacterSet
{ // check extended character set
	const char *defaultCharset = "latin-1";
	const char *charset = _doc->getSpecificCharacterSet();
	if ((charset == NULL || strlen(charset) == 0) && _doc->containsExtendedCharacters())
	{
	  // we have an unspecified extended character set
		OFString charset(defaultCharset);
		if (charset == "latin-1") _doc->setSpecificCharacterSetType(DSRTypes::CS_Latin1);
		else if (charset == "latin-2") _doc->setSpecificCharacterSetType(DSRTypes::CS_Latin2);
		else if (charset == "latin-3") _doc->setSpecificCharacterSetType(DSRTypes::CS_Latin3);
		else if (charset == "latin-4") _doc->setSpecificCharacterSetType(DSRTypes::CS_Latin4);
		else if (charset == "latin-5") _doc->setSpecificCharacterSetType(DSRTypes::CS_Latin5);
		else if (charset == "cyrillic") _doc->setSpecificCharacterSetType(DSRTypes::CS_Cyrillic);
		else if (charset == "arabic") _doc->setSpecificCharacterSetType(DSRTypes::CS_Arabic);
		else if (charset == "greek") _doc->setSpecificCharacterSetType(DSRTypes::CS_Greek);
		else if (charset == "hebrew") _doc->setSpecificCharacterSetType(DSRTypes::CS_Hebrew);

	}
}

- (void)createReport{
	if (_isEditable) {
		//NSLog(@"Create report");	
		//NSLog(@"study: %@", [_study description]);
		
		//clear old content
		_doc->getTree().clear();
				
		_doc->getTree().addContentItem(DSRTypes::RT_isRoot, DSRTypes::VT_Container);
		_doc->getTree().getCurrentContentItem().setConceptName(DSRCodedEntryValue("11528-7", "LN", "Radiology Report"));
		if (_physician) {
			_doc->getTree().addContentItem(DSRTypes::RT_hasObsContext, DSRTypes::VT_PName, DSRTypes::AM_belowCurrent);
			_doc->getTree().getCurrentContentItem().setConceptName(DSRCodedEntryValue("121008", "DCM", "Person Observer Name"));
			_doc->getTree().getCurrentContentItem().setStringValue([_physician UTF8String]);
		}
		
		if (_institution) {
			_doc->getTree().addContentItem(DSRTypes::RT_hasObsContext, DSRTypes::VT_Text);
			_doc->getTree().getCurrentContentItem().setConceptName(DSRCodedEntryValue("121009", "DCM", "Person Observer's Organization Name"));
			_doc->getTree().getCurrentContentItem().setStringValue([_institution UTF8String]);
		}
		
		if (_history) {
			_doc->getTree().addContentItem(DSRTypes::RT_contains, DSRTypes::VT_Text);
			_doc->getTree().getCurrentContentItem().setConceptName(DSRCodedEntryValue("121060", "DCM", "History"));
			_doc->getTree().getCurrentContentItem().setStringValue([_history UTF8String]);
		}
		
		if (_request){
			_doc->getTree().addContentItem(DSRTypes::RT_contains, DSRTypes::VT_Text);
			_doc->getTree().getCurrentContentItem().setConceptName(DSRCodedEntryValue("121062", "DCM", "Request"));
			_doc->getTree().getCurrentContentItem().setStringValue([_request UTF8String]);
		}
		
		if (_procedureDescription){
			_doc->getTree().addContentItem(DSRTypes::RT_contains, DSRTypes::VT_Container);
			_doc->getTree().getCurrentContentItem().setConceptName(DSRCodedEntryValue("121064", "DCM", "Current Procedure Descriptions"));
			_doc->getTree().addContentItem(DSRTypes::RT_contains, DSRTypes::VT_Text, DSRTypes::AM_belowCurrent);
			_doc->getTree().getCurrentContentItem().setConceptName(DSRCodedEntryValue("121065", "DCM", "Procedure Description"));
			_doc->getTree().getCurrentContentItem().setStringValue([_procedureDescription UTF8String]);
			//go back up in tree
			_doc->getTree().goUp();
			
		}
		
		if ([_findings count] > 0) {
			_doc->getTree().addContentItem(DSRTypes::RT_contains, DSRTypes::VT_Container);
			_doc->getTree().getCurrentContentItem().setConceptName(DSRCodedEntryValue("121070", "DCM", "Findings"));
			NSEnumerator *enumerator = [_findings objectEnumerator];
			NSDictionary *dict;
			BOOL first = YES;
			
			while (dict = [enumerator nextObject]) {
				NSString *finding = [dict objectForKey:@"finding"];
				if (finding){
					if (first) {
						// go down one level if first Finding
						_doc->getTree().addContentItem(DSRTypes::RT_contains, DSRTypes::VT_Text, DSRTypes::AM_belowCurrent);
						first = NO;
					}
					else
						_doc->getTree().addContentItem(DSRTypes::RT_contains, DSRTypes::VT_Text);
					_doc->getTree().getCurrentContentItem().setConceptName(DSRCodedEntryValue("121071", "DCM", "Finding"));
					_doc->getTree().getCurrentContentItem().setStringValue([finding UTF8String]);
				}
			}
			//go back up in tree
			_doc->getTree().goUp();
			
		}
		
			
			
		if ([_conclusions count] > 0) {
			_doc->getTree().addContentItem(DSRTypes::RT_contains, DSRTypes::VT_Container);
			//SH.07 is probably wrong. I'm not sure how to get the right values here.
			_doc->getTree().getCurrentContentItem().setConceptName(DSRCodedEntryValue("121072", "DCM", "Impressions"));
			NSEnumerator *enumerator = [_conclusions objectEnumerator];
			NSDictionary *dict;
			BOOL first = YES;
			
			while (dict = [enumerator nextObject]) {
				if (first) {
					// go down one level if first Finding
					_doc->getTree().addContentItem(DSRTypes::RT_contains, DSRTypes::VT_Text, DSRTypes::AM_belowCurrent);
					first = NO;
				}
				else
					_doc->getTree().addContentItem(DSRTypes::RT_contains, DSRTypes::VT_Text);
				NSString *conclusion = [dict objectForKey:@"conclusion"];			
				_doc->getTree().getCurrentContentItem().setConceptName(DSRCodedEntryValue("121073", "DCM", "Impression"));
				_doc->getTree().getCurrentContentItem().setStringValue([conclusion UTF8String]);
			}
			//go back up in tree
			_doc->getTree().goUp();
		}
		
	
		
		/***** Exmaple of code to add a reference image **************
		_doc->getTree().addContentItem(DSRTypes::RT_contains, DSRTypes::VT_Image);
		_doc->getTree().getCurrentContentItem().setConceptName(DSRCodedEntryValue("121180", DCM, "Key Images"));
		_doc->getTree().getCurrentContentItem().setImageReference(DSRImageReferenceValue(SOPClassUID, SOPInstanceUID));
		_doc->getCurrentRequestedProcedureEvidence().addItem(const OFString &studyUID, const OFString &seriesUID, const OFString &sopClassUID, const OFString &instanceUID);
		*/
		
		_reportHasChanged = NO;
	}
}

- (void)save{
	
	DcmFileFormat fileformat;	
	OFCondition status = _doc->write(*fileformat.getDataset());
	if (status.good()) 
		status = fileformat.saveFile([[self srPath] UTF8String], EXS_LittleEndianExplicit);
	
	if (status.good()) 
		[_study setValue:[self srPath] forKey:@"reportURL"];
}

- (void)export:(NSString *)path{
	NSString *extension = [path pathExtension];
	if ([extension isEqualToString:@"dcm"]) {
		DcmFileFormat fileformat;	
		OFCondition status = _doc->write(*fileformat.getDataset());
		if (status.good()) 
			status = fileformat.saveFile([path UTF8String], EXS_LittleEndianExplicit);
	}
	else if ([extension isEqualToString:@"xml"]){
		size_t writeFlags = 0;		
		[self checkCharacterSet];
		ofstream stream([path UTF8String]);
		_doc->writeXML(stream, writeFlags);
	}
	else if ([extension isEqualToString:@"htm"] || [extension isEqualToString:@"html"]){
		if (_reportHasChanged) {
			[self createReport];
		}
		[self checkCharacterSet];
		size_t renderFlags = DSRTypes::HF_renderDcmtkFootnote;		
		ofstream stream([path UTF8String]);
		_doc->renderHTML(stream, renderFlags, NULL);
	}
}

- (void)convertXMLToSR{
	if (_doc)
		delete _doc;
	_doc = new DSRDocument();
	_doc->readXML([[self xmlPath] UTF8String], nil);
}

- (void)writeHTML{
	if (_reportHasChanged) {
		[self createReport];
	}
	[self checkCharacterSet];
	size_t renderFlags = DSRTypes::HF_renderDcmtkFootnote;		
	ofstream stream([[self htmlPath] UTF8String]);
	_doc->renderHTML(stream, renderFlags, NULL);	
}

- (void)writeXML{
	size_t writeFlags = 0;		
	[self checkCharacterSet];
	ofstream stream([[self xmlPath] UTF8String]);
	_doc->writeXML(stream, writeFlags);
}




- (void)readXML{
	[_xmlDoc release];
	NSURL *url = [NSURL fileURLWithPath:[self xmlPath]]; 
	NSError *error;
	_xmlDoc = [[NSXMLDocument alloc] initWithContentsOfURL:(NSURL *)url options:nil error:(NSError **)error];
}


- (NSString *)xmlPath{
	NSString *tempPath = @"/tmp";
	NSString *path = [[tempPath stringByAppendingPathComponent:[_study valueForKey:@"studyInstanceUID"]] stringByAppendingPathExtension:@"xml"];
	return path;
}
- (NSString *)htmlPath{
 	NSString *tempPath = @"/tmp";
	NSString *path = [[tempPath stringByAppendingPathComponent:[_study valueForKey:@"studyInstanceUID"]] stringByAppendingPathExtension:@"html"];
	return path;
}
- (NSString *)srPath{
	if (![_study valueForKey:@"reportURL"]) {
		NSString *dbPath = [[[BrowserController currentBrowser] documentsDirectory] stringByAppendingPathComponent:@"REPORTS"];
		NSString *path = [[dbPath stringByAppendingPathComponent:[_study valueForKey:@"studyInstanceUID"]] stringByAppendingPathExtension:@"dcm"];
		return path;
	}
	return [_study valueForKey:@"reportURL"];
}

//- (NSMXLDocument *)xmlDoc{
//	return _xmlDoc;
//}




	

@end
