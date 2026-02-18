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
	return [...]string{"SyntaxError", "TypeError", "NameError", "LinkerError", "InternalError"}[e]
}

type DataType int

const (
	TypeInt DataType = iota
	TypeFloat
	TypeStr
	TypeBool
)

func (d DataType) String() string {
	return [...]string{"int", "float", "str", "bool"}[d]
}

type Variable struct {
	Name string
	IsConst bool
	DataType DataType
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

func (c *Compiler) Dispose() {
	c.Locals = nil
}

func (c *Compiler) EnterScope() {
	c.ScopeLevel++
}

func (c *Compiler) ExitScope() {
	c.ScopeLevel--
}

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
		color = "\x1b[31m"
	case Warning:
		color = "\x1b[33m"
	case Note:
		color = "\x1b[36m"
	}

	fmt.Printf("%s[%s]%s at line %d, col %d: %s\n",
		color, code.String(), reset, token.Line, token.Col, message)

	if extra != "" {
		fmt.Printf("  └─ \x1b[32mHint: %s%s\n", extra, reset)
	}

	if level == Error || level == Fatal {
		if level == Fatal {
			os.Exit(1)
		}
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

func (c *Compiler) GetGoType(dtype DataType) string {
	switch dtype {
	case TypeInt:
		return "int64"
	case TypeFloat:
		return "float64"
	case TypeBool:
		return "bool"
	case TypeStr:
		return "string"
	default:
		return "interface{}"
	}
}
