const std = @import("std");
const rl = @import("raylib");

const soul = @import("soul.zig");

pub const Body = struct {
    const Self = @This();

    pub const BodyType = enum {
        static,
        dynamic,
        kinematic,
    };

    rect: rl.Rectangle = .init(0, 0, 32, 32 * 2),
    velocity: rl.Vector2 = .zero(),
    acceleration: rl.Vector2 = .zero(),
    kind: BodyType,
    grounded: bool = false,

    pub fn getCenter(body: *const Self) rl.Vector2 {
        return .init(
            body.rect.x + body.rect.width / 2,
            body.rect.y + body.rect.height / 2,
        );
    }
};

pub const EntityPool = struct {
    const Self = @This();

    _entities: std.ArrayList(Entity) = .empty,
    _colliders: std.ArrayList(Entity) = .empty,

    gpa: std.mem.Allocator,
    entities: []Entity = &.{},
    colliders: []Entity = &.{},

    overlaps: std.ArrayList(rl.Rectangle) = .empty,

    pub fn init(gpa: std.mem.Allocator) Self {
        return .{ 
            .gpa = gpa,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.entities) |*entity|
            entity.destroy();

        self._entities.deinit(self.gpa);
        self._colliders.deinit(self.gpa);

        self.overlaps.deinit(self.gpa);
    }

    pub fn queryColliders(self: *Self, rect: rl.Rectangle) []const rl.Rectangle {
        self.overlaps.clearRetainingCapacity();
        for (self.colliders) |c| {
            if (rl.checkCollisionRecs(c.body.rect, rect)) 
                self.overlaps.append(self.gpa, c.body.rect) catch {};
        }

        return self.overlaps.items;
    }

    pub fn spawnCollider(self: *Self, comptime T: type, val: T) !void {
        try self.spawn(T, val);
        
        const collider = self.entities[self.entities.len - 1];

        try self._colliders.append(self.gpa, collider);
        self.colliders = self._colliders.items;
    }

    pub fn spawn(self: *Self, comptime T: type, val: T) !void {
        const ptr = try self.gpa.create(T);
        errdefer self.gpa.destroy(ptr);

        ptr.* = val;

        const entity = Entity.create(self.gpa, ptr);
        try self._entities.append(self.gpa, entity);
        self.entities = self._entities.items;
    }

    pub fn despawn(self: *Self, entity: Entity) void {
        for (self.entities, 0..) |target, i| {
            if (target.ptr == entity.ptr) self._entities.swapRemove(i);
        }

        for (self.colliders, 0..) |target, i| {
            if (target.ptr == entity.ptr) self._colliders.swapRemove(i);
        }

        entity.destroy();
    }
};

pub const Entity = struct {
    const Self = @This();

    ptr: *anyopaque,
    gpa: std.mem.Allocator,
    body: *Body,
    updateFn: *const fn(*anyopaque, f32) anyerror!void,
    drawFn: *const fn(*anyopaque) anyerror!void,
    possessedFn: *const fn(*anyopaque) ?soul.Possessed,
    deinitFn: *const fn(*anyopaque, std.mem.Allocator) void,

    pub fn create(gpa: std.mem.Allocator, ptr: anytype) Self {
        const T = @typeInfo(@TypeOf(ptr)).pointer.child;
        if (@typeInfo(T) != .@"struct") @compileError(@typeName(T) ++ " is not a struct type");
        if (!@hasField(T, "body")) @compileError("Type " ++ @typeName(T) ++ " has no field named body");

        return .{
            .ptr = ptr,
            .gpa = gpa,
            .body = &@field(ptr, "body"),
            .updateFn = struct {
                fn f(p: *anyopaque, dt: f32) !void {
                    const self: *T = @alignCast(@ptrCast(p));
                    if (@hasDecl(T, "update")) return T.update(self, dt);
                }
            }.f,
            .drawFn = struct {
                fn f(p: *anyopaque) !void {
                    const self: *T = @alignCast(@ptrCast(p));
                    if (@hasDecl(T, "draw")) return T.draw(self);
                }
            }.f,
            .possessedFn = struct {
                fn f(p: *anyopaque) ?soul.Possessed {
                    const self: *T = @alignCast(@ptrCast(p));
                    if (@hasDecl(T, "getPossessed")) return T.getPossessed(self)
                    else return null;
                }
            }.f,
            .deinitFn = struct {
                fn f(p: *anyopaque, allocator: std.mem.Allocator) void {
                    const self: *T = @alignCast(@ptrCast(p));
                    if (@hasDecl(T, "deinit")) T.deinit(self);
                    allocator.destroy(self);
                }
            }.f,
        };
    }

    pub fn update(self: *Self, dt: f32) !void {
        try self.updateFn(self.ptr, dt);
    }

    pub fn draw(self: *Self) !void {
        try self.drawFn(self.ptr);
    }

    pub fn getPossessed(self: *Self) ?soul.Possessed {
        return self.possessedFn(self.ptr);
    }

    pub fn destroy(self: *Self) void {
        self.deinitFn(self.ptr, self.gpa);
    }
};

pub const Player = struct {
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
};

pub const Block = struct {
    const Self = @This();
    body: Body,

    pub fn init(x: f32, y: f32, w: f32, h: f32) Self {
        return .{
            .body = .{ .rect = .init(x, y, w, h), .kind = .static }
        };
    }

    pub fn draw(self: *Self) void {
        rl.drawRectangleRec(self.body.rect, .yellow);
    }
};
