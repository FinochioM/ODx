package cache

import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:strings"
import "src:version"

Task_Key_Params :: struct {
    task_name:    string,
    profile:      string,
    target:       string,
    flags:        []string,
    defines:      map[string]string,
    source_paths: []string,
    odin_version: string,
}

compute_task_key :: proc(p: Task_Key_Params, allocator := context.allocator) -> (key: string, ok: bool) {
    buf := make([dynamic]byte, context.temp_allocator)

    push :: proc(buf: ^[dynamic]byte, s: string) {
        append(buf, ..transmute([]byte)s)
        append(buf, 0) // field separator: "ab"+"c" != "a"+"bc"
    }

    push(&buf, version.ODX_VERSION)
    push(&buf, p.odin_version)
    push(&buf, p.task_name)
    push(&buf, p.profile)
    push(&buf, p.target)

    for flag in p.flags {
        push(&buf, flag)
    }

    define_keys := make([]string, len(p.defines), context.temp_allocator)
    i := 0
    for k in p.defines {
        define_keys[i] = k
        i += 1
    }
    slice.sort(define_keys)

    for k in define_keys {
        push(&buf, k)
        push(&buf, p.defines[k])
    }

    for path in p.source_paths {
        data, read_ok := os.read_entire_file(path, context.temp_allocator)
        if !read_ok {
            return "", false
        }
        append(&buf, ..data)
        append(&buf, 0)
    }

    return hash_bytes(buf[:], allocator), true
}

module_id :: proc(module_root: string, allocator := context.allocator) -> string {
    full := hash_string(module_root, context.temp_allocator)
    return strings.clone(full[:12], allocator)
}

stamp_path :: proc(
    task_name: string,
    module_root: string,
    cache_key: string,
    allocator := context.allocator,
) -> string {
    dir := get_cache_dir(context.temp_allocator)
    mid := module_id(module_root, context.temp_allocator)
    return filepath.join(
        {dir, "v0", "tasks", mid, task_name, cache_key, "stamp"},
        allocator,
    )
}
