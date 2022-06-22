use unix

fn -ulimit-hdr {||
        printf "%-10s %10s %10s\n" "resource" "current" "maximum"
        printf "%-10s %10s %10s\n" "==========" "==========" "=========="
}

fn -ulimit-print {|resource vals|
    var cur max = unlimited unlimited
    if (has-key $vals cur) {
        set cur = $vals[cur]
    }
    if (has-key $vals max) {
        set cur = $vals[cur]
    }
    printf "%-10s %10v %10v\n" $resource $cur $max
}

# Usage:
#   ulimit
#      Display all resource limits.
#   ulimit $resource
#      Display one resource limit.
#   ulimit $resource $value
#      Update a resource limit. The value can be an integer, or the strings
#      "inf" or "unlimited".
fn ulimit {|@args|
    if (== 0 (count $args)) {
        # Display all resource limits.
        -ulimit-hdr
        for resource [(keys $unix:rlimits | order)] {
            -ulimit-print $resource $unix:rlimits[$resource]
        }
    } elif (== 1 (count $args)) {
        # Display one resource limit.
        var resource = $args[0]
        if (has-key $unix:rlimits $resource) {
            -ulimit-hdr
            -ulimit-print $resource $unix:rlimits[$resource]
        } else {
            fail "no such resource: "$resource
        }
    } elif (== 2 (count $args)) {
        # Modify the current limit for a resource.
        var resource value = $args[0] $args[1]
        if (not (has-key $unix:rlimits $resource)) {
            fail "no such resource: "$resource
        }
        if (or (eq $value "inf") (eq $value "unlimited")) {
            del unix:rlimits[$resource][cur]
        } else {
            try {
                set value = (num $value)
            } catch {
                fail $resource" value "$value" is not a number"
            }
            set unix:rlimits[$resource][cur] = $value
        }
    } else {
        fail "expected at most two arguments, got "(count $args)
    }
}
