#include <AvailabilityMacros.h>
#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudio.h>


#import "app/ServicePopUpButton.h"
#import "app/Log.h"

id AudioObjectGetObjectProperty( AudioObjectID objectID, UInt32 selector);
NSArray *QueryOutputServices();

id AudioObjectGetObjectProperty( AudioObjectID objectID, UInt32 selector) {
  id result = nil;
  UInt32 propSize;
  AudioObjectPropertyAddress query;
	query.mSelector = selector;
	query.mScope = kAudioObjectPropertyScopeOutput;
	query.mElement = kAudioObjectPropertyElementMaster;
  AudioObjectGetPropertyData(objectID, &query, 0, NULL, &propSize, &result);
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
    INFO(@"Device ID: %d", (int)deviceID);
    NSString *outputID = AudioObjectGetObjectProperty(deviceID, kAudioDevicePropertyDeviceUID);
    if (!outputID)
      outputID = @"";
    NSString *title = AudioObjectGetObjectProperty(deviceID, kAudioObjectPropertyName);
    if (!title)
      title = @"";
    INFO(@"title: %@", title);

    NSDictionary *item = @{
      @"id": outputID,
      @"deviceID": [NSNumber numberWithLong:(long)deviceID],
      @"title": title};
    [result addObject:item];
  }
  return result;
}

@interface ServicePopUpButton (Private)
- (void)reloadServices;
- (NSString *)selectedID;

@end

@implementation ServicePopUpButton
@synthesize services = services_;
@synthesize onService = onService_;

- (void)dealloc {
  [onService_ release];
  [services_ release];
  [super dealloc];
}

- (id)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    self.target = self;
    self.action = @selector(onClick:);
    [self reloadServices];
  }
  return self;
}

- (NSDictionary *)selectedOutput {
  int i = self.indexOfSelectedItem;
  if (i >= 0 && i < self.services.count) {
    return self.services[i];
  } else {
    return nil;
  }

}

- (void)reloadServices {
  NSDictionary *selected = [self selectedOutput];
  self.services = QueryOutputServices();
  [self removeAllItems];
  int i = 0;
  for (NSDictionary *s in self.services) {
    [self addItemWithTitle:s[@"title"]];
    if ([selected[@"id"] isEqual:s[@"id"]]) {
      [self selectItemAtIndex:i];
    }
    i++;
  }
  INFO(@"services: %@", self.services);
}

- (void)onClick:(id)sender {
  NSDictionary *output = self.selectedOutput;
  if (output && onService_) {
    onService_(output);
  }
}

@end
