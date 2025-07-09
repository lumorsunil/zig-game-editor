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

    pub const setEntityReferenceWindowHeight = NonPersistentData.setEntityReferenceWindowHeight;
    pub const setEntityReferenceWindowWidth = NonPersistentData.setEntityReferenceWindowHeight;

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

    pub fn getSizeFromEntityType(
        context: *Context,
        entityType: SceneEntityType,
    ) !?rl.Vector2 {
        return switch (entityType) {
            .exit => rl.Vector2.init(16, 16),
            .entrance => rl.Vector2.init(16, 16),
            .tilemap => unreachable,
            .custom => |c| {
                const document = try context.requestDocumentTypeById(.entityType, c.entityTypeId) orelse return null;
                const cellSize: @Vector(2, f32) = @floatFromInt(document.getCellSize().*);
                return rl.Vector2.init(cellSize[0], cellSize[1]);
            },
        };
    }

    pub fn drawEntity(_: *SceneDocument, context: *Context, entity: *SceneEntity) void {
        const scale: f32 = @floatFromInt(context.scale);
        switch (entity.type) {
            .custom => |c| {
                const entityType = context.requestDocumentTypeById(.entityType, c.entityTypeId) catch return orelse {
                    std.log.debug("entity {} not found while drawing", .{c});
                    return;
                };
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
        _: *SceneDocument,
        context: *Context,
        tag: std.meta.FieldEnum(SceneEntityType),
        position: Vector,
    ) void {
        switch (tag) {
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

    pub fn getTilemapId(self: *SceneDocument) ?UUID {
        for (self.document.persistentData.entities.items) |entity| {
            switch (entity.type) {
                .tilemap => |tilemap| return tilemap.tilemapId,
                else => continue,
            }
        }

        return null;
    }

    pub fn setTilemapId(self: *SceneDocument, id: UUID) void {
        for (self.getEntities().items) |entity| {
            if (entity.type == .tilemap) {
                entity.type.tilemap.tilemapId = id;
                break;
            }
        }
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

    pub fn openSetEntityWindow(
        self: *SceneDocument,
        targetSceneId: *?UUID,
        targetEntityId: *?UUID,
    ) void {
        self.document.nonPersistentData.setEntityWindow.isOpen = true;
        self.document.nonPersistentData.setEntityWindow.sceneTarget = targetSceneId;
        self.document.nonPersistentData.setEntityWindow.entityTarget = targetEntityId;
    }

    pub fn closeSetEntityWindow(self: *SceneDocument) void {
        self.document.nonPersistentData.setEntityWindow.isOpen = false;
    }

    pub fn isSetEntityWindowOpen(self: *SceneDocument) bool {
        return self.document.nonPersistentData.setEntityWindow.isOpen;
    }

    pub fn getSetEntityReferenceScene(self: *SceneDocument) ?UUID {
        return self.document.nonPersistentData.setEntityWindow.selectedScene;
    }

    pub fn getSetEntityReferenceEntity(self: *SceneDocument) ?UUID {
        return self.document.nonPersistentData.setEntityWindow.selectedEntity;
    }

    pub fn setSetEntityReferenceScene(self: *SceneDocument, sceneId: ?UUID) void {
        self.document.nonPersistentData.setEntityWindow.selectedScene = sceneId;
    }

    pub fn setSetEntityReferenceEntity(self: *SceneDocument, entityId: ?UUID) void {
        self.document.nonPersistentData.setEntityWindow.selectedEntity = entityId;
    }

    pub fn getSetEntityWindowRenderTexture(self: *SceneDocument) rl.RenderTexture {
        return self.document.nonPersistentData.setEntityWindow.renderTexture;
    }

    pub fn getSetEntityWindowCamera(self: *SceneDocument) *rl.Camera2D {
        return &self.document.nonPersistentData.setEntityWindow.camera;
    }

    pub fn commitSetEntityTarget(self: *SceneDocument) void {
        const sceneTarget = self.document.nonPersistentData.setEntityWindow.sceneTarget orelse return;
        const entityTarget = self.document.nonPersistentData.setEntityWindow.entityTarget orelse return;
        sceneTarget.* = self.getSetEntityReferenceScene() orelse unreachable;
        entityTarget.* = self.getSetEntityReferenceEntity() orelse unreachable;
    }

    pub fn clearSetEntityTarget(self: *SceneDocument) void {
        self.document.nonPersistentData.setEntityWindow.sceneTarget = null;
        self.document.nonPersistentData.setEntityWindow.entityTarget = null;
    }

    pub fn getEntityByInstanceId(self: *SceneDocument, id: UUID) ?*SceneEntity {
        for (self.getEntities().items) |entity| {
            if (entity.id.uuid == id.uuid) {
                return entity;
            }
        }

        return null;
    }
};
