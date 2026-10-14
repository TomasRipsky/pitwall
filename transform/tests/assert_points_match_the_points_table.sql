-- After issue #21's correction every classified result must score what its place is worth: the
-- points table, plus one for the fastest lap in Races up to 2024. Anything else — a race shortened
-- to half points, a penalty applied after the flag, a new source defect — warns so a person decides.
{{ config(severity='warn') }}

with results as (
    select
        results.session_key,
        results.driver_number,
        results.finish_position,
        results.points,
        sessions.session_name,
        sessions.season,
        case sessions.session_name
            when 'Race' then [25, 18, 15, 12, 10, 8, 6, 4, 2, 1][safe_offset(results.finish_position - 1)]
            when 'Sprint' then [8, 7, 6, 5, 4, 3, 2, 1][safe_offset(results.finish_position - 1)]
        end as table_points
    from {{ ref('fct_session_results') }} as results
    inner join {{ ref('dim_sessions') }} as sessions on sessions.session_key = results.session_key
    where results.finish_position is not null
)

select *
from results
where
    coalesce(points, 0) < coalesce(table_points, 0)
    or coalesce(points, 0) > coalesce(table_points, 0) + if(session_name = 'Race' and season <= 2024, 1, 0)
