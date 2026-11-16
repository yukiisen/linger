const std = @import("std");
const rl = @import("raylib");

const Body = @import("entities/entities.zig").Body;
const Entity = @import("entities/entities.zig").Entity;

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

    pub fn update(self: *Self, entities: []Entity, dt: f32) !void {
        if (self.state == .attached and rl.isKeyDown(DETACH_BTN)) {
            self.state = .detached;
            self.possessed.body.velocity = .zero();
            self.rect = self.possessed.body.rect;
            self.possessed.body.acceleration.y = self.possessed.body.acceleration.y / 2;
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
            self.possessed.body.acceleration.y = self.possessed.body.acceleration.y * 2;

            for (entities) |*entity| {
                if (rl.checkCollisionCircleRec(self.getCenter(), 32, entity.body.rect)) {
                    if (entity.getPossessed()) |possessed| {
                        self.possessed = possessed;
                        break;
                    }
                }
            }
        }
    }

    pub fn draw(self: *const Self) !void {
        if (self.state == .detached) {
            const center = self.possessed.body.getCenter();

            rl.drawRectangleRec(self.rect, .blue);
            rl.drawCircleV(center, RADIUS, .alpha(.white, 0.4));
        }
    }
};

pub const Possessed = struct {
    const Self = @This();

    ptr: *anyopaque,
    body: *Body,
    updateFn: *const fn(*anyopaque, f32) anyerror!void,

    pub fn init(ptr: anytype) Self {
        const T = @typeInfo(@TypeOf(ptr)).pointer.child;
        if (!@hasField(T, "body")) @compileError("Type " ++ @typeName(T) ++ " has no field named body");
        if (!@hasDecl(T, "pupdate")) @compileError("Type " ++ @typeName(T) ++ " has no member named pupdate");

        return .{
            .ptr = ptr,
            .body = &@field(ptr, "body"),
            .updateFn = struct {
                fn f(p: *anyopaque, dt: f32) !void {
                    const self: *T = @alignCast(@ptrCast(p));
                    return T.pupdate(self, dt);
                }
            }.f,
        };
    }

    pub fn update(self: *Self, dt: f32) !void {
        return self.updateFn(self.ptr, dt);
    }
};

