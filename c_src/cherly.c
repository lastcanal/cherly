#include <stdio.h>
#include <string.h>
#include "cherly.h"
#include "common.h"
#include <time.h>

static void cherly_eject_callback(cherly_t *cherly, char *key, int length);

/**
 * Initialize LRU-Storage
 */
void cherly_init(cherly_t *cherly, int options, unsigned long long max_size) {
  cherly->hm = runtime_makemap_c(&StrMapType, max_size);
  memset(&cherly->slab, 0, sizeof(slabs_t));
  slabs_init(&cherly->slab, max_size, 1.5, false);

  cherly->lru  = lru_create();
  cherly->size = 0;
  cherly->items_length = 0;
  cherly->max_size = max_size;
}


/**
 * Insert an object into LRU-Storage
 */
// node -> item -> value
bool cherly_put(cherly_t *cherly, void *key, int length, void *value, int size, int timeout, DestroyCallback destroy) {
  lru_item_t * item;
  String skey, sval;
  bool exists;

  // Prepare put-operation
  size_t bufsiz = sizeof(size_t) + length + 1 + size;
  void* buf = slabs_alloc(&cherly->slab, bufsiz);
  if (buf == NULL) {
    // retry
    cherly->size -= lru_eject_by_size(cherly->lru,
                                      SETTING_ITEM_SIZE_MAX,
                                      (EjectionCallback)cherly_eject_callback, cherly);
    buf = slabs_alloc(&cherly->slab, bufsiz);
    if (buf == NULL) return false;
  }
  *((size_t*)buf) = bufsiz;
  char* bufkey = (char*)((char*)buf + sizeof(size_t));

  skey.str = (byte*)bufkey;
  skey.len = length;

  memcpy(bufkey, key, length);
  runtime_mapaccess(&StrMapType, cherly->hm, (byte*)&skey, (byte*)&sval, &exists);

  if (exists) {
    item = (lru_item_t*)sval.str;
    cherly_remove(cherly, lru_item_key(item), lru_item_keylen(item));
  }
  if (cherly->size + bufsiz > cherly->max_size) {
    cherly->size -= lru_eject_by_size(cherly->lru,
                                     (length + size) - (cherly->max_size - cherly->size),
                                     (EjectionCallback)cherly_eject_callback, cherly);
  }

  void* bufval = (void*)(bufkey + length + 1);
  memcpy(bufval, value, size);

  // Insert an object into lru-storage
  item = lru_insert(cherly->lru, bufkey, length, bufval, size, timeout, destroy);
  if (item == NULL) return false;

  // After put-operation
  sval.str = (byte*)item;
  runtime_mapassign(&StrMapType, cherly->hm, (byte*)&skey, (byte*)&sval);

  cherly->size += lru_item_size(item);
  cherly->items_length++;
  return true;

}


/**
 * Retrieve an object from LRU-Storage
 */
void* cherly_get(cherly_t *cherly, void *key, int length, int* vallen) {
  lru_item_t * item;
  String skey, sval;
  bool exists;

  // Prepare get-operation
  skey.str = (byte*)key;
  skey.len = length;

  // Retrieve an object
  runtime_mapaccess(&StrMapType, cherly->hm, (byte*)&skey, (byte*)&sval, &exists);

  if (!exists) {
    return nil;
  } else {
    // need to check time_t and timeout
    item = (lru_item_t *)sval.str;

    if(item->timeout > 0) {
      time_t currTime = time(NULL);
      if((currTime - item->timeout) > item->timestamp) {
        // delete item from lru
        cherly_remove(cherly, key, length);
        return nil;
      }
    }

    lru_touch(cherly->lru, item);
    *vallen = lru_item_vallen(item);

    return lru_item_value(item);
  }
}


/**
 * Free a stored memory
 */
static inline void cherly_slab_free(slabs_t* slab, char* key) {
  size_t* psize = (size_t*)key;
  psize--;
  slabs_free(slab, (void*)psize, *psize);
}


/**
 * Callback
 */
static void cherly_eject_callback(cherly_t *cherly, char *key, int length) {
  lru_item_t *item;
  String skey, sval;
  bool exists;
  int32 ret;

  skey.str = (byte*)key;
  skey.len = length;
  runtime_mapaccess(&StrMapType, cherly->hm, (byte*)&skey, (byte*)&sval, &exists);

  if (!exists) {
    return;
  }

  item = (lru_item_t*)sval.str;
  cherly_slab_free(&cherly->slab, lru_item_key(item));
  ret = runtime_mapassign(&StrMapType, cherly->hm, (byte*)&skey, nil);

  if (ret) {
    cherly->items_length--;
    cherly->size -= lru_item_size(item);
  }
}


/**
 * Remove an object from LRU-Storage
 */
void* cherly_remove(cherly_t *cherly, void *key, int length) {
  lru_item_t *item;
  String skey, sval;
  bool exists;


  skey.str = (byte*)key;
  skey.len = length;
  runtime_mapaccess(&StrMapType, cherly->hm, (byte*)&skey, (byte*)&sval, &exists);


  // TODO: give a return value so we can do not_exists for memcached
  // we could also use bloom filters!
  if (!exists) {
    return 0;
  }

  item = (lru_item_t *)sval.str;
  cherly_slab_free(&cherly->slab, lru_item_key(item));

  lru_remove_and_destroy(cherly->lru, item);
  cherly->size -= lru_item_size(item);
  cherly->items_length--;

  runtime_mapassign(&StrMapType, cherly->hm, (byte*)&skey, nil);

  return 1;
}


/**
 * Destroy LRU-Storage
 */
void cherly_destroy(cherly_t *cherly) {
  runtime_mapdestroy(cherly->hm);
  lru_destroy(cherly->lru);
}

