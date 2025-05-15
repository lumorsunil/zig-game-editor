const std = @import("std");
const Allocator = std.mem.Allocator;
const rl = @import("raylib");
const lib = @import("root").lib;
const DocumentGeneric = lib.documents.DocumentGeneric;
const PersistentData = @import("persistent-data.zig").TexturePersistentData;
const NonPersistentData = @import("non-persistent-data.zig").TextureNonPersistentData;

pub const TextureDocument = struct {
    document: DocumentType,

    pub const DocumentType = DocumentGeneric(
        PersistentData,
        NonPersistentData,
        .{ .isDeserializable = false },
    );

    pub fn init(allocator: Allocator) TextureDocument {
        return TextureDocument{
            .document = DocumentType.init(allocator),
        };
    }

    pub fn deinit(self: *TextureDocument, allocator: Allocator) void {
        self.document.deinit(allocator);
    }

    pub fn getTexture(self: TextureDocument) ?rl.Texture2D {
        return self.document.nonPersistentData.texture;
    }
};
