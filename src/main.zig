const std = @import("std");
const rl = @import("raylib");

const Game = @import("game.zig");

pub fn main(init: std.process.Init) !void {
    rl.setConfigFlags(.{ .vsync_hint = true, .fullscreen_mode = true });
    rl.initWindow(1280, 720, "Linger");
    defer rl.closeWindow();

    var game = Game.init(init.gpa);
    defer game.deinit();

    const target = try rl.loadRenderTexture(Game.WIDTH, Game.HEIGHT);
    defer target.unload();

    rl.setTextureFilter(target.texture, .point);
    rl.setExitKey(.q);

    try game.load();

    while (!rl.windowShouldClose()) {
        const dt = @min(rl.getFrameTime(), 1.0 / 60.0);
        try game.update(dt);

        rl.beginTextureMode(target);
        rl.clearBackground(.blank);
        try game.draw();
        rl.endTextureMode();

        rl.beginDrawing();
        rl.clearBackground(.black);
        try game.postprocess(&target);
        rl.endDrawing();
    }
}
