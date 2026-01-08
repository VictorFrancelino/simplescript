const std = @import("std");
const Compiler = @import("compiler.zig").Compiler;
const optimizer = @import("optimizer.zig");
const statements = @import("statements.zig");

pub fn main() !void {
  var gpa = std.heap.GeneralPurposeAllocator(.{}){};
  defer _ = gpa.deinit();
  const allocator = gpa.allocator();

  const args = try std.process.argsAlloc(allocator);
  defer std.process.argsFree(allocator, args);

  if (args.len < 2) {
    std.debug.print("Usage: simplescript <file.ss>\n", .{});
    std.debug.print("Example: simplescript hello.ss\n", .{});
    return;
  }

  const filename = args[1];

  // Validate file extension
  if (!std.mem.endsWith(u8, filename, ".ss")) {
    std.debug.print("Error: File must have .ss extension\n", .{});
    std.process.exit(1);
  }

  // Initialize LLVM target once
  try optimizer.initNativeTarget();

  // Read source file (1MB max by default)
  const source_code = try readFile(allocator, filename, 1024 * 1024);
  defer allocator.free(source_code);

  // Extract module name without allocation if possible
  const stem = std.fs.path.stem(filename);
  const module_name = try allocator.dupeZ(u8, stem);
  defer allocator.free(module_name);

  // Compile
  var compiler = try Compiler.init(allocator, module_name);
  defer compiler.deinit();

  statements.compile(&compiler, source_code) catch {
    std.process.exit(1);
  };

  compiler.finish();

  // Generate object file
  try optimizer.saveToBinary(compiler.module, "output.o");

  // Link to executable
  const output_name = try std.fmt.allocPrint(allocator, "{s}", .{stem});
  defer allocator.free(output_name);

  try linkExecutable(allocator, output_name);

  // Success message
  std.debug.print("✓ Compiled successfully: {s}\n", .{output_name});
  std.debug.print("Run with: ./{s}\n", .{output_name});
}

fn readFile(allocator: std.mem.Allocator, path: []const u8, max_size: usize) ![]u8 {
  const file = std.fs.cwd().openFile(path, .{}) catch |err| {
    std.debug.print("Error: Cannot open file '{s}': {}\n", .{ path, err });
    return err;
  };

  defer file.close();

  return file.readToEndAlloc(allocator, max_size) catch |err| {
    std.debug.print("Error: Cannot read file '{s}': {}\n", .{ path, err });
    return err;
  };
}

fn linkExecutable(allocator: std.mem.Allocator, output_name: []const u8) !void {
  const result = try std.process.Child.run(.{
    .allocator = allocator,
    .argv = &[_][]const u8{ "clang", "output.o", "-o", output_name },
  });

  defer allocator.free(result.stdout);
  defer allocator.free(result.stderr);

  if (result.term.Exited != 0) {
    std.debug.print("Link error:\n{s}\n", .{result.stderr});
    return error.LinkFailed;
  }
}
