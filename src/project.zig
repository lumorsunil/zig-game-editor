const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const Serializer = @import("serializer.zig").Serializer;

const AssetsLibrary = @import("assets-library.zig").AssetsLibrary;

pub const Project = struct {
    assetsLibrary: AssetsLibrary,

    // openedDocuments: ArrayList(Document),

    pub fn init(allocator: Allocator) Project {
        return Project{
            .assetsLibrary = AssetsLibrary.init(allocator),
        };
    }

    pub const Serialized = ProjectSerialized;
};

const ProjectSerialized = struct {
    assetsLibrary: AssetsLibrary.Serialized,

    pub fn init(value: Project) ProjectSerialized {
        return ProjectSerialized{
            .assetsLibrary = Serializer.serializeIntermediate(value.assetsLibrary),
        };
    }

    pub fn deserialize(self: ProjectSerialized, allocator: Allocator) Project {
        return Project{
            .assetsLibrary = self.assetsLibrary.deserialize(allocator),
        };
    }
};
