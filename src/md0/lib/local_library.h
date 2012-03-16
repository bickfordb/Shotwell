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
  public: 
    long double last_update();
    LocalLibrary(); 
    ~LocalLibrary();
    void GetAll(vector<Track> *tracks);
    int Save(const Track &t);
    int Open(const string &path);
    int Close();
    int Get(const string &path, Track *t);
    int Clear();
    void Scan(vector<string> scan_paths, bool sync);
    void Prune();
    void RunPruneThread();
    int Count();
    int Delete(const string &);
};
}

#endif 
