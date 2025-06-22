const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const rl = @import("raylib");
const lib = @import("root").lib;
const config = @import("root").config;
const Context = lib.Context;
const Vector = lib.Vector;
const drawTilemap = lib.drawTilemap;
const Scene = @import("persistent-data.zig").Scene;
const NonPersistentData = @import("non-persistent-data.zig").SceneNonPersistentData;
const DocumentGeneric = lib.documents.DocumentGeneric;
const SceneEntity = @import("persistent-data.zig").SceneEntity;
const SceneEntityType = @import("persistent-data.zig").SceneEntityType;
const UUID = lib.UUIDSerializable;

const tileSize = config.tileSize;

pub const SceneDocument = struct {
    document: DocumentType,

    pub const DocumentType = DocumentGeneric(Scene, NonPersistentData, .{});

    pub fn init(allocator: Allocator) SceneDocument {
        return SceneDocument{
            .document = DocumentType.init(allocator),
        };
    }

    pub fn deinit(self: *SceneDocument, allocator: Allocator) void {
        self.document.deinit(allocator);
    }

    pub fn getId(self: SceneDocument) UUID {
        return self.document.persistentData.id;
    }

    pub fn getTextureFromEntityType(
        self: *SceneDocument,
        _: *Context,
        entityType: std.meta.FieldEnum(SceneEntityType),
    ) !?*rl.Texture2D {
        return switch (entityType) {
            .klet => &self.document.nonPersistentData.kletTexture,
            .mossing => &self.document.nonPersistentData.mossingTexture,
            .stening => &self.document.nonPersistentData.steningTexture,
            .barlingSpawner => &self.document.nonPersistentData.barlingTexture,
            .player => &self.document.nonPersistentData.playerTexture,
            .npc => &self.document.nonPersistentData.npcTexture,
            // .custom => |c| {
            //     const document = try context.requestDocumentType(.entityType, c) orelse return null;
            //     const textureFilePath = document.getTextureFilePath() orelse return null;
            //     return try context.requestTexture(textureFilePath);
            // },
            .custom => return null,
            .exit, .entrance, .tilemap => unreachable,
        };
    }

    pub fn getSourceRectFromEntityType(
        _: *Context,
        entityType: std.meta.FieldEnum(SceneEntityType),
    ) !?rl.Rectangle {
        return switch (entityType) {
            .klet => rl.Rectangle.init(0, 0, 32, 32),
            .mossing => rl.Rectangle.init(0, 0, 32, 32),
            .stening => rl.Rectangle.init(0, 0, 32, 32),
            .barlingSpawner => rl.Rectangle.init(0, 0, 32, 32),
            .player => rl.Rectangle.init(1 * 16, 6 * 32, 16, 32),
            .npc => rl.Rectangle.init(0, 0, 32, 32),
            // .custom => |c| {
            //     const document = try context.requestDocumentType(.entityType, c) orelse return null;
            //     const gridPosition = document.getGridPosition().*;
            //     const cellSize = document.getCellSize().*;
            //     const rectPos: @Vector(2, f32) = @floatFromInt(gridPosition * cellSize);
            //     const rectSize: @Vector(2, f32) = @floatFromInt(cellSize);
            //     return rl.Rectangle.init(rectPos[0], rectPos[1], rectSize[0], rectSize[1]);
            // },
            .custom => return null,
            .exit, .entrance, .tilemap => unreachable,
        };
    }

    pub fn getSizeFromEntityType(
        context: *Context,
        entityType: SceneEntityType,
    ) !?rl.Vector2 {
        return switch (entityType) {
            .klet => rl.Vector2.init(32, 32),
            .mossing => rl.Vector2.init(32, 32),
            .stening => rl.Vector2.init(32, 32),
            .barlingSpawner => rl.Vector2.init(32, 32),
            .player => rl.Vector2.init(16, 32),
            .npc => rl.Vector2.init(32, 32),
            .exit => rl.Vector2.init(16, 16),
            .entrance => rl.Vector2.init(16, 16),
            .tilemap => unreachable,
            .custom => |c| {
                const document = try context.requestDocumentType(.entityType, c) orelse return null;
                const cellSize: @Vector(2, f32) = @floatFromInt(document.getCellSize().*);
                return rl.Vector2.init(cellSize[0], cellSize[1]);
            },
        };
    }

    pub fn drawEntity(self: *SceneDocument, context: *Context, entity: *SceneEntity) void {
        const scale: f32 = @floatFromInt(context.scale);
        switch (entity.type) {
            .custom => |c| {
                const entityType = context.requestDocumentType(.entityType, c) catch return orelse return;
                const textureId = entityType.getTextureId() orelse return;
                const texture = context.requestTextureById(textureId) catch return orelse return;

                const gridPosition = entityType.getGridPosition().*;
                const cellSize = entityType.getCellSize().*;
                const rectPos: @Vector(2, f32) = @floatFromInt(gridPosition * cellSize);
                const rectSize: @Vector(2, f32) = @floatFromInt(cellSize);
                const source = rl.Rectangle.init(
                    rectPos[0],
                    rectPos[1],
                    rectSize[0],
                    rectSize[1],
                );

                const position: @Vector(2, f32) = @floatFromInt(entity.position);
                const dest = rl.Rectangle.init(
                    position[0] * scale,
                    position[1] * scale,
                    source.width * scale,
                    source.height * scale,
                );
                const origin = rl.Vector2.init(source.width / 2 * scale, source.height / 2 * scale);

                rl.drawTexturePro(texture.*, source, dest, origin, 0, rl.Color.white);
            },
            .klet, .mossing, .stening, .barlingSpawner, .player, .npc => {
                const source = getSourceRectFromEntityType(context, entity.type) catch return orelse return;
                const texture = self.getTextureFromEntityType(context, entity.type) catch return orelse return;
                const position: @Vector(2, f32) = @floatFromInt(entity.position);
                const dest = rl.Rectangle.init(
                    position[0] * scale,
                    position[1] * scale,
                    source.width * scale,
                    source.height * scale,
                );
                const origin = rl.Vector2.init(source.width / 2 * scale, source.height / 2 * scale);

                rl.drawTexturePro(texture.*, source, dest, origin, 0, rl.Color.white);
            },
            .tilemap => |*tilemap| {
                const tilemapId = tilemap.tilemapId orelse return;
                const document = context.requestDocumentById(tilemapId) orelse {
                    tilemap.tilemapId = null;
                    return;
                };
                const tilemapDocument = &document.content.?.tilemap;
                const tilemapSizeHalf = tilemapDocument.getTilemap().grid.size * tileSize * context.scaleV / Vector{ 2, 2 };
                const position = entity.position - tilemapSizeHalf;
                drawTilemap(context, tilemapDocument, position, context.scale, true);
            },
            inline .exit, .entrance => |e| {
                const sizeInt = tileSize * context.scaleV;
                const scaledSizeInt = sizeInt * @as(Vector, @intFromFloat(e.scale.?));
                const size: @Vector(2, f32) = @floatFromInt(scaledSizeInt);
                const position: @Vector(2, f32) = @floatFromInt(entity.position * context.scaleV - scaledSizeInt / Vector{ 2, 2 });

                const rec = rl.Rectangle.init(
                    position[0],
                    position[1],
                    size[0],
                    size[1],
                );

                const color = if (entity.type == .exit) rl.Color.white.alpha(0.5) else rl.Color.yellow.alpha(0.5);

                rl.drawRectanglePro(rec, rl.Vector2.zero(), 0, color);
            },
        }
    }

    pub fn drawEntityEx(
        self: *SceneDocument,
        context: *Context,
        tag: std.meta.FieldEnum(SceneEntityType),
        position: Vector,
    ) void {
        const scale: f32 = @floatFromInt(context.scale);
        switch (tag) {
            .klet, .mossing, .stening, .barlingSpawner, .player, .npc => {
                const source = getSourceRectFromEntityType(context, tag) catch return orelse return;
                const texture = self.getTextureFromEntityType(context, tag) catch return orelse return;
                const fPosition: @Vector(2, f32) = @floatFromInt(position);
                const dest = rl.Rectangle.init(
                    fPosition[0] * scale,
                    fPosition[1] * scale,
                    source.width * scale,
                    source.height * scale,
                );
                const origin = rl.Vector2.init(source.width / 2 * scale, source.height / 2 * scale);

                rl.drawTexturePro(texture.*, source, dest, origin, 0, rl.Color.white);
            },
            .custom => {},
            inline .exit, .entrance => {
                const sizeInt = tileSize * context.scaleV;
                const size: @Vector(2, f32) = @floatFromInt(sizeInt);
                const fPosition: @Vector(2, f32) = @floatFromInt(position * context.scaleV - sizeInt / Vector{ 2, 2 });

                const rec = rl.Rectangle.init(
                    fPosition[0],
                    fPosition[1],
                    size[0],
                    size[1],
                );

                const color = if (tag == .exit) rl.Color.white.alpha(0.5) else rl.Color.yellow.alpha(0.5);

                rl.drawRectanglePro(rec, rl.Vector2.zero(), 0, color);
            },
            .tilemap => {},
        }
    }

    pub fn getEntities(self: *SceneDocument) *ArrayList(*SceneEntity) {
        return &self.document.persistentData.entities;
    }

    pub fn getSelectedEntities(self: SceneDocument) *ArrayList(*SceneEntity) {
        return &self.document.nonPersistentData.selectedEntities;
    }

    pub fn selectEntity(self: *SceneDocument, entity: *SceneEntity, allocator: Allocator) void {
        self.getSelectedEntities().clearRetainingCapacity();
        self.getSelectedEntities().append(allocator, entity) catch unreachable;
    }

    pub fn deleteEntity(self: *SceneDocument, allocator: Allocator, entity: *SceneEntity) void {
        const entitiesIndex = std.mem.indexOfScalar(*SceneEntity, self.document.persistentData.entities.items, entity) orelse unreachable;
        _ = self.document.persistentData.entities.swapRemove(entitiesIndex);
        entity.deinit(allocator);
        allocator.destroy(entity);
        const selectedEntitiesIndex = std.mem.indexOfScalar(*SceneEntity, self.getSelectedEntities().items, entity) orelse unreachable;
        _ = self.getSelectedEntities().swapRemove(selectedEntitiesIndex);
    }

    pub fn getTilemapFileName(self: *SceneDocument) ?[]const u8 {
        for (self.document.persistentData.entities.items) |entity| {
            switch (entity.type) {
                .tilemap => |tilemap| return tilemap.fileName,
                else => continue,
            }
        }

        return null;
    }

    pub fn getDragPayload(self: *SceneDocument) *?SceneEntityType {
        return &self.document.nonPersistentData.dragPayload;
    }

    pub fn getIsDragging(self: *SceneDocument) bool {
        return self.document.nonPersistentData.isDragging;
    }

    pub fn setIsDragging(self: *SceneDocument, isDragging: bool) void {
        self.document.nonPersistentData.isDragging = isDragging;
    }

    pub fn getDragStartPoint(self: *SceneDocument) ?Vector {
        return self.document.nonPersistentData.dragStartPoint;
    }

    pub fn setDragStartPoint(self: *SceneDocument, dragStartPoint: ?Vector) void {
        self.document.nonPersistentData.dragStartPoint = dragStartPoint;
    }
};
