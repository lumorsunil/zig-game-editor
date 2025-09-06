const std = @import("std");
const Allocator = std.mem.Allocator;
const lib = @import("lib");
const UUID = lib.UUIDSerializable;
const Project = lib.Project;
const optionsRelativePath = lib.project.optionsRelativePath;
const Vector = lib.Vector;
const io = @import("zig-io");

pub const ProjectOptions = struct {
    entryScene: ?UUID = null,
    defaultTileset: ?UUID = null,
    tileSize: Vector = .{ 16, 16 },
    tilesetPadding: u32 = 4,

    pub const empty: ProjectOptions = .{};

    pub fn load(project: *Project, allocator: Allocator) !ProjectOptions {
        var filePathBuffer: [std.posix.PATH_MAX]u8 = undefined;
        var bufferAllocator = std.heap.FixedBufferAllocator.init(&filePathBuffer);

        const filePath = std.fs.path.join(bufferAllocator.allocator(), &.{
            project.getRootDirPath(),
            optionsRelativePath,
        }) catch unreachable;

        return try io.readJsonFileLeaky(ProjectOptions, allocator, filePath, .{});
    }

    pub fn save(self: ProjectOptions, project: Project) !void {
        var filePathBuffer: [std.posix.PATH_MAX]u8 = undefined;
        var bufferAllocator = std.heap.FixedBufferAllocator.init(&filePathBuffer);

        const filePath = std.fs.path.join(bufferAllocator.allocator(), &.{
            project.getRootDirPath(),
            optionsRelativePath,
        }) catch unreachable;

        try io.writeJsonFile(filePath, self, .{});
    }
};
