const std = @import("std");
const vm_mod = @import("vm/root.zig");
const Compiler = @import("compiler/root.zig").Compiler;

pub fn main() !void {
  var gpa = std.heap.GeneralPurposeAllocator(.{}){};
  defer _ = gpa.deinit();
  const allocator = gpa.allocator();

  const args = try std.process.argsAlloc(allocator);
  defer std.process.argsFree(allocator, args);

  const filename = args[1];

  const max_size = 1024 * 1024;
  const source_code = try readFile(allocator, filename, max_size);
  defer allocator.free(source_code);

  var compiler = Compiler.init(allocator);
  defer compiler.deinit();

  try compiler.compile(source_code);

  var vm = vm_mod.VM{
    .registers = undefined,
    .constants = compiler.constants.items,
    .pc = 0,
  };

  try vm.run(compiler.instructions.items);
}

fn readFile(allocator: std.mem.Allocator, filename: []const u8, max_size: usize) ![]u8 {
  const file = try std.fs.cwd().openFile(filename, .{});
  defer file.close();
  return file.readToEndAlloc(allocator, max_size);
}
