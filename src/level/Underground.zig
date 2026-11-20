const std = @import("std");
const rl = @import("raylib");

const Soul = @import("../soul.zig").Soul;
const EntityPool = @import("../entities/entities.zig").EntityPool;

const Ruby = @import("../entities/ruby.zig");
const Block = @import("../entities/platform.zig").Block;

const tiled = @import("../res/tiled.zig");
const textures = @import("../res/textures.zig");

const conf = @import("../config.zig");

const Self = @This();
gpa: std.mem.Allocator,
world: EntityPool,
soul: Soul = undefined,

pub fn init(gpa: std.mem.Allocator) Self {
    return .{
        .gpa = gpa,
        .world = .init(gpa),
    };
}

pub fn deinit(self: *Self) void {
    self.world.deinit();
}

pub fn unload(self: *Self) void {
    self.world.clear();
}

pub fn load(self: *Self, io: std.Io) !void {
    try textures.loadTexture("assets/itch/idle.png", "ruby_idle");
    try textures.loadTexture("assets/itch/jump.png", "ruby_jump");
    try textures.loadTexture("assets/itch/run.png", "ruby_run");

    try self.world.spawn(Ruby, try .spawn(self.gpa, 10, 0));
    try self.world.spawn(Ruby, try .spawn(self.gpa, 10, 4));
    self.soul = .{ .possessed = self.world.entities[1].getPossessed().? };

    const map = try tiled.loadTilemap("levels/Map.json", io, self.gpa);
    defer map.deinit();

    try tiled.parseTilemapLayers(&map.value, &self.world);
}

pub fn update(self: *Self, dt: f32) !void {
    try self.soul.update(self.world.entities, dt);

    for (self.world.entities) |*entity| {
        try entity.update(dt);

        if (entity.body.kind != .static) 
            self.world.handle_movement(dt, entity.body);
    }
}

pub fn draw(self: *const Self) !void {
    for (self.world.entities) |*entity| {
        try entity.draw();
    }

    if (conf.DebugBodies) self.world.drawDebug();

    try self.soul.draw();
}
