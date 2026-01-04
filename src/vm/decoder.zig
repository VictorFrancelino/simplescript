const std = @import("std");
const types = @import("types.zig");

pub inline fn getOp(inst: u32) types.OpCode {
  return @enumFromInt(@as(u8, @truncate(inst)));
}

pub inline fn getA(inst: u32) u8 {
  return @as(u8, @truncate(inst >> 8));
}

pub inline fn getB(inst: u32) u8 {
  return @as(u8, @truncate(inst >> 16));
}

pub inline fn getC(inst: u32) u8 {
  return @as(u8, @truncate(inst >> 24));
}

pub inline fn getBx(inst: u32) u16 {
  return @as(u16, @truncate(inst >> 16));
}
