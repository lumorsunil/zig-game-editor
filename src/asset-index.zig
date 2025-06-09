const std = @import("std");
const Allocator = std.mem.Allocator;
const lib = @import("root").lib;
const UUID = lib.UUIDSerializable;
const uuid = @import("uuid");
const IdArrayHashMap = lib.IdArrayHashMap;

const indexJsonFileName = "index.json";

const AssetId = struct {
    id: UUID,
};

pub const AssetIndex = struct {
    hashMap: IdArrayHashMap([:0]const u8),

    pub const empty: AssetIndex = .{
        .hashMap = .empty,
    };

    pub fn deinit(self: *AssetIndex, allocator: Allocator) void {
        for (self.hashMap.map.values()) |value| {
            allocator.free(value);
        }
        self.hashMap.deinit(allocator);
    }

    pub fn load(self: *AssetIndex, allocator: Allocator, projectDirectory: []const u8) !void {
        if (try self.loadExistingIndex(allocator, projectDirectory)) return;
        try self.rebuildIndex(allocator, projectDirectory);
    }

    fn loadExistingIndex(
        self: *AssetIndex,
        allocator: Allocator,
        projectDirectory: []const u8,
    ) !bool {
        var dir = try std.fs.openDirAbsolute(projectDirectory, .{});
        defer dir.close();

        const file = dir.openFile(indexJsonFileName, .{}) catch |err| {
            switch (err) {
                std.fs.File.OpenError.FileNotFound => return false,
                else => return err,
            }
        };
        defer file.close();
        const reader = file.reader();
        var jsonReader = std.json.reader(allocator, reader);
        defer jsonReader.deinit();
        const jsonData = try std.json.parseFromTokenSourceLeaky(IdArrayHashMap([:0]const u8), allocator, &jsonReader, .{ .ignore_unknown_fields = true });
        self.hashMap = jsonData;

        return true;
    }

    fn rebuildIndex(self: *AssetIndex, allocator: Allocator, projectDirectory: []const u8) !void {
        var dir = try std.fs.openDirAbsolute(projectDirectory, .{ .iterate = true });
        defer dir.close();

        var walker = try dir.walk(allocator);
        defer walker.deinit();
        while (try walker.next()) |entry| {
            switch (entry.kind) {
                .file => {
                    if (std.mem.eql(u8, entry.path, indexJsonFileName)) continue;
                    if (!std.mem.endsWith(u8, entry.path, ".json")) continue;

                    const file = try dir.openFile(entry.path, .{});
                    defer file.close();
                    const reader = file.reader();
                    var jsonReader = std.json.reader(allocator, reader);
                    defer jsonReader.deinit();
                    const parsed = std.json.parseFromTokenSource(AssetId, allocator, &jsonReader, .{ .ignore_unknown_fields = true }) catch |err| {
                        std.log.err("Could not parse json {s}, {}", .{ entry.path, err });
                        return err;
                    };
                    defer parsed.deinit();
                    const id = parsed.value.id;
                    const filePath = allocator.dupeZ(u8, entry.path) catch unreachable;
                    try self.hashMap.map.put(allocator, id, filePath);
                },
                else => continue,
            }
        }
    }

    pub fn save(self: AssetIndex, projectDirectory: []const u8) !void {
        var dir = try std.fs.openDirAbsolute(projectDirectory, .{});
        defer dir.close();
        const file = try dir.createFile(indexJsonFileName, .{});
        defer file.close();
        const writer = file.writer();
        try std.json.stringify(self.hashMap, .{}, writer);
    }

    pub fn addIndex(
        self: *AssetIndex,
        allocator: Allocator,
        key: UUID,
        filePath: [:0]const u8,
    ) void {
        const filePath_ = allocator.dupeZ(u8, filePath) catch unreachable;
        self.hashMap.map.put(allocator, key, filePath_) catch unreachable;
    }

    pub fn getIndex(
        self: AssetIndex,
        id: UUID,
    ) ?[:0]const u8 {
        const filePath = self.hashMap.map.get(id) orelse {
            std.log.debug("Could not match id: {}", .{id});
            std.log.debug("Index:", .{});
            for (self.hashMap.map.keys(), 0..) |key, i| {
                std.log.debug("{d}: {} --> {s}", .{ i, key, self.hashMap.map.values()[i] });
            }
            return null;
        };

        return filePath;
    }

    pub fn getId(
        self: AssetIndex,
        filePath: [:0]const u8,
    ) ?UUID {
        for (self.hashMap.map.values(), 0..) |value, i| {
            if (std.mem.eql(u8, value, filePath)) {
                return self.hashMap.map.keys()[i];
            }
        }

        return null;
    }
};
