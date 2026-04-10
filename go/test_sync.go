package main

import (
	"fmt"
	"sync"
	"time"
)

// ---------------------------------------------------------------------------
// SYNCHRONOUS COMMUNICATION
// From https://go.dev/tour/concurrency/2: By default, sends and receives
// block until the other side is ready. This allows goroutines to synchronize
// without explicit locks or condition variables.
// ---------------------------------------------------------------------------

func test_sync_sender(ch chan int, msgs int) {
	for i := 0; i < msgs; i++ {
		ch <- i // blocks until receiver is ready
	}
	close(ch) // signal "no more values"
}

func test_sync_receiver(ch chan int) {
	for msg := range ch { // loops until channel is closed
		fmt.Println("[sync: single sender] Receiver got:", msg)
	}
	fmt.Println("[sync: single sender] Receiver: channel closed, no more messages, done receiving")
}

func test_sync() {
	ch := make(chan int)
	var wg sync.WaitGroup

	wg.Add(2)

	fmt.Println("[sync: single sender] Spawned receiver goroutine...")
	go func() {
		defer wg.Done()
		test_sync_receiver(ch)
	}()

	time.Sleep(100 * time.Millisecond) // Ensure receiver is ready before sender starts

	fmt.Println("[sync: single sender] Spawned sender goroutine...")
	go func() {
		defer wg.Done()
		test_sync_sender(ch, 3)
	}()

	wg.Wait() // blocks until all Done() are called

}

func test_sync_multiple_blocked_senders() {
	ch := make(chan int)
	var wg sync.WaitGroup

	// Spawn 4 senders that will all block (buffer is full)
	n_senders := 4
	for i := 1; i <= 4; i++ {
		wg.Add(1)
		senderID := i
		go func() {
			defer wg.Done()
			fmt.Printf("[sync: multi-sender] Sender %d attempting to send...\n", senderID)
			ch <- senderID // This will block because receiver is not ready yet
			fmt.Printf("[sync: multi-sender] Sender %d completed send\n", senderID)
		}()
	}

	time.Sleep(100 * time.Millisecond) // Let all senders block

	fmt.Printf("[sync: multi-sender] All %d senders are now blocked. Starting receiver...\n", n_senders)

	// Now receive messages one by one
	// Each receive should unblock one sender
	for i := 1; i <= n_senders; i++ {
		msg := <-ch
		fmt.Printf("[sync: multi-sender] Receiver got: %d\n", msg)
		time.Sleep(200 * time.Millisecond) // Slow down to see sender unblocking
	}

	wg.Wait()
	close(ch)
	fmt.Println("[sync: multi-sender] Test complete")
}

// ---------------------------------------------------------------------------
// MAIN
// ---------------------------------------------------------------------------

func test_sync_main() {
	fmt.Println("\n--- Synchronous tests ---")

	fmt.Println("------ Sync 1: Send on an open channel (one sender, one receiver) ------")
	test_sync()

	fmt.Println("\n------ Sync 2: Send on an open channel (multiple senders, one receiver) ------")
	test_sync_multiple_blocked_senders()

	fmt.Println("--- End Synchronous tests ---")
}
