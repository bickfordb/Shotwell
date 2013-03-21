#include <stdio.h>
#include <string>
#include <sys/stat.h>

#include <objc/runtime.h>

#import "Chromaprint.h"
#import "Library.h"
#import "Track.h"
#import "Log.h"
#import "Util.h"
#import "UUID.h"

NSString * const kTrackStarted = @"TrackStarted";
NSString * const kTrackEnded = @"TrackEnded";
NSString * const kTrackAdded = @"TrackAdded";
NSString * const kTrackDeleted = @"TrackDeleted";
NSString * const kTrackAcoustID = @"acoustID";
NSString * const kTrackAlbum = @"album";
NSString * const kTrackArtist = @"artist";
NSString * const kTrackCreatedAt = @"createdAt";
NSString * const kTrackCoverArtID = @"coverArtID";
NSString * const kTrackDuration = @"duration";
NSString * const kTrackIsCoverArtChecked = @"isCoverArtChecked";
NSString * const kTrackGenre = @"genre";
NSString * const kTrackID = @"id";
NSString * const kTrackIsAcoustIDChecked = @"isAcoustIDChecked";
NSString * const kTrackIsAudio = @"isAudio";
NSString * const kTrackIsVideo = @"isVideo";
NSString * const kTrackLastPlayedAt = @"lastPlayedAt";
NSString * const kTrackLibrary = @"library";
NSString * const kTrackPath = @"path";
NSString * const kTrackPublisher = @"publisher";
NSString * const kTrackTitle = @"title";
NSString * const kTrackNumber = @"trackNumber";
NSString * const kTrackUpdatedAt = @"updatedAt";
NSString * const kTrackURL = @"url";
NSString * const kTrackYear = @"year";

static NSArray *allTrackKeys = @[
    kTrackAcoustID,
    kTrackAlbum,
    kTrackArtist,
    kTrackCoverArtID,
    kTrackCreatedAt,
    kTrackDuration,
    kTrackGenre,
    kTrackID,
    kTrackIsAcoustIDChecked,
    kTrackIsAudio,
    kTrackIsCoverArtChecked,
    kTrackIsVideo,
    kTrackLastPlayedAt,
    kTrackPath,
    kTrackPublisher,
    kTrackTitle,
    kTrackURL,
    kTrackNumber,
    kTrackUpdatedAt,
    kTrackYear];

NSMutableDictionary *TrackNew() {
  NSMutableDictionary *t = [NSMutableDictionary dictionary];
  t[kTrackID] = [[NSData randomUUIDLike] hex];
  t[kTrackUpdatedAt] = [NSDate date];
  t[kTrackCreatedAt] = [NSDate date];
  return t;
}

