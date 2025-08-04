const std = @import("std");
const Allocator = std.mem.Allocator;
const rl = @import("raylib");
const lib = @import("lib");
const Context = lib.Context;
const Vector = lib.Vector;
const TilemapDocument = lib.documents.TilemapDocument;
const Tilemap = lib.Tilemap;
const TilemapLayer = lib.TilemapLayer;
const TileSource = lib.TileSource;
const drawLayer = lib.drawLayer;
const SelectGrid = lib.SelectGrid;
const Rectangle = @import("../rectangle.zig").Rectangle;

pub const SelectTool = struct {
    selectedTiles: SelectGrid = SelectGrid.init(),
    newSelectionStart: ?Vector = null,
    newSelectionEnd: ?Vector = null,
    pendingSelection: ?SelectionType = null,
    floatingLayer: ?TilemapLayer = null,
    floatingSelectionDragPoint: ?Vector = null,
    copiedLayer: ?TilemapLayer = null,
    copiedSelectedTiles: SelectGrid = SelectGrid.init(),

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
        self.copiedSelectedTiles.deinit(allocator);
        if (self.copiedLayer) |*copiedLayer| copiedLayer.deinit(allocator);
    }

    pub fn draw(
        self: *SelectTool,
        context: *Context,
        tilemapDocument: *TilemapDocument,
    ) void {
        if (self.getNewSelectionRectangle()) |rect| {
            drawSelectionBox(context, tilemapDocument, rect);
        }

        const tileSize = tilemapDocument.getTileSize();
        const scale = context.scaleV * tileSize;

        if (self.floatingLayer) |*layer| {
            drawLayer(context, tilemapDocument, layer, tileSize, self.selectedTiles.offset * scale, context.scale, true);
        }

        var it = self.selectedTiles.lineIterator();
        while (it.next()) |line| {
            const coords = line.lineCoordinates();
            const imin = (coords.min + self.selectedTiles.offset) * scale;
            const imax = (coords.max + self.selectedTiles.offset) * scale;
            const fmin = rl.Vector2.init(@floatFromInt(imin[0]), @floatFromInt(imin[1]));
            const fmax = rl.Vector2.init(@floatFromInt(imax[0]), @floatFromInt(imax[1]));

            const editor = context.getCurrentEditor().?;
            rl.drawLineEx(fmin, fmax, 1 / editor.camera.zoom, rl.Color.white);
        }
    }

    fn drawSelectionBox(context: *Context, document: *TilemapDocument, rectangle: Rectangle) void {
        const s = context.scaleV * document.getTileSize();
        const position = rectangle.min * s;
        const size = rectangle.size() * s;
        const rect = rl.Rectangle.init(
            @floatFromInt(position[0]),
            @floatFromInt(position[1]),
            @floatFromInt(size[0]),
            @floatFromInt(size[1]),
        );
        const editor = context.getCurrentEditor().?;
        rl.drawRectangleLinesEx(rect, 1 / editor.camera.zoom, rl.Color.white);
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
            if (self.selectedTiles.hasSelected() and rl.isKeyDown(.left_control) and rl.isKeyDown(.left_alt)) {
                self.pendingSelection = .floatingMove;
                self.floatingLayer = self.cloneSelectedTiles(context, tilemap.getActiveLayer(), true);
                self.floatingSelectionDragPoint = gridPosition;
                return;
            }

            self.newSelectionStart = gridPosition;
        }

        self.newSelectionEnd = gridPosition;

        if (rl.isKeyDown(.left_control)) {
            self.pendingSelection = .subtract;
        } else if (rl.isKeyDown(.left_shift)) {
            self.pendingSelection = .add;
        } else {
            self.pendingSelection = .select;
        }
    }

    pub fn onUseEnd(self: *SelectTool, context: *Context, tilemapDocument: *TilemapDocument) void {
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
                self.mergeFloatingLayer(tilemapDocument);
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

    fn cloneSelectedTiles(
        self: *SelectTool,
        context: *Context,
        sourceLayer: *TilemapLayer,
        clearSource: bool,
    ) TilemapLayer {
        return sourceLayer.cloneTiles(context.allocator, self.selectedTiles, clearSource);
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

    fn mergeFloatingLayer(self: *SelectTool, tilemapDocument: *TilemapDocument) void {
        const tilemap = tilemapDocument.getTilemap();
        const activeLayer = tilemap.getActiveLayer();
        activeLayer.pasteLayer(&self.floatingLayer.?, self.selectedTiles);
    }

    pub fn copy(self: *SelectTool, context: *Context, tilemapDocument: *TilemapDocument) void {
        if (self.copiedLayer) |*layer| layer.deinit(context.allocator);
        const tilemap = tilemapDocument.getTilemap();
        self.copiedLayer = self.cloneSelectedTiles(context, tilemap.getActiveLayer(), false);
        self.copiedSelectedTiles.clear(context.allocator);
        self.copiedSelectedTiles = self.selectedTiles.clone(context.allocator);
    }

    pub fn paste(self: *SelectTool, context: *Context) void {
        const copiedLayer = self.copiedLayer orelse return;
        self.pendingSelection = .floatingMove;
        self.floatingLayer = copiedLayer.clone(context.allocator);
        self.selectedTiles.clear(context.allocator);
        self.selectedTiles = self.copiedSelectedTiles.clone(context.allocator);
    }

    pub fn delete(self: *SelectTool, context: *Context, tilemapDocument: *TilemapDocument) void {
        const selectedTiles = self.selectedTiles.getSelected(context.allocator);
        defer context.allocator.free(selectedTiles);

        const sourceLayer = tilemapDocument.getTilemap().getActiveLayer();

        for (selectedTiles) |v| {
            const tile = sourceLayer.getTileByV(v);
            TileSource.clear(&tile.source);
        }
    }
};
