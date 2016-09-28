%%====================================================================
%%
%% Cherly
%%
%% Copyright (c) 2012 Stoic, Inc.
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
%% -------------------------------------------------------------------
%% Cherly Unit Test
%% @doc
%% @end
%%====================================================================
-module(test_cherly).
-author('Yoshiyuki Kanno').
-author('Yosuke Hara').

-include("cherly.hrl").
-include_lib("eunit/include/eunit.hrl").

-export([succ/1, fast_acc/3, time_to_epoch_float/1]).


%%--------------------------------------------------------------------
%% TEST FUNCTIONS
%%--------------------------------------------------------------------
-ifdef(EUNIT).

simple_test() ->
    {ok, C} = cherly:start(120),
    K = <<"key">>,
    V = <<"value">>,
    Len   = byte_size(K) + byte_size(V),
    cherly:put(C, K, V, 0),

    ?assertEqual({ok, V},   cherly:get(C, <<"key">>)),
    ?assertEqual({ok, Len}, cherly:size(C)),
    cherly:stop(C).

put_plural_objects_test() ->
    {ok, C} = cherly:start(10000),
    Keys = ["A","B","C","D","E","F",
            "G","H","I","J","K","L",
            "M","N","O","P","Q","R",
            "S","T","U","V","W","X",
            "Y","Z","1","2","3","4",
            "5","6","7","8","9","0"],
    lists:foreach(fun(K) ->
                          cherly:put(C, list_to_binary(K), <<"LEOFS">>, 0)
                  end, Keys),
    lists:foreach(fun(K) ->
                          {ok, <<"LEOFS">>} = cherly:get(C, list_to_binary(K))
                  end, Keys),

    Items = length(Keys),
    Size  = Items + (Items * 5),

    ?assertEqual({ok, Items}, cherly:items(C)),
    ?assertEqual({ok, Size},  cherly:size(C)),
    cherly:stop(C).

put_term_key_test() ->
    {ok, C} = cherly:start(1000),
    K = term_to_binary({1234567890, "server/erlang"}),
    V = <<"LEOFS">>,
    Len = byte_size(K) + byte_size(V),

    ok = cherly:put(C, K, V, 0),
    {ok, V} = cherly:get(C, K),

    ?assertEqual({ok, 1},   cherly:items(C)),
    ?assertEqual({ok, Len}, cherly:size(C)),
    cherly:stop(C).

put_including_null_key_test() ->
    {ok, C} = cherly:start(1000),
    H = <<"abcdefghijklmnopqrstuvwxyz">>,
    T = <<0:64>>,
    K = <<H/binary,T/binary>>,
    V = <<"LEOFS">>,
    Len = byte_size(K) + byte_size(V),

    ok = cherly:put(C, K, V, 0),
    {ok, V} = cherly:get(C, K),

    ?assertEqual({ok, 1},   cherly:items(C)),
    ?assertEqual({ok, Len}, cherly:size(C)),
    cherly:stop(C).

put_get_and_remove_test() ->
    {ok, C} = cherly:start(120),
    K = <<"key">>,
    V = <<"value">>,

    ?assertEqual(not_found, cherly:get(C, K)),
    cherly:put(C, K, V, 0),
    ?assertEqual({ok, V}, cherly:get(C, K)),
    cherly:remove(C, K),
    ?assertEqual(not_found, cherly:get(C, K)),
    ?assertEqual({ok, 0}, cherly:size(C)),
    cherly:stop(C).

put_with_lru_eject_test() ->
    {ok, C} = cherly:start(70),
    V = <<"value">>,
    lists:foldl(fun(_, Str) ->
                        Mod = list_to_binary(succ(Str)),
                        ?debugVal(Mod),
                        cherly:put(C, Mod, V, 0),
                        binary_to_list(Mod)
                end, "abc", lists:seq(1, 10)),
    ?debugVal(cherly:size(C)),
    %% ?assertEqual({ok, 8}, cherly:items(C)),
    cherly:stop(C).

what_goes_in_must_come_out_test() ->
    {ok, C} = cherly:start(120),
    K = <<"key">>,

    cherly:put(C, K, list_to_binary([<<"val1">>, <<"val2">>]), 0),
    ?assertEqual({ok, list_to_binary([<<"val1">>, <<"val2">>])}, cherly:get(C, K)),
    cherly:stop(C).

big_stuff_that_goes_in_must_come_out_test() ->
    {ok, C} = cherly:start(1048576),
    K = <<"key">>,
    V1 = <<0:524288>>,
    V2 = <<1:524288>>,

    cherly:put(C, K, list_to_binary([V1, V2]), 0),
    {ok, Ret} = cherly:get(C, K),
    ?assertEqual(list_to_binary([V1,V2]), Ret),
    cherly:stop(C).

put_one_thing_in_no_list_big_test() ->
    {ok, C} = cherly:start(1048576),
    K = <<"key">>,
    V = <<0:524288>>,

    cherly:put(C, K, V, 0),
    ?assertEqual({ok, V}, cherly:get(C, K)),
    cherly:stop(C).

put_one_thing_in_no_list_small_test() ->
    {ok, C} = cherly:start(1048576),
    K = <<"key">>,
    V = <<1:8>>,
    cherly:put(C, K, V, 0),
    ?assertEqual({ok, V}, cherly:get(C, K)),
    cherly:stop(C).

remove_nonexistant_test() ->
    {ok, C} = cherly:start(120),
    K = <<"key">>,

    cherly:remove(C, K),
    ?assertEqual(not_found, cherly:get(C, K)),
    cherly:stop(C).

put_bigger_thing_than_1MB_test() ->
    {ok, C} = cherly:start(1024 * 1024 * 5),
    K = <<"key">>,
    V = crypto:rand_bytes(1024 * 1024 * 2),
    cherly:put(C, K, V, 0),
    cherly:remove(C, K),
    ?assertEqual(not_found, cherly:get(C, K)),
    {ok, 0}  = cherly:items(C),
    {ok, 0} = cherly:size(C),
    cherly:stop(C).

double_get_test() ->
    %% outputv modifies the iovec with a skipsize.  That's fucking rad
    {ok, C} = cherly:start(1123123),
    K = <<"aczup">>,
    V = list_to_binary([<<131,108,0,0,0,1,104,2,107,0,9,60,48,46,52,55,50,46,48,
                          62,99,49,46,50,51,54,53,51,49,53,54,49,57,53,57,56,55,
                          50,57,54,49,48,52,101,43,48,57,0,0,0,0,0,106>>,
                        <<235,105,34,223,191,105,56,25,199,24,148,52,180,112,
                          198,246,56,150,15,175,56,34,38,120,99,41,59,53,204,
                          233,41,246,189,135,39,171,124,233,143,40,108,119,63,
                          130,237,8,121,35,97,121,172,20,149,241,129,191,2,211,
                          151,167,0,102,103,63,242,240,41,83,150,211,189,32,56,
                          65,217,241,234,237,58,216,34,245,253,153,140,190,186,
                          24,147,240,181,63,222,161,13,217,55,232,254,148>>]),
    cherly:put(C, K, V, 0),
    ?assertEqual({ok, V}, cherly:get(C, K)),
    ?assertEqual({ok, V}, cherly:get(C, K)),
    cherly:stop(C).

server_test() ->
    K = <<"KEY-1">>,
    V = <<"VALUE-1">>,

    ProcId = 'test_cherly',
    cherly_server:start_link(ProcId, (1024 * 1024)),
    ok = cherly_server:put(ProcId, K, V),
    {ok, V}  = cherly_server:get(ProcId, K),
    {ok, 1}  = cherly_server:items(ProcId),
    {ok, 12} = cherly_server:size(ProcId),

    {ok, Stats1} = cherly_server:stats(ProcId),
    ?assertEqual(#cache_stats{gets = 1,
                              puts = 1,
                              dels = 0,
                              hits = 1,
                              records = 1,
                              cached_size = 12}, Stats1),

    ok = cherly_server:delete(ProcId, K),
    not_found = cherly_server:delete(ProcId, K),
    {ok, Stats2} = cherly_server:stats(ProcId),
    ?assertEqual(#cache_stats{gets = 1,
                              puts = 1,
                              dels = 1,
                              hits = 1,
                              records = 0,
                              cached_size = 0}, Stats2),

    {ok, 0} = cherly_server:items(ProcId),
    {ok, 0} = cherly_server:size(ProcId),

    cherly_server:stop(ProcId),
    ok.


%%--------------------------------------------------------------------
%% INNER FUNCTIONS
%%--------------------------------------------------------------------
succ([]) ->
    [];
succ(Str) ->
    succ_int(lists:reverse(Str), []).


succ_int([Char|Str], Acc) ->
    if
        Char >= $z -> succ_int(Str, [$a|Acc]);
        true -> lists:reverse(lists:reverse([Char+1|Acc]) ++ Str)
    end.

fast_acc(_,   Acc, 0) -> Acc;
fast_acc(Fun, Acc, N) ->
    fast_acc(Fun, Fun(Acc), N-1).


time_to_epoch_float({Mega,Sec,Micro}) ->
    Mega * 1000000 + Sec + Micro / 1000000.

-endif.

