-- grain: one row per driver per Race or Sprint session
with results as (
    select * from {{ ref('fct_session_results') }}
),

races as (
    select * from {{ ref('rpt_races') }}
),

drivers as (
    select * from {{ ref('dim_session_drivers') }}
),

pace as (
    select
        session_key,
        driver_number,
        approx_quantiles(if(is_clean_lap, lap_time_s, null), 2)[offset(1)] as median_clean_lap_s,
        min(if(is_clean_lap, lap_time_s, null)) as best_lap_s,
        max(speed_trap_kph) as top_speed_kph
    from {{ ref('fct_laps') }}
    group by session_key, driver_number
),

field_pace as (
    -- the typical clean lap of the whole field: the yardstick each driver is compared with
    select
        session_key,
        approx_quantiles(if(is_clean_lap, lap_time_s, null), 2)[offset(1)] as field_median_clean_lap_s
    from {{ ref('fct_laps') }}
    group by session_key
),

stops as (
    select
        session_key,
        driver_number,
        count(*) as pit_stops
    from {{ ref('fct_pit_stops') }}
    group by session_key, driver_number
),

tyres as (
    -- the strategy in one string, e.g. "M-H-H": first letter of each compound, in stint order
    -- (U = the source did not name the compound: dropping it would hide a stint)
    select
        session_key,
        driver_number,
        string_agg(substr(coalesce(compound, 'UNKNOWN'), 1, 1), '-' order by stint_number) as tyres
    from {{ ref('fct_stints') }}
    group by session_key, driver_number
)

select
    results.session_key,
    results.driver_number,
    races.season,
    races.session_name,
    races.race_date,
    races.meeting_name,
    races.circuit_short_name,
    races.circuit_type,
    drivers.full_name,
    drivers.name_acronym,
    drivers.team_name,
    drivers.team_colour_hex,
    results.grid_position,
    results.finish_position,
    results.positions_gained,
    results.points,
    results.is_points_corrected,
    results.laps_completed,
    case
        when coalesce(results.did_not_start, false) then 'DNS'
        when coalesce(results.disqualified, false) then 'DSQ'
        when coalesce(results.did_not_finish, false) then 'DNF'
        else 'Finished'
    end as status,
    coalesce(stops.pit_stops, 0) as pit_stops,
    tyres.tyres,
    round(pace.median_clean_lap_s, 3) as median_clean_lap_s,
    round(pace.best_lap_s, 3) as best_lap_s,
    -- positive = slower than the field's typical clean lap, in percent
    round(100 * (safe_divide(pace.median_clean_lap_s, field_pace.field_median_clean_lap_s) - 1), 2)
        as pace_gap_pct,
    pace.top_speed_kph
from results
inner join races on races.session_key = results.session_key
inner join drivers
    on drivers.session_key = results.session_key
    and drivers.driver_number = results.driver_number
left join pace
    on pace.session_key = results.session_key
    and pace.driver_number = results.driver_number
left join field_pace on field_pace.session_key = results.session_key
left join stops
    on stops.session_key = results.session_key
    and stops.driver_number = results.driver_number
left join tyres
    on tyres.session_key = results.session_key
    and tyres.driver_number = results.driver_number
