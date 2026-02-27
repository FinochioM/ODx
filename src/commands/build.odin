package commands

import "core:fmt"
import "core:os"
import "core:os/os2"
import "core:path/filepath"
import "core:strings"
import "core:time"
import "src:cache"
import "src:deps"
import "src:events"
import "src:module"
import "src:watch"

Build_Args :: struct {
    path:     string,
    profile:  string,
    target:   string,
    out:      string,
    verbose:  bool,
    no_cache: bool,
    watch:    bool,
    cli_flags: []string,
    cli_defines: []string,
}

build :: proc(a: Build_Args) -> bool {
    if a.watch {
        return build_watch(a)
    }
    _, ok := build_binary(a)
    return ok
}

@(private)
build_watch :: proc(a: Build_Args) -> bool {
    for {
        build_binary(a)

        sources := watch_sources(a.path)
        defer delete(sources)

        fmt.println("odx: watching for changes...")
        watch.wait_for_change(sources)
        fmt.println("\nodx: change detected, rebuilding...")
    }
}

build_binary :: proc(a: Build_Args) -> (bin_path: string, ok: bool) {
    mod, mod_ok := module.resolve(a.path)
    if !mod_ok do return "", false

    manifest: module.Manifest
    has_manifest := false

    if mod.has_manifest {
        manifest_path := filepath.join({mod.root, "odx.toml"})
        manifest, has_manifest = module.load_manifest(manifest_path)
        if !has_manifest do return "", false
    }

    entry, entry_ok := module.resolve_entry(mod, manifest, has_manifest)
    if !entry_ok do return "", false

    extra_collections := make(map[string]string)
    defer delete(extra_collections)

    if has_manifest && len(manifest.deps) > 0 {
        resolved, deps_ok := deps.resolve_all(mod, manifest)
        if !deps_ok do return "", false

        deps.write_lock(mod.root, resolved)

        for r in resolved {
            extra_collections[r.name] = r.path
        }
    }

    profile := a.profile
    if profile == "" {
        profile = manifest.build.default_profile if has_manifest else "dev"
    }

    target := a.target
    if target == "" {
        target = manifest.build.default_target if has_manifest else "host"
    }

    name := mod.name
    if has_manifest && manifest.name != "" {
        name = manifest.name
    }

    out_dir := "build"
    if has_manifest && manifest.out_dir != "" {
        out_dir = manifest.out_dir
    }

    bin_dir := filepath.join({mod.root, out_dir, target, profile, "bin"})
    if !cache.make_dir_all(bin_dir) {
        fmt.eprintfln("odx: could not create output dir '%s'", bin_dir)
        return "", false
    }

    bin_name := name
    when ODIN_OS == .Windows {
        bin_name = strings.concatenate({name, ".exe"})
    }

    bin_path = a.out if a.out != "" else filepath.join({bin_dir, bin_name})

    odin_cmd := "odin"
    if has_manifest && manifest.build.odin_cmd != "" {
        odin_cmd = manifest.build.odin_cmd
    }

    if has_manifest && len(manifest.build.pre_build) > 0 {
        if !run_hooks(manifest.build.pre_build, mod, manifest, a.verbose) {
            return "", false
        }
    }

    task_start := time.now()
    events.emit(events.Task_Started{
        event = "task_started",
        task  = "build",
        time  = events.now_string(context.temp_allocator),
    })

    profile_flags:   []string
    profile_defines: map[string]string

    if has_manifest {
        if p, found := manifest.profiles[profile]; found {
            profile_flags   = p.flags
            profile_defines = p.defines
        }
    }

    flags, defines := merge_profile_overrides(
        profile_flags,
        profile_defines,
        a.cli_flags,
        a.cli_defines,
    )

    if !a.no_cache {
        sources, src_ok := module.collect_sources(mod.root)
        if src_ok {
            odin_ver := get_odin_version(context.temp_allocator)
            key, key_ok := cache.compute_task_key({
                task_name    = "build",
                profile      = profile,
                target       = target,
                flags        = flags,
                defines      = defines,
                source_paths = sources,
                odin_version = odin_ver,
            })

            if key_ok {
                stamp := cache.stamp_path("build", mod.root, key)
                if cache.is_cache_hit(stamp, key) && os.exists(bin_path) {
                    events.emit(events.Cache_Hit{event = "cache_hit", task = "build"})
                    events.emit(events.Task_Finished{
                        event      = "task_finished",
                        task       = "build",
                        elapsed_ms = time.duration_milliseconds(time.diff(task_start, time.now())),
                        success    = true,
                    })
                    fmt.printfln("odx: %s (cached)", bin_path)
                    return bin_path, true
                }
                events.emit(events.Cache_Miss{event = "cache_miss", task = "build"})

                defer cache.write_stamp(stamp, key)
            }
        }
    }

    argv := make([dynamic]string)
    defer delete(argv)

    append(&argv, odin_cmd, "build", entry, fmt.aprintf("-out:%s", bin_path))

    for flag in flags {
        append(&argv, flag)
    }
    for k, v in defines {
        append(&argv, fmt.aprintf("-define:%s=%s", k, v))
    }

    if has_manifest {
        for col_name, rel_path in manifest.build.collections {
            abs_path := filepath.join({mod.root, rel_path})
            append(&argv, fmt.aprintf("-collection:%s=%s", col_name, abs_path))
        }
        for col_name, abs_path in extra_collections {
            append(&argv, fmt.aprintf("-collection:%s=%s", col_name, abs_path))
        }
    } else if profile == "dev" {
        append(&argv, "-debug")
    }

    if a.verbose {
        fmt.println(strings.join(argv[:], " "))
    }

    events.emit(events.Command_Exec{
        event   = "command_exec",
        task    = "build",
        command = argv[:],
    })

    state, _, stderr, run_err := os2.process_exec({command = argv[:]}, context.allocator)
    if run_err != nil {
        events.emit(events.Task_Finished{event = "task_finished", task = "build", elapsed_ms = time.duration_milliseconds(time.diff(task_start, time.now())), success = false})
        fmt.eprintfln("odx: failed to launch odin: %v", run_err)
        return "", false
    }

    if state.exit_code != 0 {
        if len(stderr) > 0 {
            fmt.eprint(string(stderr))
        }
        events.emit(events.Task_Finished{event = "task_finished", task = "build", elapsed_ms = time.duration_milliseconds(time.diff(task_start, time.now())), success = false})
        fmt.eprintfln("odx: build failed (exit code %d)", state.exit_code)
        return "", false
    }

    events.emit(events.Task_Finished{
        event      = "task_finished",
        task       = "build",
        elapsed_ms = time.duration_milliseconds(time.diff(task_start, time.now())),
        success    = true,
    })
    fmt.printfln("odx: built %s", bin_path)
    return bin_path, true
}

watch_sources :: proc(path: string, allocator := context.allocator) -> []string {
    mod, ok := module.resolve(path, allocator)
    if !ok {
        return nil
    }
    sources, _ := module.collect_sources(mod.root, allocator)
    return sources
}
