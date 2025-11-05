const std = @import("std");
const lib = @import("lib");
const Context = lib.Context;
const Vector = lib.Vector;
const UUID = lib.UUIDSerializable;
const MapCell = lib.sceneMap.MapCell;

const c = @import("c").c;
const rl = @import("raylib");
const z = @import("zgui");

const utils = @import("utils.zig");

const defaultNumberOfItems = 10;

pub fn findAssetsUI(context: *Context) void {
    if (context.isFindAssetsMenuOpen) {
        z.setNextWindowSize(.{ .cond = .first_use_ever, .w = 600, .h = 300 });
        z.setNextWindowPos(.{ .cond = .first_use_ever, .x = 300, .y = 200 });
        // z.setNextWindowBgAlpha(.{ .alpha = 1 });
        _ = z.begin("Find Assets...", .{ .popen = &context.isFindAssetsMenuOpen, .flags = .{
            .no_move = false,
        } });
        defer z.end();

        z.pushStrId("input");
        if (!context.hasFocusedFindAssetsInput) {
            z.setKeyboardFocusHere(0);
            context.hasFocusedFindAssetsInput = true;
        }
        if (z.inputText("", .{ .buf = &context.findAssetsInputBuffer })) {
            search(context);
        }
        z.popId();

        if (z.beginChild("list", .{})) {
            for (context.findAssetsResults.items, 0..) |id, i| {
                const fileName = context.getFilePathById(id) orelse {
                    std.log.err("Could not get filename for asset {f}", .{id});
                    continue;
                };

                const selected = if (context.findAssetsHighlightedIndex) |n| i == n else false;

                if (z.selectable(fileName, .{ .selected = selected })) {
                    close(context);
                    context.openEditorById(id);
                }
            }
            z.endChild();
        }
    }
}

pub fn findAssetsUIHandleInput(context: *Context) void {
    if (context.isFindAssetsMenuOpen) {
        if (context.findAssetsHighlightedIndex) |i| {
            if (rl.isKeyPressed(.enter)) {
                close(context);
                context.openEditorById(context.findAssetsResults.items[i]);
                return;
            }
        }
        if (rl.isKeyPressed(.down)) {
            context.findAssetsHighlightedIndex = if (context.findAssetsHighlightedIndex) |n| @min(n + 1, context.findAssetsResults.items.len - 1) else 0;
        }
        if (rl.isKeyPressed(.up)) {
            context.findAssetsHighlightedIndex = if (context.findAssetsHighlightedIndex) |n| n -| 1 else context.findAssetsResults.items.len - 1;
        }
    } else {
        if (!z.io.getWantCaptureKeyboard()) {
            if ((rl.isKeyDown(.left_control) or rl.isKeyDown(.right_control)) and rl.isKeyPressed(.p)) {
                open(context);
            }
        }
    }
}

fn search(context: *Context) void {
    std.log.debug("searching...", .{});

    const p = context.currentProject orelse return;
    var candidates = p.assetIndex.hashMap.map.iterator();

    const text = std.mem.trim(u8, std.mem.sliceTo(&context.findAssetsInputBuffer, 0), " \t\n\r");

    if (text.len == 0) {
        setResultsToDefault(context);
        return;
    }

    context.findAssetsResults.clearRetainingCapacity();
    context.findAssetsHighlightedIndex = null;

    while (candidates.next()) |candidate| {
        if (match(text, candidate.value_ptr.*)) {
            context.findAssetsResults.append(context.allocator, candidate.key_ptr.*) catch unreachable;
        }
    }

    if (context.findAssetsResults.items.len != 0) {
        context.findAssetsHighlightedIndex = 0;
    }
}

fn match(text: []const u8, source: []const u8) bool {
    var splitIt = std.mem.splitScalar(u8, text, ' ');
    var index: usize = 0;

    while (splitIt.next()) |part| {
        index = std.mem.indexOfPos(u8, source, index, part) orelse return false;
        index += part.len;
    }

    return true;
}

fn open(context: *Context) void {
    context.isFindAssetsMenuOpen = true;
    context.findAssetsInputBuffer[0] = 0;
    context.hasFocusedFindAssetsInput = false;
    context.findAssetsHighlightedIndex = null;
    setResultsToDefault(context);
}

fn close(context: *Context) void {
    context.isFindAssetsMenuOpen = false;
}

fn setResultsToDefault(context: *Context) void {
    context.findAssetsResults.clearRetainingCapacity();
    context.findAssetsResults.ensureTotalCapacity(context.allocator, defaultNumberOfItems) catch unreachable;
    const p = context.currentProject orelse return;
    const ids = p.assetIndex.hashMap.map.keys()[0..defaultNumberOfItems];
    context.findAssetsResults.appendSliceAssumeCapacity(ids);
}
