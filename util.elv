use file
use flag
use os
use re
use str

# Reverse a sequence of values.
fn reverse {|@inputs|
    if (== 0 (count $inputs)) { set inputs = [[(all)]] }
    put $@inputs[(range (- (count $@inputs) 1) -1)]
}

# Filters a sequence of items and outputs those for whom the function outputs
# $true.
fn filter {|&out=$false func~ @inputs|
    if $out {
        each {|item| if (not (func $item)) { put $item } } $@inputs
    } else {
        each {|item| if (func $item) { put $item } } $@inputs
    }
}

# Like ** but only returns regular files.
#
# Takes a sequence of filename extensions to limit the output to files with
# the specified extensions. Don't include the separating dot.
fn ff {|@ext|
    fn filter {|p|
        # Ignore .git directories.
        if (re:match '(^|/)\.git(/|$)' $p) { return }
        if (== 0 (count $ext)) {
            # Emit all paths since no extensions were given.
            put $p
        } else {
            # Only emit paths matching the wanted extensions.
            each {|e|
                if (re:match '\.'$e'$' $p) { put $p; return }
            } $ext
        }
    }

    put **[type:regular] |
        each $filter~ |
        order
}

fn gitfiles {|@args|
    var @files = (git status --porcelain --short --untracked-files=all $@args |
      sort -u |
      sed -e 's/^ *[^ ]* *//')
    if (eq [] $files) {
        set @files = (git show --word-diff=porcelain --name-only --pretty=oneline $@args |
          tail -n +2 | sort -u )
    }

    for f $files {
        if ?(test -e $f) {
            put $f
        }
    }
}

fn machname {||
    use platform
    platform:hostname &strip-domain
}

# Simulate the POSIX `which` command. We do this for two reasons:
# 1) to avoid spawning an external command, and
# 2) on Windows the MSYS2 `which` command doesn't do what we want.
#
# Specifically, regarding point #2 above, the MSYS2 `which ls` command will
# output somthing like `/usr/bin/ls` where we want `c:\msys64\usr\bin\ls.exe`.
fn which {|@args|
    var all = $false
    var no-output = $false
    var arg-specs = [
      [&short=a &arg-optional=$false &arg-required=$false]
      [&short=s &arg-optional=$false &arg-required=$false]
    ]

    var flags args = (
        flag:parse-getopt $args $arg-specs ^
            &stop-after-double-dash=$true &stop-before-non-flag=$true &long-only=$false
    )

    for flag $flags {
        if (eq $flag[spec][short] a) {
            set all = $true
        }
        if (eq $flag[spec][short] s) {
            set no-output = $true
        }
    }

    if (== 0 (count $args)) {
        fail 'You have to provide at least one external command name'
    }

    var not-found = $false
    for arg $args {
        try {
            var result = (search-external $arg)
            if (eq $no-output $false) {
                put $result
            }
        } catch {
            if (eq $no-output $false) {
                fail 'External command '(printf "%q" $arg)' was not found'
            } else {
                set not-found = $true
            }
        }
    }
    if (eq $not-found $true) {
        fail 'One or more commands were not found'
    }
}

# -fenv-to-map converts the lines emitted by the e:env command into an Elvish
# map.
fn -fenv-from-json {||
    each {|l|
        var kv = [(str:split &max=2 = $l)]
        if (!= 2 (count $kv)) {
            # This should only happen if the value of an env var contains
            # newlines. Not much we can do other than ignore those lines.
            continue
        }
        put $kv
    } | make-map
}

# -fenv-to-map converts the lines emitted by the e:env command into an Elvish
# map.
fn -fenv-from-env {||
    each {|l|
        var kv = [(str:split &max=2 = $l)]
        if (!= 2 (count $kv)) {
            # This can only happen if the value of an env var contains
            # newlines. Not much we can do other than ignore those lines (and
            # use an incorrect, truncated, value for the env var). If the user
            # needs to handle this case they should install the `jq` utility.
            continue
        }
        put $kv
    } | make-map
}

# -fenv-update compares two env maps and applies the difference to the current
# environment. That is,
#
# a) env vars in the new env are added to the current env,
# b) env vars not in the new env are removed from the current env, and
# c) env vars whose value in the new env differs from the current env is
#    back-propagated to the current env.
fn -fenv-update {|&dry-run=$false old-env new-env|
    # We never want changes to these env vars propagated back into the current
    # shell process. They should be silently ignored.
    var ignored-env-vars = ['_' 'SHLVL' 'PWD' 'OLDPWD' 'XPC_SERVICE_NAME']

    for key [(keys $old-env)] {
        if (has-value $ignored-env-vars $key) {
            continue
        }
        if (not (has-key $new-env $key)) {
            if $dry-run {
                echo 'Env var deleted: '$key'='(repr $old-env[$key])
            } else {
                unset-env $key
            }
        } elif (not (eq $old-env[$key] $new-env[$key])) {
            if $dry-run {
                echo 'Env var modified: '$key
                echo '    was: '(repr $old-env[$key])
                echo '    now: '(repr $new-env[$key])
            } else {
                set-env $key $new-env[$key]
            }
        }
    }
    for key [(keys $new-env)] {
        if (has-value $ignored-env-vars $key) {
            continue
        }
        if (not (has-key $old-env $key)) {
            if $dry-run {
                echo 'Env var added: '$key'='(repr $new-env[$key])
            } else {
                set-env $key $new-env[$key]
            }
        }
    }
}

# fenv runs the script in your login shell (which is presumably a POSIX shell
# like Bash or Zsh) and propagates any changes to its environment back into
# the current Elvish process. This is useful for situations such as virtual
# environment initialization done by tools like `conda`, `pyenv` or `venv`
# which do not have native support for Elvish.
#
# This uses the `jq` command if available to correctly handle env vars whose
# value includes newlines. If `jq` isn't available it uses the `env` command
# and will not correctly handle env vars with embedded newlines.
fn fenv {|&dry-run=$false script|
    var old-env
    var new-env
    var tmpf = (os:temp-file)
    defer {
        file:close $tmpf
        os:remove $tmpf[name]
    }
    if (has-external jq) {
        set old-env = (jq -n env | from-json)
        $E:SHELL -ic $script'; jq -n env > '$tmpf[name];
        set new-env = (from-json < $tmpf)
    } else {
        set old-env = (e:env | -fenv-from-env)
        $E:SHELL -ic $script'; env > '$tmpf[name];
        set new-env = (-fenv-from-env < $tmpf)
    }
    -fenv-update &dry-run=$dry-run $old-env $new-env
}

# Deactivate an Anaconda environment.
fn coff {||
    fenv 'conda deactivate'
}

# Without an arg list the available Anaconda environments; otherwise, activate
# the named Anaconda environment.
fn con {|@args|
    if (== 0 (count $args)) {
        e:conda info --envs
        return
    }

    if (> (count $args) 1) {
        fail 'Too many args -- expected at most one conda environment name.'
    }

    fenv 'conda activate '$args[0]
}
