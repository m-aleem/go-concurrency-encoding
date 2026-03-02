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
		fmt.Printf("[async] Sender sent: %d\n", i)
	}
	close(ch) // signal "no more values"
}

func test_async_receiver(ch chan int) {
	for msg := range ch { // loops until channel is closed
		fmt.Println("[async] Receiver got:", msg)
		time.Sleep(200 * time.Millisecond) // Simulate slower receiver to demonstrate buffering
	}
	fmt.Println("[async] Receiver: channel closed, no more messages, done receiving")
}

func test_async() {
	ch := make(chan int, 2) // buffered channel with capacity 2
	var wg sync.WaitGroup

	wg.Add(2)

	fmt.Println("[async] Spawned receiver goroutine...")
	go func() {
		defer wg.Done()
		test_async_receiver(ch)
	}()

	time.Sleep(100 * time.Millisecond) // Ensure receiver is ready before sender starts

	fmt.Println("[async] Spawned sender goroutine...")
	go func() {
		defer wg.Done()
		test_async_sender(ch, 5) // send 5 messages (buffer is only 2)
	}()

	wg.Wait() // blocks until all Done() are called
}

// ---------------------------------------------------------------------------
// MAIN
// ---------------------------------------------------------------------------

func test_async_main() {
	fmt.Println("--- Asynchronous ---")
	test_async()
	fmt.Println("--- End Asynchronous --\n")
}
