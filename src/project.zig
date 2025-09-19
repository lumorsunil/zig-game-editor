const std = @import("std");
const Allocator = std.mem.Allocator;
const rl = @import("raylib");

const lib = @import("lib");
const UUID = lib.UUIDSerializable;

const AssetsLibrary = @import("assets-library.zig").AssetsLibrary;
const AssetIndex = @import("asset-index.zig").AssetIndex;
const Thumbnails = @import("thumbnails.zig").Thumbnails;
pub const ProjectOptions = @import("project-options.zig").ProjectOptions;

pub const cacheDirectoryName = "cache";
pub const optionsRelativePath = "project.json";

pub const Project = struct {
    assetsLibrary: AssetsLibrary,
    assetIndex: AssetIndex = .empty,
    thumbnails: Thumbnails = .empty,
    cacheDirectory: []const u8,
    options: ProjectOptions,
    isProjectOptionsOpen: bool = false,
    focusSetProjectCommand: bool = false,

    pub fn init(allocator: Allocator, root: []const u8) Project {
        return Project{
            .assetsLibrary = AssetsLibrary.init(allocator, root),
            .cacheDirectory = std.fs.path.join(allocator, &.{ root, cacheDirectoryName }) catch unreachable,
            .options = .init(allocator),
        };
    }

    pub fn deinit(self: *Project, allocator: Allocator) void {
        self.assetsLibrary.deinit(allocator);
        self.assetIndex.deinit(allocator);
        self.thumbnails.deinit(allocator);
        self.options.deinit(allocator);
        allocator.free(self.cacheDirectory);
    }

    pub fn getRootDirPath(self: Project) []const u8 {
        return self.assetsLibrary.root;
    }

    pub fn setCurrentDirectory(
        self: *Project,
        allocator: Allocator,
        path: [:0]const u8,
    ) !void {
        try self.assetsLibrary.setCurrentDirectory(allocator, self.assetIndex, path);
    }

    pub fn loadOptions(self: *Project, allocator: Allocator) !void {
        self.options = try ProjectOptions.load(allocator, self);
    }

    pub fn saveOptions(self: *Project) !void {
        try self.options.save(self.*);
    }

    pub fn loadIndex(self: *Project, allocator: Allocator) !void {
        try self.assetIndex.load(allocator, self.getRootDirPath(), self.cacheDirectory);
    }

    pub fn saveIndex(self: Project) !void {
        try self.assetIndex.save(self.cacheDirectory);
    }

    pub fn rebuildIndex(self: *Project, allocator: Allocator) !void {
        try self.assetIndex.rebuildIndex(allocator, self.getRootDirPath());
    }

    pub fn requestThumbnailById(self: *Project, allocator: Allocator, id: UUID) !?*rl.Texture2D {
        return self.thumbnails.requestById(allocator, id, self.cacheDirectory);
    }

    pub fn updateThumbnailById(
        self: *Project,
        allocator: Allocator,
        id: UUID,
        image: rl.Image,
    ) !void {
        return self.thumbnails.updateById(allocator, id, self.cacheDirectory, image);
    }
};
