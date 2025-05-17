const std = @import("std");
const rl = @import("raylib");
const z = @import("zgui");
const lib = @import("root").lib;
const Context = lib.Context;
const Editor = lib.Editor;
const AnimationDocument = lib.documents.AnimationDocument;
const LayoutGeneric = lib.LayoutGeneric;
const utils = @import("utils.zig");

pub const LayoutAnimation = LayoutGeneric(.animation, draw, menu, handleInput);

fn draw(context: *Context, animationDocument: *AnimationDocument) void {
    if (animationDocument.getTextureFilePath()) |textureFilePath| {
        if (context.requestTexture(textureFilePath)) |texture| {
            rl.drawTexture(texture, 0, 0, rl.Color.white);
        }
    }
}

fn menu(
    context: *Context,
    editor: *Editor,
    animationDocument: *AnimationDocument,
) void {
    z.setNextWindowPos(.{ .x = 0, .y = 0 });
    z.setNextWindowSize(.{ .w = 200, .h = 800 });
    _ = z.begin("Menu", .{ .flags = .{
        .no_title_bar = true,
        .no_resize = true,
        .no_move = true,
        .no_collapse = true,
    } });
    defer z.end();

    if (z.button("Save", .{})) {
        context.saveEditorFile(editor);
    }

    if (z.button("Set Texture", .{})) {
        if (context.openFileWithDialog(.texture)) |textureDocument| {
            animationDocument.setTexture(context.allocator, textureDocument.filePath);
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
        if (z.selectable(animation.name.slice, .{ .selected = selectedIndex == i })) {
            animationDocument.setSelectedAnimationIndex(i);
        }
    }
    z.endListBox();
}

fn handleInput(
    context: *Context,
    _: *Editor,
    _: *AnimationDocument,
) void {
    utils.cameraControls(context);
}
