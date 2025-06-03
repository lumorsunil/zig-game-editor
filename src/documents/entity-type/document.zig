const std = @import("std");
const Allocator = std.mem.Allocator;
const lib = @import("root").lib;
const PersistentData = @import("persistent-data.zig").EntityType;
const NonPersistentData = @import("non-persistent-data.zig").EntityTypeNonPersistentData;
const DocumentGeneric = lib.documents.DocumentGeneric;
const UUID = lib.UUIDSerializable;
const StringZ = lib.StringZ;
const Vector = lib.Vector;

pub const EntityTypeDocument = struct {
    document: DocumentType,

    pub const DocumentType = DocumentGeneric(PersistentData, NonPersistentData, .{});

    pub fn init(allocator: Allocator) EntityTypeDocument {
        return EntityTypeDocument{
            .document = DocumentType.init(allocator),
        };
    }

    pub fn deinit(self: *EntityTypeDocument, allocator: Allocator) void {
        self.document.deinit(allocator);
    }

    pub fn getId(self: EntityTypeDocument) UUID {
        return self.document.persistentData.id;
    }

    pub fn getName(self: *EntityTypeDocument) *StringZ(64) {
        return &self.document.persistentData.name;
    }

    pub fn getCellSize(self: *EntityTypeDocument) *Vector {
        return &self.document.persistentData.icon.cellSize;
    }

    pub fn getGridPosition(self: *EntityTypeDocument) *Vector {
        return &self.document.persistentData.icon.gridPosition;
    }

    pub fn setGridPosition(self: *EntityTypeDocument, gridPosition: Vector) void {
        self.document.persistentData.icon.gridPosition = gridPosition;
    }

    pub fn getTextureFilePath(self: EntityTypeDocument) ?[:0]const u8 {
        return self.document.persistentData.icon.texturePath;
    }

    pub fn setTextureFilePath(self: *EntityTypeDocument, allocator: Allocator, texturePath: [:0]const u8) void {
        self.document.persistentData.icon.setTexturePath(allocator, texturePath);
    }
};
