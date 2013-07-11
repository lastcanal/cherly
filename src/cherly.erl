%%%-------------------------------------------------------------------
%%% File:      cherly.erl
%%% @author    Cliff Moon <cliff@moonpolysoft.com> []
%%% @copyright 2009 Cliff Moon See LICENSE file
%%% @doc
%%%
%%% @end
%%%
%%% @since 2009-02-22 by Cliff Moon
%%% @since 2012-02-22 by Yoshiyuki Kanno
%%%-------------------------------------------------------------------
-module(cherly).
-author('cliff@moonpolysoft.com').
-author('Yoshiyuki Kanno').

-export([start/1, put/4, get/2, remove/2, size/1, items/1, stop/1]).
-on_load(init/0).


%% @doc Initialize
%%
-spec(init() ->
             ok).
init() ->
    SoName = case code:priv_dir(?MODULE) of
                 {error, bad_name} ->
                     case code:which(?MODULE) of
                         Filename when is_list(Filename) ->
                             filename:join([filename:dirname(Filename),"../priv", "cherly"]);
                         _ ->
                             filename:join("../priv", "cherly")
                     end;
                 Dir ->
                     filename:join(Dir, "cherly")
             end,
    erlang:load_nif(SoName, 0).


%% @doc Launch cherly
%%
-spec(start(integer()) ->
             {ok, any()}).
start(_Size) ->
    exit(nif_library_not_loaded).

% -spec(put(any(), binary(), binary()) -> ok | {error, any()}).
% put(Res, Key, Value) ->
%     io:format("called put~n"),
%     put(Res, Key, Value, 0).

%% @doc Insert an object into the cherly
%%
-spec(put(any(), binary(), binary(), integer()) ->
             ok | {error, any()}).
put(_Res, _Key, _Value, _Timeout) ->
    exit(nif_library_not_loaded).

%% @doc Touch an object in cherly, update timeout
%%
%% we will define a new function here, basically if the nif library
%% does not load properly (the on_load(init/0) call), then the function
%% will hit exit. else it will call the cherly.so library
-spec(touch(any(), binary(), integer()) -> 
    ok | not_found | {error, any()}).
touch(_Res, _Key, _Timeout) ->
    exit(nif_library_not_loaded).


%% @doc Retrieve an object from the cherly
%%
-spec(get(any(), binary()) ->
             {ok, binary()} | not_found | {error, any()}).
get(_Res, _Key) ->
    exit(nif_library_not_loaded).

%% @doc Remove an object from the cherly
%%
-spec(remove(any(), binary()) ->
             ok | {error, any()}).
remove(_Res, _Key) ->
    exit(nif_library_not_loaded).


%% @doc Retrieve size of cached objects
%%
-spec(size(any()) ->
             {ok, integer()} | {error, any()}).
size(_Res) ->
    exit(nif_library_not_loaded).

%% @doc Retrieve total of cached objects
%%
-spec(items(any()) ->
             {ok, integer()} | {error, any()}).
items(_Res) ->
    exit(nif_library_not_loaded).


%% @doc Halt the cherly
%%
-spec(stop(any()) ->
             ok | {error, any()}).
stop(_Res) ->
    exit(nif_library_not_loaded).

