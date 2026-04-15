package main

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

// Helper function to run go test with a pattern
func runGoTest(pattern string) error {
	cmd := exec.Command("go", "test", "-v", "-run", pattern, ".")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func main() {
	fmt.Println("=== Enter Test(s) to Run ===")
	fmt.Println("1: Sync Test")
	fmt.Println("2: Async Test")
	fmt.Println("3: Mobility Test")
	fmt.Println("4: Close (Panic) Test")
	fmt.Println("5: Typing Tests")
	fmt.Println("6: All Tests")
	fmt.Print("Enter choice (e.g., 1, 2, 3, 4, 5, 6): ")

	reader := bufio.NewReader(os.Stdin)
	input, _ := reader.ReadString('\n')
	input = strings.TrimSpace(input)

	valid := map[rune]bool{'1': true, '2': true, '3': true, '4': true, '5': true, '6': true}
	runTests := make(map[string]bool)

	// Check validity
	for _, ch := range input {
		if !valid[ch] {
			fmt.Println("Invalid input. No tests will be run.")
			return
		}
		runTests[string(ch)] = true
	}

	// If "6" (All) is chosen, run all tests
	if runTests["6"] {
		fmt.Println("=== Running ALL Tests ===")
		runGoTest("TestSync")     // runs all tests with "TestSync" in their name
		runGoTest("TestAsync")    // runs all tests with "TestAsync" in their name
		runGoTest("TestMobility") // runs all tests with "TestMobility" in their name
		runGoTest("TestClose")    // runs all tests with "TestClose" in their name
		runGoTest("TestTyped")    // runs all tests with "TestTyped"  in their name
		return
	}

	// Run selected tests
	if runTests["1"] {
		fmt.Println("=== Running Sync Tests ===")
		runGoTest("TestSync")
	}
	if runTests["2"] {
		fmt.Println("=== Running Async Tests ===")
		runGoTest("TestAsync")
	}
	if runTests["3"] {
		fmt.Println("=== Running Mobility Tests ===")
		runGoTest("TestMobility")
	}
	if runTests["4"] {
		fmt.Println("=== Running Close Tests ===")
		runGoTest("TestClose")
	}
	if runTests["5"] {
		fmt.Println("=== Running Typing Tests ===")
		runGoTest("TestTyped")
	}
}
