#import "AppDelegate.h"
#import "movie.h"
#import "MD1Slider.h"
#include <locale>

static NSSize kStartupSize = {1100, 600};
static NSString *kAlbum = @"album";
static NSString *kArtist = @"artist";
static NSString *kGenre = @"genre";
static NSString *kNextButton = @"NextButton";
static NSString *kPath = @"path";
static NSString *kPlayButton = @"PlayButton";
static NSString *kPreviousButton = @"PreviousButton";
static NSString *kProgressControl = @"ProgressControl";
static NSString *kSearchControl = @"SearchControl";
static NSString *kStatus = @"status";
static NSString *kTitle = @"title";
static NSString *kTrackNumber = @"track_number";
static NSString *kVolumeControl = @"VolumeControl";
static NSString *kYear = @"year";

using namespace std;
using namespace std::tr1;

static NSString *FormatSeconds(double seconds); 
static NSString *GetString(const string &s);
static bool Contains(string &haystack, string &needle);
static bool IsTrackMatchAllTerms(Track *t, vector<string> &terms);
static void HandleMovieEvent(void *ctx, MovieEvent e, void *data);

static NSString *GetString(const string &s) {
  return [NSString stringWithUTF8String:s.c_str()];
}

static bool Contains(const string &haystack, const string &needle) {
  return strcasestr(haystack.c_str(), needle.c_str()) != NULL;
}

static bool IsTrackMatchAllTerms(Track *t, vector<string> &terms) { 
  bool ret = true;
  for (vector<string>::iterator i = terms.begin(); i < terms.end(); i++) {
    string token = *i;
    if (!(Contains(t->artist(), token)
        || Contains(t->album(), token)
        || Contains(t->title(), token)
        || Contains(t->path(), token))) {
      return false;
    }
  }
  return true;
}

static NSString *FormatSeconds(double seconds) { 
  int hours = seconds / (60 * 60);
  seconds -= hours * 60 * 60;
  int minutes = seconds / 60;
  seconds -= minutes * 60;
  if (hours > 0)
    return [NSString stringWithFormat:@"%02d:%02d:%02d", hours, minutes, seconds];
  else
    return [NSString stringWithFormat:@"%02d:%02d", minutes, (int)seconds];
}

void HandleMovieEvent(void *ctx, Movie *m, MovieEvent e, void *data) { 
  AppDelegate *a = (AppDelegate *)ctx;
  [a handleMovie:m event:e data:data];
}

@implementation AppDelegate
@synthesize searchQuery = searchQuery_;

- (void)dealloc { 
  NSLog(@"dealloc");
  [contentView_ dealloc];
  [mainWindow_ dealloc];
  [super dealloc];
}

- (void)refresh { 
  @synchronized (self) { 
    allTracks_ = library_->GetAll();
  }
  [trackTableView_ reloadData];
}


- (void)applicationDidFinishLaunching:(NSNotification *)n {
  MovieInit();
  NSApplication *sharedApp = [NSApplication sharedApplication];
  library_.reset(new Library());
  library_->Open("/Users/bran/.md1.db");
  tracks_.reset(new vector<shared_ptr<Track> >());
  movie_.reset();
  seekToRow_ = -1;
  needsReload_ = NO;

  std::vector<std::string> pathsToScan;
  pathsToScan.push_back("/Users/bran/Music/rsynced");
  //library_->Scan(pathsToScan, false);
  mainWindow_ = [[NSWindow alloc] 
    initWithContentRect:NSMakeRect(150, 150, kStartupSize.width, kStartupSize.height)
    styleMask:NSClosableWindowMask | NSTitledWindowMask | NSResizableWindowMask
    | NSMiniaturizableWindowMask | NSTexturedBackgroundWindowMask
    backing:NSBackingStoreBuffered
    defer:NO];
  [mainWindow_ setAutorecalculatesKeyViewLoop:YES];
  contentView_ = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, kStartupSize.width, kStartupSize.height)];
  contentView_.autoresizesSubviews = YES;
  contentView_.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  [mainWindow_ setContentView:contentView_];
  
  [mainWindow_ setContentBorderThickness:22 forEdge:NSMaxYEdge];
  mainWindow_.title = @"MD1";
  [mainWindow_ display];
  [mainWindow_ makeKeyAndOrderFront:self];
  
  trackTableFont_ = [[NSFont systemFontOfSize:11.0] retain];
  trackTablePlayingFont_ = [[NSFont boldSystemFontOfSize:11.0] retain];

  trackTableScrollView_ = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 22, kStartupSize.width, kStartupSize.height)];
  trackTableView_ = [[NSTableView alloc] initWithFrame:NSMakeRect(0, 0, 364, 200)];
  // create columns for our table
  [trackTableView_ setUsesAlternatingRowBackgroundColors:YES];
  [trackTableView_ setGridStyleMask:NSTableViewSolidVerticalGridLineMask];

  NSTableColumn * statusColumn = [[[NSTableColumn alloc] initWithIdentifier:kStatus] autorelease];
  NSTableColumn * artistColumn = [[[NSTableColumn alloc] initWithIdentifier:kArtist] autorelease];
  NSTableColumn * albumColumn = [[[NSTableColumn alloc] initWithIdentifier:kAlbum] autorelease];
  NSTableColumn * titleColumn = [[[NSTableColumn alloc] initWithIdentifier:kTitle] autorelease];
  NSTableColumn * trackNumberColumn = [[[NSTableColumn alloc] initWithIdentifier:kTrackNumber] autorelease];
  NSTableColumn * genreColumn = [[[NSTableColumn alloc] initWithIdentifier:kGenre] autorelease];
  NSTableColumn * yearColumn = [[[NSTableColumn alloc] initWithIdentifier:kYear] autorelease];
  NSTableColumn * pathColumn = [[[NSTableColumn alloc] initWithIdentifier:kPath] autorelease];
   
  emptyImage_ = [[NSImage alloc] initWithSize:NSMakeSize(22, 22)];
  playImage_ = [[NSImage imageNamed:@"NSRightFacingTriangleTemplate"] retain];
  [statusColumn setDataCell:[[NSImageCell alloc] initImageCell:emptyImage_]];
  [statusColumn setWidth:30];
  [statusColumn setMaxWidth:30];
  [artistColumn setWidth:252];
  [albumColumn setWidth:252];
  [titleColumn setWidth:252];
  [trackNumberColumn setWidth:50];
  [genreColumn setWidth:252];
  [yearColumn setWidth:252];
  [pathColumn setWidth:1000];

  [[statusColumn headerCell] setStringValue:@""];
  [[artistColumn headerCell] setStringValue:@"Artist"];
  [[artistColumn headerCell] setFont:[NSFont boldSystemFontOfSize:11.0]];
  [[artistColumn headerCell] setFont:[NSFont boldSystemFontOfSize:11.0]];
  [[albumColumn headerCell] setStringValue:@"Album"];
  [[albumColumn headerCell] setFont:[NSFont boldSystemFontOfSize:11.0]];
  [[titleColumn headerCell] setStringValue:@"Title"];
  [[titleColumn headerCell] setFont:[NSFont boldSystemFontOfSize:11.0]];
  [[yearColumn headerCell] setStringValue:@"Year"];
  [[yearColumn headerCell] setFont:[NSFont boldSystemFontOfSize:11.0]];
  [[genreColumn headerCell] setStringValue:@"Genre"];
  [[genreColumn headerCell] setFont:[NSFont boldSystemFontOfSize:11.0]];
  [[trackNumberColumn headerCell] setStringValue:@"#"];
  [[trackNumberColumn headerCell] setFont:[NSFont boldSystemFontOfSize:11.0]];
  [[pathColumn headerCell] setStringValue:@"Path"];
  [[pathColumn headerCell] setFont:[NSFont boldSystemFontOfSize:11.0]];

  [[artistColumn dataCell] setFont:[NSFont systemFontOfSize:11.0]];
  [[albumColumn dataCell] setFont:[NSFont systemFontOfSize:11.0]];
  [[titleColumn dataCell] setFont:[NSFont systemFontOfSize:11.0]];
  [[genreColumn dataCell] setFont:[NSFont systemFontOfSize:11.0]];
  [[yearColumn dataCell] setFont:[NSFont systemFontOfSize:11.0]];
  [[pathColumn dataCell] setFont:[NSFont systemFontOfSize:11.0]];
  [[trackNumberColumn dataCell] setFont:[NSFont systemFontOfSize:11.0]];

  [trackTableView_ addTableColumn:statusColumn];
  [trackTableView_ addTableColumn:trackNumberColumn];
  [trackTableView_ addTableColumn:titleColumn];
  [trackTableView_ addTableColumn:artistColumn];
  [trackTableView_ addTableColumn:albumColumn];
  [trackTableView_ addTableColumn:genreColumn];
  [trackTableView_ addTableColumn:yearColumn];
  [trackTableView_ addTableColumn:pathColumn];
  [trackTableView_ setDelegate:self];
  [trackTableView_ setDataSource:self];
  [trackTableView_ reloadData];
  // embed the table view in the scroll view, and add the scroll view
  // to our window.
  [trackTableScrollView_ setDocumentView:trackTableView_];
  [trackTableScrollView_ setHasVerticalScroller:YES];
  [trackTableScrollView_ setHasHorizontalScroller:YES];
  trackTableScrollView_.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

  [trackTableView_ setDoubleAction:@selector(trackTableDoubleClicked:)];
  [trackTableView_ setTarget:self];
  [mainWindow_ setContentView:trackTableScrollView_];
  [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
  pollMovieTimer_ = [NSTimer scheduledTimerWithTimeInterval:.15 target:self selector:@selector(onPollMovieTimer:) userInfo:nil repeats:YES];
  pollLibraryTimer_ = [NSTimer scheduledTimerWithTimeInterval:10.0 target:self selector:@selector(onPollLibraryTimer:) userInfo:nil repeats:YES];
  
  // Setup the toolbar items and the toolbar.
  playButton_ = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 60, 22)];
  [playButton_ setTarget:self];
  [playButton_ setTitle:@"Play"];
  [playButton_ setAction:@selector(playClicked:)];
  playButtonItem_ = [[NSToolbarItem alloc] initWithItemIdentifier:kPlayButton];
  [playButtonItem_ setEnabled:YES];
  [playButtonItem_ setView:playButton_];
 
  nextButton_ = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 60, 22)];
  [nextButton_ setTarget:self];
  [nextButton_ setTitle:@"Next"];
  [nextButton_ setAction:@selector(nextClicked:)];
  nextButtonItem_ = [[NSToolbarItem alloc] initWithItemIdentifier:kNextButton];
  [nextButtonItem_ setEnabled:YES];
  [nextButtonItem_ setView:nextButton_];

  // Previous button
  previousButton_ = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 60, 22)];
  [previousButton_ setTarget:self];
  [previousButton_ setTitle:@"Previous"];
  [previousButton_ setAction:@selector(previousClicked:)];
  previousButtonItem_ = [[NSToolbarItem alloc] initWithItemIdentifier:kPreviousButton];
  [previousButtonItem_ setEnabled:YES];
  [previousButtonItem_ setView:previousButton_];

  // Volume
  volumeSlider_ = [[MD1Slider alloc] initWithFrame:NSMakeRect(0, 0, 100, 22)];
  [volumeSlider_ setContinuous:YES];
  [volumeSlider_ setTarget:self];
  [volumeSlider_ setAction:@selector(volumeClicked:)];
  volumeSlider_.autoresizingMask = 0;
  [[volumeSlider_ cell] setControlSize: NSSmallControlSize];
  [volumeSlider_ setMaxValue:1.0];
  [volumeSlider_ setMinValue:0.0];
  [volumeSlider_ setDoubleValue:0.5];
  volumeItem_ = [[NSToolbarItem alloc] initWithItemIdentifier:kVolumeControl];
  [volumeItem_ setView:volumeSlider_];

  NSView *progressControl = [[NSView alloc] 
    initWithFrame:NSMakeRect(0, 0, 5 + 60 + 5 + 300 + 5 + + 60 + 5, 22)];
  // Progress Bar
  progressSlider_ = [[MD1Slider alloc] initWithFrame:NSMakeRect(5 + 60 + 5, 0, 300, 22)];
  [progressSlider_ setContinuous:YES];
  [progressSlider_ setTarget:self];
  [progressSlider_ setAction:@selector(progressClicked:)];
  progressSlider_.autoresizingMask = NSViewWidthSizable;
  [[progressSlider_ cell] setControlSize: NSSmallControlSize];
  [progressSlider_ setMaxValue:1.0];
  [progressSlider_ setMinValue:0.0];
  [progressSlider_ setDoubleValue:0.0];

  elapsedText_ = [[NSTextField alloc] initWithFrame:NSMakeRect(5, 3, 60, 15)];
  elapsedText_.font = [NSFont systemFontOfSize:9.0];
  elapsedText_.stringValue = @"";
  elapsedText_.autoresizingMask = NSViewMaxXMargin;
  elapsedText_.alignment = NSRightTextAlignment;
  [elapsedText_ setDrawsBackground: NO];
  [elapsedText_ setEditable: NO];
  [elapsedText_ setBordered:NO];
  [progressControl addSubview:elapsedText_];

  durationText_ = [[NSTextField alloc] initWithFrame:NSMakeRect(5 + 60 + 5 + 300 + 5, 3, 60, 15)];
  durationText_.font = [NSFont systemFontOfSize:9.0];
  durationText_.stringValue = @"";
  durationText_.autoresizingMask = NSViewMinXMargin;
  durationText_.alignment = NSLeftTextAlignment;
  [durationText_ setDrawsBackground: NO];
  [durationText_ setBordered:NO];
  [durationText_ setEditable: NO];
  [progressControl addSubview:durationText_];

  [progressControl addSubview:progressSlider_];
  progressControl.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable;
  progressSliderItem_ = [[NSToolbarItem alloc] initWithItemIdentifier:kProgressControl];
  [progressSliderItem_ setEnabled:YES];
  [progressSliderItem_ setView:progressControl];

  [[NSNotificationCenter defaultCenter] 
    addObserver:self selector:@selector(progressSliderIsUp:) name:kSliderIsUpNotification object:nil];

  [progressSliderItem_ setMaxSize:NSMakeSize(1000, 22)];
  [progressSliderItem_ setMinSize:NSMakeSize(400, 22)];

  searchField_ = [[NSSearchField alloc] initWithFrame:NSMakeRect(0, 0, 100, 22)];
  searchField_.font = [NSFont systemFontOfSize:12.0];
  searchField_.autoresizingMask = NSViewMinXMargin;
  searchField_.target = self;
  searchField_.action = @selector(onSearch:);

  [searchField_ setRecentsAutosaveName:@"recentSearches"];

  searchItem_ = [[NSToolbarItem alloc] initWithItemIdentifier:kSearchControl];
  [searchItem_ setView:searchField_];

  toolbar_ = [[NSToolbar alloc] initWithIdentifier:@"md1toolbar"];
  [toolbar_ setDelegate:self];
  [toolbar_ setDisplayMode:NSToolbarDisplayModeIconOnly];
  [toolbar_ insertItemWithItemIdentifier:kPlayButton atIndex:0];
  [mainWindow_ setToolbar:toolbar_];
  predicateChanged_ = YES;
  [self refresh];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag {
  NSLog(@"get toolbar item: %@", itemIdentifier);  
  if (itemIdentifier == kPlayButton) { 
    return playButtonItem_;  
  } else if (itemIdentifier == kProgressControl) { 
    return progressSliderItem_;
  } else if (itemIdentifier == kVolumeControl) { 
    return volumeItem_;
  } else if (itemIdentifier == kSearchControl) { 
    return searchItem_;
  } else if (itemIdentifier == kPreviousButton) { 
    return previousButtonItem_;
  } else if (itemIdentifier == kNextButton)  {
    return nextButtonItem_;
  }
  return nil;
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
  return [NSArray arrayWithObjects:kPreviousButton, kPlayButton, kNextButton, kVolumeControl, kProgressControl, kSearchControl, nil];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar { 
  return [NSArray arrayWithObjects:kPreviousButton, kPlayButton, kNextButton, kVolumeControl, kProgressControl, kSearchControl, nil];
}

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar {
  return [NSArray array];
}

- (void)toolbarWillAddItem:(NSNotification *)notification {

}

- (void)toolbarWillRemoveItem:(NSNotification *)notification {
}

- (void)executeSearch { 
  NSArray *parts = [searchQuery_ componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  NSLog(@"search for %@", parts);
  vector<string> parts0;
  if (parts) {
    for (NSString *p in parts) {
      string s = p.UTF8String; 
      if (s.length() > 0)
        parts0.push_back(s); 
    }
  }
  shared_ptr<vector<shared_ptr<Track> > > filteredTracks(new vector<shared_ptr<Track > >);
  for (vector<shared_ptr<Track> >::iterator i = allTracks_->begin();   
      i < allTracks_->end(); 
      i++) {
    shared_ptr<Track> t = *i;  
    if (parts0.size() == 0 || IsTrackMatchAllTerms(t.get(), parts0)) {
      filteredTracks->push_back(t);
    }
  }
  @synchronized(self) {
    tracks_ = filteredTracks;
    needsReload_ = YES;
  }
}

- (void)onSearch:(id)sender { 
  self.searchQuery = searchField_.stringValue;
  predicateChanged_ = YES;
  needsReload_ = YES;


  
}

- (void)volumeClicked:(id)sender { 
  if (movie_)
    movie_->SetVolume(volumeSlider_.doubleValue);
}

- (void)progressSliderIsUp:(NSNotification *)notification {
  if (movie_)
    movie_->Seek(progressSlider_.doubleValue * movie_->Duration());  
}

- (void)progressClicked:(id)sender { 
  if (movie_) {
    double duration = movie_->Duration();
    [self displayElapsed:(progressSlider_.doubleValue * duration) duration:duration];
  }
}

- (void)displayElapsed:(double)elapsed duration:(double)duration {
  [progressSlider_ setEnabled:YES];
  double pct = duration > 0 ? elapsed / duration : 0;
  durationText_.stringValue = FormatSeconds(duration);
  elapsedText_.stringValue = FormatSeconds(elapsed);
  if (![progressSlider_ isMouseDown] && !movie_->isSeeking())
    [progressSlider_ setDoubleValue:pct];
}

- (void)onPollMovieTimer:(id)sender { 
  if (track_ != NULL) {
    mainWindow_.title = [NSString stringWithUTF8String:track_->path().c_str()];
  } else { 
    mainWindow_.title = @"MD1";
  }
  if (movie_ != NULL) {
    if (![progressSlider_ isMouseDown] && !movie_->isSeeking()) { 
      double duration = movie_->Duration();
      double elapsed = movie_->Elapsed();
      [self displayElapsed:elapsed duration:duration];
    }
  } else { 
    [progressSlider_ setEnabled:NO];
    [progressSlider_ setDoubleValue:0];
    durationText_.stringValue = @"";
    elapsedText_.stringValue = @"";
  }

  if (predicateChanged_) {
    [self executeSearch];
    predicateChanged_ = NO;
  } 

  if (needsReload_) {
    [trackTableView_ reloadData];
    needsReload_ = NO;
  }

  if (seekToRow_ >= 0) {
    NSLog(@"seeking to row %d", seekToRow_);
    [trackTableView_ scrollRowToVisible:seekToRow_];
    seekToRow_ = -1;
  }

}

- (void)onPollLibraryTimer:(id)sender { 
  //[self refresh];
}

- (void)trackTableDoubleClicked:(id)sender { 
  int row = [trackTableView_ clickedRow];
  if (row >= 0 && row < tracks_->size()) {
    [self playTrackAtIndex:row];
  }
}

- (void)playTrackAtIndex:(int)index { 
  @synchronized(self) {
    if (index < 0)
      return;
    if (index >= tracks_->size())
      return;
    shared_ptr<Track> aTrack = tracks_->at(index);
    NSLog(@"play: %s", aTrack->path().c_str());
    if (movie_.get() != NULL) {
      NSLog(@"stopping previous movie");
      movie_->Stop();
    }
    track_ = aTrack;
    movie_.reset(new Movie(aTrack->path().c_str()));
    NSLog(@"playing new movie");
    movie_->Play();
    movie_->SetListener(HandleMovieEvent, self);
    movie_->SetVolume(volumeSlider_.doubleValue);
    needsReload_ = YES;
    seekToRow_ = index;
  }
}

- (void)handleMovie:(Movie *)movie event:(MovieEvent)event data:(void *)data {
  if (movie != movie_.get())
    return;
  switch (event) { 
    case kAudioFrameProcessedMovieEvent:
      break;
    case kRateChangeMovieEvent:
      break;
    case kEndedMovieEvent: 
      NSLog(@"movie ended event");
      [self playNextTrack];
      break;
    default:
      break;
  }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
  return tracks_->size();
}

/*
 * Play the next track.
 */
- (void)playNextTrack {
  int idx = 0;
  int found = -1;  
  if (track_) { 
    vector<shared_ptr<Track > > *ts = tracks_.get();
    for (vector<shared_ptr<Track> >::iterator i = ts->begin(); i < ts->end(); i++) {
       if (i->get()->path() == track_->path()) {
         found = idx;       
         break;
       }
       idx++;
    }
  } 
  if (found >= 0 && (found + 1) < tracks_->size()) {
    [self playTrackAtIndex:found + 1];
  }   
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
  shared_ptr<Track> t = (*tracks_)[rowIndex];
  NSString *identifier = aTableColumn.identifier;
  id result = nil;
  NSString *s = nil;
  bool isPlaying = (track_
        && movie_
        && movie_->state() == kPlayingMovieState
        && t->path() == track_->path());
  if (identifier == kArtist)
    s = GetString(t->artist());
  else if (identifier == kAlbum)
    s = GetString(t->album());
  else if (identifier == kGenre)
    s = GetString(t->genre());
  else if (identifier == kYear)
    s = GetString(t->year());
  else if (identifier == kTitle)
    s = GetString(t->title());
  else if (identifier == kTrackNumber)
    s = GetString(t->track_number());
  else if (identifier == kPath)
    s = GetString(t->path());
  else if (identifier == kStatus) {
    if (isPlaying)
      result = playImage_;
  }
  if (s) {
    result = s;
    [[aTableColumn dataCell] setFont:isPlaying ? trackTablePlayingFont_ : trackTableFont_];
  } else { 
     
  }
  return result;
}

- (void)playClicked:(id)sender { 
  NSLog(@"play clicked");
}

@end

