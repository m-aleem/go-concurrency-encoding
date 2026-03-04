package main

import (
	"fmt"
	"sync"
	"time"
)

// ---------------------------------------------------------------------------
// ASYNCHRONOUS COMMUNICATION
// From https://go.dev/ref/spec#Channel_types: The capacity, in number of
// elements, sets the size of the buffer in the channel. If the capacity is
// zero or absent, the channel is unbuffered and communication succeeds only
// when both a sender and receiver are ready. Otherwise, the channel is buffered
// and communication succeeds without blocking if the buffer is not full (sends)
// or not empty (receives). A nil channel is never ready for communication.
// ---------------------------------------------------------------------------
func test_async_sender(ch chan int, msgs int) {
	for i := 0; i < msgs; i++ {
		ch <- i // does not block if buffer has space
		fmt.Printf("[async: single sender] Sender sent: %d\n", i)
	}
	close(ch) // signal "no more values"
}

func test_async_receiver(ch chan int) {
	for msg := range ch { // loops until channel is closed
		fmt.Println("[async: single sender] Receiver got:", msg)
		time.Sleep(200 * time.Millisecond) // Simulate slower receiver to demonstrate buffering
	}
	fmt.Println("[async: single sender] Receiver: channel closed, no more messages, done receiving")
}

func test_async() {
	ch := make(chan int, 2) // buffered channel with capacity 2
	var wg sync.WaitGroup

	wg.Add(2)

	fmt.Println("[async: single sender] Spawned receiver goroutine...")
	go func() {
		defer wg.Done()
		test_async_receiver(ch)
	}()

	time.Sleep(100 * time.Millisecond) // Ensure receiver is ready before sender starts

	fmt.Println("[async: single sender] Spawned sender goroutine...")
	go func() {
		defer wg.Done()
		test_async_sender(ch, 5) // send 5 messages (buffer is only 2)
	}()

	wg.Wait() // blocks until all Done() are called
}

func test_async_multiple_blocked_senders() {
	ch := make(chan int, 2) // buffered channel with capacity 2
	var wg sync.WaitGroup

	// Fill the buffer first
	ch <- 1
	ch <- 2
	fmt.Println("[async: multi-sender] Buffer filled with [1, 2]")

	// Spawn 3 senders that will all block (buffer is full)
	for i := 3; i <= 5; i++ {
		wg.Add(1)
		senderID := i
		go func() {
			defer wg.Done()
			fmt.Printf("[async: multi-sender] Sender %d attempting to send...\n", senderID)
			ch <- senderID // This will block because buffer is full
			fmt.Printf("[async: multi-sender] Sender %d completed send\n", senderID)
		}()
	}

	time.Sleep(100 * time.Millisecond) // Let all senders block

	fmt.Println("[async: multi-sender] All 3 senders are now blocked. Starting receiver...")

	// Now receive messages one by one
	// Each receive should unblock one sender
	for i := 1; i <= 5; i++ {
		msg := <-ch
		fmt.Printf("[async: multi-sender] Receiver got: %d\n", msg)
		time.Sleep(200 * time.Millisecond) // Slow down to see sender unblocking
	}

	wg.Wait()
	close(ch)
	fmt.Println("[async: multi-sender] Test complete")
}

// ---------------------------------------------------------------------------
// MAIN
// ---------------------------------------------------------------------------

func test_async_main() {
	fmt.Println("--- Asynchronous ---")
	test_async()
	test_async_multiple_blocked_senders()
	fmt.Println("--- End Asynchronous --\n")
}
