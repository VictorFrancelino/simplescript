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

type Variable struct {
	Name string
	IsConst bool
	Type string
}

type Compiler struct {
	Locals map[string]Variable
	ScopeLevel int
}

func NewCompiler() *Compiler {
	return &Compiler{
		Locals: make(map[string]Variable),
		ScopeLevel: 0,
	}
}

func MustCompile(prog *ast.Program) *Compiler {
	c := NewCompiler()
	c.compile(prog)
	return c
}

func (c *Compiler) compile(prog *ast.Program) {
	for _, stmt := range prog.Statements {
		c.processStatement(stmt)
	}
}

func (c *Compiler) processStatement(stmt ast.Statement) {
	switch s := stmt.(type) {
	case *ast.VarDecl:
		c.Locals[s.Name] = Variable{
			Name: s.Name,
			IsConst: s.IsConst,
			Type: s.DataType,
		}
	case *ast.Block:
		for _, bStmt := range s.Statements {
			c.processStatement(bStmt)
		}
	case *ast.IfStmt:
	  c.processStatement(s.Consequence)
	  if s.Alternative != nil {
	     c.processStatement(s.Alternative)
	  }
	case *ast.ForStmt:
		c.processStatement(s.Body)
	}
}

// Maps SimpleScript types to Go native types for generation
func (c *Compiler) GetGoType(ssType string) string {
	switch ssType {
	case "int": return "int"
	case "float": return "float64"
	case "bool": return "bool"
	case "str": return "string"
	case "list": return "[]interface{}"
	default: return "interface{}"
	}
}

func (c *Compiler) LookupVariable(name string) (Variable, bool) {
	val, ok := c.Locals[name]
	return val, ok
}

func (c *Compiler) HasVariable(name string) bool {
	_, ok := c.Locals[name]
	return ok
}

func (c *Compiler) EnterScope() { c.ScopeLevel++ }

func (c *Compiler) ExitScope() { c.ScopeLevel-- }

func (c *Compiler) Dispose() { c.Locals = nil }

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
