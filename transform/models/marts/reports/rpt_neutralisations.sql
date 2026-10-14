-- grain: one row per session x lap number x kind of neutralisation
-- Laps run under the Safety Car, the Virtual Safety Car or a red flag, for shading race charts.
-- fct_laps gives each lap one kind (red flag over Safety Car over Virtual Safety Car); the kind
-- stays in the key so a change of that rule upstream shows up as a failed test, not as lost rows.
select distinct
    session_key,
    lap_number,
    neutralisation
from {{ ref('fct_laps') }}
where neutralisation is not null
