<img align="left" style="width:240px" src="logo/odx.png" width="288px">

<br>
<br>
<br>

**A build tool for [Odin](https://odin-lang.org/).** <br>
Odx is an unofficial build tool/system for the Odin programming language. <br>
It handles building, running, testing and caching for Odin projects.

*NOTE: This is an unofficial project & it is being actively developed, meaning some things could be changed in future versions.*

---
<br clear="left">

[![Made with Odin](https://img.shields.io/badge/made%20with-Odin-blue)](https://odin-lang.org/)
[![GitHub Releases Downloads](https://img.shields.io/github/downloads/FinochioM/ODx/total)](https://github.com/FinochioM/ODx/releases)
[![GitHub Stars](https://img.shields.io/github/stars/FinochioM/ODx?style=flat&label=stars)](https://github.com/FinochioM/ODx/stargazers)
[![GitHub commits since tagged version](https://img.shields.io/github/commits-since/FinochioM/ODx/latest)](https://github.com/FinochioM/ODx/commits/master)
[![License](https://img.shields.io/github/license/FinochioM/ODx)](LICENSE)

[![GitHub Release](https://img.shields.io/github/v/release/FinochioM/ODx)](https://github.com/FinochioM/ODx/releases/latest)
[![Build](https://github.com/FinochioM/ODx/actions/workflows/release.yml/badge.svg)](https://github.com/FinochioM/ODx/actions/workflows/release.yml)

## Installation 

**Prebuilt binary**

You can download one of the auto-generated binaries from [Releases](https://github.com/FinochioM/ODx/releases) and put it somewhere on your `PATH`.

**Build from source**

You can also just build from source, which is better in my opinion.

It requires odin to be installed.

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

## Roadmap
Future changes or bug fixes might be added [here](roadmap.md) (if I remember to do it)