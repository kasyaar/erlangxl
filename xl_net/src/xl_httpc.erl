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
-module(xl_httpc).

-include("xl_httpc.hrl").

-behaviour(gen_server).
-compile({parse_transform, do}).

%% -----------------------------------------------------------------------------
%% API Function Exports
%% -----------------------------------------------------------------------------
-export([start_link/2, stop/1, call/2, post/4]).

%% -----------------------------------------------------------------------------
%% gen_server Function Exports
%% -----------------------------------------------------------------------------
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
    terminate/2, code_change/3]).

%% -----------------------------------------------------------------------------
%% API Function Definitions
%% -----------------------------------------------------------------------------
-spec start_link/2 :: (atom(), atom()) -> {ok, pid()} | ignore | {error, term()}.
start_link(App, Profile) ->
    gen_server:start_link({local, server_name(Profile)}, ?MODULE, {App, Profile}, []).

-spec stop/1 :: (atom()) -> ok.
stop(Profile) -> gen_server:cast(server_name(Profile), stop).

-spec post/4 :: (atom(), string(), string(), string() | binary()) ->
    error_m:monad({integer(), string(), string()}).
post(Profile, Url, ContentType, Body) ->
    gen_server:call(server_name(Profile), {post, Url, ContentType, Body}).

-spec call/2 :: (atom(), string()) -> error_m:monad(tuple()).
call(Profile, Url) -> gen_server:call(server_name(Profile), {call, Url}).

%% -----------------------------------------------------------------------------
%% gen_server Function Definitions
%% -----------------------------------------------------------------------------
-record(state, {request_opts, profile}).

init({App, Profile}) ->
    do([error_m ||
        inets:start(httpc, [{profile, Profile}]),
        ClientOpts <- xl_application:eget_env(App, Profile),
        httpc:set_options(
            element(2, xl_lists:keyfind(client, 1,
                ClientOpts, {client, []})),
            Profile),
        return(#state{
            request_opts = element(2,
                xl_lists:keyfind(request, 1, ClientOpts, {request, []})),
            profile = Profile
        })
    ]).

handle_call({call, Url}, _From,
	    State = #state{profile = Profile, request_opts = Opts}) ->
    Result = case httpc:request(get, {Url, []}, Opts, [], Profile) of
        {ok, {{_, Code, Reason}, _, _}} ->
            {ok, #http_resp{code = Code, reason = Reason}};
        E = {error, _} -> E
    end,
    {reply, Result, State};
handle_call({post, Url, ContentType, RequestBody}, _From,
	    State = #state{profile = Profile, request_opts = Opts}) ->
    Result = case httpc:request(post, {Url, [], ContentType, RequestBody}, Opts, [], Profile) of
        {ok, {{_, Code, Reason}, Headers, Body}} ->
            {ok, #http_resp{
                code = Code,
                reason = Reason,
                content_type = xl_lists:kvfind("content-type", Headers, undefined),
                content = Body
            }};
        E = {error, _} -> E
    end,
    {reply, Result, State};
handle_call(_Request, _From, State) -> {noreply, ok, State}.

handle_cast(stop, State) -> {stop, normal, State};
handle_cast(_Msg, State) -> {noreply, State}.

handle_info(_Info, State) -> {noreply, State}.

terminate(_Reason, _State) ->
    inets:stop(httpc, s2s_http),
    ok.

code_change(_OldVsn, State, _Extra) -> {ok, State}.

%% -----------------------------------------------------------------------------
%% Internal Function Definitions
%% -----------------------------------------------------------------------------

server_name(Name) ->
    xl_convert:make_atom([Name, '_httpc']).
