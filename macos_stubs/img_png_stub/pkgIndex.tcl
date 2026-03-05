# img::png compatibility stub for macOS with Tk 8.6+
#
# Tk 8.6 and later include native PNG support in the photo image subsystem.
# "image create photo -format png" works without tkimg on Tk 8.6+.
# This stub satisfies "package require img::png 1.3" so the app starts.

package ifneeded img::png 1.3 {
    package provide img::png 1.3
}
