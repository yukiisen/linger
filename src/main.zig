const std = @import("std");

const rl = @import("raylib");

pub fn main(_: std.process.Init) !void {
    rl.initWindow(800, 600, "hentai");
    defer rl.closeWindow();


    var color: rl.Color = .pink;
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        if (rl.isKeyPressed(.q)) break;

        if (rl.isKeyPressed(.a)) color = .purple
        else if (rl.isKeyPressed(.s)) color = .pink;

        rl.clearBackground(color);
    }
}
