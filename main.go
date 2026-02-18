package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"simplescript/internal/frontend"
  "simplescript/internal/backend"
)

func main() {
	args := os.Args

	if len(args) < 2 {
		printUsage()
		return
	}

	command := args[1]

	switch len(args) {
	case 2:
		switch command {
		case "-v":
			fmt.Println("0.5.0")
		case "-h":
			printUsage()
		default:
			fmt.Printf("Error: Unknown flag '%s'\n", command)
			printUsage()
			os.Exit(1)
		}
	case 3:
		filename := args[2]

		if command != "run" && command != "build" {
			fmt.Printf("Error: Unknown command '%s'\n", command)
			printUsage()
			os.Exit(1)
		}

		processBuildOrRun(command, filename)
	default:
		printUsage()
	}
}

func processBuildOrRun(command, filename string) {
	if !strings.HasSuffix(filename, ".ss") {
		fmt.Println("Error: File must have .ss extension")
		os.Exit(1)
	}

	sourceCode, err := os.ReadFile(filename)
	if err != nil {
		fmt.Printf("Error: Cannot read file '%s': %v\n", filename, err)
		os.Exit(1)
	}

	stem := strings.TrimSuffix(filepath.Base(filename), ".ss")

	// Frontend
	lexer := frontend.NewLexer(string(sourceCode))
	parser := frontend.NewParser(lexer)
	program, err := parser.Parse()
	if err != nil {
		fmt.Printf("Parse Error: %v\n", err)
		os.Exit(1)
	}

	// Backend
	gen := backend.NewGenerator()
	generatedGoCode, err := gen.Generate(program)
	if err != nil {
		fmt.Printf("Generation Error: %v\n", err)
		os.Exit(1)
	}

	tempGoFile := stem + ".gen.go"
	err = os.WriteFile(tempGoFile, []byte(generatedGoCode), 0644)
	if err != nil {
		fmt.Printf("Error writing temporary file: %v\n", err)
		os.Exit(1)
	}
	defer os.Remove(tempGoFile)

	switch command {
	case "run":
		runGoCode(tempGoFile)
	case "build":
		buildGoCode(tempGoFile, stem)
		fmt.Printf("✓ Build successful: ./%s\n", stem)
	}
}

func runGoCode(tempFile string) {
	cmd := exec.Command("go", "run", tempFile)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin

	if err := cmd.Run(); err != nil {
		os.Exit(1)
	}
}

func buildGoCode(tempFile, outputName string) {
	cmd := exec.Command("go", "build", "-o", outputName, tempFile)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		fmt.Printf("Build error: %v\n", err)
		os.Exit(1)
	}
}

func printUsage() {
	fmt.Println("SimpleScript CLI")
	fmt.Println("Usage: simplescript <command> <file.ss>")
	fmt.Println("\nOptions:")
	fmt.Println("  -v - Show version")
	fmt.Println("  -h - Show help")
	fmt.Println("\nCommands:")
	fmt.Println("  build <file.ss> - Compile to a native executable (via Go)")
	fmt.Println("  run   <file.ss> - Transpile and execute immediately")
}
