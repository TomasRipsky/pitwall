-- grain: one row per stint (a set of tyres used by a driver in a session)
with stints as (
    select * from {{ ref('fct_stints') }}
),

driver_races as (
    select * from {{ ref('rpt_driver_races') }}
),

races as (
    select * from {{ ref('rpt_races') }}
),

drivers as (
    select * from {{ ref('dim_session_drivers') }}
)

select
    stints.session_key,
    stints.driver_number,
    stints.stint_number,
    races.season,
    races.session_name,
    races.meeting_name,
    races.circuit_short_name,
    drivers.name_acronym,
    drivers.full_name,
    drivers.team_name,
    drivers.team_colour_hex,
    stints.compound,
    stints.first_lap,
    stints.last_lap,
    stints.laps_in_stint,
    stints.tyre_age_at_start,
    stints.clean_laps,
    round(stints.degradation_s_per_lap, 4) as degradation_s_per_lap,
    driver_races.finish_position,
    driver_races.grid_position
from stints
inner join races on races.session_key = stints.session_key
inner join drivers
    on drivers.session_key = stints.session_key
    and drivers.driver_number = stints.driver_number
left join driver_races
    on driver_races.session_key = stints.session_key
    and driver_races.driver_number = stints.driver_number
