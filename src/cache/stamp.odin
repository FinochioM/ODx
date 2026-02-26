package cache

import "core:os"
import "core:strings"

is_cache_hit :: proc(stamp_file, expected_key: string) -> bool {
    data, ok := os.read_entire_file(stamp_file, context.temp_allocator)
    if !ok {
        return false
    }
    stored := strings.trim_space(string(data))
    return stored == expected_key
}

write_stamp :: proc(stamp_file, key: string) -> bool {
    parent := parent_dir(stamp_file)
    if !make_dir_all(parent) {
        return false
    }
    return os.write_entire_file(stamp_file, transmute([]byte)key)
}

@(private)
parent_dir :: proc(path: string) -> string {
    for i := len(path) - 1; i >= 0; i -= 1 {
        if path[i] == '/' || path[i] == '\\' {
            return path[:i]
        }
    }
    return "."
}
