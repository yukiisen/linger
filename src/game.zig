const std = @import("std");
const rl = @import("raylib");

const Level = @import("level/level.zig");
const Underground = @import("level/Underground.zig");

const Self = @This();

pub const WIDTH = 640;
pub const HEIGHT = 360;

gpa: std.mem.Allocator,
levels: std.ArrayList(Level) = .empty,
currentLevel: Level = undefined,
camera: rl.Camera2D = .{
    .offset = .zero(),
    .target = .zero(),
    .rotation = 0,
    .zoom = 1,
},

pub fn init(gpa: std.mem.Allocator) Self {
    return .{
        .gpa = gpa,
    };
}

pub fn deinit(self: *Self) void {
    for (self.levels.items) |*lv| {
        lv.deinit();
    }

    self.levels.deinit(self.gpa);
}

pub fn load(self: *Self, io: std.Io) !void {
    try self.levels.append(self.gpa, try .init(Underground.init(self.gpa), self.gpa));
    self.currentLevel = self.levels.items[0];

    try self.currentLevel.load(io);
}

pub fn update(self: *Self, dt: f32) !void {
    try self.currentLevel.update(dt);

    self.camera.target = .lerp(
        self.camera.target,
        self.currentLevel.soul.possessed.body.getCenter(),
        10.0 * dt,
    );

    self.camera.offset = .init(WIDTH / 2, HEIGHT / 2);
}

pub fn draw(self: *const Self) !void {
    self.camera.begin();
    try self.currentLevel.draw();
    self.camera.end();

    rl.drawFPS(10, 10);
}

pub fn postprocess(_: *Self, target: *const rl.RenderTexture) !void {
    const screen_width: f32 = @floatFromInt(rl.getScreenWidth());
    const screen_height: f32 = @floatFromInt(rl.getScreenHeight());

    const scale = @min(
        screen_width / WIDTH,
        screen_height / HEIGHT,
    );

    const dest_width = WIDTH * scale;
    const dest_height = HEIGHT * scale;

    const dest_x = (screen_width - dest_width) / 2;
    const dest_y = (screen_height - dest_height) / 2;

    rl.drawTexturePro(
        target.texture,
        .init(0, 0, WIDTH, -HEIGHT),
        .init(dest_x, dest_y, dest_width, dest_height),
        .init(0, 0),
        0,
        .white,
    );
}
