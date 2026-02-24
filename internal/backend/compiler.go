package backend

import "simplescript/internal/ast"

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

	for _, stmt := range prog.Statements {
		c.processStatement(stmt)
	}

	return c
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
