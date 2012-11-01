#import <Cocoa/Cocoa.h>

// vim: set filetype=objcpp

extern NSString *kChromaprintAPIKey;
int ChromaprintFingerprint(NSString *url, NSString **fingerprint, int *duration);
NSDictionary *AcoustIDLookup(NSString *apiKey, NSString *fingerprint, int duration, NSArray *fields);
int ChromaprintGetAcoustID(NSString *apiKey, NSString *path, NSDictionary **acoustID, NSArray *fields);
