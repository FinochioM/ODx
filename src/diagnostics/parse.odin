package diagnostics

import "core:strconv"
import "core:strings"

Diagnostic :: struct {
    file:   string,
    line: int,
    col: int,
    level: string,
    message: string
}

parse_line :: proc(raw: string, allocator := context.allocator) -> (d: Diagnostic, ok: bool) {
    s := strings.trim_space(raw)
    if len(s) == 0 {
        return {}, false
    }

    paren_open := strings.index(s, "(")
    if paren_open < 0 {
        return {}, false
    }

    paren_close := strings.index(s[paren_open:], ")")
    if paren_close < 0 {
        return {}, false
    }

    paren_close += paren_open

    file := s[:paren_open]

    coords := s[paren_open + 1 : paren_close]
    colon := strings.index(coords, ":")
    if colon < 0 {
        return {}, false
    }

    line_num, line_ok := strconv.parse_int(coords[:colon])
    col_num, col_ok := strconv.parse_int(coords[colon + 1:])
    if !line_ok || !col_ok {
        return {}, false
    }

    rest := strings.trim_space(s[paren_close + 1:])

    colon2 := strings.index(rest, ":")
    if colon2 < 0 {
        return {}, false
    }

    level := strings.trim_space(rest[:colon2])
    message := strings.trim_space(rest[colon2 + 1:])

    if len(file) == 0 || len(level) == 0 || len(message) == 0 {
        return {}, false
    }

    return Diagnostic{
        file = strings.clone(file, allocator),
        line = line_num,
        col = col_num,
        level = strings.to_lower(level, allocator),
        message = strings.clone(message, allocator),
    }, true
}

parse_stderr :: proc(stderr: string, allocator := context.allocator) -> []Diagnostic {
    out := make([dynamic]Diagnostic, allocator)

    text := stderr

    for raw_line in strings.split_lines_iterator(&text) {
        if d, ok := parse_line(raw_line, allocator); ok {
            append(&out, d)
        }
    }

    return out[:]
}
