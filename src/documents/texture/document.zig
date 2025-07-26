const std = @import("std");
const Allocator = std.mem.Allocator;
const rl = @import("raylib");
const lib = @import("lib");
const DocumentGeneric = lib.documents.DocumentGeneric;
const PersistentData = @import("persistent-data.zig").TexturePersistentData;
const NonPersistentData = @import("non-persistent-data.zig").TextureNonPersistentData;
const UUID = lib.UUIDSerializable;

pub const TextureDocument = struct {
    document: DocumentType,

    pub const DocumentType = DocumentGeneric(
        PersistentData,
        NonPersistentData,
        .{},
    );

    pub fn init(allocator: Allocator) TextureDocument {
        return TextureDocument{
            .document = DocumentType.init(allocator),
        };
    }

    pub fn deinit(self: *TextureDocument, allocator: Allocator) void {
        self.document.deinit(allocator);
    }

    pub fn getId(self: TextureDocument) UUID {
        return self.document.persistentData.id;
    }

    pub fn getTexture(self: TextureDocument) ?*rl.Texture2D {
        return if (self.document.nonPersistentData.texture) |*texture| texture else null;
    }

    pub fn setTextureFilePath(
        self: *TextureDocument,
        textureFilePath: [:0]const u8,
    ) void {
        self.document.persistentData.textureFilePath.set(textureFilePath);
    }
};
