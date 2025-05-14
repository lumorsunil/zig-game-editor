const std = @import("std");
const Allocator = std.mem.Allocator;
const lib = @import("root").lib;
const Tool = lib.Tool;
const BrushTool = lib.tools.BrushTool;
const SelectTool = lib.tools.SelectTool;
const ImplTool = lib.ImplTool;
const Action = lib.Action;
const Vector = lib.Vector;
const PersistentData = @import("persistent-data.zig").TilemapData;

var __tools = [_]Tool{
    Tool.init("brush", .{ .brush = BrushTool.init() }),
    Tool.init("select", .{ .select = SelectTool.init() }),
};

pub const NonPersistentData = struct {
    currentTool: ?*Tool = &__tools[0],
    tools: []Tool = &__tools,
    materializingAction: ?Action = null,
    focusOnActiveLayer: bool = false,
    inputTilemapSize: Vector = .{ 0, 0 },

    pub fn init(_: Allocator) NonPersistentData {
        return NonPersistentData{};
    }

    pub fn deinit(self: *NonPersistentData, allocator: Allocator) void {
        for (self.tools) |*tool| tool.deinit(allocator);
        self.currentTool = null;
    }

    pub fn load(self: *NonPersistentData, _: [:0]const u8, data: *PersistentData) void {
        // TODO: Move tileset texture loading logic to here
        self.inputTilemapSize = data.tilemap.grid.size;
    }

    pub fn getTool(
        self: *const NonPersistentData,
        comptime toolType: std.meta.FieldEnum(ImplTool),
    ) *Tool {
        for (self.tools) |*tool| {
            switch (tool.impl) {
                toolType => return tool,
                else => {},
            }
        }

        unreachable;
    }

    pub fn setTool(
        self: *NonPersistentData,
        comptime toolType: std.meta.FieldEnum(ImplTool),
    ) void {
        self.currentTool = self.getTool(toolType);
    }
};
