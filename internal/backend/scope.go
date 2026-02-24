package backend

type Variable struct {
	Name string
	IsConst bool
	Type string
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
