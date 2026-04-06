update public.procedures
set
  editorial_summary = case lower(name)
    when 'rhinoplasty' then 'Refines nasal balance, profile, and sometimes breathing support, with swelling that makes the final result emerge gradually over months.'
    when 'facelift' then 'Repositions facial tissue for a more rested, lifted contour, with refinement that settles naturally as swelling eases over the first several weeks.'
    when 'blepharoplasty' then 'Refreshes droopy or puffy eyelids for a more rested look, with changes that are visible quickly and sharpen as healing settles.'
    when 'botox / dysport' then 'Softens dynamic expression lines with little downtime, offering a subtle, easy-to-maintain way to look more rested.'
    when 'lip filler' then 'Adds shape, softness, and definition to the lips with quick recovery, where proportion and technique matter as much as volume.'
    when 'breast augmentation' then 'A breast augmentation is a personalized procedure that uses implants or, in select cases, fat transfer to restore or enhance breast volume in a way that feels balanced to your frame and goals.'
    when 'breast lift' then 'A breast lift reshapes and repositions breasts that have stretched or sagged, aiming for a more elevated outline while preserving natural tissue and, when needed, pairing well with added volume.'
    when 'tummy tuck' then 'A tummy tuck smooths and firms the abdomen by removing excess skin and tightening the abdominal wall, often after pregnancy or major weight change, for a flatter silhouette.'
    when 'liposuction' then 'Liposuction refines stubborn pockets of fat to improve body contour, but it is not a weight-loss procedure and does not reliably tighten loose skin or erase cellulite.'
    when 'brazilian butt lift' then 'A Brazilian Butt Lift uses your own fat to add buttock shape and projection while contouring donor areas, but it should be framed as a highly technique-sensitive procedure with important safety safeguards.'
    else editorial_summary
  end,
  default_consult_questions = case lower(name)
    when 'rhinoplasty' then jsonb_build_array(
      'What changes are realistic for my nose shape, skin thickness, and facial balance?',
      'If breathing is part of my goal, how do you address structure as well as appearance?',
      'How long should I expect swelling to blur the final result?',
      'Can you show examples from patients with anatomy similar to mine?'
    )
    when 'facelift' then jsonb_build_array(
      'What type of lift best matches my goals and facial anatomy?',
      'How much bruising, swelling, and social downtime should I realistically plan for?',
      'Where are the scars typically placed, and how do they soften over time?',
      'Would I benefit from combining the lift with eyelid surgery or fat grafting?'
    )
    when 'blepharoplasty' then jsonb_build_array(
      'Would upper, lower, or combined eyelid surgery best match what I want to improve?',
      'How long should I expect bruising and swelling to affect my appearance?',
      'What scar placement should I expect, and how are incisions hidden?',
      'Could this help with eyelid heaviness that affects my field of vision?'
    )
    when 'botox / dysport' then jsonb_build_array(
      'How much treatment would fit my goals and expression pattern?',
      'When should I expect the result to start working, and how long will it usually last for me?',
      'How do you keep the result soft and balanced rather than frozen?',
      'Are there any reasons I should delay treatment or avoid it for now?'
    )
    when 'lip filler' then jsonb_build_array(
      'How much volume would look balanced on my face without looking overfilled?',
      'What product and technique do you recommend for the shape I want?',
      'How long should I expect swelling, bruising, or tenderness to affect the final look?',
      'If I do not like the result, what are my options for adjusting or dissolving it?'
    )
    when 'breast augmentation' then jsonb_build_array(
      'Am I a better fit for implants or fat transfer based on my anatomy and desired look?',
      'Which implant type, size, and placement would best match my proportions and activity level?',
      'What are the main chances of capsular contracture, rupture, rippling, or revision over time?',
      'How will pregnancy, weight change, mammograms, and long-term follow-up affect my results?'
    )
    when 'breast lift' then jsonb_build_array(
      'Do I need a lift alone, or would a lift plus implant better match my goals?',
      'Which scar pattern is most appropriate for my anatomy and tolerance for visible scarring?',
      'How likely are changes in nipple sensation, asymmetry, or recurrent sagging over time?',
      'How could future weight change or pregnancy affect the lift?'
    )
    when 'tummy tuck' then jsonb_build_array(
      'Do I need a full, mini, or extended tummy tuck based on skin laxity and muscle separation?',
      'Would adding liposuction improve my contour, and would that change my risk profile?',
      'Am I at higher risk for seroma, wound-healing issues, blood clots, or prominent scarring?',
      'How long should I wait after weight loss or pregnancy before surgery, and when can I return to exercise?'
    )
    when 'liposuction' then jsonb_build_array(
      'Which areas are realistic to treat, and where would skin tightening be limited?',
      'Am I a good candidate if my goal is contouring rather than weight loss?',
      'What anesthesia, compression, and recovery plan do you recommend?',
      'What happens if my weight changes after surgery?'
    )
    when 'brazilian butt lift' then jsonb_build_array(
      'Do I have enough donor fat, and how much volume is realistic for my anatomy?',
      'How do you reduce the risk of fat embolism, and do you inject only above the muscle?',
      'Would a smaller-volume change, staged contouring, or another option fit me better?',
      'What is your recovery plan for sitting, activity, and touch-up needs?'
    )
    else default_consult_questions
  end
where lower(name) in (
  'rhinoplasty',
  'facelift',
  'blepharoplasty',
  'botox / dysport',
  'lip filler',
  'breast augmentation',
  'breast lift',
  'tummy tuck',
  'liposuction',
  'brazilian butt lift'
);
