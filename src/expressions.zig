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
    .equal_equal, .bang_equal, .less, .less_equal, .greater, .greater_equal => .comparison,
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
  var left = try parseUnary(compiler, lexer);

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
    .kw_true => ExprResult {
      .val = llvm.LLVMConstInt(llvm.LLVMInt1TypeInContext(compiler.context), 1, 0),
      .dtype = .bool
    },
    .kw_false => ExprResult{
      .val = llvm.LLVMConstInt(llvm.LLVMInt1TypeInContext(compiler.context), 0, 0),
      .dtype = .bool
    },
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

fn parseUnary(compiler: *Compiler, lexer: *Lexer) anyerror!ExprResult {
  const token = lexer.peek();

  if (token.tag == .minus) {
    const operator = lexer.next();
    const operand = try parseUnary(compiler, lexer);
    return generateUnaryOp(compiler, operator.tag, operand);
  }

  return parsePrimary(compiler, lexer);
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
  const val = llvm.LLVMBuildLoad2(compiler.builder, llvm_type, local.llvm_value, "");

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

  var res_val: llvm.LLVMValueRef = undefined;
  var res_dtype: compiler_mod.DataType = left.dtype;

  switch (left.dtype) {
    .int => {
      res_val = switch (operator) {
        .plus => llvm.LLVMBuildAdd(compiler.builder, left.val, right.val, "add"),
        .minus => llvm.LLVMBuildSub(compiler.builder, left.val, right.val, "sub"),
        .asterisk => llvm.LLVMBuildMul(compiler.builder, left.val, right.val, "mul"),
        .slash => llvm.LLVMBuildSDiv(compiler.builder, left.val, right.val, "div"),
        .equal_equal => blk: {
          res_dtype = .bool;
          break :blk llvm.LLVMBuildICmp(compiler.builder, llvm.LLVMIntEQ, left.val, right.val, "eq");
        },
        .bang_equal => blk: {
          res_dtype = .bool;
          break :blk llvm.LLVMBuildICmp(compiler.builder, llvm.LLVMIntNE, left.val, right.val, "ne");
        },
        .greater => blk: {
          res_dtype = .bool;
          break :blk llvm.LLVMBuildICmp(compiler.builder, llvm.LLVMIntSGT, left.val, right.val, "gt");
        },
        .less => blk: {
          res_dtype = .bool;
          break :blk llvm.LLVMBuildICmp(compiler.builder, llvm.LLVMIntSLT, left.val, right.val, "lt");
        },
        .greater_equal => blk: {
          res_dtype = .bool;
          break :blk llvm.LLVMBuildICmp(compiler.builder, llvm.LLVMIntSGE, left.val, right.val, "ge");
        },
        .less_equal => blk: {
          res_dtype = .bool;
          break :blk llvm.LLVMBuildICmp(compiler.builder, llvm.LLVMIntSLE, left.val, right.val, "le");
        },
        else => return error.InvalidOperator,
      };
    },
    .float => {
      res_val = switch (operator) {
        .plus => llvm.LLVMBuildFAdd(compiler.builder, left.val, right.val, "fadd"),
        .minus => llvm.LLVMBuildFSub(compiler.builder, left.val, right.val, "fsub"),
        .asterisk => llvm.LLVMBuildFMul(compiler.builder, left.val, right.val, "fmul"),
        .slash => llvm.LLVMBuildFDiv(compiler.builder, left.val, right.val, "fdiv"),
        .equal_equal => blk: {
          res_dtype = .bool;
          break :blk llvm.LLVMBuildFCmp(compiler.builder, llvm.LLVMRealOEQ, left.val, right.val, "feq");
        },
        .bang_equal => blk: {
          res_dtype = .bool;
          break :blk llvm.LLVMBuildFCmp(compiler.builder, llvm.LLVMRealONE, left.val, right.val, "fne");
        },
        .greater => blk: {
          res_dtype = .bool;
          break :blk llvm.LLVMBuildFCmp(compiler.builder, llvm.LLVMRealOGT, left.val, right.val, "fgt");
        },
        .less => blk: {
          res_dtype = .bool;
          break :blk llvm.LLVMBuildFCmp(compiler.builder, llvm.LLVMRealOLT, left.val, right.val, "flt");
        },
        .greater_equal => blk: {
          res_dtype = .bool;
          break :blk llvm.LLVMBuildFCmp(compiler.builder, llvm.LLVMRealOGE, left.val, right.val, "fge");
        },
        .less_equal => blk: {
          res_dtype = .bool;
          break :blk llvm.LLVMBuildFCmp(compiler.builder, llvm.LLVMRealOLE, left.val, right.val, "fle");
        },
        else => return error.InvalidOperator,
      };
    },
    .str => {
      res_dtype = .bool;
      res_val = switch (operator) {
        .equal_equal => llvm.LLVMBuildICmp(compiler.builder, llvm.LLVMIntEQ, left.val, right.val, "seq"),
        .bang_equal => llvm.LLVMBuildICmp(compiler.builder, llvm.LLVMIntNE, left.val, right.val, "sne"),
        else => return error.OperationNotSupportedForType,
      };
    },
    .bool => {
      res_val = switch (operator) {
        .equal_equal => llvm.LLVMBuildICmp(compiler.builder, llvm.LLVMIntEQ, left.val, right.val, "beq"),
        else => return error.InvalidOperator,
      };
      res_dtype = .bool;
    },
  }

  return ExprResult{ .val = res_val, .dtype = res_dtype };
}

fn generateUnaryOp(
  compiler: *Compiler,
  op_type: TokenType,
  operand: ExprResult
) !ExprResult {
  switch (op_type) {
    .minus => {
      if (operand.dtype == .int) {
        const val = llvm.LLVMBuildNeg(compiler.builder, operand.val, "neg");
        return ExprResult{ .val = val, .dtype = .int };
      } else if (operand.dtype == .float) {
        const val = llvm.LLVMBuildFNeg(compiler.builder, operand.val, "fneg");
        return ExprResult{ .val = val, .dtype = .float };
      } else {
        return error.TypeMismatch;
      }
    },
    else => return error.InvalidOperator,
  }
}
