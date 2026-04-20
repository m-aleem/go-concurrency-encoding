package main

import (
	"fmt"
	"sync"
	"testing"
	"time"
)

// --- Test 1: Sync typed channel accepts correct type ---
// This test demonstrates that a typed channel only accepts values of the specified type and the receiver receives the correct type and value.
func TestTypedSyncChannelAccept(t *testing.T) {
	fmt.Println("------ Typing 1: Sync typed channel accepts correct type ------")
	expectedResult := 1
	expectedType := fmt.Sprintf("%T", expectedResult)

	var got any
	var gotType string

	ch := make(chan int) // typed channel
	var wg sync.WaitGroup

	wg.Add(2)

	fmt.Println("[typing] Spawned receiver goroutine...")
	go func() {
		defer wg.Done()
		for msg := range ch { // loops until channel is closed
			fmt.Printf("[typing] Receiver got type: %T, value: %v\n", msg, msg)
			got = msg
			gotType = fmt.Sprintf("%T", msg)
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

	if expectedType != gotType {
		t.Fatalf("[typing] Expected type %s, got %T\n", expectedType, expectedResult)
	} else {
		fmt.Printf("[typing] Expected type %s, got %T\n", expectedType, got)
	}

	if expectedResult != got {
		t.Fatalf("[typing] Expected value %v, got %v\n", expectedResult, got)
	} else {
		fmt.Printf("[typing] Expected value %v, got %v\n", expectedResult, got)
	}
}

// --- Test 2: Sync typed channel rejects wrong type ---
// This test demonstrates that a typed channel does not accept values of the wrong type and causes a compile-time error.
func TestTypedSyncChannelReject(t *testing.T) {
	fmt.Println("------ Typing 2: Sync typed channel rejects wrong type ------")
	fmt.Printf("[typing] This test will cause a compile-time error due to type mismatch.\n")
}

// --- Test 3: Sync typed channel accepts any type ---
// This test demonstrates that an untyped channel (chan any) can accept values of any type and the receiver receives the correct types and values.
func TestTypedSyncChannelAcceptAny(t *testing.T) {
	fmt.Println("------ Typing 3: Sync untyped channel accepts any type ------")
	expectedResult := []any{42, "hello"}
	expectedType := []string{"int", "string"}

	var got []any
	var gotType []string

	ch := make(chan any) // any channel
	var wg sync.WaitGroup

	wg.Add(2)

	fmt.Println("[typing] Spawned receiver goroutine...")
	go func() {
		defer wg.Done()
		for msg := range ch { // loops until channel is closed
			fmt.Printf("[typing] Receiver got type: %T, value: %v\n", msg, msg)
			got = append(got, msg)
			gotType = append(gotType, fmt.Sprintf("%T", msg))
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

	// compare slices of types and values
	assert_equal(t, gotType, expectedType, "[typing]")
	assert_equal(t, got, expectedResult, "[typing]")
}

// --- Test 4: Async typed channel accepts correct type ---
// This test demonstrates that a typed channel only accepts values of the specified type and the receiver receives the correct type and value.
func TestTypedAsyncChannelAccept(t *testing.T) {
	fmt.Println("------ Typing 4: Async typed channel accepts correct type ------")
	expectedResult := []int{42, 1}
	expectedType := []string{"int", "int"}

	var got []int
	var gotType []string

	ch := make(chan int, 2) // buffered typed channel
	var wg sync.WaitGroup

	wg.Add(2)

	fmt.Println("[typing] Spawned receiver goroutine...")
	go func() {
		defer wg.Done()
		for msg := range ch { // loops until channel is closed
			fmt.Printf("[typing] Receiver got type: %T, value: %v\n", msg, msg)
			got = append(got, msg)
			gotType = append(gotType, fmt.Sprintf("%T", msg))
		}
		fmt.Println("[typing] Receiver: channel closed, no more messages, done receiving")
	}()

	time.Sleep(100 * time.Millisecond) // Ensure receiver is ready before sender starts

	fmt.Println("[typing] Spawned sender goroutine...")
	go func() {
		defer wg.Done()
		ch <- 42  // send correct type message
		ch <- 1   // send correct type message
		close(ch) // signal "no more values"
	}()

	wg.Wait() // blocks until all Done() are called

	// compare slices of types and values
	assert_equal(t, gotType, expectedType, "[typing]")
	assert_equal(t, got, expectedResult, "[typing]")
}

// --- Test 5: Async typed channel rejects wrong type ---
// This test demonstrates that a typed channel does not accept values of the wrong type and causes a compile-time error.
func TestTypedAsyncChannelReject(t *testing.T) {
	fmt.Println("------ Typing 5: Async typed channel rejects wrong type ------")
	fmt.Printf("[typing] This test will cause a compile-time error due to type mismatch.\n")
}

// --- Test 6: Async typed channel accepts any type ---
// This test demonstrates that an untyped channel (chan any) can accept values of any type and the receiver receives the correct types and values.
func TestTypedAsyncChannelAcceptAny(t *testing.T) {
	fmt.Println("------ Typing 6: Async untyped channel accepts any type ------")
	expectedResult := []any{42, "hello"}
	expectedType := []string{"int", "string"}

	var got []any
	var gotType []string

	ch := make(chan any, 2) // any channel buffered
	var wg sync.WaitGroup

	wg.Add(2)

	fmt.Println("[typing] Spawned receiver goroutine...")
	go func() {
		defer wg.Done()
		for msg := range ch { // loops until channel is closed
			fmt.Printf("[typing] Receiver got type: %T, value: %v\n", msg, msg)
			got = append(got, msg)
			gotType = append(gotType, fmt.Sprintf("%T", msg))
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

	// compare slices of types and values
	assert_equal(t, gotType, expectedType, "[typing]")
	assert_equal(t, got, expectedResult, "[typing]")
}
