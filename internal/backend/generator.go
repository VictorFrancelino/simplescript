package backend

import (
	"fmt"
	"strings"
	"simplescript/internal/ast"
)

type Generator struct {
	builder strings.Builder
}

func NewGenerator() *Generator {
	return &Generator{}
}

func (g *Generator) Generate(prog *ast.Program) (string, error) {
	g.builder.WriteString("package main\n\nimport \"fmt\"\n\nfunc main() {\n")

	for _, stmt := range prog.Statements {
		g.genStatement(stmt, 1)
	}

	g.builder.WriteString("}\n")
	return g.builder.String(), nil
}

func (g *Generator) genStatement(stmt ast.Statement, indent int) {
	tabs := strings.Repeat("\t", indent)

	switch s := stmt.(type) {
	case *ast.VarDecl:
		keyword := "var"
		if s.IsConst { keyword = "const" }

		g.builder.WriteString(fmt.Sprintf("%s%s %s = %s\n", tabs, keyword, s.Name, g.genExpression(s.Value)))

	case *ast.Assignment:
		targets := strings.Join(s.Targets, ", ")
		values := []string{}
		for _, v := range s.Values {
			values = append(values, g.genExpression(v))
		}
		g.builder.WriteString(fmt.Sprintf("%s%s = %s\n", tabs, targets, strings.Join(values, ", ")))

	case *ast.SayStmt:
		g.builder.WriteString(fmt.Sprintf("%sfmt.Println(", tabs))

		for i, arg := range s.Args {
			g.builder.WriteString(g.genExpression(arg))
			if i < len(s.Args)-1 { g.builder.WriteString(", ") }
		}

		g.builder.WriteString(")\n")

	case *ast.IfStmt:
		cond := g.genExpression(s.Condition)
		g.builder.WriteString(fmt.Sprintf("%sif %s {\n", tabs, cond))
		g.genStatement(s.Consequence, indent + 1)
		g.builder.WriteString(tabs + "}")

		if s.Alternative != nil {
			if _, isIf := s.Alternative.(*ast.IfStmt); isIf {
				g.builder.WriteString(" else ")
				g.genStatement(s.Alternative, indent)
			} else {
				g.builder.WriteString(" else {\n")
				g.genStatement(s.Alternative, indent)
				g.builder.WriteString(tabs + "}\n")
			}
		} else {
			g.builder.WriteString("\n")
		}

	case *ast.ForStmt:
		start := g.genExpression(s.Start)
		end := g.genExpression(s.End)
		g.builder.WriteString(fmt.Sprintf("%sfor %s := %s; %s < %s; %s++ {\n",
			tabs, s.Iterator, start, s.Iterator, end, s.Iterator))
		g.genStatement(s.Body, indent + 1)
		g.builder.WriteString(tabs + "}\n")

	case *ast.Block:
		for _, bStmt := range s.Statements {
			g.genStatement(bStmt, indent)
		}
	}
}

func (g *Generator) genExpression(expr ast.Expression) string {
	switch e := expr.(type) {
	case *ast.IntegerLiteral:
		return fmt.Sprintf("%d", e.Value)
	case *ast.FloatLiteral:
		return fmt.Sprintf("%f", e.Value)
	case *ast.StringLiteral:
		return fmt.Sprintf("\"%s\"", e.Value)
	case *ast.BooleanLiteral:
		return fmt.Sprintf("%t", e.Value)
	case *ast.Identifier:
		return e.Value
	case *ast.PrefixExpression:
		return fmt.Sprintf("(%s%s)", e.Operator, g.genExpression(e.Right))
	case *ast.InfixExpression:
		return fmt.Sprintf(
			"(%s %s %s)",
      g.genExpression(e.Left),
      e.Operator,
      g.genExpression(e.Right),
    )
	}
	return ""
}
