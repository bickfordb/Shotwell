var kSize = 300;

playing = null;

function onTrackStarted(track) {
  window.playing = track;
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
    if (plugin.hidden()) {
      plugin.showSize_isVertical_(kSize, true); 
    }
  } else { 
    plugin.hide();
    return;
  }
  $("div.artist").html(playing.artist());
  $("div.album").html(playing.album());
  $("div.title").html(playing.title());
  $("div.year").html(playing.year());
  $("div.genre").html(playing.genre());
  $("div.url").html(playing.url().absoluteString());
  var url = playing.coverArtURL();
  if (url && url.length > 0) {
    $("img.cover-art").show().attr("src", playing.coverArtURL());
    $("div.cover-art-container").show();
  } else {
    $("div.cover-art-container").hide();
  }
  updateSize();
  $("div.artist-info").html("");
  runSearch();
}

function runSearch() { 
  query = "+artist:\"" + playing.artist() + "\" +release:\"" + playing.album() + "\"";
  $.ajax({
      url: "http://musicbrainz.org/ws/2/release",
      data: {query: query},
      success: function(doc) {
        if (!doc)
          return;
        var releases = doc.getElementsByTagName("release");
        if (!releases || !releases.length) 
          return;
        var release = releases[0];
        var artists = release.getElementsByTagName("artist");
        if (!artists)
          return;
        fillArtistInfo(artists[0].getAttribute("id"));
      }
  });
}

function fillArtistInfo(artistID) {
  if (!artistID)
    return;

  $.ajax({
    url: "http://musicbrainz.org/ws/2/artist/" + artistID,
    data: {inc: "url-rels"},
    success: function(doc) {
      console.log("artist urls");
      console.log(doc);
      if (!doc)
        return;
      var relations = doc.getElementsByTagName("relation");
      if (!relations || !relations.length)
        return;
      $("div.artist-info").append($("<br />"));
      $("div.artist-info").append("<p>On the web:</p>");
      var ul = $("<dl class=\"dl-horizontal\" />");
      for (var i = 0; i < relations.length; i++) {
        var relation = relations[i];
        var type = relation.getAttribute("type");
        var link = $("<a />");
        var target = $(relation).find("target").text();
        if (!type || !target)
          continue;
        link.attr("url", target);
        link.attr("href", "#");
        link.click(onURLClick);
        link.text(target);
        var item = $("<li />");
        item.append(link);
        ul.append($("<dt />").text(type));
        ul.append($("<dd />").append(link));
      }
      $("div.artist-info").append(ul);
    }
  });
}

function onURLClick() {
  var url = $(this).attr("url");
  if (url)
    plugin.openBrowser_(url);
  return false;  
}

function updateSize() {
  var w = window.innerWidth;
  var h = window.innerHeight;
  var imgWidth = 0;
  var imgHeight = 0;
  if (playing && playing.coverArtURL()) { 
    imgWidth = Math.min(w, h);
    imgHeight = Math.min(w, h);
  }
  $("img.cover-art").width(imgWidth);
  $("img.cover-art").height(imgHeight);
  $("div.track-info-container").height(h);
  $("div.track-info-container").width(w);

}

function search(s) { 
  if (s)
    plugin.controller().search_(s + "");
}

$(function() {
  $("div.track-field").click(function() {
    var el = this;
    search($(el).text());
    return false;
  });
  $(window).resize(updateSize);
})

