#!/usr/bin/env fish
function progress_bar
    # Define the date range
    set start_date 2025-03-17
    set end_date 2025-11-03
    set current_date (date +"%Y-%m-%d")

    # Convert dates to seconds 
    set start_seconds (date -j -f "%Y-%m-%d" $start_date "+%s")
    set end_seconds (date -j -f "%Y-%m-%d" $end_date "+%s")
    set current_seconds (date -j -f "%Y-%m-%d" $current_date "+%s")

    # Calculate durations
    set total_duration (math "$end_seconds - $start_seconds")
    set elapsed_time (math "$current_seconds - $start_seconds")

    # Calculate percentage with bounds checking
    set percentage 0
    if test $current_seconds -ge $end_seconds
        set percentage 100
    else if test $current_seconds -gt $start_seconds
        set percentage (math "round(($elapsed_time / $total_duration) * 100)")
    end

    # Progress bar settings
    set bar_width 80
    set filled_width (math "round($bar_width * $percentage / 100)")
    set empty_width (math "$bar_width - $filled_width")

    # Define characters and colors
    set filled_char "█"
    set empty_char "░"
    set green (set_color green)
    set blue (set_color blue)
    set red (set_color red)
    set yellow (set_color yellow)
    set reset (set_color normal)

    # Create the progress bar
    echo -n "["
    for i in (seq 1 $filled_width)
        echo -n $green$filled_char$reset
    end
    for i in (seq 1 $empty_width)
        echo -n $empty_char
    end
    echo -n "] "$green$percentage"%"$reset

    # Calculate days
    set days_passed (math "round($elapsed_time / 86400)")
    set days_total (math "round($total_duration / 86400)")
    set days_remaining (math "$days_total - $days_passed")

    # Print days information
    echo
    echo $yellow""$green$days_passed$yellow" out of "$blue$days_total$yellow""$yellow" ("$red$days_remaining$yellow" remains)"$reset
    echo
end
