const std = @import("std");
const Compiler = @import("compiler.zig").Compiler;
const optimizer = @import("optimizer.zig");
const statements = @import("statements.zig");
const llvm = @import("llvm.zig");

pub fn main() !void {
  var gpa = std.heap.GeneralPurposeAllocator(.{}){};
  defer _ = gpa.deinit();
  const allocator = gpa.allocator();

  const args = try std.process.argsAlloc(allocator);
  defer std.process.argsFree(allocator, args);

  if (args.len > 1) {
    const first_arg = args[1];

    if (std.mem.eql(u8, first_arg, "--version") or std.mem.eql(u8, first_arg, "-v")) {
      std.debug.print("0.5.0\n", .{});
      try llvm.printLLVMInfo(allocator);
      return;
    }
  }

  if (args.len < 3) {
    printUsage();
    std.process.exit(1);
  }

  const command = args[1];
  const filename = args[2];

  const is_run = std.mem.eql(u8, command, "run");
  const is_build = std.mem.eql(u8, command, "build");

  if (!is_run and !is_build) {
    std.debug.print("Error: Unknown command '{s}'\n", .{command});
    printUsage();
    std.process.exit(1);
  }

  if (!std.mem.endsWith(u8, filename, ".ss")) {
    std.debug.print("Error: File must have .ss extension\n", .{});
    std.process.exit(1);
  }

  try optimizer.initNativeTarget();
  const source_code = try readFile(allocator, filename, 1024 * 1024);
  defer allocator.free(source_code);

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

  const obj_file = "output.o";
  try optimizer.saveToBinary(compiler.module, obj_file);

  // Link to executable
  const output_name = try std.fmt.allocPrint(allocator, "{s}", .{stem});
  defer allocator.free(output_name);

  try linkExecutable(allocator, obj_file, output_name);

  if (is_run) {
    try runGeneratedExecutable(allocator, output_name);

    std.fs.cwd().deleteFile(obj_file) catch {};
    std.fs.cwd().deleteFile(output_name) catch {};
  } else if (is_build) {
    std.debug.print("✓ Build successful: ./{s}\n", .{output_name});
    std.fs.cwd().deleteFile(obj_file) catch {};
  }
}

fn printUsage() void {
  std.debug.print("SimpleScript CLI\n", .{});
  std.debug.print("Usage: simplescript <command> <file.ss>\n\n", .{});
  std.debug.print("Commands:\n", .{});
  std.debug.print("build - Compile the file and generate a native executable\n", .{});
  std.debug.print("run - Compile, execute, and remove temporary files\n", .{});
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

fn linkExecutable(allocator: std.mem.Allocator, obj_name: []const u8, output_name: []const u8) !void {
  const result = try std.process.Child.run(.{
    .allocator = allocator,
    .argv = &[_][]const u8{ "clang-21", obj_name, "-o", output_name },
  });

  defer allocator.free(result.stdout);
  defer allocator.free(result.stderr);

  if (result.term.Exited != 0) {
    std.debug.print("Link error (Is LLVM/Clang 21 installed?):\n{s}\n", .{result.stderr});
    return error.LinkFailed;
  }
}

fn runGeneratedExecutable(allocator: std.mem.Allocator, exe_name: []const u8) !void {
  const run_cmd = try std.fmt.allocPrint(allocator, "./{s}", .{exe_name});
  defer allocator.free(run_cmd);

  var child = std.process.Child.init(&[_][]const u8{run_cmd}, allocator);
  _ = try child.spawnAndWait();
}
