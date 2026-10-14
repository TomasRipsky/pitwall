-- grain: one row per driver per Race or Sprint session
with results as (
    select * from {{ ref('stg_openf1__session_result') }}
),

grid as (
    select * from {{ ref('stg_openf1__starting_grid') }}
),

sessions as (
    select * from {{ ref('stg_openf1__sessions') }}
),

grid_by_race as (
    -- OpenF1 attaches each grid to the qualifying session that produced it
    select
        race.session_key,
        grid.driver_number,
        grid.grid_position
    from grid
    inner join sessions as quali
        on quali.session_key = grid.qualifying_session_key
    inner join sessions as race
        on race.meeting_key = quali.meeting_key
        and race.session_type = 'Race'
        and race.session_name = case quali.session_name
            when 'Qualifying' then 'Race'
            when 'Sprint Qualifying' then 'Sprint'
            when 'Sprint Shootout' then 'Sprint'
        end
),

fastest_laps as (
    -- who set the fastest lap of each session (the earlier of two equal times wins, as on track)
    select
        session_key,
        array_agg(driver_number order by lap_time_s, started_at is null, started_at limit 1)[offset(0)] as driver_number
    from {{ ref('stg_openf1__laps') }}
    where lap_time_s is not null
    group by session_key
),

scored as (
    select
        results.*,
        sessions.season,
        sessions.session_name,
        -- the points table of 2023-2026: Races 25-18-15-12-10-8-6-4-2-1, Sprints 8-1
        case sessions.session_name
            when 'Race' then [25, 18, 15, 12, 10, 8, 6, 4, 2, 1][safe_offset(results.finish_position - 1)]
            when 'Sprint' then [8, 7, 6, 5, 4, 3, 2, 1][safe_offset(results.finish_position - 1)]
        end as table_points,
        -- the fastest lap earned a point in Races up to 2024 (the source shows none from 2025)
        coalesce(
            sessions.session_name = 'Race'
            and sessions.season <= 2024
            and fastest_laps.driver_number = results.driver_number,
            false
        ) as earned_fastest_lap_point
    from results
    -- left: a result whose session is missing must survive (and fail the relationships test)
    left join sessions on sessions.session_key = results.session_key
    left join fastest_laps on fastest_laps.session_key = results.session_key
),

trusted_tables as (
    -- A session whose scored results all follow the full points table. A race stopped early pays
    -- fewer places on a smaller table, so its zeros are real and it is left alone.
    select session_key
    from scored
    group by session_key
    having logical_and(
        coalesce(points, 0) = 0
        or points between table_points and table_points + if(earned_fastest_lap_point, 1, 0)
    )
),

corrected as (
    -- OpenF1 gave 0 points to ten classified 2023 finishers (Saudi Arabia P2; United States P2-P10,
    -- re-classified after two disqualifications without new points: issue #21). A classified
    -- finisher inside the points table of a full-points session never scores 0, so those zeros are
    -- filled from the table. Never for a car that was disqualified, retired or did not start.
    select
        scored.*,
        coalesce(scored.points, 0) = 0
        and scored.table_points is not null
        and scored.session_key in (select session_key from trusted_tables)
        and not coalesce(scored.disqualified or scored.did_not_start or scored.did_not_finish, false)
            as is_points_corrected
    from scored
)

select
    corrected.session_key,
    corrected.meeting_key,
    corrected.driver_number,
    grid_by_race.grid_position,
    corrected.finish_position,
    grid_by_race.grid_position - corrected.finish_position as positions_gained,
    cast(if(
        corrected.is_points_corrected,
        corrected.table_points + if(corrected.earned_fastest_lap_point, 1, 0),
        corrected.points
    ) as float64) as points,
    corrected.is_points_corrected,
    corrected.laps_completed,
    corrected.did_not_finish,
    corrected.did_not_start,
    corrected.disqualified,
    corrected.gap_to_leader
from corrected
left join grid_by_race
    on grid_by_race.session_key = corrected.session_key
    and grid_by_race.driver_number = corrected.driver_number
