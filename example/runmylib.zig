const std = @import("std");
const liberrors = @import("myliberrors.zig").MyLibErrors;
const errabi = @import("../error_abi.zig");

extern fn libfn(err: bool) errabi.ErrorVal(u32);

pub fn main() u8 {
    std.debug.warn("Calling without error...\n");
    var val: u32 = 0;
    if (errabi.errorUnwrap(liberrors, u32, libfn(false))) |goodval| {
        val = goodval;
    } else |err_val| {
        unreachable;
    }

    if (val != 35) {
        @panic("val is incorrect");
    }

    std.debug.warn("Val was correct\n");

    _ = errabi.errorUnwrap(liberrors, u32, libfn(true)) catch |e| {
        std.debug.warn("Error was correct: {}", e);
    };

    return 0;
}
