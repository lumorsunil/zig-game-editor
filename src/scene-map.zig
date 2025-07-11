const std = @import("std");
const Allocator = std.mem.Allocator;
const rl = @import("raylib");
const lib = @import("root").lib;
const Context = lib.Context;
const UUID = lib.UUIDSerializable;
const IdArrayHashMap = lib.IdArrayHashMap;
const SceneDocument = lib.documents.SceneDocument;
const TilemapDocument = lib.documents.TilemapDocument;
const drawTilemap = lib.drawTilemap;
const Vector = lib.Vector;

pub const MapCell = struct {
    tilemapId: ?UUID,
    position: @Vector(2, f32),
    size: @Vector(2, f32),
};

pub const SceneMapError = error{ NoValidScenesFound, MissingDocument, MissingEntrance };

pub const SceneMap = struct {
    renderTexture: ?rl.RenderTexture2D = null,
    mapCells: IdArrayHashMap(MapCell) = .empty,

    pub fn init() SceneMap {
        return SceneMap{};
    }

    pub fn deinit(self: *SceneMap, allocator: Allocator) void {
        if (self.renderTexture) |renderTexture| rl.unloadRenderTexture(renderTexture);
        self.mapCells.deinit(allocator);
    }

    pub fn generate(self: *SceneMap, context: *Context) !void {
        const startingScene = try findStartingScene(context);
        try self.processScene(context, startingScene, .startingCell);
        try self.renderMap(context);
    }

    fn findStartingScene(context: *Context) !UUID {
        const sceneIds = context.getIdsByDocumentType(.scene);
        defer context.allocator.free(sceneIds);

        for (sceneIds) |id| {
            const sceneDocument = try context.requestDocumentTypeById(.scene, id) orelse continue;

            for (sceneDocument.getEntities().items) |entity| {
                if (entity.type == .exit) return id;
            }
        }

        return SceneMapError.NoValidScenesFound;
    }

    const LoadCellOptions = union(enum) {
        startingCell,
        relativeCell: struct {
            entranceKey: [:0]const u8,
            exitPosition: @Vector(2, f32),
        },
    };

    fn loadCell(context: *Context, sceneId: UUID, options: LoadCellOptions) !MapCell {
        const sceneDocument = try context.requestDocumentTypeById(.scene, sceneId) orelse return SceneMapError.MissingDocument;
        const tilemapId = sceneDocument.getTilemapId() orelse unreachable;
        const tilemapDocument = if (tilemapId.*) |id| try context.requestDocumentTypeById(.tilemap, id) else null;
        const tilemapSize: @Vector(2, f32) = if (tilemapDocument) |td| @floatFromInt(
            td.getGridSize() * td.getTileSize(),
        ) else .{ 0, 0 };

        return switch (options) {
            .startingCell => MapCell{
                .tilemapId = tilemapId.*,
                .position = .{ 0, 0 },
                .size = tilemapSize,
            },
            .relativeCell => |relativeCell| MapCell{
                .tilemapId = tilemapId.*,
                .position = relativeCell.exitPosition - try getEntrancePosition(
                    sceneDocument,
                    relativeCell.entranceKey,
                ),
                .size = tilemapSize,
            },
        };
    }

    fn getEntrancePosition(
        sceneDocument: *SceneDocument,
        entranceKey: [:0]const u8,
    ) !@Vector(2, f32) {
        const entity = sceneDocument.getEntranceByKey(entranceKey) orelse return SceneMapError.MissingEntrance;
        return @floatFromInt(entity.position);
    }

    /// If null is passed as previousCell, this is processed as the starting cell
    fn processScene(
        self: *SceneMap,
        context: *Context,
        sceneToBeProcessed: UUID,
        loadCellOptions: LoadCellOptions,
    ) !void {
        if (self.mapCells.map.contains(sceneToBeProcessed)) return;
        const cell = loadCell(context, sceneToBeProcessed, loadCellOptions) catch |err| {
            std.log.warn("Could not load cell {}: {}", .{ sceneToBeProcessed, err });
            return;
        };
        try self.mapCells.map.put(context.allocator, sceneToBeProcessed, cell);

        const sceneDocument = try context.requestDocumentTypeById(
            .scene,
            sceneToBeProcessed,
        ) orelse return SceneMapError.MissingDocument;

        for (sceneDocument.getEntities().items) |entity| {
            if (entity.type == .exit) {
                const exitSceneId = entity.type.exit.sceneId orelse continue;
                try self.processScene(context, exitSceneId, .{ .relativeCell = .{
                    .entranceKey = entity.type.exit.entranceKey.slice(),
                    .exitPosition = cell.position + @as(@Vector(2, f32), @floatFromInt(entity.position)),
                } });
            }
        }
    }

    fn renderMap(self: *SceneMap, context: *Context) !void {
        if (self.renderTexture) |renderTexture| {
            rl.unloadRenderTexture(renderTexture);
            self.renderTexture = null;
        }

        const min, const size = self.calculateMapMinAndSize();
        self.renderTexture = try rl.loadRenderTexture(size[0], size[1]);

        rl.beginTextureMode(self.renderTexture.?);
        defer rl.endTextureMode();

        for (self.mapCells.map.values()) |cell| {
            const tilemapId = cell.tilemapId orelse continue;
            const tilemapDocument = try context.requestDocumentTypeById(.tilemap, tilemapId) orelse continue;
            const cellPosition: Vector = @intFromFloat(cell.position - cell.size / @Vector(2, f32){ 2, 2 });
            drawTilemap(context, tilemapDocument, cellPosition - min, 1, true);
        }
    }

    pub fn calculateMapMinAndSize(self: SceneMap) struct { Vector, Vector } {
        var min: Vector = @splat(std.math.maxInt(i32));
        var max: Vector = @splat(std.math.minInt(i32));

        for (self.mapCells.map.values()) |cell| {
            const cellMin: Vector = @intFromFloat(cell.position - cell.size / @Vector(2, f32){ 2, 2 });
            var cellMax: Vector = @intFromFloat(cell.size);
            cellMax += cellMin;

            min = @min(min, cellMin);
            max = @max(max, cellMax);
        }

        return .{ min, max - min };
    }
};
