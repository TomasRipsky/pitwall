-- grain: one row per undercut attempt (an attacker pitting before the car directly ahead)
with attempts as (
    select * from {{ ref('fct_undercut_attempts') }}
),

races as (
    select * from {{ ref('rpt_races') }}
),

drivers as (
    select * from {{ ref('dim_session_drivers') }}
)

select
    attempts.session_key,
    attempts.attacker_driver_number,
    attempts.defender_driver_number,
    attempts.attacker_pit_lap,
    attempts.defender_pit_lap,
    attempts.defender_pit_lap - attempts.attacker_pit_lap as laps_between_stops,
    races.season,
    races.session_name,
    races.meeting_name,
    races.circuit_short_name,
    attacker.name_acronym as attacker,
    attacker.team_name as attacker_team,
    defender.name_acronym as defender,
    defender.team_name as defender_team,
    attempts.is_success,
    attempts.attacker_pitted_under_neutralisation
from attempts
inner join races on races.session_key = attempts.session_key
inner join drivers as attacker
    on attacker.session_key = attempts.session_key
    and attacker.driver_number = attempts.attacker_driver_number
inner join drivers as defender
    on defender.session_key = attempts.session_key
    and defender.driver_number = attempts.defender_driver_number
