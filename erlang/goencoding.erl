%% goencoding.erl

-module(goencoding).
-export([sync_new/0, sync_send/2, sync_recv/1, sync_close/1,
         async_new/1, async_send/2, async_recv/1, async_close/1,
         panic/1, recover/1]).

%% ---------------------------------------------------------------------------
%% SYNCHRONOUS CHANNELS
%% ---------------------------------------------------------------------------

%% sync_new() -> ChannelPid
%% Creates a new synchronous channel (like Go's make(chan T))
%% Returns: Pid of the channel process
sync_new() ->
    spawn(fun() -> sync_channel_loop(none, false) end).

%% Internal Channel Process for Synchronous Channels
%%
%% ChannelState can be:
%%   none - no one waiting
%%   {waiting_sender, SenderPid, Msg} - sender blocked waiting for receiver
%%   {waiting_receiver, RecvPid} - receiver blocked waiting for sender
%%
%% Closed is a boolean indicating if channel is closed
%%
%% The channel process loop maintains the synchronization of senders
%% and receivers. It ensures that a sender and receiver communicate
%% "directly" without buffering, and that the correct blocking behavior occurs
%% when one party is waiting for the other.
%%
%% The function waits for different messages depending on the current state
%% of the channel. For example, if a sender is waiting, the channel will only accept
%% recv or close messages, and any send messages will accumulate in the
%% mailbox until the waiting sender is handled. See inline comments for more details.

sync_channel_loop(ChannelState, Closed) ->
    case ChannelState of
        none ->
            %% No one waiting, accept any operation
            receive
                {send, SenderPid, Msg} ->
                    %% Sender arrived first! Check if channel is closed first
                    if
                        Closed ->
                            %% Send on closed channel - panic in Go!
                            exit(SenderPid, {panic, send_on_closed_channel}),
                            sync_channel_loop(none, Closed);
                        true ->
                            %% No receiver waiting, sender blocks
                            sync_channel_loop({waiting_sender, SenderPid, Msg}, Closed)
                    end;

                {recv, RecvPid} ->
                    %% Receiver arrived first! Check if channel is closed first
                    if
                        Closed ->
                            %% Receive on closed channel with no sender
                            RecvPid ! closed,
                            sync_channel_loop(none, Closed);
                        true ->
                            %% No sender waiting, receiver blocks
                            sync_channel_loop({waiting_receiver, RecvPid}, Closed)
                    end;

                {close_channel, CloserPid} ->
                    %% Received close request, check if already closed
                    if
                        Closed ->
                            %% Close of closed channel - panic in Go!
                            exit(CloserPid, {panic, close_of_closed_channel}),
                            sync_channel_loop(none, Closed);
                        true ->
                            %% Mark channel as closed
                            CloserPid ! ok,
                            sync_channel_loop(none, true)
                    end
            end;

        {waiting_sender, SenderPid, Msg} ->
            %% Sender waiting, only accept recv or close
            %% Any {send, _, _} messages will accumulate in mailbox
            receive
                {recv, RecvPid} ->
                    %% Receiver arrived!
                    RecvPid ! {ok, Msg},
                    SenderPid ! ok,
                    sync_channel_loop(none, Closed);

                {close_channel, CloserPid} ->
                    if
                        Closed ->
                            %% Close of closed channel - panic in Go!
                            exit(CloserPid, {panic, close_of_closed_channel}),
                            sync_channel_loop({waiting_sender, SenderPid, Msg}, Closed);
                        true ->
                            %% Channel closed while sender waiting
                            %% Notify waiting sender with error
                            CloserPid ! ok,
                            exit(SenderPid, {panic, send_on_closed_channel}),
                            sync_channel_loop(none, true)
                    end
            end;

        {waiting_receiver, RecvPid} ->
            %% Receiver waiting, only accept send or close
            %% Any {recv, _} messages will accumulate in mailbox
            receive
                {send, SenderPid, Msg} ->
                    %% Sender arrived!
                    if
                        Closed ->
                            %% Send on closed channel - panic in Go!
                            exit(SenderPid, {panic, send_on_closed_channel}),
                            sync_channel_loop({waiting_receiver, RecvPid}, Closed);
                        true ->
                            %% Sender arrived! Rendezvous
                            RecvPid ! {ok, Msg},
                            SenderPid ! ok,
                            sync_channel_loop(none, Closed)
                    end;

                {close_channel, CloserPid} ->
                    if
                        Closed ->
                            %% Close of closed channel - panic in Go!
                            exit(CloserPid, {panic, close_of_closed_channel}),
                            sync_channel_loop({waiting_receiver, RecvPid}, Closed);
                        true ->
                            %% Channel closed while receiver waiting
                            %% Notify waiting receiver
                            CloserPid ! ok,
                            exit(RecvPid, {panic, recv_on_closed_channel}),
                            sync_channel_loop(none, true)
                    end
            end
    end.

%% sync_send(ChannelPid, Msg) -> ok | {error, closed}
%% Sends a message on the channel (like Go's ch <- msg)
%% Blocks until a receiver is ready to receive
%% In Go, sending on a closed channel causes a panic
sync_send(ChannelPid, Msg) ->
    ChannelPid ! {send, self(), Msg},
    receive
        ok -> ok;
        {error, closed} -> {error, closed}
    end.

%% sync_recv(ChannelPid) -> {ok, Msg} | closed
%% Receives a message from the channel (like Go's msg := <-ch)
%% Blocks until a sender is ready to send
%% Returns: {ok, Msg} if successful, 'closed' if channel is closed
sync_recv(ChannelPid) ->
    ChannelPid ! {recv, self()},
    receive
        {ok, Msg} -> {ok, Msg};
        closed -> closed
    end.

%% sync_close(ChannelPid) -> ok | {error, already_closed}
%% Closes the channel (like Go's close(ch))
%% From https://go.dev/tour/concurrency/4:
%% Note: Only the sender should close a channel, never the receiver.
%% In Go, closing an already-closed channel causes a panic
sync_close(ChannelPid) ->
    ChannelPid ! {close_channel, self()},
    receive
        ok -> ok;
        {error, already_closed} -> {error, already_closed}
    end.

%% ---------------------------------------------------------------------------
%% ASYNCHRONOUS (BUFFERED) CHANNELS
%% ---------------------------------------------------------------------------

%% async_new(Capacity) -> ChannelPid
%% Creates a new asynchronous (buffered) channel (like Go's make(chan T, capacity))
%% Capacity: maximum number of messages that can be buffered
%% Returns: Pid of the channel process
async_new(Capacity) ->
    %% Initiate asynchronous channel process with an internal loop
    %% and (unbounded) queue for buffering messages, but specify
    %% the capacity limit for blocking behavior.
    %% Also, initialize with empty waiting receivers and senders
    %% lists, and closed = false
    spawn(fun() -> async_channel_loop(queue:new(), Capacity, queue:new(), queue:new(), false) end).

%% Internal Channel Process for Asynchronous Channels
%%
%% Buffer: queue of buffered messages
%% Capacity: maximum buffer size
%% WaitingReceivers: list of receiver PIDs waiting for messages
%% WaitingSenders: list of sender PIDs and msg waiting for buffer space
%% Closed: boolean indicating if channel is closed
%%
%% The channel process loop maintains the state of waiting receivers and
%% the message buffer.
%% The function waits for messages of the following patterns:
%%   1 {send, SenderPid, Msg} - a sender wants to send a message
%%   2 {recv, RecvPid} - a receiver wants to receive a message
%%   3 {close_channel, CloserPid} - a request to close the channel
%%
%% The channel process handles these messages according to whether
%% the channel is closed, whether there are waiting receivers or
%% senders.
async_channel_loop(Buffer, Capacity, WaitingReceivers, WaitingSenders, Closed) ->
    BufferSize = queue:len(Buffer),
    receive
        {send, SenderPid, Msg} ->
            %% Sender wants to send a message
            if
                Closed ->
                    %% Send on closed channel - panic in Go!
                    %% In Erlang, we notify sender with error and print to console
                    exit(SenderPid, {panic, send_on_closed_channel}),
                    async_channel_loop(Buffer, Capacity, WaitingReceivers, WaitingSenders, Closed);
                true ->
                    case queue:out(WaitingReceivers) of
                        {{value, RecvPid}, RestReceivers} ->
                            %% Receiver waiting! Send directly (bypass buffer)
                            RecvPid ! {ok, Msg},
                            SenderPid ! ok,
                            async_channel_loop(Buffer, Capacity, RestReceivers, WaitingSenders, Closed);
                        {empty, _} ->
                            %% No receiver waiting, check buffer space
                            if
                                BufferSize < Capacity ->
                                    %% Buffer has space, accept message immediately
                                    NewBuffer = queue:in(Msg, Buffer),
                                    SenderPid ! ok,
                                    async_channel_loop(NewBuffer, Capacity, WaitingReceivers, WaitingSenders, Closed);
                                true ->
                                    %% Buffer full, sender must block
                                    %% Store sender in waiting sender list
                                    NewWaitingSenders = queue:in({SenderPid, Msg}, WaitingSenders),
                                    async_channel_loop(Buffer, Capacity, WaitingReceivers, NewWaitingSenders, Closed)
                            end
                    end
            end;

        {recv, RecvPid} ->
            %% Receiver wants to receive a message
            case queue:out(Buffer) of
                {{value, Msg}, NewBuffer} ->
                    %% Message in buffer, deliver it
                    RecvPid ! {ok, Msg},
                    %% Check if senders are waiting and unblock one because buffer space is now available
                    case queue:out(WaitingSenders) of
                        {{value, {WaitingSenderPid, WaitingMsg}}, RestSenders} ->
                            %% Sender waiting, add their message to buffer and unblock
                            NewBuffer2 = queue:in(WaitingMsg, NewBuffer),
                            WaitingSenderPid ! ok,
                            async_channel_loop(NewBuffer2, Capacity, WaitingReceivers, RestSenders, Closed);
                        {empty, _} ->
                            %% No senders waiting
                            async_channel_loop(NewBuffer, Capacity, WaitingReceivers, WaitingSenders, Closed)
                    end;
                {empty, _} ->
                    %% Buffer empty
                    if
                        Closed ->
                            %% Buffer empty and channel closed
                            RecvPid ! closed,
                            async_channel_loop(Buffer, Capacity, WaitingReceivers, WaitingSenders, Closed);
                        true ->
                            %% Buffer empty, receiver must block
                            case queue:out(WaitingSenders) of
                                %% Check if senders are waiting first
                                {{value, {SenderPid, Msg}}, RestSenders} ->
                                    %% Sender waiting! Direct handoff to receiver
                                    RecvPid ! {ok, Msg},
                                    SenderPid ! ok,
                                    %% This is a "bad" case indicating that we have waiting senders but no
                                    %% buffered messages. In a well-behaved program, this should not happen
                                    %% because if senders are waiting, the buffer should be full.
                                    %% However, we handle it gracefully by doing a direct handoff and then
                                    %% checking for more waiting senders.
                                    async_channel_loop(Buffer, Capacity, WaitingReceivers, RestSenders, Closed);
                                {empty, _} ->
                                    %% No senders waiting, receiver must wait
                                    NewWaitingReceivers = queue:in(RecvPid, WaitingReceivers),
                                    async_channel_loop(Buffer, Capacity, NewWaitingReceivers, WaitingSenders, Closed)
                            end
                    end
            end;

        {close_channel, CloserPid} ->
            if
                Closed ->
                    %% Close of closed channel - panic in Go!
                    %% In Erlang, we print to console and notify caller
                    exit(CloserPid, {panic, close_of_closed_channel}),
                    async_channel_loop(Buffer, Capacity, WaitingReceivers, WaitingSenders, Closed);
                true ->
                    %% Mark channel as closed, notify all waiting receivers and senders
                    lists:foreach(fun(RecvPid) -> RecvPid ! closed end, queue:to_list(WaitingReceivers)),
                    lists:foreach(fun({SenderPid, _}) -> SenderPid ! {error, closed} end, queue:to_list(WaitingSenders)),
                    %% We do NOT explicitly empty the buffer here because in Go, closing a channel
                    %% does not discard buffered messages. Receivers can still receive buffered
                    %% messages until the buffer is empty per https://go.dev/ref/spec#Close
                    CloserPid ! ok,
                    async_channel_loop(Buffer, Capacity, queue:new(), queue:new(), true)
            end
    end.%% async_send(ChannelPid, Msg) -> ok | {error, closed}
%% Sends a message on the buffered channel (like Go's ch <- msg)
%% Does not block if buffer has space; blocks if buffer is full
%% In Go, sending on a closed channel causes a panic
async_send(ChannelPid, Msg) ->
    ChannelPid ! {send, self(), Msg},
    receive
        ok -> ok;
        {error, closed} -> {error, closed}
    end.

%% async_recv(ChannelPid) -> {ok, Msg} | closed
%% Receives a message from the buffered channel (like Go's msg := <-ch)
%% Does not block if buffer has messages; blocks if buffer is empty
%% Returns: {ok, Msg} if successful, 'closed' if channel is closed and empty
async_recv(ChannelPid) ->
    ChannelPid ! {recv, self()},
    receive
        {ok, Msg} -> {ok, Msg};
        closed -> closed
    end.

%% async_close(ChannelPid) -> ok | {error, already_closed}
%% Closes the buffered channel (like Go's close(ch))
%% From https://go.dev/tour/concurrency/4:
%% Note: Only the sender should close a channel, never the receiver.
%% In Go, closing an already-closed channel causes a panic
async_close(ChannelPid) ->
    ChannelPid ! {close_channel, self()},
    receive
        ok -> ok;
        {error, already_closed} -> {error, already_closed}
    end.

%% ---------------------------------------------------------------------------
%% CHANNEL MOBILITY
%% ---------------------------------------------------------------------------

%% In our Erlang encoding, channels are represented as PIDs therefore channel
%% mobility is inherently supported without any special handling. You can send
%% a channel as follows:
%%
%% Example:
%%   Ch1 = sync_new(),           % Create first channel
%%   Ch2 = sync_new(),           % Create second channel
%%   sync_send(Ch1, Ch2),        % Send Ch2 through Ch1
%%   {ok, ReceivedCh} = sync_recv(Ch1),  % Receive the channel
%%   sync_send(ReceivedCh, 42),  % Use the received channel
%%
%% This works for both sync_* and async_* channel functions.


%% ---------------------------------------------------------------------------
%% PANIC UTILITIES (Go-like panic/recover model)
%% ---------------------------------------------------------------------------

%% panic(Reason) -> no_return()
%% Kills the calling process with a reason, like Go's panic().
%% The process dies and propagates to linked processes unless caught.
panic(Reason) ->
    io:format("panic: ~p in process ~p~n", [Reason, self()]),
    exit(Reason).

%% recover(Fun) -> {ok, Result} | {panic, Reason}
%% Executes Fun and catches any panic (exit signal).
%% Like Go's defer + recover() pattern.
recover(Fun) ->
    try Fun() of
        Result -> {ok, Result}
    catch
        exit:Reason -> {panic, Reason};
        error:Reason -> {panic, Reason}
    end.