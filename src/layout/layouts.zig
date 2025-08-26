const std = @import("std");
const lib = @import("lib");
const Context = lib.Context;
const Editor = lib.Editor;
const DocumentTag = lib.documents.DocumentTag;
const LayoutGeneric = lib.layouts.LayoutGeneric;
const LayoutScene = lib.layouts.LayoutScene;
const LayoutTilemap = lib.layouts.LayoutTilemap;
const LayoutAnimation = lib.layouts.LayoutAnimation;
const LayoutEntityType = lib.layouts.LayoutEntityType;
const Document = lib.documents.Document;
const DocumentContent = lib.documents.DocumentContent;

const layouts = .{
    .scene = LayoutScene,
    .tilemap = LayoutTilemap,
    .animation = LayoutAnimation,
    .entityType = LayoutEntityType,
};

pub fn getLayout(document: Document) ?(struct { type, *anyopaque }) {
    switch (document.content.?) {
        inline else => |*content, tag| {
            const tagName = @tagName(tag);
            if (@hasField(@TypeOf(layouts), tagName)) {
                return .{
                    @field(layouts, tagName),
                    content,
                };
            }
            return null;
        },
    }
}

pub fn draw(context: *Context, document: *Document) void {
    switch (document.content.?) {
        inline else => |*content, tag| {
            const tagName = @tagName(tag);

            if (@hasField(@TypeOf(layouts), tagName)) {
                const Layout = @field(layouts, tagName);
                Layout.draw(context, content);
            }

            return;
        },
    }
}

pub fn menu(context: *Context, editor: *Editor, document: *Document) void {
    switch (document.content.?) {
        inline else => |*content, tag| {
            const tagName = @tagName(tag);

            if (@hasField(@TypeOf(layouts), tagName)) {
                const Layout = @field(layouts, tagName);
                Layout.menu(context, editor, content);
            }

            return;
        },
    }
}

pub fn handleInput(context: *Context, editor: *Editor, document: *Document) void {
    switch (document.content.?) {
        inline else => |*content, tag| {
            const tagName = @tagName(tag);

            if (@hasField(@TypeOf(layouts), tagName)) {
                const Layout = @field(layouts, tagName);
                Layout.handleInput(context, editor, content);
            }

            return;
        },
    }
}
