const std = @import("std");
const Allocator = std.mem.Allocator;
const lib = @import("root").lib;
const DocumentGeneric = lib.documents.DocumentGeneric;
const PersistentData = @import("persistent-data.zig").TexturePersistentData;
const NonPersistentData = @import("non-persistent-data.zig").TextureNonPersistentData;

pub const TextureDocument = struct {
    document: DocumentType,

    pub const DocumentType = DocumentGeneric(PersistentData, NonPersistentData);

    pub const fileFilter = "png";

    pub fn init(allocator: Allocator) TextureDocument {
        return TextureDocument{
            .document = DocumentType.init(allocator),
        };
    }

    pub fn deinit(self: *TextureDocument, allocator: Allocator) void {
        self.document.deinit(allocator);
    }
};
