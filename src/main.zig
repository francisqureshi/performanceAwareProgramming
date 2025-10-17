const std = @import("std");
const pap = @import("performanceAwareProgramming");

const listing_037 = @import("listing_0037_single_register_mov.zig");

pub fn main() !void {
    // Prints to stderr, ignoring potential errors.
    // std.debug.print("Haversine Distance Problem\n", .{});

    // const test_data_file_path = "/Users/fq/Zig/performance_aware_programming/performanceAwareProgramming/data/someTest.txt";
    const asm_in = "/Users/fq/Zig/performance_aware_programming/computer_enhance-main/perfaware/part1/listing_0037_single_register_mov";
    // const filepath = try std.fs.cwd().openDir("data", .{});
    // _ = try importData(asm_in);
    _ = try listing_037.homeworkOne(asm_in);
}
