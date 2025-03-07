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
    },
    modules: struct {
        c: *Module,
        nfd: *Module,
        uuid: *Module,
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

        const nfdDep = b.dependency("nfd-zig", .{
            .target = target,
            .optimize = optimize,
        });

        const uuidDep = b.dependency("uuid", .{
            .target = target,
            .optimize = optimize,
        });

        return Context{
            .deps = .{
                .nfd = nfdDep,
                .uuid = uuidDep,
            },
            .modules = .{
                .nfd = nfdDep.module("nfd"),
                .c = cModule,
                .uuid = uuidDep.module("uuid"),
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
};
