-- Race control words its messages by hand, and the wording drifts between seasons ("VIRTUAL SAFETY
-- CAR DEPLOYED" became "VSC DEPLOYED"; from 2026 a stopped race is "SESSION ABORTED" with no red
-- flag — issue #14). int_neutralised_laps reads them by exact text, so a wording it does not know
-- is a neutralisation the models cannot see. Any message that looks like one, in any category,
-- and is not on this list warns: read it, then add it here and — if it starts or ends a period —
-- to the model.
{{ config(severity='warn') }}

select
    session_key,
    category,
    message,
    count(*) as messages
from {{ ref('stg_openf1__race_control') }}
where
    regexp_contains(message, r'^(VIRTUAL )?SAFETY CAR|^VSC|^SESSION |^RED FLAG')
    and message not in (
        -- read by the model
        'SAFETY CAR DEPLOYED',
        'SAFETY CAR IN THIS LAP',
        'VIRTUAL SAFETY CAR DEPLOYED',
        'VIRTUAL SAFETY CAR ENDING',
        'VSC DEPLOYED',
        'VSC ENDING',
        'SESSION ABORTED',
        'RED FLAG',
        -- known and deliberately not read
        'RED FLAG - RACE SUSPENDED',
        'SAFETY CAR THROUGH THE PIT LANE',
        'SAFETY CAR LIGHTS ON',
        'SAFETY CAR WILL USE START/FINISH STRAIGHT',
        'SAFETY CAR WILL ENTER PITS: ROLLING START PROCEDURE',
        'SESSION STARTED',
        'SESSION FINISHED'
    )
group by session_key, category, message
