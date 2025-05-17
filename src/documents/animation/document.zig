const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const rl = @import("raylib");
const lib = @import("root").lib;
const Vector = lib.Vector;
const Animation = @import("animation.zig").Animation;
const DocumentGeneric = lib.documents.DocumentGeneric;
const PersistentData = @import("persistent-data.zig").PersistentData;
const NonPersistentData = @import("non-persistent-data.zig").NonPersistentData;

const defaultGridSize: Vector = .{ 32, 32 };

pub const AnimationDocument = struct {
    document: DocumentType,

    isNewAnimationDialogOpen: bool = false,

    pub const DocumentType = DocumentGeneric(PersistentData, NonPersistentData, .{});

    pub fn init(allocator: Allocator) AnimationDocument {
        return AnimationDocument{
            .document = DocumentType.init(allocator),
        };
    }

    pub fn deinit(self: *AnimationDocument, allocator: Allocator) void {
        self.document.deinit(allocator);
    }

    pub fn getAnimations(self: *AnimationDocument) *ArrayList(Animation) {
        return &self.document.persistentData.animations;
    }

    pub fn getTextureFilePath(self: AnimationDocument) ?[:0]const u8 {
        return self.document.persistentData.texturePath;
    }

    pub fn setTexture(self: *AnimationDocument, allocator: Allocator, path: [:0]const u8) void {
        const data = self.document.persistentData;
        if (data.texturePath) |tp| allocator.free(tp);
        data.texturePath = allocator.dupeZ(u8, path) catch unreachable;
    }

    pub fn setSelectedAnimationIndex(self: *AnimationDocument, index: ?usize) void {
        self.document.nonPersistentData.selectedAnimation = index;
    }

    pub fn getSelectedAnimationIndex(self: AnimationDocument) ?usize {
        return self.document.nonPersistentData.selectedAnimation;
    }

    pub fn addAnimation(self: *AnimationDocument, allocator: Allocator, label: [:0]const u8) void {
        const animations = self.getAnimations();
        animations.append(
            allocator,
            Animation.init(allocator, defaultGridSize),
        ) catch unreachable;
        const animation = &animations.items[animations.items.len - 1];
        animation.name.set(label);
    }
};
