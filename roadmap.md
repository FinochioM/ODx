# 0.2.0
**`--define` / `--flag` CLI overrides**  
Merge CLI-supplied defines and flags on top of the active profile. Included in cache key :: **DONE**

**Richer template variables**  
Add `{env.VAR}`, `{bin_dir}`, `{name}`, `{cache_dir}` to task templates.  **DONE**

**`--allow-shell` + per-task `shell = true`**  
Opt-in shell execution for tasks. Shell is never on without explicit user intent. **DONE**

**User tasks can depend on built-ins**  
`deps = ["compile"]` works for example. **DONE**

**Structured Odin diagnostics**  
Parse compiler stderr into file/line/col. Clean output + `Diagnostic` JSON events. **DONE**

**`--explain` flag**  
Print the task graph that would run, then exit. Make it work with `--json` too.

**Parallel task execution (`--jobs N`)**  
New `src/engine/scheduler.odin`. Independent tasks run concurrently. Default: logical CPU count.

**`odx package`**  
Build + archive binary and declared extras into a `.tar.gz` / `.zip`.

**Workspace support**  
`workspace.toml` discovery, member glob expansion, `odx workspace list/build/test/clean`.
