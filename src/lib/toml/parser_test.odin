package toml

import "core:fmt"
import "core:testing"

@(test)
test_basic :: proc(t: ^testing.T) {
    src := `
[project]
name = "myapp"
out_dir = "build"

[profiles.dev]
flags = ["-debug", "-o:none"]
defines = { LOG_LEVEL = "debug" }
`
    table, ok, err := parse(src)
    if !ok {
        fmt.printfln("parse error line %d: %s", err.line, err.msg)
        testing.fail(t)
        return
    }

    testing.expect_value(t, get_string(table, "project.name"), "myapp")
    testing.expect_value(t, get_string(table, "project.out_dir"), "build")

    flags := get_array(table, "profiles.dev.flags")
    testing.expect_value(t, len(flags), 2)
    testing.expect_value(t, flags[0], "-debug")

    defines := get_table(table, "profiles.dev.defines")
    testing.expect(t, defines != nil)
    level, _ := defines["LOG_LEVEL"].(string)
    testing.expect_value(t, level, "debug")
}
