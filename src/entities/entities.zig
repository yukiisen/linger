const std = @import("std");
const rl = @import("raylib");

const soul = @import("../soul.zig");

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

    pub fn clear(self: *Self) void {
        for (self.entities) |*entity|
            entity.destroy();

        self._entities.clearRetainingCapacity();
        self._colliders.clearRetainingCapacity();
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


    pub fn handle_movement(self: *Self, dt: f32, body: *Body) void {
        body.velocity = body.velocity.add(body.acceleration.scale(dt));

        body.rect.x = body.rect.x + body.velocity.x * dt;

        const horizontal = self.queryColliders(body.rect);
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

        const vertical = self.queryColliders(body.rect);
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

};
