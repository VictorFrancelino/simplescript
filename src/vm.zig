const std = @import("std");

// Definimos erros possíveis durante a execução
pub const RuntimeError = error {
  TypeMismatch,
  InvalidInstruction
};

pub const OpCode = enum(u8) {
  LoadConst,
  Add,
  Say,
  Exit,
};

pub const Value = union(enum) {
  int: i64,
  string: []const u8,
};

pub const VM = struct {
  registers: [256]Value,
  constants: []const Value,
  pc: usize,

  // Pega os primeiros 8 bits (OpCode)
  inline fn getOp(inst: u32) OpCode {
    return @enumFromInt(@as(u8, @truncate(inst)));
  }

  // Pega o argumento A (bits 8-15) - Geralmente o Registrador de Destino
  inline fn getA(inst: u32) u8 {
    return @as(u8, @truncate(inst >> 8));
  }

  // Pega o argumento B (bits 16-23) - Usado em operações ABC
  inline fn getB(inst: u32) u8 {
    return @as(u8, @truncate(inst >> 16));
  }

  // Pega o argumento C (bits 24-31) - Usado em operações ABC
  inline fn getC(inst: u32) u8 {
    return @as(u8, @truncate(inst >> 24));
  }

  // Pega o argumento Bx/Ax (bits 16-31) - Usado para índices grandes (Constantes)
  inline fn getBx(inst: u32) u16 {
    return @as(u16, @truncate(inst >> 16));
  }

  pub fn run(self: *VM, instructions: []const u32) !void {
    self.pc = 0;

    while (true) {
      // Bounds check simplificado (em ReleaseFast o Zig remove se for seguro)
      if (self.pc >= instructions.len) break;

      const inst = instructions[self.pc];
      self.pc += 1;

      switch (getOp(inst)) {
        .LoadConst => {
          // Formato: [OP] [REG_A] [CONST_INDEX (16 bits)]
          const reg = getA(inst);
          const const_idx = getBx(inst);
          self.registers[reg] = self.constants[const_idx];
        },
        .Add => {
          // Formato: [OP] [DEST] [SRC1] [SRC2]
          const dest = getA(inst);
          const src1 = getB(inst);
          const src2 = getC(inst);

          const val1 = self.registers[src1];
          const val2 = self.registers[src2];

          // Type Checking: Só podemos somar Int com Int (por enquanto)
          if (val1 == .int and val2 == .int) {
            self.registers[dest] = .{ .int = val1.int + val2.int };
          } else {
            std.debug.print("Erro: Tentativa de somar tipos nao inteiros.\n", .{});
            return RuntimeError.TypeMismatch;
          }
        },
        .Say => {
          const reg = getA(inst);
          const val = self.registers[reg];
          switch (val) {
            .int => |v| std.debug.print("{d}\n", .{v}),
            .string => |v| std.debug.print("{s}\n", .{v}),
          }
        },
        .Exit => return,
      }
    }
  }
};
