const std = @import("std");

pub fn build(b: *std.Build) void {
  const target = b.standardTargetOptions(.{});
  const optimize = b.standardOptimizeOption(.{});

  const exe = b.addExecutable(.{
    .name = "simplescript",
    .root_module = b.createModule(.{
      .root_source_file = b.path("src/main.zig"),
      .target = target,
      .optimize = optimize,
    }),
  });

  const llvm_config = "llvm-config-21";

  const include_path = b.run(&[_][]const u8{ llvm_config, "--includedir" });
  const lib_path = b.run(&[_][]const u8{ llvm_config, "--libdir" });

  exe.addIncludePath(.{ .cwd_relative = std.mem.trim(u8, include_path, " \n\r") });
  exe.addLibraryPath(.{ .cwd_relative = std.mem.trim(u8, lib_path, " \n\r") });

  exe.linkLibC();
  exe.linkSystemLibrary("c++");
  exe.linkSystemLibrary("LLVM-21");

  if (target.result.os.tag == .linux) exe.linkSystemLibrary("z");

  b.installArtifact(exe);

  const run_cmd = b.addRunArtifact(exe);
  run_cmd.step.dependOn(b.getInstallStep());
  if (b.args) |args| run_cmd.addArgs(args);

  const run_step = b.step("run", "Run the app");
  run_step.dependOn(&run_cmd.step);
}
