package main

import (
	"fmt"
	"sync"
	"testing"
)

// ---------------------------------------------------------------------------
// CHANNEL MOBILITY
// In Go, channels can be sent through other channels.
// This works for both synchronous and asynchronous (buffered) channels.
// ---------------------------------------------------------------------------

// Test 1: Mobility with synchronous channels
// This test demonstrates that a client can send an sync channel to the sync channel server, and the server can send the response through that channel.
func TestMobilitySync(t *testing.T) {
	fmt.Println("------ Mobility 1: Synchronous ------")

	var result int
	expectedResult := 1

	// Channel that carries channels! (synchronous)
	serverCh := make(chan chan int)

	var wg sync.WaitGroup
	wg.Add(2)

	go func() {
		result = sync_client(1, serverCh, &wg)
	}()

	go sync_server(serverCh, &wg)

	wg.Wait()

	if result != expectedResult {
		t.Fatalf("expected result %d, got %d", expectedResult, result)
	}
}

// Test 2: Mobility with asynchronous (buffered) channels
// This test demonstrates that a client can send an async channel to the sync channel server, and the server can send multiple results back through that channel.
func TestMobilityAsync(t *testing.T) {
	fmt.Println("------ Mobility 2: Asynchronous ------")

	gotResults := []int{}
	expectedResult := []int{1, 2, 3}

	// Channel that carries channels! (synchronous)
	serverCh := make(chan chan int)

	var wg sync.WaitGroup
	wg.Add(2)

	go func() {
		gotResults = async_client(1, serverCh, &wg)
	}()

	go async_server(serverCh, &wg)

	wg.Wait()

	if len(gotResults) != len(expectedResult) {
		t.Fatalf("expected %d results, got %d", len(expectedResult), len(gotResults))
	}

	for i, got := range gotResults {
		if got != expectedResult[i] {
			t.Fatalf("expected result %d at index %d, got %d", expectedResult[i], i, got)
		}
	}
}
