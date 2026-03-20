-module(test_close).
-export([main/0]).

%% ---------------------------------------------------------------------------
%% CHANNEL CLOSING
%% ---------------------------------------------------------------------------

test_close_sync_sender(Ch, Msgs) ->
    test_close_sync_sender(Ch, Msgs, 0).

test_close_sync_sender(Ch, Msgs, I) when I < Msgs ->
    goencoding:sync_send(Ch, I), % blocks until receiver is ready
    test_close_sync_sender(Ch, Msgs, I + 1);
test_close_sync_sender(Ch, _Msgs, _I) ->
    goencoding:sync_close(Ch). % signal "no more values"

test_close_sync_receiver(Ch) ->
    case goencoding:sync_recv(Ch) of % loops until channel is closed
        {ok, Msg} ->
            io:format("[close] Sync Receiver got: ~p~n", [Msg]),
            if Msg == 1 ->
                io:format("[close] Sync Receiver: about to close channel, will cause sender panic...~n"),
                goencoding:sync_close(Ch); % signal "no more values"
               true -> ok
            end,
            test_close_sync_receiver(Ch);
        closed ->
            io:format("[close] Sync Receiver: channel closed, no more messages, done receiving~n")
    end.

test_close_sync() ->
    OldTrapExit = process_flag(trap_exit, true),
    Ch = goencoding:sync_new(),
    Parent = self(),

    io:format("[close] Spawned Sync receiver goroutine...~n"),
    spawn(fun() ->
        test_close_sync_receiver(Ch),
        Parent ! {done, receiver}
    end),

    timer:sleep(100), % Ensure receiver is ready before sender starts

    io:format("[close] Spawned Sync sender goroutine...~n"),
    SenderPid = spawn_link(fun() ->
        test_close_sync_sender(Ch, 5),
        Parent ! {done, sender}
    end),

    % Wait for both to complete
    receive {done, receiver} -> ok end,
    receive
        {done, sender} -> ok;
        {'EXIT', SenderPid, Reason} ->
            io:format("[close] Sync Sender panic: ~p~n", [Reason])
    end,
    process_flag(trap_exit, OldTrapExit).

test_close_async() ->
    io:format("[close async] FIXME~n").

test_close_closed() ->
    Ch = goencoding:sync_new(),
    Parent = self(),
    io:format("[close closed] Close channel first time~n"),
    goencoding:sync_close(Ch),
    io:format("[close closed] Close channel second time~n"),
    {CloserPid, Ref} = spawn_monitor(fun() ->
        goencoding:sync_close(Ch),
        Parent ! {done, close_second_time}
    end),
    receive
        {done, close_second_time} -> ok;
        {'DOWN', Ref, process, CloserPid, Reason} ->
            io:format("[close closed] Panic on second close: ~p~n", [Reason])
    end.


%% ---------------------------------------------------------------------------
%% MAIN
%% ---------------------------------------------------------------------------

main() ->
    io:format("--- Close ---~n"),

    io:format("~n------ Close 1: Send on a closed sync channel ------~n"),
    test_close_sync(),

    io:format("~n------ Close 2: Send on a closed async channel ------~n"),
    test_close_async(),

    io:format("~n------ Close 3: Close a closed channel ------~n"),
    test_close_closed(),

    io:format("~n------ Close 4: Close a receive-only channel ------~n"),
    io:format("N/A: We did not implement receive-only channels in this Erlang version~n"),

    io:format("--- End Close ---~n~n").