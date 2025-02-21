const std = @import("std");
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const rl = @import("raylib");
const Tool = @import("tool.zig").Tool;
const BrushTool = @import("tools/brush.zig").BrushTool;
const FileData = @import("file-data.zig").FileData;
const Vector = @import("vector.zig").Vector;
const VectorInt = @import("vector.zig").VectorInt;
const nfd = @import("nfd");
const EditorSession = @import("editor-session.zig").EditorSession;

var __tools = [_]Tool{
    Tool.init("brush", .{ .brush = BrushTool.init() }),
};

pub const Context = struct {
    allocator: Allocator,
    tilemapArena: ArenaAllocator,

    defaultPath: [:0]const u8,
    currentFileName: ?[:0]const u8 = null,

    backgroundColor: rl.Color = rl.Color.init(125, 125, 155, 255),
    isDemoWindowOpen: bool = false,
    isDemoWindowEnabled: bool = false,
    camera: rl.Camera2D,

    currentTool: ?*Tool = &__tools[0],

    tools: []Tool = &__tools,

    textures: std.StringHashMap(rl.Texture2D),
    fileData: *FileData,
    scale: VectorInt = 4,
    scaleV: Vector = .{ 4, 4 },

    const defaultSize: Vector = .{ 35, 17 };
    const defaultTileSize: Vector = .{ 16, 16 };

    pub fn init(allocator: Allocator) Context {
        return Context{
            .allocator = allocator,
            .tilemapArena = ArenaAllocator.init(allocator),
            .defaultPath = getDefaultPath(allocator) catch unreachable,
            .camera = rl.Camera2D{
                .target = .{ .x = 0, .y = 0 },
                .offset = .{ .x = 0, .y = 0 },
                .rotation = 0,
                .zoom = 1,
            },
            .textures = std.StringHashMap(rl.Texture2D).init(allocator),
            .fileData = undefined,
        };
    }

    pub fn deinit(self: *Context) void {
        self.textures.deinit();
        self.freeFileData();
        self.allocator.free(self.defaultPath);
        if (self.currentFileName) |fileName| {
            self.allocator.free(fileName);
        }
    }

    fn createFileData(self: *Context, size: Vector, tileSize: Vector) *FileData {
        const allocator = self.tilemapArena.allocator();
        const ptr = allocator.create(FileData) catch unreachable;
        ptr.* = FileData.init(allocator, size, tileSize);
        return ptr;
    }

    fn createDefaultFileData(self: *Context) *FileData {
        return self.createFileData(defaultSize, defaultTileSize);
    }

    fn freeFileData(self: *Context) void {
        _ = self.tilemapArena.reset(.free_all);
    }

    inline fn getDefaultPath(allocator: Allocator) ![:0]const u8 {
        var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const cwd = try std.fmt.allocPrintZ(allocator, "{s}", .{try std.fs.cwd().realpath(".", &buf)});
        return cwd;
    }

    /// fileName will be duplicated
    fn setCurrentFileName(self: *Context, fileName: ?[]const u8) !void {
        if (self.currentFileName) |cfn| {
            self.allocator.free(cfn);
            self.currentFileName = null;
        }

        if (fileName) |cfn| {
            self.currentFileName = try self.allocator.dupeZ(u8, cfn);
        }
    }

    const fileFilter = "tilemap.json";

    pub fn saveFile(self: *Context) !void {
        if (self.currentFileName) |fileName| {
            try self.saveFileTo(fileName);
            return;
        }

        const fileName = try nfd.saveFileDialog(fileFilter, self.defaultPath) orelse return;
        defer nfd.freePath(fileName);

        if (!std.mem.endsWith(u8, fileName, ".tilemap.json")) {
            self.currentFileName = try std.fmt.allocPrintZ(self.allocator, "{s}.tilemap.json", .{fileName});
        } else {
            self.currentFileName = try std.fmt.allocPrintZ(self.allocator, "{s}", .{fileName});
        }

        try self.saveFileTo(self.currentFileName.?);
    }

    fn saveFileTo(self: *Context, fileName: [:0]const u8) !void {
        std.log.debug("Saving to file: {s}", .{fileName});
        const file = try std.fs.createFileAbsolute(fileName, .{});
        defer file.close();
        const writer = file.writer();
        try self.fileData.serialize(writer);
    }

    pub fn openFile(self: *Context) !void {
        const maybeFileName = try nfd.openFileDialog(fileFilter, self.defaultPath);

        if (maybeFileName) |fileName| {
            defer nfd.freePath(fileName);
            try self.openFileEx(fileName);
        }
    }

    fn openFileEx(self: *Context, fileName: []const u8) !void {
        const file = std.fs.openFileAbsolute(fileName, .{}) catch |err| {
            switch (err) {
                error{FileNotFound}.FileNotFound => {
                    try self.newFile();
                    return;
                },
                else => return err,
            }
        };
        defer file.close();
        const fileReader = file.reader();
        var reader = std.json.reader(self.allocator, fileReader);
        defer reader.deinit();
        self.freeFileData();
        self.fileData = FileData.deserialize(self.tilemapArena.allocator(), &reader) catch |err| {
            std.log.err("Error reading file: {s} {}", .{ fileName, err });
            return self.newFile();
        };
        try self.setCurrentFileName(fileName);
    }

    pub fn newFile(self: *Context) !void {
        try self.setCurrentFileName(null);
        self.freeFileData();
        self.fileData = self.createDefaultFileData();
    }

    fn createEditorSession(self: *Context) EditorSession {
        return EditorSession{
            .currentFileName = self.currentFileName,
            .camera = self.camera,
            .windowSize = .{ rl.getScreenWidth(), rl.getScreenHeight() },
            .windowPos = brk: {
                const winPos = rl.getWindowPosition();
                break :brk @intFromFloat(@Vector(2, f32){ winPos.x, winPos.y });
            },
            .currentTool = self.currentTool,
        };
    }

    const sessionFileName = "session.json";

    pub fn storeSession(self: *Context) !void {
        const file = try std.fs.cwd().createFile(sessionFileName, .{});
        defer file.close();
        const writer = file.writer();
        try std.json.stringify(self.createEditorSession(), .{}, writer);
    }

    pub fn restoreSession(self: *Context) !void {
        const file = std.fs.cwd().openFile(sessionFileName, .{}) catch |err| {
            switch (err) {
                error{FileNotFound}.FileNotFound => {
                    try self.newFile();
                    return;
                },
                else => return err,
            }
        };
        defer file.close();
        const reader = file.reader();
        var jsonReader = std.json.reader(self.allocator, reader);
        defer jsonReader.deinit();
        const parsed = try std.json.parseFromTokenSource(EditorSession, self.allocator, &jsonReader, .{});
        defer parsed.deinit();

        if (parsed.value.currentFileName) |cfn| {
            try self.openFileEx(cfn);
        } else {
            try self.newFile();
        }
        // TODO: need to properly clone the tool
        //self.currentTool = parsed.value.currentTool;
        rl.setWindowSize(parsed.value.windowSize[0], parsed.value.windowSize[1]);
        rl.setWindowPosition(parsed.value.windowPos[0], parsed.value.windowPos[1]);

        self.camera = parsed.value.camera;
    }
};
