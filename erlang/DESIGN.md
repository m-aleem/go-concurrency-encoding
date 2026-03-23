# Design Decisions for the Erlang Encoding of Go Concurrency

This document explains the key design decisions made while encoding Go's concurrency primitives (channels, panic/recover) into Erlang.

## Channels as Processes

Each channel is implemented as a dedicated Erlang process that maintains its own internal state via a recursive loop. Callers interact with the channel by sending messages (`{send, Pid, Msg}`, `{recv, Pid}`, `{close_channel, Pid}`) and blocking on a `receive` for the channel's reply.

This approach was chosen because:
- Erlang processes are lightweight and map naturally to Go's channel abstraction.
- The channel process can enforce synchronization and ordering guarantees internally, without requiring callers to coordinate with each other.
- Channel PIDs can be passed around freely, which gives us **channel mobility** for free (see below).

## Panic Semantics: Message-Based Instead of `erlang:halt/1`

### The Problem

In Go, a panic (e.g., sending on a closed channel) crashes the **entire program** unless it is recovered within the same goroutine using `defer` + `recover()`. We needed to model this in Erlang.

### Approaches Considered

1. **`erlang:halt/1`** — Halts the entire Erlang VM immediately, killing all processes. This faithfully models an **unrecovered** Go panic but makes it impossible to use `recover`, since `halt` terminates the runtime before any `try/catch` can execute. We initially implemented this approach but discarded it.

2. **`exit(Pid, {panic, Reason})`** (2-arity) — Sends an exit signal from the channel process to the offending caller. The problem is that the panic originates in the **channel process**, not in the caller process. A `try/catch` in the caller cannot intercept an external exit signal unless the caller has `trap_exit` enabled, which changes the process's behavior globally and does not compose well with `recover/1`.

3. **Message + local `exit/1`** (chosen approach) — The channel sends a `{panic, Reason}` message back to the caller. The caller's API function (`sync_send`, `sync_close`, etc.) matches this message and calls `exit({panic, Reason})` locally. Since the `exit/1` happens inside the caller's own process, it can be caught by a surrounding `try/catch`, which is exactly what `recover/1` provides.

### Why This Works

```erlang
%% Channel loop (runs in its own process):
SenderPid ! {panic, send_on_closed_channel},

%% sync_send (runs in the caller's process):
receive
    ok -> ok;
    {panic, Reason} -> panic(Reason)  %% calls exit({panic, Reason})
end.

%% recover wraps the caller in try/catch:
recover(fun() -> sync_send(Ch, 42) end).
%% Returns: {panic, send_on_closed_channel}
```

This models Go's semantics correctly:
- A panic is **recoverable** within the same goroutine (process) via `recover/1`.
- An **unrecovered** panic kills the process and propagates to linked processes via Erlang's standard exit signal mechanism.

## The `panic/1` Function

We provide a `panic(Reason)` function that simply calls `exit({panic, Reason})`. This serves two purposes:

1. **Consistency** — All panics (both channel-induced and user-triggered) use the same `{panic, Reason}` exit format, so `recover/1` catches them uniformly.
2. **Readability** — Calling `panic(Reason)` is more expressive than `exit({panic, Reason})` and mirrors Go's `panic()` function directly.

The `panic/1` function is used both internally by the channel API functions and is exported for direct use in user code.

## Receive on Closed Channel Is Not a Panic

In Go, receiving from a closed channel is **not** a panic — it returns the zero value of the channel's type. We model this by having the channel send back the atom `closed` to the receiver, and `sync_recv`/`async_recv` return `closed` as a normal value:

```erlang
sync_recv(ChannelPid) ->
    ChannelPid ! {recv, self()},
    receive
        {ok, Msg} -> {ok, Msg};
        closed -> closed
    end.
```

Only **sending** on a closed channel and **closing** an already-closed channel cause panics, matching Go's specification.

## Channel Mobility

In Go, channels are first-class values that can be sent through other channels. In our Erlang encoding, channels are just PIDs, which are naturally sendable through any channel:

```erlang
Ch1 = sync_new(),
Ch2 = sync_new(),
sync_send(Ch1, Ch2),            %% Send Ch2 through Ch1
{ok, ReceivedCh} = sync_recv(Ch1),
sync_send(ReceivedCh, 42).     %% Use the received channel
```

No special handling is needed — Erlang's message passing natively supports sending PIDs as message payloads.

## Buffered (Async) Channel Close Behavior

When closing a buffered channel with waiting senders, each waiting sender receives a `{panic, send_on_closed_channel}` message (since they attempted to send on what is now a closed channel). Waiting receivers get `closed`. The buffer is **not** emptied on close — remaining buffered messages can still be received, matching Go's semantics per the [language specification](https://go.dev/ref/spec#Close).

## Channel Typing via Runtime Validation

### The Problem

In Go, channels are typed: `make(chan int)` only accepts integers, and the compiler rejects type mismatches at compile time. Erlang is dynamically typed, so any term can be sent through any channel by default.

### Approach

We add an optional `TypeCheck` parameter (a predicate `fun(Msg) -> boolean()`) to the channel constructors. The channel process validates every message against this predicate **at send time**, before the message enters the channel. If the predicate returns `false`, the sender receives a `{panic, {type_error, Msg}}`, which mirrors Go's behavior of rejecting type-incorrect sends — except at runtime instead of compile time.

```erlang
%% Equivalent to Go's make(chan int)
Ch = sync_new(fun is_integer/1),
sync_send(Ch, 42),        %% ok
sync_send(Ch, "hello"),   %% panic: {type_error, "hello"}

%% Equivalent to Go's make(chan int, 5)
BufCh = async_new(5, fun is_integer/1),

%% Untyped channel (like chan any / chan interface{})
Ch2 = sync_new().          %% accepts any term
```

### Why Validation Lives in the Channel Process

The type check is performed inside the channel process loop, not in the `sync_send`/`async_send` API functions. This ensures that:

1. **The channel owns its type** — just like in Go, the type is a property of the channel, not of the sender. Multiple goroutines (processes) sending to the same channel all get the same type enforcement.
2. **Consistent error semantics** — a type error produces a `{panic, {type_error, Msg}}` message that flows through the same panic mechanism as `send_on_closed_channel`, so `recover/1` catches it uniformly.
3. **No races** — since the channel process is single-threaded, the type check and the state update are atomic.

### Backward Compatibility

The original API (`sync_new/0`, `async_new/1`) continues to work unchanged. These now delegate to `sync_new(fun(_) -> true end)` and `async_new(Capacity, fun(_) -> true end)` respectively, accepting any term — equivalent to Go's `chan any`.

### Type Error as a Panic

A type mismatch on send produces a `{panic, {type_error, Msg}}` that flows through **exactly the same panic mechanism** as the other channel panics. The three panic reasons are:

| Situation | Panic Reason |
|---|---|
| Send on closed channel | `send_on_closed_channel` |
| Close an already-closed channel | `close_of_closed_channel` |
| Send with wrong type | `{type_error, Msg}` |

All three follow the same path: the channel process sends `{panic, Reason}` to the caller, the API function (`sync_send`, `async_send`, etc.) calls `panic(Reason)` (i.e., `exit({panic, Reason})`), and `recover/1` catches it uniformly. An unrecovered type error kills the process just like any other unrecovered panic.

### Available Type Predicates

The `TypeCheck` argument accepts any `fun(term()) -> boolean()`. Erlang's built-in type-checking BIFs (guard functions) map naturally to Go's channel types:

| Erlang BIF | Go equivalent |
|---|---|
| `fun is_integer/1` | `chan int` |
| `fun is_float/1` | `chan float64` |
| `fun is_number/1` | `chan int \| chan float64` (numeric) |
| `fun is_atom/1` | `chan bool` / enum-like |
| `fun is_list/1` | `chan string` / `chan []T` |
| `fun is_binary/1` | `chan []byte` |
| `fun is_tuple/1` | `chan struct{...}` |
| `fun is_pid/1` | `chan chan T` (channel of channels) |
| `fun is_map/1` | `chan map[K]V` |
| `fun is_boolean/1` | `chan bool` |

These are BIFs from the `erlang` module, available without imports. Custom predicates can also be used for more complex type constraints (e.g., `fun(X) -> is_integer(X) andalso X > 0 end` for a channel of positive integers).
