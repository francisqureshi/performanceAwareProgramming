const std = @import("std");
const pap = @import("performanceAwareProgramming");

pub fn homeworkOne(filepath: []const u8) !void {
    const filename = std.fs.path.basename(filepath);
    const file = try std.fs.openFileAbsolute(filepath, .{ .mode = .read_only });
    defer file.close();

    const file_stat = try file.stat();

    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const full_path = try std.fs.realpath(filepath, &buf);

    std.debug.print("File: {s}\n", .{filename});
    std.debug.print("Size: {} bytes\n", .{file_stat.size});
    std.debug.print("Full path: {s}\n", .{full_path});
    std.debug.print("\n--- File Contents ---\n", .{});

    var file_read_buffer: [1024]u8 = undefined;

    var stdout_buffer: [1024]u8 = undefined;

    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    var reader = file.reader(&file_read_buffer);

    // Write ASM header
    try stdout.writeAll("; ========================================================================\n");
    try stdout.writeAll(";\n; fq 8086 ASM decoder...\n;\n");
    try stdout.print("; {s}.asm\n", .{filename});
    try stdout.writeAll("; ========================================================================\n\n");
    try stdout.writeAll("bits 16\n\n");

    // 8086 2 byte insrtuction
    // OpCode Byte (1)
    // | OpCode | D | W |
    //     6  +  1 + 1
    const OpCodeByte = enum(u6) {
        mov = 0b100010,
        add = 0b000000,
        sub = 0b001010,
        cmp = 0b001110,
        and_op = 0b001000,
        or_op = 0b000010,
        _,
    };

    const direction_bit = enum(u1) { source_is_reg = 0b0, destination_is_reg = 0b1 };
    const word_byte_bit = enum(u1) { byte_op = 0b0, word_op = 0b1 };

    // // Operand Byte (2)
    // // | Mod | Reg | Reg/Mem |
    // //    2  + 3  +   3
    const MOD_byte = enum(u2) { reg_mode = 0b11 };
    const REG_byte = enum(u3) { al = 0b000, cl = 0b001, dl = 0b010, bl = 0b011, ah = 0b100, ch = 0b101, dh = 0b110, bh = 0b111 };
    const REG_word = enum(u3) { ax = 0b000, cx = 0b001, dx = 0b010, bx = 0b011, sp = 0b100, bp = 0b101, si = 0b110, di = 0b111 };
    //
    //

    var byte_count: usize = 0;

    while (true) {
        // Fill buffer and get what's available
        reader.interface.fillMore() catch |err| {
            if (err == error.EndOfStream) break;
            return err;
        };
        const u8_chunk = reader.interface.buffered();
        if (u8_chunk.len == 0) break;

        // Process bytes in pairs (2-byte instructions)
        // will have to considor a switch when dealing with flagged 2+ byte memeory instructions.
        var i: usize = 0;
        while (i + 1 < u8_chunk.len) : (i += 2) {
            const opcode_byte = u8_chunk[i];
            const operand_byte = u8_chunk[i + 1];

            // Decode opcode byte
            const opcode = opcode_byte >> 2;
            const d_bit = (opcode_byte >> 1) & 0b1;
            const w_bit = opcode_byte & 0b1;

            const op_asm: OpCodeByte = @enumFromInt(opcode);
            const d_flag: direction_bit = @enumFromInt(d_bit);
            const w_flag: word_byte_bit = @enumFromInt(w_bit);

            std.debug.print("OpCode  : {b:0>8}", .{opcode_byte});
            std.debug.print(" -> {t}", .{op_asm});
            std.debug.print(", {t}", .{d_flag});
            std.debug.print(", {t}", .{w_flag});

            // Decode operand byte
            const mod = operand_byte >> 6;
            const reg = (operand_byte >> 3) & 0b111;
            const rm = operand_byte & 0b111;

            const mod_flag: MOD_byte = @enumFromInt(mod);

            std.debug.print(" | Operand: {b:0>8}", .{operand_byte});
            std.debug.print(" -> {t}", .{mod_flag});

            // Use w_bit to decide which register enum to use
            if (w_flag == .word_op) {
                const reg_asm: REG_word = @enumFromInt(reg);
                const rm_asm: REG_word = @enumFromInt(rm);

                // Use d_bit to determine operand order
                if (d_flag == .destination_is_reg) {
                    std.debug.print(" {t}, {t}\n", .{ reg_asm, rm_asm });
                    try stdout.print("{t} {t}, {t}\n", .{ op_asm, reg_asm, rm_asm });
                } else {
                    std.debug.print(" {t}, {t}\n", .{ rm_asm, reg_asm });
                    try stdout.print("{t} {t}, {t}\n", .{ op_asm, rm_asm, reg_asm });
                }
            } else {
                const reg_asm: REG_byte = @enumFromInt(reg);
                const rm_asm: REG_byte = @enumFromInt(rm);

                // Use d_bit to determine operand order
                if (d_flag == .destination_is_reg) {
                    std.debug.print(" {t}, {t}\n", .{ reg_asm, rm_asm });
                    try stdout.print("{t} {t}, {t}\n", .{ op_asm, reg_asm, rm_asm });
                } else {
                    std.debug.print(" {t}, {t}\n", .{ rm_asm, reg_asm });
                    try stdout.print("{t} {t}, {t}\n", .{ op_asm, rm_asm, reg_asm });
                }
            }

            byte_count += 2;
        }
        reader.interface.tossBuffered();
    }
    if (byte_count % 8 != 0) {
        try stdout.writeAll("\n");
    }
    try stdout.flush();
}
