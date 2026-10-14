-- grain: one row per pit stop
with stops as (
    select * from {{ ref('fct_pit_stops') }}
),

races as (
    select * from {{ ref('rpt_races') }}
),

drivers as (
    select * from {{ ref('dim_session_drivers') }}
)

select
    stops.session_key,
    stops.driver_number,
    stops.lap_number,
    races.season,
    races.session_name,
    races.race_date,
    races.meeting_name,
    races.circuit_short_name,
    drivers.name_acronym,
    drivers.full_name,
    drivers.team_name,
    drivers.team_colour_hex,
    stops.pit_lane_time_s,
    stops.stationary_time_s,
    stops.source,
    stops.compound_before,
    stops.compound_after,
    stops.position_before,
    stops.position_after,
    stops.neutralisation,
    stops.is_under_neutralisation
from stops
inner join races on races.session_key = stops.session_key
inner join drivers
    on drivers.session_key = stops.session_key
    and drivers.driver_number = stops.driver_number
