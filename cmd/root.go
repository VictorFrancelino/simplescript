package cmd

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"

	"simplescript/internal/analyzer"
	"simplescript/internal/backend"
	"simplescript/internal/frontend/lexer"
	"simplescript/internal/frontend/parser"
)

var rootCmd = &cobra.Command{
	Use: "simplescript",
	Version: "0.5.0",
	Short: "SimpleScript is a modern transpiler for the web",
	Long: `A fast and easy-to-use language that transpiles to Go and WebAssembly. Built with love for the modern web.`,
}

func Execute() {
	if err := rootCmd.Execute(); err != nil {
		os.Exit(1)
	}
}

func processSource(command, filename string) {
	sourceCode := readSource(filename)
	stem := strings.TrimSuffix(filepath.Base(filename), ".ss")
	tempFile := stem + ".gen.go"

	// Frontend
	tokens := lexer.MustTokenize(sourceCode)
	program := parser.MustParse(tokens)
	program = analyzer.MustAnalyze(program)

	// Backend
	compiledProgram := backend.MustCompile(program)
	generatedCode := backend.MustGenerate(compiledProgram, program)

	mustWriteFile(tempFile, generatedCode)
	defer os.Remove(tempFile)

	handleCompletion(command, tempFile, stem)
}

func handleCompletion(command, tempFile, stem string) {
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

func readSource(filename string) string {
	if !strings.HasSuffix(filename, ".ss") {
		fmt.Println("Error: File must have .ss extension")
		os.Exit(1)
	}

	sourceCode, err := os.ReadFile(filename)
	if err != nil {
		fmt.Printf("Error: Cannot read file '%s': %v\n", filename, err)
		os.Exit(1)
	}

	return string(sourceCode)
}

func mustWriteFile(filename, content string) {
	err := os.WriteFile(filename, []byte(content), 0644)
	if err != nil {
		fmt.Printf("Error writing temporary file: %v\n", err)
		os.Exit(1)
	}
}

func runGoCode(tempFile string) {
	cmd := exec.Command("go", "run", tempFile)
	cmd.Stdout, cmd.Stderr, cmd.Stdin = os.Stdout, os.Stderr, os.Stdin
	if err := cmd.Run(); err != nil {
		os.Exit(1)
	}
}

func buildGoCode(tempFile, outputName string) {
	cmd := exec.Command("go", "build", "-o", outputName, tempFile)
	cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr
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
	cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr

	if err := cmd.Run(); err != nil {
		fmt.Printf("TinyGo error: %v\n", err)
		os.Exit(1)
	}
}
