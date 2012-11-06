#import "app/AppDelegate.h"
#import "app/Enum.h"
#import "app/Log.h"
#import "app/MicroSecondsToDate.h"
#import "app/MicroSecondsToHMS.h"
#import "app/NSNumberTimeFormat.h"
#import "app/Pthread.h"
#import "app/Search.h"
#import "app/Sort.h"
#import "app/Track.h"
#import "app/TrackBrowser.h"

static NSString * const kStatus = @"status";
static NSString * const kOnSortDescriptorsChanged = @"OnSortDescriptorsChanged";
static double const kTrackFontSize = 11.0;




@implementation TrackBrowser
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
    for (Track *t in tracks) {
      [self.library delete:t];
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
    [pb writeObjects:[tracks valueForKey:kURL]];
  });
}

- (void)cut:(id)sender {
  NSArray *tracks = self.cutSelectedTracks;
  [self.tableView deselectAll:self];
  NSPasteboard *pb = [NSPasteboard generalPasteboard];
  [pb clearContents];
  [pb declareTypes:[NSArray arrayWithObject:NSURLPboardType] owner:nil];
  [pb writeObjects:[tracks valueForKey:kURL]];
}


- (void)search:(NSString *)term after:(On0)after {
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

- (id)initWithLibrary:(Library *)library {
  self = [super init];
  if (self) {
    self.library = library;
    self.tracks = [[[SortedSeq alloc] init] autorelease];
    self.scrollView.borderType = NSNoBorder;
    __block TrackBrowser *weakSelf = self;
    self.font = [NSFont systemFontOfSize:kTrackFontSize];
    self.playingFont = [NSFont boldSystemFontOfSize:kTrackFontSize];
    self.tableView.onKeyDown = ^(NSEvent *e) {
      if (e.keyCode == 49) {
        [SharedAppDelegate() playClicked:nil];
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
      @{@"identifier": kTitle,
        @"title": @"Title",
        @"width": @250,
        @"comparator": StandardComparison,
        @"key": kTitle},
      @{@"identifier": kArtist,
        @"title": @"Artist",
        @"width": @180,
        @"comparator": StandardComparison,
        @"key": kArtist},
      @{@"identifier": kAlbum,
        @"title": @"Album",
        @"width": @180,
        @"comparator": StandardComparison,
        @"key": kAlbum},
      @{@"identifier": kGenre,
        @"title": @"Genre",
        @"width": @150,
        @"comparator": StandardComparison,
        @"key": kGenre},
      @{@"identifier": kDuration,
        @"title": @"Duration",
        @"width": @50,
        @"bindingOptions": @{
          NSValueTransformerBindingOption: [[[MicroSecondsToHMS alloc] init] autorelease]},
        @"key": kDuration},
      @{@"identifier": kYear,
        @"title": @"Year",
        @"width": @50,
        @"keyPath": @"arrangedObjects.year",
        @"comparator": StandardComparison,
        @"key": kYear},
      @{@"identifier": kPath,
        @"title": @"Path",
        @"width": @1000,
        @"key": kPath,
        @"comparator": StandardComparison,
        @"key": kPath},
      @{@"identifier": kCreatedAt,
        @"title": @"Created",
        @"width": @150,
        @"bindingOptions": @{NSValueTransformerBindingOption: [[[MicroSecondsToDate alloc] init] autorelease]},
        @"key": kCreatedAt},
      @{@"identifier": kUpdatedAt,
        @"title": @"Updated",
        @"width": @150,
        @"bindingOptions": @{NSValueTransformerBindingOption: [[[MicroSecondsToDate alloc] init] autorelease]},
        @"key": kUpdatedAt},
        @{@"identifier": kLastPlayedAt,
        @"title": @"Last Played",
        @"width": @150,
        @"bindingOptions": @{NSValueTransformerBindingOption: [[[MicroSecondsToDate alloc] init] autorelease]},
        @"key": kLastPlayedAt}];

    for (NSDictionary *colSpec in colSpecs) {
      NSTableColumn *col = [[[NSTableColumn alloc] initWithIdentifier:colSpec[@"identifier"]] autorelease];
      if (colSpec[@"width"])
        [col setWidth:[colSpec[@"width"] intValue]];
      if (colSpec[@"maxWidth"])
        [col setWidth:[colSpec[@"maxWidth"] intValue]];
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
    for (id key in @[kArtist, kAlbum, kTrackNumber, kTitle, kPath]) {
      id sd = [cols[key] sortDescriptorPrototype];
      if (sd) {
        [sortDescriptors addObject:sd];
      }
    }
    self.tableView.sortDescriptors = sortDescriptors;

    // embed the table view in the scroll view, and add the scroll view
    // to our window.

    self.onDoubleAction = ^(int row){
      [SharedAppDelegate() playTrackAtIndex:row];
    };
    self.onCellValue = ^id(int row, NSTableColumn *tableColumn) {
      Track *t = [weakSelf.tracks get:row];
      NSString *ident = tableColumn.identifier;
      bool isPlaying = [SharedAppDelegate().track isEqual:t];
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
      [self.library each:^(Track *t) {
        [tracks_ addObject:t];
      }];
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
  }
  return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
  if (context == kOnSortDescriptorsChanged) {
    self.tracks.comparator = GetComparatorFromSortDescriptors(self.tableView.sortDescriptors);
  } else {
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
  }
}

- (void)onTrackChange:(NSNotification *)notification {
  NSString *change = [notification.userInfo valueForKey:@"change"];
  Track *t = [notification.userInfo valueForKey:@"track"];
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
  [library_ release];
  [playingFont_ release];
  [font_ release];
  [emptyImage_ release];
  [playImage_ release];
  [tracks_ release];
  [super dealloc];
}
@end
