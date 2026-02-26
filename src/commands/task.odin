package commands

import "core:fmt"
import "core:os/os2"
import "core:path/filepath"
import "core:strings"
import "src:module"

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

    argv := make([dynamic]string)
    defer delete(argv)

    vars := build_template_vars(mod, manifest)
    defer delete(vars)

    for part in task.cmd {
        append(&argv, expand_vars(part, vars, run_args))
    }

    env := make([dynamic]string)
    defer delete(env)

    for k, v in task.env {
        append(&env, fmt.aprintf("%s=%s", k, v))
    }

    if verbose {
        fmt.println(strings.join(argv[:], " "))
    }

    desc := os2.Process_Desc{
        command = argv[:],
        env     = env[:] if len(env) > 0 else nil,
    }

    state, stdout, stderr, run_err := os2.process_exec(desc, context.allocator)
    if run_err != nil {
        fmt.eprintfln("odx: failed to launch task '%s': %v", name, run_err)
        return false
    }

    if len(stdout) > 0 do fmt.print(string(stdout))
    if len(stderr) > 0 do fmt.eprint(string(stderr))

    if state.exit_code != 0 {
        fmt.eprintfln("odx: task '%s' failed (exit code %d)", name, state.exit_code)
        return false
    }

    fmt.printfln("odx: task '%s' completed", name)
    return true
}

@(private)
build_template_vars :: proc(mod: module.Module, manifest: module.Manifest) -> map[string]string {
    vars := make(map[string]string)
    vars["{module_root}"] = mod.root
    vars["{out_dir}"]     = filepath.join({mod.root, manifest.out_dir})
    vars["{gen_dir}"]     = filepath.join({mod.root, manifest.out_dir, "gen"})
    vars["{profile}"]     = manifest.build.default_profile
    vars["{target}"]      = manifest.build.default_target
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
