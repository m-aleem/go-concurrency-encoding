-module(test_close).
-export([main/0]).

%% ---------------------------------------------------------------------------
%% CHANNEL CLOSING
%% ---------------------------------------------------------------------------

test_close_sync_sender(Ch, Msgs) ->
    test_close_sync_sender(Ch, Msgs, 0).

test_close_sync_sender(Ch, Msgs, I) when I < Msgs ->
    goencoding:sync_send(Ch, I), % blocks until receiver is ready
    %io:format("[close sync] Sender sent: ~p~n", [I]),
    test_close_sync_sender(Ch, Msgs, I + 1);
test_close_sync_sender(Ch, _Msgs, _I) ->
    goencoding:sync_close(Ch). % signal "no more values"

test_close_sync_receiver(Ch) ->
    case goencoding:sync_recv(Ch) of % loops until channel is closed
        {ok, Msg} ->
            io:format("[close sync] Receiver got: ~p~n", [Msg]),
            if Msg == 1 ->
                io:format("[close sync] Receiver: about to close channel, will cause sender panic...~n"),
                goencoding:sync_close(Ch); % signal "no more values"
               true -> ok
            end,
            test_close_sync_receiver(Ch);
        closed ->
            io:format("[close sync] Receiver: channel closed, no more messages, done receiving~n")
    end.

test_close_sync() ->
    OldTrapExit = process_flag(trap_exit, true),
    Ch = goencoding:sync_new(),
    Parent = self(),

    io:format("[close sync] Spawned sync receiver goroutine...~n"),
    spawn(fun() ->
        test_close_sync_receiver(Ch),
        Parent ! {done, receiver}
    end),

    timer:sleep(100), % Ensure receiver is ready before sender starts

    io:format("[close sync] Spawned sync sender goroutine...~n"),
    SenderPid = spawn_link(fun() ->
        test_close_sync_sender(Ch, 5),
        Parent ! {done, sender}
    end),

    % Wait for both to complete
    receive {done, receiver} -> ok end,
    receive
        {done, sender} -> ok;
        {'EXIT', SenderPid, Reason} ->
            io:format("[close sync] Sender panic: ~p~n", [Reason])
    end,
    process_flag(trap_exit, OldTrapExit).

test_close_async_sender(Ch, Msgs) ->
    test_close_async_sender(Ch, Msgs, 0).

test_close_async_sender(Ch, Msgs, I) when I < Msgs ->
    goencoding:async_send(Ch, I),
    timer:sleep(100), % simulate slow sending and allow receiver to process messages
    %io:format("[close async] Sender sent: ~p~n", [I]),
    test_close_async_sender(Ch, Msgs, I + 1);

test_close_async_sender(Ch, _Msgs, _I) ->
    goencoding:async_close(Ch).  % signal "no more values"

test_close_async_receiver(Ch) ->
    case goencoding:async_recv(Ch) of % loops until channel is closed
        {ok, Msg} ->
            io:format("[close async] Receiver got: ~p~n", [Msg]),
            if Msg == 1 ->
                io:format("[close async] Receiver: about to close channel, will cause sender panic...~n"),
                goencoding:async_close(Ch);
               true -> ok
            end,
            test_close_async_receiver(Ch);
        closed ->
            io:format("[close async] Receiver: channel closed, no more messages, done receiving~n")
    end.

test_close_async() ->
    OldTrapExit = process_flag(trap_exit, true),
    Ch = goencoding:async_new(3), % buffered channel with capacity 3
    Parent = self(),

    io:format("[close async] Spawned async receiver goroutine...~n"),
    spawn(fun() ->
        test_close_async_receiver(Ch),
        Parent ! {done, receiver}
    end),

    timer:sleep(100), % Ensure receiver is ready before sender starts

    io:format("[close async] Spawned async sender goroutine...~n"),
    SenderPid = spawn_link(fun() ->
        test_close_async_sender(Ch, 5), % send 5 messages (buffer is only 3, so sender will block on 4th send until receiver processes some messages)
        Parent ! {done, sender}
    end),

    % Wait for both to complete
    receive {done, receiver} -> ok end,
    receive
        {done, sender} -> ok;
        {'EXIT', SenderPid, Reason} ->
            io:format("[close async] Sender panic: ~p~n", [Reason])
    end,
    process_flag(trap_exit, OldTrapExit).


test_receive_closed_async() ->
    Ch = goencoding:async_new(3),
    Parent = self(),

    spawn(fun() ->
        timer:sleep(120), % simulate a slow receiver
        test_receive_closed_async_loop(Ch),
        Parent ! {done, receiver}
    end),

    timer:sleep(50),
    goencoding:async_send(Ch, 1),
    goencoding:async_send(Ch, 2),
    io:format("[receive closed async] Sender: about to close channel after sending values to buffered channel~n"),
    goencoding:async_close(Ch),
    receive {done, receiver} -> ok end.


test_receive_closed_async_loop(Ch) ->
    case goencoding:async_recv(Ch) of
        {ok, Msg} ->
            io:format("[receive closed async] Receiver got: ~p~n", [Msg]),
            timer:sleep(50),
            test_receive_closed_async_loop(Ch);
        closed ->
            io:format("[receive closed async] Receiver: channel closed, no more messages, done receiving~n")
    end.


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
    io:format("~n--- Close tests ---~n"),

    io:format("------ Close 1: Send on a closed sync channel ------~n"),
    test_close_sync(),

    io:format("~n------ Close 2: Send on a closed async channel ------~n"),
    test_close_async(),

    io:format("~n------ Close 3: Close a closed channel ------~n"),
    test_close_closed(),

    io:format("~n------ Close 4: Receive on a closed async channel ------~n"),
    test_receive_closed_async(),

    %io:format("~n------ Close 5: Close a receive-only channel ------~n"),
    %io:format("N/A: We did not implement receive-only channels in this Erlang version~n"),

    io:format("--- End Close tests ---~n").