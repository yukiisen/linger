const std = @import("std");
const textures = @import("textures.zig");
const rl = @import("raylib");

const EntityPool = @import("../entities/entities.zig").EntityPool;
const Block = @import("../entities/platform.zig").Block;

pub fn loadTilemap(path: []const u8, io: std.Io, gpa: std.mem.Allocator) !std.json.Parsed(Map) {
    const file = try std.Io.Dir.cwd().openFile(io, path, .{ .mode = .read_only });
    defer file.close(io);
    
    const stat = try file.stat(io);
    const buffer = try gpa.alloc(u8, stat.size);
    defer gpa.free(buffer);
    _ = try file.readPositionalAll(io, buffer, 0);

    const map = try std.json.parseFromSlice(Map, gpa, buffer, .{ 
        .ignore_unknown_fields = true,
        .allocate = .alloc_always
    });

    for (map.value.tilesets) |tileset| {
        const image = try std.fmt.allocPrintSentinel(gpa, "assets/{s}", .{ tileset.image }, 0);
        defer gpa.free(image);

        const tex = try rl.loadTexture(image);
        try textures.put(tileset.image, tex);
    }

    return map;
}

pub fn parseTilemapLayers(map: *const Map, world: *EntityPool) !void {
    for (map.layers) |layer| {
        for (0..layer.width) |x| {
            for (0..layer.height) |y| {
                const gid = layer.gidAt(x, y) orelse continue;
                if (gid == 0) continue;

                const tileset = map.findTileset(gid) orelse continue;
                const idx = gid - tileset.firstgid;

                const tile_x = idx % tileset.columns;
                const tile_y = idx / tileset.columns;

                const source = rl.Rectangle {
                    .x = @floatFromInt(tile_x * tileset.tilewidth),
                    .y = @floatFromInt(tile_y * tileset.tileheight),
                    .width = @floatFromInt(tileset.tilewidth),
                    .height = @floatFromInt(tileset.tileheight),
                };

                try world.spawnCollider(Block, .init(
                    @floatFromInt(x * map.tilewidth),
                    @floatFromInt(y * map.tileheight),
                    textures.get(tileset.image),
                    source
                ));
            }
        }
    }
}

pub const Map = struct {
    width: u32,
    height: u32,
    tilewidth: u32,
    tileheight: u32,
    layers: []const Layer,
    tilesets: []const Tileset,

    pub fn findTileset(self: Map, gid: u32) ?*const Tileset {
        for (self.tilesets) |*tileset| {
            if (gid >= tileset.firstgid and
                gid < tileset.firstgid + tileset.tilecount)
            {
                return tileset;
            }
        }

        return null;
    }
};

pub const Layer = struct {
    name: []const u8,
    width: u32,
    height: u32,

    /// Row-major tile GIDs; 0 means an empty cell.
    data: []const u32,

    pub fn gidAt(layer: Layer, x_pos: usize, y_pos: usize) ?u32 {
        if (x_pos >= layer.width or y_pos >= layer.height) return null;

        const index = y_pos * layer.width + x_pos;
        if (index >= layer.data.len) return null;

        const gid = layer.data[index];
        return if (gid == 0) null else gid;
    }
};

/// A tileset is either embedded in the map or referenced by `source`.
/// The reference form only contains `firstgid` and `source`.
pub const Tileset = struct {
    firstgid: u32 = 1,
    image: []const u8 = &.{},
    tilewidth: u32 = 0,
    tileheight: u32 = 0,
    tilecount: u32 = 0,
    columns: u32 = 0,
    margin: u32 = 0,
    spacing: u32 = 0,
};
