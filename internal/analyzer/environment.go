package analyzer

type Environment struct {
	store map[string]string
	outer *Environment
}

func NewEnvironment() *Environment {
	return &Environment {
		store: make(map[string]string),
		outer: nil,
	}
}

func NewEnclosedEnvironment(outer *Environment) *Environment {
	env := NewEnvironment()
	env.outer = outer
	return env
}

func (e *Environment) Define(name, dataType string) {
	e.store[name] = dataType
}

func (e *Environment) Resolve(name string) (string, bool) {
	obj, ok := e.store[name]
	if !ok && e.outer != nil {
		return e.outer.Resolve(name)
	}
	return obj, ok
}
