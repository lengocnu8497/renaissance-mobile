update public.procedures
set
  editorial_summary = coalesce(
    editorial_summary,
    case
      when lower(name) = 'rhinoplasty' then 'Refines nasal shape, balance, and breathing structure with a recovery arc that improves gradually over time.'
      when lower(name) like '%bleph%' then 'Refreshes the eye area by reducing heaviness or puffiness, with a relatively short but very visible recovery window.'
      when lower(name) like '%lip filler%' or lower(name) like '%lip augmentation%' then 'Adds shape, softness, and definition to the lips with minimal downtime and quick day-to-day recovery.'
      when lower(name) like '%breast surgery%' then 'Reshapes breast volume or position with a recovery plan focused on support, swelling management, and gradual return to movement.'
      when lower(name) like '%body contouring%' then 'Improves body shape and proportion through contour-focused surgery, with compression and swelling management playing a central role.'
      when lower(name) like '%facial surgery%' then 'Refines facial structure and lift with recovery centered on swelling, bruising, and gradual return to a natural look.'
      when lower(name) like '%facelift%' then 'Lifts and repositions facial tissue for a more rested contour, with healing that settles visibly over the first several weeks.'
      when lower(name) like '%liposuction%' then 'Targets localized fullness to create cleaner body contours, with swelling and compression shaping much of the recovery experience.'
      when lower(name) like '%tummy tuck%' then 'Tightens the abdominal area with a recovery path that depends on swelling control, mobility, and incision care.'
      when lower(name) like '%bbl%' or lower(name) like '%buttock%' then 'Reshapes body proportions through fat transfer, with early recovery focused heavily on pressure avoidance and swelling.'
      when lower(name) = 'surgery' then 'A structured recovery workspace for surgical procedures, helping you compare healing, prep, and follow-up questions in one place.'
      else null
    end
  ),
  default_consult_questions = coalesce(
    default_consult_questions,
    case
      when lower(name) = 'rhinoplasty' then jsonb_build_array(
        'What changes are realistic for my nose shape and skin thickness?',
        'How long should I expect swelling to hide the final result?',
        'Can you show before-and-afters for cases similar to mine?'
      )
      when lower(name) like '%bleph%' then jsonb_build_array(
        'Am I a better candidate for upper, lower, or combined eyelid surgery?',
        'How long will swelling or bruising affect my appearance?',
        'What kind of scar placement should I expect?'
      )
      when lower(name) like '%lip filler%' or lower(name) like '%lip augmentation%' then jsonb_build_array(
        'How much volume would look balanced for my face?',
        'How long should I expect swelling to last after treatment?',
        'What product and technique do you recommend for my goals?'
      )
      when lower(name) like '%breast surgery%' then jsonb_build_array(
        'What result is realistic for my frame and tissue quality?',
        'What will the first two weeks of recovery realistically feel like?',
        'How do you help patients choose size, shape, or lift strategy?'
      )
      when lower(name) like '%body contouring%' then jsonb_build_array(
        'Which areas would benefit most from treatment based on my goals?',
        'How much swelling should I expect and for how long?',
        'What compression, mobility, or downtime requirements should I plan for?'
      )
      when lower(name) like '%facial surgery%' then jsonb_build_array(
        'Which procedure would best match the result I want to achieve?',
        'How long will I look noticeably swollen or bruised?',
        'What does a natural-looking result look like for my face?'
      )
      when lower(name) like '%facelift%' then jsonb_build_array(
        'What kind of lift is appropriate for my anatomy and goals?',
        'How should I think about recovery, bruising, and social downtime?',
        'Where will scars typically sit and how do they mature over time?'
      )
      when lower(name) like '%liposuction%' then jsonb_build_array(
        'Which areas can be treated most effectively for my body type?',
        'How long will swelling and compression be part of recovery?',
        'When do contour changes usually become visible?'
      )
      when lower(name) like '%tummy tuck%' then jsonb_build_array(
        'Am I a candidate for a full tummy tuck, mini tummy tuck, or another option?',
        'What restrictions will I have during the first few weeks of healing?',
        'How should I think about scar placement and long-term recovery?'
      )
      when lower(name) like '%bbl%' or lower(name) like '%buttock%' then jsonb_build_array(
        'How much change is realistic based on my current anatomy and donor fat?',
        'How long do I need to avoid pressure on the area after surgery?',
        'What should I expect from swelling, shape changes, and fat retention?'
      )
      when lower(name) = 'surgery' then jsonb_build_array(
        'What recovery timeline should I realistically plan around?',
        'Which risks or tradeoffs matter most for my goals?',
        'What should I prepare before surgery so recovery goes more smoothly?'
      )
      else null
    end
  )
where editorial_summary is null
   or default_consult_questions is null;
