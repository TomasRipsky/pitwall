-- grain: one row per session x lap number x kind of neutralisation
-- Laps run under the Safety Car, the Virtual Safety Car or a red flag, for shading race charts.
-- Two drivers can be on the same lap number under different conditions, hence the kind in the key.
select distinct
    session_key,
    lap_number,
    neutralisation
from {{ ref('fct_laps') }}
where neutralisation is not null
