const std = @import("std");
const Allocator = std.mem.Allocator;
const rl = @import("raylib");
const Tool = @import("tool.zig").Tool;
const BrushTool = @import("tools/brush.zig").BrushTool;
const FileData = @import("file-data.zig").FileData;
const Vector = @import("vector.zig").Vector;
const VectorInt = @import("vector.zig").VectorInt;
const nfd = @import("nfd");

var __tools = [_]Tool{
    Tool.init("brush", .{ .brush = BrushTool.init() }),
};

pub const Context = struct {
    allocator: Allocator,

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

    pub fn init(allocator: Allocator) Context {
        return Context{
            .allocator = allocator,
            .defaultPath = getDefaultPath(allocator) catch unreachable,
            .camera = rl.Camera2D{
                .target = .{ .x = 0, .y = 0 },
                .offset = .{ .x = 0, .y = 0 },
                .rotation = 0,
                .zoom = 1,
            },
            .textures = std.StringHashMap(rl.Texture2D).init(allocator),
            .fileData = brk: {
                const ptr = allocator.create(FileData) catch unreachable;
                ptr.* = FileData.init(allocator, .{ 35, 17 }, .{ 16, 16 });
                break :brk ptr;
            },
        };
    }

    pub fn deinit(self: *Context) void {
        self.textures.deinit();
        self.fileData.deinit(self.allocator);
        self.allocator.destroy(self.fileData);
        self.allocator.free(self.defaultPath);
        if (self.currentFileName) |fileName| {
            self.allocator.free(fileName);
        }
    }

    inline fn getDefaultPath(allocator: Allocator) ![:0]const u8 {
        var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const cwd = try std.fmt.allocPrintZ(allocator, "{s}", .{try std.fs.cwd().realpath(".", &buf)});
        return cwd;
    }

    const fileFilter = "tilemap.json";

    pub fn saveFile(self: *Context) !void {
        if (self.currentFileName) |fileName| {
            try self.saveFileTo(fileName);
            return;
        }

        const fileName = try nfd.saveFileDialog(fileFilter, self.defaultPath) orelse return;
        defer nfd.freePath(fileName);

        if (!std.mem.eql(u8, std.fs.path.extension(fileName), ".json")) {
            self.currentFileName = try std.fmt.allocPrintZ(self.allocator, "{s}.json", .{fileName});
        } else {
            self.currentFileName = try std.fmt.allocPrintZ(self.allocator, "{s}", .{fileName});
        }

        try self.saveFileTo(self.currentFileName.?);
    }

    fn saveFileTo(self: *Context, fileName: [:0]const u8) !void {
        std.log.debug("Saving to file: {s}", .{fileName});
        const file = try std.fs.createFileAbsolute(fileName, .{});
        defer file.close();
        var writer = file.writer();
        try self.fileData.serialize(&writer);
    }

    pub fn openFile(self: *Context) !void {
        const maybeFileName = try nfd.openFileDialog(fileFilter, self.defaultPath);

        if (maybeFileName) |fileName| {
            defer nfd.freePath(fileName);
            const file = try std.fs.openFileAbsolute(fileName, .{});
            defer file.close();
            const fileReader = file.reader();
            var reader = std.json.reader(self.allocator, fileReader);
            defer reader.deinit();
            const fileData = try FileData.deserialize(self.allocator, &reader);

            self.fileData.deinit(self.allocator);
            self.allocator.destroy(self.fileData);
            self.fileData = fileData;
        }
    }
};
