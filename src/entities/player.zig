const rl = @import("raylib");
const Body = @import("entities.zig").Body;

const soul = @import("../soul.zig");

const Self = @This();
body: Body = .{
    .acceleration = .init(0, gravity),
    .kind = .dynamic
},

color: rl.Color,

pub const speed = 240;
pub const jump = -450;
pub const gravity = 900;

pub fn spawn(x: f32, y: f32, color: rl.Color) Self {
    var self = Self { .color = color };
    self.body.rect.x = x * 32;
    self.body.rect.y = y * 32;

    return self;
}

pub fn pupdate(self: *Self, _: f32) void {
    if (rl.isKeyDown(.a)) self.body.velocity.x = -speed
    else if (rl.isKeyDown(.d)) self.body.velocity.x = speed
    else self.body.velocity.x = 0;

    if (rl.isKeyDown(.space) and self.body.grounded) {
        self.body.velocity.y = jump;
        self.body.grounded = false;
    }
}

pub fn getPossessed(self: *Self) soul.Possessed {
    return .init(self);
}

pub fn draw(self: *const Self) void {
    rl.drawRectangleRec(self.body.rect, self.color);
}
