-- The effect, whatever the wording: a race with most of its laps under the Safety Car means a
-- period that never closed (issue #14: Monza 2026 showed 51 of 53 laps). The real record in the
-- data is a 19-lap Sprint with 10 neutralised laps (53 %), so anything above 60 % warns.
{{ config(severity='warn') }}

with laps as (
    select session_key, max(lap_number) as laps
    from {{ ref('stg_openf1__laps') }}
    group by session_key
),

neutralised as (
    select session_key, count(distinct lap_number) as neutralised_laps
    from {{ ref('int_neutralised_laps') }}
    group by session_key
)

select
    laps.session_key,
    laps.laps,
    neutralised.neutralised_laps
from laps
inner join neutralised on neutralised.session_key = laps.session_key
where neutralised.neutralised_laps > 0.6 * laps.laps
