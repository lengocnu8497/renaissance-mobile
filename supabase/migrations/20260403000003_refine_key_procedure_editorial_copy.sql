update public.procedures
set
  editorial_summary = case lower(name)
    when 'rhinoplasty' then 'Refines nasal balance, profile, and breathing structure with a recovery arc that reveals itself gradually rather than all at once.'
    when 'facelift' then 'Repositions facial tissue for a more rested, lifted contour, with swelling and definition settling elegantly over the first several weeks.'
    when 'breast augmentation' then 'Builds breast volume and shape with a recovery path defined by implant settling, soreness, and the gradual softening of the final look.'
    when 'tummy tuck' then 'Refines the abdominal contour and support of the midsection, with recovery centered on swelling control, mobility, and incision care.'
    when 'lip filler' then 'Adds softness, shape, and definition to the lips with minimal downtime and a result that reads polished rather than overdone when planned well.'
    when 'botox / dysport' then 'Softens dynamic expression lines with almost no downtime, making it one of the easiest treatments to start, maintain, and fine-tune over time.'
    when 'brazilian butt lift' then 'Enhances body shape through fat transfer, with early recovery focused on swelling, positioning, and protecting the newly transferred volume.'
    when 'mommy makeover' then 'Combines body-focused procedures into one coordinated recovery plan, making downtime, support, and surgical sequencing especially important to get right.'
    else editorial_summary
  end,
  default_consult_questions = case lower(name)
    when 'rhinoplasty' then jsonb_build_array(
      'What changes are realistic for my nose shape, skin thickness, and profile?',
      'How long should I expect swelling to blur the final result?',
      'Can you show results from patients with anatomy similar to mine?'
    )
    when 'facelift' then jsonb_build_array(
      'What type of lift best fits my anatomy and the result I want?',
      'How should I think about bruising, swelling, and social downtime?',
      'Where are scars typically placed, and how do they soften over time?'
    )
    when 'breast augmentation' then jsonb_build_array(
      'How do you guide patients on size, profile, and overall balance?',
      'What should I expect from implant settling during the first few months?',
      'How do you decide incision placement based on my anatomy and goals?'
    )
    when 'tummy tuck' then jsonb_build_array(
      'Am I a better fit for a full tummy tuck, mini tummy tuck, or another option?',
      'What movement restrictions should I realistically expect in the first few weeks?',
      'How should I think about scar placement and long-term healing?'
    )
    when 'lip filler' then jsonb_build_array(
      'How much volume would look balanced and still feel natural on my face?',
      'How long should I expect swelling to affect the final look?',
      'What product and technique do you recommend for the shape I want?'
    )
    when 'botox / dysport' then jsonb_build_array(
      'How much product would be appropriate for my goals and muscle movement?',
      'When should I expect the result to appear, and how long will it last?',
      'How do you keep the result soft, balanced, and natural-looking?'
    )
    when 'brazilian butt lift' then jsonb_build_array(
      'How much change is realistic based on my anatomy and available donor fat?',
      'How long do I need to avoid pressure on the area after surgery?',
      'What should I expect from swelling, shape changes, and fat retention over time?'
    )
    when 'mommy makeover' then jsonb_build_array(
      'Which procedures make the most sense to combine for my goals and recovery capacity?',
      'What kind of downtime and at-home support should I realistically plan for?',
      'How do you decide whether to stage procedures or combine them in one surgery?'
    )
    else default_consult_questions
  end
where lower(name) in (
  'rhinoplasty',
  'facelift',
  'breast augmentation',
  'tummy tuck',
  'lip filler',
  'botox / dysport',
  'brazilian butt lift',
  'mommy makeover'
);
