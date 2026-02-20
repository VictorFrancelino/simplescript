package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"simplescript/internal/frontend/lexer"
	"simplescript/internal/frontend/parser"
	"simplescript/internal/analyzer"
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

		if command != "run" && command != "build" && command != "wasm" {
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

	// Frontend
	lex := lexer.NewLexer(string(sourceCode))
	tokens := lex.Tokenize()

	par := parser.NewParser(tokens)
	program, err := par.Parse()

	if len(par.Errors()) > 0 {
		fmt.Println("Syntax Erros found:")

		for _, msg := range par.Errors() {
			fmt.Printf(" - %s\n", msg)
		}

		os.Exit(1)
	}

	ana := analyzer.NewAnalyzer()
	err = ana.Analyze(program)
	if err != nil {
		fmt.Println("Semantic Errors found:")

		for _, msg := range ana.Errors() {
			fmt.Printf(" - %s\n", msg)
		}

		os.Exit(1)
	}

	// Backend
	comp := backend.NewCompiler()
	comp.Compile(program)
	gen := backend.NewGenerator(comp)
	generatedCode, genErr := gen.Generate(program)

	if genErr != nil {
		fmt.Printf("Generation Error: %v\n", genErr)
		os.Exit(1)
	}

	stem := strings.TrimSuffix(filepath.Base(filename), ".ss")
	tempFile := stem + ".gen.go"

	err = os.WriteFile(tempFile, []byte(generatedCode), 0644)
	if err != nil {
		fmt.Printf("Error writing temporary file: %v\n", err)
		os.Exit(1)
	}
	defer os.Remove(tempFile)

	switch command {
	case "run":
		runGoCode(tempFile)
	case "build":
		buildGoCode(tempFile, stem)
		fmt.Printf("✓ Build successful: ./%s\n", stem)
	case "wasm":
		buildWasmWithTinyGo(tempFile, stem)
		fmt.Printf("✓ Wasm successful: ./%s.wasm\n", stem)
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

func buildWasmWithTinyGo(tempFile, outputName string) {
	cmd := exec.Command(
		"tinygo", "build",
		"-o", outputName+".wasm",
		"-target", "wasm",
		"-opt", "z",
		"-no-debug",
		"-panic", "trap",
		"-scheduler", "none",
		"-gc", "leaking",
		tempFile,
	)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		fmt.Printf("TinyGo error: %v\n", err)
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
	fmt.Println("  wasm  <file.ss> - Compile to WebAssembly (via TinyGo)")
}
