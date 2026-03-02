package main

import (
	"fmt"
	"sync"
)

// ---------------------------------------------------------------------------
// CHANNEL MOBILITY
// In Go, channels can be sent through other channels.
// This works for both synchronous and asynchronous (buffered) channels.
// ---------------------------------------------------------------------------

// Test 1: Mobility with synchronous channels

func test_mobility_sync_worker(id int, requestChan chan chan int, wg *sync.WaitGroup) {
	defer wg.Done()

	// Create a response channel (synchronous)
	responseChan := make(chan int)

	// Send our response channel through the request channel
	fmt.Printf("[mobility-sync] Worker %d: sending response channel\n", id)
	requestChan <- responseChan

	// Wait for result on our response channel
	result := <-responseChan
	fmt.Printf("[mobility-sync] Worker %d: received result %d\n", id, result)
}

func test_mobility_sync_server(requestChan chan chan int, wg *sync.WaitGroup) {
	defer wg.Done()

	// Receive a response channel from a worker
	responseChan := <-requestChan
	fmt.Println("[mobility-sync] Server: received response channel from worker")

	// Send result back through the received channel
	result := 42
	fmt.Printf("[mobility-sync] Server: sending result %d through received channel\n", result)
	responseChan <- result
}

func test_mobility_sync() {
	// Channel that carries channels! (synchronous)
	requestChan := make(chan chan int)

	var wg sync.WaitGroup
	wg.Add(2)

	fmt.Println("[mobility-sync] Starting worker...")
	go test_mobility_sync_worker(1, requestChan, &wg)

	fmt.Println("[mobility-sync] Starting server...")
	go test_mobility_sync_server(requestChan, &wg)

	wg.Wait()
	fmt.Println("[mobility-sync] Done!")
}

// Test 2: Mobility with asynchronous (buffered) channels

func test_mobility_async_worker(id int, requestChan chan chan int, wg *sync.WaitGroup) {
	defer wg.Done()

	// Create a response channel (asynchronous with buffer)
	responseChan := make(chan int, 2)

	// Send our response channel through the request channel
	fmt.Printf("[mobility-async] Worker %d: sending response channel\n", id)
	requestChan <- responseChan

	// Wait for result on our response channel
	result := <-responseChan
	fmt.Printf("[mobility-async] Worker %d: received result %d\n", id, result)
}

func test_mobility_async_server(requestChan chan chan int, wg *sync.WaitGroup) {
	defer wg.Done()

	// Receive a response channel from a worker
	responseChan := <-requestChan
	fmt.Println("[mobility-async] Server: received response channel from worker")

	// Send result back through the received channel (won't block due to buffer)
	result := 99
	fmt.Printf("[mobility-async] Server: sending result %d through received channel\n", result)
	responseChan <- result
}

func test_mobility_async() {
	// Channel that carries channels! (synchronous carrier, but carries async channels)
	requestChan := make(chan chan int)

	var wg sync.WaitGroup
	wg.Add(2)

	fmt.Println("[mobility-async] Starting worker...")
	go test_mobility_async_worker(1, requestChan, &wg)

	fmt.Println("[mobility-async] Starting server...")
	go test_mobility_async_server(requestChan, &wg)

	wg.Wait()
	fmt.Println("[mobility-async] Done!")
}

// ---------------------------------------------------------------------------
// MAIN
// ---------------------------------------------------------------------------

func test_mobility_main() {
	fmt.Println("--- Mobility ---")

	fmt.Println("\n------ Mobility 1: Synchronous ------")
	test_mobility_sync()

	fmt.Println("\n------ Mobility 2: Asynchronous ------")
	test_mobility_async()

	fmt.Println("--- End Mobility --\n")
}
