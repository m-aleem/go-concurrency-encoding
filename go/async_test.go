package main

import (
	"fmt"
	"sync"
	"testing"
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

// Test 1: Send on an open channel (one sender, one receiver)
// This test demonstrates that a sender can send messages to a receiver through a buffered channel without blocking, as long as the buffer is not full.
func TestAsyncSingleSender(t *testing.T) {
	fmt.Println("------ Async 1: Send on an open channel (one sender, one receiver) ------")

	got := run_async(2, 5) // send 5 messages (buffer is only 2)
	want := []int{0, 1, 2, 3, 4}

	assert_equal(t, got, want, "received messages")
}

// Test 2: Send on an open channel (multiple senders, one receiver)
// This test demonstrates that multiple senders can send messages to a receiver through a buffered channel without blocking, as long as the buffer is not full.
func TestAsyncMultipleBlockedSenders(t *testing.T) {
	fmt.Println("------ Async 2: Send on an open channel (multiple senders, one receiver) ------")

	ch := make(chan int, 2) // buffered channel with capacity 2
	var wg sync.WaitGroup

	// Fill the buffer first
	ch <- 1
	ch <- 2
	fmt.Println("[async: multi-sender] Buffer filled with [1, 2]")

	// One "done" channel (empty) per sender, so we can see when each send completes.
	done3 := make(chan struct{})
	done4 := make(chan struct{})
	done5 := make(chan struct{})

	dones := []chan struct{}{done3, done4, done5}
	n_senders := len(dones)

	// Spawn 3 senders that will all block (buffer is full)
	startSender := func(senderID int, done chan struct{}) {
		wg.Add(1)
		go func() {
			defer wg.Done()
			fmt.Printf("[async: multi-sender] Sender %d attempting to send...\n", senderID)
			ch <- senderID
			fmt.Printf("[async: multi-sender] Sender %d could send the message\n", senderID)
			close(done)
		}()
	}

	// Start all senders
	for i := range dones {
		startSender(i+3, dones[i]) // sender IDs start at 3 since 1 and 2 are in the buffer
	}

	time.Sleep(100 * time.Millisecond) // Let all senders block

	fmt.Println("[async: multi-sender] All 3 senders are now blocked. Starting receiver...")

	// If any of the senders have completed, that's an error (they should all be blocked)
	for i := range dones {
		select {
		case <-dones[i]:
			t.Fatalf("sender %d should still be blocked", i+1)
		default:
		}
	}

	// Now receive messages one by one
	// Each receive should unblock one sender
	for i := 1; i <= 5; i++ {
		msg := <-ch
		fmt.Printf("[async: multi-sender] Receiver got: %d\n", msg)

		time.Sleep(200 * time.Millisecond) // Slow down to see sender unblocking (slow receiver)

		completed := 0
		for _, done := range dones {
			select {
			case <-done:
				completed++
			default:
			}
		}

		if i >= 1 && i <= n_senders {
			if completed != i {
				t.Fatalf("after receiving %d, expected %d senders to have completed, but got %d", msg, i, completed)
			}
		}

	}

	wg.Wait()
	close(ch)
	fmt.Println("[async: multi-sender] Test complete")
}
