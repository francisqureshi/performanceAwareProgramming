const std = @import("std");
const pap = @import("performanceAwareProgramming");

// Packed structs for instruction decoding
const MovOpcode = packed struct(u8) {
    w: u1,
    d: u1,
    opcode: u6,
};

const ModRegRM = packed struct(u8) {
    rm: u3,
    reg: u3,
    mod: u2,
};

const ImmToReg = packed struct(u8) {
    reg: u3,
    w: u1,
    opcode: u4,
};

pub fn decodeASM(filepath: []const u8) !void {
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

    // Register name lookup tables
    const reg_w0 = [_][]const u8{ "al", "cl", "dl", "bl", "ah", "ch", "dh", "bh" };
    const reg_w1 = [_][]const u8{ "ax", "cx", "dx", "bx", "sp", "bp", "si", "di" };

    // Effective address base by R/M field
    const eff_addr_base = [_][]const u8{
        "bx + si",
        "bx + di",
        "bp + si",
        "bp + di",
        "si",
        "di",
        "bp",
        "bx",
    };

    // Instruction format types
    const InstructionFormat = enum {
        immediate_to_reg, // 1011wreg + data
        immediate_to_reg_mem, // 1100011w mod 000 r/m + data
        reg_mem_to_from_reg, // 100010dw mod reg r/m (standard format)
        mem_to_accum, // 1010000w + addr
        accum_to_mem, // 1010001w + addr
    };

    var byte_count: usize = 0;

    // Peek and decode instructions
    while (true) {
        // Peek first 2 bytes to decode and determine instruction length
        const initial_peek = reader.interface.peek(2) catch |err| {
            if (err == error.EndOfStream) break;
            return err;
        };

        // Decode opcode byte (byte 0)
        const opcode_byte = initial_peek[0];

        // Detect instruction format based on opcode pattern
        const format: InstructionFormat = blk: {
            const opcode_top_4_bits = opcode_byte >> 4;
            const opcode_top_7_bits = opcode_byte >> 1;

            if (opcode_top_4_bits == 0b1011) break :blk .immediate_to_reg;
            if (opcode_top_7_bits == 0b1100011) break :blk .immediate_to_reg_mem;
            if (opcode_top_7_bits == 0b1010000) break :blk .mem_to_accum;
            if (opcode_top_7_bits == 0b1010001) break :blk .accum_to_mem;

            // Default to standard reg/mem format
            break :blk .reg_mem_to_from_reg;
        };

        std.debug.print("Instruction format: {t}\n", .{format});

        // Switch on instruction format
        switch (format) {
            .immediate_to_reg => {
                // Format: 1011wreg + data (1 or 2 bytes)
                const imm_to_reg: ImmToReg = @bitCast(opcode_byte);

                // Determine instruction length
                const instr_len: usize = if (imm_to_reg.w == 1) 3 else 2;

                // Peek full instruction
                const instruction = reader.interface.peek(instr_len) catch |err| {
                    if (err == error.EndOfStream) break;
                    return err;
                };

                std.debug.print("Immediate to register MOV | InstrLen: {}\n", .{instr_len});

                // Decode and print based on word/byte
                if (imm_to_reg.w == 1) {
                    const data_low = instruction[1];
                    const data_high = instruction[2];
                    const data: i16 = @bitCast(@as(u16, data_low) | (@as(u16, data_high) << 8));

                    std.debug.print("mov {s}, {}\n", .{ reg_w1[imm_to_reg.reg], data });
                    try stdout.print("mov {s}, {}\n", .{ reg_w1[imm_to_reg.reg], data });
                } else {
                    const data: i8 = @bitCast(instruction[1]);

                    std.debug.print("mov {s}, {}\n", .{ reg_w0[imm_to_reg.reg], data });
                    try stdout.print("mov {s}, {}\n", .{ reg_w0[imm_to_reg.reg], data });
                }

                byte_count += instr_len;
                reader.interface.toss(instr_len);
            },
            .immediate_to_reg_mem => {
                std.debug.print("TODO: Immediate to reg/mem MOV\n", .{});
                byte_count += 2;
                reader.interface.toss(2);
                continue;
            },
            .mem_to_accum, .accum_to_mem => {
                std.debug.print("TODO: Accumulator MOV\n", .{});
                byte_count += 3;
                reader.interface.toss(3);
                continue;
            },
            .reg_mem_to_from_reg => {
                // Standard reg/mem format: 100010dw mod reg r/m
                const mov_opcode: MovOpcode = @bitCast(opcode_byte);
                const modrm: ModRegRM = @bitCast(initial_peek[1]);

                // Determine instruction length based on MOD and R/M
                const instr_len: usize = switch (modrm.mod) {
                    0b11 => 2, // register mode
                    0b01 => 3, // 8-bit displacement
                    0b10 => 4, // 16-bit displacement
                    0b00 => if (modrm.rm == 0b110) 4 else 2, // direct address or no displacement
                };

                // Peek full instruction (for displacement bytes if needed)
                const instruction = reader.interface.peek(instr_len) catch |err| {
                    if (err == error.EndOfStream) break;
                    return err;
                };

                std.debug.print("Got {} bytes | InstrLen: {}\n", .{ instruction.len, instr_len });
                std.debug.print("OpCode: {b:0>8} -> d={}, w={}\n", .{ opcode_byte, mov_opcode.d, mov_opcode.w });
                std.debug.print("ModRM: {b:0>8} -> mod={b:0>2}, reg={b:0>3}, rm={b:0>3}\n", .{ initial_peek[1], modrm.mod, modrm.reg, modrm.rm });

                // Get register name
                const reg_name = if (mov_opcode.w == 1) reg_w1[modrm.reg] else reg_w0[modrm.reg];

                // Determine if R/M is register or memory
                if (modrm.mod == 0b11) {
                    // R/M is a register
                    const rm_name = if (mov_opcode.w == 1) reg_w1[modrm.rm] else reg_w0[modrm.rm];

                    if (mov_opcode.d == 1) {
                        std.debug.print("mov {s}, {s}\n", .{ reg_name, rm_name });
                        try stdout.print("mov {s}, {s}\n", .{ reg_name, rm_name });
                    } else {
                        std.debug.print("mov {s}, {s}\n", .{ rm_name, reg_name });
                        try stdout.print("mov {s}, {s}\n", .{ rm_name, reg_name });
                    }
                } else {
                    // R/M is memory addressing
                    var mem_operand_buf: [64]u8 = undefined;
                    var mem_operand: []const u8 = undefined;

                    // Handle special case: MOD=00 and R/M=110 is direct address
                    if (modrm.mod == 0b00 and modrm.rm == 0b110) {
                        const addr_low = instruction[2];
                        const addr_high = instruction[3];
                        const addr: u16 = @as(u16, addr_low) | (@as(u16, addr_high) << 8);
                        mem_operand = try std.fmt.bufPrint(&mem_operand_buf, "[{}]", .{addr});
                    } else {
                        // Normal memory addressing with optional displacement
                        const base = eff_addr_base[modrm.rm];

                        switch (modrm.mod) {
                            0b00 => {
                                // No displacement
                                mem_operand = try std.fmt.bufPrint(&mem_operand_buf, "[{s}]", .{base});
                            },
                            0b01 => {
                                // 8-bit displacement
                                const disp: i8 = @bitCast(instruction[2]);
                                if (disp >= 0) {
                                    mem_operand = try std.fmt.bufPrint(&mem_operand_buf, "[{s} + {}]", .{ base, disp });
                                } else {
                                    mem_operand = try std.fmt.bufPrint(&mem_operand_buf, "[{s} - {}]", .{ base, -disp });
                                }
                            },
                            0b10 => {
                                // 16-bit displacement
                                const disp_low = instruction[2];
                                const disp_high = instruction[3];
                                const disp: i16 = @bitCast(@as(u16, disp_low) | (@as(u16, disp_high) << 8));
                                if (disp >= 0) {
                                    mem_operand = try std.fmt.bufPrint(&mem_operand_buf, "[{s} + {}]", .{ base, disp });
                                } else {
                                    mem_operand = try std.fmt.bufPrint(&mem_operand_buf, "[{s} - {}]", .{ base, -disp });
                                }
                            },
                            0b11 => unreachable,
                        }
                    }

                    // Print based on direction
                    if (mov_opcode.d == 1) {
                        std.debug.print("mov {s}, {s}\n", .{ reg_name, mem_operand });
                        try stdout.print("mov {s}, {s}\n", .{ reg_name, mem_operand });
                    } else {
                        std.debug.print("mov {s}, {s}\n", .{ mem_operand, reg_name });
                        try stdout.print("mov {s}, {s}\n", .{ mem_operand, reg_name });
                    }
                }

                // Toss the bytes we just processed
                byte_count += instr_len;
                reader.interface.toss(instr_len);
            },
        }
    }
    if (byte_count % 8 != 0) {
        std.debug.print("\n\n\nWriting ASM file as follows:\n\n\n", .{});
        try stdout.writeAll("\n");
    }
    try stdout.flush();
}
