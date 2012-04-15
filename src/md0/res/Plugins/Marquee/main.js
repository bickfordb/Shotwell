playing = null;

var builtinWallpapers = [
  "file:///Library/Desktop%20Pictures/Nature/Tahoe.jpg",
  "file:///Library/Desktop%20Pictures/Nature/Summit.jpg"
];

function onTrackStarted(track) {
  window.playing = track;
  plugin.showSize_isVertical_(300, true); 
  renderPlaying(); 
}

function onTrackEnded(track) { 
  plugin.hide();
}

function onTrackSaved(track) { 
  if (playing && playing.id() == track.id()) {
    window.playing = track;
    renderPlaying();
  }
}

function renderPlaying() { 
  if (playing) {
    $("p.artist").html(playing.artist());
    $("p.album").html(playing.album());
    $("p.title").html(playing.title());
    $("p.year").html(playing.year());
    $("p.genre").html(playing.genre());
    $("p.url").html(playing.url());
    var coverArtURL = playing.coverArtURL();
    var i = 0;
    if (!coverArtURL) {
      coverArtURL = builtinWallpapers[i];
    }
    $("body").css("background-image", "url(" + coverArtURL + ")");
    var w = $("body").width();
    var h = $("body").height();
    if (w < h) 
      w = h;
    if (h < w)
      h = w;
    $("body").css("background-size", "" + w + "px " + h  +"px");

  }
}

function search(s) { 
  plugin.log_("Search: " + s);
  plugin.controller().search_(s);
}

$(function() {
  $("p.track-field").click(function() {
    var el = this;
    search($(el).text());
    return false;
  });
  
})
