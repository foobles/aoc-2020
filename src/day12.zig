const std = @import("std");
const file_util = @import("file_util.zig");

const Allocator = std.mem.Allocator;

pub const Solution = struct {
    simple_distance: u32,
    true_distance: u32,
};

pub fn solve(alloc: *Allocator) !Solution {
    var simple_state = State{};
    var true_state = State{ .angle = .{ .x = 10, .y = 1 } };

    var lines = try file_util.dayFileLines(alloc, 12, "steps.txt");
    defer lines.deinit();
    while (try lines.next()) |line| {
        const step = Step{
            .magnitude = try std.fmt.parseUnsigned(i32, line[1..], 10),
            .kind = switch (line[0]) {
                'N' => .North,
                'E' => .East,
                'S' => .South,
                'W' => .West,
                'F' => .Forward,
                'L' => .Left,
                'R' => .Right,
                else => return error.InvalidInstruction,
            },
        };

        simple_state.runSimpleStep(step);
        true_state.runTrueStep(step);
    }

    return Solution{
        .simple_distance = simple_state.manhattan(),
        .true_distance = true_state.manhattan(),
    };
}

const Step = struct {
    magnitude: i32,
    kind: enum { North, East, South, West, Forward, Left, Right },
};

const State = struct {
    pos: Vec2 = .{ .x = 0, .y = 0 },
    angle: Vec2 = .{ .x = 1, .y = 0 },

    fn runSimpleStep(self: *State, step: Step) void {
        switch (step.kind) {
            .North => {
                self.pos.y += step.magnitude;
            },
            .East => {
                self.pos.x += step.magnitude;
            },
            .South => {
                self.pos.y -= step.magnitude;
            },
            .West => {
                self.pos.x -= step.magnitude;
            },
            .Forward => {
                self.pos = self.pos.add(self.angle.mulScalar(step.magnitude));
            },
            .Left => {
                self.angle = self.angle.mulComplex(Vec2.fromAngle(step.magnitude));
            },
            .Right => {
                self.angle = self.angle.mulComplex(Vec2.fromAngle(-step.magnitude));
            },
        }
    }

    fn runTrueStep(self: *State, step: Step) void {
        switch (step.kind) {
            .North => self.angle.y += step.magnitude,
            .East => self.angle.x += step.magnitude,
            .South => self.angle.y -= step.magnitude,
            .West => self.angle.x -= step.magnitude,
            .Forward => self.pos = self.pos.add(self.angle.mulScalar(step.magnitude)),
            .Left => self.angle = self.angle.mulComplex(Vec2.fromAngle(step.magnitude)),
            .Right => self.angle = self.angle.mulComplex(Vec2.fromAngle(-step.magnitude)),
        }
    }

    fn manhattan(self: State) u32 {
        return std.math.absCast(self.pos.x) + std.math.absCast(self.pos.y);
    }
};

const Vec2 = struct {
    x: i32,
    y: i32,

    fn mulScalar(self: Vec2, s: i32) Vec2 {
        return .{
            .x = self.x * s,
            .y = self.y * s,
        };
    }

    fn add(self: Vec2, other: Vec2) Vec2 {
        return .{
            .x = self.x + other.x,
            .y = self.y + other.y,
        };
    }

    fn mulComplex(self: Vec2, other: Vec2) Vec2 {
        const x = (self.x * other.x) - (self.y * other.y);
        const y = (self.y * other.x) + (self.x * other.y);
        return .{
            .x = x,
            .y = y,
        };
    }

    fn fromAngle(degrees: i32) Vec2 {
        return switch (@mod(degrees, 360)) {
            0 => .{ .x = 1, .y = 0 },
            90 => .{ .x = 0, .y = 1 },
            180 => .{ .x = -1, .y = 0 },
            270 => .{ .x = 0, .y = -1 },
            else => unreachable,
        };
    }
};
