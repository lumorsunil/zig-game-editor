const std = @import("std");
const lib = @import("root").lib;
const Context = lib.Context;
const Editor = lib.Editor;
const DocumentTag = lib.DocumentTag;
const DocumentContent = lib.DocumentContent;

fn DocumentPayload(comptime documentType: DocumentTag) type {
    return std.meta.TagPayload(DocumentContent, documentType);
}

pub fn LayoutGeneric(
    comptime documentType: DocumentTag,
    comptime drawFn: fn (
        context: *Context,
        document: *DocumentPayload(documentType),
    ) void,
    comptime menuFn: fn (
        context: *Context,
        editor: *Editor,
        document: *DocumentPayload(documentType),
    ) void,
    comptime handleInputFn: fn (
        context: *Context,
        editor: *Editor,
        document: *DocumentPayload(documentType),
    ) void,
) type {
    return struct {
        pub fn draw(
            context: *Context,
            document: *DocumentPayload(documentType),
        ) void {
            drawFn(context, document);
        }

        pub fn menu(
            context: *Context,
            editor: *Editor,
            document: *DocumentPayload(documentType),
        ) void {
            menuFn(context, editor, document);
        }

        pub fn handleInput(
            context: *Context,
            editor: *Editor,
            document: *DocumentPayload(documentType),
        ) void {
            handleInputFn(context, editor, document);
        }
    };
}
