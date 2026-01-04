const std = @import("std");
const types = @import("types.zig");
const decoder = @import("decoder.zig");

pub const Value = types.Value;
pub const OpCode = types.OpCode;
pub const RuntimeError = types.RuntimeError;

pub inline fn getBx(inst: u32) u16 {
  return @as(u16, @truncate(inst >> 16));
}

pub const VM = struct {
  registers: [256]Value,
  constants: []const Value,
  pc: usize,

  pub fn run(self: *VM, instructions: []const u32) !void {
    self.pc = 0;

    while (true) {
      if (self.pc >= instructions.len) break;

      const inst = instructions[self.pc];
      self.pc += 1;

      switch (decoder.getOp(inst)) {
        .LoadConst => {
          const reg = decoder.getA(inst);
          const const_idx = decoder.getBx(inst);
          self.registers[reg] = self.constants[const_idx];
        },
        .LessThan => {
          const dest = decoder.getA(inst);
          const val1 = self.registers[decoder.getB(inst)];
          const val2 = self.registers[decoder.getC(inst)];

          if (val1 == .int and val2 == .int) {
            self.registers[dest] = .{ .boolean = val1.int < val2.int };
          } else {
            return RuntimeError.TypeMismatch;
          }
        },
        .Jump => {
          const target = decoder.getBx(inst);
          self.pc = target;
        },
        .JumpIfFalse => {
          const cond_reg = decoder.getA(inst);
          const target = decoder.getBx(inst);
          const val = self.registers[cond_reg];

          if (val == .boolean and val.boolean == false) self.pc = target;
        },
        .Move => {
          const dest = decoder.getA(inst);
          const src = decoder.getB(inst);
          self.registers[dest] = self.registers[src];
        },
        .Add => {
          const dest = decoder.getA(inst);
          const src1 = decoder.getB(inst);
          const src2 = decoder.getC(inst);

          const val1 = self.registers[src1];
          const val2 = self.registers[src2];

          if (val1 == .int and val2 == .int) {
            self.registers[dest] = .{ .int = val1.int + val2.int };
          } else {
            std.debug.print("Erro: Tentativa de somar tipos nao inteiros.\n", .{});
            return RuntimeError.TypeMismatch;
          }
        },
        .Say => {
          const reg = decoder.getA(inst);
          const val = self.registers[reg];
          switch (val) {
            .int => |v| std.debug.print("{d}\n", .{v}),
            .string => |v| std.debug.print("{s}\n", .{v}),
            .boolean => |v| std.debug.print("{}\n", .{v}),
          }
        },
        .Exit => return,
      }
    }
  }
};
