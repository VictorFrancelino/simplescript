package backend

import (
	"fmt"
	"os"

	"simplescript/internal/ast"
)

type DiagnosticLevel int

const (
	Note DiagnosticLevel = iota
	Warning
	Error
	Fatal
)

type ErrorCode int

const (
	SyntaxError ErrorCode = iota
	TypeError
	NameError
	LinkerError
	InternalError
)

func (e ErrorCode) String() string {
	switch e {
	case SyntaxError: return "SyntaxError"
	case TypeError: return "TypeError"
	case NameError: return "NameError"
	case LinkerError: return "LinkerError"
	case InternalError: return "InternalError"
	default: return "UnknownError"
	}
}

// Prints formatted diagnostic messages to the standard error output
func (c *Compiler) Report(
	level DiagnosticLevel,
	code ErrorCode,
	token ast.Token,
	message string,
	extra string,
) {
	color := ""
	reset := "\x1b[0m"

	switch level {
	case Error, Fatal:
		color = "\x1b[31m" // Red
	case Warning:
		color = "\x1b[33m" // Yellow
	case Note:
		color = "\x1b[36m" // Cyan
	}

	fmt.Printf(
		"%s[%s]%s at line %d, col %d: %s\n",
		color,
		code.String(),
		reset,
		token.Line,
		token.Col,
		message,
	)

	if extra != "" {
		fmt.Printf("  └─ \x1b[32mHint: %s%s\n", extra, reset)
	}

	if level == Fatal {
		os.Exit(1)
	}
}
