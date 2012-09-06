-module(xl_shell).

-export([command/1, command/2]).

-spec command/1 :: (string()) -> error_m:monad(string()).
command(Command) ->
    case eunit_lib:command(Command) of
        {0, Out} -> {ok, Out};
        {_, Out} -> {error, Out}
    end.

-spec command/2 :: (string(), file:name()) -> error_m:monad(string()).
command(Command, Dir) ->
    case eunit_lib:command(Command, Dir) of
        {0, Out} -> {ok, Out};
        {_, Out} -> {error, Out}
    end.