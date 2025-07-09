const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const lib = @import("root").lib;
const Document = lib.Document;
const Serializer = lib.Serializer;
const AssetIndex = lib.AssetIndex;
const UUID = lib.UUIDSerializable;

pub const Node = union(enum) {
    file: File,
    directory: Directory,

    pub const File = struct {
        id: ?UUID,
        path: [:0]const u8,
        name: [:0]const u8,
        documentType: lib.DocumentTag,

        pub fn deinit(self: File, allocator: Allocator) void {
            allocator.free(self.path);
            allocator.free(self.name);
        }
    };

    pub const Directory = struct {
        path: [:0]const u8,
        name: [:0]const u8,

        pub fn deinit(self: Directory, allocator: Allocator) void {
            allocator.free(self.path);
            allocator.free(self.name);
        }
    };

    pub fn deinit(self: Node, allocator: Allocator) void {
        switch (self) {
            inline else => |n| n.deinit(allocator),
        }
    }

    pub fn getPath(self: Node) [:0]const u8 {
        return switch (self) {
            inline else => |n| n.path,
        };
    }
};

pub const AssetsLibrary = struct {
    root: []const u8,
    // TODO: Refactor into arraylist
    currentFilesAndDirectories: ?[]Node = null,
    currentDirectory: ?[:0]const u8 = null,
    dragPayload: ?*Node = null,
    assetTypeFilter: lib.DocumentTag = .scene,
    enableAssetTypeFilter: bool = false,

    pub fn init(allocator: Allocator, root: []const u8) AssetsLibrary {
        return AssetsLibrary{
            .root = std.fs.cwd().realpathAlloc(allocator, root) catch unreachable,
        };
    }

    pub fn deinit(self: *AssetsLibrary, allocator: Allocator) void {
        allocator.free(self.root);
        self.deinitCurrentFilesAndDirectories(allocator);
        self.currentFilesAndDirectories = null;
        self.currentDirectory = null;
    }

    fn deinitCurrentFilesAndDirectories(self: AssetsLibrary, allocator: Allocator) void {
        if (self.currentFilesAndDirectories) |c| {
            for (c) |n| n.deinit(allocator);
            allocator.free(c);
        }
        if (self.currentDirectory) |cd| allocator.free(cd);
    }

    pub const SetCurrentDirectoryError = error{InvalidDirectory};

    pub fn setCurrentDirectory(
        self: *AssetsLibrary,
        allocator: Allocator,
        assetIndex: AssetIndex,
        path: [:0]const u8,
    ) !void {
        if (!self.isValidDirectory(allocator, path)) return SetCurrentDirectoryError.InvalidDirectory;
        const dupedPath = allocator.dupeZ(u8, path) catch unreachable;
        self.deinitCurrentFilesAndDirectories(allocator);
        self.currentFilesAndDirectories = self.readDirectory(allocator, assetIndex, dupedPath);
        self.currentDirectory = dupedPath;
    }

    pub fn appendNewFile(
        self: *AssetsLibrary,
        allocator: Allocator,
        assetIndex: AssetIndex,
        path: [:0]const u8,
    ) void {
        const fileNode = createNodeFromFilePath(allocator, assetIndex, path) catch unreachable;

        if (self.currentFilesAndDirectories) |c| {
            self.currentFilesAndDirectories = std.mem.concat(allocator, Node, &.{
                &.{fileNode},
                c,
            }) catch unreachable;
            allocator.free(c);
        } else {
            self.currentFilesAndDirectories = allocator.alloc(Node, 1) catch unreachable;
            self.currentFilesAndDirectories.?[0] = fileNode;
        }
    }

    pub fn appendNewDirectory(
        self: *AssetsLibrary,
        allocator: Allocator,
        path: [:0]const u8,
    ) void {
        const dirNode = createNodeFromDirectoryPath(allocator, path);

        if (self.currentFilesAndDirectories) |c| {
            self.currentFilesAndDirectories = std.mem.concat(allocator, Node, &.{
                &.{dirNode},
                c,
            }) catch unreachable;
            allocator.free(c);
        } else {
            self.currentFilesAndDirectories = allocator.alloc(Node, 1) catch unreachable;
            self.currentFilesAndDirectories.?[0] = dirNode;
        }
    }

    pub fn removeNode(self: *AssetsLibrary, allocator: Allocator, path: [:0]const u8) void {
        const cfad = self.currentFilesAndDirectories orelse return;

        for (0..cfad.len) |i| {
            const node = cfad[i];
            if (std.mem.eql(u8, path, node.getPath())) {
                defer node.deinit(allocator);
                const start = if (i == 0) &.{} else cfad[0..i];
                const end = if (i == cfad.len - 1) &.{} else cfad[i + 1 ..];
                const newCfad = allocator.alloc(Node, start.len + end.len) catch unreachable;
                self.currentFilesAndDirectories = newCfad;
                defer allocator.free(cfad);

                for (0..start.len) |j| {
                    newCfad[j] = start[j];
                }
                for (0..end.len) |j| {
                    newCfad[start.len + j] = end[j];
                }

                return;
            }
        }
    }

    pub fn openRoot(self: AssetsLibrary) std.fs.Dir {
        return std.fs.openDirAbsolute(
            self.root,
            .{},
        ) catch |err| {
            std.debug.panic("Could not open root dir {s}: {}", .{ self.root, err });
        };
    }

    pub const OpenDirError = error{InvalidDirectory};

    pub fn openDir(
        self: AssetsLibrary,
        allocator: Allocator,
        relativeDir: [:0]const u8,
    ) !std.fs.Dir {
        if (!self.isValidDirectory(allocator, relativeDir)) return OpenDirError.InvalidDirectory;
        const path = std.fs.path.join(allocator, &.{ self.root, relativeDir }) catch unreachable;
        defer allocator.free(path);
        return std.fs.openDirAbsolute(
            path,
            .{},
        ) catch |err| {
            std.debug.panic("Could not open root dir {s}: {}", .{ self.root, err });
        };
    }

    pub const OpenCurrentDirError = error{NoCurrentDirectorySet};

    pub fn openCurrentDirectory(self: AssetsLibrary, allocator: Allocator) !std.fs.Dir {
        const cd = self.currentDirectory orelse return OpenCurrentDirError.NoCurrentDirectorySet;
        return try self.openDir(allocator, cd);
    }

    pub fn isValidDirectory(
        self: AssetsLibrary,
        allocator: Allocator,
        path: [:0]const u8,
    ) bool {
        var rootDir = self.openRoot();
        defer rootDir.close();
        const absolutePath = rootDir.realpathAlloc(allocator, path) catch unreachable;
        defer allocator.free(absolutePath);
        if (!std.mem.startsWith(u8, absolutePath, self.root)) {
            std.log.err("{s} is not a valid directory, does not start with {s}", .{ absolutePath, self.root });
            return false;
        }
        var dir = std.fs.openDirAbsolute(absolutePath, .{ .access_sub_paths = false }) catch |err| {
            std.log.err("{s} is not a valid directory, could not open: {}", .{ absolutePath, err });
            return false;
        };
        defer dir.close();
        return true;
    }

    /// Assumes that path is a valid directory
    fn readDirectory(
        self: AssetsLibrary,
        allocator: Allocator,
        assetIndex: AssetIndex,
        path: [:0]const u8,
    ) []Node {
        var rootDir = self.openRoot();
        defer rootDir.close();
        var targetDir = rootDir.openDir(
            path,
            .{ .iterate = true, .access_sub_paths = false },
        ) catch unreachable;
        defer targetDir.close();
        var it = targetDir.iterate();

        var list = std.ArrayListUnmanaged(Node).initCapacity(allocator, 10) catch unreachable;

        while (it.next() catch |err| {
            const absolutePath = targetDir.realpathAlloc(allocator, path) catch unreachable;
            defer allocator.free(absolutePath);
            std.debug.panic("Could not iterate path {s}: {}", .{ absolutePath, err });
        }) |entry| {
            const entryPath = std.fs.path.joinZ(allocator, &.{ path, entry.name }) catch unreachable;
            defer allocator.free(entryPath);

            // TODO: Make this work on non-windows
            const withoutDotSlash = if (std.mem.startsWith(u8, entryPath, ".\\")) entryPath[2..] else entryPath;

            const node: Node = switch (entry.kind) {
                .file => createNodeFromFilePath(allocator, assetIndex, withoutDotSlash) catch continue,
                .directory => createNodeFromDirectoryPath(allocator, withoutDotSlash),
                else => continue,
            };

            list.append(allocator, node) catch unreachable;
        }

        return list.toOwnedSlice(allocator) catch unreachable;
    }

    pub fn createNodeFromFilePath(
        allocator: Allocator,
        assetIndex: AssetIndex,
        path: [:0]const u8,
    ) !Node {
        const documentType = try Document.getTagByFilePath(path);
        const pathZ = allocator.dupeZ(u8, path) catch unreachable;
        const nameZ = allocator.dupeZ(u8, std.mem.sliceTo(std.fs.path.basename(path), '.')) catch unreachable;
        const id = assetIndex.getId(pathZ);

        return .{ .file = .{
            .id = id,
            .path = pathZ,
            .name = nameZ,
            .documentType = documentType,
        } };
    }

    pub fn createNodeFromDirectoryPath(allocator: Allocator, path: [:0]const u8) Node {
        const pathZ = allocator.dupeZ(u8, path) catch unreachable;
        const nameZ = allocator.dupeZ(u8, std.fs.path.basename(path)) catch unreachable;

        return .{ .directory = .{
            .path = pathZ,
            .name = nameZ,
        } };
    }
};

const AssetsLibrarySerialized = struct {
    sources: []const AssetsSource,

    pub fn init(value: AssetsLibrary) AssetsLibrarySerialized {
        return AssetsLibrarySerialized{
            .sources = value.sources.items,
        };
    }

    pub fn deserialize(self: AssetsLibrarySerialized, allocator: Allocator) AssetsLibrary {
        return AssetsLibrary{
            .sources = ArrayList(AssetsSource).fromOwnedSlice(allocator, self.sources),
        };
    }
};

pub const AssetsSource = union(enum) {
    folder: []const u8,

    pub fn init(allocator: Allocator, folder: []const u8) AssetsSource {
        return AssetsSource{
            .folder = allocator.dupe(u8, folder) catch unreachable,
        };
    }

    pub fn deinit(self: AssetsSource, allocator: Allocator) void {
        allocator.free(self.folder);
    }
};
