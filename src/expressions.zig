const std = @import("std");
const compiler_mod = @import("compiler.zig");
const parser_mod = @import("parser.zig");
const llvm_bindings = @import("llvm.zig");

const Compiler = compiler_mod.Compiler;
const Lexer = parser_mod.Lexer;
const Token = parser_mod.Token;
const TokenType = parser_mod.TokenType;
const llvm = llvm_bindings.c;

pub const ExprResult = struct {
  val: llvm.LLVMValueRef,
  dtype: compiler_mod.DataType,
};

const Precedence = enum(u8) {
  none = 0,       // Not an operator
  assignment = 1, // = (future)
  logical = 2,    // and, or (future)
  comparison = 3, // ==, !=, <, >, <=, >= (future)
  term = 4,       // +, -
  factor = 5,     // *, /
  unary = 6,      // -, ! (future)
  call = 7,       // . () [] (future)
  primary = 8,    // literals, grouping
};

// Get operator precedence for a token
fn getPrecedence(token: Token) Precedence {
  return switch (token.tag) {
    .plus, .minus => .term,
    .asterisk, .slash => .factor,
    else => .none,
  };
}

// Get next higher precedence level
inline fn nextPrecedence(p: Precedence) Precedence {
  return @enumFromInt(@min(@intFromEnum(p) + 1, @intFromEnum(Precedence.primary)));
}

// Parse an expression starting from lowest precedence
pub fn parseExpression(compiler: *Compiler, lexer: *Lexer) anyerror!ExprResult {
  return parsePrecedence(compiler, lexer, .assignment);
}

// Parse expression with precedence climbing
fn parsePrecedence(
  compiler: *Compiler,
  lexer: *Lexer,
  min_precedence: Precedence,
) anyerror!ExprResult {
  // Parse left operand (highest precedence)
  var left = try parsePrimary(compiler, lexer);

  // Parse operators while they have higher or equal precedence
  while (true) {
    const next_token = lexer.peek();
    const next_prec = getPrecedence(next_token);

    if (@intFromEnum(next_prec) < @intFromEnum(min_precedence)) {
      break;
    }

    const operator = lexer.next();

    // Parse right operand with higher precedence
    const right = try parsePrecedence(
      compiler,
      lexer,
      nextPrecedence(next_prec)
    );

    left = try generateBinaryOp(compiler, operator.tag, left, right);
  }

  return left;
}

// Parse primary expressions (literals, variables, grouping)
fn parsePrimary(compiler: *Compiler, lexer: *Lexer) anyerror!ExprResult {
  const token = lexer.next();

  return switch (token.tag) {
    .string => try parseString(compiler, token),
    .int => try parseNumber(compiler, token, .int),
    .float => try parseNumber(compiler, token, .float),
    .identifier => try parseIdentifier(compiler, token),
    .lparen => try parseGrouping(compiler, lexer),
    else => {
      std.debug.print("Error: Unexpected token {any} in expression\n", .{token});
      return error.UnexpectedToken;
    },
  };
}

fn parseString(compiler: *Compiler, token: Token) !ExprResult {
  const str_z = try compiler.allocator.dupeZ(u8, token.slice);
  defer compiler.allocator.free(str_z);

  const val = llvm.LLVMBuildGlobalStringPtr(compiler.builder, str_z, "str");
  return ExprResult{ .val = val, .dtype = .str };
}

fn parseNumber(compiler: *Compiler, token: Token, dtype: compiler_mod.DataType) !ExprResult {
  if (dtype == .int) {
    const value = std.fmt.parseInt(i64, token.slice, 10) catch return error.InvalidNumber;
    const val = llvm.LLVMConstInt(compiler.getI64Type(), @bitCast(value), 0);
    return ExprResult{ .val = val, .dtype = .int };
  } else {
    const value = std.fmt.parseFloat(f64, token.slice) catch return error.InvalidFloat;
    const val = llvm.LLVMConstReal(llvm.LLVMDoubleTypeInContext(compiler.context), value);
    return ExprResult{ .val = val, .dtype = .float };
  }
}

fn parseIdentifier(compiler: *Compiler, token: Token) !ExprResult {
  const local = compiler.lookupVariable(token.slice) orelse {
    std.debug.print("Error: Undefined variable '{s}'\n", .{token.slice});
    return error.UndefinedVariable;
  };

  const llvm_type = compiler.getLLVMType(local.data_type);
  const val = llvm.LLVMBuildLoad2(compiler.builder, llvm_type, local.llvm_value, token.slice.ptr);

  return ExprResult{ .val = val, .dtype = local.data_type };
}

fn parseGrouping(compiler: *Compiler, lexer: *Lexer) !ExprResult {
  const expr = try parseExpression(compiler, lexer);

  const rparen = lexer.next();
  if (rparen.tag != .rparen) {
    std.debug.print("Error: Expected ')' after expression, got {any}\n", .{rparen});
    return error.ExpectedRParen;
  }

  return expr;
}

// Generate LLVM IR for binary operation
fn generateBinaryOp(
  compiler: *Compiler,
  operator: TokenType,
  left: ExprResult,
  right: ExprResult,
) !ExprResult {
  if (left.dtype != right.dtype) {
    std.debug.print("Type Error: Mismatched types in binary op: {s} and {s}\n", .{ @tagName(left.dtype), @tagName(right.dtype) });
    return error.TypeMismatch;
  }

  const val = switch (left.dtype) {
    .int => switch (operator) {
      .plus => llvm.LLVMBuildAdd(compiler.builder, left.val, right.val, "add"),
      .minus => llvm.LLVMBuildSub(compiler.builder, left.val, right.val, "sub"),
      .asterisk => llvm.LLVMBuildMul(compiler.builder, left.val, right.val, "mul"),
      .slash => llvm.LLVMBuildSDiv(compiler.builder, left.val, right.val, "div"),
      else => return error.InvalidOperator,
    },
    .float => switch (operator) {
      .plus => llvm.LLVMBuildFAdd(compiler.builder, left.val, right.val, "fadd"),
      .minus => llvm.LLVMBuildFSub(compiler.builder, left.val, right.val, "fsub"),
      .asterisk => llvm.LLVMBuildFMul(compiler.builder, left.val, right.val, "fmul"),
      .slash => llvm.LLVMBuildFDiv(compiler.builder, left.val, right.val, "fdiv"),
      else => return error.InvalidOperator,
    },
    else => return error.OperationNotSupportedForType,
  };

  return ExprResult{ .val = val, .dtype = left.dtype };
}
