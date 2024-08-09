const std = @import("std");
const encoder = @import("lsp.zig");
pub fn main() !void {
    const TestStruct = struct { msg: []const u8, length: u16 };

    const x = TestStruct{ .msg = "Hello world", .length = 10 };
    const res = try encoder.encodeMessage(x);
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("{s}\n", .{res});

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    // const stdout_file = std.io.getStdOut().writer();
    // var bw = std.io.bufferedWriter(stdout_file);
    // const stdout = bw.writer();
    //
    // try stdout.print("Run `zig build test` to run the tests.\n", .{});
    //
    // try bw.flush(); // don't forget to flucontentTypesh!
    // f
}

// test "simple test" {
//     var list = std.ArrayList(i32).init(std.testing.allocator);
//     defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
//     try list.append(42);
//     try std.testing.expectEqual(@as(i32, 42), list.pop());
// }
const testing = std.testing;
//Testing section
// test "basic encode" {
//     const TestStruct = struct { msg: []const u8, length: u16 };
//     const x = TestStruct{ .msg = "Hello world", .length = 10 };
//     const encoded = try encoder.encodeMessage(x);
//     try testing.expect(std.mem.eql(u8, encoded,
//         \\{"msg":"Hello World","length":10}
//     ));
// }
// test "basic decode" {
//     const content =
//         \\{"jsonrpc" : "2.0","id": 1,"method" : "textDocument/completion"}
//     ;
//     const msg = "Content-Length :  10\r\n\r\n" ++ content;
//     const decoded = try encoder.decodeMessage(msg);
//     try testing.expectEqualStrings("2.0", decoded.jsonrpc);
// }
//
