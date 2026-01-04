const std = @import("std");

pub const RuntimeError = error {
  TypeMismatch,
  InvalidInstruction
};

pub const OpCode = enum(u8) {
  LoadConst,
  Move,
  Add,
  LessThan,
  Jump,
  JumpIfFalse,
  Say,
  Exit,
};

pub const Value = union(enum) {
  int: i64,
  boolean: bool,
  string: []const u8,
};
