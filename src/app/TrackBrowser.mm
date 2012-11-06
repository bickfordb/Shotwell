#import "app/AppDelegate.h"
#import "app/Enum.h"
#import "app/Log.h"
#import "app/MicroSecondsToDate.h"
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

    NSTableColumn *statusColumn = [[[NSTableColumn alloc] initWithIdentifier:kStatus] autorelease];
    NSTableColumn *artistColumn = [[[NSTableColumn alloc] initWithIdentifier:kArtist] autorelease];
    [artistColumn bind:@"value" toObject:self.tracks withKeyPath:@"arrangedObjects.artist" options:nil];
    artistColumn.sortDescriptorPrototype = [NSSortDescriptor sortDescriptorWithKey:kArtist ascending:YES comparator:StandardComparison];
    NSTableColumn *albumColumn = [[[NSTableColumn alloc] initWithIdentifier:kAlbum] autorelease];
    [albumColumn bind:@"value" toObject:self.tracks withKeyPath:@"arrangedObjects.album"
      options:nil];
    albumColumn.sortDescriptorPrototype = [NSSortDescriptor sortDescriptorWithKey:kAlbum ascending:YES comparator:StandardComparison];

    NSTableColumn *titleColumn = [[[NSTableColumn alloc] initWithIdentifier:kTitle] autorelease];
    [titleColumn bind:@"value" toObject:self.tracks withKeyPath:@"arrangedObjects.title"
      options:nil];
    titleColumn.sortDescriptorPrototype = [NSSortDescriptor sortDescriptorWithKey:kTitle ascending:YES comparator:StandardComparison];

    NSTableColumn *trackNumberColumn = [[[NSTableColumn alloc] initWithIdentifier:kTrackNumber] autorelease];
    [trackNumberColumn bind:@"value" toObject:self.tracks withKeyPath:@"arrangedObjects.trackNumber"
      options:nil];
    trackNumberColumn.sortDescriptorPrototype = [NSSortDescriptor sortDescriptorWithKey:kTrackNumber ascending:YES comparator:StandardComparison];

    NSTableColumn *genreColumn = [[[NSTableColumn alloc] initWithIdentifier:kGenre] autorelease];
    [genreColumn bind:@"value" toObject:self.tracks withKeyPath:@"arrangedObjects.genre"
      options:nil];
    genreColumn.sortDescriptorPrototype = [NSSortDescriptor sortDescriptorWithKey:kGenre ascending:YES comparator:StandardComparison];


    NSTableColumn *durationColumn = [[[NSTableColumn alloc] initWithIdentifier:kDuration] autorelease];
    [durationColumn bind:@"value" toObject:self.tracks withKeyPath:@"arrangedObjects.duration.formatSeconds"
      options:nil];
    durationColumn.sortDescriptorPrototype = [NSSortDescriptor sortDescriptorWithKey:kDuration ascending:YES comparator:DefaultComparison];

    NSTableColumn *yearColumn = [[[NSTableColumn alloc] initWithIdentifier:kYear] autorelease];
    [yearColumn bind:@"value" toObject:self.tracks withKeyPath:@"arrangedObjects.year"
      options:nil];
    yearColumn.sortDescriptorPrototype = [NSSortDescriptor sortDescriptorWithKey:kYear ascending:YES comparator:StandardComparison];

    NSTableColumn *pathColumn = [[[NSTableColumn alloc] initWithIdentifier:kPath] autorelease];
    [pathColumn bind:@"value" toObject:self.tracks withKeyPath:@"arrangedObjects.path" options:nil];
    pathColumn.sortDescriptorPrototype = [NSSortDescriptor sortDescriptorWithKey:kPath ascending:YES comparator:StandardComparison];

    NSTableColumn *createdAtColumn = [[[NSTableColumn alloc] initWithIdentifier:kCreatedAt] autorelease];
    [createdAtColumn bind:@"value" toObject:self.tracks withKeyPath:@"arrangedObjects.createdAt"
      options:@{NSValueTransformerBindingOption: [[MicroSecondsToDate alloc] init]}];
    createdAtColumn.sortDescriptorPrototype = [NSSortDescriptor sortDescriptorWithKey:kCreatedAt ascending:YES comparator:DefaultComparison];

    NSTableColumn *updatedAtColumn = [[[NSTableColumn alloc] initWithIdentifier:kUpdatedAt] autorelease];
    [updatedAtColumn bind:@"value" toObject:self.tracks withKeyPath:@"arrangedObjects.updatedAt" options:@{NSValueTransformerBindingOption: [[MicroSecondsToDate alloc] init]}];
    updatedAtColumn.sortDescriptorPrototype = [NSSortDescriptor sortDescriptorWithKey:kUpdatedAt ascending:YES comparator:DefaultComparison];

    self.tableView.sortDescriptors = [NSArray arrayWithObjects:artistColumn.sortDescriptorPrototype, albumColumn.sortDescriptorPrototype, trackNumberColumn.sortDescriptorPrototype, titleColumn.sortDescriptorPrototype, pathColumn.sortDescriptorPrototype, nil];

    self.emptyImage = [[[NSImage alloc] initWithSize:NSMakeSize(22, 22)] autorelease];
    self.playImage = [NSImage imageNamed:@"dot"];
    [statusColumn setDataCell:[[[NSImageCell alloc] initImageCell:emptyImage_] autorelease]];
    [statusColumn setWidth:30];
    [statusColumn setMaxWidth:30];
    [artistColumn setWidth:180];
    [albumColumn setWidth:180];
    [titleColumn setWidth:252];
    [trackNumberColumn setWidth:50];
    [genreColumn setWidth:150];
    [yearColumn setWidth:50];
    [durationColumn setWidth:50];
    [pathColumn setWidth:1000];
    [updatedAtColumn setWidth:200];
    [createdAtColumn setWidth:200];

    [[statusColumn headerCell] setStringValue:@""];
    [[artistColumn headerCell] setStringValue:@"Artist"];
    [[albumColumn headerCell] setStringValue:@"Album"];
    [[titleColumn headerCell] setStringValue:@"Title"];
    [[yearColumn headerCell] setStringValue:@"Year"];
    [[genreColumn headerCell] setStringValue:@"Genre"];
    [[durationColumn headerCell] setStringValue:@"Duration"];
    [[trackNumberColumn headerCell] setStringValue:@"#"];
    [[pathColumn headerCell] setStringValue:@"URL"];
    [[createdAtColumn headerCell] setStringValue:@"Created"];
    [[updatedAtColumn headerCell] setStringValue:@"Updated"];

    [self.tableView addTableColumn:statusColumn];
    [self.tableView addTableColumn:trackNumberColumn];
    [self.tableView addTableColumn:titleColumn];
    [self.tableView addTableColumn:artistColumn];
    [self.tableView addTableColumn:albumColumn];
    [self.tableView addTableColumn:yearColumn];
    [self.tableView addTableColumn:durationColumn];
    [self.tableView addTableColumn:genreColumn];
    [self.tableView addTableColumn:pathColumn];
    [self.tableView addTableColumn:createdAtColumn];
    [self.tableView addTableColumn:updatedAtColumn];

    for (NSTableColumn *column in self.tableView.tableColumns) {
      NSCell *dataCell = [column dataCell];
      NSCell *headerCell = [column headerCell];
      [headerCell setFont:[NSFont boldSystemFontOfSize:kTrackFontSize]];
      if ([dataCell isKindOfClass:[NSTextFieldCell class]]) {
        [dataCell setFont:[NSFont systemFontOfSize:kTrackFontSize]];
      }
    }

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
