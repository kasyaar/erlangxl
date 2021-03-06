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
-module(persist_fsync).

-behaviour(xl_gen_periodic).

%% API
-export([start_link/3, stop/1]).

%% xl_gen_periodic callbacks
-export([init/1, handle_action/2, terminate/3]).

% API
-spec start_link/3 :: (ets:tid() | atom(), pos_integer(), module()) -> error_m:monad(pid()).
start_link(ETS, Interval, Storage) ->
    xl_gen_periodic:start_link(?MODULE, {ETS, Storage}, Interval, []).

-spec stop/1 :: (pid()) -> ok.
stop(Pid) -> xl_gen_periodic:stop(Pid).

% xl_gen_periodic callbacks
-record(state, {
    ets = error({undefined, ets}) :: ets:tid() | atom(),
    storage = error({undefined, storage}) :: module()
}).

init({ETS, Storage}) ->
    {ok, #state{
            ets = ETS,
            storage = Storage
    }}.

handle_action(LastAction, State = #state{ets = ETS, storage = Storage}) ->
    fsync(ETS, LastAction, Storage),
    {ok, State}.

terminate(_Reason, LastAction, #state{ets = ETS, storage = Storage}) ->
    fsync(ETS, LastAction, Storage),
    ok.

% Internal functions
fsync(ETS, LastSync, Storage) ->
    Status = xl_stream:eforeach(fun
        ({Id, _, _, true}) ->
            case Storage:delete(Id) of
                ok ->
                    ets:delete(ETS, Id),
                    ok;
                E -> E
            end;
        (R = {Id, _, _, _}) -> Storage:store(Id, R)
    end, persist:ets_changes(ETS, LastSync)),
    case Status of
        ok -> ok;
        Error -> error_logger:error_msg("cannot fsync: ~p~n", [Error])
    end.


