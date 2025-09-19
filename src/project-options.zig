const std = @import("std");
const Allocator = std.mem.Allocator;
const lib = @import("lib");
const UUID = lib.UUIDSerializable;
const Project = lib.Project;
const optionsRelativePath = lib.project.optionsRelativePath;
const Vector = lib.Vector;
const io = @import("zig-io");
const StringZ = lib.StringZ;

pub const ProjectOptions = struct {
    version: lib.documents.DocumentVersion = currentVersion,
    playCommand: StringZ,
    playCommandCwd: StringZ,
    entryScene: ?UUID = null,
    defaultTileset: ?UUID = null,
    tileSize: Vector = .{ 16, 16 },
    tilesetPadding: u32 = 4,

    pub const currentVersion: lib.documents.DocumentVersion = lib.upgrade.finalUpgraderVersion(@This());

    pub const upgraders = &.{
        @import("project-options/upgraders/0-1.zig"),
        @import("project-options/upgraders/1-2.zig"),
    };

    pub const UpgradeContainer = lib.upgrade.Container.init(&.{});

    pub fn init(allocator: Allocator) ProjectOptions {
        return .{
            .playCommand = .init(allocator, ""),
            .playCommandCwd = .init(allocator, ""),
        };
    }

    pub fn deinit(self: ProjectOptions, allocator: Allocator) void {
        self.playCommand.deinit(allocator);
        self.playCommandCwd.deinit(allocator);
    }

    fn getFilePath(project: *Project, buffer: []u8) []const u8 {
        var bufferAllocator = std.heap.FixedBufferAllocator.init(buffer);

        const filePath = std.fs.path.join(bufferAllocator.allocator(), &.{
            project.getRootDirPath(),
            optionsRelativePath,
        }) catch unreachable;

        return filePath;
    }

    pub fn load(allocator: Allocator, project: *Project) !ProjectOptions {
        var filePathBuffer: [std.posix.PATH_MAX]u8 = undefined;
        const filePath = getFilePath(project, &filePathBuffer);
        const projectOptions = try lib.documents.DocumentGeneric(
            ProjectOptions,
            struct {},
            .{},
        ).parseFileAndHandleUpgrades(
            allocator,
            std.fs.cwd(),
            filePath,
        );
        defer allocator.destroy(projectOptions);
        return projectOptions.*;
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

    pub fn hasPlayCommand(self: ProjectOptions) bool {
        return std.mem.trim(u8, self.playCommand.slice(), " \t").len > 0;
    }

    pub fn getPlayCommandBuffer(self: ProjectOptions) [:0]u8 {
        return self.playCommand.buffer;
    }

    pub fn getPlayCommandCwd(self: ProjectOptions) ?[]const u8 {
        const slice = self.playCommandCwd.slice();
        if (slice.len == 0) return null;
        return slice;
    }
};
