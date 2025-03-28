const std = @import("std");
const Allocator = std.mem.Allocator;
const Vector = @import("../vector.zig").Vector;
const Tilemap = @import("../tilemap.zig").Tilemap;
const TileSource = @import("../tilemap.zig").TileSource;
const SelectBox = @import("../select-box.zig").SelectGrid;
const rl = @import("raylib");
const Context = @import("../context.zig").Context;

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
        self.selectedSourceTiles.deinit(allocator);
    }

    pub fn onUse(
        self: *BrushTool,
        context: *Context,
        tilemap: *Tilemap,
        gridPosition: Vector,
    ) void {
        const layer = tilemap.getActiveLayer();
        const tile = layer.getTileByV(gridPosition);

        if (rl.isKeyDown(.key_left_control)) {
            return self.copySource(context, &tile.source);
        } else if (rl.isMouseButtonPressed(.mouse_button_left) and rl.isKeyDown(.key_left_shift) and self.lastPaintedCell != null) {
            return self.paintLine(context, self.lastPaintedCell.?, gridPosition);
        }

        self.paint(context, gridPosition);
    }

    fn copySource(self: *BrushTool, context: *Context, tileSource: *?TileSource) void {
        if (TileSource.eql(self.source, tileSource.*)) return;
        TileSource.set(&self.source, context.allocator, tileSource);
    }

    fn paint(self: *BrushTool, context: *Context, gridPosition: Vector) void {
        // Check if we need to paint
        if (self.currentPaintedCell) |cpc| if (@reduce(.And, cpc == gridPosition)) return;

        // Sets the brush source to one of the selected sources at random
        if (self.selectedSourceTiles.hasSelected()) {
            TileSource.set(&self.source, context.allocator, &self.getRandomFromSelected(context));
        }

        // Paint from the brush source
        const tilemap = &context.tilemapDocument.tilemap;
        const layer = tilemap.getActiveLayer();
        const tile = layer.getTileByV(gridPosition);
        TileSource.set(&tile.source, context.tilemapArena.allocator(), &self.source);

        self.currentPaintedCell = gridPosition;
        self.lastPaintedCell = gridPosition;
    }

    fn paintLine(self: *BrushTool, context: *Context, startPosition: Vector, endPosition: Vector) void {
        if (@reduce(.And, startPosition == endPosition)) {
            self.paint(context, startPosition);
            return;
        }

        const tilemap = &context.tilemapDocument.tilemap;
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

            self.paint(context, currentGridPosition);

            currentPosition += step;
        }

        const maxGridPosition: Vector = @intFromFloat(fEndPosition);
        self.paint(context, maxGridPosition);
    }

    pub fn onUseEnd(self: *BrushTool) void {
        self.currentPaintedCell = null;
    }

    pub fn onAlternateUse(self: *const BrushTool, context: *Context, tilemap: *Tilemap, gridPosition: Vector) void {
        _ = self; // autofix
        const layer = tilemap.getActiveLayer();
        const tile = layer.getTileByV(gridPosition);
        TileSource.set(&tile.source, context.tilemapArena.allocator(), &null);
    }

    fn getRandomFromSelected(self: *const BrushTool, context: *Context) TileSource {
        const selectedGridPositions = self.selectedSourceTiles.getSelected(context.allocator);
        defer context.allocator.free(selectedGridPositions);
        const i = std.crypto.random.uintLessThan(usize, selectedGridPositions.len);

        return TileSource{
            .tileset = self.tileset,
            .gridPosition = selectedGridPositions[i],
        };
    }
};
