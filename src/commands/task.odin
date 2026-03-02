package commands

import "core:fmt"
import "core:os"
import "core:os/os2"
import "core:path/filepath"
import "core:strings"
import "src:module"
import "src:cache"
import "src:events"
import "core:time"

Task_Args :: struct {
    path:      string,
    task_name: string,
    verbose:   bool,
    run_args:  []string,
}

run_task :: proc(a: Task_Args) -> bool {
    if a.task_name == "" {
        fmt.eprintln("odx: task name required")
        fmt.eprintln("     usage: odx task <name> [path]")
        return false
    }

    mod, ok := module.resolve(a.path)
    if !ok do return false

    if !mod.has_manifest {
        fmt.eprintln("odx: no odx.toml found — cannot run tasks in ad-hoc mode")
        return false
    }

    manifest_path := filepath.join({mod.root, "odx.toml"})
    manifest, man_ok := module.load_manifest(manifest_path)
    if !man_ok do return false

    task, found := manifest.tasks[a.task_name]
    if !found {
        fmt.eprintfln("odx: unknown task '%s'", a.task_name)
        fmt.eprintln("     run 'odx list' to see available tasks")
        return false
    }

    return exec_task(a.task_name, task, mod, manifest, a.verbose, a.run_args)
}

@(private)
run_deps :: proc(
    task:      module.Task,
    mod:       module.Module,
    manifest:  module.Manifest,
    verbose:   bool,
    in_progress: ^[dynamic]string,
) -> bool {
    for dep_name in task.deps {
        for visiting in in_progress^ {
            if visiting == dep_name {
                fmt.eprintfln("odx: cycle detected: '%s' is already in the current dependency chain", dep_name)
                return false
            }
        }

        dep_task, found := manifest.tasks[dep_name]
        if !found {
            fmt.eprintfln("odx: task '%s' depends on unknown task '%s'", task.deps[0], dep_name)
            return false
        }

        append(in_progress, dep_name)

        if !run_deps(dep_task, mod, manifest, verbose, in_progress) {
            return false
        }

        if !exec_task(dep_name, dep_task, mod, manifest, verbose, nil) {
            fmt.eprintfln("odx: dependency '%s' failed", dep_name)
            return false
        }

        pop(in_progress)
    }

    return true
}

exec_task :: proc(
    name:     string,
    task:     module.Task,
    mod:      module.Module,
    manifest: module.Manifest,
    verbose:  bool,
    run_args: []string,
) -> bool {
    if len(task.cmd) == 0 {
        fmt.eprintfln("odx: task '%s' has no cmd defined", name)
        return false
    }

    if len(task.deps) > 0 {
        in_progress := make([dynamic]string)
        defer delete(in_progress)
        append(&in_progress, name)
        if !run_deps(task, mod, manifest, verbose, &in_progress) {
            return false
        }
    }

    use_cache := len(task.inputs) > 0 || len(task.outputs) > 0

    var_map := build_template_vars(mod, manifest)
    defer delete(var_map)

    cache_key: string
    stamp:     string

    task_start := time.now()
    events.emit(events.Task_Started{
        event = "task_started",
        task  = name,
        time  = events.now_string(context.temp_allocator),
    })

    if use_cache {
        inputs, glob_ok := resolve_globs(task.inputs, mod.root, var_map)
        defer delete(inputs)

        if glob_ok {
            key, key_ok := cache.compute_task_key({
                task_name    = name,
                profile      = "",
                target       = "",
                flags        = task.cmd,
                defines      = {},
                source_paths = inputs,
                odin_version = "",
            })

            if key_ok {
                cache_key = key
                stamp     = cache.stamp_path(name, mod.root, key)

                if cache.is_cache_hit(stamp, key) && outputs_exist(task.outputs, mod.root, var_map) {
                    events.emit(events.Cache_Hit{event = "cache_hit", task = name})
                    events.emit(events.Task_Finished{
                        event      = "task_finished",
                        task       = name,
                        elapsed_ms = time.duration_milliseconds(time.diff(task_start, time.now())),
                        success    = true,
                    })
                    fmt.printfln("odx: task '%s' up-to-date (cached)", name)
                    return true
                }

                events.emit(events.Cache_Miss{event = "cache_miss", task = name})
            }
        }
    }

    argv := make([dynamic]string)
    defer delete(argv)

    for part in task.cmd {
        append(&argv, expand_vars(part, var_map, run_args))
    }

    env := make([dynamic]string)
    defer delete(env)

    for k, v in task.env {
        append(&env, fmt.aprintf("%s=%s", k, v))
    }

    if verbose {
        fmt.println(strings.join(argv[:], " "))
    }

    events.emit(events.Command_Exec{
        event   = "command_exec",
        task    = name,
        command = argv[:],
    })

    desc := os2.Process_Desc{
        command = argv[:],
        env     = env[:] if len(env) > 0 else nil,
    }

    state, stdout, stderr, run_err := os2.process_exec(desc, context.allocator)
    if run_err != nil {
        events.emit(events.Task_Finished{
            event      = "task_finished",
            task       = name,
            elapsed_ms = time.duration_milliseconds(time.diff(task_start, time.now())),
            success    = false,
        })
        fmt.eprintfln("odx: failed to launch task '%s': %v", name, run_err)
        return false
    }

    if len(stdout) > 0 do fmt.print(string(stdout))
    if len(stderr) > 0 do fmt.eprint(string(stderr))

    if state.exit_code != 0 {
        events.emit(events.Task_Finished{
            event      = "task_finished",
            task       = name,
            elapsed_ms = time.duration_milliseconds(time.diff(task_start, time.now())),
            success    = false,
        })
        fmt.eprintfln("odx: task '%s' failed (exit code %d)", name, state.exit_code)
        return false
    }

    if use_cache && cache_key != "" {
        cache.write_stamp(stamp, cache_key)
    }

    events.emit(events.Task_Finished{
        event      = "task_finished",
        task       = name,
        elapsed_ms = time.duration_milliseconds(time.diff(task_start, time.now())),
        success    = true,
    })
    fmt.printfln("odx: task '%s' completed", name)
    return true
}

@(private)
resolve_globs :: proc(patterns: []string, root: string, vars: map[string]string) -> (files: []string, ok: bool) {
    out := make([dynamic]string)

    for pat in patterns {
        expanded := pat
        for k, v in vars {
            expanded, _ = strings.replace_all(expanded, k, v)
        }

        abs_pat := expanded if filepath.is_abs(expanded) else filepath.join({root, expanded})

        matches, glob_err := filepath.glob(abs_pat)
        if glob_err != .None {
            delete(out)
            return nil, false
        }

        for m in matches {
            append(&out, m)
        }
    }

    return out[:], true
}

@(private)
outputs_exist :: proc(patterns: []string, root: string, vars: map[string]string) -> bool {
    if len(patterns) == 0 do return false

    for pat in patterns {
        expanded := pat
        for k, v in vars {
            expanded, _ = strings.replace_all(expanded, k, v)
        }

        abs_path := expanded if filepath.is_abs(expanded) else filepath.join({root, expanded})

        is_glob := strings.contains_any(abs_path, "*?[")

        if is_glob {
            matches, glob_err := filepath.glob(abs_path)
            if glob_err != .None || len(matches) == 0 {
                return false
            }
        } else {
            if !os.exists(abs_path) {
                return false
            }
        }
    }

    return true
}

@(private)
build_template_vars :: proc(mod: module.Module, manifest: module.Manifest) -> map[string]string {
    vars := make(map[string]string)

    out_dir :=  filepath.join({mod.root, manifest.out_dir})
    profile := manifest.build.default_profile
    target := manifest.build.default_target
    name := manifest.name

    if name == "" {
        name = mod.name
    }
    
    vars["{module_root}"] = mod.root
    vars["{out_dir}"]     = out_dir
    vars["{gen_dir}"]     = filepath.join({mod.root, manifest.out_dir, "gen"})
    vars["{profile}"]     = profile
    vars["{target}"]      = target
    vars["{name}"]        = name
    vars["{cache_dir}"]   = cache.get_cache_dir()
    vars["{bin_dir}"]     = filepath.join({out_dir, target, profile, "bin"})

    return vars
}

@(private)
expand_vars :: proc(s: string, vars: map[string]string, run_args: []string) -> string {
    if s == "{args}" {
        return strings.join(run_args, " ")
    }
    result := s
    for k, v in vars {
        result, _ = strings.replace_all(result, k, v)
    }
    return result
}
