
#include <errno.h>
#include <fts.h>
#include <google/protobuf/io/coded_stream.h>
#include <google/protobuf/io/zero_copy_stream_impl.h>
#include <pcre.h>
#include <pthread.h>
#include <stdio.h>
#include <sys/stat.h>
#include <tr1/tuple>
#include <pcrecpp.h>
#include <leveldb/slice.h>

#include "md0/lib/local_library.h"
#include "md0/lib/log.h"

using namespace google::protobuf::io;
using namespace std;
using namespace std::tr1;

namespace md0 { 
typedef tuple<LocalLibrary *, vector<string> > ScanArgs;

static void *ScanPaths(void *ctx);
static void *RunPrune(void *ctx);
bool IsTrackKey(const string &key);

const char *kTrackPrefix = "t:";
const char *kScanPathPrefix = "p:";

static void *RunPrune(void *ctx) { 
  ((LocalLibrary *)ctx)->RunPruneThread(); 
  return NULL;
}

static void *ScanPaths(void *ctx) { 
  ScanArgs *args = (ScanArgs *)ctx;
  LocalLibrary *library = get<0>(*args);
  INFO("scanning");
  vector<string> scan_paths = get<1>(*args);
  delete args;
  char *scan_paths0[scan_paths.size() + 1];
  int idx = 0;
  for (vector<string>::iterator i = scan_paths.begin(); i < scan_paths.end(); i++) {
    const char *s = i->c_str();
    scan_paths0[idx] = (char *)s;
    idx++;
  }
  scan_paths0[idx] = NULL;
  FTS *tree = fts_open(scan_paths0, FTS_NOCHDIR, 0);
  if (tree == NULL)
    return NULL;
  FTSENT *node = NULL;
  const char *error = NULL;
  int error_offset = 0;
  pcrecpp::RE media_pat("^.*[.](?:mp3|m4a|ogg|avi|mkv|aac|mov)$");
  if (error != NULL) {
    ERROR("pcre error: %s", error);
    return NULL;
  }
  while (tree && (node = fts_read(tree))) {
    if (node->fts_level > 0 && node->fts_name[0] == '.') {
      fts_set(tree, node, FTS_SKIP);
      continue;
    }
    if (!(node->fts_info & FTS_F)) 
      continue;
    string filename(node->fts_path);
    if (!media_pat.FullMatch(filename))
      continue;
    Track t;
    if (library->Get(filename, &t) != 0) {
      t.ReadTag(filename);
      library->Save(t);
    }
  }
  if (fts_close(tree)) {
    return NULL;
  }
  return NULL;
}

LocalLibrary::LocalLibrary() {
  db_ = NULL;
  prune_thread_ = NULL;
  last_update_ = 0;
}

long double LocalLibrary::last_update() { 
  return last_update_;
}

void LocalLibrary::MarkUpdated() { 
  struct timeval t;
  gettimeofday(&t, NULL);
  last_update_ = t.tv_sec + (t.tv_usec / 1000000.0);
}

void LocalLibrary::RunPruneThread() {
  leveldb::Iterator *i = db_->NewIterator(leveldb::ReadOptions());
  i->SeekToFirst();
  while (i->Valid()) {
    struct stat the_status;
    string path = i->key().ToString();
    if (IsTrackKey(path)) {
      Track t;
      // prune unparseable
      if (!t.ParsePartialFromString(i->value().ToString())) {
        db_->Delete(leveldb::WriteOptions(), i->key());
        MarkUpdated(); 
      } else { 
        string path = t.path();
        if (stat(path.c_str(), &the_status) < 0 && errno == ENOENT) {
          INFO("Removing %s", path.c_str());
          db_->Delete(leveldb::WriteOptions(), i->key());
          MarkUpdated(); 
        }
      }
    }
    i->Next();
  }
}

void LocalLibrary::Prune() { 
  if (!prune_thread_)
    pthread_create(&prune_thread_, NULL, RunPrune, this);
}

LocalLibrary::~LocalLibrary() { 
  pthread_cancel(prune_thread_);
  if (db_ != NULL) { 
    delete db_;
    db_ = NULL;
  }
}

int LocalLibrary::Open(const std::string &path) { 
  leveldb::Options opts;
  opts.create_if_missing = true;
  opts.error_if_exists = false;
  leveldb::Status st = leveldb::DB::Open(opts, path.c_str(), &db_);
  MarkUpdated();
  return st.ok() ? 0 : -1;
}

int LocalLibrary::Close() { 
  if (db_ != NULL) {
    delete db_;
    db_ = NULL;
  }
  return 0;
}

int LocalLibrary::Get(const std::string &path, Track *t) {
  std::string val;
  string key(kTrackPrefix);
  key += path;
  leveldb::Status st = db_->Get(leveldb::ReadOptions(), key, &val);
  if (!st.ok()) 
    return -2;
  if (st.IsNotFound()) 
    return -1;
  if (t->ParsePartialFromString(val)) { 
    return 0;
  } else { 
    return -3;
  }
}

int LocalLibrary::Save(const Track &t) { 
  if (t.path().length() == 0)
    return -1;
  string key(kTrackPrefix); 
  key += t.path();
  leveldb::Status st = db_->Put(leveldb::WriteOptions(), key, t.SerializePartialAsString());
  MarkUpdated();
  return st.ok() ? 0 : -1;
}

bool IsTrackKey(const string &key) {
  return key.find(kTrackPrefix, 0) == 0;
}

int LocalLibrary::Clear() {
  leveldb::Iterator *i = db_->NewIterator(leveldb::ReadOptions());
  i->SeekToFirst();
  while (i->Valid()) { 
    string key = i->key().ToString();
    if (IsTrackKey(key)) {
      db_->Delete(leveldb::WriteOptions(), i->key());
      MarkUpdated();
    }
    i->Next();
  }
  return 0;
}

int LocalLibrary::Delete(const string &path) {
  string key(kTrackPrefix);
  key += path;
  leveldb::Slice s(key);
  db_->Delete(leveldb::WriteOptions(), s);
  MarkUpdated();
  return 0;
}

int LocalLibrary::Count() { 
  int total = 0;
  leveldb::Iterator *i = db_->NewIterator(leveldb::ReadOptions());
  i->SeekToFirst();
  while (i->Valid()) {
    if (IsTrackKey(i->key().ToString())) {
      i->Next();
      total++;
    }
  }
  return total;
}

void LocalLibrary::GetAll(vector<Track> *result) { 
  leveldb::Iterator *i = db_->NewIterator(leveldb::ReadOptions());
  i->SeekToFirst();
  while (i->Valid()) {
    if (IsTrackKey(i->key().ToString())) {
      string val = i->value().ToString();
      Track t;
      if (t.ParsePartialFromString(val)) 
        result->push_back(t);
    }
    i->Next();
  }
}

void LocalLibrary::Scan(vector<string> scan_paths, bool sync) { 
  pthread_t thread_id;
  memset(&thread_id, 0, sizeof(thread_id));
  void *args = (void *)(new ScanArgs(this, scan_paths));
  if (sync)
    ScanPaths(args);
  else
    pthread_create(&thread_id, NULL, ScanPaths, args);
}
}
