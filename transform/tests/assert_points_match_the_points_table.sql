-- Every classified result the source scored must be worth its place: the full points table, plus
-- one for the fastest lap in Races up to 2024. It reads the source's own points (not the corrected
-- ones), skipping only the rows issue #21 fills in: a race shortened to fewer points, a penalty
-- applied after the flag or a new source defect warns, so a person decides.
{{ config(severity='warn') }}

with source_points as (
    select session_key, driver_number, points as source_points
    from {{ ref('stg_openf1__session_result') }}
),

results as (
    select
        results.session_key,
        results.driver_number,
        results.finish_position,
        source_points.source_points,
        sessions.session_name,
        sessions.season,
        case sessions.session_name
            when 'Race' then [25, 18, 15, 12, 10, 8, 6, 4, 2, 1][safe_offset(results.finish_position - 1)]
            when 'Sprint' then [8, 7, 6, 5, 4, 3, 2, 1][safe_offset(results.finish_position - 1)]
        end as table_points
    from {{ ref('fct_session_results') }} as results
    inner join source_points
        on source_points.session_key = results.session_key
        and source_points.driver_number = results.driver_number
    inner join {{ ref('dim_sessions') }} as sessions on sessions.session_key = results.session_key
    where results.finish_position is not null and not results.is_points_corrected
)

select *
from results
where
    coalesce(source_points, 0) < coalesce(table_points, 0)
    or coalesce(source_points, 0) > coalesce(table_points, 0) + if(session_name = 'Race' and season <= 2024, 1, 0)
