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
%% Cherly Supervisor
%% @doc
%% @end
%%======================================================================
-module(cherly_sup).
-author("Yosuke Hara").

-behaviour(supervisor).

-include_lib("eunit/include/eunit.hrl").

%% External API
-export([start_link/0, stop/0, start_child/2]).

%% Callbacks
-export([init/1]).

-define(MAX_RESTART,              5).
-define(MAX_TIME,                60).
-define(SHUTDOWN_WAITING_TIME, 2000).

-define(CHILD_SPEC(Id, CacheSize), 
    {Id, 
        {cherly_server, start_link, [Id, CacheSize]}, 
        permanent, ?SHUTDOWN_WAITING_TIME, worker, [cherly_server]
    }).


-ifdef(TEST).
-define(DEF_TOTAL_CACHE_SIZE, 1024 * 1024). %% 1MB
-else.
-define(DEF_TOTAL_CACHE_SIZE, 1024 * 1024 * 1024). %% 1GB
-endif.


%%-----------------------------------------------------------------------
%% External API
%%-----------------------------------------------------------------------
%% @spec (Params) -> ok
%% @doc start link.
%% @end
start_link() ->
    %% should put in which partitions and such
    %% total cache size should be for all partitions? or cache size per partition?
    TotalCacheSize = case application:get_env(cherly, total_cache_size) of
                         {ok, Value1} when is_integer(Value1) ->
                             Value1;
                         _ ->
                             ?DEF_TOTAL_CACHE_SIZE
                     end,
    supervisor:start_link({local, ?MODULE}, ?MODULE, [TotalCacheSize]).


%% @spec () -> ok |
%%             not_started
%% @doc stop process.
%% @end
stop() ->
    case whereis(?MODULE) of
        Pid when is_pid(Pid) == true ->
            exit(Pid, shutdown),
            ok;
        _ -> not_started
    end.


start_child(Id, CacheSize) ->
    supervisor:start_child(?MODULE, ?CHILD_SPEC(Id, CacheSize)).


%% ---------------------------------------------------------------------
%% Callbacks
%% ---------------------------------------------------------------------
%% @spec (Params) -> ok
%% @doc stop process.
%% @end
%% @private
init([_TotalCacheSize]) ->
    {ok, {{one_for_one, ?MAX_RESTART, ?MAX_TIME},
          []}}.

