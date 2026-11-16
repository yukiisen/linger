const std = @import("std");
const rl = @import("raylib");

var isInitialized = false;
var textures: std.StringHashMapUnmanaged(rl.Texture) = .empty;
var gpa: std.mem.Allocator = undefined;

pub fn init(allocator: std.mem.Allocator) void {
    gpa = allocator;
    isInitialized = true;
}

pub fn deinit() void {
    if (!isInitialized) return;

    var it = textures.valueIterator();
    while (it.next()) |tex| {
        tex.unload();
    }
    
    textures.deinit(gpa);
    textures = .empty;
    isInitialized = false;
}

/// *Asserts* that the texture exists.
pub fn get(name: []const u8) rl.Texture {
    return textures.get(name) orelse std.debug.panic("Texture not found: {s}", .{ name });
}

pub fn put(name: []const u8, tex: rl.Texture) !void {
    if (!isInitialized) return error.LibraryUninitialized;
    try textures.put(gpa, name, tex);
}

pub fn loadTexture(file: []const u8, key: []const u8) !void {
    if (!isInitialized) return error.LibraryUninitialized;

    const filename = try gpa.allocSentinel(u8, file.len, 0);
    defer gpa.free(filename);
    @memcpy(filename, file);

    const tex = try rl.loadTexture(filename);
    try put(key, tex);
}
