package ast

type IntegerLiteral struct{
	baseExpr
	Token Token
	Value int64
}

type FloatLiteral struct{
	baseExpr
	Token Token
	Value float64
}

type StringLiteral struct{
	baseExpr
	Token Token
	Value string
}

type BooleanLiteral struct{
	baseExpr
	Token Token
	Value bool
}

type ListLiteral struct{
	baseExpr
	Token Token
	Elements []Expression
}

type Identifier struct{
	baseExpr
	Token Token
	Value string
}

type InfixExpression struct {
	baseExpr
	Left Expression
	Operator string
	Right Expression
}

type PrefixExpression struct {
	baseExpr
	Operator string
	Right Expression
}
