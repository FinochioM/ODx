package cli

import "core:c/libc"
import "core:fmt"
import "core:os"
import "core:strings"

Command :: enum {
    Run,
    Build,
    Test,
    Check,
    Clean,
    Task,
    List,
    Doctor,
}

Args :: struct {
    command  : Command,
    path     : string,
    profile  : string,
    target   : string,
    out      : string,
    task_name: string,
    verbose  : bool,
    quiet    : bool,
    no_cache : bool,
    clean_all: bool,
    raw_args : []string,
    json     : bool,
    watch    : bool,
    defines  : [dynamic]string,
    flags    : [dynamic]string,
    allow_shell: bool,
    explain : bool,
}

parse :: proc(argv: []string) -> Args {
    if len(argv) == 0 {
        print_usage()
        os.exit(0)
    }

    args: Args
    args.path = "."
    args.defines = make([dynamic]string)
    args.flags   = make([dynamic]string)

    switch argv[0] {
    case "run":    args.command = .Run
    case "build":  args.command = .Build
    case "test":   args.command = .Test
    case "check":  args.command = .Check
    case "clean":  args.command = .Clean
    case "task":   args.command = .Task
    case "list":   args.command = .List
    case "doctor": args.command = .Doctor
    case:
        fmt.eprintfln("odx: unknown command '%s'", argv[0])
        os.exit(1)
    }

    rest := argv[1:]

    if args.command == .Task && len(rest) > 0 && rest[0][0] != '-' {
        args.task_name = rest[0]
        rest = rest[1:]
    }

    for i := 0; i < len(rest); i += 1 {
        switch {
        case rest[i] == "-v" || rest[i] == "--verbose":
            args.verbose = true
        case rest[i] == "-q" || rest[i] == "--quiet":
            args.quiet = true
        case rest[i] == "--no-cache":
            args.no_cache = true
        case rest[i] == "--":
            args.raw_args = rest[i+1:]
            return args
        case rest[i] == "--profile" || rest[i] == "-p":
            if i+1 < len(rest) {
                i += 1
                args.profile = rest[i]
            }
        case rest[i] == "--target":
            if i+1 < len(rest) {
                i += 1
                args.target = rest[i]
            }
        case rest[i] == "-o":
            if i+1 < len(rest) {
                i += 1
                args.out = rest[i]
            }
        case rest[i] == "--define":
            if i+1 < len(rest) {
                i += 1
                append(&args.defines, rest[i])
            }
        case rest[i] == "--flag":
            if i+1 < len(rest) {
                i += 1
                append(&args.flags, rest[i])
            }
        case rest[i] == "--allow-shell":
            args.allow_shell = true
        case rest[i] == "--explain":
            args.explain == true
        case rest[i] == "--watch":
            args.watch = true
        case rest[i] == "--json":
            args.json = true
        case rest[i] == "--all":
            args.clean_all = true
        case strings.has_prefix(rest[i], "--profile="):
            args.profile = rest[i][len("--profile="):]
        case strings.has_prefix(rest[i], "--target="):
            args.target = rest[i][len("--target="):]
        case strings.has_prefix(rest[i], "-o="):
            args.out = rest[i][len("-o="):]
        case strings.has_prefix(rest[i], "--define="):
            append(&args.defines, rest[i][len("--define="):])
        case strings.has_prefix(rest[i], "--flag="):
            append(&args.flags, rest[i][len("--flag="):])
        case len(rest[i]) > 0 && rest[i][0] != '-':
            args.path = rest[i]
        }
    }

    return args
}

@(private)
print_usage :: proc() {
    fmt.println(
`Usage: odx <command> [path] [flags]

Commands:
  run     Build and run
  build   Build only
  test    Run tests
  check   Type-check only
  clean   Remove build outputs
  task    Run a named task
  list    List modules and tasks
  doctor  Show environment info

Flags:
  --profile dev|release|test
  --target  host|<triple>
  -o <path>
  --define  K=V   (repeatable, merged on top of profile)
  --flag    F     (repeatable, merged on top of profile)
  -v / --verbose
  -q / --quiet
  --no-cache
  --watch
  --allow-shell
  --explain`)
}
