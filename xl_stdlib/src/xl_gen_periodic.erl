%% Copyright
-module(xl_gen_periodic).
-author("volodymyr.kyrychenko@strikead.com").

-behaviour(gen_server).

-callback init/1 :: (Args :: term()) ->
    {ok, State :: term()} | {ok, State :: term(), timeout() | hibernate} |
    {stop, Reason :: term()} | ignore.

-callback handle_action/2 :: (LastAction :: pos_integer(), State :: term()) ->
    {ok, NewState :: term()} | {ok, NewState :: term(), hibernate}.

-callback terminate(Reason :: (normal | shutdown | {shutdown, term()} | term()),
    LastAction :: pos_integer(), State :: term()) -> term().

%% API
-export([start_link/5, start_link/4, stop/1]).

%% gen_server
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
    terminate/2, code_change/3]).

-spec start_link/5 :: (Name, Mod :: atom(), Args :: term(), Interval :: timer:time(), Options) ->
    {ok, Pid} | {error, {already_started, Pid}} | {error, Reason} when
    Name :: {local, atom()} | {global, atom()} | {via, atom(), term()},
    Options :: [{timeout, timeout()} | {debug, [Flag]}],
    Flag :: trace | log | {logfile, file:name()} | statistics | debug,
    Reason :: {already_started, Pid} | term().
start_link(Name, Mod, Args, Interval, Options) ->
    gen_server:start_link(Name, xl_gen_periodic, {Mod, Args, Interval}, Options).

-spec start_link/4 :: (Mod :: atom(), Args :: term(), Interval :: timer:time(), Options) ->
    {ok, Pid} | {error, {already_started, Pid}} | {error, Reason} when
    Options :: [{timeout, timeout()} | {debug, [Flag]}],
    Flag :: trace | log | {logfile, file:name()} | statistics | debug,
    Reason :: {already_started, Pid} | term().
start_link(Mod, Args, Interval, Options) ->
    gen_server:start_link(xl_gen_periodic, {Mod, Args, Interval}, Options).

-spec stop/1 :: (Name) -> term() when
    Name :: {local, atom()} | {global, atom()} | {via, atom(), term()}.
stop(Name) -> gen_server:call(Name, stop).

%% gen_server callbacks
-record(internal_state, {
    module = error({undefined, module}) :: module(),
    state = error({undefined, state}) :: term(),
    timer = error({undefined, timer}) :: timer:tref(),
    interval = error({undefined, interval}),
    last_action = 0 :: integer()
}).

init({Mod, Args, Interval}) ->
    case Mod:init(Args) of
        {ok, State} -> new_internal_state(0, Mod, Interval, State);
        {ok, State, TimeoutOrHibernate} -> new_internal_state(0, Mod, Interval, State, TimeoutOrHibernate);
        Stop = {stop, _} -> Stop;
        ignore -> ignore
    end.

new_internal_state(LastAction, Mod, Interval, State, TimeoutOrHibernate) ->
    case new_internal_state(LastAction, Mod, Interval, State) of
        {ok, InternalState} -> {ok, InternalState, TimeoutOrHibernate};
        E -> E
    end.

new_internal_state(LastAction, Mod, Interval, State) ->
    case timer:send_after(Interval, action) of
        {ok, TRef} ->
            {ok, #internal_state{
                module = Mod,
                state = State,
                timer = TRef,
                interval = Interval,
                last_action = LastAction
            }};
        {error, E} -> {stop, E}
    end.

handle_call(stop, _From, InternalState) ->
    {stop, normal, ok, InternalState}.

handle_cast(_Msg, InternalState) ->
    {noreply, InternalState}.

handle_info(action, InternalState = #internal_state{module = Mod, interval = Interval, state = State, last_action = LA}) ->
    Now = xl_calendar:now_millis(),
    case Mod:handle_action(LA, State) of
        {ok, NewState} ->
            handle_info_result(new_internal_state(Now, Mod, Interval, NewState), InternalState);
        {ok, NewState, Hibernate} ->
            handle_info_result(new_internal_state(Now, Mod, Interval, NewState, Hibernate), InternalState)
    end;
handle_info(_Info, InternalState) ->
    {noreply, InternalState}.

handle_info_result({stop, Reason}, LastInternalState) ->
    {stop, Reason, LastInternalState};
handle_info_result({ok, InternalState}, _LastInternalState) ->
    {noreply, InternalState};
handle_info_result({ok, InternalState, hibernate}, _LastInternalState) ->
    {noreply, InternalState, hibernate}.

terminate(Reason, #internal_state{module = Mod, state = State, last_action = LA, timer = Timer}) ->
    timer:cancel(Timer),
    Mod:terminate(Reason, LA, State).

code_change(_OldVsn, InternalState, _Extra) ->
    {ok, InternalState}.

