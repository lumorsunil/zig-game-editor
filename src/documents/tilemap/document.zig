const std = @import("std");
const Allocator = std.mem.Allocator;
const lib = @import("root").lib;
const Tilemap = lib.Tilemap;
const History = lib.History;
const Vector = lib.Vector;
const Action = lib.Action;
const Tool = lib.Tool;
const ImplTool = lib.ImplTool;
const DocumentGeneric = lib.documents.DocumentGeneric;
const TilemapData = @import("persistent-data.zig").TilemapData;
const TilemapLayer = lib.TilemapLayer;
const NonPersistentData = @import("non-persistent-data.zig").NonPersistentData;

pub const TilemapDocument = struct {
    document: DocumentType,

    pub const DocumentType = DocumentGeneric(TilemapData, NonPersistentData, .{});

    pub fn init(allocator: Allocator) TilemapDocument {
        return TilemapDocument{
            .document = DocumentType.init(allocator),
        };
    }

    pub fn deinit(self: *TilemapDocument, allocator: Allocator) void {
        self.document.deinit(allocator);
    }

    pub fn getTilemap(self: TilemapDocument) *Tilemap {
        return &self.document.persistentData.tilemap;
    }

    pub fn getHistory(self: TilemapDocument) *History {
        return &self.document.persistentData.history;
    }

    pub fn undo(self: *TilemapDocument, allocator: Allocator) void {
        if (!self.canUndo()) return;
        self.getHistory().undo(allocator, self.getTilemap());
        self.document.nonPersistentData.inputTilemapSize = self.getTilemap().grid.size;
    }

    pub fn redo(self: *TilemapDocument, allocator: Allocator) void {
        if (!self.canRedo()) return;
        self.getHistory().redo(allocator, self.getTilemap());
        self.document.nonPersistentData.inputTilemapSize = self.getTilemap().grid.size;
    }

    pub fn startAction(self: *TilemapDocument, action: Action) void {
        self.document.nonPersistentData.materializingAction = action;
    }

    pub fn endAction(self: *TilemapDocument, allocator: Allocator) void {
        self.getHistory().push(allocator, self.document.nonPersistentData.materializingAction.?);
        self.document.nonPersistentData.materializingAction = null;
        self.document.nonPersistentData.inputTilemapSize = self.getTilemap().grid.size;
    }

    pub fn canUndo(self: TilemapDocument) bool {
        return self.getHistory().canUndo();
    }

    pub fn canRedo(self: TilemapDocument) bool {
        return self.getHistory().canRedo();
    }

    pub fn startGenericAction(
        self: *TilemapDocument,
        comptime GenericActionType: type,
        allocator: Allocator,
    ) void {
        if (self.document.nonPersistentData.materializingAction) |_| return;

        const snapshotBefore = self.getTilemap().*;
        const fieldName = comptime brk: {
            for (std.meta.fields(Action)) |field| {
                if (field.type == GenericActionType) break :brk field.name;
            } else {
                @compileError("Type " ++ @typeName(GenericActionType) ++ " not a valid Action");
            }
        };

        const action = @unionInit(
            Action,
            fieldName,
            GenericActionType.init(snapshotBefore, allocator),
        );

        self.startAction(action);
    }

    pub fn endGenericAction(
        self: *TilemapDocument,
        comptime GenericActionType: type,
        allocator: Allocator,
    ) void {
        if (self.document.nonPersistentData.materializingAction) |*action| switch (action.*) {
            inline else => |*generic| if (GenericActionType == @TypeOf(generic.*)) {
                generic.materialize(allocator, self.getTilemap().*);
                self.endAction(allocator);
            },
        };
    }

    pub fn squashHistory(self: TilemapDocument, allocator: Allocator) void {
        self.getHistory().deinit(allocator);
        self.getHistory().* = History.init();
    }

    pub fn getCurrentTool(self: TilemapDocument) ?*Tool {
        return self.document.nonPersistentData.currentTool;
    }

    pub fn isCurrentTool(self: TilemapDocument, toolType: std.meta.Tag(ImplTool)) bool {
        const currentTool = self.getCurrentTool() orelse return false;
        return currentTool.impl == toolType;
    }

    pub fn getFocusOnActiveLayer(self: TilemapDocument) bool {
        return self.document.nonPersistentData.focusOnActiveLayer;
    }

    pub fn getFocusOnActiveLayerPtr(self: *TilemapDocument) *bool {
        return &self.document.nonPersistentData.focusOnActiveLayer;
    }

    pub fn getTileSize(self: TilemapDocument) Vector {
        return self.document.persistentData.tilemap.tileSize;
    }

    pub fn getGridSize(self: TilemapDocument) Vector {
        return self.document.persistentData.tilemap.grid.size;
    }

    pub fn isOutOfBounds(self: TilemapDocument, gridPosition: Vector) bool {
        return self.document.persistentData.tilemap.isOutOfBounds(gridPosition);
    }

    pub fn setToolByType(
        self: *TilemapDocument,
        comptime toolType: std.meta.FieldEnum(ImplTool),
    ) void {
        self.document.nonPersistentData.setTool(toolType);
    }

    pub fn setTool(
        self: *TilemapDocument,
        tool: *Tool,
    ) void {
        self.document.nonPersistentData.currentTool = tool;
    }

    pub fn getTools(self: *TilemapDocument) []Tool {
        return self.document.nonPersistentData.tools;
    }

    pub fn hasTool(self: TilemapDocument) bool {
        return self.getCurrentTool() != null;
    }

    pub fn addLayer(self: *TilemapDocument, allocator: Allocator, name: [:0]const u8) *TilemapLayer {
        return self.document.persistentData.tilemap.addLayer(allocator, name);
    }
};
