const std = @import("std");
const rl = @import("raylib");

const textures = @import("res/textures.zig");

const Game = @import("game.zig");

pub fn main(init: std.process.Init) !void {
    rl.setConfigFlags(.{ .vsync_hint = true, .fullscreen_mode = false });
    rl.initWindow(1280, 720, "Linger");
    defer rl.closeWindow();

    textures.init(init.gpa);
    defer textures.deinit();

    var game = Game.init(init.gpa);
    defer game.deinit();

    const target = try rl.loadRenderTexture(Game.WIDTH, Game.HEIGHT);
    defer target.unload();

    rl.setTextureFilter(target.texture, .point);
    rl.setExitKey(.q);

    try game.load(init.io);

    while (!rl.windowShouldClose()) {
        const dt = @min(rl.getFrameTime(), 1.0 / 20.0);
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
