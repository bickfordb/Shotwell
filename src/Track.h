#import <Cocoa/Cocoa.h>

@class Library;

// vim: set filetype=objcpp
/* Track keys */
extern NSString * const kTrackAcoustID;
extern NSString * const kTrackAdded;
extern NSString * const kTrackAlbum;
extern NSString * const kTrackArtist;
extern NSString * const kTrackCoverArtID;
extern NSString * const kTrackCreatedAt;
extern NSString * const kTrackDeleted;
extern NSString * const kTrackDuration;
extern NSString * const kTrackEnded;
extern NSString * const kTrackGenre;
extern NSString * const kTrackID;
extern NSString * const kTrackIsAcoustIDChecked;
extern NSString * const kTrackIsAudio;
extern NSString * const kTrackIsCoverArtChecked;
extern NSString * const kTrackIsVideo;
extern NSString * const kTrackLastPlayedAt;
extern NSString * const kTrackLibrary;
extern NSString * const kTrackNumber;
extern NSString * const kTrackPath;
extern NSString * const kTrackPublisher;
extern NSString * const kTrackStarted;
extern NSString * const kTrackTitle;
extern NSString * const kTrackURL;
extern NSString * const kTrackUpdatedAt;
extern NSString * const kTrackYear;

NSMutableDictionary *TrackNew();
BOOL TrackIsEqual(NSMutableDictionary *track, NSMutableDictionary *otherTrack);
NSURL *TrackURL(NSMutableDictionary *track, Library *library);

// vim: filetype=objcpp
