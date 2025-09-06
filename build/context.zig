const std = @import("std");

const Build = std.Build;
const Dependency = Build.Dependency;
const Module = Build.Module;
const LazyPath = Build.LazyPath;

const zxg = @import("zxg");

const utils = @import("utils.zig");

pub const Context = struct {
    deps: struct {
        nfd: *Dependency,
        uuid: *Dependency,
        zig_io: *Dependency,
    },
    modules: struct {
        c: *Module,
        nfd: *Module,
        uuid: *Module,
        @"zig-io": *Module,
    },

    pub fn init(b: *Build, options: anytype) Context {
        const target = options.target;
        const optimize = options.optimize;

        const cModule = b.createModule(.{
            .root_source_file = b.path("lib/c.zig"),
            .target = target,
            .optimize = optimize,
        });
        zxg.setup(b, cModule, .{
            .target = target,
            .optimize = optimize,
            .backend = .Zgui,
        });

        const nfdDep = b.dependency("nfd_zig", .{
            .target = target,
            .optimize = optimize,
        });

        const uuidDep = b.dependency("uuid", .{
            .target = target,
            .optimize = optimize,
        });

        const zigIoDep = b.dependency("zig_io", .{
            .target = target,
            .optimize = optimize,
        });

        return Context{
            .deps = .{
                .nfd = nfdDep,
                .uuid = uuidDep,
                .zig_io = zigIoDep,
            },
            .modules = .{
                .nfd = nfdDep.module("nfd"),
                .c = cModule,
                .uuid = uuidDep.module("uuid"),
                .@"zig-io" = zigIoDep.module("zig_io"),
            },
        };
    }

    fn add(self: Context, comptime key: []const u8, target: *Module) void {
        target.addImport(key, @field(self.modules, key));
    }

    pub fn addC(self: Context, target: *Module) void {
        self.add("c", target);
        utils.addModuleImports(&.{target}, self.modules.c);
    }

    pub fn addNfd(self: Context, target: *Module) void {
        self.add("nfd", target);
    }

    pub fn addUuid(self: Context, target: *Module) void {
        self.add("uuid", target);
    }

    pub fn addZigIo(self: Context, target: *Module) void {
        self.add("zig-io", target);
    }
};
