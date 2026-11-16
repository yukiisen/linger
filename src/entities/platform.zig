const rl = @import("raylib");
const Body = @import("entities.zig").Body;

pub const Block = struct {
    const Self = @This();
    body: Body,

    texture: rl.Texture,
    source: rl.Rectangle,

    pub fn init(x: f32, y: f32, texture: rl.Texture, source: rl.Rectangle) Self {
        return .{
            .body = .{ .rect = .init(x, y, source.width, source.height), .kind = .static },
            .texture = texture,
            .source = source,
        };
    }

    pub fn draw(self: *Self) void {
        rl.drawTextureRec(self.texture, self.source, .init(self.body.rect.x, self.body.rect.y), .white);
    }
};
