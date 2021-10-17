fn human-readable {|duration|
    if (> 0.001 $duration) {
        # Up to one millisecond display microseconds.
        printf '%.0f µs' (* $duration 1_000_000)
    } elif (> 1 $duration) {
        # Up to one second display milliseconds.
        printf '%.1f ms' (* $duration 1_000)
    } elif (> 60 $duration) {
        # Up to one minute display fractional seconds.
        printf '%.1f s' $duration
    } elif (> 3600 $duration) {
        # Up to one hour display fractional minutes.
        printf '%.1f m' (/ $duration 60)
    } else {
        # Otherwise display fractional hours.
        printf '%.1f h' (/ $duration 3600)
    }
}
