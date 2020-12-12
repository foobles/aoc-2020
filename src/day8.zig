const std = @import("std");
const file_util = @import("file_util.zig");
const parse = @import("parse.zig");

const mem = std.mem;

const ParseState = parse.ParseState;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const Solution = struct {
    final_reg: i32,
};

pub fn solve(alloc: *Allocator) !Solution {
    var inst_arr = ArrayList(State.Inst).init(alloc);
    defer inst_arr.deinit();

    var lines = try file_util.dayFileLines(alloc, 8, "prog.txt");
    while (try lines.next()) |line| {
        var state = ParseState{ .str = line };
        try inst_arr.append(try parseLine(&state));
    }

    var prog_state = State{ .insts = inst_arr.items };

    return Solution{
        .final_reg = try prog_state.run_until_loop(alloc),
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

    fn run_until_loop(self: *State, alloc: *Allocator) !i32 {
        var hit_insts = try alloc.alloc(bool, self.insts.len);
        defer alloc.free(hit_insts);

        mem.set(bool, hit_insts, false);
        while (!hit_insts[self.ip]) {
            hit_insts[self.ip] = true;
            self.step();
        } 
        return self.acc;
    }

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

    const Inst = struct {
        const Kind = enum { Nop, Jmp, Acc };
        kind: Kind,
        val: isize,
    };
};
