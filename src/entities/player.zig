const std = @import("std");
const rl = @import("raylib");
const Body = @import("entities.zig").Body;

const soul = @import("../soul.zig");
const anim = @import("../res/animation.zig");
const texture = @import("../res/textures.zig");

const Self = @This();
body: Body = .{
    .acceleration = .init(0, gravity),
    .kind = .dynamic
},

animation: anim.AnimationPlayer,
flip: bool = false,

pub const speed = 240;
pub const jump = -450;
pub const gravity = 900;

pub fn spawn(gpa: std.mem.Allocator, x: f32, y: f32) !Self {
    var self = Self { .animation = .init(gpa) };
    self.body.rect = .init(x * 32, y * 32, 39, 54);

    try self.animation.create("idle", .{
        .tex = texture.get("maid_idle"),

        .frame_width = 1536/4,
        .frame_height = 128,

        .start = 0,
        .end = 4,

        .frame_duration = 0.2,
        .repeat = -1,
    });

    try self.animation.create("run", .{
        .tex = texture.get("maid_run"),

        .frame_width = 2304/6,
        .frame_height = 128,

        .start = 0,
        .end = 6,

        .frame_duration = 0.1,
        .repeat = -1,
    });

    return self;
}

pub fn deinit(self: *Self) void {
    self.animation.deinit();
}

pub fn update(self: *Self, dt: f32) void {
    self.animation.tick(dt);

    if (self.animation.active == null)
        self.animation.play("idle");
}

pub fn pupdate(self: *Self, _: f32) void {
    if (rl.isKeyDown(.a)) {
        self.body.velocity.x = -speed;
        self.flip = true;
        self.animation.play("run");
    }
    else if (rl.isKeyDown(.d)) {
        self.body.velocity.x = speed;
        self.flip = false;
        self.animation.play("run");
    }
    else {
        self.body.velocity.x = 0;
        self.animation.play("idle");
    }

    if (rl.isKeyDown(.space) and self.body.grounded) {
        self.body.velocity.y = jump;
        self.body.grounded = false;
    }
}

pub fn getPossessed(self: *Self) soul.Possessed {
    return .init(self);
}

pub fn draw(self: *const Self) void {
    // rl.drawRectangleLinesEx(self.body.rect, 1, .blue);
    self.animation.draw(self.body.getCenter().add(.init(0, -4)), self.flip);
}
