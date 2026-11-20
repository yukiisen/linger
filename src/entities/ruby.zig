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
    self.body.rect = .init(x * 32, y * 32, 22, 32);

    try self.animation.create("idle", .{
        .tex = texture.get("ruby_idle"),

        .frame_width = 60,
        .frame_height = 80,
        .padding = .init(20, 0),

        .offset = .init(0, -2),

        .start = 0,
        .end = 18,

        .frame_duration = 0.07,
        .repeat = -1,
    });

    try self.animation.create("run", .{
        .tex = texture.get("ruby_run"),

        .frame_width = 60,
        .frame_height = 80,
        .padding = .init(20, 0),

        .offset = .init(0, -2),

        .start = 0,
        .end = 24,

        .frame_duration = 0.035,
        .repeat = -1,
    });

    try self.animation.create("jump", .{
        .tex = texture.get("ruby_jump"),

        .frame_width = 60,
        .frame_height = 80,
        .padding = .init(20, 0),

        .offset = .init(0, -2),

        .start = 0,
        .end = 19,

        .frame_duration = 0.05,
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
        if (self.body.grounded) self.animation.play("run");
    }
    else if (rl.isKeyDown(.d)) {
        self.body.velocity.x = speed;
        self.flip = false;
        if (self.body.grounded) self.animation.play("run");
    }
    else {
        self.body.velocity.x = 0;
        if (self.body.grounded) self.animation.play("idle");
    }

    if (rl.isKeyDown(.space) and self.body.grounded) {
        self.body.velocity.y = jump;
        self.body.grounded = false;
        self.animation.play("jump");
    }
}

pub fn getPossessed(self: *Self) soul.Possessed {
    return .init(self);
}

pub fn draw(self: *const Self) void {
    self.animation.draw(self.body.getCenter().add(.init(0, -4)), self.flip);
}
