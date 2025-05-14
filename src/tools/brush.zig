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

pub const BrushTool = struct {
    source: ?TileSource = null,
    isSelectingTileSource: bool = false,
    selectedSourceTiles: SelectBox = SelectBox.init(),
    tileset: []const u8 = "tileset-initial",
    currentPaintedCell: ?Vector = null,
    lastPaintedCell: ?Vector = null,

    pub fn init() BrushTool {
        return BrushTool{};
    }

    pub fn deinit(self: BrushTool, allocator: Allocator) void {
        if (self.source) |source| source.deinit(allocator);
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

        if (rl.isKeyDown(.key_left_control)) {
            return self.copySource(context, &tile.source);
        } else if (rl.isMouseButtonPressed(.mouse_button_left) and rl.isKeyDown(.key_left_shift) and self.lastPaintedCell != null) {
            return self.paintLine(context, tilemapDocument, self.lastPaintedCell.?, gridPosition);
        }

        self.paint(context, tilemapDocument, gridPosition);
    }

    fn copySource(self: *BrushTool, context: *Context, tileSource: *?TileSource) void {
        if (TileSource.eql(self.source, tileSource.*)) return;
        TileSource.set(&self.source, context.allocator, tileSource);
    }

    fn paint(self: *BrushTool, context: *Context, tilemapDocument: *TilemapDocument, gridPosition: Vector) void {
        // Check if we need to paint
        if (self.currentPaintedCell) |cpc| if (@reduce(.And, cpc == gridPosition)) return;

        // Sets the brush source to one of the selected sources at random
        if (self.selectedSourceTiles.hasSelected()) {
            TileSource.set(&self.source, context.allocator, &self.getRandomFromSelected(context));
        }

        // Paint from the brush source
        const tilemap = tilemapDocument.getTilemap();
        const layer = tilemap.getActiveLayer();
        const tile = layer.getTileByV(gridPosition);
        TileSource.set(&tile.source, context.allocator, &self.source);

        self.currentPaintedCell = gridPosition;
        self.lastPaintedCell = gridPosition;
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

    pub fn onAlternateUse(self: *const BrushTool, context: *Context, tilemap: *Tilemap, gridPosition: Vector) void {
        _ = self; // autofix
        const layer = tilemap.getActiveLayer();
        const tile = layer.getTileByV(gridPosition);
        TileSource.set(&tile.source, context.allocator, &null);
    }

    fn getRandomFromSelected(self: *const BrushTool, context: *Context) TileSource {
        const selectedGridPositions = self.selectedSourceTiles.getSelected(context.allocator);
        defer context.allocator.free(selectedGridPositions);
        const i = std.crypto.random.uintLessThan(usize, selectedGridPositions.len);

        return TileSource.init(context.allocator, self.tileset, selectedGridPositions[i]);
    }
};
