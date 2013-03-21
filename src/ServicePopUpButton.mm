#include <AvailabilityMacros.h>
#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudio.h>

#import "Enum.h"
#import "ServicePopUpButton.h"
#import "Log.h"

id AudioObjectGetObjectProperty(AudioObjectID objectID, UInt32 selector, UInt32 scope);
unsigned int QueryTransportType(AudioDeviceID deviceID);
NSArray *QueryOutputServices();

#define GET_PROPERTY(ID, SELECTOR, SCOPE, RET_ADDR) { \
  UInt32 propSize = sizeof(*RET_ADDR); \
  AudioObjectPropertyAddress query; \
	query.mSelector = SELECTOR; \
	query.mScope = SCOPE; \
	query.mElement = kAudioObjectPropertyElementMaster; \
  OSStatus ret = AudioObjectGetPropertyData(ID, &query, 0, NULL, &propSize, RET_ADDR); \
  if (ret) {  \
    ERROR(@"failed to fetch property %u, %u (%d)", SELECTOR, SCOPE, ret); \
  } \
}

#define GET_PROPERTY_SIZE(ID, SELECTOR, SCOPE, RET_ADDR) { \
  AudioObjectPropertyAddress query; \
	query.mSelector = SELECTOR; \
	query.mScope = SCOPE; \
	query.mElement = kAudioObjectPropertyElementMaster; \
  OSStatus ret = AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &addr, 0, NULL, RET_ADDR); \
  if (ret) {  \
    ERROR(@"failed to fetch property size %u, %u (%d)", SELECTOR, SCOPE, ret); \
  } \
}

NSArray *QueryAudioSources(AudioDeviceID deviceID) {
  NSMutableArray *audioSources = [NSMutableArray array];
  UInt32 dataSize = 0;
  AudioObjectPropertyAddress dataSourceAddr;
  dataSourceAddr.mSelector = kAudioDevicePropertyDataSources;
  dataSourceAddr.mScope = kAudioDevicePropertyScopeOutput;
  dataSourceAddr.mElement = kAudioObjectPropertyElementMaster;
  AudioObjectGetPropertyDataSize(deviceID, &dataSourceAddr, 0, NULL, &dataSize);

  UInt32 numSourceIDs = dataSize / sizeof(UInt32);
  UInt32 sourceIDs[numSourceIDs];

  AudioObjectGetPropertyData(deviceID, &dataSourceAddr, 0, NULL, &dataSize, sourceIDs);
  for (int j = 0; j < numSourceIDs; j++) {
    UInt32 sourceID = sourceIDs[j];
    INFO(@"source Id: %u", sourceID);
    AudioObjectPropertyAddress nameAddr;
    nameAddr.mSelector = kAudioDevicePropertyDataSourceNameForIDCFString;
    nameAddr.mScope = kAudioObjectPropertyScopeOutput;
    nameAddr.mElement = kAudioObjectPropertyElementMaster;

    NSString *value = nil;

    AudioValueTranslation audioValueTranslation;
    audioValueTranslation.mInputDataSize = sizeof(UInt32);
    audioValueTranslation.mOutputData = (void *) &value;
    audioValueTranslation.mOutputDataSize = sizeof(CFStringRef);
    audioValueTranslation.mInputData = (void *) &sourceID;

    UInt32 propsize = sizeof(AudioValueTranslation);

    AudioObjectGetPropertyData(deviceID, &nameAddr, 0, NULL, &propsize, &audioValueTranslation);
    [audioSources addObject:@{
        @"title": value ? value : @"",
        @"id": [NSNumber numberWithInt:sourceID]}];
  }
  return audioSources;
}

unsigned int QueryTransportType(AudioDeviceID deviceID) {
  unsigned int result = 0;
  GET_PROPERTY(deviceID, kAudioDevicePropertyTransportType, kAudioObjectPropertyScopeGlobal, &result);
  return result;
}

BOOL QueryIsOutput(AudioDeviceID deviceID) {
  BOOL result = NO;
  UInt32 propsize;

  AudioObjectPropertyAddress addr;
  addr.mSelector = kAudioDevicePropertyStreams;
  addr.mScope = kAudioDevicePropertyScopeInput;
  addr.mElement = kAudioObjectPropertyElementWildcard;

  AudioObjectGetPropertyDataSize(deviceID, &addr, 0, NULL, &propsize);
  int numberOfInputStreams = propsize / sizeof(AudioStreamID);
  result = numberOfInputStreams == 0;
  return result;
}




id AudioObjectGetObjectProperty(AudioObjectID objectID, UInt32 selector, UInt32 scope) {
  id result = nil;
  UInt32 propSize = sizeof(result);
  AudioObjectPropertyAddress query;
	query.mSelector = selector;
	query.mScope = scope;
	query.mElement = kAudioObjectPropertyElementMaster;
  OSStatus ret = AudioObjectGetPropertyData(objectID, &query, 0, NULL, &propSize, &result);
  if (ret) {
    ERROR(@"failed to fetch property %u, %u (%d)", selector, scope, ret);
  }
  return result;
}

NSArray *QueryOutputServices() {
  NSMutableArray *result = [NSMutableArray array];
  AudioObjectPropertyAddress addr;
  addr.mSelector = kAudioHardwarePropertyDevices;
  addr.mScope = kAudioObjectPropertyScopeOutput;
  addr.mElement = kAudioObjectPropertyElementWildcard;
  UInt32 propSize;
  AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &addr, 0, NULL, &propSize);
  UInt32 numDevices = propSize / sizeof(AudioDeviceID);
  AudioDeviceID deviceIDs[numDevices];
  AudioObjectGetPropertyData(kAudioObjectSystemObject, &addr, 0, NULL, &propSize, deviceIDs);
  for (int i = 0; i < numDevices; i++) {
    AudioDeviceID deviceID = deviceIDs[i];
    if (!QueryIsOutput(deviceID)) {
      continue;
    }
    INFO(@"Device ID: %d", (int)deviceID);
    NSString *outputID = nil;
    GET_PROPERTY(deviceID, kAudioDevicePropertyDeviceUID, kAudioObjectPropertyScopeOutput, &outputID);
    if (!outputID)
      outputID = @"";

    NSString *title = nil;
    GET_PROPERTY(deviceID, kAudioObjectPropertyName, kAudioObjectPropertyScopeGlobal, &title);
    title = title ? title : @"";

    NSArray *sources = QueryAudioSources(deviceID);
    for (NSDictionary *source in sources) {
      if (source[@"title"])
        title = source[@"title"];
    }
    unsigned int transportType = QueryTransportType(deviceID);
    NSDictionary *item = @{
      @"id": outputID,
      @"deviceID": [NSNumber numberWithLong:(long)deviceID],
      @"transportType": @(transportType),
      @"isAirplay": @(transportType == kAudioDeviceTransportTypeAirPlay),
      @"title": title};
    [result addObject:item];
  }
  return result;
}

@interface ServicePopUpButton (Private)
- (void)reloadServices;
- (NSString *)selectedID;

@end

OSStatus OnPropertyChange(AudioObjectID inObjectID,
    UInt32 inNumberAddresses,
    const AudioObjectPropertyAddress inAddresses[],
    void*inClientData) {
  ServicePopUpButton *button = (ServicePopUpButton *)inClientData;
  [button performSelectorOnMainThread:@selector(reloadServices) withObject:nil waitUntilDone:NO];
  return 0;
}

@implementation ServicePopUpButton
@synthesize services = services_;
@synthesize onService = onService_;

- (void)dealloc {
  [onService_ release];
  [services_ release];
  AudioObjectPropertyAddress addr;
  addr.mSelector = kAudioHardwarePropertyDevices;
  addr.mScope = kAudioObjectPropertyScopeOutput;
  addr.mElement = kAudioObjectPropertyElementWildcard;
  AudioObjectRemovePropertyListener(kAudioObjectSystemObject, &addr, OnPropertyChange, self);
  [super dealloc];
}

- (id)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    self.target = self;
    self.action = @selector(onClick:);
    [self reloadServices];
    AudioObjectPropertyAddress addr;
    addr.mSelector = kAudioHardwarePropertyDevices;
    addr.mScope = kAudioObjectPropertyScopeOutput;
    addr.mElement = kAudioObjectPropertyElementWildcard;
    AudioObjectAddPropertyListener(kAudioObjectSystemObject, &addr, OnPropertyChange, self);
  }
  return self;
}

- (void)onClick:(id)sender {
  NSDictionary *item = [self selectedOutput];
  if (item && onService_) {
    self.onService(item);
  }
}

- (NSDictionary *)selectedOutput {
  int i = self.indexOfSelectedItem;
  if (i >= 0 && i < self.services.count) {
    return self.services[i];
  } else {
    return nil;
  }

}

- (void)selectItem:(id)sender {
  INFO(@"Select item: %@", [sender representedObject]);
}

- (void)reloadServices {
  NSArray *services = [QueryOutputServices()
   sortedArrayUsingComparator:^NSComparisonResult(id left, id right) {
    return [left[@"isAirplay"] intValue] - [right[@"isAirplay"] intValue];
   }];
  self.services = services;
  [self removeAllItems];
  for (NSDictionary *s in services) {
    [self addItemWithTitle:s[@"title"]];
  }
}

@end
