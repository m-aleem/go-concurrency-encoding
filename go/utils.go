package main

import (
	"fmt"
	"reflect"
	"sync"
	"testing"
	"time"
)

// HELPER FUNCTIONS FOR TESTING

// assert_equal checks that two slices are deeply equal and fails the test if they are not
func assert_equal(t testing.TB, got, want any, msg string) {
	t.Helper() // shows the line of the test that fails

	// using reflect.DeepEqual to compare slices
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("%s got %v, want %v\n", msg, got, want)
	} else {
		fmt.Printf("%s got %v, want %v\n", msg, got, want)
	}
}

// assert_panic checks that a function panics and fails the test if no panic occurs
func assert_panic(t testing.TB, fn func(), msg string) {
	t.Helper()
	defer func() {
		if r := recover(); r == nil {
			t.Fatalf("%s Expected panic but none occurred\n", msg)
		} else {
			fmt.Printf("%s Panic captured correctly: %s\n", msg, r)
		}
	}()
	fn()
}

// ASYNC

// async_sender sends a sequence of integers to the channel and then closes it
func async_sender(ch chan int, msgs int) {
	for i := range msgs {
		ch <- i // does not block if buffer has space
		//fmt.Printf("[async: single sender] Sender sent: %d\n", i)
	}
	close(ch) // signal "no more values"
}

// async_receiver receives integers from the channel until it is closed and returns them as a slice
func async_receiver(ch chan int) []int {
	var received []int
	for msg := range ch { // loops until channel is closed
		fmt.Println("[async: single sender] Receiver got:", msg)
		time.Sleep(200 * time.Millisecond) // Simulate slower receiver to demonstrate buffering
		received = append(received, msg)
	}
	fmt.Println("[async: single sender] Receiver: channel closed, no more messages, done receiving")
	return received
}

// run_async sets up the channel and goroutines for the async test and returns the received messages
func run_async(bufferSize int, msgs int) []int {
	ch := make(chan int, bufferSize) // buffered channel with capacity bufferSize

	var wg sync.WaitGroup
	var received []int

	wg.Add(2)

	fmt.Println("[async: single sender] Spawned receiver goroutine...")
	go func() {
		defer wg.Done()
		received = async_receiver(ch)
	}()

	time.Sleep(100 * time.Millisecond) // Ensure receiver is ready before sender starts

	fmt.Println("[async: single sender] Spawned sender goroutine...")
	go func() {
		defer wg.Done()
		async_sender(ch, msgs)
	}()

	wg.Wait() // blocks until all Done() are called
	return received
}

// async_blocking_receiver receives a message and then closes the channel, which will cause the sender to panic if it tries to send after the channel is closed
func async_blocking_receiver(ch chan int) {
	msg := <-ch // blocks until sender sends a message
	fmt.Println("[close] Async Receiver got:", msg)
	fmt.Println("[close] Async Receiver: about to close channel, will cause sender panic...")
	close(ch)
	fmt.Println("[close] Async Receiver: channel closed")
}

// TEST SYNC

// sync_sender sends a sequence of integers to the channel and then closes it
func sync_sender(ch chan int, msgs int) {
	for i := range msgs {
		ch <- i // blocks until receiver is ready
	}
	close(ch) // signal "no more values"
}

// sync_receiver receives integers from the channel until it is closed and returns them as a slice
func sync_receiver(ch chan int) []int {
	var received []int

	for msg := range ch { // loops until channel is closed
		fmt.Println("[sync: single sender] Receiver got:", msg)
		received = append(received, msg)

	}
	fmt.Println("[sync: single sender] Receiver: channel closed, no more messages, done receiving")
	return received
}

// run_sync sets up the channel and goroutines for the sync test and returns the received messages
func run_sync(msgs int) []int {
	ch := make(chan int)

	var wg sync.WaitGroup
	var received []int

	wg.Add(2)

	fmt.Println("[sync: single sender] Spawned receiver goroutine...")
	go func() {
		defer wg.Done()
		received = sync_receiver(ch)
	}()

	fmt.Println("[sync: single sender] Spawned sender goroutine...")
	go func() {
		defer wg.Done()
		sync_sender(ch, msgs)
	}()

	wg.Wait() // blocks until all Done() are called
	return received
}

// sync_blocking_receiver receives a message and then closes the channel, which will cause the sender to panic if it tries to send after the channel is closed
func sync_blocking_receiver(ch chan int) {
	msg := <-ch // blocks until sender sends a message
	fmt.Println("[close] Sync Receiver got:", msg)
	fmt.Println("[close] Sync Receiver: about to close channel, will cause sender panic...")
	close(ch)
	fmt.Println("[close] Sync Receiver: channel closed")
}

// TEST MOBILITY SYNC

// sync_client creates a client channel, sends it to the server through the server channel, and waits for a response on the client channel
func sync_client(id int, serverCh chan chan int, wg *sync.WaitGroup) int {
	defer wg.Done()

	fmt.Printf("[mobility-sync] Starting Client %d...\n", id)

	// Create a response channel (synchronous)
	clientCh := make(chan int)

	// Send our client channel through the server channel
	fmt.Printf("[mobility-sync] Client %d: sending its channel to the server\n", id)
	serverCh <- clientCh

	// Wait for result on our response channel
	result := <-clientCh
	fmt.Printf("[mobility-sync] Client %d: received result %d\n", id, result)

	return result
}

// sync_server receives a client channel from the server channel, sends a result back through the received channel, and returns the received channel
func sync_server(serverCh chan chan int, wg *sync.WaitGroup) chan int {
	defer wg.Done()

	fmt.Println("[mobility-sync] Starting Server...")

	// Receive a channel from a client through the server channel
	clientCh := <-serverCh
	fmt.Println("[mobility-sync] Server: received a channel from a client")

	// Server sends result back through the received channel
	result := 1
	fmt.Printf("[mobility-sync] Server: sending result %d through received channel\n", result)
	clientCh <- result

	return clientCh
}

// TEST MOBILITY ASYNC

// async_client creates a client channel, sends it to the server through the server channel, and waits for responses on the client channel until it is closed
func async_client(id int, serverCh chan chan int, wg *sync.WaitGroup) []int {
	defer wg.Done()

	fmt.Printf("[mobility-async] Starting Client %d...\n", id)

	// Create a response channel (asynchronous with buffer)
	clientCh := make(chan int, 2)

	// Send our client channel through the server channel
	fmt.Printf("[mobility-async] Client %d: sending its channel to the server\n", id)
	serverCh <- clientCh

	// Wait for result on our response channel
	results := []int{}

	for {
		result, ok := <-clientCh
		if !ok {
			fmt.Printf("[mobility-async] Client %d: channel closed, done receiving results\n", id)
			break
		}
		results = append(results, result)
		fmt.Printf("[mobility-async] Client %d: received result %d\n", id, result)
	}

	return results
}

// async_server receives a client channel from the server channel, sends multiple results back through the received channel, and closes it to signal no more results
func async_server(serverCh chan chan int, wg *sync.WaitGroup) chan int {
	defer wg.Done()

	fmt.Println("[mobility-async] Starting Server...")

	// Receive a channel from a client through the server channel
	clientCh := <-serverCh
	fmt.Println("[mobility-async] Server: received a channel from a client")

	// Server sends result back through the received channel
	results := []int{1, 2, 3}

	for _, result := range results {
		fmt.Printf("[mobility-async] Server: sending result %d through received channel\n", result)
		clientCh <- result
	}

	close(clientCh) // signal to client that no more results will be sent

	return clientCh
}
