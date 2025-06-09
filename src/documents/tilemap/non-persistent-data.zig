const std = @import("std");
const Allocator = std.mem.Allocator;
const lib = @import("root").lib;
const Context = lib.Context;
const Tool = lib.Tool;
const BrushTool = lib.tools.BrushTool;
const SelectTool = lib.tools.SelectTool;
const ImplTool = lib.ImplTool;
const Action = lib.Action;
const Vector = lib.Vector;
const PersistentData = @import("persistent-data.zig").TilemapData;

pub const NonPersistentData = struct {
    currentTool: ?*Tool = null,
    materializingAction: ?Action = null,
    focusOnActiveLayer: bool = false,
    inputTilemapSize: Vector = .{ 0, 0 },

    pub fn init(_: Allocator) NonPersistentData {
        return NonPersistentData{};
    }

    pub fn deinit(self: *NonPersistentData, _: Allocator) void {
        self.currentTool = null;
    }

    pub fn load(self: *NonPersistentData, _: [:0]const u8, data: *PersistentData) void {
        // TODO: Move tileset texture loading logic to here
        self.inputTilemapSize = data.tilemap.grid.size;
    }

    pub fn getTool(
        _: *const NonPersistentData,
        comptime toolType: std.meta.FieldEnum(ImplTool),
        context: *Context,
    ) *Tool {
        for (&context.tools) |*tool| {
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
        context: *Context,
    ) void {
        self.currentTool = self.getTool(toolType, context);
    }
};
