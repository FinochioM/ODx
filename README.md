# odx

A build tool for [Odin](https://odin-lang.org/).
_This is mostly a hobby project, odin is the language I default to and I started this project as a practice exercise_

## Installation

**Prebuilt binary**

You can download one of the auto-generated binaries from [Releases](https://github.com/FinochioM/ODx/releases) and put it somewhere on your `PATH`.

**Build from source**

You can also just build from source, which is better in my opinion.

It requires [Odin](https://odin-lang.org/) to be installed.

```sh
git clone https://github.com/FinochioM/odx
cd odx
odin build src -collection:src=src -out:build/odx
```

## Commands

```
odx build  [path]            Build the project
odx run    [path] -- [args]  Build and run
odx test   [path]            Run tests
odx check  [path]            Type-check only, no output binary
odx clean  [path]            Remove build outputs
odx task   <name> [path]     Run a named task from odx.toml
odx list   [path]            List modules and tasks
odx doctor                   Print environment info
```

## Flags

```
--profile dev|release|test   Build profile (default: dev)
--target  <triple>           Target platform (default: host)
-o <path>                    Output binary path
--watch                      Rerun on file changes
--no-cache                   Force rebuild
--json                       Machine-readable output
-v / --verbose               Print full commands
```

## Configuration

Config is optional. Create an `odx.toml` at your project root to configure profiles, targets, collections, dependencies, and tasks.

```toml
[project]
name    = "bestappever"
root    = "sauce"
out_dir = "dist"

[profiles.dev]
flags   = ["-debug"]

[profiles.release]
flags   = ["-o:speed", "-no-bounds-check"]

[tasks.tell_the_truth]
cmd     = ["echo", "nerf singed", "--out", "{gen_dir}"]
inputs  = ["some_input"]
outputs = ["{gen_dir}/**"]

[build]
pre_build = ["tasks.tell_the_truth"]

[deps]
mylib = { path = "../libs/mylib" }
```

Without a config file, odx looks for `src/main.odin` or `main.odin` and builds from there.

## Caching

Builds are cached by content hash. A task only reruns if its source files, flags, defines, or tool version changed. use the `--no-cache` flag to force a full rebuild.
