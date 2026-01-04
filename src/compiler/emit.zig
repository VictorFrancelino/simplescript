const std = @import("std");
const root = @import("root.zig");
const vm_mod = @import("../vm/root.zig");
const OpCode = vm_mod.OpCode;
const Value = vm_mod.Value;

pub fn addConstant(self: *root.Compiler, val: Value) !u16 {
  const idx = self.constants.items.len;
  try self.constants.append(self.allocator, val);
  return @as(u16, @intCast(idx));
}

pub fn emit(self: *root.Compiler, op: OpCode, a: u8, b: u8, c: u8) !void {
  const instr = @as(u32, @intFromEnum(op)) | (@as(u32, a) << 8) | (@as(u32, b) << 16) | (@as(u32, c) << 24);
  try self.instructions.append(self.allocator, instr);
}

pub fn emitLoad(self: *root.Compiler, op: OpCode, reg: u8, const_idx: u16) !void {
  const instr = @as(u32, @intFromEnum(op)) | (@as(u32, reg) << 8) | (@as(u32, const_idx) << 16);
  try self.instructions.append(self.allocator, instr);
}
