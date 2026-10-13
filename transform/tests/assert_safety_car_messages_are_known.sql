-- Race control words its messages by hand, and the wording drifts between seasons ("VIRTUAL SAFETY
-- CAR DEPLOYED" became "VSC DEPLOYED"; red flags stopped being sent as flags in 2026 — issue #14).
-- A Safety Car message that int_neutralised_laps does not know is a neutralisation the models
-- cannot see: warn, so the new wording gets added before the charts are wrong.
{{ config(severity='warn') }}

select
    session_key,
    message,
    count(*) as messages
from {{ ref('stg_openf1__race_control') }}
where
    category = 'SafetyCar'
    and message not in (
        'SAFETY CAR DEPLOYED',
        'SAFETY CAR IN THIS LAP',
        'SAFETY CAR THROUGH THE PIT LANE',
        'VIRTUAL SAFETY CAR DEPLOYED',
        'VIRTUAL SAFETY CAR ENDING',
        'VSC DEPLOYED',
        'VSC ENDING'
    )
group by session_key, message
