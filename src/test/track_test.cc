

#include <limits.h>
#include "gtest/gtest.h"
#include "track.h"
#include "av.h"
#include "library.h"
#include <tr1/memory>

using namespace std;
using namespace std::tr1;

TEST(TrackTest, General) {
  Track *track = new Track();
  track->set_artist("Something");
  track->set_album("Album");
  track->set_title("Title");
  track->set_year("Year");
  track->set_genre("Genre");
  track->set_created_at(1);
  track->set_updated_at(2);

  ASSERT_EQ(track->artist(), "Something");
  ASSERT_EQ(track->album(), "Album");
  ASSERT_EQ(track->title(), "Title");
  ASSERT_EQ(track->year(), "Year");
  ASSERT_EQ(track->genre(), "Genre");
  ASSERT_EQ(track->created_at(), 1);
  ASSERT_EQ(track->updated_at(), 2);

  track->set_path("/foo.mp3");
  ASSERT_EQ(track->path(), "/foo.mp3");
}

TEST(TrackTest, Tag) {
  AVInit();
  Track track;
  track.set_path("./test-data/x.mp3");  
  int ret = ReadTag(&track);
  ASSERT_EQ(ret, 0);
  ASSERT_EQ(track.artist(), "The Dodos");
}

TEST(TrackTest, GetAll) { 
  system("rm -rf getall.db");
  Library *library = new Library();
  ASSERT_EQ(library->Open("getall.db"), 0);
  Track t;
  t.set_path("/efg");
  library->Save(t);
  shared_ptr<vector<shared_ptr<Track> > > tracks = library.GetAll();
  
  ASSERT_EQ(tracks->length(), 0);
  ASSERT_EQ(tracks.size(), 1);
  delete library;
  system("rm -rf getall.db");
}

TEST(TrackTest, Clear) { 
  Library *library = new Library();
  Track t;
  t.set_path("/efg");
  system("rm -rf clear.db");
  library->Open("clear.db");
  library->Save(t);
  ASSERT_EQ(library->Count(), 1);
  library->Clear();
  ASSERT_EQ(library->Count(), 0);
  delete library;
  system("rm -rf clear.db");
}

TEST(TrackTest, DB) { 
  Library *library = new Library();
  system("rm -rf get-save.db");
  ASSERT_EQ(library->Open("get-save.db"), 0);
  Track t;
  t.set_path("/abc");
  ASSERT_EQ(library->Save(t), 0);
  Track t0;
  ASSERT_EQ(library->Get("/abc", &t0), 0);
  delete library;
  system("rm -rf get-save.db");
}

TEST(TrackTest, Scan) {
  Library *library = new Library();
  system("rm -rf scan.db");
  library->Open("scan.db");
  std::vector<std::string> ps;
  ps.push_back("test-data");
  library->Scan(ps, true);
  ASSERT_EQ(library->Count(), 1);
  delete library;
  system("rm -rf scan.db");
}

