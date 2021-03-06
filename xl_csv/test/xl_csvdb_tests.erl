%%  Copyright (c) 2012-2013
%%  StrikeAd LLC http://www.strikead.com
%%
%%  All rights reserved.
%%
%%  Redistribution and use in source and binary forms, with or without
%%  modification, are permitted provided that the following conditions are met:
%%
%%      Redistributions of source code must retain the above copyright
%%  notice, this list of conditions and the following disclaimer.
%%      Redistributions in binary form must reproduce the above copyright
%%  notice, this list of conditions and the following disclaimer in the
%%  documentation and/or other materials provided with the distribution.
%%      Neither the name of the StrikeAd LLC nor the names of its
%%  contributors may be used to endorse or promote products derived from
%%  this software without specific prior written permission.
%%
%%  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
%%  IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
%%  TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
%%  PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
%%  HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
%%  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
%%  TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
%%  PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
%%  LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
%%  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
%%  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
-module(xl_csvdb_tests).

-include_lib("eunit/include/eunit.hrl").
-include("xl_csvdb.hrl").

-behaviour(xl_csvdb_handler).
-export([extract/1, find/2, format/2]).

index_test() ->
    Csv = xl_eunit:resource(?MODULE, "csvdb.csv"),
    os:cmd("rm " ++ xl_csvdb:cache_path(Csv)),
    ExpectedHeader = [<<"key">>, <<"value">>],
    ExpectedTree = {3, {1, {entry, <<"one">>, 14, 10}, nil, {2, {entry, <<"two">>, 24, 10}, nil, {3, {entry, <<"three">>, 34, 12}, nil, nil}}}},
    {Header, Tree, File} = xl_csvdb:start_index(Csv, fun([Key, Value]) -> {list_to_integer(binary_to_list(Key)), Value} end),
    file:close(File),
    ?assertEqual(ExpectedHeader, Header),
    ?assertEqual(ExpectedTree, Tree).



lookup_test() ->
    Csv = xl_eunit:resource(?MODULE, "csvdbbig.csv"),
    os:cmd("rm " ++ xl_csvdb:cache_path(Csv)),
    xl_csvdb:start_link(Csv, ?MODULE, sync),
    try
        ?assertEqual({<<"1">>, <<"one">>}, xl_csvdb:lookup(1)),
        ?assertEqual({<<"3">>, <<"three">>}, xl_csvdb:lookup(4)),
        ?assertEqual({<<"33">>, <<"three">>}, xl_csvdb:lookup(33)),
        ?assertEqual(not_found, xl_csvdb:lookup(23))
    after
        xl_csvdb:stop()
    end.

unload_load_test() ->
    Csv = xl_eunit:resource(?MODULE, "csvdbbig.csv"),
    os:cmd("rm " ++ xl_csvdb:cache_path(Csv)),
    xl_csvdb:start_link(Csv, ?MODULE, sync),
    try
        xl_csvdb:unload(),
        ?assertEqual(not_available, xl_csvdb:lookup(1)),
        xl_csvdb:load(Csv, ?MODULE),
        timer:sleep(100),
        ?assertEqual({<<"1">>, <<"one">>}, xl_csvdb:lookup(1))
    after
        xl_csvdb:stop()
    end.


extract([Key, Value]) -> {list_to_integer(binary_to_list(Key)), Value}.
accept_if_possible(Key, Value = #entry{value = <<"three">>}) -> {Key, Value};
accept_if_possible(_Key, _Value) -> not_found.

find(_, nil) -> not_found;
find(Key, {Key, V, _, _}) -> {Key, V};
find(Key, {K, V, _, nil}) when Key > K -> accept_if_possible(K, V);
find(Key, {K, V, nil, _}) when Key < K -> accept_if_possible(K, V);
find(Key, {K, V, _, {KR, _, _, _}}) when Key > K, Key < KR -> accept_if_possible(K, V);
find(Key, {K, _, _, Right}) when Key > K -> find(Key, Right);
find(Key, {K, _, Left, _}) when Key < K -> find(Key, Left).

format(_Header, [Key, Value]) -> {Key, Value}.
