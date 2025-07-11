const rl = @import("raylib");
const z = @import("zgui");
const lib = @import("root").lib;
const Context = lib.Context;
const Project = lib.Project;
const Vector = lib.Vector;
const utils = @import("utils.zig");

pub fn noProjectOpenedMenu(context: *Context) void {
    const screenSize: Vector = .{ rl.getScreenWidth(), rl.getScreenHeight() };
    const screenW, const screenH = @as(@Vector(2, f32), @floatFromInt(screenSize));

    z.setNextWindowPos(.{ .x = 0, .y = 0 });
    z.setNextWindowSize(.{ .w = screenW, .h = screenH });
    _ = z.begin("No Project Opened Menu", .{ .flags = .{ .no_title_bar = true, .no_resize = true, .no_collapse = true, .no_background = true, .no_move = true } });
    defer z.end();

    const buttonSize = 256;
    const buttonSpacing = 64;

    z.setCursorPos(.{ screenW / 2 - buttonSize - buttonSpacing, screenH / 2 - buttonSize / 2 });

    if (z.button("New Project", .{ .w = buttonSize, .h = buttonSize })) {
        context.newProject();
    }
    z.sameLine(.{ .spacing = buttonSpacing });
    if (z.button("Open Project", .{ .w = buttonSize, .h = buttonSize })) {
        context.openProject();
    }
}

pub fn projectMenu(context: *Context, project: *Project) bool {
    if (z.beginMainMenuBar()) {
        defer z.endMainMenuBar();
        if (z.beginMenu("Projects", true)) {
            defer z.endMenu();
            if (z.selectable("New Project", .{})) {
                context.newProject();
                return true;
            }
            if (z.selectable("Open Project", .{})) {
                context.openProject();
                return true;
            }
            if (z.selectable("Close Project", .{})) {
                context.closeProject();
                return true;
            }
        }
        if (z.button("Project Options", .{})) {
            project.isProjectOptionsOpen = true;
        }
        z.sameLine(.{});
        if (z.button("Scene Map", .{})) {
            context.isSceneMapWindowOpen = true;
        }
        z.sameLine(.{});
    }

    projectOptionsUI(context, project);

    return false;
}

fn projectOptionsUI(context: *Context, project: *Project) void {
    if (project.isProjectOptionsOpen) {
        z.setNextWindowSize(.{ .w = 800, .h = 600, .cond = .first_use_ever });
        _ = z.begin("Project Options", .{ .popen = &project.isProjectOptionsOpen });
        defer z.end();

        z.text("Default Tileset:", .{});
        z.sameLine(.{ .spacing = 8 });
        _ = utils.assetInput(.texture, context, &project.options.defaultTileset);
    }
}
