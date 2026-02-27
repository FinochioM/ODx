package commands

import "core:strings"

merge_profile_overrides :: proc(
    profile_flags:   []string,
    profile_defines: map[string]string,
    cli_flags:       []string,
    cli_defines:     []string,
    allocator := context.allocator,
) -> (flags: []string, defines: map[string]string) {
    merged_flags := make([dynamic]string, allocator)
    for f in profile_flags  { append(&merged_flags, f) }
    for f in cli_flags      { append(&merged_flags, f) }
    flags = merged_flags[:]

    merged_defines := make(map[string]string, allocator)
    for k, v in profile_defines { merged_defines[k] = v }

    for entry in cli_defines {
        eq := strings.index(entry, "=")
        if eq < 0 {
            merged_defines[entry[:]] = ""
            continue
        }
        merged_defines[entry[:eq]] = entry[eq+1:]
    }

    defines = merged_defines
    return
}
