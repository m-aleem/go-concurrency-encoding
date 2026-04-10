package main

import (
	"fmt"
	"sync"
	"time"
)

// --- Test 1: Sync typed channel accepts correct type ---
func test_sync_typed_accept() {
	ch := make(chan int) // typed channel
	var wg sync.WaitGroup

	wg.Add(2)

	fmt.Println("[typing] Spawned receiver goroutine...")
	go func() {
		defer wg.Done()
		for msg := range ch { // loops until channel is closed
			fmt.Println("[typing] Receiver got right type:", msg)
		}
		fmt.Println("[typing] Receiver: channel closed, no more messages, done receiving")
	}()

	time.Sleep(100 * time.Millisecond) // Ensure receiver is ready before sender starts

	fmt.Println("[typing] Spawned sender goroutine...")
	go func() {
		defer wg.Done()
		ch <- 1   // send correct type message
		close(ch) // signal "no more values"
	}()

	wg.Wait() // blocks until all Done() are called
}

// --- Test 2: Sync typed channel rejects wrong type ---
func test_sync_typed_reject() {
	fmt.Printf("[typing] This test will cause a compile-time error due to type mismatch.\n")
}

// --- Test 3: Sync typed channel accepts any type ---
func test_sync_any_typed_accept() {
	ch := make(chan any) // any type
	var wg sync.WaitGroup

	wg.Add(2)

	fmt.Println("[typing] Spawned receiver goroutine...")
	go func() {
		defer wg.Done()
		for msg := range ch { // loops until channel is closed
			fmt.Println("[typing] Receiver got:", msg)
		}
		fmt.Println("[typing] Receiver: channel closed, no more messages, done receiving")
	}()

	time.Sleep(100 * time.Millisecond) // Ensure receiver is ready before sender starts

	fmt.Println("[typing] Spawned sender goroutine...")
	go func() {
		defer wg.Done()

		// send any type of message
		ch <- 42
		ch <- "hello"

		close(ch) // signal "no more values"
	}()

	wg.Wait() // blocks until all Done() are called
}

// --- Test 4: Async typed channel accepts correct type ---
func test_async_typed_accept() {
	ch := make(chan int, 2) // buffered channel with capacity 2
	var wg sync.WaitGroup

	wg.Add(2)

	fmt.Println("[typing] Spawned receiver goroutine...")
	go func() {
		defer wg.Done()
		for msg := range ch { // loops until channel is closed
			fmt.Println("[typing] Receiver got:", msg)
			time.Sleep(200 * time.Millisecond) // Simulate slower receiver to demonstrate buffering
		}
		fmt.Println("[typing] Receiver: channel closed, no more messages, done receiving")
	}()

	time.Sleep(100 * time.Millisecond) // Ensure receiver is ready before sender starts

	fmt.Println("[typing] Spawned sender goroutine...")
	go func() {
		defer wg.Done()

		arr := []int{42, 1}
		for _, i := range arr {
			ch <- i // send correct type message
		}
		close(ch)
	}()

	wg.Wait() // blocks until all Done() are called
}

// --- Test 5: Async typed channel rejects wrong type ---
func test_async_typed_reject() {
	fmt.Printf("[typing] This test will cause a compile-time error due to type mismatch.\n")
}

// --- Test 6: Async typed channel accepts any type ---
func test_async_any_typed_accept() {
	ch := make(chan any, 2) // any type with buffer size 2
	var wg sync.WaitGroup

	wg.Add(2)

	fmt.Println("[typing] Spawned receiver goroutine...")
	go func() {
		defer wg.Done()

		for msg := range ch { // loops until channel is closed
			fmt.Println("[typing] Receiver got:", msg)
			time.Sleep(200 * time.Millisecond) // Simulate slower receiver to demonstrate buffering
		}
		fmt.Println("[typing] Receiver: channel closed, no more messages, done receiving")
	}()

	time.Sleep(100 * time.Millisecond) // Ensure receiver is ready before sender starts

	fmt.Println("[typing] Spawned sender goroutine...")
	go func() {
		defer wg.Done()

		// send any type of message
		ch <- 42
		ch <- "hello"

		close(ch) // signal "no more values"
	}()

	wg.Wait() // blocks until all Done() are called
}

// ---------------------------------------------------------------------------
// MAIN
// ---------------------------------------------------------------------------

func test_typing_main() {
	fmt.Println("\n--- Typing Tests ---")

	fmt.Println("------ Typing 1: Sync typed channel accepts correct type ------")
	test_sync_typed_accept()

	fmt.Println("\n------ Typing 2: Sync typed channel rejects wrong type ------")
	test_sync_typed_reject()

	fmt.Println("\n------ Typing 3: Sync typed channel accepts any type ------")
	test_sync_any_typed_accept()

	fmt.Println("\n------ Typing 4: Async typed channel accepts correct type ------")
	test_async_typed_accept()

	fmt.Println("\n------ Typing 5: Async typed channel rejects wrong type ------")
	test_async_typed_reject()

	fmt.Println("\n------ Typing 6: Async typed channel accepts any type ------")
	test_async_any_typed_accept()

	fmt.Println("--- End Typing Tests ---")
}
