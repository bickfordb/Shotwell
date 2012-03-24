#ifndef _LOCAL_LIBRARY_H
#define _LOCAL_LIBRARY_H

#include <vector>
#include "md0/lib/library.h"
#include <leveldb/db.h>
#include <sys/time.h>

using namespace std;

namespace md0 { 

class LocalLibrary : public md0::Library { 
  private:
    leveldb::DB *db_;
    pthread_t prune_thread_;
    long double last_update_;
    void MarkUpdated();
    uint32_t NextID();
    // 0 -> missing
    uint32_t GetURLIndex(const string &url);
    void PutURLIndex(const string &url, uint32_t id);
    static string GetIDKey(uint32_t id);
    static string GetURLKey(const string &url);
    static void *ScanPathsCallback(void *);
  public: 
    long double last_update();
    LocalLibrary(); 
    ~LocalLibrary();
    void GetAll(vector<Track> *tracks);
    int Save(Track *t);
    int Open(const string &path);
    int Close();
    bool Get(uint32_t id, Track *t);
    int Clear();
    void Scan(vector<string> scan_paths, bool sync);
    void Prune();
    void RunPruneThread();
    int Count();
    void Delete(const Track &);
};
}

#endif 
