const std = @import("std");
const Allocator = std.mem.Allocator;
const lib = @import("root").lib;
const DocumentGeneric = lib.documents.DocumentGeneric;
const PersistentData = @import("persistent-data.zig").PersistentData;
const NonPersistentData = @import("non-persistent-data.zig").NonPersistentData;

pub const AnimationDocument = struct {
    document: DocumentType,

    pub const DocumentType = DocumentGeneric(PersistentData, NonPersistentData);

    pub const fileFilter = "animations.json";

    pub fn init(allocator: Allocator) AnimationDocument {
        return AnimationDocument{
            .document = DocumentType.init(allocator),
        };
    }

    pub fn deinit(self: *AnimationDocument, allocator: Allocator) void {
        self.document.deinit(allocator);
    }
};
