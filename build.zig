const std = @import("std");
const sokol = @import("deps/sokol-zig/build.zig");
const zstbi = @import("deps/zstbi/build.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "ProjectChuuni",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const sokolBuild = sokol.buildSokol(b, target, optimize, .{}, "deps/sokol-zig/");
    const sokolModule = b.addModule("sokol", .{
        .source_file = std.Build.FileSource.relative("deps/sokol-zig/src/sokol/sokol.zig"),
    });
    exe.addModule("sokol", sokolModule);
    exe.linkLibrary(sokolBuild);

    exe.addIncludePath("deps/nuklear/");

    const zstbiPkg = zstbi.package(b, target, optimize, .{});
    zstbiPkg.link(exe);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    // const unit_tests = b.addTest(.{
    //     .root_source_file = .{ .path = "src/main.zig" },
    //     .target = target,
    //     .optimize = optimize,
    // });

    // const run_unit_tests = b.addRunArtifact(unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    // const test_step = b.step("test", "Run unit tests");
    // test_step.dependOn(&run_unit_tests.step);
}
