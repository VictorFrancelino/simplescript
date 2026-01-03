const std = @import("std");
const vm_mod = @import("vm.zig");
const Compiler = @import("compiler.zig").Compiler;

pub fn main() !void {
  var gpa = std.heap.GeneralPurposeAllocator(.{}){};
  defer _ = gpa.deinit();
  const allocator = gpa.allocator();

  const source_code =
    \\say('Iniciando Benchmark...')
    \\say(123456)
    \\say('Fim.')
    \\say(10 + 20)
    \\say(10 + 20 + 30 + 40 + 50)
  ;

  std.debug.print("==================================\n", .{});
  std.debug.print("SIMPLE SCRIPT ENGINE - BENCHMARK\n", .{});
  std.debug.print("==================================\n", .{});

  var timer = try std.time.Timer.start();

  var compiler = Compiler.init(allocator);
  defer compiler.deinit();

  try compiler.compile(source_code);

  const compile_time = timer.read();

  var vm = vm_mod.VM{
    .registers = undefined,
    .constants = compiler.constants.items,
    .pc = 0,
  };

  timer.reset();
  try vm.run(compiler.instructions.items);

  const run_time = timer.read();

  std.debug.print("\n----------------------------------\n", .{});
  std.debug.print("RELATORIO DE PERFORMANCE:\n", .{});

  const compile_ms = @as(f64, @floatFromInt(compile_time)) / 1_000_000.0;
  const run_ms = @as(f64, @floatFromInt(run_time)) / 1_000_000.0;

  std.debug.print("Tempo de Compilacao: {d:.4} ms\n", .{ compile_ms });
  std.debug.print("Tempo de Execucao:   {d:.4} ms\n", .{ run_ms });
  std.debug.print("----------------------------------\n", .{});
}
