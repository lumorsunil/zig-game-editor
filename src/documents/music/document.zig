const std = @import("std");
const Allocator = std.mem.Allocator;
const rl = @import("raylib");
const lib = @import("lib");
const DocumentGeneric = lib.documents.DocumentGeneric;
const PersistentData = @import("persistent-data.zig").MusicPersistentData;
const NonPersistentData = @import("non-persistent-data.zig").MusicNonPersistentData;
const UUID = lib.UUIDSerializable;

pub const MusicDocument = struct {
    document: DocumentType,

    pub const DocumentType = DocumentGeneric(
        PersistentData,
        NonPersistentData,
        .{},
    );

    pub fn init(allocator: Allocator) MusicDocument {
        return MusicDocument{
            .document = DocumentType.init(allocator),
        };
    }

    pub fn deinit(self: *MusicDocument, allocator: Allocator) void {
        self.document.deinit(allocator);
    }

    pub fn getId(self: MusicDocument) UUID {
        return self.document.persistentData.id;
    }

    pub fn getMusic(self: MusicDocument) ?*rl.Music {
        return if (self.document.nonPersistentData.music) |*music| music else null;
    }

    pub fn setMusicFilePath(
        self: *MusicDocument,
        musicFilePath: [:0]const u8,
    ) void {
        self.document.persistentData.musicFilePath.set(musicFilePath);
    }
};
