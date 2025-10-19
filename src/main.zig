const std = @import("std");
const pap = @import("performanceAwareProgramming");
const asm_decode = @import("asm_decode.zig");
const current = @import("current.zig");

const args_parser = @import("args.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const parsed = try args_parser.parseArgs(allocator);
    defer {
        if (parsed.input_file) |input| allocator.free(input);
        if (parsed.output_file) |output| allocator.free(output);
    }

    switch (parsed.command) {
        .decode => {
            if (parsed.input_file) |input| {
                try asm_decode.decodeASM(input);
            } else {
                std.debug.print("Error: -decode requires input file\n", .{});
            }
        },
        .main => {
            std.debug.print("Running main loop\n", .{});
            current.somefn();
        },
    }
}
