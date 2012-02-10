-module(strikead_file).

-export([list_dir/2, compile_mask/1, find/2, exists/1, ensure_dir/1, mkdirs/1, write_terms/2, read_file/1, delete/1, make_symlink/2, write_file/2]).

list_dir(Dir, Filter) when is_function(Filter) ->
    case strikead_io:apply_io(file,list_dir,[Dir]) of
        {ok, Listing} -> {ok, lists:filter(Filter, Listing)};
        E -> E
    end;

list_dir(Dir, Mask) when is_list(Mask) -> list_dir(Dir, compile_mask(Mask)).

find(Dir, Mask) when is_list(Mask) ->
    case list_dir(Dir, Mask) of
        {ok, [F|_]} -> {ok, F};
        {ok, []} -> not_found;
        E -> E
    end.

compile_mask(Mask) ->
    fun(X) ->
        case re:run(X, compile_mask(Mask, [])) of
            {match, _} -> true;
            _ -> false
        end
    end.
compile_mask([], Acc) -> Acc;
compile_mask([$. | T], Acc) -> compile_mask(T, Acc ++ "\.");     
compile_mask([$* | T], Acc) -> compile_mask(T, Acc ++ ".*");     
compile_mask([$? | T], Acc) -> compile_mask(T, Acc ++ ".");     
compile_mask([H | T], Acc) -> compile_mask(T, Acc ++ [H]).     

exists(Path) ->
	case strikead_io:apply_io(file, read_file_info, [Path]) of
		{ok, _} -> true;
		{error, enoent, _, _} -> false;
		E -> E
	end.

ensure_dir(Path) -> strikead_io:apply_io(filelib, ensure_dir, [Path]).

mkdirs(Path) -> ensure_dir(Path ++ "/X").

write_terms(File, L) when is_list(L) ->
    strikead_autofile:using(File, [write], fun(F) ->
        lists:foreach(fun(X) -> io:format(F, "~p.~n",[X]) end, L)
    end);

write_terms(File, L) -> write_terms(File, [L]).

read_file(Path) -> strikead_io:apply_io(file, read_file, [Path]).
write_file(Path, Data) -> strikead_io:apply_io(file, write_file, [Path, Data]).
delete(Path) -> strikead_io:apply_io(file, delete, [Path]).
make_symlink(Target, Link) -> strikead_io:apply_io(file, make_symlink, [Target, Link]).
