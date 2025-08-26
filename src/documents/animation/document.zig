const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const rl = @import("raylib");
const lib = @import("lib");
const Vector = lib.Vector;
const Animation = @import("animation.zig").Animation;
const Frame = @import("animation.zig").Frame;
const DocumentGeneric = lib.documents.DocumentGeneric;
const PersistentData = @import("persistent-data.zig").PersistentData;
const NonPersistentData = @import("non-persistent-data.zig").NonPersistentData;
const UUID = lib.UUIDSerializable;

const defaultGridSize: Vector = .{ 32, 32 };

pub const AnimationsDocument = struct {
    document: DocumentType,

    isNewAnimationDialogOpen: bool = false,
    currentPreviewFrame: usize = 0,
    nextPreviewFrameAt: f64 = 0,

    pub const DocumentType = DocumentGeneric(
        PersistentData,
        NonPersistentData,
        .{},
    );

    pub fn init(allocator: Allocator) AnimationsDocument {
        return AnimationsDocument{
            .document = DocumentType.init(allocator),
        };
    }

    pub fn deinit(self: *AnimationsDocument, allocator: Allocator) void {
        self.document.deinit(allocator);
    }

    pub fn getId(self: AnimationsDocument) UUID {
        return self.document.persistentData.id;
    }

    pub fn getAnimations(self: *AnimationsDocument) *ArrayList(Animation) {
        return &self.document.persistentData.animations;
    }

    pub fn getTextureId(self: *AnimationsDocument) *?UUID {
        return &self.document.persistentData.textureId;
    }

    pub fn setTexture(self: *AnimationsDocument, textureId: UUID) void {
        self.document.persistentData.textureId = textureId;
    }

    pub fn setSelectedAnimationIndex(self: *AnimationsDocument, index: ?usize) void {
        self.document.nonPersistentData.selectedAnimation = index;
        self.setSelectedFrameIndex(null);
        self.resetAnimation();
    }

    pub fn getSelectedAnimationIndex(self: AnimationsDocument) ?usize {
        return self.document.nonPersistentData.selectedAnimation;
    }

    pub fn addAnimation(self: *AnimationsDocument, allocator: Allocator, label: [:0]const u8) void {
        const animations = self.getAnimations();
        animations.append(
            allocator,
            Animation.init(allocator, defaultGridSize),
        ) catch unreachable;
        const animation = &animations.items[animations.items.len - 1];
        animation.name.set(label);
        self.setSelectedAnimationIndex(animations.items.len - 1);
    }

    pub fn getSelectedAnimation(self: *AnimationsDocument) ?*Animation {
        const i = self.getSelectedAnimationIndex() orelse return null;
        return &self.getAnimations().items[i];
    }

    pub fn deleteSelectedAnimation(self: *AnimationsDocument, allocator: Allocator) void {
        if (self.getSelectedAnimationIndex()) |i| {
            const animation = &self.getAnimations().items[i];
            animation.deinit(allocator);
            _ = self.getAnimations().orderedRemove(i);
            self.setSelectedAnimationIndex(null);
        }
    }

    pub fn setSelectedFrameIndex(self: *AnimationsDocument, index: ?usize) void {
        self.document.nonPersistentData.selectedFrame = index;
    }

    pub fn getSelectedFrameIndex(self: AnimationsDocument) ?usize {
        return self.document.nonPersistentData.selectedFrame;
    }

    pub fn getSelectedFrame(self: *AnimationsDocument) ?*Frame {
        const animation = self.getSelectedAnimation() orelse return null;
        const i = self.getSelectedFrameIndex() orelse return null;
        return &animation.frames.items[i];
    }

    pub fn getPreviewFrame(self: *AnimationsDocument) ?Frame {
        const animation = self.getSelectedAnimation() orelse return null;
        if (self.currentPreviewFrame < animation.frames.items.len) {
            return animation.frames.items[self.currentPreviewFrame];
        } else return null;
    }

    pub fn updatePreview(self: *AnimationsDocument) void {
        const t = rl.getTime();
        const animation = self.getSelectedAnimation() orelse return;
        var frame = self.getPreviewFrame() orelse return;

        if (self.nextPreviewFrameAt <= t) {
            self.currentPreviewFrame = @mod(
                self.currentPreviewFrame + 1,
                animation.frames.items.len,
            );
            frame = self.getPreviewFrame() orelse return;
            const dt = t - self.nextPreviewFrameAt;
            const timesToFastForward = @floor(dt / animation.getTotalDuration());
            const timeToFastForward = timesToFastForward * animation.getTotalDuration();
            self.nextPreviewFrameAt += timeToFastForward;
            self.nextPreviewFrameAt += animation.frameDuration * frame.durationScale;
        }
    }

    pub fn resetAnimation(self: *AnimationsDocument) void {
        self.currentPreviewFrame = 0;
        const animation = self.getSelectedAnimation() orelse return;
        const frame = self.getPreviewFrame() orelse return;
        const frameDuration = animation.frameDuration * frame.durationScale;
        self.nextPreviewFrameAt = rl.getTime() + frameDuration;
    }

    pub fn removeSelectedFrame(self: *AnimationsDocument) void {
        const animation = self.getSelectedAnimation() orelse return;
        const frameIndex = self.getSelectedFrameIndex() orelse return;

        animation.removeFrame(frameIndex);
        self.setSelectedFrameIndex(null);
        self.resetAnimation();
    }
};
