-module(test_sync).
-export([main/0]).

%% ---------------------------------------------------------------------------
%% SYNCHRONOUS COMMUNICATION
%% From https://go.dev/tour/concurrency/2: By default, sends and receives
%% block until the other side is ready. This allows goroutines to synchronize
%% without explicit locks or condition variables.
%% ---------------------------------------------------------------------------

test_sync_sender(Ch, Msgs) ->
    test_sync_sender(Ch, Msgs, 0).

test_sync_sender(Ch, Msgs, I) when I < Msgs ->
    goencoding:sync_send(Ch, I), % blocks until receiver is ready
    test_sync_sender(Ch, Msgs, I + 1);
test_sync_sender(Ch, _Msgs, _I) ->
    goencoding:sync_close(Ch). % signal "no more values"

test_sync_receiver(Ch) ->
    case goencoding:sync_recv(Ch) of % loops until channel is closed
        {ok, Msg} ->
            io:format("[sync] Receiver got: ~p~n", [Msg]),
            test_sync_receiver(Ch);
        closed ->
            io:format("[sync] Receiver: channel closed, no more messages, done receiving~n")
    end.

test_sync() ->
    Ch = goencoding:sync_new(),
    Parent = self(),

    io:format("[sync] Spawned receiver goroutine...~n"),
    spawn(fun() ->
        test_sync_receiver(Ch),
        Parent ! {done, receiver}
    end),

    timer:sleep(100), % Ensure receiver is ready before sender starts

    io:format("[sync] Spawned sender goroutine...~n"),
    spawn(fun() ->
        test_sync_sender(Ch, 3),
        Parent ! {done, sender}
    end),

    % Wait for both to complete
    receive {done, receiver} -> ok end,
    receive {done, sender} -> ok end.

%% ---------------------------------------------------------------------------
%% MAIN
%% ---------------------------------------------------------------------------

main() ->
    io:format("--- Synchronous ---~n"),
    test_sync(),
    io:format("--- End Synchronous ---~n~n").