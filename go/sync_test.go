package main

import (
	"fmt"
	"sync"
	"testing"
	"time"
)

// ---------------------------------------------------------------------------
// SYNCHRONOUS COMMUNICATION
// From https://go.dev/tour/concurrency/2: By default, sends and receives
// block until the other side is ready. This allows goroutines to synchronize
// without explicit locks or condition variables.
// ---------------------------------------------------------------------------

// Test 1: Send on an open channel (one sender, one receiver)
// This test demonstrates that a send on an open channel succeeds and the value is received by the receiver.
func TestSyncSingleSender(t *testing.T) {
	fmt.Println("------ Sync 1: Send on an open channel (one sender, one receiver) ------")

	got := run_sync(1) // send 3 messages
	want := []int{0}

	assert_equal(t, got, want, "received messages")
}

// Test 2: Send on an open channel (multiple senders, one receiver)
// This test demonstrates that multiple senders can send on an open channel and the receiver receives all messages.
func TestSyncMultipleBlockedSenders(t *testing.T) {
	fmt.Println("------ Sync 2: Send on an open channel (multiple senders, one receiver) ------")

	ch := make(chan int)
	var wg sync.WaitGroup

	// One "done" channel (empty) per sender, so we can see when each send completes.
	done1 := make(chan struct{})
	done2 := make(chan struct{})
	done3 := make(chan struct{})
	done4 := make(chan struct{})

	dones := []chan struct{}{done1, done2, done3, done4}
	n_senders := len(dones)

	// Spawn 4 senders that will all block (receiver is not ready)
	startSender := func(senderID int, done chan struct{}) {
		wg.Add(1)
		go func() {
			defer wg.Done()
			fmt.Printf("[sync: multi-sender] Sender %d attempting to send...\n", senderID)
			ch <- senderID
			fmt.Printf("[sync: multi-sender] Sender %d could send the message\n", senderID)
			close(done)
		}()
	}

	// Start all senders
	for i := range dones {
		startSender(i+1, dones[i])
	}

	time.Sleep(100 * time.Millisecond) // Let all senders block

	fmt.Printf("[sync: multi-sender] All %d senders are now blocked. Starting receiver...\n", n_senders)

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
	for i := 1; i <= n_senders; i++ {
		msg := <-ch
		fmt.Printf("[sync: multi-sender] Receiver got: %d\n", msg)

		time.Sleep(200 * time.Millisecond) // Slow down to see sender unblocking

		completed := 0
		for _, done := range dones {
			select {
			case <-done:
				completed++
			default:
			}
		}

		if completed != i {
			t.Fatalf("after receiving %d, expected %d senders to have completed, but got %d", msg, i, completed)
		}

	}

	wg.Wait()
	close(ch)
	fmt.Println("[sync: multi-sender] Test complete")
}
