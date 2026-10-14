-- grain: one row per circuit (or 'All circuits') x dry compound x tyre age in laps
-- Each clean lap is compared with the average of its own stint: that removes the pace of the car
-- and the driver and leaves the effect of tyre age. Cars also get lighter as fuel burns, which
-- hides the wear, so a second curve adds back var('fuel_s_per_lap') for every lap already run.
with clean as (
    select
        laps.session_key,
        laps.compound,
        laps.tyre_age_laps,
        laps.lap_time_s - avg(laps.lap_time_s) over stint as delta_s,
        (laps.lap_time_s + {{ var('fuel_s_per_lap') }} * laps.lap_number)
        - avg(laps.lap_time_s + {{ var('fuel_s_per_lap') }} * laps.lap_number) over stint
            as delta_fuel_corrected_s
    from {{ ref('fct_laps') }} as laps
    where laps.is_clean_lap and laps.compound in ('SOFT', 'MEDIUM', 'HARD')
    window stint as (partition by laps.session_key, laps.driver_number, laps.stint_number)
),

by_circuit as (
    select
        races.circuit_short_name,
        clean.compound,
        clean.tyre_age_laps,
        clean.delta_s,
        clean.delta_fuel_corrected_s
    from clean
    inner join {{ ref('rpt_races') }} as races on races.session_key = clean.session_key
),

scoped as (
    select * from by_circuit
    union all
    select
        'All circuits' as circuit_short_name,
        compound,
        tyre_age_laps,
        delta_s,
        delta_fuel_corrected_s
    from by_circuit
)

select
    circuit_short_name,
    compound,
    tyre_age_laps,
    round(approx_quantiles(delta_s, 2)[offset(1)], 3) as median_delta_s,
    round(approx_quantiles(delta_fuel_corrected_s, 2)[offset(1)], 3) as median_delta_fuel_corrected_s,
    count(*) as laps,
    {{ var('fuel_s_per_lap') }} as fuel_s_per_lap
from scoped
group by circuit_short_name, compound, tyre_age_laps
-- a median of fewer than five laps is noise, not a curve
having count(*) >= 5
