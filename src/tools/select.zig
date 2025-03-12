const std = @import("std");
const Allocator = std.mem.Allocator;
const Vector = @import("../vector.zig").Vector;
const Tilemap = @import("../tilemap.zig").Tilemap;
const TilemapLayer = @import("../tilemap.zig").TilemapLayer;
const TileSource = @import("../tilemap.zig").TileSource;
const SelectBox = @import("../select-box.zig").SelectGrid;
const rl = @import("raylib");
const Context = @import("../context.zig").Context;
const Rectangle = @import("../rectangle.zig").Rectangle;
const drawLayer = @import("../draw-tilemap.zig").drawLayer;

pub const SelectTool = struct {
    selectedTiles: SelectBox = SelectBox.init(),
    newSelectionStart: ?Vector = null,
    newSelectionEnd: ?Vector = null,
    pendingSelection: ?SelectionType = null,
    floatingLayer: ?TilemapLayer = null,
    floatingSelectionDragPoint: ?Vector = null,

    pub const SelectionType = enum {
        select,
        add,
        subtract,
        floatingMove,
        mergeFloating,
    };

    pub fn init() SelectTool {
        return SelectTool{};
    }

    pub fn deinit(self: *SelectTool, allocator: Allocator) void {
        self.selectedTiles.deinit(allocator);
        if (self.floatingLayer) |*layer| layer.deinit(allocator);
    }

    pub fn draw(
        self: *SelectTool,
        context: *Context,
    ) void {
        if (self.getNewSelectionRectangle()) |rect| {
            drawSelectionBox(context, rect);
        }

        const tileSize = context.fileData.tilemap.tileSize;
        const scale = context.scaleV * tileSize;

        if (self.floatingLayer) |*layer| {
            drawLayer(context, layer, tileSize, self.selectedTiles.offset * scale, true);
        }

        var it = self.selectedTiles.lineIterator();
        while (it.next()) |line| {
            const coords = line.lineCoordinates();
            const imin = (coords.min + self.selectedTiles.offset) * scale;
            const imax = (coords.max + self.selectedTiles.offset) * scale;
            const fmin = rl.Vector2.init(@floatFromInt(imin[0]), @floatFromInt(imin[1]));
            const fmax = rl.Vector2.init(@floatFromInt(imax[0]), @floatFromInt(imax[1]));

            rl.drawLineEx(fmin, fmax, 1 / context.camera.zoom, rl.Color.white);
        }
    }

    fn drawSelectionBox(context: *Context, rectangle: Rectangle) void {
        const s = context.scaleV * context.fileData.tilemap.tileSize;
        const position = rectangle.min * s;
        const size = rectangle.size() * s;
        const rect = rl.Rectangle.init(
            @floatFromInt(position[0]),
            @floatFromInt(position[1]),
            @floatFromInt(size[0]),
            @floatFromInt(size[1]),
        );
        rl.drawRectangleLinesEx(rect, 1 / context.camera.zoom, rl.Color.white);
    }

    pub fn getNewSelectionRectangle(self: SelectTool) ?Rectangle {
        const start = self.newSelectionStart orelse return null;
        const end = self.newSelectionEnd orelse return null;

        return Rectangle{
            .min = @min(start, end),
            .max = @max(start, end),
        };
    }

    pub fn onUse(
        self: *SelectTool,
        context: *Context,
        tilemap: *Tilemap,
        gridPosition: Vector,
    ) void {
        if (self.pendingSelection == .mergeFloating) {
            return;
        }

        if (self.floatingLayer != null) {
            return self.handleFloatingTilemap(gridPosition);
        }

        if (self.pendingSelection == null) {
            // Start floating selection
            if (self.selectedTiles.hasSelected() and rl.isKeyDown(.key_left_control) and rl.isKeyDown(.key_left_alt)) {
                self.pendingSelection = .floatingMove;
                self.floatingLayer = self.initFloatingLayer(context, tilemap);
                self.floatingSelectionDragPoint = gridPosition;
                return;
            }

            self.newSelectionStart = gridPosition;
        }

        self.newSelectionEnd = gridPosition;

        if (rl.isKeyDown(.key_left_control)) {
            self.pendingSelection = .subtract;
        } else if (rl.isKeyDown(.key_left_shift)) {
            self.pendingSelection = .add;
        } else {
            self.pendingSelection = .select;
        }
    }

    pub fn onUseEnd(self: *SelectTool, context: *Context) void {
        const rect = self.getNewSelectionRectangle() orelse Rectangle.init();

        switch (self.pendingSelection.?) {
            .select => {
                self.selectedTiles.clear(context.allocator);
                self.selectedTiles.selectRegion(context.allocator, rect.min, rect.max);
            },
            .add => {
                self.selectedTiles.selectRegion(context.allocator, rect.min, rect.max);
            },
            .subtract => {
                self.selectedTiles.deselectRegion(context.allocator, rect.min, rect.max);
            },
            .floatingMove => {
                self.floatingSelectionDragPoint = null;
            },
            .mergeFloating => {
                self.mergeFloatingLayer(context);
                self.floatingLayer.?.deinit(context.allocator);
                self.floatingLayer = null;
                self.floatingSelectionDragPoint = null;
                self.selectedTiles.clear(context.allocator);
            },
        }

        self.newSelectionStart = null;
        self.newSelectionEnd = null;
        self.pendingSelection = null;
    }

    fn initFloatingLayer(self: *SelectTool, context: *Context, tilemap: *Tilemap) TilemapLayer {
        const start: @Vector(2, usize) = @intCast(self.selectedTiles.offset);
        const startX, const startY = start;
        const size: @Vector(2, usize) = @intCast(self.selectedTiles.size);
        const sizeX, const sizeY = size;

        const activeLayer = tilemap.getActiveLayer();
        var newLayer = TilemapLayer.init(context.allocator, "Floating Selection", self.selectedTiles.size);

        for (0..sizeX) |rx| {
            for (0..sizeY) |ry| {
                const x = startX + rx;
                const y = startY + ry;
                const rv: Vector = @intCast(@Vector(2, usize){ rx, ry });
                const v: Vector = @intCast(@Vector(2, usize){ x, y });

                if (self.selectedTiles.isSelected(v)) {
                    const tile = activeLayer.getTileByV(v);
                    const newTile = newLayer.getTileByV(rv);
                    TileSource.set(&newTile.source, context.allocator, &tile.source);
                    TileSource.clear(&tile.source, context.tilemapArena.allocator());
                }
            }
        }

        return newLayer;
    }

    fn handleFloatingTilemap(self: *SelectTool, gridPosition: Vector) void {
        if (self.pendingSelection == null and self.selectedTiles.isSelected(gridPosition)) {
            self.pendingSelection = .floatingMove;
            self.floatingSelectionDragPoint = gridPosition;
        } else if (self.pendingSelection == .floatingMove) {
            const delta = gridPosition - self.floatingSelectionDragPoint.?;
            self.floatingSelectionDragPoint = gridPosition;
            self.selectedTiles.offset += delta;
        } else {
            self.pendingSelection = .mergeFloating;
        }
    }

    fn mergeFloatingLayer(self: *SelectTool, context: *Context) void {
        const tilemap = &context.fileData.tilemap;

        const size: @Vector(2, usize) = @intCast(self.selectedTiles.size);
        const sizeX, const sizeY = size;

        const activeLayer = tilemap.getActiveLayer();
        const sourceLayer = &self.floatingLayer.?;

        for (0..sizeX) |rx| {
            for (0..sizeY) |ry| {
                const rv: Vector = @intCast(@Vector(2, usize){ rx, ry });
                const v = rv + self.selectedTiles.offset;
                if (tilemap.grid.isOutOfBounds(v)) continue;

                const sourceTile = sourceLayer.getTileByV(rv);

                if (self.selectedTiles.isSelected(v) and sourceTile.source != null) {
                    const destTile = activeLayer.getTileByV(v);
                    TileSource.set(&destTile.source, context.tilemapArena.allocator(), &sourceTile.source);
                }
            }
        }
    }
};
