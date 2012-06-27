#import <QuartzCore/CoreImage.h>
#import "app/AppDelegate.h"
#import "app/CoverBrowser.h"
#import "app/Log.h"
#import "app/Pthread.h"
#import "app/Search.h"
#import "app/Sort.h"
#import "app/Track.h"

static NSString * const kTotal = @"total";
static NSImage *blankImage = nil;

CoverBrowserTrackToKey CoverBrowserGroupByFolder = ^(Track *track) {
  return track.path.stringByDeletingLastPathComponent;
};

CoverBrowserTrackToKey CoverBrowserGroupByArtist = ^(Track *track) {
  return track.artist;
};

CoverBrowserTracksToPredicate CoverBrowserSearchByFolder = ^(NSSet *tracks) {
  for (Track *t in tracks) {
    if (!t.path || !t.path.length) {
      continue;
    }
    return [NSString stringWithFormat:@"path:\"%@\"", t.path.stringByDeletingLastPathComponent];
  }
  return nil;
};

CoverBrowserTracksToPredicate CoverBrowserSearchByArtist = ^(NSSet *tracks) {
  for (Track *t in tracks) {
    if (!t.artist || !t.artist.length) {
      continue;
    }
    return [NSString stringWithFormat:@"artist:\"%@\"", t.artist];
  }
  return nil;
};

CoverBrowserTracksToString CoverBrowserArtistTitle = ^(NSSet *tracks) {
  for (Track *t in tracks) {
    return t.artist;
  }
  return @"?";
};

CoverBrowserTracksToString CoverBrowserFolderTitle = ^(NSSet *tracks) {
    NSString *artist = nil;
    NSString *album = nil;
    NSString *title = nil;
    for (Track *t in tracks) {
      if (!artist) {
        artist = t.artist;
      } else if (t.artist && ![t.artist isEqual:artist]) {
        artist = @"Various Artists";
      }
      if (!album) {
        album = t.album;
      } else if (t.album && ![t.album isEqual:album]) {
        album = @"Various Albums";
      }
      title = t.title;
    }
    if (album && artist) {
      return [NSString stringWithFormat:@"%@ - %@", artist, album];
    } else if (album) {
      return album;
    } else if (artist) {
      return artist;
    } else if (title) {
      return title;
    } else {
      return [[[tracks anyObject] url] absoluteString];
    }
};

CoverBrowserTracksToString CoverBrowserFolderSubtitle = ^(NSSet *tracks)  {
  for (Track *t in tracks) {
    if (t.year && t.year.length) {
      return t.year;
    }
  }
  return nil;
};

CoverBrowserTracksToString CoverBrowserArtistSubtitle = ^(NSSet *tracks)  {
  NSMutableSet *albums = [NSMutableSet set];
  int n = 0;
  for (Track *t in tracks){
    n++;
    if (t.album && t.album.length) {
      [albums addObject:t.album];
    }
  }
  int i = albums.count;
  if (i > 0 || n > 0) {
    return [NSString stringWithFormat:@"%d Tracks / %d Albums", n, i];
  } else {
    return nil;
  }
};

@interface CoverBrowserItem : NSObject {
  NSMutableSet *tracks_;
  NSString *key_;
  CoverBrowserTracksToString toTitle_;
  CoverBrowserTracksToString toSubtitle_;
}


@property (retain) NSString *key;
@property (retain) NSMutableSet *tracks;
@property (copy) CoverBrowserTracksToString toTitle;
@property (copy) CoverBrowserTracksToString toSubtitle;

// IKImageBrowserItem protocol:
- (NSString *)imageUID;
- (NSUInteger)imageVersion;
- (NSString *)imageTitle;
- (NSString *)imageSubtitle;
- (NSString *)imageRepresentationType;
- (id)imageRepresentation;
- (BOOL)isSelectable;
@end

@implementation CoverBrowserItem
@synthesize tracks = tracks_;
@synthesize key = key_;
@synthesize toTitle = toTitle_;
@synthesize toSubtitle = toSubtitle_;

+ (void)initialize {
  blankImage = [NSImage imageNamed:@"album"];
}

- (NSString *)imageUID {
  return key_;
}

- (NSUInteger)imageVersion {
  return 0;
}

- (NSString *)imageTitle {
  @synchronized(tracks_) {
    if (toTitle_)
      return toTitle_(tracks_);
  }
  return @"";
}

- (NSString *)imageSubtitle {
  if (toSubtitle_) {
    @synchronized(tracks_) {
      return toSubtitle_(tracks_);
    }
  }
  return nil;
}

- (NSString *)imageRepresentationType {
  return IKImageBrowserNSImageRepresentationType;
}

- (id)imageRepresentation {
  for (Track *t in self.tracks) {
    if (t.coverArtID) {
      return [[[NSImage alloc] initWithContentsOfURL:t.coverArtURL] autorelease];
    }
  }
  return blankImage;
}

- (BOOL)isSelectable {
  return YES;
}

- (id)init {
  self = [super init];
  if (self) {
    self.tracks = [NSMutableSet set];
    self.key = @"";
  }
  return self;
}

- (void)dealloc {
  [tracks_ release];
  [key_ release];
  [super dealloc];
}
@end

@interface CoverBrowser (Private)
- (void)addTracks:(NSArray *)t;
- (void)removeTrack:(Track *)t;
@end

@implementation CoverBrowser
@synthesize items = items_;
@synthesize keyToItem = keyToItem_;
@synthesize library = library_;
@synthesize scrollView = scrollView_;
@synthesize browserView = browserView_;
@synthesize toPredicate = toPredicate_;
@synthesize toTitle = toTitle_;
@synthesize toSubtitle = toSubtitle_;
@synthesize toKey = toKey_;

- (id)initWithLibrary:(Library *)library
        toKey:(CoverBrowserTrackToKey)toKey
        toTitle:(CoverBrowserTracksToString)toTitle
        toSubtitle:(CoverBrowserTracksToString)toSubtitle
        toPredicate:(CoverBrowserTracksToPredicate)toPredicate {
  self = [super init];
  if (self) {
    self.toKey = toKey;
    self.toTitle = toTitle;
    self.toSubtitle = toSubtitle;
    self.toPredicate = toPredicate;
    self.items = [[[SortedSeq alloc] init] autorelease];
    self.items.comparator = ^(id left, id right) {
      return NaturalComparison([left imageTitle], [right imageTitle]);
    };
    self.library = library;
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(onTrackChange:)
     name:kLibraryTrackChanged
     object:self.library];
    self.scrollView = [[[NSScrollView alloc] initWithFrame:self.view.frame] autorelease];
    self.browserView = [[[IKImageBrowserView alloc] initWithFrame:self.scrollView.frame] autorelease];
    self.browserView.canControlQuickLookPanel = YES;

    self.scrollView.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable;
    self.browserView.autoresizingMask = (NSViewMinXMargin |
        NSViewWidthSizable | NSViewMaxXMargin | NSViewMinYMargin |
        NSViewHeightSizable | NSViewMaxYMargin);
    self.browserView.cellsStyleMask = IKCellsStyleTitled | IKCellsStyleSubtitled;
    self.browserView.cellSize = CGSizeMake(225, 225);
    self.browserView.animates = YES;
    self.browserView.delegate = self;
    self.browserView.intercellSpacing = CGSizeMake(7, 7);
    self.scrollView.focusRingType = NSFocusRingTypeNone;
    self.scrollView.frame = self.view.frame;
    self.scrollView.documentView = self.browserView;
    self.scrollView.hasHorizontalScroller = YES;
    self.scrollView.hasVerticalScroller = YES;
    [self.view addSubview:self.scrollView];
    self.keyToItem = [NSMutableDictionary dictionary];
    self.isBusy = true;
    ForkWith(^{
      NSMutableArray *seq = [NSMutableArray array];
      [self.library each:^(Track *t) {
        [seq addObject:t];
      }];
      [self addTracks:seq];
      ForkToMainWith(^{
        [self.browserView bind:@"content" toObject:items_ withKeyPath:@"arrangedObjects" options:nil];
      });
      self.isBusy = false;
    });
  }
  return self;
}

- (void)removeTrack:(Track *)t {
  CoverBrowserItem *item = nil;
  if (!toKey_)
    return;

  NSString *key = toKey_(t);
  if (!key) {
    return;
  }
  @synchronized(keyToItem_) {
    item = [keyToItem_ objectForKey:key];
  }
  if (!item) {
    return;
  }
  @synchronized(item.tracks) {
    [item.tracks removeObject:t];
  }
  if (item.tracks.count == 0) {
    @synchronized(keyToItem_) {
      [keyToItem_ removeObjectForKey:key];
    }
    ForkToMainWith(^{
      [items_ removeObject:item];
    });
  }
}

- (void)imageBrowser:(IKImageBrowserView *)aBrowser cellWasDoubleClickedAtIndex:(NSUInteger)index {
  if (!toPredicate_) {
    return;
  }
  NSArray *items = self.items.array;
  if (index < items.count) {
    CoverBrowserItem *item = [self.items get:index];
    NSString *query = toPredicate_(item.tracks);
    if (query && query.length) {
      // make this nicer
      [SharedAppDelegate().mainWindowController selectBrowser:MainWindowControllerTrackBrowser];
      [SharedAppDelegate() search:query after:^{
        [SharedAppDelegate() playTrackAtIndex:0];
      }];
    }
  }
}


- (void)addTracks:(NSArray *)tracks {
  if (!toKey_) {
    return;
  }

  for (Track *track in tracks) {
    CoverBrowserItem *item = nil;
    NSString *key = toKey_(track);
    if (!key) {
      continue;
    }
    @synchronized(keyToItem_) {
      item = [keyToItem_ objectForKey:key];
    }
    bool isNew = false;
    NSString *oldTitle;
    if (!item) {
      isNew = true;
      item = [[[CoverBrowserItem alloc] init] autorelease];
      item.key = key;
      item.toTitle = toTitle_;
      item.toSubtitle = toSubtitle_;
      @synchronized(keyToItem_) {
        [keyToItem_ setObject:item forKey:key];
      }
      isNew = true;
    } else {
      oldTitle = item.imageTitle;
    }
    @synchronized(item.tracks) {
      [item.tracks addObject:track];
    }
    if (isNew) {
      [self.items add:item];
    } else if (![item.imageTitle isEqualToString:oldTitle]) {
      [self.items remove:item];
      [self.items add:item];
    }
  }
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self.browserView unbind:@"content"];
  [library_ release];
  [browserView_ release];
  [scrollView_ release];
  [items_ release];
  [keyToItem_ release];
  [super dealloc];
}

- (void)onTrackChange:(NSNotification *)notification {
  Track *t = [notification.userInfo valueForKey:@"track"];
  NSString *change = [notification.userInfo valueForKey:@"change"];

  @synchronized(items_) {
    if (change == kLibraryTrackDeleted) {
      [self removeTrack:t];
    } else if (change == kLibraryTrackAdded) {
      [self addTracks:[NSArray arrayWithObjects:t, nil]];
    } else if (change == kLibraryTrackSaved) {
      [self removeTrack:t];
      [self addTracks:[NSArray arrayWithObjects:t, nil]];
    }
  }
}

- (void)search:(NSString *)term after:(On0)after {
  after = [after copy];
  ForkWith(^{
    NSPredicate *predicate = ParseSearchQuery(term);
    NSPredicate *predicate0 = predicate ? [NSPredicate predicateWithBlock:Block_copy(^(id item, NSDictionary *opts) {
      NSSet *tracks = [item valueForKey:@"tracks"];
      for (id t in tracks) {
        if ([predicate evaluateWithObject:t]) {
          return YES;
        }
      }
      return NO;
    })] : nil;
    self.items.predicate = predicate0;
    if (after)
      after();
  });
}
@end
