#ifndef _Library_H_
#define _Library_H_

#include <vector>
#include <set>
#include "track.h"
#include <leveldb/db.h>
#include <tr1/memory>
#include <sys/time.h>

using namespace std;
using namespace std::tr1;

class Library { 
  private:
    leveldb::DB *db_;
    pthread_t prune_thread_;
    long double last_update_;
    void MarkUpdated();
  public: 
    long double last_update();
    Library(); 
    ~Library();
    int Save(const Track &t);
    int Open(const string &path);
    int Close();
    int Get(const string &path, Track *t);
    shared_ptr<vector<shared_ptr<Track> > > GetAll(); 
    int Clear();
    void Scan(vector<string> scan_paths, bool sync);
    void Prune();
    void RunPruneThread();
    int Count();
    int Delete(const string &);
};

#endif 
