const std = @import("std");
const rl = @import("raylib");

const Body = @import("entities.zig").Body;
const Block = @import("entities.zig").Block;
const Player = @import("entities.zig").Player;
const Entity = @import("entities.zig").Entity;
const EntityPool = @import("entities.zig").EntityPool;
const Soul = @import("soul.zig").Soul;
const Possessed = @import("soul.zig").Possessed;

const Self = @This();

pub const WIDTH = 640;
pub const HEIGHT = 360;

gpa: std.mem.Allocator,
soul: Soul = undefined,
world: EntityPool,
camera: rl.Camera2D = .{
    .offset = .zero(),
    .target = .zero(),
    .rotation = 0,
    .zoom = 1,
},

pub fn init(gpa: std.mem.Allocator) Self {
    return .{
        .gpa = gpa,
        .world = .init(gpa),
    };
}

pub fn deinit(self: *Self) void {
    self.world.deinit();
}

pub fn load(self: *Self) !void {
    try self.world.spawn(Player, .spawn(10, 0, .red));
    try self.world.spawn(Player, .spawn(10, 4, .pink));
    self.soul = .{ .possessed = self.world.entities[0].getPossessed().? };

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

            try self.world.spawnCollider(Block, .init(
                @floatFromInt(x * 32),
                @floatFromInt(y * 32),
                32,
                32,
            ));
        }
    }
}

pub fn update(self: *Self, dt: f32) !void {
    try self.soul.update(self.world.entities, dt);

    for (self.world.entities) |*entity| {
        try entity.update(dt);

        if (entity.body.kind != .static) 
            self.handle_movement(dt, entity.body);
    }

    self.camera.target = .lerp(
        self.camera.target,
        self.soul.possessed.body.getCenter(),
        8.0 * dt,
    );

    self.camera.offset = .init(WIDTH / 2, HEIGHT / 2);
}

fn handle_movement(self: *Self, dt: f32, body: *Body) void {
    body.velocity = body.velocity.add(body.acceleration.scale(dt));

    body.rect.x = body.rect.x + body.velocity.x * dt;

    const horizontal = self.world.queryColliders(body.rect);
    for (horizontal) |block| {
        if (body.velocity.x > 0)
            body.rect.x = block.x - body.rect.width
        else if (body.velocity.x < 0)
            body.rect.x = block.x + block.width;

        body.velocity.x = 0;
    }

    // Vertical movement
    body.rect.y = body.rect.y + body.velocity.y * dt;
    body.grounded = false;

    const vertical = self.world.queryColliders(body.rect);
    for (vertical) |block| {
        if (body.velocity.y > 0) {
            body.rect.y = block.y - body.rect.height;
            body.grounded = true;
        } else if (body.velocity.y < 0) {
            body.rect.y = block.y + block.height;
        }

        body.velocity.y = 0;
    }
}

pub fn draw(self: *const Self) !void {
    self.camera.begin();
    
    for (self.world.entities) |*entity| {
        try entity.draw();
    }

    try self.soul.draw();

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
