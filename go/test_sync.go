package main

import (
	"fmt"
	"sync"
	"time"
)

// -------------------------------------------------------------------------
// SYNCHRONOUS COMMUNICATION
// From https://go.dev/tour/concurrency/2: By default, sends and receives
// block until the other side is ready. This allows goroutines to synchronize
// without explicit locks or condition variables.
// -------------------------------------------------------------------------

func test_sync_sender(ch chan int, msgs int) {
	for i := 0; i < msgs; i++ {
		ch <- i // blocks until receiver is ready
	}
	close(ch) // signal "no more values"
}

func test_sync_receiver(ch chan int) {
	for msg := range ch { // loops until channel is closed
		fmt.Println("[sync] Receiver got:", msg)
	}
	fmt.Println("[sync] Receiver: channel closed, no more messages, done receiving")
}

func test_sync() {
	ch := make(chan int)
	var wg sync.WaitGroup

	wg.Add(2)

	fmt.Println("[sync] Spawned receiver goroutine...")
	go func() {
		defer wg.Done()
		test_sync_receiver(ch)
	}()

	time.Sleep(100 * time.Millisecond) // Ensure receiver is ready before sender starts

	fmt.Println("[sync] Spawned sender goroutine...")
	go func() {
		defer wg.Done()
		test_sync_sender(ch, 3)
	}()

	wg.Wait() // blocks until all Done() are called

}

// -------------------------------------------------------------------------
// MAIN
// -------------------------------------------------------------------------

func main() {
	fmt.Println("--- Synchronous ---")
	test_sync()
}
