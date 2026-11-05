const std = @import("std");
const rl = @import("raylib");

const Body = @import("entities.zig").Body;
const Block = @import("entities.zig").Block;
const Player = @import("entities.zig").Player;
const Soul = @import("soul.zig").Soul;
const Possessed = @import("soul.zig").Possessed;

const Self = @This();

pub const WIDTH = 640;
pub const HEIGHT = 360;

gpa: std.mem.Allocator,
player: Player = .{},
soul: Soul = undefined,
blocks: std.array_list.Managed(Block),
should_close: bool = false,
camera: rl.Camera2D = .{
    .offset = .zero(),
    .target = .zero(),
    .rotation = 0,
    .zoom = 1,
},

pub fn init(gpa: std.mem.Allocator) Self {
    return .{
        .gpa = gpa,
        .blocks = .init(gpa),
    };
}

pub fn deinit(self: *Self) void {
    self.blocks.deinit();
}

pub fn load(self: *Self) !void {
    const level = [_][]const u8{
        "....................................................",
        "...........................####.....................",
        "######..............................................",
        "....................................................",
        ".....................................####...........",
        "....................................................",
        "..........................####......................",
        "....................................................",
        ".................####......................####.....",
        "....................................................",
        "....................................................",
        "..........##...#####....####....#####....####....###",
        "....................................................",
        "####################################################",
    };

    for (level, 0..) |row, y| {
        for (row, 0..) |tile, x| {
            if (tile != '#') continue;

            try self.blocks.append(.{
                .rect = .init(
                    @floatFromInt(x * 32),
                    @floatFromInt(y * 32),
                    32,
                    32,
                ),
            });
        }
    }

    self.soul = .{ .possessed = Possessed.init(&self.player) };
}

const gravity = 900;

pub fn update(self: *Self, dt: f32) !void {
    if (rl.isKeyDown(.q)) return self.close();

    try self.soul.update(dt);

    self.handle_movement(dt, &self.player.body);

    self.camera.target = .lerp(
        self.camera.target,
        self.player.body.getCenter(),
        8.0 * dt,
    );

    self.camera.offset = .init(WIDTH / 2, HEIGHT / 2);
}

fn handle_movement(self: *Self, dt: f32, body: *Body) void {
    body.rect.x = body.rect.x + body.velocity.x * dt;

    for (self.blocks.items) |block| {
        if (!rl.checkCollisionRecs(body.rect, block.rect)) continue;

        if (body.velocity.x > 0) {
            body.rect.x = block.rect.x - body.rect.width;
        } else if (body.velocity.x < 0) {
            body.rect.x = block.rect.x + block.rect.width;
        }

        body.velocity.x = 0;
    }

    // Vertical movement
    body.rect.y = body.rect.y + body.velocity.y * dt;
    body.grounded = false;

    for (self.blocks.items) |block| {
        if (!rl.checkCollisionRecs(body.rect, block.rect)) continue;

        if (body.velocity.y > 0) {
            body.rect.y = block.rect.y - body.rect.height;
            body.grounded = true;
        } else if (body.velocity.y < 0) {
            body.rect.y = block.rect.y + block.rect.height;
        }

        body.velocity.y = 0;
    }
}

pub fn draw(self: *const Self) !void {
    self.camera.begin();
    
    try self.soul.draw();

    for (self.blocks.items) |block| {
        rl.drawRectangleRec(block.rect, .yellow);
    }

    self.camera.end();

    const text = try std.fmt.allocPrintSentinel(
        self.gpa,
        "{d}FPS",
        .{ rl.getFPS() },
        0,
    );
    defer self.gpa.free(text);

    rl.drawText(text, 10, 10, 16, .white);
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

inline fn close(self: *Self) void {
    self.should_close = true;
}
