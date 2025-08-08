const std = @import("std");
const Allocator = std.mem.Allocator;
const lib = @import("lib");
const UUID = lib.UUIDSerializable;
const IdArrayHashMap = lib.IdArrayHashMap;
const DocumentTag = lib.DocumentTag;
const Document = lib.Document;
const cacheDirectoryName = lib.cacheDirectoryName;
const projectJsonFileName = lib.optionsRelativePath;

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

    pub fn load(
        self: *AssetIndex,
        allocator: Allocator,
        projectDirectory: []const u8,
        cacheDirectory: []const u8,
    ) !void {
        _ = cacheDirectory; // autofix
        // if (try self.loadExistingIndex(allocator, cacheDirectory)) return;
        try self.rebuildIndex(allocator, projectDirectory);
    }

    // Returns true if loaded successfully and has at least one index
    fn loadExistingIndex(
        self: *AssetIndex,
        allocator: Allocator,
        cacheDirectory: []const u8,
    ) !bool {
        var dir = try std.fs.openDirAbsolute(cacheDirectory, .{});
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
        const jsonData = std.json.parseFromTokenSourceLeaky(IdArrayHashMap([:0]const u8), allocator, &jsonReader, .{ .ignore_unknown_fields = true }) catch |err| {
            std.log.err("Could not read {s}: {}", .{ indexJsonFileName, err });
            return false;
        };
        self.hashMap = jsonData;

        if (jsonData.map.count() == 0) {
            return false;
        }

        return true;
    }

    pub fn rebuildIndex(
        self: *AssetIndex,
        allocator: Allocator,
        projectDirectory: []const u8,
    ) !void {
        self.deinit(allocator);
        self.hashMap = .empty;

        var dir = try std.fs.openDirAbsolute(projectDirectory, .{ .iterate = true });
        defer dir.close();

        var walker = try dir.walk(allocator);
        defer walker.deinit();
        while (try walker.next()) |entry| {
            switch (entry.kind) {
                .file => {
                    if (std.mem.eql(u8, entry.path, indexJsonFileName)) continue;
                    if (std.mem.eql(u8, entry.path, projectJsonFileName)) continue;
                    if (std.fs.path.dirname(entry.path)) |dirname| if (std.mem.eql(u8, dirname, cacheDirectoryName)) continue;
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

    pub fn save(self: AssetIndex, cacheDirectory: []const u8) !void {
        std.fs.makeDirAbsolute(cacheDirectory) catch |err| {
            switch (err) {
                std.posix.MakeDirError.PathAlreadyExists => {},
                else => return err,
            }
        };
        var dir = try std.fs.openDirAbsolute(cacheDirectory, .{});
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
        const filePath_ = allocator.dupeZ(u8, normalizeIndex(filePath)) catch unreachable;
        self.hashMap.map.put(allocator, key, filePath_) catch unreachable;
    }

    // Returns true if entry was removed
    pub fn removeIndex(
        self: *AssetIndex,
        allocator: Allocator,
        key: UUID,
    ) bool {
        const entry = self.hashMap.map.fetchSwapRemove(key) orelse return false;
        allocator.free(entry.value);
        return true;
    }

    pub fn updateIndex(
        self: *AssetIndex,
        allocator: Allocator,
        key: UUID,
        newIndex: [:0]const u8,
    ) void {
        const index = self.hashMap.map.getPtr(key) orelse return;
        allocator.free(index.*);
        index.* = allocator.dupeZ(u8, normalizeIndex(newIndex)) catch unreachable;
    }

    pub fn getIndex(
        self: AssetIndex,
        id: UUID,
    ) ?[:0]const u8 {
        return (self.getIndexPtr(id) orelse return null).*;
    }

    pub fn getIndexPtr(
        self: AssetIndex,
        id: UUID,
    ) ?*[:0]const u8 {
        const filePath = self.hashMap.map.getPtr(id) orelse {
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
        const normalized = normalizeIndex(filePath);

        for (self.hashMap.map.values(), 0..) |value, i| {
            if (std.mem.eql(u8, value, normalized)) {
                return self.hashMap.map.keys()[i];
            }
        }

        return null;
    }

    pub fn normalizeIndex(index: [:0]const u8) [:0]const u8 {
        return if (std.mem.startsWith(u8, index, "." ++ std.fs.path.sep_str))
            index[1 + std.fs.path.sep_str.len ..]
        else
            index;
    }

    pub fn getIdsByDocumentType(
        self: AssetIndex,
        allocator: Allocator,
        comptime documentType: DocumentTag,
    ) []UUID {
        var ids = std.ArrayListUnmanaged(UUID).initCapacity(allocator, 128) catch unreachable;

        for (self.hashMap.map.values(), 0..) |filePath, i| {
            const dt = Document.getTagByFilePath(filePath) catch |err| {
                std.log.err("Could not get document type from {s}: {}", .{ filePath, err });
                continue;
            };
            switch (dt) {
                documentType => ids.append(allocator, self.hashMap.map.keys()[i]) catch unreachable,
                else => continue,
            }
        }

        return ids.toOwnedSlice(allocator) catch unreachable;
    }
};
