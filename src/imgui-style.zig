const z = @import("zgui");

pub fn setImguiStyle() void {
    const style = z.getStyle();
    style.setColorsDark();
    style.setColor(.window_bg, .{ 0, 0, 0, 0.6 });
    style.setColor(.title_bg_active, .{ 0.3, 0.4, 0.3, 1 });
    style.setColor(.frame_bg, .{ 0.3, 0.4, 0.3, 1 });
    style.setColor(.header, .{ 0.4, 0.7, 0.4, 0.6 });
    style.setColor(.button, .{ 0.3, 0.4, 0.3, 1 });
    style.setColor(.button_hovered, .{ 0.4, 0.7, 0.4, 1 });
    style.setColor(.separator_hovered, .{ 0.4, 0.7, 0.4, 1 });
    style.setColor(.tab_hovered, .{ 0.4, 0.7, 0.4, 1 });
    style.setColor(.frame_bg_hovered, .{ 0.4, 0.7, 0.4, 1 });
    style.setColor(.plot_lines_hovered, .{ 0.4, 0.7, 0.4, 1 });
    style.setColor(.resize_grip_hovered, .{ 0.4, 0.7, 0.4, 1 });
    style.setColor(.scrollbar_grab_hovered, .{ 0.4, 0.7, 0.4, 1 });
    style.setColor(.header_hovered, .{ 0.4, 0.7, 0.4, 0.6 });
    style.setColor(.check_mark, .{ 1, 1, 1, 1 });
    style.frame_rounding = 5;
    style.window_rounding = 5;
    style.scrollbar_rounding = 5;
    style.child_rounding = 5;
    style.grab_rounding = 5;
    style.popup_rounding = 5;
}
