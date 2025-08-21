const std = @import("std");
const Allocator = std.mem.Allocator;
const rl = @import("raylib");
const lib = @import("lib");
const DocumentGeneric = lib.documents.DocumentGeneric;
const PersistentData = @import("persistent-data.zig").SoundPersistentData;
const NonPersistentData = @import("non-persistent-data.zig").SoundNonPersistentData;
const UUID = lib.UUIDSerializable;

pub const SoundDocument = struct {
    document: DocumentType,

    pub const DocumentType = DocumentGeneric(
        PersistentData,
        NonPersistentData,
        .{},
    );

    pub fn init(allocator: Allocator) SoundDocument {
        return SoundDocument{
            .document = DocumentType.init(allocator),
        };
    }

    pub fn deinit(self: *SoundDocument, allocator: Allocator) void {
        self.document.deinit(allocator);
    }

    pub fn getId(self: SoundDocument) UUID {
        return self.document.persistentData.id;
    }

    pub fn getSound(self: SoundDocument) ?*rl.Sound {
        return if (self.document.nonPersistentData.sound) |*sound| sound else null;
    }

    pub fn setSoundFilePath(
        self: *SoundDocument,
        soundFilePath: [:0]const u8,
    ) void {
        self.document.persistentData.soundFilePath.set(soundFilePath);
    }
};
