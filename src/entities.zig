const std = @import("std");
const rl = @import("raylib");

const soul = @import("soul.zig");

pub const Body = struct {
    const Self = @This();
    rect: rl.Rectangle = .init(0, 0, 32, 32 * 2),
    velocity: rl.Vector2 = .zero(),
    acceleration: rl.Vector2 = .zero(),
    grounded: bool = false,

    pub fn getCenter(body: *const Self) rl.Vector2 {
        return .init(
            body.rect.x + body.rect.width / 2,
            body.rect.y + body.rect.height / 2,
        );
    }
};

pub const Player = struct {
    const Self = @This();
    body: Body = .{
        .acceleration = .init(0, 900)
    },

    const speed = 240;
    const jump = -450;

    pub fn update(self: *Self, dt: f32) void {
        self.body.velocity = self.body.velocity.add(self.body.acceleration.multiply(.init(dt, dt)));

        if (rl.isKeyDown(.a)) self.body.velocity.x = -speed
        else if (rl.isKeyDown(.d)) self.body.velocity.x = speed
        else self.body.velocity.x = 0;

        if (rl.isKeyDown(.space) and self.body.grounded) {
            self.body.velocity.y = jump;
            self.body.grounded = false;
        }
    }

    pub fn draw(self: *const Self) void {
        rl.drawRectangleRec(self.body.rect, .red);
    }
};

pub const Block = struct {
    rect: rl.Rectangle,
};

