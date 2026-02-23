-module(test_sync).
-export([main/0]).

main() ->
    io:format("--- Synchronous ---~n"),
    sync:hello_world().