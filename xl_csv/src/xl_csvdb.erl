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
-module(xl_csvdb).

-behaviour(gen_server).
-include("xl_csvdb.hrl").

%% ------------------------------------------------------------------
%% API Function Exports
%% ------------------------------------------------------------------
-export([start_link/3, start_index/2, cache_path/1, stop/0, lookup/1, index/3, unload/0, load/2, info/0]).

%% ------------------------------------------------------------------
%% gen_server Function Exports
%% ------------------------------------------------------------------
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

%% ------------------------------------------------------------------
%% API Function Definitions
%% ------------------------------------------------------------------
-record(db, {header, tree, handler, file}).

start_link(Location, Handler, Mode) ->
    error_logger:info_report("csvdb started at " ++ Location),
    gen_server:start_link({local, ?MODULE}, ?MODULE, [Location, Handler, Mode], []).

cache_path(ForPath) -> filename:dirname(ForPath) ++ "/data.index".

save_cache(Path, Header, Tree) ->
    error_logger:info_report("storing index..."),
    file:write_file(Path, term_to_binary([Header, Tree])).

load_cache(ForPath) ->
    CachePath = cache_path(ForPath),
    case filelib:is_regular(CachePath) of
        true ->
            error_logger:info_report("loading index..."),
            case file:read_file(CachePath) of
                {ok, Data} ->
                    [Header, Tree] = binary_to_term(Data),
                    error_logger:info_report("index loaded"),
                    {ok, {Header, Tree}};
                {error, Reason} ->
                    error_logger:error_report({no_index_cache, Reason}),
                    nocache;
                _ ->
                    error_logger:error_report(no_index_cache),
                    nocache
            end;
        _ -> nocache
    end.

start_index(Path, ExtractF) ->
    error_logger:info_report("start indexing..."),
    {ok, {Header, Tree}} = case load_cache(Path) of
        R = {ok, _} -> R;
        _ -> index(ExtractF, Path, cache_path(Path))
    end,
    error_logger:info_report("indexing finished. Loading data into memory...."),
    {ok, F} = xl_vmfile:open(Path, [{segment, 100000000}]),
    error_logger:info_report("...loaded"),
    {Header, Tree, F}.


index(ExtractF, Path, IndexPath) ->
    xl_file:using(Path, [read], fun(File) ->
        case xl_stream:to_pair(xl_io:parse_lines(File)) of
            [] -> {empty_file, Path};
            [{HeaderLine, _Offset} | Lines] ->
                H = xl_csv:parse_line(HeaderLine),
                T = xl_stream:ifoldl(fun({Line, Offset}, Tree, I) ->
                    progress(I),
                    {Key, Value} = ExtractF(xl_csv:parse_line(Line)),
                    gb_trees:insert(Key, #entry{value = Value, offset = Offset, length = size(Line)}, Tree)
                end, gb_trees:empty(), Lines),
                save_cache(IndexPath, H, T),
                {H, T}
        end
    end).


progress(I) when I rem 10000 == 0 -> error_logger:info_report(io_lib:format("progress: ~p", [I]));
progress(_) -> none.

find(Key, Db) ->
    {_, T} = Db#db.tree,
    H = Db#db.handler,
    case H:find(Key, T) of
        {_, #entry{offset = Offset, length = Length}} ->
            {ok, Line} = file:pread(Db#db.file, Offset, Length),
            H:format(Db#db.header, xl_csv:parse_line(Line));
        not_found -> not_found
    end.

stop() ->
    gen_server:cast(?MODULE, stop).

lookup(Key) -> gen_server:call(?MODULE, {lookup, Key}).

unload() -> gen_server:call(?MODULE, unload).

load(Location, Handler) ->
    gen_server:cast(?MODULE, {load, Location, Handler}), ok.

info() -> gen_server:call(?MODULE, info).


%% ------------------------------------------------------------------
%% gen_server Function Definitions
%% ------------------------------------------------------------------

init([Location, Handler, sync]) ->
    {Header, Tree, File} = start_index(Location, fun(X) -> Handler:extract(X) end),
    {ok, #db{header = Header, tree = Tree, handler = Handler, file = File}};
init([Location, Handler, async]) ->
    gen_server:cast(?MODULE, {load, Location, Handler}),
    {ok, not_available}.

handle_cast(stop, Db) -> {stop, normal, Db};
handle_cast({load, Location, Handler}, State) ->
    spawn_link(fun() ->
        {Header, Tree, File} = start_index(Location, fun(X) -> Handler:extract(X) end),
        gen_server:call(?MODULE, {ready, #db{header = Header, tree = Tree, handler = Handler, file = File}})
    end),
    {noreply, State};
handle_cast(_Msg, Db) -> {noreply, Db}.

handle_call(info, _From, State) -> {reply, process_info(self(), binary), State};
handle_call({lookup, _Key}, _From, State = not_available) -> {reply, State, State};
handle_call({lookup, Key}, _From, Db) -> {reply, find(Key, Db), Db};
handle_call(unload, _From, not_available) -> {reply, ok, not_available};
handle_call(unload, _From, Db) -> file:close(Db#db.file), {reply, ok, not_available, hibernate};
handle_call({ready, Db}, _From, _State) -> {reply, ok, Db}.

handle_info(_Msg, Db) -> {noreply, Db}.
code_change(_Old, Db, _Extra) -> {ok, Db}.
terminate(normal, not_available) ->
    error_logger:info_report(normal_exit), ok;
terminate(normal, Db) ->
    file:close(Db#db.file),
    error_logger:info_report(normal_exit), ok;
terminate(Reason, not_available) ->
    error_logger:error_report({terminated, Reason}), ok;
terminate(Reason, Db) ->
    file:close(Db#db.file),
    error_logger:error_report({terminated, Reason}), ok.

%% ------------------------------------------------------------------
%% Internal Function Definitions
%% ------------------------------------------------------------------

