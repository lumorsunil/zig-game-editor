const std = @import("std");
const rl = @import("raylib");
const z = @import("zgui");
const c = @import("c");
const lib = @import("root").lib;
const Context = lib.Context;
const Editor = lib.Editor;
const AnimationDocument = lib.documents.AnimationDocument;
const Animation = lib.documents.animation.Animation;
const Frame = lib.documents.animation.Frame;
const LayoutGeneric = lib.LayoutGeneric;
const Vector = lib.Vector;
const Node = lib.Node;
const utils = @import("utils.zig");
const config = @import("../config.zig");

pub const LayoutAnimation = LayoutGeneric(.animation, draw, menu, handleInput);

fn draw(context: *Context, animationDocument: *AnimationDocument) void {
    const textureId = animationDocument.getTextureId() orelse return;
    const texture = context.requestTextureById(textureId) catch return orelse return;

    rl.drawTextureEx(texture.*, .{ .x = 0, .y = 0 }, 0, @floatFromInt(context.scale), rl.Color.white);
}

fn menu(
    context: *Context,
    editor: *Editor,
    animationDocument: *AnimationDocument,
) void {
    const screenSize: @Vector(2, f32) = @floatFromInt(Vector{ rl.getScreenWidth(), rl.getScreenHeight() });
    z.setNextWindowPos(.{ .x = 0, .y = config.topBarOffset });
    z.setNextWindowSize(.{ .w = 300, .h = screenSize[1] - config.topBarOffset });
    _ = z.begin("Menu", .{ .flags = .{
        .no_title_bar = true,
        .no_resize = true,
        .no_move = true,
        .no_collapse = true,
    } });
    defer z.end();

    if (z.button("Save", .{})) {
        context.saveEditorFile(editor);
        context.updateThumbnailById(animationDocument.getId());
    }

    textureInput(context, animationDocument);

    if (z.button("Reload Texture", .{})) {
        if (animationDocument.getTextureId()) |textureId| {
            context.reloadDocumentById(textureId);
        }
    }

    if (z.button("New Animation", .{})) {
        animationDocument.isNewAnimationDialogOpen = true;
    }

    if (animationDocument.isNewAnimationDialogOpen) {
        _ = z.begin("New Animation", .{});
        defer z.end();

        z.pushStrId("new-animation-input");
        _ = z.inputText("", .{
            .buf = &context.reusableTextBuffer,
        });
        z.popId();

        if (z.button("Create", .{})) {
            animationDocument.isNewAnimationDialogOpen = false;
            animationDocument.addAnimation(
                context.allocator,
                std.mem.sliceTo(&context.reusableTextBuffer, 0),
            );
            context.reusableTextBuffer[0] = 0;
        }
    }

    _ = z.beginListBox("Animations", .{});
    for (animationDocument.getAnimations().items, 0..) |animation, i| {
        const selectedIndex = animationDocument.getSelectedAnimationIndex();
        if (z.selectable(animation.name.buffer, .{ .selected = selectedIndex == i })) {
            animationDocument.setSelectedAnimationIndex(i);
        }
    }
    z.endListBox();

    if (animationDocument.getSelectedAnimation()) |animation| {
        animationDetailsMenu(context, animationDocument, animation);
        frameWindow(context, animationDocument, animation);
        animationDocument.updatePreview();
        previewWindow(context, animationDocument, animation);

        if (animationDocument.getSelectedFrame()) |frame| {
            frameDetailsMenu(animationDocument, animation, frame);
        }
    }
}

fn textureInput(context: *Context, animationDocument: *AnimationDocument) void {
    const textureId = animationDocument.getTextureId();
    const textureFilePath = (if (textureId) |id| context.getFilePathById(id) else null) orelse "None";
    z.text("{s}", .{textureFilePath});
    if (z.beginDragDropTarget()) {
        if (z.getDragDropPayload()) |payload| {
            const node: *Node = @as(**Node, @ptrCast(@alignCast(payload.data.?))).*;

            switch (node.*) {
                .directory => {},
                .file => |file| {
                    if (file.documentType == .texture) {
                        if (z.acceptDragDropPayload("asset", .{})) |_| {
                            const newTextureId = context.getIdByFilePath(file.path) orelse unreachable;
                            animationDocument.setTexture(newTextureId);
                        }
                    }
                },
            }
        }
        z.endDragDropTarget();
    }
}

fn animationDetailsMenu(
    context: *Context,
    animationDocument: *AnimationDocument,
    animation: *Animation,
) void {
    z.separatorText("Animation");
    if (z.button("Delete Animation", .{})) {
        return animationDocument.deleteSelectedAnimation(context.allocator);
    }
    _ = z.inputText("Name", .{ .buf = animation.name.buffer });
    _ = z.inputInt2("Grid size", .{ .v = &animation.gridSize });
    if (z.inputFloat("Frame dur.", .{ .v = &animation.frameDuration })) {
        animationDocument.resetAnimation();
    }
    z.text("Total dur.: {d:0.3}", .{animation.getTotalDuration()});
}

fn frameDetailsMenu(
    animationDocument: *AnimationDocument,
    animation: *Animation,
    frame: *Frame,
) void {
    z.separatorText("Frame");
    if (z.button("Delete Frame", .{})) return animationDocument.removeSelectedFrame();
    _ = z.inputInt2("Origin", .{ .v = &frame.origin });
    if (z.inputFloat("Dur. Scale", .{ .v = &frame.durationScale })) {
        animationDocument.resetAnimation();
    }
    z.text("Frame start: {d:0.3}", .{animation.getFrameStart(frame)});
}

fn frameWindow(
    context: *Context,
    animationDocument: *AnimationDocument,
    animation: *Animation,
) void {
    const screenWidth: f32 = @floatFromInt(rl.getScreenWidth());
    z.setNextWindowSize(.{
        .cond = .always,
        .w = screenWidth - 300,
        .h = @floatFromInt(context.scale * animation.gridSize[1] + 24 * 2 + 16),
    });
    _ = z.begin("Animation Frames", .{ .flags = .{
        .always_horizontal_scrollbar = true,
        .no_resize = true,
    } });
    var listBoxSize = z.getWindowContentRegionMax();
    listBoxSize[0] = @floatFromInt(@as(i32, @intCast(animation.frames.items.len)) * (context.scale * animation.gridSize[0] + 8));
    listBoxSize[1] -= 24 + 12;
    z.pushStrId("Animation Frames Listbox");
    if (z.beginListBox("", .{ .w = listBoxSize[0], .h = listBoxSize[1] })) {
        for (animation.frames.items, 0..) |frame, i| {
            var buffer: [4:0]u8 = undefined;
            const label = std.fmt.bufPrintZ(&buffer, "{d}", .{i}) catch unreachable;
            const isSelected = if (animationDocument.getSelectedFrameIndex()) |si| si == i else false;
            const fGridSizeScaled: @Vector(2, f32) = @floatFromInt(animation.gridSize * context.scaleV);
            const selectablePos = z.getCursorPos();
            if (z.selectable(
                label,
                .{
                    .selected = isSelected,
                    .w = fGridSizeScaled[0],
                    .h = fGridSizeScaled[1],
                },
            )) {
                animationDocument.setSelectedFrameIndex(i);
            }
            const nextPos = z.getCursorPos();
            z.setCursorPos(selectablePos);
            drawFrame(context, animationDocument, animation, frame);
            z.setCursorPos(nextPos);

            if (i < animation.frames.items.len - 1) z.sameLine(.{});
        }
        z.endListBox();
    }
    z.popId();
    z.end();
}

fn drawFrame(
    context: *Context,
    animationDocument: *AnimationDocument,
    animation: *Animation,
    frame: Frame,
) void {
    const textureId = animationDocument.getTextureId() orelse return;
    const texture = context.requestTextureById(textureId) catch return orelse return;

    const fGridSize: @Vector(2, f32) = @floatFromInt(animation.gridSize);
    const gridPosition = frame.gridPos;
    const sourceRectMin = @as(@Vector(2, f32), @floatFromInt(gridPosition * animation.gridSize));
    const sourceRect = c.Rectangle{
        .x = sourceRectMin[0],
        .y = sourceRectMin[1],
        .width = fGridSize[0],
        .height = fGridSize[1],
    };
    c.rlImGuiImageRect(
        @ptrCast(texture),
        animation.gridSize[0] * context.scale,
        animation.gridSize[1] * context.scale,
        sourceRect,
    );
}

fn previewWindow(
    context: *Context,
    animationDocument: *AnimationDocument,
    animation: *Animation,
) void {
    const fGridSize: @Vector(2, f32) = @floatFromInt(animation.gridSize);
    const fGridSizeScaled: @Vector(2, f32) = @floatFromInt(animation.gridSize * context.scaleV);
    const padding = @Vector(2, f32){ 2, 2 } * @as(@Vector(2, f32), @floatFromInt(context.scaleV));
    z.setNextWindowSize(.{
        .cond = .always,
        .w = fGridSizeScaled[0] + padding[0] * 2,
        .h = fGridSizeScaled[1] + padding[1] * 2,
    });
    _ = z.begin("Preview", .{ .flags = .{ .no_title_bar = true, .no_scrollbar = true, .always_auto_resize = true } });
    defer z.end();

    const textureId = animationDocument.getTextureId() orelse return;
    const texture = context.requestTextureById(textureId) catch return orelse return;
    const currentFrame = animationDocument.getPreviewFrame() orelse return;

    const gridPosition = currentFrame.gridPos;
    const sourceRectMin = @as(
        @Vector(2, f32),
        @floatFromInt(gridPosition * animation.gridSize),
    );
    const sourceRect = c.Rectangle{
        .x = sourceRectMin[0],
        .y = sourceRectMin[1],
        .width = fGridSize[0],
        .height = fGridSize[1],
    };

    z.setCursorPos(padding);
    c.rlImGuiImageRect(
        @ptrCast(texture),
        animation.gridSize[0] * context.scale,
        animation.gridSize[1] * context.scale,
        sourceRect,
    );
}

fn handleInput(
    context: *Context,
    _: *Editor,
    animationDocument: *AnimationDocument,
) void {
    utils.cameraControls(context);

    if (animationDocument.getSelectedAnimation()) |animation| {
        handleAnimationInput(context, animationDocument, animation);
    }
}

fn handleAnimationInput(
    context: *Context,
    animationDocument: *AnimationDocument,
    animation: *Animation,
) void {
    const gridPosition = utils.getMouseGridPositionWithSize(context, animation.gridSize);
    const textureId = animationDocument.getTextureId() orelse return;
    const texture = context.requestTextureById(textureId) catch return orelse return;

    const textureSize: Vector = .{ texture.width, texture.height };
    const textureGridSize: Vector = @divFloor(textureSize, animation.gridSize);

    const isInBounds = @reduce(.And, gridPosition >= Vector{ 0, 0 }) and @reduce(.And, gridPosition < textureGridSize);

    if (isInBounds) {
        utils.highlightHoveredCell(context, animation.gridSize, textureGridSize);

        if (z.isMouseClicked(.left)) {
            if (animationDocument.getSelectedFrame()) |frame| {
                frame.gridPos = gridPosition;
            } else {
                animation.addFrame(context.allocator, gridPosition);
                animationDocument.resetAnimation();
            }
        }
    }
}
