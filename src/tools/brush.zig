const std = @import("std");
const Allocator = std.mem.Allocator;
const rl = @import("raylib");
const lib = @import("root").lib;
const Context = lib.Context;
const Vector = lib.Vector;
const Tilemap = lib.Tilemap;
const TileSource = lib.TileSource;
const TilemapDocument = lib.documents.TilemapDocument;
const TilemapLayer = lib.TilemapLayer;
const SelectGrid = lib.SelectGrid;
const UUID = lib.UUIDSerializable;
const SceneDocument = lib.documents.SceneDocument;

pub const BrushTool = struct {
    source: ?TileSource = null,
    isSelectingTileSource: bool = false,
    selectedSourceTiles: SelectGrid = SelectGrid.init(),
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

        if (!tilemapDocument.isOutOfBounds(gridPosition) and rl.isKeyDown(.left_control)) {
            const tile = layer.getTileByV(gridPosition);
            return self.copySource(&tile.source);
        } else if (rl.isMouseButtonPressed(.left) and rl.isKeyDown(.left_shift) and self.lastPaintedCell != null) {
            return self.paintLine(context, tilemapDocument, self.lastPaintedCell.?, gridPosition);
        }

        _ = self.paint(context, tilemapDocument, gridPosition);
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
    ) Vector {
        // Check if we need to paint
        if (self.currentPaintedCell) |cpc| if (@reduce(.And, cpc == gridPosition)) return Vector{ 0, 0 };

        // Sets the brush source to one of the selected sources at random
        if (self.selectedSourceTiles.hasSelected()) {
            TileSource.set(&self.source, &self.getRandomFromSelected(context));
        }

        const gridPositionMove = handleAutoExpand(context, tilemapDocument, gridPosition);
        const gridPositionAdjusted = gridPositionMove + gridPosition;

        // Paint from the brush source
        const tilemap = tilemapDocument.getTilemap();
        const layer = tilemap.getActiveLayer();
        const tile = layer.getTileByV(gridPositionAdjusted);
        TileSource.set(&tile.source, &self.source);

        self.currentPaintedCell = gridPositionAdjusted;
        self.lastPaintedCell = gridPositionAdjusted;

        return gridPositionMove;
    }

    fn handleAutoExpand(
        context: *Context,
        tilemapDocument: *TilemapDocument,
        gridPosition: Vector,
    ) Vector {
        const isAutoExpandEnabled = tilemapDocument.getAutoExpand().*;
        if (!isAutoExpandEnabled) return Vector{ 0, 0 };
        if (!tilemapDocument.isOutOfBounds(gridPosition)) return Vector{ 0, 0 };

        const tilemap = tilemapDocument.getTilemap();

        if (gridPosition[0] >= 0 and gridPosition[1] >= 0) {
            const newSize: Vector = @max(
                gridPosition + Vector{ 1, 1 },
                tilemapDocument.getGridSize(),
            );
            if (@reduce(.And, newSize == tilemapDocument.getGridSize())) {
                return Vector{ 0, 0 };
            }
            const expansionV = newSize - tilemapDocument.getGridSize();
            tilemap.setSize(context.allocator, newSize);
            updateSceneEntitiesPosition(context, tilemapDocument, expansionV);
            return Vector{ 0, 0 };
        }

        // If gridPosition is negative, resize to new size and move tiles accordingly

        const oldMax = tilemapDocument.getGridSize() - Vector{ 1, 1 };

        const newMin = @min(gridPosition, Vector{ 0, 0 });
        const newMax = @max(gridPosition, oldMax);
        const newSize = newMax - newMin + Vector{ 1, 1 };
        const expansionV = (newSize - tilemapDocument.getGridSize()) * std.math.sign(gridPosition);

        const copiedLayers = context.allocator.alloc(TilemapLayer, tilemap.layers.items.len) catch unreachable;
        defer context.allocator.free(copiedLayers);

        var selectGrid = SelectGrid.init();
        defer selectGrid.deinit(context.allocator);
        selectGrid.selectRegion(context.allocator, .{ 0, 0 }, oldMax);

        for (tilemap.layers.items, 0..) |layer, i| {
            copiedLayers[i] = layer.cloneTiles(context.allocator, selectGrid, true);
        }

        tilemap.setSize(context.allocator, newSize);
        updateSceneEntitiesPosition(context, tilemapDocument, expansionV);

        const moveV: Vector = @intCast(@abs(@min(gridPosition, Vector{ 0, 0 })));
        selectGrid.offset = moveV;

        for (tilemap.layers.items, 0..) |layer, i| {
            layer.pasteLayer(&copiedLayers[i], selectGrid);
            copiedLayers[i].deinit(context.allocator);
        }

        const tileSize = tilemapDocument.getTileSize();
        const scale = context.scale;

        context.camera.target.x += @floatFromInt(moveV[0] * tileSize[0] * scale);
        context.camera.target.y += @floatFromInt(moveV[1] * tileSize[1] * scale);

        return moveV;
    }

    fn updateSceneEntitiesPosition(
        context: *Context,
        tilemapDocument: *TilemapDocument,
        expansionV: Vector,
    ) void {
        const tileSize = tilemapDocument.getTileSize();
        if (context.getSceneReferencingTilemap(tilemapDocument.getId())) |sceneId| {
            const sceneDocument: *SceneDocument = (context.requestDocumentTypeById(.scene, sceneId) catch return) orelse return;

            const entityMove: Vector = (expansionV * tileSize) / -Vector{ 2, 2 };

            for (sceneDocument.getEntities().items) |entity| {
                switch (entity.type) {
                    .tilemap => continue,
                    else => {
                        entity.position += entityMove;
                    },
                }
            }
        }
    }

    fn paintLine(self: *BrushTool, context: *Context, tilemapDocument: *TilemapDocument, startPosition: Vector, endPosition: Vector) void {
        if (@reduce(.And, startPosition == endPosition)) {
            _ = self.paint(context, tilemapDocument, startPosition);
            return;
        }

        var startPositionMut = startPosition;
        var endPositionMut = endPosition;

        const tilemap = tilemapDocument.getTilemap();
        const layer = tilemap.getActiveLayer();

        const startPositionMove = handleAutoExpand(context, tilemapDocument, startPositionMut);
        startPositionMut += startPositionMove;
        endPositionMut += startPositionMove;
        const endPositionMove = handleAutoExpand(context, tilemapDocument, endPositionMut);
        startPositionMut += endPositionMove;
        endPositionMut += endPositionMove;

        const fStartPosition: @Vector(2, f32) = @floatFromInt(startPositionMut);
        const fEndPosition: @Vector(2, f32) = @floatFromInt(endPositionMut);
        const relative = fEndPosition - fStartPosition;
        const length: @Vector(2, f32) = @splat(@sqrt(@reduce(.Add, relative * relative)));
        const step = relative / length;
        var currentPosition = fStartPosition;

        while (true) {
            const currentGridPosition: Vector = @intFromFloat(currentPosition);
            if (layer.grid.isOutOfBounds(currentGridPosition) or @reduce(.And, currentGridPosition == endPositionMut)) break;

            _ = self.paint(context, tilemapDocument, currentGridPosition);

            currentPosition += step;
        }

        const maxGridPosition: Vector = @intFromFloat(fEndPosition);
        _ = self.paint(context, tilemapDocument, maxGridPosition);
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
