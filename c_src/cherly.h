#ifndef __CHERLY__
#define __CHERLY__

#include "runtime.h"
#include "lru.h"
#include "slabs.h"

#define cherly_size(cherly) ((cherly)->size)
#define cherly_items_length(cherly) ((cherly)->items_length)
#define cherly_max_size(cherly) ((cherly)->max_size)

typedef struct _cherly_t {
  Hmap* hm;
  slabs_t slab;
  lru_t *lru;
  unsigned long long size;
  unsigned long long items_length;
  unsigned long long max_size;
} cherly_t;

void cherly_init(cherly_t *cherly, int options, unsigned long long max_size);
void * cherly_get(cherly_t *cherly, void * key, int length, int* vallen);
bool cherly_put(cherly_t *cherly, void * key, int length, void *value, int size, int timeout, DestroyCallback);
void * cherly_remove(cherly_t *cherly, void * key, int length);
void cherly_destroy(cherly_t *cherly);

#endif
