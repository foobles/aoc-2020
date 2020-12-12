const std = @import("std");
const file_util = @import("file_util.zig");
const parse = @import("parse.zig");

const mem = std.mem;

const ParseState = parse.ParseState;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const Solution = struct {
    final_reg_loop: i32,
    final_reg_uncorrupted: i32,
};

pub fn solve(alloc: *Allocator) !Solution {
    var inst_arr = ArrayList(State.Inst).init(alloc);
    defer inst_arr.deinit();

    var lines = try file_util.dayFileLines(alloc, 8, "prog.txt");
    defer lines.deinit();
    while (try lines.next()) |line| {
        var state = ParseState{ .str = line };
        try inst_arr.append(try parseLine(&state));
    }

    var prog_state = State{ .insts = inst_arr.items };

    const loop_result = try prog_state.run(alloc);
    const final_reg_uncorrupted = try prog_state.run_uncorrupted(alloc);

    return Solution{
        .final_reg_loop = loop_result.final_acc,
        .final_reg_uncorrupted = final_reg_uncorrupted,
    };
}

fn parseLine(state: *ParseState) !State.Inst {
    const name = ((try state.skipUntil(ParseState.expectChar, .{" "})) orelse return state.parseError(error.NoName)).skipped;
    const val = try state.signed(isize);
    return State.Inst{
        .val = val,
        .kind = if (mem.eql(u8, name, "nop"))
            State.Inst.Kind.Nop
        else if (mem.eql(u8, name, "acc"))
            State.Inst.Kind.Acc
        else if (mem.eql(u8, name, "jmp"))
            State.Inst.Kind.Jmp
        else
            return state.parseError(error.InvalidInstKind),
    };
}

const State = struct {
    ip: usize = 0,
    acc: i32 = 0,
    insts: []Inst,

    fn run_uncorrupted(self: *State, alloc: *Allocator) !i32 {
        const hit_insts = try alloc.alloc(bool, self.insts.len);
        defer alloc.free(hit_insts);

        for (self.insts) |*inst| {
            inst.flip();
            defer inst.flip();
            self.reset();
            const run_result = self.run_with_hit_list(hit_insts);
            if (run_result.finished) {
                return run_result.final_acc;
            }
        }
        return error.Unsalvageable;
    }

    fn run(self: *State, alloc: *Allocator) !RunResult {
        const hit_insts = try alloc.alloc(bool, self.insts.len);
        defer alloc.free(hit_insts);
        return self.run_with_hit_list(hit_insts);
    }

    fn run_with_hit_list(self: *State, hit_insts: []bool) RunResult {
        mem.set(bool, hit_insts, false);
        const finished = while (self.ip < self.insts.len) {
            if (hit_insts[self.ip])
                break false;
            hit_insts[self.ip] = true;
            self.step();
        } else true;
        return RunResult{
            .final_acc = self.acc,
            .finished = finished,
        };
    }

    const RunResult = struct {
        final_acc: i32,
        finished: bool,
    };

    fn step(self: *State) void {
        const cur = self.insts[self.ip];
        switch (cur.kind) {
            .Nop => {
                self.ip += 1;
            },
            .Jmp => {
                self.ip = @intCast(usize, @intCast(isize, self.ip) + cur.val);
            },
            .Acc => {
                self.acc += @intCast(i32, cur.val);
                self.ip += 1;
            },
        }
    }

    fn reset(self: *State) void {
        self.acc = 0;
        self.ip = 0;
    }

    const Inst = struct {
        fn flip(self: *Inst) void {
            self.kind = switch (self.kind) {
                .Nop => .Jmp,
                .Jmp => .Nop,
                .Acc => .Acc,
            };
        }

        const Kind = enum { Nop, Jmp, Acc };
        kind: Kind,
        val: isize,
    };
};
