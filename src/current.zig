const std = @import("std");

pub fn somefn() void {
    const a: u8 = 64;
    const b: f32 = @as(f32, @floatFromInt(a)) * 2.22;
    std.debug.print("b = {d}\n", .{b});
}
