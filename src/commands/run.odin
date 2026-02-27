package commands

import "core:fmt"
import "core:os/os2"
import "core:path/filepath"
import "src:module"
import "src:watch"

Run_Args :: struct {
    path:     string,
    profile:  string,
    target:   string,
    verbose:  bool,
    watch:    bool,
    run_args: []string,
}

run :: proc(a: Run_Args) -> bool {
    if a.watch {
        return run_watch(a)
    }
    return run_once(a)
}

@(private)
run_once :: proc(a: Run_Args) -> bool {
    bin_path, ok := build_binary({
        path    = a.path,
        profile = a.profile,
        target  = a.target,
        verbose = a.verbose,
    })
    if !ok do return false

    if pre_run_hooks(a.path, a.verbose) == .Failed do return false

    argv := make([dynamic]string)
    defer delete(argv)

    append(&argv, bin_path)
    for arg in a.run_args {
        append(&argv, arg)
    }

    if a.verbose {
        fmt.println("running:", bin_path)
    }

    state, _, _, run_err := os2.process_exec({command = argv[:]}, context.allocator)
    if run_err != nil {
        fmt.eprintfln("odx: failed to launch binary: %v", run_err)
        return false
    }

    if state.exit_code != 0 {
        fmt.eprintfln("odx: program exited with code %d", state.exit_code)
        return false
    }

    return true
}

@(private)
run_watch :: proc(a: Run_Args) -> bool {
    for {
        bin_path, build_ok := build_binary({
            path    = a.path,
            profile = a.profile,
            target  = a.target,
            verbose = a.verbose,
        })

        proc_handle: os2.Process
        process_started := false

        if build_ok && pre_run_hooks(a.path, a.verbose) != .Failed {
            argv := make([dynamic]string)
            append(&argv, bin_path)
            for arg in a.run_args {
                append(&argv, arg)
            }

            if a.verbose {
                fmt.println("running:", bin_path)
            }

            handle, start_err := os2.process_start(os2.Process_Desc{
                command = argv[:],
                stdin   = os2.stdin,
                stdout  = os2.stdout,
                stderr  = os2.stderr,
            })

            if start_err == nil {
                proc_handle      = handle
                process_started  = true
            } else {
                fmt.eprintfln("odx: failed to start binary: %v", start_err)
            }
        }

        sources := watch_sources(a.path)
        fmt.println("odx: watching for changes...")
        watch.wait_for_change(sources)
        delete(sources)

        if process_started {
            _ = os2.process_kill(proc_handle)
            _, _ = os2.process_wait(proc_handle)
            _ = os2.process_close(proc_handle)
        }

        fmt.println("\nodx: change detected, restarting...")
    }
}

Hook_Result :: enum { OK, Failed, NoManifest }

pre_run_hooks :: proc(path: string, verbose: bool) -> Hook_Result {
    mod, ok := module.resolve(path)
    if !ok do return .Failed

    if !mod.has_manifest do return .NoManifest

    manifest_path := filepath.join({mod.root, "odx.toml"})
    manifest, man_ok := module.load_manifest(manifest_path)
    if !man_ok do return .Failed

    if len(manifest.build.pre_run) == 0 do return .OK

    if !run_hooks(manifest.build.pre_run, mod, manifest, verbose) {
        return .Failed
    }
    return .OK
}
