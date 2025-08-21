const std = @import("std");
const Allocator = std.mem.Allocator;
const rl = @import("raylib");
const lib = @import("lib");
const DocumentGeneric = lib.documents.DocumentGeneric;
const PersistentData = @import("persistent-data.zig").FontPersistentData;
const NonPersistentData = @import("non-persistent-data.zig").FontNonPersistentData;
const UUID = lib.UUIDSerializable;

pub const FontDocument = struct {
    document: DocumentType,

    pub const DocumentType = DocumentGeneric(
        PersistentData,
        NonPersistentData,
        .{},
    );

    pub fn init(allocator: Allocator) FontDocument {
        return FontDocument{
            .document = DocumentType.init(allocator),
        };
    }

    pub fn deinit(self: *FontDocument, allocator: Allocator) void {
        self.document.deinit(allocator);
    }

    pub fn getId(self: FontDocument) UUID {
        return self.document.persistentData.id;
    }

    pub fn getFont(self: FontDocument) ?*rl.Font {
        return if (self.document.nonPersistentData.font) |*font| font else null;
    }

    pub fn setFontFilePath(
        self: *FontDocument,
        fontFilePath: [:0]const u8,
    ) void {
        self.document.persistentData.fontFilePath.set(fontFilePath);
    }
};
