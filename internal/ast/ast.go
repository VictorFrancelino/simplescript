package ast

type Expression interface {
	expressionNode()
	String() string
}

type Statement interface {
	statementNode()
}

type baseExpr struct{}
func (b *baseExpr) expressionNode() {}
func (b *baseExpr) String() string { return "" }

type baseStmt struct{}
func (b *baseStmt) statementNode() {}

type Program struct {
	baseStmt
	Statements []Statement
}
