const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const lib = @import("root").lib;
const Document = lib.Document;
const Serializer = lib.Serializer;

pub const Node = union(enum) {
    file: File,
    directory: Directory,

    pub const File = struct {
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
};

pub const AssetsLibrary = struct {
    root: []const u8,
    currentFilesAndDirectories: ?[]Node = null,

    pub fn init(allocator: Allocator, root: []const u8) AssetsLibrary {
        return AssetsLibrary{
            .root = std.fs.cwd().realpathAlloc(allocator, root) catch unreachable,
        };
    }

    pub fn deinit(self: *AssetsLibrary, allocator: Allocator) void {
        allocator.free(self.root);
        self.deinitCurrentFilesAndDirectories(allocator);
        self.currentFilesAndDirectories = null;
    }

    fn deinitCurrentFilesAndDirectories(self: AssetsLibrary, allocator: Allocator) void {
        if (self.currentFilesAndDirectories) |c| {
            for (c) |n| n.deinit(allocator);
            allocator.free(c);
        }
    }

    pub const SetCurrentDirectoryError = error{InvalidDirectory};

    pub fn setCurrentDirectory(
        self: *AssetsLibrary,
        allocator: Allocator,
        path: []const u8,
    ) !void {
        if (!self.isValidDirectory(allocator, path)) return SetCurrentDirectoryError.InvalidDirectory;
        self.deinitCurrentFilesAndDirectories(allocator);
        self.currentFilesAndDirectories = self.readDirectory(allocator, path);
    }

    pub fn appendNewFile(self: *AssetsLibrary, allocator: Allocator, path: []const u8) void {
        const fileNode = createNodeFromFilePath(allocator, path);

        if (self.currentFilesAndDirectories) |c| {
            self.currentFilesAndDirectories = std.mem.concat(allocator, Node, &.{
                c,
                &.{fileNode},
            }) catch unreachable;
            allocator.free(c);
        } else {
            self.currentFilesAndDirectories = allocator.alloc(Node, 1) catch unreachable;
            self.currentFilesAndDirectories.?[0] = fileNode;
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

    pub fn isValidDirectory(
        self: AssetsLibrary,
        allocator: Allocator,
        path: []const u8,
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
    fn readDirectory(self: AssetsLibrary, allocator: Allocator, path: []const u8) []Node {
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
            const node: Node = switch (entry.kind) {
                .file => createNodeFromFilePath(allocator, entry.name),
                .directory => createNodeFromDirectoryPath(allocator, entry.name),
                else => continue,
            };

            list.append(allocator, node) catch unreachable;
        }

        return list.toOwnedSlice(allocator) catch unreachable;
    }

    pub fn createNodeFromFilePath(allocator: Allocator, path: []const u8) Node {
        const pathZ = allocator.dupeZ(u8, path) catch unreachable;
        const nameZ = allocator.dupeZ(u8, std.mem.sliceTo(std.fs.path.basename(path), '.')) catch unreachable;

        return .{ .file = .{
            .path = pathZ,
            .name = nameZ,
            .documentType = Document.getTagByFilePath(path),
        } };
    }

    pub fn createNodeFromDirectoryPath(allocator: Allocator, path: []const u8) Node {
        const pathZ = allocator.dupeZ(u8, path) catch unreachable;
        const nameZ = allocator.dupeZ(u8, std.mem.sliceTo(std.fs.path.basename(path), '.')) catch unreachable;

        return .{ .directory = .{
            .path = pathZ,
            .name = nameZ,
        } };
    }

    // pub usingnamespace Serializer.MakeSerialize(
    //     @This(),
    //     AssetsLibrarySerialized,
    //     AssetsLibrarySerialized.init,
    //     AssetsLibrarySerialized.deserialize,
    // );
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
