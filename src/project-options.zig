const std = @import("std");
const Allocator = std.mem.Allocator;
const lib = @import("lib");
const UUID = lib.UUIDSerializable;
const Project = lib.Project;
const optionsRelativePath = lib.optionsRelativePath;
const Vector = lib.Vector;

pub const ProjectOptions = struct {
    entryScene: ?UUID = null,
    defaultTileset: ?UUID = null,
    tileSize: Vector = .{ 16, 16 },
    tilesetPadding: u32 = 4,

    pub const empty: ProjectOptions = .{};

    pub fn load(project: *Project, allocator: Allocator) !ProjectOptions {
        const filePath = std.fs.path.join(allocator, &.{
            project.getRootDirPath(),
            optionsRelativePath,
        }) catch unreachable;
        defer allocator.free(filePath);
        const file = std.fs.openFileAbsolute(filePath, .{}) catch |err| {
            std.log.err("Could not open {s}: {}", .{ filePath, err });
            return err;
        };
        defer file.close();
        var buffer: [1024]u8 = undefined;
        const len = file.readAll(&buffer) catch |err| {
            std.log.err("Could not read {s}: {}", .{ filePath, err });
            return err;
        };
        if (len == buffer.len) {
            std.log.warn("Length of {s} is exactly matching the buffer size. Probably need to bump it up or change the algorithm.", .{filePath});
        }
        const fileContent = buffer[0..len];
        return std.json.parseFromSliceLeaky(ProjectOptions, allocator, fileContent, .{}) catch |err| {
            std.log.err("Could not parse project options json: {}", .{err});
            return err;
        };
    }

    pub fn save(self: ProjectOptions, allocator: Allocator, project: Project) !void {
        const filePath = std.fs.path.join(allocator, &.{
            project.getRootDirPath(),
            optionsRelativePath,
        }) catch unreachable;
        defer allocator.free(filePath);
        const file = std.fs.createFileAbsolute(filePath, .{}) catch |err| {
            std.log.err("Could not open {s}: {}", .{ filePath, err });
            return err;
        };
        defer file.close();
        const writer = file.writer();
        std.json.stringify(self, .{}, writer) catch |err| {
            std.log.err("Could not save project options {s}: {}", .{ filePath, err });
            return err;
        };
    }
};
