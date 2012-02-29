
#include "library.h"
#include "log.h"
#include <fts.h>
#include <google/protobuf/io/coded_stream.h>
#include <google/protobuf/io/zero_copy_stream_impl.h>
#include <stdio.h>
#include <pcre.h>
#include <pthread.h>
#include <tr1/tuple>

using namespace google::protobuf::io;
using namespace std;
using namespace std::tr1;

typedef tuple<Library *, vector<string> > ScanArgs;

static void *ScanPaths(void *ctx);
static void *ScanPaths(void *ctx) { 
  ScanArgs *args = (ScanArgs *)ctx;
  Library *library = get<0>(*args);
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
  pcre *media_pat = pcre_compile(
      "^.*(mp3|m4a|ogg|avi|mkv|aac|mov)$",
      0, 
      &error,
      &error_offset,
      0);
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
    //INFO("visit %s", node->fts_path);
    string filename(node->fts_path);
    int ovector[10];
    int pcre_ret = pcre_exec(media_pat,
        0,
        filename.c_str(),
        filename.length(),
        0,
        0,
        ovector,
        2);
    if (pcre_ret < 0) {
      //INFO("doesnt match regex");
      continue;
    }
    Track t;
    t.set_path(filename);
    if (library->Get(filename, &t) != 0) {
      ReadTag(&t);
      //INFO("saving %p, %s", library, filename.c_str());
      library->Save(t);
    }
  }
  if (fts_close(tree)) {
    return NULL;
  }
  return NULL;
}

Library::Library() {
  db_ = NULL;
}

Library::~Library() { 
  if (db_ != NULL) { 
    delete db_;
    db_ = NULL;
  }
}

int Library::Open(const std::string &path) { 
  leveldb::Options opts;
  opts.create_if_missing = true;
  opts.error_if_exists = false;
  leveldb::Status st = leveldb::DB::Open(opts, path.c_str(), &db_);
  return st.ok() ? 0 : -1;
}

int Library::Close() { 
  if (db_ != NULL) {
    delete db_;
    db_ = NULL;
  }
}

int Library::Get(const std::string &path, Track *t) {
  std::string val;
  leveldb::Status st = db_->Get(leveldb::ReadOptions(), path, &val);
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

int Library::Save(const Track &t) { 
  if (t.path().length() == 0)
    return -1;
  leveldb::Status st = db_->Put(leveldb::WriteOptions(), t.path(), t.SerializePartialAsString());
  return st.ok() ? 0 : -1;
}

int Library::Clear() {
  leveldb::Iterator *i = db_->NewIterator(leveldb::ReadOptions());
  i->SeekToFirst();
  while (i->Valid()) {
    db_->Delete(leveldb::WriteOptions(), i->key());
    i->Next();
  }
  return 0;
}

int Library::Count() { 
  int total = 0;
  leveldb::Iterator *i = db_->NewIterator(leveldb::ReadOptions());
  i->SeekToFirst();
  while (i->Valid()) {
    db_->Delete(leveldb::WriteOptions(), i->key());
    i->Next();
    total++;
  }
  return total;
}

shared_ptr<vector<shared_ptr<Track> > > Library::GetAll() { 
  shared_ptr<vector<shared_ptr<Track> > > result(new vector<shared_ptr<Track> >);  
  leveldb::Iterator *i = db_->NewIterator(leveldb::ReadOptions());
  i->SeekToFirst();
  for (;;) {
    if (!i->Valid()) 
      break;
    string key = i->key().ToString();
    string val = i->value().ToString();
    shared_ptr<Track> t(new Track());
    if (t->ParsePartialFromString(val)) 
      result->push_back(t);
    i->Next();
  }
  return result;
}

void Library::Scan(vector<string> scan_paths, bool sync) { 
  pthread_t thread_id;
  memset(&thread_id, 0, sizeof(thread_id));
  void *args = (void *)(new ScanArgs(this, scan_paths));
  if (sync)
    ScanPaths(args);
  else
    pthread_create(&thread_id, NULL, ScanPaths, args);
}

