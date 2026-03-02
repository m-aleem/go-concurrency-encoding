package main

import (
	"bufio"
	"fmt"
	"os"
	"strings"
)

func main() {
	fmt.Println("=== Enter Test(s) to Run ===")
	fmt.Println("1: Sync Test")
	fmt.Println("2: Async Test")
	fmt.Println("3: Mobility Test")
	fmt.Println("4: All Tests")
	fmt.Print("Enter choice (e.g., 1, 23, 4): ")

	reader := bufio.NewReader(os.Stdin)
	input, _ := reader.ReadString('\n')
	input = strings.TrimSpace(input)

	valid := map[rune]bool{'1': true, '2': true, '3': true, '4': true}
	runTests := make(map[string]bool)

	// Check validity
	for _, ch := range input {
		if !valid[ch] {
			fmt.Println("Invalid input. No tests will be run.")
			return
		}
		runTests[string(ch)] = true
	}

	// If "4" (All) is chosen, run all tests
	if runTests["4"] {
		test_sync_main()
		test_async_main()
		test_mobility_main()
		return
	}

	// Run selected tests
	if runTests["1"] {
		test_sync_main()
	}
	if runTests["2"] {
		test_async_main()
	}
	if runTests["3"] {
		test_mobility_main()
	}
}
