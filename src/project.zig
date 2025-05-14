const std = @import("std");
const Allocator = std.mem.Allocator;

const AssetsLibrary = @import("assets-library.zig").AssetsLibrary;

pub const Project = struct {
    assetsLibrary: AssetsLibrary,

    pub fn init(allocator: Allocator, root: []const u8) Project {
        return Project{
            .assetsLibrary = AssetsLibrary.init(allocator, root),
        };
    }

    pub fn deinit(self: *Project, allocator: Allocator) void {
        self.assetsLibrary.deinit(allocator);
    }
};
