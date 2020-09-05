use math

# Define a `now` function to allow us to determine the current time as
# fractional seconds since the epoch. Use the best implementation based
# on the capabilities of the system.
fn now []{ }
if (has-external gdate) {
    # Presumably we're on a macOS system where I've installed the GNU
    # date utility via Homebrew; i.e., `brew install coreutils`.
    now~ = []{ float64 (gdate '+%s.%N') }
} else {
    try {
        now~ = []{ float64 (date '+%s.%N') }
        now >/dev/null 2>&1
    } except e {
        # Must be a BSD system which doesn't support %N and where we don't
        # have GNU date installed as `gdate`. So simply accept that a
        # resolution of seconds is the best we can do.
        now~ = []{ float64 (date '+%s') }
    }
}

duration = (float64 0)
start-time = (now)

fn before-readline []{
    end-time = (now)
    duration = (- $end-time $start-time)
}

fn after-readline [cmd]{
    start-time = (now)
}

# WARNING: This requires an external `printf` command. Ideally that wouldn't
# be a dependency but at this time Elvish doesn't provide an equivalent
# command.
fn human-readable []{
    if (>= 1 $duration) {
        # Up to one second display milliseconds.
        d = (math:round (* $duration 1000))
        put $d" ms"
    } elif (>= 60 $duration) {
        # Up to one minute display fractional seconds.
        d = (printf '%.1f' $duration)
        put $d" s"
    } elif (>= 3600 $duration) {
        # Up to one hour display fractional minutes.
        d = (printf '%.1f' (/ $duration 60))
        put $d" m"
    } else {
        # Otherwise display fractional hours.
        d = (printf '%.1f' (/ $duration 3600))
        put $d" h"
    }
}

# Arrange for the functions needed to compute the command duration to be run.
edit:before-readline = [ $@edit:before-readline $before-readline~ ]
edit:after-readline = [ $@edit:after-readline $after-readline~ ]
