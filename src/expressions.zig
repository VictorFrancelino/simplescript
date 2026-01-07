const std = @import("std");
const compiler_mod = @import("compiler.zig");
const parser_mod = @import("parser.zig");
const llvm_bindings = @import("llvm.zig");

const Compiler = compiler_mod.Compiler;
const Lexer = parser_mod.Lexer;
const Token = parser_mod.Token;
const TokenType = parser_mod.TokenType;
const llvm = llvm_bindings.c;

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
pub fn parseExpression(compiler: *Compiler, lexer: *Lexer) !llvm.LLVMValueRef {
  return parsePrecedence(compiler, lexer, .assignment);
}

// Parse expression with precedence climbing
fn parsePrecedence(
  compiler: *Compiler,
  lexer: *Lexer,
  min_precedence: Precedence,
) !llvm.LLVMValueRef {
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
fn parsePrimary(compiler: *Compiler, lexer: *Lexer) !llvm.LLVMValueRef {
  const token = lexer.next();

  return switch (token.tag) {
    .number => try parseNumber(compiler, token),
    .identifier => try parseIdentifier(compiler, token),
    .lparen => try parseGrouping(compiler, lexer),

    else => {
      std.debug.print("Error: Unexpected token {} in expression\n", .{token});
      return error.UnexpectedToken;
    },
  };
}

// Parse a number literal
fn parseNumber(compiler: *Compiler, token: Token) !llvm.LLVMValueRef {
  const value = std.fmt.parseInt(i64, token.slice, 10) catch |err| {
    std.debug.print("Error: Invalid number literal '{s}': {}\n", .{ token.slice, err });
    return error.InvalidNumber;
  };

  const i64_type = compiler.getI64Type();
  return llvm.LLVMConstInt(i64_type, @bitCast(value), 0);
}

// Parse an identifier (variable reference)
fn parseIdentifier(compiler: *Compiler, token: Token) !llvm.LLVMValueRef {
  const local = compiler.lookupVariable(token.slice) orelse {
    std.debug.print("Error: Undefined variable '{s}'\n", .{token.slice});
    return error.UndefinedVariable;
  };

  const i64_type = compiler.getI64Type();
  return llvm.LLVMBuildLoad2(
    compiler.builder,
    i64_type,
    local.llvm_value,
    token.slice.ptr
  );
}

// Parse a grouped expression: (expr)
fn parseGrouping(compiler: *Compiler, lexer: *Lexer) !llvm.LLVMValueRef {
  // Parse the inner expression
  const expr = try parseExpression(compiler, lexer);

  // Expect closing parenthesis
  const rparen = lexer.next();
  if (rparen.tag != .rparen) {
    std.debug.print("Error: Expected ')' after expression, got {}\n", .{rparen});
    return error.ExpectedRParen;
  }

  return expr;
}

// Generate LLVM IR for binary operation
fn generateBinaryOp(
  compiler: *Compiler,
  operator: TokenType,
  left: llvm.LLVMValueRef,
  right: llvm.LLVMValueRef,
) !llvm.LLVMValueRef {
  return switch (operator) {
    .plus => llvm.LLVMBuildAdd(compiler.builder, left, right, "add"),
    .minus => llvm.LLVMBuildSub(compiler.builder, left, right, "sub"),
    .asterisk => llvm.LLVMBuildMul(compiler.builder, left, right, "mul"),
    .slash => llvm.LLVMBuildSDiv(compiler.builder, left, right, "div"),

    else => {
      std.debug.print("Error: Invalid binary operator: {}\n", .{operator});
      return error.InvalidOperator;
    },
  };
}
