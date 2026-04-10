package main

import (
	"fmt"
	"sync"
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
func test_sync_close_sender(ch chan int, msgs int) {
	for i := 0; i < msgs; i++ {
		ch <- i // blocks until receiver is ready
	}
	// close(ch) // signal "no more values"
}

func test_sync_close_receiver(ch chan int) {
	for msg := range ch { // loops until channel is closed
		fmt.Println("[close] Sync Receiver got:", msg)
		if msg == 1 {
			fmt.Println("[close] Sync Receiver: about to close channel, will cause sender panic...")
			close(ch) // signal "no more values"
		}
	}
}

func test_sync_send_closed() {
	ch := make(chan int)
	var wg sync.WaitGroup

	wg.Add(2)

	fmt.Println("[close] Spawned Sync receiver goroutine...")
	go func() {
		defer wg.Done()
		test_sync_close_receiver(ch)
	}()

	time.Sleep(100 * time.Millisecond) // Ensure receiver is ready before sender starts

	fmt.Println("[close] Spawned Sync sender goroutine...")
	go func() {
		defer wg.Done()

		defer func() {
			if r := recover(); r != nil {
				fmt.Println("[close] captured panic:", r)
			}
		}()

		test_sync_close_sender(ch, 5)
	}()

	wg.Wait() // blocks until all Done() are called

}

func test_async_close_sender(ch chan int, msgs int) {
	for i := 0; i < msgs; i++ {
		ch <- i // does not block if buffer has space
		fmt.Printf("[close] async Sender sent: %d\n", i)
	}
	// close(ch) // signal "no more values"
}

func test_async_close_receiver(ch chan int) {
	for msg := range ch { // loops until channel is closed
		fmt.Println("[close] async Receiver got:", msg)
		time.Sleep(200 * time.Millisecond) // Simulate slower receiver to demonstrate buffering
		if msg == 1 {
			fmt.Println("[close] async Receiver: about to close channel, will cause sender panic...")
			close(ch) // signal "no more values"
		}
	}
	fmt.Println("[close] async Receiver: channel closed, no more messages, done receiving")
}

func test_async_send_closed() {
	ch := make(chan int, 2) // buffered channel with capacity 2
	var wg sync.WaitGroup

	wg.Add(2)

	fmt.Println("[close] Spawned async receiver goroutine...")
	go func() {
		defer wg.Done()
		test_async_close_receiver(ch)
	}()

	time.Sleep(100 * time.Millisecond) // Ensure receiver is ready before sender starts

	fmt.Println("[close] Spawned async sender goroutine...")
	go func() {
		defer wg.Done()

		defer func() {
			if r := recover(); r != nil {
				fmt.Println("[close] captured panic:", r)
			}
		}()

		test_async_close_sender(ch, 5) // send 5 messages (buffer is only 2)
	}()

	wg.Wait() // blocks until all Done() are called
}

func test_close_closed() {
	var ch chan int

	defer func() {
		if r := recover(); r != nil {
			fmt.Println("[close] captured panic:", r)
		}
	}()

	fmt.Println("[close closed] Close channel first time")
	close(ch)
	fmt.Println("[close closed] Close channel second time")
	close(ch)

}

func test_async_receiver_closed() {
	ch := make(chan int, 2) // buffered channel
	var wg sync.WaitGroup

	wg.Add(2)

	fmt.Println("[close] Spawned async sender goroutine...")
	go func() {
		defer wg.Done()
		// Send messages to buffer
		ch <- 10
		ch <- 20
		fmt.Println("[close] Sender: sent 10 and 20 to buffer, now closing channel")
		close(ch)
	}()

	fmt.Println("[close] Spawned async receiver goroutine...")
	go func() {
		defer wg.Done()
		// Receive messages
		for {
			val, ok := <-ch
			if !ok {
				fmt.Printf("[close] Receiver: channel closed, received zero value: %d\n", val)
				break
			}
			fmt.Printf("[close] Receiver got: %d\n", val)
		}
	}()

	wg.Wait()
}

// ---------------------------------------------------------------------------
// MAIN
// ---------------------------------------------------------------------------

func test_close_main() {
	fmt.Println("\n--- Close tests ---")

	fmt.Println("------ Close 1: Send on a closed sync channel ------")
	test_sync_send_closed()

	fmt.Println("\n------ Close 2: Send on a closed async channel ------")
	test_async_send_closed()

	fmt.Println("\n------ Close 3: Close a closed channel ------")
	test_close_closed()

	fmt.Println("\n------ Close 4: Receive from a closed async channel ------")
	test_async_receiver_closed()

	// fmt.Println("\n------ Close 4: Close a receive-only channel ------")
	// test_close_receiver()
	// fmt.Println("Fails to compile: cannot close receive-only channel")

	fmt.Println("--- End Close tests ---")
}
