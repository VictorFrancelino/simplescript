# SimpleScript

O **SimpleScript** é uma linguagem de programação experimental, minimalista e de ultra-alta performance escrita em **Zig**. 

Diferente da maioria das linguagens iniciantes que utilizam interpretadores de árvore (AST) ou máquinas de pilha (Stack-based), o SimpleScript utiliza uma **Register-based VM** (Máquina Virtual de Registradores), o que reduz drasticamente o overhead de manipulação de memória e resulta em execuções na casa dos microssegundos.

## ✨ Características Técnicas

* **Engine:** Register-Based VM (eficiência de registradores virtuais).
* **Bytecode:** Instruções compactas de 32-bits.
* **Aritmética:** Suporte a cadeias de operações aritméticas (ex: `10 + 20 + 30`).
* **Tipagem:** Dinâmica com suporte inicial para `Int64` e `String`.
* **Desenvolvido em:** Zig 0.16.0-dev (foco em segurança de memória e performance nativa).

## 📊 Performance (v0.1.0)

Em testes realizados em um ambiente Linux, os resultados foram:
* **Tempo de Compilação:** ~3.8 ms
* **Tempo de Execução:** ~0.018 ms (18 microssegundos)

## 🛠️ Estrutura do Projeto

O projeto é modularizado para facilitar a escalabilidade:
* `src/lexer.zig`: Analisador léxico (Tokenização).
* `src/compiler.zig`: Traduz código fonte para Bytecode de 32-bits.
* `src/vm.zig`: Máquina virtual que executa o bytecode.
* `src/main.zig`: Ponto de entrada e motor de benchmark.
