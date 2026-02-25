package toml

import "core:fmt"
import "core:strings"

Value :: union {
    string,
    []string,
    Table,
}

Table :: map[string]Value

Parse_Error :: struct {
    line: int,
    msg:  string,
}

parse :: proc(src: string, allocator := context.allocator) -> (table: Table, ok: bool, err: Parse_Error) {
    table = make(Table, allocator)
    ok    = true

    lines := strings.split_lines(src, allocator)
    defer delete(lines)

    current_section: []string

    for raw, i in lines {
        line     := strings.trim_space(raw)
        line_num := i + 1

        if len(line) == 0 || line[0] == '#' {
            continue
        }

        if line[0] == '[' {
            if line[len(line)-1] != ']' {
                return table, false, Parse_Error{line_num, "malformed section header: missing ']'"}
            }
            inner           := strings.trim_space(line[1:len(line)-1])
            current_section  = strings.split(inner, ".", allocator)
            continue
        }

        eq := strings.index(line, "=")
        if eq < 0 {
            return table, false, Parse_Error{line_num, "expected '='"}
        }

        key     := strings.trim_space(line[:eq])
        val_src := strings.trim_space(line[eq+1:])

        if len(key) == 0 {
            return table, false, Parse_Error{line_num, "empty key"}
        }

        val, val_ok := parse_value(val_src, allocator)
        if !val_ok {
            return table, false, Parse_Error{line_num, fmt.aprintf("could not parse value for key '%s'", key, allocator = allocator)}
        }

        table_set(&table, current_section, key, val, allocator)
    }

    return table, true, {}
}

@(private)
table_set :: proc(root: ^Table, section: []string, key: string, val: Value, allocator := context.allocator) {
    if len(section) == 0 {
        root^[strings.clone(key, allocator)] = val
        return
    }

    part := section[0]

    child: Table
    if existing, exists := root^[part]; exists {
        if t, is_table := existing.(Table); is_table {
            child = t
        } else {
            child = make(Table, allocator)
        }
    } else {
        child = make(Table, allocator)
    }

    table_set(&child, section[1:], key, val, allocator)

    root^[strings.clone(part, allocator)] = child
}

get :: proc(table: Table, path: string) -> (Value, bool) {
    parts := strings.split(path, ".")
    defer delete(parts)

    current := table
    for part, i in parts {
        v, exists := current[part]
        if !exists {
            return nil, false
        }
        if i == len(parts) - 1 {
            return v, true
        }
        child, is_table := v.(Table)
        if !is_table {
            return nil, false
        }
        current = child
    }
    return nil, false
}

get_string :: proc(table: Table, path: string, default := "") -> string {
    v, ok := get(table, path)
    if !ok {
        return default
    }
    s, is_str := v.(string)
    return is_str ? s : default
}

get_array :: proc(table: Table, path: string) -> []string {
    v, ok := get(table, path)
    if !ok {
        return nil
    }
    arr, is_arr := v.([]string)
    return is_arr ? arr : nil
}

get_table :: proc(table: Table, path: string) -> Table {
    v, ok := get(table, path)
    if !ok {
        return nil
    }
    t, is_table := v.(Table)
    return is_table ? t : nil
}

@(private)
parse_value :: proc(src: string, allocator := context.allocator) -> (Value, bool) {
    if len(src) == 0 {
        return nil, false
    }
    switch src[0] {
    case '"': return parse_string(src, allocator)
    case '[': return parse_array(src, allocator)
    case '{': return parse_inline_table(src, allocator)
    }
    return nil, false
}

@(private)
parse_string :: proc(src: string, allocator := context.allocator) -> (string, bool) {
    if len(src) < 2 || src[0] != '"' {
        return "", false
    }
    for i := 1; i < len(src); i += 1 {
        if src[i] == '\\' {
            i += 1
            continue
        }
        if src[i] == '"' {
            return strings.clone(src[1:i], allocator), true
        }
    }
    return "", false
}

@(private)
parse_array :: proc(src: string, allocator := context.allocator) -> ([]string, bool) {
    if len(src) < 2 || src[0] != '[' {
        return nil, false
    }
    close := strings.last_index(src, "]")
    if close < 0 {
        return nil, false
    }

    inner  := strings.trim_space(src[1:close])
    result := make([dynamic]string, allocator)

    if len(inner) == 0 {
        return result[:], true
    }

    parts, ok := split_csv(inner, allocator)
    if !ok {
        return nil, false
    }

    for part in parts {
        s, str_ok := parse_string(strings.trim_space(part), allocator)
        if !str_ok {
            return nil, false
        }
        append(&result, s)
    }

    return result[:], true
}

@(private)
parse_inline_table :: proc(src: string, allocator := context.allocator) -> (Table, bool) {
    if len(src) < 2 || src[0] != '{' {
        return nil, false
    }
    close := strings.last_index(src, "}")
    if close < 0 {
        return nil, false
    }

    inner  := strings.trim_space(src[1:close])
    result := make(Table, allocator)

    if len(inner) == 0 {
        return result, true
    }

    parts, ok := split_csv(inner, allocator)
    if !ok {
        return nil, false
    }

    for part in parts {
        eq := strings.index(part, "=")
        if eq < 0 {
            return nil, false
        }
        k := strings.clone(strings.trim_space(part[:eq]), allocator)
        s, str_ok := parse_string(strings.trim_space(part[eq+1:]), allocator)
        if !str_ok {
            return nil, false
        }
        result[k] = s
    }

    return result, true
}

@(private)
split_csv :: proc(src: string, allocator := context.allocator) -> ([]string, bool) {
    parts  := make([dynamic]string, allocator)
    depth  := 0
    in_str := false
    start  := 0

    for i := 0; i < len(src); i += 1 {
        ch := src[i]
        switch {
        case ch == '\\' && in_str: i += 1
        case ch == '"':            in_str = !in_str
        case ch == '[' || ch == '{': depth += 1
        case ch == ']' || ch == '}': depth -= 1
        case ch == ',' && !in_str && depth == 0:
            append(&parts, src[start:i])
            start = i + 1
        }
    }

    append(&parts, src[start:])
    return parts[:], true
}
