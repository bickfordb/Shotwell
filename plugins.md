Plugins
=======

Plugin Use Cases
----------------

* Display a vertical or horizontal pane with artist information, album information
* Notify a remote API on events.  For instance post to last.fm everytime you play a song.
* Show a history of recently played artists and albums
* Show a browser of years, artists and albums
* When a playing an album and "idling", switch to a view which looks like a vinyl record album back cover w/ track.  Guessing this can be automated by scraping album art from the iTunes API
  * Inspiration: http://www.behance.net/gallery/The-Visual-Mixtape/512579
  * Apple iTunes LP (cf http://www.apple.com/itunes/lp-and-extras/)
  * I'm not sure how to detect when one is playing an album.  Maybe this could occur for anything with cover art.
  * I suppose any fancy creative commons photography could take the place of the cover art when there is no cover art?

class Plugin {
  .show(flags, size) 
  .hide()
  .hideTrackTable()
  .showTrackTable()
  .http(request, on-response); // this will be unnecessary if XMLHTTPRequest is available
  .html() // set the HTML to this
  .nextTracks(num, offset) // get the next N tracks which will play.  by default offset is zero.
}

* I have been unable to decide whether to use dom windows or naked interpreter instances

