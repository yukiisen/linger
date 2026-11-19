const std = @import("std");
const rl = @import("raylib");

pub const Animation = struct {
    name: []const u8,
    texture: rl.Texture,
    frame_duration: f32,
    offset: rl.Vector2,

    current_frame: usize = 0,
    timer: f32 = 0,
    repeats: i32 = 1,

    frames: []const Frame,

    pub fn tick(self: *Animation, dt: f32) void {
        if (self.repeats == 0) return;

        self.timer += dt;

        while (self.timer >= self.frame_duration) {
            self.timer -= self.frame_duration;
            self.current_frame += 1;

            if (self.current_frame >= self.frames.len) {
                if (self.repeats > 0) self.repeats -= 1;

                if (self.repeats == 0) {
                    self.current_frame = self.frames.len - 1;
                    self.timer = 0;
                    return;
                }

                self.current_frame = 0;
            }
        }

    }

    pub fn getSource(self: *const Animation) rl.Rectangle {
        return self.frames[self.current_frame].source;
    }

    pub fn reset(self: *Animation) void {
        self.current_frame = 0;
        self.repeats = 0;
        self.timer = 0;
    }
};

pub const Frame = struct {
    source: rl.Rectangle,
    offset: rl.Vector2 = .zero(),
    duration: ?f32 = null,
};

pub const AnimationPlayer = struct {
    const Self = @This();

    gpa: std.mem.Allocator,
    anims: std.StringHashMap(Animation),
    queue: std.Deque(Animation) = .empty,
    active: ?Animation = null,

    pub fn init(gpa: std.mem.Allocator) Self {
        return .{ 
            .gpa = gpa,
            .anims = .init(gpa),
        };
    }

    pub fn tick(self: *Self, dt: f32) void {
        if (self.active) |*active| {
            active.tick(dt);

            if (active.repeats == 0) {
                self.active = self.queue.popFront();
            }
        }
    }

    pub fn play(self: *Self, name: []const u8) void {
        while (self.queue.popFront()) |_| {}
        if (self.active) |active| if (std.mem.eql(u8, active.name, name)) return;
        self.active = self.anims.get(name);
    }

    pub fn playNext(self: *Self, name: []const u8) void {
        self.queue.pushBack(self.gpa, self.anims.get(name).?) catch {};
    }

    pub fn create(self: *Self, name: []const u8, config: AnimationConfig) !void {
        const count = config.end - config.start;

        const frames = try self.gpa.alloc(Frame, count);
        errdefer self.gpa.free(frames);

        const width: f32 = @floatFromInt(config.tex.width);
        const columns = @as(u32, @intFromFloat(
            (width - config.margin.x - config.margin.z + config.padding.x) /
            (config.frame_width + config.padding.x),
        ));

        for (frames, config.start..) |*frame, i| {
            const column = i % columns;
            const row = i / columns;

            frame.* = .{
                .source = .{
                    .x = config.margin.x + @as(f32, @floatFromInt(column)) *
                        (config.frame_width + config.padding.x),
                    .y = config.margin.y + @as(f32, @floatFromInt(row)) *
                        (config.frame_height + config.padding.y),
                    .width = config.frame_width,
                    .height = config.frame_height,
                },
            };
        }

        const anim = Animation {
            .name = name,
            .texture = config.tex,
            .frame_duration = config.frame_duration,
            .frames = frames,
            .repeats = config.repeat,
            .offset = config.offset,
        };

        try self.anims.put(name, anim);
    }

    pub fn draw(self: *const Self, pos: rl.Vector2, flip: bool) void {
        if (self.active) |active| {
            var src = active.getSource();
            if (flip) src.width = -src.width;
            rl.drawTextureRec(active.texture, src, pos.subtract(.init(@abs(src.width / 2), src.height / 2)), .white);
        }
    }

    pub fn deinit(self: *Self) void {
        var it = self.anims.valueIterator();

        while (it.next()) |anim| {
            self.gpa.free(anim.frames);
        }

        self.anims.deinit();
        self.queue.deinit(self.gpa);
    }
};

pub const AnimationConfig = struct {
    frame_width: f32,
    frame_height: f32,
    frame_duration: f32,
    start: u32, 
    end: u32,
    repeat: i32 = -1,

    tex: rl.Texture,

    offset: rl.Vector2 = .zero(),
    padding: rl.Vector2 = .zero(),
    margin: rl.Vector4 = .zero(),
};
