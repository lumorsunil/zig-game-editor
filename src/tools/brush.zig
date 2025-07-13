const std = @import("std");
const Allocator = std.mem.Allocator;
const rl = @import("raylib");
const lib = @import("root").lib;
const Context = lib.Context;
const Vector = lib.Vector;
const Tilemap = lib.Tilemap;
const TileSource = lib.TileSource;
const TilemapDocument = lib.documents.TilemapDocument;
const SelectBox = @import("../select-box.zig").SelectGrid;
const UUID = lib.UUIDSerializable;

pub const BrushTool = struct {
    source: ?TileSource = null,
    isSelectingTileSource: bool = false,
    selectedSourceTiles: SelectBox = SelectBox.init(),
    tileset: ?UUID = null,
    currentPaintedCell: ?Vector = null,
    lastPaintedCell: ?Vector = null,

    pub fn init() BrushTool {
        return BrushTool{};
    }

    pub fn deinit(self: *BrushTool, allocator: Allocator) void {
        self.source = null;
        self.selectedSourceTiles.deinit(allocator);
    }

    pub fn onUse(
        self: *BrushTool,
        context: *Context,
        tilemapDocument: *TilemapDocument,
        gridPosition: Vector,
    ) void {
        const tilemap = tilemapDocument.getTilemap();
        const layer = tilemap.getActiveLayer();
        const tile = layer.getTileByV(gridPosition);

        if (rl.isKeyDown(.left_control)) {
            return self.copySource(&tile.source);
        } else if (rl.isMouseButtonPressed(.left) and rl.isKeyDown(.left_shift) and self.lastPaintedCell != null) {
            return self.paintLine(context, tilemapDocument, self.lastPaintedCell.?, gridPosition);
        }

        self.paint(context, tilemapDocument, gridPosition);
    }

    fn copySource(self: *BrushTool, tileSource: *?TileSource) void {
        if (TileSource.eql(self.source, tileSource.*)) return;
        TileSource.set(&self.source, tileSource);
    }

    fn paint(
        self: *BrushTool,
        context: *Context,
        tilemapDocument: *TilemapDocument,
        gridPosition: Vector,
    ) void {
        // Check if we need to paint
        if (self.currentPaintedCell) |cpc| if (@reduce(.And, cpc == gridPosition)) return;

        // Sets the brush source to one of the selected sources at random
        if (self.selectedSourceTiles.hasSelected()) {
            TileSource.set(&self.source, &self.getRandomFromSelected(context));
        }

        handleAutoExpand(context, tilemapDocument, gridPosition);

        // Paint from the brush source
        const tilemap = tilemapDocument.getTilemap();
        const layer = tilemap.getActiveLayer();
        const tile = layer.getTileByV(gridPosition);
        TileSource.set(&tile.source, &self.source);

        self.currentPaintedCell = gridPosition;
        self.lastPaintedCell = gridPosition;
    }

    fn handleAutoExpand(
        context: *Context,
        tilemapDocument: *TilemapDocument,
        gridPosition: Vector,
    ) void {
        const isAutoExpandEnabled = tilemapDocument.getAutoExpand().*;
        if (!isAutoExpandEnabled) return;
        if (!tilemapDocument.isOutOfBounds(gridPosition)) return;

        const tilemap = tilemapDocument.getTilemap();

        if (gridPosition[0] >= 0 and gridPosition[1] >= 0) {
            const newSize: Vector = @max(gridPosition, tilemapDocument.getGridSize());
            tilemap.setSize(context.allocator, newSize);
        }
    }

    fn paintLine(self: *BrushTool, context: *Context, tilemapDocument: *TilemapDocument, startPosition: Vector, endPosition: Vector) void {
        if (@reduce(.And, startPosition == endPosition)) {
            self.paint(context, tilemapDocument, startPosition);
            return;
        }

        const tilemap = tilemapDocument.getTilemap();
        const layer = tilemap.getActiveLayer();

        const fStartPosition: @Vector(2, f32) = @floatFromInt(startPosition);
        const fEndPosition: @Vector(2, f32) = @floatFromInt(endPosition);
        const relative = fEndPosition - fStartPosition;
        const length: @Vector(2, f32) = @splat(@sqrt(@reduce(.Add, relative * relative)));
        const step = relative / length;
        var currentPosition = fStartPosition;

        while (true) {
            const currentGridPosition: Vector = @intFromFloat(currentPosition);
            if (layer.grid.isOutOfBounds(currentGridPosition) or @reduce(.And, currentGridPosition == endPosition)) break;

            self.paint(context, tilemapDocument, currentGridPosition);

            currentPosition += step;
        }

        const maxGridPosition: Vector = @intFromFloat(fEndPosition);
        self.paint(context, tilemapDocument, maxGridPosition);
    }

    pub fn onUseEnd(self: *BrushTool) void {
        self.currentPaintedCell = null;
    }

    pub fn onAlternateUse(
        _: *const BrushTool,
        tilemap: *Tilemap,
        gridPosition: Vector,
    ) void {
        const layer = tilemap.getActiveLayer();
        const tile = layer.getTileByV(gridPosition);
        TileSource.set(&tile.source, &null);
    }

    fn getRandomFromSelected(self: *const BrushTool, context: *Context) TileSource {
        const tileset = self.tileset orelse unreachable;

        const selectedGridPositions = self.selectedSourceTiles.getSelected(context.allocator);
        defer context.allocator.free(selectedGridPositions);
        const i = std.crypto.random.uintLessThan(usize, selectedGridPositions.len);

        return TileSource.init(tileset, selectedGridPositions[i]);
    }
};
