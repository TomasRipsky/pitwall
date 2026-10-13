-- grain: one row per Race or Sprint session
with sessions as (
    select * from {{ ref('dim_sessions') }}
),

meetings as (
    select * from {{ ref('dim_meetings') }}
),

laps as (
    select
        session_key,
        max(lap_number) as laps,
        count(distinct driver_number) as drivers,
        count(*) as driver_laps,
        countif(lap_time_s is not null) as timed_laps,
        count(distinct if(neutralisation is not null, lap_number, null)) as neutralised_laps,
        count(distinct if(neutralisation = 'RED', lap_number, null)) as red_flag_laps
    from {{ ref('fct_laps') }}
    group by session_key
),

stops as (
    select
        session_key,
        count(*) as pit_stops,
        countif(source = 'pit') as timed_pit_stops,
        countif(is_under_neutralisation) as pit_stops_under_neutralisation,
        -- a stop under green flag: what pitting really costs at this circuit
        approx_quantiles(
            if(source = 'pit' and not is_under_neutralisation, pit_lane_time_s, null), 2
        )[offset(1)] as median_pit_lane_s
    from {{ ref('fct_pit_stops') }}
    group by session_key
),

results as (
    select
        session_key,
        countif(grid_position is not null) > 0 as grid_published
    from {{ ref('fct_session_results') }}
    group by session_key
),

winners as (
    select
        results.session_key,
        results.driver_number,
        results.grid_position,
        drivers.full_name,
        drivers.name_acronym,
        drivers.team_name,
        drivers.team_colour_hex
    from {{ ref('fct_session_results') }} as results
    inner join {{ ref('dim_session_drivers') }} as drivers
        on drivers.session_key = results.session_key
        and drivers.driver_number = results.driver_number
    where results.finish_position = 1
)

select
    sessions.session_key,
    sessions.meeting_key,
    sessions.season,
    sessions.session_name,
    format_date('%Y-%m-%d', date(sessions.starts_at)) as race_date,
    meetings.meeting_name,
    meetings.country_name,
    meetings.circuit_short_name,
    meetings.circuit_type,
    laps.laps,
    laps.drivers,
    laps.driver_laps,
    round(safe_divide(laps.timed_laps, laps.driver_laps), 4) as timed_laps_share,
    laps.neutralised_laps,
    laps.red_flag_laps,
    coalesce(stops.pit_stops, 0) as pit_stops,
    coalesce(stops.pit_stops_under_neutralisation, 0) as pit_stops_under_neutralisation,
    case
        when coalesce(stops.pit_stops, 0) = 0 then 'none'
        when stops.timed_pit_stops = stops.pit_stops then 'official'
        when stops.timed_pit_stops = 0 then 'inferred'
        else 'mixed'
    end as pit_timing,
    round(stops.median_pit_lane_s, 1) as median_pit_lane_s,
    coalesce(results.grid_published, false) as grid_published,
    winners.driver_number as winner_driver_number,
    winners.full_name as winner_name,
    winners.name_acronym as winner_acronym,
    winners.team_name as winner_team,
    winners.team_colour_hex as winner_team_colour_hex,
    winners.grid_position as winner_grid_position
from sessions
inner join meetings on meetings.meeting_key = sessions.meeting_key
inner join laps on laps.session_key = sessions.session_key
left join stops on stops.session_key = sessions.session_key
left join results on results.session_key = sessions.session_key
left join winners on winners.session_key = sessions.session_key
