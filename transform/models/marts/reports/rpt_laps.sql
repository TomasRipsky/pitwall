-- grain: one row per lap of a driver in a Race or Sprint session
-- Only what the lap chart and the pace charts need: this is the largest file the browser loads.
select
    session_key,
    driver_number,
    lap_number,
    position_end_of_lap as position,
    compound,
    tyre_age_laps,
    neutralisation
from {{ ref('fct_laps') }}
