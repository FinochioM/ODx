package module

import "core:fmt"
import "core:os"
import "src:lib/toml"

Manifest :: struct {
    name:     string,
    root:     string,
    entry:    string,
    out_dir:  string,
    build:    Build_Config,
    profiles: map[string]Profile,
    targets:  map[string]Target,
    tasks:    map[string]Task,
    deps:     map[string]Dep,
}

Build_Config :: struct {
    odin_cmd:        string,
    default_profile: string,
    default_target:  string,
    collections:     map[string]string,   
    pre_build:       []string,
    pre_run:         []string,
    pre_test:        []string,
}

Profile :: struct {
    flags:   []string,
    defines: map[string]string,
}

Target :: struct {
    triple:  string,
    flags:   []string,
    defines: map[string]string,
}

Task :: struct {
    deps:    []string,
    cmd:     []string,
    inputs:  []string,
    outputs: []string,
    env:     map[string]string,
    shell:  bool,
}

Dep_Kind :: enum { Path, Git }

Dep :: struct {
    kind:   Dep_Kind,
    url:    string,
    rev:    string,
}

load_manifest :: proc(path: string, allocator := context.allocator) -> (m: Manifest, ok: bool) {
    data, read_ok := os.read_entire_file(path, allocator)
    if !read_ok {
        fmt.eprintfln("odx: could not read '%s'", path)
        return {}, false
    }
    defer delete(data)

    table, parse_ok, parse_err := toml.parse(string(data), allocator)
    if !parse_ok {
        fmt.eprintfln("odx: manifest parse error (line %d): %s", parse_err.line, parse_err.msg)
        return {}, false
    }

    m.name    = toml.get_string(table, "project.name")
    m.root    = toml.get_string(table, "project.root",    ".")
    m.entry   = toml.get_string(table, "project.entry")
    m.out_dir = toml.get_string(table, "project.out_dir", "build")

    m.build = Build_Config{
        odin_cmd        = toml.get_string(table, "build.odin_cmd",        "odin"),
        default_profile = toml.get_string(table, "build.default_profile", "dev"),
        default_target  = toml.get_string(table, "build.default_target",  "host"),
        collections     = table_to_string_map(toml.get_table(table, "build.collections"), allocator),
        pre_build       = toml.get_array(table,  "build.pre_build"),
        pre_run         = toml.get_array(table,  "build.pre_run"),
        pre_test        = toml.get_array(table,  "build.pre_test"),
    }

    m.profiles = make(map[string]Profile, allocator)
    if profiles_table := toml.get_table(table, "profiles"); profiles_table != nil {
        for name, val in profiles_table {
            pt, is_table := val.(toml.Table)
            if !is_table do continue
            m.profiles[name] = Profile{
                flags =   toml.get_array(pt,  "flags"),
                defines = table_to_string_map(toml.get_table(pt, "defines"), allocator),
            }
        }
    }

    m.targets = make(map[string]Target, allocator)
    if targets_table := toml.get_table(table, "targets"); targets_table != nil {
        for name, val in targets_table {
            tt, is_table := val.(toml.Table)
            if !is_table do continue
            m.targets[name] = Target{
                triple =  toml.get_string(tt, "triple"),
                flags =  toml.get_array(tt,  "flags"),
                defines = table_to_string_map(toml.get_table(tt, "defines"), allocator),
            }
        }
    }

    m.tasks = make(map[string]Task, allocator)
    if tasks_table := toml.get_table(table, "tasks"); tasks_table != nil {
        for name, val in tasks_table {
            tt, is_table := val.(toml.Table)
            if !is_table do continue
            m.tasks[name] = Task{
                deps =    toml.get_array(tt, "deps"),
                cmd =     toml.get_array(tt, "cmd"),
                inputs =  toml.get_array(tt, "inputs"),
                outputs = toml.get_array(tt, "outputs"),
                env =     table_to_string_map(toml.get_table(tt, "env"), allocator),
                shell = toml.get_string(tt, "shell") == "true",
            }
        }
    }

    m.deps = make(map[string]Dep, allocator)
    if deps_table := toml.get_table(table, "deps"); deps_table != nil {
        for name, val in deps_table {
            dt, is_table := val.(toml.Table)
            if !is_table do continue

            if path_str, ok := dt["path"].(string); ok {
                m.deps[name] = Dep{kind = .Path, url = path_str}
            } else if git_str, ok := dt["git"].(string); ok {
                rev, _ := dt["rev"].(string)
                m.deps[name] = Dep{kind = .Git, url = git_str, rev = rev}
            }
        }
    }

    return m, true
}

@(private)
table_to_string_map :: proc(t: toml.Table, allocator := context.allocator) -> map[string]string {
    m := make(map[string]string, allocator)
    if t == nil do return m
    for k, v in t {
        if s, is_str := v.(string); is_str {
            m[k] = s
        }
    }
    return m
}
