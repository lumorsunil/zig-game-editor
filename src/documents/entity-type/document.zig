const std = @import("std");
const Allocator = std.mem.Allocator;
const lib = @import("lib");
const PersistentData = @import("persistent-data.zig").EntityType;
const NonPersistentData = @import("non-persistent-data.zig").EntityTypeNonPersistentData;
const DocumentGeneric = lib.documents.DocumentGeneric;
const UUID = lib.UUIDSerializable;
const StringZ = lib.StringZ;
const Vector = lib.Vector;
const PropertyObject = lib.properties.PropertyObject;

pub const EntityTypeDocument = struct {
    document: DocumentType,

    pub const DocumentType = DocumentGeneric(
        PersistentData,
        NonPersistentData,
        .{},
    );

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

    pub fn getName(self: *EntityTypeDocument) *StringZ {
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

    pub fn getTextureId(self: EntityTypeDocument) *?UUID {
        return &self.document.persistentData.icon.textureId;
    }

    pub fn addNewProperty(self: *EntityTypeDocument, allocator: Allocator) void {
        self.document.persistentData.properties.addNewProperty(allocator);
    }

    pub fn deleteProperty(
        self: *EntityTypeDocument,
        allocator: Allocator,
        key: PropertyObject.K,
    ) void {
        self.document.persistentData.properties.deleteProperty(allocator, key);
    }

    pub fn getProperties(self: *EntityTypeDocument) *PropertyObject {
        return &self.document.persistentData.properties;
    }
};
