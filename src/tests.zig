const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualDeep = std.testing.expectEqualDeep;
const expectEqualStrings = std.testing.expectEqualStrings;
const lib = @import("lib");
const Property = lib.Property;
const PropertyObject = lib.PropertyObject;
const Scene = lib.documents.scene.Document1;

// test "this is a test" {
//     const json =
//         \\{"id":"04a869ec-1a1b-4866-9f90-887a66d76f27","property":{"boolean":{"value":false}}}
//     ;
//
//     const property = try std.json.parseFromSlice(Property, std.testing.allocator, json, .{});
//     defer property.deinit();
//
//     try expectEqual(std.meta.activeTag(property.value.property), .boolean);
//     try expectEqual(property.value.property.boolean.value, false);
// }
//
// test "property object" {
//     const json =
//         \\ {
//         \\   "activates": {
//         \\     "id": "3b635677-6c40-4383-8324-5b722989f1a0",
//         \\     "property": {
//         \\       "entityReference": {
//         \\         "sceneId": "c0969c06-f4ec-4648-903a-4308365fd878",
//         \\         "entityId": "e671bef6-b06c-493b-8e9d-c1f7c853ddec"
//         \\       }
//         \\     }
//         \\   },
//         \\   "initialState": {
//         \\     "id": "04a869ec-1a1b-4866-9f90-887a66d76f27",
//         \\     "property": { "boolean": { "value": false } }
//         \\   }
//         \\ }
//     ;
//
//     var stream = std.io.fixedBufferStream(json);
//     const streamReader = stream.reader();
//     var reader = std.json.reader(std.testing.allocator, streamReader);
//     defer reader.deinit();
//
//     var properties = std.json.parseFromTokenSource(PropertyObject, std.testing.allocator, &reader, .{}) catch |err| {
//         lib.json.reportJsonError(reader, err);
//         return err;
//     };
//
//     defer properties.deinit();
//
//     try expectEqual(properties.value.getByKey(std.testing.allocator, "initialState").?.property.boolean.value, false);
// }

// test "enter file" {
//     const json =
//         \\ {
//         \\   "version": 1,
//         \\   "id": "c0969c06-f4ec-4648-903a-4308365fd878",
//         \\   "entities": [
//         \\     {
//         \\       "id": "325b875d-9b77-4c76-943a-166da49f01c4",
//         \\       "position": [0, 0],
//         \\       "type": {
//         \\         "tilemap": { "tilemapId": "088a6d9e-9c24-4e49-b0b6-1b019c9b461c" }
//         \\       }
//         \\     },
//         \\     {
//         \\       "id": "d93711b1-8691-4b6a-b114-0880782fc82d",
//         \\       "position": [16, 24],
//         \\       "type": {
//         \\         "custom": {
//         \\           "entityTypeId": "e51aa85c-3c25-40e9-a60e-9250b4385e44",
//         \\           "properties": {}
//         \\         }
//         \\       }
//         \\     },
//         \\     {
//         \\       "id": "c6bc4f7a-46d6-4c77-97c0-3d57ebd33220",
//         \\       "position": [855, -64],
//         \\       "type": {
//         \\         "exit": {
//         \\           "sceneId": "b2d2f652-1e7e-4756-a515-c024a5d569cd",
//         \\           "scale": [1, 1.4e1],
//         \\           "entranceKey": "left",
//         \\           "isVertical": false
//         \\         }
//         \\       }
//         \\     },
//         \\     {
//         \\       "id": "584384c7-b656-481b-a7b9-abcd094a1d6d",
//         \\       "position": [-855, 64],
//         \\       "type": {
//         \\         "exit": {
//         \\           "sceneId": "c790c1e9-7d46-41ca-9ab4-b9c0b16de2e1",
//         \\           "scale": [1, 1.4e1],
//         \\           "entranceKey": "right",
//         \\           "isVertical": false
//         \\         }
//         \\       }
//         \\     },
//         \\     {
//         \\       "id": "f5119e46-a4a7-4de7-a1bb-6a8103da52a8",
//         \\       "position": [-832, 64],
//         \\       "type": { "entrance": { "key": "left", "scale": [1, 1.4e1] } }
//         \\     },
//         \\     {
//         \\       "id": "e84d4192-92b4-48cc-99ab-0041a9800ada",
//         \\       "position": [832, -64],
//         \\       "type": { "entrance": { "key": "right", "scale": [1, 1.4e1] } }
//         \\     },
//         \\     {
//         \\       "id": "a5ebbe8b-8222-4806-96bd-d9559c1ed643",
//         \\       "position": [-48, 16],
//         \\       "type": { "entrance": { "key": "start", "scale": [1, 1] } }
//         \\     },
//         \\     {
//         \\       "id": "af239843-773d-455c-b1df-b20ac9442142",
//         \\       "position": [-760, 168],
//         \\       "type": {
//         \\         "custom": {
//         \\           "entityTypeId": "8fb9ffbe-49bb-4041-b18e-9cb007583ae5",
//         \\           "properties": {}
//         \\         }
//         \\       }
//         \\     },
//         \\     {
//         \\       "id": "fa2b7e58-109e-47c4-8b1d-9063d58c58f4",
//         \\       "position": [744, 24],
//         \\       "type": {
//         \\         "custom": {
//         \\           "entityTypeId": "8fb9ffbe-49bb-4041-b18e-9cb007583ae5",
//         \\           "properties": {}
//         \\         }
//         \\       }
//         \\     },
//         \\     {
//         \\       "id": "bf64f3cb-95fb-40a7-90a2-cda1ffb03e8d",
//         \\       "position": [-48, 24],
//         \\       "type": {
//         \\         "custom": {
//         \\           "entityTypeId": "761ee4e0-53b5-48a6-abe4-8cba1abd9119",
//         \\           "properties": {}
//         \\         }
//         \\       }
//         \\     },
//         \\     {
//         \\       "id": "e671bef6-b06c-493b-8e9d-c1f7c853ddec",
//         \\       "position": [184, -136],
//         \\       "type": {
//         \\         "custom": {
//         \\           "entityTypeId": "317f36f6-c711-43cd-926f-11d135cacdb5",
//         \\           "properties": {}
//         \\         }
//         \\       }
//         \\     },
//         \\     {
//         \\       "id": "72ba5769-849f-411f-9b2b-61ec00011fbf",
//         \\       "position": [56, -120],
//         \\       "type": {
//         \\         "custom": {
//         \\           "entityTypeId": "92a1debf-d5fb-4ba1-aead-0e0cdf7b0086",
//         \\           "properties": {
//         \\             "activates": {
//         \\               "id": "3b635677-6c40-4383-8324-5b722989f1a0",
//         \\               "property": {
//         \\                 "entityReference": {
//         \\                   "sceneId": "c0969c06-f4ec-4648-903a-4308365fd878",
//         \\                   "entityId": "e671bef6-b06c-493b-8e9d-c1f7c853ddec"
//         \\                 }
//         \\               }
//         \\             },
//         \\             "initialState": {
//         \\               "id": "04a869ec-1a1b-4866-9f90-887a66d76f27",
//         \\               "property": { "boolean": { "value": false } }
//         \\             }
//         \\           }
//         \\         }
//         \\       }
//         \\     }
//         \\   ]
//         \\ }
//     ;
//
//     var stream = std.io.fixedBufferStream(json);
//     const streamReader = stream.reader();
//     var reader = std.json.reader(std.testing.allocator, streamReader);
//     var diagnostics = std.json.Diagnostics{};
//     reader.enableDiagnostics(&diagnostics);
//     defer reader.deinit();
//
//     var scene = std.json.parseFromTokenSource(Scene, std.testing.allocator, &reader, .{}) catch |err| {
//         try expectEqualDeep(diagnostics.getColumn(), 0);
//         // var reportBuffer: [1024 * 4]u8 = undefined;
//         // var reportStream = std.io.fixedBufferStream(&reportBuffer);
//         // try lib.json.reportJsonErrorToWriter(reader, err, reportStream.writer());
//         // try expectEqualStrings(reportStream.getWritten(), "");
//         return err;
//     };
//
//     defer scene.deinit();
//
//     try expect(true);
// }

test "removeCharacters" {
    var buffer: [64:0]u8 = undefined;
    const input = try std.fmt.bufPrintZ(&buffer, "abc/def/123.txt", .{});
    const delimiters = "/";
    const expected = "abcdef123.txt";

    const actual = lib.layouts.utils.removeCharacters(delimiters, input);

    try expectEqualStrings(expected, actual);
}
