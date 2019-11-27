const std = @import("std");
const expect = std.testing.expect;
const expectError = std.testing.expectError;

/// Value that serializes a !T
/// The T value is memset to all zeros.
pub fn ErrorVal(comptime T: type) type {
    return packed struct {
        const Self = @This();

        err: u32,
        val: T,

        pub fn init() Self {
            var ret = Self{ .err = 0, .val = undefined };
            @memset(@ptrCast([*]u8, &ret.val), 0, @sizeOf(T));
            return ret;
        }
    };
}

/// Hash an error value string; is a simple sum hash.
/// Must be the actual error name, not one from a ErrorSet
/// i.e "error.<whatever>"
pub fn errorHash(comptime err: anyerror) u32 {
    const errname = @errorName(err);
    comptime var ret: u32 = 0;
    comptime {
        for (errname) |c| {
            ret += c;
            ret += @truncate(u8, ret);
        }
    }
    return ret;
}

/// Given an ErrorSet, a return type, and an ErrorVal of the same return type
/// This fn will deduce if the result has an error, if not return the value
/// if so, return the actual error.
/// If the error that was returned is unknown, then returns error.UnknownExternalError.
pub fn errorUnwrap(comptime errset: type, comptime T: type, result: ErrorVal(T)) !T {
    comptime checkForCollisions(errset);
    if (result.err == 0) {
        return result.val;
    }
    const errs = comptime std.meta.fields(errset);
    inline for (errs) |err| {
        const err_val = @intToError(err.value);
        if (errorHash(err_val) == result.err) {
            return err_val;
        }
    }
    return error.UnknownExternalError;
}

/// Wraps a result from a fn that can error and returns a errorval
pub fn errorWrap(comptime errset: type, comptime T: type, val: errset!T) ErrorVal(T) {
    comptime checkForCollisions(errset);
    var res = ErrorVal(T).init();
    if (val) |actual_val| {
        res.val = actual_val;
    } else |thiserr| {
        inline for (comptime std.meta.fields(errset)) |err| {
            const err_val = @intToError(err.value);
            if (thiserr == err_val) {
                res.err = errorHash(err_val);
                break;
            }
        }
    }
    return res;
}

fn checkForCollisions(comptime errset: type) void {
    comptime {
        const errs = std.meta.fields(errset);
        for (errs) |err1, i| {
            const errval1 = @intToError(err1.value);
            for (errs) |err2, j| {
                if (i == j) continue;
                const errval2 = @intToError(err2.value);
                if (errorHash(errval1) == errorHash(errval2)) {
                    const msg = "Hash collision of error." ++ err1.name ++ " and error." ++ err2.name;
                    @compileError(msg);
                }
            }
        }
    }
}

// Error set to test with
const TestingErrors = error{
    LameError,
    WackError,
};

// exported fn to test with
// add export to test this fn as exported, removed to not export in importing projects
fn testexport(err: bool) ErrorVal(u32) {
    var res = errorWrap(TestingErrors, u32, dummyfn(err));
    return res;
}

// test fn that may return an error
fn dummyfn(err: bool) !u32 {
    if (err) return error.WackError;
    return 1;
}

test "exported error" {
    var ret = ErrorVal(u32).init();
    expect(ret.err == 0);
    expect(ret.val == 0);
}

const Collisions = error{
    abcd,
    abdc,
    dcba,
    cdba,
};

test "errorHash and collisions" {
    const hash = errorHash(error.LameError);
    expect(hash == 1968);

    checkForCollisions(Collisions);
    expect(errorHash(error.abcd) != errorHash(error.abdc));
    expect(errorHash(error.abcd) != errorHash(error.dcba));
    expect(errorHash(error.abcd) != errorHash(error.cdba));
}

test "errorWrap/errorUnwrap" {
    var result = errorWrap(TestingErrors, u32, error.LameError);
    expectError(error.LameError, errorUnwrap(TestingErrors, u32, result));

    result.err = errorHash(error.OutOfMemory);
    expectError(error.UnknownExternalError, errorUnwrap(TestingErrors, u32, result));

    expect(1 == try errorUnwrap(TestingErrors, u32, testexport(false)));

    expectError(error.WackError, errorUnwrap(TestingErrors, u32, testexport(true)));
}
