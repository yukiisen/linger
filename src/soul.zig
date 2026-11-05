const std = @import("std");
const rl = @import("raylib");

const Body = @import("entities.zig").Body;

pub const Possessed = struct {
    const Self = @This();

    ptr: *anyopaque,
    body: *Body,
    _update: *const fn(*anyopaque, f32) anyerror!void,
    _draw: *const fn(*const anyopaque) anyerror!void,
    _deinit: *const fn(*anyopaque) void,

    pub fn init(ptr: anytype) Self {
        const T = @typeInfo(@TypeOf(ptr)).pointer.child;
        if (!@hasDecl(T, "update")) @compileError("Type " ++ @typeName(T) ++ " has no method named update");
        if (!@hasDecl(T, "draw")) @compileError("Type " ++ @typeName(T) ++ " has no method named draw");
        if (!@hasField(T, "body")) @compileError("Type " ++ @typeName(T) ++ " has no field named body");

        return .{
            .ptr = ptr,
            .body = &@field(ptr, "body"),
            ._update = struct {
                fn f(p: *anyopaque, dt: f32) !void {
                    const self: *T = @alignCast(@ptrCast(p));
                    return T.update(self, dt);
                }
            }.f,
            ._draw = struct {
                fn f(p: *const anyopaque) !void {
                    const self: *const T = @alignCast(@ptrCast(p));
                    return T.draw(self);
                }
            }.f,
            ._deinit = struct {
                fn f(p: *anyopaque) void {
                    if (!@hasDecl(T, "deinit")) return;
                    const self: *T = @alignCast(@ptrCast(p));
                    return T.deinit(self);
                }
            }.f,
        };
    }

    pub fn update(self: *Self, dt: f32) !void {
        return self._update(self.ptr, dt);
    }

    pub fn draw(self: *const Self) !void {
        return self._draw(self.ptr);
    }

    pub fn deinit(self: *Self) void {
        return self._deinit(self.ptr);
    }
};

pub const Soul = struct {
    const Self = @This();
    rect: rl.Rectangle = .init(0, 0, 32, 32 * 2),
    velocity: rl.Vector2 = .zero(),
    acceleration: rl.Vector2 = .zero(),
    state: enum { attached, detached } = .attached,
    possessed: Possessed,

    const DETACH_BTN: rl.KeyboardKey = .o;
    const RADIUS = 32 * 4;

    const speed = 240;

    pub fn getCenter(self: *const Self) rl.Vector2 {
        return rl.Vector2.init(
            self.rect.x + self.rect.width / 2,
            self.rect.y + self.rect.height / 2,
        );
    }

    pub fn update(self: *Self, dt: f32) !void {
        if (self.state == .attached and rl.isKeyDown(DETACH_BTN)) {
            self.state = .detached;
            self.possessed.body.velocity = .zero();
            self.rect = self.possessed.body.rect;
        }

        if (self.state == .attached) return self.possessed.update(dt);

        const b_center = self.possessed.body.getCenter();
        const s_center = self.getCenter();

        const dx = s_center.x - b_center.x;
        const dy = s_center.y - b_center.y;

        const distance_sq = dx * dx + dy * dy;
        const radius_sq = RADIUS * RADIUS;

        if (distance_sq > radius_sq) {
            const scale = RADIUS / @sqrt(distance_sq);

            self.rect.x = b_center.x + dx * scale - self.rect.width / 2;
            self.rect.y = b_center.y + dy * scale - self.rect.height / 2;
        }

        if (rl.isKeyDown(.a)) self.velocity.x = -speed
        else if (rl.isKeyDown(.d)) self.velocity.x = speed
        else self.velocity.x = 0;

        if (rl.isKeyDown(.s)) self.velocity.y = speed
        else if ((rl.isKeyDown(.w) or rl.isKeyDown(.space))) self.velocity.y = -speed
        else self.velocity.y = 0;

        self.rect.x = self.rect.x + self.velocity.x * dt;
        self.rect.y = self.rect.y + self.velocity.y * dt;

        if (!rl.isKeyDown(DETACH_BTN)) {
            self.state = .attached;
            self.possessed.body.rect = self.rect;
        }

    }

    pub fn draw(self: *const Self) !void {
        try self.possessed.draw();

        if (self.state == .detached) {
            const center = self.possessed.body.getCenter();

            rl.drawRectangleRec(self.rect, .blue);
            rl.drawCircleV(center, RADIUS, .alpha(.white, 0.4));
        }
    }
};
