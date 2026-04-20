package main

import (
	"fmt"
	"sync"
	"testing"
	"time"
)

// ---------------------------------------------------------------------------
// CHANNEL CLOSING
// From https://go.dev/ref/spec#Close: For a channel ch, the built-in function
// close(ch) records that no more values will be sent on the channel. It is an
// error if ch is a receive-only channel. Sending to or closing a closed
// channel causes a run-time panic. Closing the nil channel also causes a
// run-time panic. After calling close, and after any previously sent values
// have been received, receive operations will return the zero value for the
// channel's type without blocking. The multi-valued receive operation returns
// a received value along with an indication of whether the channel is closed.
// If the type of the argument to close is a type parameter, all types in its
// type set must be channels. It is an error if any of those channels is a
// receive-only channel.
// ---------------------------------------------------------------------------

// Test 1: Send on a closed sync channel
// This test demonstrates that sending on a closed channel causes a panic.
func TestCloseSyncChannelAndSend(t *testing.T) {
	fmt.Println("------ Close 1: Send on a closed sync channel ------")

	ch := make(chan int)
	var wg sync.WaitGroup

	wg.Add(2)

	fmt.Println("[close] Spawned Sync receiver goroutine...")
	go func() {
		defer wg.Done()
		sync_blocking_receiver(ch)
	}()

	time.Sleep(100 * time.Millisecond) // Ensure receiver is ready before sender starts

	fmt.Println("[close] Spawned Sync sender goroutine...")

	startSenders := func() {
		defer wg.Done()
		// Try to send more messages - will panic because channel is closed
		sync_sender(ch, 4)
	}

	assert_panic(t, startSenders, "[close]")

	wg.Wait() // blocks until all Done() are called
}

// Test 2: Send on a closed async channel
// This test demonstrates that sending on a closed channel causes a panic.
func TestCloseAsyncChannelAndSend(t *testing.T) {
	fmt.Println("------ Close 2: Send on a closed async channel ------")
	ch := make(chan int, 2) // buffered channel with capacity 2
	var wg sync.WaitGroup

	wg.Add(2)

	fmt.Println("[close] Spawned Async receiver goroutine...")
	go func() {
		defer wg.Done()
		async_blocking_receiver(ch)
	}()

	time.Sleep(100 * time.Millisecond) // Ensure receiver is ready before sender starts

	fmt.Println("[close] Spawned Async receiver goroutine...")

	startSenders := func() {
		defer wg.Done()
		// Try to send more messages - will panic because channel is closed
		async_sender(ch, 5)
	}

	assert_panic(t, startSenders, "[close]")

	wg.Wait() // blocks until all Done() are called
}

// Test 3: Close a closed channel
// This test demonstrates that closing a closed channel causes a panic.
func TestCloseClosedChannel(t *testing.T) {
	fmt.Println("------ Close 3: Close a closed channel ------")
	ch := make(chan int)

	close(ch) // ok
	fmt.Println("[close closed] Close the channel first time")

	closeAgain := func() { close(ch) } // panics because channel is already closed

	assert_panic(t, closeAgain, "[close closed]")
}

// Test 4: Receive from a closed async channel
// This test demonstrates that receiving from a closed channel returns the values in the buffeer and then the zero value and does not block.
func TestCloseAsyncChannelAndReceive(t *testing.T) {
	fmt.Println("------ Close 4: Receive from a closed async channel ------")

	ch := make(chan int, 2) // buffered channel
	var wg sync.WaitGroup

	got := []int{}
	want := []int{10, 20, 0} // expect to receive 10, then 20, then zero value (0) after channel is closed

	wg.Add(2)

	fmt.Println("[close] Spawned async sender goroutine...")
	go func() {
		defer wg.Done()
		// Send messages to buffer
		ch <- 10
		ch <- 20
		fmt.Println("[close] Sender: sent 10 and 20 to buffer")
		close(ch)
		fmt.Println("[close] Sender: closed the channel")
	}()

	fmt.Println("[close] Spawned async receiver goroutine...")
	go func() {
		defer wg.Done()

		// Receive messages
		for {
			val, ok := <-ch
			got = append(got, val)
			if !ok {
				fmt.Printf("[close] Receiver: channel closed, received zero value: %d\n", val)
				break
			}
			fmt.Printf("[close] Receiver got: %d\n", val)
		}

	}()

	wg.Wait() // blocks until all Done() are called

	// Check length first
	if len(got) != len(want) {
		t.Fatalf("len(got) = %d, want %d", len(got), len(want))
	}

	// Check contents
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("got[%d] = %d, want %d", i, got[i], want[i])
		}
	}
}
