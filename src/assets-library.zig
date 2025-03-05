const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const lib = @import("root").lib;
const Serializer = lib.Serializer;

pub const AssetsLibrary = struct {
    allocator: Allocator,
    sources: ArrayList(AssetsSource),

    pub fn init(allocator: Allocator) AssetsLibrary {
        return AssetsLibrary{
            .allocator = allocator,
            .sources = ArrayList(AssetsSource).initBuffer(&.{}),
        };
    }

    pub usingnamespace Serializer.MakeSerialize(
        @This(),
        AssetsLibrarySerialized,
        AssetsLibrarySerialized.init,
        AssetsLibrarySerialized.deserialize,
    );
};

const AssetsLibrarySerialized = struct {
    sources: []const AssetsSource,

    pub fn init(value: AssetsLibrary) AssetsLibrarySerialized {
        return AssetsLibrarySerialized{
            .sources = value.sources.items,
        };
    }

    pub fn deserialize(self: AssetsLibrarySerialized, allocator: Allocator) AssetsLibrary {
        return AssetsLibrary{
            .sources = ArrayList(AssetsSource).fromOwnedSlice(allocator, self.sources),
        };
    }
};

pub const AssetsSource = union(enum) {
    folder: []const u8,
};
