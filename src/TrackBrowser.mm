#import "AppDelegate.h"
#import "Enum.h"
#import "LocalLibrary.h"
#import "Log.h"
#import "MainWindowController.h"
#import "MicroSecondsToDate.h"
#import "MicroSecondsToHMS.h"
#import "NSNumberTimeFormat.h"
#import "Player.h"
#import "Search.h"
#import "Sort.h"
#import "Track.h"
#import "TrackBrowser.h"
#import "Util.h"

static NSString * const kStatus = @"status";
static NSString * const kIsPaused = @"isPaused";
static NSString * const kIsDone = @"isDone";
static NSString * const kOnSortDescriptorsChanged = @"OnSortDescriptorsChanged";
static double const kTrackFontSize = 11.0;

@implementation TrackBrowser {
  SortedSeq *tracks_;
  NSFont *playingFont_;
  NSFont *font_;
  NSImage *emptyImage_;
  NSImage *playImage_;
  Library *library_;
}

@synthesize emptyImage = emptyImage_;
@synthesize font = font_;
@synthesize playImage = playImage_;
@synthesize playingFont = playingFont_;
@synthesize tracks = tracks_;
@synthesize library = library_;

NSComparator GetComparatorFromSortDescriptors(NSArray *sortDescriptors) {
  NSMutableArray *sds = [NSMutableArray array];
  for (NSSortDescriptor *sd in sortDescriptors) {
    [sds addObject:[sd copy]];
  }
  return Block_copy(^(id left, id right) {
    NSComparisonResult ret = NSOrderedSame;
    for (NSSortDescriptor *sd in sds) {
      NSString *key = sd.key;
      id valLeft = [left valueForKey:key];
      id valRight = [right valueForKey:key];
      if (valLeft && !valRight)
        ret = NSOrderedAscending;
      else if (!valRight && !valLeft)
        ret = NSOrderedSame;
      else if (!valLeft && valRight)
        ret = NSOrderedDescending;
      else
        ret = sd.comparator(valLeft, valRight);
      if (!sd.ascending)
        ret *= -1;
      if (ret != NSOrderedSame) {
        break;
      }
    }
    return ret;
  });
}

- (id)currentTrack {
  return nil;
}

- (void)setCurrentTrack:(NSMutableDictionary *)track {
  __block NSUInteger row = NSNotFound;
  NSObject *trackID = (NSObject *)track[kTrackID];
  [[NSUserDefaults standardUserDefaults] setObject:trackID forKey:@"lastTrackID"];
  ForkToMainWith(^{
    [self.tableView reloadData];
    if (row != NSNotFound) {
    }
  });
  [self seekToTrackID:trackID];

}

- (void)delete:(id)sender {
  [self cutSelectedTracks];
  [self.tableView deselectAll:self];
}

- (NSArray *)selectedTracks {
  NSIndexSet *indices = self.tableView.selectedRowIndexes;
  return [self.tracks getMany:indices];
}

- (BOOL)acceptURLs:(NSArray *)urls {
  INFO(@"accept URLS:", urls);
  NSArray *fileURLs = Filter(urls, ^(id url) { return (bool)[url isFileURL]; });
  NSArray *paths = [fileURLs valueForKey:@"path"];
  [self.library scan:paths];
  return paths.count > 0;
}

- (NSArray *)cutSelectedTracks {
  NSIndexSet *indices = self.tableView.selectedRowIndexes;
  NSArray *tracks = [self.tracks getMany:indices];
  ForkWith(^{
    for (id track in tracks) {
      self.library[track[kTrackID]] = nil;
    }
  });
  return tracks;
}

- (void)copy:(id)sender {
  NSArray *tracks = self.selectedTracks;
  ForkWith(^{
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb clearContents];
    [pb declareTypes:[NSArray arrayWithObject:NSURLPboardType] owner:nil];
    [pb writeObjects:[tracks valueForKey:kTrackURL]];
  });
}

- (void)cut:(id)sender {
  NSArray *tracks = self.cutSelectedTracks;
  [self.tableView deselectAll:self];
  NSPasteboard *pb = [NSPasteboard generalPasteboard];
  [pb clearContents];
  [pb declareTypes:[NSArray arrayWithObject:NSURLPboardType] owner:nil];
  [pb writeObjects:[tracks valueForKey:kTrackURL]];
}


- (void)search:(NSString *)term after:(On0)after {
  self.lastSearch = term;
  after = [after copy];
  ForkToMainWith(^{
    @synchronized(tracks_) {
      tracks_.predicate = ParseSearchQuery(term);
    }
    [self reload];
    if (after)
      after();
  });
}

- (id)init {
  self = [super init];
  if (self) {
    self.library = [LocalLibrary shared];
    self.tracks = [[[SortedSeq alloc] init] autorelease];
    self.scrollView.borderType = NSNoBorder;
    __block TrackBrowser *weakSelf = self;
    self.font = [NSFont systemFontOfSize:kTrackFontSize];
    self.playingFont = [NSFont boldSystemFontOfSize:kTrackFontSize];
    self.tableView.onKeyDown = ^(NSEvent *e) {
      if (e.keyCode == 49) {
        /* handle play click here*/

        return false;
      }
      return true;
    };
    [self.tableView
      addObserver:self
      forKeyPath:@"sortDescriptors"
      options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld)
      context:kOnSortDescriptorsChanged];

    NSMenu *tableMenu = [[[NSMenu alloc] initWithTitle:@"Track Menu"] autorelease];
    [tableMenu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
    [tableMenu addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"c"];
    [tableMenu addItemWithTitle:@"Delete" action:@selector(delete:) keyEquivalent:@""];
    self.tableView.menu = tableMenu;
    self.emptyImage = [[[NSImage alloc] initWithSize:NSMakeSize(22, 22)] autorelease];
    self.playImage = [NSImage imageNamed:@"dot"];

    NSMutableDictionary *cols = [NSMutableDictionary dictionary];
    NSArray *colSpecs = @[
      @{@"identifier": kStatus,
        @"dataCell": [[[NSImageCell alloc] initImageCell:emptyImage_] autorelease],
        @"width": @30,
        @"title": @"",
        @"maxWidth": @30},
      @{@"identifier": kTrackNumber,
        @"title": @"#",
        @"width": @50,
        @"comparator": StandardComparison,
        @"key": kTrackNumber},
      @{@"identifier": kTrackTitle,
        @"title": @"Title",
        @"width": @250,
        @"comparator": StandardComparison,
        @"key": kTrackTitle},
      @{@"identifier": kTrackArtist,
        @"title": @"Artist",
        @"width": @180,
        @"comparator": StandardComparison,
        @"key": kTrackArtist},
      @{@"identifier": kTrackAlbum,
        @"title": @"Album",
        @"width": @180,
        @"comparator": StandardComparison,
        @"key": kTrackAlbum},
      @{@"identifier": kTrackGenre,
        @"title": @"Genre",
        @"width": @150,
        @"comparator": StandardComparison,
        @"key": kTrackGenre},
      @{@"identifier": kTrackDuration,
        @"title": @"Duration",
        @"width": @50,
        @"bindingOptions": @{
          NSValueTransformerBindingOption: [[[MicroSecondsToHMS alloc] init] autorelease]},
        @"key": kTrackDuration},
      @{@"identifier": kTrackYear,
        @"title": @"Year",
        @"width": @50,
        @"keyPath": @"arrangedObjects.year",
        @"comparator": StandardComparison,
        @"key": kTrackYear},
      @{@"identifier": kTrackPath,
        @"title": @"Path",
        @"width": @1000,
        @"key": kTrackPath,
        @"comparator": StandardComparison,
        @"key": kTrackPath},
      @{@"identifier": kTrackCreatedAt,
        @"title": @"Created",
        @"width": @150,
        @"bindingOptions": @{},
        @"key": kTrackCreatedAt},
      @{@"identifier": kTrackUpdatedAt,
        @"title": @"Updated",
        @"width": @150,
        @"bindingOptions": @{},
        @"key": kTrackUpdatedAt},
        @{@"identifier": kTrackLastPlayedAt,
        @"title": @"Last Played",
        @"width": @150,
        @"bindingOptions": @{},
        @"key": kTrackLastPlayedAt}];
    for (NSDictionary *colSpec in colSpecs) {
      NSTableColumn *col = [[[NSTableColumn alloc] initWithIdentifier:colSpec[@"identifier"]] autorelease];
      if (colSpec[@"width"])
        [col setWidth:[colSpec[@"width"] intValue]];
      if (colSpec[@"maxWidth"])
        [col setMaxWidth:[colSpec[@"maxWidth"] intValue]];
      if (colSpec[@"dataCell"])
        [col setDataCell:colSpec[@"dataCell"]];
      if (colSpec[@"title"])
        [[col headerCell] setStringValue:colSpec[@"title"]];
      NSString *keyPath = colSpec[@"keyPath"];
      NSString *key = colSpec[@"key"];
      if (!keyPath && key) {
        keyPath = [NSString stringWithFormat:@"arrangedObjects.%@", key];
      }
      NSDictionary *bindingOptions = colSpec[@"bindingOptions"];
      if (keyPath) {
        [col bind:@"value" toObject:self.tracks withKeyPath:keyPath options:bindingOptions];
      }
      NSComparator comparator = colSpec[@"comparator"];
      if (!comparator) comparator = DefaultComparison;
      if (key) {
        col.sortDescriptorPrototype = [NSSortDescriptor sortDescriptorWithKey:key ascending:YES comparator:comparator];
      }
      NSCell *dataCell = [col dataCell];
      NSCell *headerCell = [col headerCell];
      [headerCell setFont:[NSFont boldSystemFontOfSize:kTrackFontSize]];
      if ([dataCell isKindOfClass:[NSTextFieldCell class]]) {
        [dataCell setFont:[NSFont systemFontOfSize:kTrackFontSize]];
      }
      [self.tableView addTableColumn:col];
      cols[colSpec[@"identifier"]] = col;
    }

    NSMutableArray *sortDescriptors = [NSMutableArray array];
    for (id key in @[kTrackArtist, kTrackAlbum, kTrackNumber, kTrackTitle, kTrackPath]) {
      id sd = [cols[key] sortDescriptorPrototype];
      if (sd) {
        [sortDescriptors addObject:sd];
      }
    }
    self.tableView.sortDescriptors = sortDescriptors;

    // embed the table view in the scroll view, and add the scroll view
    // to our window.

    self.onDoubleAction = ^(int row){
      [self playTrackAtIndex:row];
    };
    self.onCellValue = ^id(int row, NSTableColumn *tableColumn) {
      NSMutableDictionary *t = [weakSelf.tracks get:row];
      NSString *ident = tableColumn.identifier;
      bool isPlaying = [[Player shared].track isEqual:t];
      [[tableColumn dataCell] setFont:isPlaying ? playingFont_ : font_];
      if (ident == kStatus) {
        return isPlaying ? playImage_ : emptyImage_;
      }
      return nil;
    };
    self.onRowCount = ^{
      return (int)[weakSelf.tracks count];
    };
    ForkWith(^{
      [self.library each:^(NSMutableDictionary *t) {
        [tracks_ addObject:t];
      }];
      id lastTrackID = [[NSUserDefaults standardUserDefaults] objectForKey:@"lastTrackID"];
      [self seekToTrackID:lastTrackID];
    });
    [[NSNotificationCenter defaultCenter]
      addObserver:self
      selector:@selector(onTrackChange:)
      name:kLibraryTrackChanged
      object:library_];
    [self.tableView
      bind:@"content"
      toObject:tracks_
      withKeyPath:@"arrangedObjects"
      options:nil];
    [self bind:@"currentTrack" toObject:[Player shared] withKeyPath:@"track" options:nil];
    [[Player shared] addObserver:self
      forKeyPath:@"isDone"
      options:(NSKeyValueObservingOptionNew) context:kIsDone];
    [[Player shared] addObserver:self
      forKeyPath:@"isPaused"
      options:(NSKeyValueObservingOptionNew) context:kIsPaused];
  }
  return self;
}

- (void)seekToTrackID:(id)trackID {
  if (!trackID) return;
  __block NSUInteger location = NSNotFound;
  __block NSUInteger i = 0;
  [tracks_ each:^(id item, bool *stop) {
    id otherID = item[kTrackID];
    if ([otherID isEqual:trackID]) {
      location = i;
    }
    i++;
  }];
  if (location != NSNotFound) {
    ForkToMainWith(^{
      [self.tableView scrollRowToVisible:(NSInteger)location];
    });
  }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
  if (context == kOnSortDescriptorsChanged) {
    self.tracks.comparator = GetComparatorFromSortDescriptors(self.tableView.sortDescriptors);
  } else if (context == kIsDone) {
    if ([Player shared].isDone) {
      INFO(@"player is done");
      ForkWith(^{ [self playNextTrack];});
    }
  } else if (context == kIsPaused) {
  } else if ([super respondsToSelector:@selector(observeValueForKeyPath:ofObject:change:context:)]) {
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
  }
}

- (void)onTrackChange:(NSNotification *)notification {
  NSString *change = [notification.userInfo valueForKey:@"change"];
  NSMutableDictionary *t = [notification.userInfo valueForKey:@"track"];
  ForkWith(^{
    if (change == kLibraryTrackAdded) {
      [self.tracks addObject:t];
    } else if (change == kLibraryTrackDeleted) {
      [self.tracks removeObject:t];
    } else if (change == kLibraryTrackSaved) {
      [self.tracks removeObject:t];
      [self.tracks addObject:t];
    }
  });
}

- (void)dealloc {
  [self.tableView unbind:@"content"];
  [self.tableView removeObserver:self forKeyPath:@"sortDescriptors" context:kOnSortDescriptorsChanged];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [[Player shared] removeObserver:self forKeyPath:@"isDone" context:kIsDone];
  [[Player shared] removeObserver:self forKeyPath:@"isPaused" context:kIsPaused];
  [library_ release];
  [playingFont_ release];
  [font_ release];
  [emptyImage_ release];
  [playImage_ release];
  [tracks_ release];
  [super dealloc];
}

- (void)playTrackAtIndex:(int)index {
  NSMutableDictionary *t = [tracks_ get:index];
  [[Player shared] playTrack:t];
}

/*
 * Play the next track.
 */
- (void)playNextTrack {
  IgnoreSigPIPE();
  int found = -1;
  id track = [[Player shared] track];
  if (track) {
    found = IndexOf(tracks_, track);
  }
  [self playTrackAtIndex:found + 1];
}

- (void)playPreviousTrack {
  int found = 0;
  id track = [[Player shared] track];
  if (track) {
    found = IndexOf(tracks_, track);
  }
  if (found > 0) {
    [self playTrackAtIndex:found - 1];
  }
}
@end
