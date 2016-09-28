%%======================================================================
%%
%% Cherly
%%
%% Copyright (c) 2012 Rakuten, Inc.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% ---------------------------------------------------------------------
%% Cherly Server
%% @doc
%% @end
%%======================================================================
-module(cherly_server).
-author("Yosuke Hara").

-behaviour(gen_server).

-include("cherly.hrl").
-include_lib("eunit/include/eunit.hrl").

%% API
-export([start_link/2, stop/1, call/2, cast/2, cast/3,
         get/2, put/3, put/4, delete/2, stats/1, items/1, size/1]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).


%% FIXME: we should be using something like folsom for this
%% we also need to worry about evictions
-record(state, {handler,
                total_cache_size = 0 :: integer(),
                stats_gets	     = 0 :: integer(),
                stats_puts	     = 0 :: integer(),
                stats_dels	     = 0 :: integer(),
                stats_hits       = 0 :: integer()
               }).

-define(DEFAULT_TIMEOUT, 0).

%%--------------------------------------------------------------------
%% API
%%--------------------------------------------------------------------
%% Function: {ok,Pid} | ignore | {error, Error}
%% Description: Starts the server.
start_link(Id, CacheSize) ->
    gen_server:start_link({local, Id}, ?MODULE, [CacheSize], []).


%% Function: -> ok
%% Description: Manually stops the server.
stop(Pid) ->
    cast(Pid, stop, self()).

%% @doc gen_servrer call
%%
-spec(call(atom(), tuple()) ->
           undefined | binary() | {error, any()}).
call(Id, Params) ->
  gen_server:call(Id, Params).

%% @doc gen_server cast
%%
-spec(cast(atom(), tuple(), pid()) ->
             {ok, reference()} | {error, any()}).
cast(Id, Params, ReplyTo) ->
  Ref = make_ref(),
  CastReply = gen_server:cast(Id, {Params, Ref, ReplyTo}),
  {CastReply, Ref}.

cast(Id, Params) ->
  cast(Id, Params, self()).

%% @doc Retrieve a value associated with a specified key
%%
-spec(get(atom(), binary()) ->
             undefined | binary() | {error, any()}).
get(Id, Key) ->
    call(Id, {get, Key}).


%% @doc Insert a key-value pair into the cherly
%%
-spec(put(atom(), binary(), binary()) ->
             ok | {error, any()}).
put(Id, Key, Value) ->
    put(Id, Key, Value, ?DEFAULT_TIMEOUT).

%% @doc Insert a key-value pair into the cherly
%%
-spec(put(atom(), binary(), binary(), integer()) ->
             ok | {error, any()}).
put(Id, Key, Value, Timeout) ->
    call(Id, {put, Key, Value, Timeout}).


%% @doc Remove a key-value pair by a specified key into the cherly
-spec(delete(atom(), binary()) ->
             ok | {error, any()}).
delete(Id, Key) ->
    call(Id, {delete, Key}).


%% @doc Return server's state
-spec(stats(atom()) ->
             any()).
stats(Id) ->
    call(Id, {stats}).


%% @doc Return server's items
-spec(items(atom()) ->
             any()).
items(Id) ->
    call(Id, {items}).


%% @doc Return server's summary of cache size
-spec(size(atom()) ->
             any()).
size(Id) ->
    call(Id, {size}).


%%====================================================================
%% GEN_SERVER CALLBACKS
%%====================================================================
init([CacheSize]) ->
    {ok, Handler} = cherly:start(CacheSize),
    {ok, #state{total_cache_size = CacheSize,
                handler           = Handler}}.

handle_call({get, Key}, _From, #state{handler    = Handler,
                                      stats_gets = Gets,
                                      stats_hits = Hits} = State) ->
    case catch cherly:get(Handler, Key) of
        {ok, Value} ->
            {reply, {ok, Value}, State#state{stats_gets = Gets + 1,
                                             stats_hits = Hits + 1}};
        not_found ->
            {reply, not_found, State#state{stats_gets = Gets + 1}};
        {error, Cause} ->
            error_logger:error_msg("~p,~p,~p,~p~n",
                                   [{module, ?MODULE_STRING},
                                    {function, "handle_call/3"},
                                    {line, ?LINE}, {body, Cause}]),
            {reply, {error, Cause}, State};
        {'EXIT', Cause} ->
            error_logger:error_msg("~p,~p,~p,~p~n",
                                   [{module, ?MODULE_STRING},
                                    {function, "handle_call/3"},
                                    {line, ?LINE}, {body, Cause}]),
            {reply, {error, Cause}, State}
        end;

handle_call({put, Key, Val, Timeout}, _From, #state{handler    = Handler,
                                           stats_puts = Puts} = State) ->
    case catch cherly:put(Handler, Key, Val, Timeout) of
        ok ->
            {reply, ok, State#state{stats_puts = Puts + 1}};
        {'EXIT', Cause} ->
            error_logger:error_msg("~p,~p,~p,~p~n",
                                   [{module, ?MODULE_STRING},
                                    {function, "handle_call/3"},
                                    {line, ?LINE}, {body, Cause}]),
            {reply, {error, Cause}, State};
        {error, Cause} ->
            error_logger:error_msg("~p,~p,~p,~p~n",
                                   [{module, ?MODULE_STRING},
                                    {function, "handle_call/3"},
                                    {line, ?LINE}, {body, Cause}]),
            {reply, {error, Cause}, State}
    end;

handle_call({delete, Key}, _From, State = #state{handler    = Handler,
                                                 stats_dels = Dels}) ->
    case catch cherly:remove(Handler, Key) of
        ok ->
            {reply, ok, State#state{stats_dels = Dels + 1}};
        not_found ->
            {reply, not_found, State};
        {'EXIT', Cause} ->
            error_logger:error_msg("~p,~p,~p,~p~n",
                                   [{module, ?MODULE_STRING},
                                    {function, "handle_call/3"},
                                    {line, ?LINE}, {body, Cause}]),
            {reply, {error, Cause}, State};
        {error, Cause} ->
            error_logger:error_msg("~p,~p,~p,~p~n",
                                   [{module, ?MODULE_STRING},
                                    {function, "handle_call/3"},
                                    {line, ?LINE}, {body, Cause}]),
            {reply, {error, Cause}, State}
    end;

handle_call({stats}, _From, State = #state{handler    = Handler,
                                           stats_hits = Hits,
                                           stats_gets = Gets,
                                           stats_puts = Puts,
                                           stats_dels = Dels}) ->
    {ok, Items} = cherly:items(Handler),
    {ok, Size}  = cherly:size(Handler),
    Stats = #cache_stats{hits        = Hits,
                         gets        = Gets,
                         puts        = Puts,
                         dels        = Dels,
                         records     = Items,
                         cached_size = Size},
    {reply, {ok, Stats}, State};

handle_call({items}, _From, #state{handler = Handler} = State) ->
    Reply = cherly:items(Handler),
    {reply, Reply, State};

handle_call({size}, _From, #state{handler = Handler} = State) ->
    Reply  = cherly:size(Handler),
    {reply, Reply, State};

handle_call(_Request, _From, State) ->
    {reply, undefined, State}.

handle_cast({Request, Ref, ReplyTo}, State) ->
  case catch handle_call(Request, ReplyTo, State) of
    {reply, Reply, State2} ->
      ReplyTo ! {cherly_response, Ref, Reply},
     {noreply, State2};
    {'EXIT', Cause} ->
      ReplyTo ! {cherly_error, Ref, Cause},
      {noreply, State}
  end;

handle_cast(stop, State) ->
    {stop, normal, State};

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.


%% ----------------------------------------------------------------------------------------------------------
%% Function: terminate(Reason, State) -> void()
%% Description: This function is called by a gen_server when it is about to terminate. When it returns,
%% the gen_server terminates with Reason. The return value is ignored.
%% ----------------------------------------------------------------------------------------------------------
terminate(_Reason, _State) ->
    terminated.


%% ----------------------------------------------------------------------------------------------------------
%% Function: code_change(OldVsn, State, Extra) -> {ok, NewState}
%% Description: Convert process state when code is changed.
%% ----------------------------------------------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

