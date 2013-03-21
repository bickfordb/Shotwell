#import <Cocoa/Cocoa.h>
#import "Library.h"

extern NSString * const kScanPathsChanged;

@interface LocalLibrary : Library
@property bool pruneRequested;
@property (retain) NSMutableSet *pathsToScan;

+ (LocalLibrary *)shared;
- (id)initWithDBPath:(NSString *)dbPath;
- (void)clear;
- (void)prune;
- (void)each:(void (^)(NSMutableDictionary *track))block;
- (void)checkITunesImport;
- (void)noteAddedPath:(NSString *)aPath;
- (void)checkAutomaticPaths;
- (void)scan:(NSArray *)paths;
@property bool isITunesImported;
@property (copy) NSArray *pathsToAutomaticallyScan;
@end

