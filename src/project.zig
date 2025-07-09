const std = @import("std");
const Allocator = std.mem.Allocator;
const rl = @import("raylib");

const lib = @import("root").lib;
const UUID = lib.UUIDSerializable;

const AssetsLibrary = @import("assets-library.zig").AssetsLibrary;
const AssetIndex = @import("asset-index.zig").AssetIndex;
const Thumbnails = @import("thumbnails.zig").Thumbnails;
const ProjectOptions = @import("project-options.zig").ProjectOptions;

pub const cacheDirectoryName = "cache";
pub const optionsRelativePath = "project.json";

pub const Project = struct {
    assetsLibrary: AssetsLibrary,
    assetIndex: AssetIndex,
    thumbnails: Thumbnails,
    cacheDirectory: []const u8,
    options: ProjectOptions,

    pub fn init(allocator: Allocator, root: []const u8) Project {
        return Project{
            .assetsLibrary = AssetsLibrary.init(allocator, root),
            .assetIndex = .empty,
            .thumbnails = .empty,
            .cacheDirectory = std.fs.path.join(allocator, &.{ root, cacheDirectoryName }) catch unreachable,
            .options = .empty,
        };
    }

    pub fn deinit(self: *Project, allocator: Allocator) void {
        self.assetsLibrary.deinit(allocator);
        self.assetIndex.deinit(allocator);
        self.thumbnails.deinit(allocator);
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
        const filePath = std.fs.path.join(allocator, &.{
            self.getRootDirPath(),
            optionsRelativePath,
        }) catch unreachable;
        defer allocator.free(filePath);
        const file = std.fs.openFileAbsolute(filePath, .{}) catch |err| {
            std.log.err("Could not open {s}: {}", .{ filePath, err });
            return;
        };
        defer file.close();
        var buffer: [1024]u8 = undefined;
        const len = file.readAll(&buffer) catch |err| {
            std.log.err("Could not read {s}: {}", .{ filePath, err });
            return;
        };
        if (len == buffer.len) {
            std.log.warn("Length of {s} is exactly matching the buffer size. Probably need to bump it up or change the algorithm.", .{filePath});
        }
        const fileContent = buffer[0..len];
        self.options = std.json.parseFromSliceLeaky(ProjectOptions, allocator, fileContent, .{}) catch |err| {
            std.log.err("Could not parse project options json: {}", .{err});
            return;
        };
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
