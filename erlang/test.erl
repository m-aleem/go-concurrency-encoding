-module(test).
-export([main/0]).

main() ->
    io:format("=== Enter Test(s) to Run ===~n"),
    io:format("1: Sync Test~n"),
    io:format("2: Async Test~n"),
    io:format("3: Mobility Test~n"),
    io:format("4: All Tests~n"),
    io:format("Enter choice (e.g., 1, 23, 4): "),

    InputRaw = io:get_line(""),
    Input = string:trim(InputRaw, both),

    case is_valid(Input) of
        false ->
            io:format("Invalid input. No tests will be run.~n");
        true ->
            case lists:member($4, Input) of
                true ->
                    run_test(test_sync),
                    run_test(test_async),
                    run_test(test_mobility);
                false ->
                    run_if_selected(Input, $1, test_sync),
                    run_if_selected(Input, $2, test_async),
                    run_if_selected(Input, $3, test_mobility)
            end
    end.

is_valid([]) -> true;
is_valid([H|T]) when H >= $1, H =< $4 -> is_valid(T);
is_valid(_) -> false.

run_if_selected(Input, Char, Module) ->
    case lists:member(Char, Input) of
        true -> run_test(Module);
        false -> ok
    end.

run_test(Module) ->
    apply(Module, main, []).