package diagnostics

import "core:fmt"
import "core:strings"

print_diagnostics :: proc(diagnostics: []Diagnostic) {
    for d in diagnostics {
        fmt.printfln("%s: %s:%d:%d", d.level, d.file, d.line, d.col)
        fmt.printfln("  %s", d.message)
    }
}

print_raw :: proc(stderr: string) {
    text := stderr

    for line in strings.split_lines_iterator(&text) {
        trimmed := strings.trim_space(line)
        if len(trimmed) > 0 {
            fmt.eprintln(trimmed)
        }
    }
}

partition :: proc(stderr: string, allocator := context.allocator) -> (structured: []Diagnostic, remainder: string) {
    diags := make([dynamic]Diagnostic, allocator)
    leftover := strings.builder_make(allocator)

    text := stderr
    for raw_line in strings.split_lines_iterator(&text) {
        if d, ok := parse_line(raw_line, allocator); ok {
            append(&diags, d)
        } else {
            trimmed := strings.trim_space(raw_line)
            if len(trimmed) > 0 {
                strings.write_string(&leftover, trimmed)
                strings.write_byte(&leftover, '\n')
            }
        }
    }

    return diags[:], strings.to_string(leftover)
}
