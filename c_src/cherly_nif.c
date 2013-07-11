#include "erl_nif.h"
#include <stdio.h>
#include <string.h>
#include "cherly.h"
#include "common.h"

#define CHERLY_RES_TYPE "cherly_res"

static ERL_NIF_TERM cherly_nif_init(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
static ERL_NIF_TERM cherly_nif_stop(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
static ERL_NIF_TERM cherly_nif_get(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
static ERL_NIF_TERM cherly_nif_put(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
static ERL_NIF_TERM cherly_nif_remove(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
static ERL_NIF_TERM cherly_nif_size(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
static ERL_NIF_TERM cherly_nif_items(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);

// declare the function
static ERL_NIF_TERM cherly_nif_touch(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);

static ErlNifFunc nif_funcs[] =
  {
    {"start",  1, cherly_nif_init},
    {"stop",   1, cherly_nif_stop},
    {"get" ,   2, cherly_nif_get},
    {"put" ,   4, cherly_nif_put},
    {"remove", 2, cherly_nif_remove},
    {"size",   1, cherly_nif_size},
    {"items" , 1, cherly_nif_items},
    {"touch",  3, cherly_nif_touch} // make sure we define a new function, with 3 params
                                    // that is mapped to the cherly_nif_touch function
  };

static ERL_NIF_TERM atom_ok;
static ERL_NIF_TERM atom_error;
static ERL_NIF_TERM atom_oom;
static ERL_NIF_TERM atom_not_found;


/**
 * Initialize
 */
static ERL_NIF_TERM cherly_nif_init(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  ErlNifUInt64 max_size;
  ERL_NIF_TERM term;
  ErlNifResourceType* pert;
  cherly_t* obj;

  if (argc < 1) {
    return enif_make_badarg(env);
  }

  if (!enif_get_uint64(env, argv[0], &max_size)) {
    return enif_make_badarg(env);
  }

  pert = (ErlNifResourceType*)enif_priv_data(env);
  obj = enif_alloc_resource(pert, sizeof(cherly_t));

  term = enif_make_resource(env, obj);
  cherly_init(obj, 0, max_size);
  enif_release_resource(obj);

  return enif_make_tuple2(env, atom_ok, term);
}


/**
 * Stop
 */
static ERL_NIF_TERM cherly_nif_stop(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  cherly_t *obj;
  ErlNifResourceType* pert;

  if (argc < 1) {
    return enif_make_badarg(env);
  }

  pert = (ErlNifResourceType*)enif_priv_data(env);

  if (!enif_get_resource(env, argv[0], pert, (void**)&obj)) {
    return enif_make_badarg(env);
  }

  cherly_destroy(obj);
  return atom_ok;
}


/**
 * Retrieve an object from LRU-Storage
 */
static ERL_NIF_TERM cherly_nif_get(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  cherly_t *obj;
  int vallen;
  void* value;

  ErlNifResourceType* pert;
  ErlNifBinary keybin;
  ErlNifBinary bin;

  if (argc < 2) {
    return enif_make_badarg(env);
  }

  pert = (ErlNifResourceType*)enif_priv_data(env);
  if (!enif_get_resource(env, argv[0], pert, (void**)&obj)) {
    return enif_make_badarg(env);
  }

  if (!enif_inspect_binary(env, argv[1], &keybin)) {
    return enif_make_badarg(env);
  }

  if (keybin.size <= 0) {
    return enif_make_badarg(env);
  }

  value = cherly_get(obj, keybin.data, keybin.size, &vallen);

  if (value == NULL) {
    return atom_not_found;
  }

  if (!enif_alloc_binary(vallen, &bin)) {
    return enif_make_badarg(env);
  }

  memcpy(bin.data, value, vallen);
  return enif_make_tuple2(env, atom_ok, enif_make_binary(env, &bin));
}

static ERL_NIF_TERM cherly_nif_touch(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  cherly_t *obj;
  int vallen;
  void* value;
  int timeout;

  ErlNifResourceType* pert;
  ErlNifBinary keybin;
  ErlNifBinary bin;

  if (argc < 3) {
    return enif_make_badarg(env);
  }

  // Make an ErlNifResourceType
  pert = (ErlNifResourceType*)enif_priv_data(env);
  // Resource is the data structure that we use to bind erlang and c
  if (!enif_get_resource(env, argv[0], pert, (void**)&obj)) {
    return enif_make_badarg(env);
  }

  // get second arg as a binary (it's our key)
  if (!enif_inspect_binary(env, argv[1], &keybin)) {
    return enif_make_badarg(env);
  }

  // Check if the key is null
  if (keybin.size <= 0) {
    return enif_make_badarg(env);
  }

  // get our third parameter (timeout)
  if(!enif_get_int(env, argv[2], &timeout)) {
    return enif_make_badarg(env);
  }

  // now we need to do a touch
  // we return either atom_ok, atom_not_found, or an error tuple {error, "message"} using 
  // enif_make_tuple2

  // unfortunately, we don't exactly have a 'touch' function per-say in the cherly.c library,
  // so we will need to add something like that. You can see on line 111 in cherly.c the lru_touch call
  
  // we will also need to update the timeout in the struct, you can see that in the lru_item_t struct
  // (example in the cherly.c function, starting on line 84)

  return atom_ok;
}


/**
 * Insert an object into LRU-Storage
 */
static ERL_NIF_TERM cherly_nif_put(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  cherly_t *obj;
  ErlNifResourceType* pert;
  ErlNifBinary keybin;
  ErlNifBinary bin;
  bool ret;
  int timeout;

  if (argc < 4) {
    return enif_make_badarg(env);
  }

  pert = (ErlNifResourceType*)enif_priv_data(env);

  if (!enif_get_resource(env, argv[0], pert, (void**)&obj)) {
    return enif_make_badarg(env);
  }
  if (!enif_inspect_binary(env, argv[1], &keybin)) {
    return enif_make_badarg(env);
  }
  if (keybin.size <= 0) {
    return enif_make_badarg(env);
  }
  if (!enif_inspect_binary(env, argv[2], &bin)) {
    return enif_make_badarg(env);
  }

  if(!enif_get_int(env, argv[3], &timeout)) {

    return enif_make_badarg(env);
  }

  ret = cherly_put(obj, keybin.data, keybin.size, bin.data, bin.size, timeout, NULL);
  return ret ? atom_ok : enif_make_tuple2(env, atom_error, atom_oom);
}


/**
 * Remove an object from LRU-Storage
 */
static ERL_NIF_TERM cherly_nif_remove(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  cherly_t *obj;
  ErlNifResourceType* pert;
  ErlNifBinary keybin;
  void* value;

  if (argc < 2) {
    return enif_make_badarg(env);
  }

  pert = (ErlNifResourceType*)enif_priv_data(env);

  if (!enif_get_resource(env, argv[0], pert, (void**)&obj)) {
    return enif_make_badarg(env);
  }

  if (!enif_inspect_binary(env, argv[1], &keybin)) {
    return enif_make_badarg(env);
  }
  if (keybin.size <= 0) {
    return enif_make_badarg(env);
  }

  value = cherly_remove(obj, keybin.data, keybin.size);

  if (value == NULL) {
    return atom_not_found;
  }

  return atom_ok;
}


/**
 * Retrieve summary of size of stored objects
 */
static ERL_NIF_TERM cherly_nif_size(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  cherly_t *obj;
  ErlNifResourceType* pert;
  ErlNifUInt64 size;

  if (argc < 1) {
    return enif_make_badarg(env);
  }

  pert = (ErlNifResourceType*)enif_priv_data(env);

  if (!enif_get_resource(env, argv[0], pert, (void**)&obj)) {
    return enif_make_badarg(env);
  }

  size = cherly_size(obj);
  return enif_make_tuple2(env, atom_ok, enif_make_uint64(env, size));
}


/**
 * Retrieve total of objects
 */
static ERL_NIF_TERM cherly_nif_items(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  cherly_t *obj;
  ErlNifResourceType* pert;
  ErlNifUInt64 len;

  if (argc < 1) {
    return enif_make_badarg(env);
  }

  pert = (ErlNifResourceType*)enif_priv_data(env);

  if (!enif_get_resource(env, argv[0], pert, (void**)&obj)) {
    return enif_make_badarg(env);
  }

  len = cherly_items_length(obj);
  return enif_make_tuple2(env, atom_ok, enif_make_uint64(env, len));
}


/**
 * When calling onload or uggrade
 */
static int onload(ErlNifEnv* env, void** priv_data, ERL_NIF_TERM load_info) {
  ErlNifResourceFlags erf = ERL_NIF_RT_CREATE|ERL_NIF_RT_TAKEOVER;
  ErlNifResourceType* pert = enif_open_resource_type(env, NULL, CHERLY_RES_TYPE, NULL, erf, &erf);

  if (pert == NULL) {
    return 1;
  }

  *priv_data = (void*)pert;
  atom_ok = enif_make_atom(env, "ok");
  atom_error = enif_make_atom(env, "error");
  atom_oom = enif_make_atom(env, "out of memory");
  atom_not_found = enif_make_atom(env, "not_found");
  return 0;
}

/**
 *  Onload
 */
int cherly_nif_onload(ErlNifEnv* env, void** priv_data, ERL_NIF_TERM load_info) {
  return onload(env, priv_data, load_info);
}


/**
 * Upgrade
 */
int cherly_nif_upgrade(ErlNifEnv* env, void** priv_data, void** old_priv_data, ERL_NIF_TERM load_info) {
  return onload(env, priv_data, load_info);
}


ERL_NIF_INIT(cherly, nif_funcs, cherly_nif_onload, NULL, cherly_nif_upgrade, NULL)

