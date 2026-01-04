const std = @import("std");
const Lexer = @import("../lexer/root.zig").Lexer;
const Token = @import("../lexer/root.zig").Token;
const vm_mod = @import("../vm/root.zig");
const OpCode = vm_mod.OpCode;
const Value = vm_mod.Value;

const emit_helper = @import("emit.zig");
const statements = @import("statements.zig");

pub const Local = struct {
  reg: u8,
  is_const: bool,
};

pub const Compiler = struct {
  instructions: std.ArrayListUnmanaged(u32) = .{},
  constants: std.ArrayListUnmanaged(Value) = .{},

  locals: std.StringHashMap(Local),

  next_register: u8,
  allocator: std.mem.Allocator,

  pub fn init(allocator: std.mem.Allocator) Compiler {
    return .{
      .locals = std.StringHashMap(Local).init(allocator),
      .next_register = 0,
      .allocator = allocator,
    };
  }

  pub fn deinit(self: *Compiler) void {
    self.instructions.deinit(self.allocator);
    self.constants.deinit(self.allocator);

    var iterator = self.locals.keyIterator();
    while (iterator.next()) |key_ptr| self.allocator.free(key_ptr.*);

    self.locals.deinit();
  }

  pub const addConstant = emit_helper.addConstant;
  pub const emit = emit_helper.emit;
  pub const emitLoad = emit_helper.emitLoad;

  pub const compile = statements.compile;
  pub const compileStatement = statements.compileStatement;
  pub const compileVarDeclaration = statements.compileVarDeclaration;
  pub const compileConstDeclaration = statements.compileConstDeclaration;
  pub const compileSay = statements.compileSay;

  pub fn patchJump(self: *Compiler, offset: usize, target: usize) void {
    const old_inst = self.instructions.items[offset];
    const op = old_inst & 0xFF;
    const reg_a = (old_inst >> 8) & 0xFF;

    const new_inst = op | (reg_a << 8) | (@as(u32, @intCast(target)) << 16);
    self.instructions.items[offset] = new_inst;
  }

  pub fn parseInt(_: *Compiler, slice: []const u8) !i64 {
    return std.fmt.parseInt(i64, slice, 10);
  }
};
