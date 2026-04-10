-module(test_async).
-export([main/0]).

%% ---------------------------------------------------------------------------
%% ASYNCHRONOUS COMMUNICATION
%% From https://go.dev/ref/spec#Channel_types: The capacity, in number of
%% elements, sets the size of the buffer in the channel. If the capacity is
%% zero or absent, the channel is unbuffered and communication succeeds only
%% when both a sender and receiver are ready. Otherwise, the channel is buffered
%% and communication succeeds without blocking if the buffer is not full (sends)
%% or not empty (receives). A nil channel is never ready for communication.
%% ---------------------------------------------------------------------------

test_async_sender(Ch, Msgs) ->
    test_async_sender(Ch, Msgs, 0).

test_async_sender(Ch, Msgs, I) when I < Msgs ->
    goencoding:async_send(Ch, I), % does not block if buffer has space
    io:format("[async] Sender sent: ~p~n", [I]),
    test_async_sender(Ch, Msgs, I + 1);

test_async_sender(Ch, _Msgs, _I) ->
    goencoding:async_close(Ch). % signal "no more values"

test_async_receiver(Ch) ->
    case goencoding:async_recv(Ch) of % loops until channel is closed
        {ok, Msg} ->
            timer:sleep(100), % simulate slow processing
            io:format("[async] Receiver got: ~p~n", [Msg]),
            test_async_receiver(Ch);
        closed ->
            io:format("[async] Receiver: channel closed, no more messages, done receiving~n")
    end.

test_async() ->
    Ch = goencoding:async_new(2), % buffered channel with capacity 2
    Parent = self(),

    io:format("[async] Spawned receiver goroutine...~n"),
    spawn(fun() ->
        test_async_receiver(Ch),
        Parent ! {done, receiver}
    end),

    timer:sleep(100), % Ensure receiver is ready before sender starts

    io:format("[async] Spawned sender goroutine...~n"),
    spawn(fun() ->
        test_async_sender(Ch, 5), % send 5 messages (buffer is only 2)
        Parent ! {done, sender}
    end),

    % Wait for both to complete
    receive {done, receiver} -> ok end,
    receive {done, sender} -> ok end.


test_async_multiple_blocked_senders() ->
    Ch = goencoding:async_new(2), % buffered channel with capacity 2
    Parent = self(),

    % Fill the buffer to block senders
    goencoding:async_send(Ch, 1),
    goencoding:async_send(Ch, 2),
    io:format("[async: multi-sender] Buffer filled with [1, 2]~n"),

    io:format("[async] Spawned receiver goroutine...~n"),
    spawn(fun() ->
        test_async_receiver(Ch),
        Parent ! {done, receiver}
    end),

    timer:sleep(100), % Ensure receiver is ready before sender starts

    io:format("[async] Spawned sender goroutine...~n"),
    spawn(fun() ->
        goencoding:async_send(Ch, 3),
        goencoding:async_send(Ch, 4),
        goencoding:async_send(Ch, 5),
        goencoding:async_close(Ch), % signal "no more values"
        Parent ! {done, sender}
    end),

    % Wait for both to complete
    receive {done, receiver} -> ok end,
    receive {done, sender} -> ok end.


%% ---------------------------------------------------------------------------
%% MAIN
%% ---------------------------------------------------------------------------

main() ->
    io:format("~n--- Asynchronous tests ---~n"),

    io:format("------ Async 1: Send on an open channel (one sender, one receiver) ------~n"),
    test_async(),
	
    io:format("~n------ Async 2: Send on an open channel (multiple senders, one receiver) ------~n"),
    test_async_multiple_blocked_senders(),

	io:format("--- End Asynchronous tests ---~n").

