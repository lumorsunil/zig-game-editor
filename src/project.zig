const std = @import("std");
const Allocator = std.mem.Allocator;

const AssetsLibrary = @import("assets-library.zig").AssetsLibrary;
const AssetIndex = @import("asset-index.zig").AssetIndex;

pub const Project = struct {
    assetsLibrary: AssetsLibrary,
    assetIndex: AssetIndex,

    pub fn init(allocator: Allocator, root: []const u8) Project {
        return Project{
            .assetsLibrary = AssetsLibrary.init(allocator, root),
            .assetIndex = .empty,
        };
    }

    pub fn deinit(self: *Project, allocator: Allocator) void {
        self.assetsLibrary.deinit(allocator);
        self.assetIndex.deinit(allocator);
    }
};
