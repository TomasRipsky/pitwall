-- grain: one row per lap of a driver in a Race or Sprint session
-- Only what the lap chart and the pace charts need: this is the largest file the browser loads.
select
    session_key,
    driver_number,
    lap_number,
    position_end_of_lap as position,
    round(lap_time_s, 3) as lap_time_s,
    compound,
    tyre_age_laps,
    neutralisation,
    is_pit_in_lap or is_pit_out_lap as is_pit_lap,
    is_clean_lap
from {{ ref('fct_laps') }}
