# SimpleScript ⚡

[![Go Version](https://img.shields.io/badge/Go-1.24+-00ADD8?logo=go)](https://golang.org/)
[![TinyGo](https://img.shields.io/badge/Powered%20by-TinyGo-blue)](https://tinygo.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

*A web-first, lightweight compiled programming language designed for modern browsers and native execution.*

[ 🇧🇷 Leia em Português ](#-versão-em-português)

SimpleScript is an experimental, statically-typed language built from scratch in **Go**. By transpiling to Go and utilizing **TinyGo**, SimpleScript produces ultra-small WebAssembly (Wasm) modules for the web, while retaining the ability to compile directly to native machine code for CLI usage.

## 🚀 Why SimpleScript?

- 🌐 **WebAssembly Native:** Built with the browser in mind. Compiles to tiny `.wasm` files.
- 🛠️ **The Power of Go:** Leverages Go's robust standard library for native execution and TinyGo for Wasm.
- 🎯 **Strict & Simple:** Static typing (`str`, `int`, `float`), immutable constants, and a clean, noise-free syntax.
- 📦 **Zero Heavy Runtimes:** The resulting Wasm binaries are incredibly small, making them perfect for fast web loads.

## 📦 Getting Started

### Prerequisites
- [Go 1.24](https://golang.org/dl/) (To build the compiler and run natively)
- [TinyGo](https://tinygo.org/getting-started/) (Required ONLY for WebAssembly compilation)

### Building the Compiler
```bash
git clone [https://github.com/VictorFrancelino/simplescript.git](https://github.com/VictorFrancelino/simplescript.git)
cd simplescript
go build -o simplescript .
```

### CLI Usage

SimpleScript comes with a built-in toolchain:

```bash
# Run a script immediately (Native via Go)
./simplescript run file.ss

# Compile to a native executable binary
./simplescript build file.ss

# Compile to WebAssembly (via TinyGo)
./simplescript wasm file.ss
```

Note on WebAssembly: To run the generated `.wasm` file in a browser, you will need the `wasm_exec.js` bridge provided by TinyGo and a basic HTML wrapper.

### Language Tour

SimpleScript features a modern, clean syntax. Here is what is currently supported in v0.5:

```bash
// Comments start with double slashes

// Built-in print function
say('--- Welcome to SimpleScript ---')

// Constants are immutable after initialization
const language: str = 'SimpleScript'
const version: float = 0.5

// Variables can be reassigned
var a: int = 10
var b: int = 20

var result: int = (a + b) * 2
say('Result:', result)

// Exclusive range loops (0 to 9)
var sum: int = 0
for i in 0..10 {
  sum = sum + i
}
say('Sum:', sum)
```

### Roadmap

We are constantly evolving. Upcoming features include:

- [] Native `json` parsing and generation.
- [] Built-in `list` and `map` structures.
- [] Functions (`func`) with return types.

### License

SimpleScript is open-source software licensed under the MIT license.

---

# 🇧🇷 Versão em Português

Uma linguagem de programação compilada, leve e focada na web, projetada para navegadores modernos e execução nativa.

O SimpleScript é uma linguagem experimental, de tipagem estática, construída do zero em Go. Ao transpilar para Go e utilizar o TinyGo, o SimpleScript produz módulos WebAssembly (Wasm) ultra-pequenos para a web, mantendo a capacidade de compilar diretamente para código de máquina nativo para uso no terminal.

## 🚀 Por que SimpleScript?

- 🌐 WebAssembly Nativo: Construído pensando no navegador. Compila para arquivos `.wasm` minúsculos.
- 🛠️ O Poder do Go: Aproveita a biblioteca padrão do Go para execução nativa e o TinyGo para Wasm.
- 🎯 Rigoroso & Simples: Tipagem estática (`str`, `int`, `float`), constantes imutáveis e uma sintaxe limpa e sem ruídos.
- 📦 Sem Runtimes Pesados: Os binários Wasm resultantes são incrivelmente pequenos, perfeitos para carregamento rápido na web.

## 📦 Como Começar

### Pré-requisitos
- [Go 1.24](https://golang.org/dl/) (Para compilar a linguagem e rodar nativamente)
- [TinyGo](https://tinygo.org/getting-started/) (Necessário APENAS para compilar para WebAssembly)

### Compilando a Linguagem
```bash
git clone [https://github.com/VictorFrancelino/simplescript.git](https://github.com/VictorFrancelino/simplescript.git)
cd simplescript
go build -o simplescript .
```

### Comandos do CLI

O SimpleScript vem com ferramentas integradas:

```bash
# Executa um script imediatamente (Nativo via Go)
./simplescript run arquivo.ss

# Compila para um executável binário nativo
./simplescript build arquivo.ss

# Compila para WebAssembly (via TinyGo)
./simplescript wasm arquivo.ss
```

Nota sobre WebAssembly: Para rodar o arquivo `.wasm` gerado no navegador, você precisará da ponte `wasm_exec.js` fornecida pelo TinyGo e de um HTML básico.

### 📖 Tour da Linguagem

O SimpleScript possui uma sintaxe moderna e limpa. Veja o que já é suportado na v0.5:

```bash
// Comentários começam com barras duplas

// Função de impressão embutida
say('--- Bem-vindo ao SimpleScript ---')

// Constantes são imutáveis
const linguagem: str = 'SimpleScript'
const versao: float = 0.5

// Variáveis podem ser reatribuídas
var a: int = 10
var b: int = 20

var resultado: int = (a + b) * 2
say('Resultado:', resultado)

// Loops de intervalo exclusivo (0 a 9)
var soma: int = 0
for i in 0..10 {
  soma = soma + i
}
say('Soma:', soma)
```

### Roadmap

Estamos em constante evolução. Os próximos passos incluem:

- [] Parsing e geração nativa de `json`.
- [] Estruturas nativas de `list` e `map`.
- [] Funções (`func`) com tipos de retorno.

### Licença

O SimpleScript é um software open-source licenciado sob a licença MIT.
