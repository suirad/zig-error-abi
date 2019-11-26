const errabi = @import("../error_abi.zig");
const liberrors = @import("myliberrors.zig").MyLibErrors;

export fn libfn(err: bool) errabi.ErrorVal(u32) {
    var res = errabi.errorWrap(liberrors, u32, failfn(err));
    return res;
}

fn failfn(giveerr: bool) !u32 {
    if (giveerr) {
        return liberrors.LibError;
    }
    return 35;
}
