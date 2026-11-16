const std = @import("std");
const rl = @import("raylib");

const Soul = @import("../soul.zig").Soul;

const Self = @This();
ptr: *anyopaque,
gpa: std.mem.Allocator,
loadFn: *const fn(*anyopaque, io: std.Io) anyerror!void,
unloadFn: *const fn(*anyopaque) void,
updateFn: *const fn(*anyopaque, f32) anyerror!void,
drawFn: *const fn(*const anyopaque) anyerror!void,
deinitFn: *const fn(*anyopaque, std.mem.Allocator) void,

soul: *Soul,

pub fn init(v: anytype, gpa: std.mem.Allocator) !Self {
    const T = @TypeOf(v);
    if (@typeInfo(T) != .@"struct") @compileError(@typeName(T) ++ " is not a struct type");
    if (!@hasField(T, "soul")) @compileError("Type " ++ @typeName(T) ++ " has no field named soul");

    const ptr = try gpa.create(T);
    ptr.* = v;

    return .{
        .ptr = ptr,
        .gpa = gpa,
        .soul = &@field(ptr, "soul"),
        .loadFn = struct {
            fn f(p: *anyopaque, io: std.Io) !void {
                const self: *T = @alignCast(@ptrCast(p));
                if (@hasDecl(T, "load")) return T.load(self, io);
            }
        }.f,
        .unloadFn = struct {
            fn f(p: *anyopaque) void {
                const self: *T = @alignCast(@ptrCast(p));
                if (@hasDecl(T, "unload")) return T.unload(self);
            }
        }.f,
        .updateFn = struct {
            fn f(p: *anyopaque, dt: f32) !void {
                const self: *T = @alignCast(@ptrCast(p));
                if (@hasDecl(T, "update")) return T.update(self, dt);
            }
        }.f,
        .drawFn = struct {
            fn f(p: *const anyopaque) !void {
                const self: *const T = @alignCast(@ptrCast(p));
                if (@hasDecl(T, "draw")) return T.draw(self);
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

pub fn load(self: *Self, io: std.Io) !void {
    return self.loadFn(self.ptr, io);
}

pub fn unload(self: *Self) void {
    return self.unloadFn(self.ptr);
}

pub fn update(self: *Self, dt: f32) !void {
    return self.updateFn(self.ptr, dt);
}

pub fn draw(self: *const Self) !void {
    return self.drawFn(self.ptr);
}

pub fn deinit(self: *Self) void {
    return self.deinitFn(self.ptr, self.gpa);
}
