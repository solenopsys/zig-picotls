const std = @import("std");
const build_utils = @import("build_utils.zig");

fn buildForTarget(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    artifacts_dir: []const u8,
    hashes: *std.StringHashMap([]const u8),
    json_step: *build_utils.WriteJsonStep,
) void {
    const target_str = build_utils.getTargetString(target);
    const lib_name = build_utils.getLibName(std.heap.page_allocator, "picotls", target_str);

    // Static library
    const lib = b.addLibrary(.{
        .name = lib_name,
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Build picotls C library
    const picotls_c = buildPicotlsC(b, target, optimize, target_str);

    lib.root_module.addIncludePath(b.path("vendor/picotls/include"));
    lib.addObjectFile(picotls_c.getEmittedBin());
    lib.linkLibC();

    const install = b.addInstallArtifact(lib, .{});

    const hash_step = build_utils.HashAndMoveStep.create(
        b,
        lib_name,
        target_str,
        artifacts_dir,
        hashes,
    );
    hash_step.step.dependOn(&install.step);

    json_step.step.dependOn(&hash_step.step);
}

fn buildPicotlsC(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    target_str: []const u8,
) *std.Build.Step.Compile {
    const lib_name = build_utils.getLibName(std.heap.page_allocator, "picotls-c", target_str);

    const picotls_c = b.addLibrary(.{
        .name = lib_name,
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
    });

    const base_flags = [_][]const u8{
        "-std=c11",
        "-Wno-error",
        "-Wno-shift-count-overflow",
        "-fno-sanitize=undefined",
        "-fPIC",
        "-O2",
        "-ffunction-sections",
        "-fdata-sections",
        "-fvisibility=hidden",
        "-DPTLS_HAVE_AEGIS=0",
        "-D_GNU_SOURCE",
    };

    // picotls core sources
    picotls_c.addCSourceFiles(.{
        .root = b.path("vendor/picotls"),
        .files = &.{
            "lib/picotls.c",
            "lib/pembase64.c",
            "lib/cifra.c",
            "lib/cifra/aes128.c",
            "lib/cifra/aes256.c",
            "lib/cifra/chacha20.c",
            "lib/cifra/x25519.c",
            "lib/cifra/random.c",
            "lib/uecc.c",
            "lib/hpke.c",
        },
        .flags = &base_flags,
    });

    // cifra sources
    picotls_c.addCSourceFiles(.{
        .root = b.path("vendor/picotls/deps/cifra/src"),
        .files = &.{
            "aes.c",
            "blockwise.c",
            "modes.c",
            "gcm.c",
            "gf128.c",
            "sha256.c",
            "sha512.c",
            "chash.c",
            "hmac.c",
            "pbkdf2.c",
            "curve25519.c",
            "drbg.c",
            "chacha20.c",
            "poly1305.c",
            "chacha20poly1305.c",
        },
        .flags = &base_flags,
    });

    // micro-ecc sources
    picotls_c.addCSourceFiles(.{
        .root = b.path("vendor/picotls/deps/micro-ecc"),
        .files = &.{
            "uECC.c",
        },
        .flags = &base_flags,
    });

    picotls_c.addIncludePath(b.path("vendor/picotls/include"));
    picotls_c.addIncludePath(b.path("vendor/picotls/deps/cifra/src"));
    picotls_c.addIncludePath(b.path("vendor/picotls/deps/cifra/src/ext"));
    picotls_c.addIncludePath(b.path("vendor/picotls/deps/micro-ecc"));
    picotls_c.linkLibC();

    return picotls_c;
}

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const artifacts_dir = "../../artifacts/libs";
    const json_path = "current.json";

    const build_all = b.option(bool, "all", "Build for all supported targets") orelse false;

    if (build_all) {
        const hashes = build_utils.createHashMap(b);
        const json_step = build_utils.WriteJsonStep.create(b, hashes, json_path);

        for (build_utils.supported_targets) |query| {
            const target = b.resolveTargetQuery(query);
            buildForTarget(b, target, optimize, artifacts_dir, hashes, json_step);
        }

        b.default_step.dependOn(&json_step.step);
    } else {
        const target = b.standardTargetOptions(.{});
        const target_str = build_utils.getTargetString(target);

        const picotls_c = buildPicotlsC(b, target, optimize, target_str);

        const lib_name = build_utils.getLibName(std.heap.page_allocator, "picotls", target_str);

        const lib = b.addLibrary(.{
            .name = lib_name,
            .linkage = .static,
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/main.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });

        lib.root_module.addIncludePath(b.path("vendor/picotls/include"));
        lib.addObjectFile(picotls_c.getEmittedBin());
        lib.linkLibC();

        b.installArtifact(lib);
    }
}
