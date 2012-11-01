#import <Cocoa/Cocoa.h>

// vim: set filetype=objcpp

extern NSString *kChromaprintAPIKey;
int ChromaprintFingerprint(NSString *url, NSString **fingerprint, int *duration);
NSDictionary *AcousticIDLookup(NSString *apiKey, NSString *fingerprint, int duration);
int ChromaprintGetAcousticID(NSString *apiKey, NSString *path, NSString **acousticID, double *score);
