const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const rl = @import("raylib");
const lib = @import("root").lib;
const Vector = lib.Vector;
const Animation = @import("animation.zig").Animation;
const Frame = @import("animation.zig").Frame;
const DocumentGeneric = lib.documents.DocumentGeneric;
const PersistentData = @import("persistent-data.zig").PersistentData;
const NonPersistentData = @import("non-persistent-data.zig").NonPersistentData;
const UUID = lib.UUIDSerializable;

const defaultGridSize: Vector = .{ 32, 32 };

pub const AnimationDocument = struct {
    document: DocumentType,

    isNewAnimationDialogOpen: bool = false,
    currentPreviewFrame: usize = 0,
    nextPreviewFrameAt: f64 = 0,

    pub const DocumentType = DocumentGeneric(
        PersistentData,
        NonPersistentData,
        .{},
    );

    pub fn init(allocator: Allocator) AnimationDocument {
        return AnimationDocument{
            .document = DocumentType.init(allocator),
        };
    }

    pub fn deinit(self: *AnimationDocument, allocator: Allocator) void {
        self.document.deinit(allocator);
    }

    pub fn getId(self: AnimationDocument) UUID {
        return self.document.persistentData.id;
    }

    pub fn getAnimations(self: *AnimationDocument) *ArrayList(Animation) {
        return &self.document.persistentData.animations;
    }

    pub fn getTextureId(self: *AnimationDocument) *?UUID {
        return &self.document.persistentData.textureId;
    }

    pub fn setTexture(self: *AnimationDocument, textureId: UUID) void {
        self.document.persistentData.textureId = textureId;
    }

    pub fn setSelectedAnimationIndex(self: *AnimationDocument, index: ?usize) void {
        self.document.nonPersistentData.selectedAnimation = index;
        self.setSelectedFrameIndex(null);
        self.resetAnimation();
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
        self.setSelectedAnimationIndex(animations.items.len - 1);
    }

    pub fn getSelectedAnimation(self: *AnimationDocument) ?*Animation {
        const i = self.getSelectedAnimationIndex() orelse return null;
        return &self.getAnimations().items[i];
    }

    pub fn deleteSelectedAnimation(self: *AnimationDocument, allocator: Allocator) void {
        if (self.getSelectedAnimationIndex()) |i| {
            const animation = &self.getAnimations().items[i];
            animation.deinit(allocator);
            _ = self.getAnimations().orderedRemove(i);
            self.setSelectedAnimationIndex(null);
        }
    }

    pub fn setSelectedFrameIndex(self: *AnimationDocument, index: ?usize) void {
        self.document.nonPersistentData.selectedFrame = index;
    }

    pub fn getSelectedFrameIndex(self: AnimationDocument) ?usize {
        return self.document.nonPersistentData.selectedFrame;
    }

    pub fn getSelectedFrame(self: *AnimationDocument) ?*Frame {
        const animation = self.getSelectedAnimation() orelse return null;
        const i = self.getSelectedFrameIndex() orelse return null;
        return &animation.frames.items[i];
    }

    pub fn getPreviewFrame(self: *AnimationDocument) ?Frame {
        const animation = self.getSelectedAnimation() orelse return null;
        if (self.currentPreviewFrame < animation.frames.items.len) {
            return animation.frames.items[self.currentPreviewFrame];
        } else return null;
    }

    pub fn updatePreview(self: *AnimationDocument) void {
        const animation = self.getSelectedAnimation() orelse return;
        var frame = self.getPreviewFrame() orelse return;

        if (self.nextPreviewFrameAt <= rl.getTime()) {
            self.currentPreviewFrame = @mod(
                self.currentPreviewFrame + 1,
                animation.frames.items.len,
            );
            frame = self.getPreviewFrame() orelse return;
            self.nextPreviewFrameAt += animation.frameDuration * frame.durationScale;
        }
    }

    pub fn resetAnimation(self: *AnimationDocument) void {
        self.currentPreviewFrame = 0;
        const animation = self.getSelectedAnimation() orelse return;
        const frame = self.getPreviewFrame() orelse return;
        const frameDuration = animation.frameDuration * frame.durationScale;
        self.nextPreviewFrameAt = rl.getTime() + frameDuration;
    }

    pub fn removeSelectedFrame(self: *AnimationDocument) void {
        const animation = self.getSelectedAnimation() orelse return;
        const frameIndex = self.getSelectedFrameIndex() orelse return;

        animation.removeFrame(frameIndex);
        self.setSelectedFrameIndex(null);
        self.resetAnimation();
    }
};
