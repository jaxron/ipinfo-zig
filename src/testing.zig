const std = @import("std");
const builder = @import("string_builder.zig");
const ipinfo = @import("ipinfo.zig");

const t = std.testing;

test "string_builder: concatenation" {
    const allocator = t.allocator;

    // Test string concatenation
    {
        var string = builder.String.init(allocator);
        defer string.deinit();

        const expected = "The quick brown fox jumps over the lazy dog";

        try string.concat(expected);
        try t.expectEqualStrings(expected, string.string());
        try t.expect(string.len() == expected.len);
    }
}

test "basic: valid IP address using own IP" {
    const allocator = t.allocator;
    var client = try ipinfo.Client.init(allocator, .{});
    defer client.deinit();

    // Test with a valid IP address
    const res = try client.basic.getIPInfo(.{});
    defer res.deinit();

    try t.expect(!res.hasError());
}

test "basic: valid IP address using 8.8.8.8" {
    const allocator = t.allocator;
    var client = try ipinfo.Client.init(allocator, .{});
    defer client.deinit();

    // Test with a valid IP address
    const res = try client.basic.getIPInfo(.{
        .ip_address = "8.8.8.8",
    });
    defer res.deinit();

    try t.expect(!res.hasError());
    try t.expectEqualStrings("AS15169 Google LLC", res.parsed.?.value.org.?);
}

test "basic: valid IP address with filter" {
    const allocator = t.allocator;
    var client = try ipinfo.Client.init(allocator, .{});
    defer client.deinit();

    // Test with valid IP address and filter
    const res = try client.basic.getFilteredIPInfo(.{
        .ip_address = "8.8.8.8",
    }, .country);
    defer res.deinit();

    try t.expect(!res.hasError());
    try t.expectEqualStrings("US", res.value.?.items);
}

test "basic: 2 batch IP address requests" {
    const allocator = t.allocator;
    var client = try ipinfo.Client.init(allocator, .{});
    defer client.deinit();

    // Get secret token
    const argv = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, argv);

    // * You need to pass in your API tokens with this format:
    // * zig run test.zig -- <API_TOKEN>
    try t.expect(argv.len >= 2);
    const token = argv[1];

    // Test with batch IP addresses
    const res = try client.basic.getBatchIPInfo(.{
        .api_token = token,
        .ip_urls = &.{
            "8.8.8.8/country",
            "8.8.8.9/hostname",
        },
        .hide_invalid = true,
    });
    defer res.deinit();

    try t.expect(!res.hasError());
    try t.expect(res.parsed.?.value.map.count() == 1);
    try t.expectEqualStrings("US", res.parsed.?.value.map.values()[0].string);

    // Test the cache with the same batch IP addresses
    const res2 = try client.basic.getBatchIPInfo(.{
        .api_token = token,
        .ip_urls = &.{
            "8.8.8.8/country",
            "8.8.8.9/hostname",
        },
        .hide_invalid = true,
    });
    defer res2.deinit();

    try t.expect(!res2.hasError());
    try t.expect(res2.parsed.?.value.map.count() == 1);
    try t.expectEqualStrings(res.parsed.?.value.map.values()[0].string, res2.parsed.?.value.map.values()[0].string);
}

test "basic: invalid IP address" {
    const allocator = t.allocator;
    var client = try ipinfo.Client.init(allocator, .{});
    defer client.deinit();

    // Test with an invalid IP address
    const res = try client.basic.getIPInfo(.{
        .ip_address = "invalid",
    });
    defer res.deinit();

    try t.expect(res.hasError());
    try t.expectEqualStrings("Wrong ip", res.err.?.@"error".title);
    try t.expectEqualStrings("Please provide a valid IP address", res.err.?.@"error".message);
}

test "basic: 2 valid IP address with cache" {
    const allocator = t.allocator;
    var client = try ipinfo.Client.init(allocator, .{});
    defer client.deinit();

    // Test with a valid IP address
    const res = try client.basic.getIPInfo(.{});
    defer res.deinit();

    try t.expect(!res.hasError());

    // Test with a valid IP address
    const res2 = try client.basic.getIPInfo(.{});
    defer res2.deinit();

    try t.expect(!res2.hasError());

    // Compare the results
    try t.expectEqualStrings(res.body.items, res2.body.items);
}

test "basic: 2 valid IP address without cache" {
    const allocator = t.allocator;
    var client = try ipinfo.Client.init(allocator, .{
        .enabled = false,
    });
    defer client.deinit();

    // Test with a valid IP address
    const res = try client.basic.getIPInfo(.{});
    defer res.deinit();

    try t.expect(!res.hasError());

    // Test with a valid IP address
    const res2 = try client.basic.getIPInfo(.{});
    defer res2.deinit();

    try t.expect(!res2.hasError());

    // Compare the results
    try t.expectEqualStrings(res.body.items, res2.body.items);
}

test "basic: bogon IP address" {
    const allocator = t.allocator;
    var client = try ipinfo.Client.init(allocator, .{});
    defer client.deinit();

    // Test with a bogon IP address
    const res = try client.basic.getIPInfo(.{
        .ip_address = "0.0.0.0",
    });
    defer res.deinit();

    try t.expect(!res.hasError());
    try t.expect(res.parsed.?.value.bogon.?);
}

test "extra: valid IP summary" {
    const allocator = t.allocator;
    var client = try ipinfo.Client.init(allocator, .{});
    defer client.deinit();

    // Test with valid IP addresses
    const res = try client.extra.getIPSummary(.{
        .ips = &.{ "8.8.8.8", "8.8.4.4", "1.1.1.1", "1.0.0.1", "94.140.14.14", "94.140.15.15", "9.9.9.9", "149.112.112.112", "76.76.2.0", "76.76.10.0" },
    });
    defer res.deinit();

    try t.expect(!res.hasError());
}

test "extra: invalid IP summary" {
    const allocator = t.allocator;
    var client = try ipinfo.Client.init(allocator, .{});
    defer client.deinit();

    // Test without enough IP addresses
    const res = try client.extra.getIPSummary(.{
        .ips = &.{"8.8.8.8"},
    });
    defer res.deinit();

    try t.expect(res.hasError());
    try t.expectEqualStrings("The list should have at least 10 distinct IPs", res.err.?.@"error");
}

test "extra: valid IP map" {
    const allocator = t.allocator;
    var client = try ipinfo.Client.init(allocator, .{});
    defer client.deinit();

    // Test with valid IP addresses
    const map = try client.extra.getIPMap(.{
        .ips = &.{ "8.8.8.8", "8.8.4.4" },
    });
    defer map.deinit();

    try t.expect(!map.hasError());

    // Test with the given report URL
    const report = try client.extra.getIPMapReport(.{
        .report_url = map.parsed.?.value.reportUrl,
    });
    defer report.deinit();

    try t.expect(!report.hasError());
    try t.expectEqual(1, report.parsed.?.value.numCountries.?);
}

test "extra: invalid IP map" {
    const allocator = t.allocator;
    var client = try ipinfo.Client.init(allocator, .{});
    defer client.deinit();

    // Test with invalid IP addresses
    const res = try client.extra.getIPMap(.{
        .ips = &.{"invalid"},
    });
    defer res.deinit();

    try t.expect(res.hasError());
    try t.expectEqualStrings("No IPs Found", res.err.?.title);
    try t.expectEqualStrings("There were no valid IPs in the text.", res.err.?.message);
}
