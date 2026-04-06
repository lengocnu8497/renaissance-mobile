update public.procedures
set
  editorial_summary = coalesce(
    editorial_summary,
    case lower(name)
      when 'botox / dysport' then 'Softens dynamic expression lines with almost no downtime, making it one of the fastest-entry aesthetic treatments to research and maintain.'
      when 'brazilian butt lift' then 'Enhances body shape through fat transfer, with early recovery centered on swelling, positioning, and protecting the transferred volume.'
      when 'breast augmentation' then 'Adds breast volume and upper-pole fullness with a recovery path shaped by implant settling, soreness, and swelling management.'
      when 'breast lift' then 'Repositions and reshapes the breast for a more lifted contour, with recovery focused on incision healing, swelling, and support.'
      when 'breast reduction' then 'Reduces breast volume to improve comfort and proportion, with recovery balancing symptom relief, support, and scar care.'
      when 'brow lift' then 'Elevates the brow and upper face for a more rested expression, with healing that gradually softens over the first few weeks.'
      when 'cheek filler' then 'Adds structure and lift through targeted volume, with minimal downtime and results that are visible quickly.'
      when 'chemical peel' then 'Improves tone and texture through controlled resurfacing, with downtime depending on peel depth and skin sensitivity.'
      when 'chin augmentation' then 'Improves lower-face balance by increasing chin projection or structure, with recovery shaped by swelling and contour refinement.'
      when 'coolsculpting' then 'Targets pockets of fullness without surgery, with a gradual result timeline and little disruption to daily routine.'
      when 'dermal filler' then 'Restores or adds facial volume with quick recovery, making shape, injector technique, and longevity key parts of the decision.'
      when 'emsculpt / emsculpt neo' then 'Builds muscle tone and can reduce fat over a treatment series, with virtually no downtime and a more gradual payoff.'
      when 'fat transfer' then 'Uses your own fat to add volume or soften contour transitions, with recovery influenced by both donor-site healing and graft settling.'
      when 'hydrafacial' then 'Refreshes skin tone and hydration in a low-downtime treatment that fits easily into ongoing maintenance routines.'
      when 'ipl photofacial' then 'Targets redness, sun damage, and pigment through light-based treatment, with improvement appearing progressively over multiple sessions.'
      when 'jawline filler' then 'Sharpens lower-face definition with targeted structure, with very little downtime but important decisions around proportion and longevity.'
      when 'kybella' then 'Reduces fullness under the chin over multiple treatments, with swelling playing a major role in the short-term recovery experience.'
      when 'laser hair removal' then 'Reduces unwanted hair gradually through a treatment series, with minimal downtime and outcomes tied to consistency and candidate fit.'
      when 'laser resurfacing' then 'Improves texture, pigment, and lines through controlled resurfacing, with recovery intensity varying by laser depth and setting.'
      when 'microfocused ultrasound' then 'Uses energy-based collagen stimulation for subtle lifting over time, with almost no downtime and a slower result curve.'
      when 'microneedling' then 'Supports texture and collagen renewal through controlled skin injury, with short downtime and results that build over repeated sessions.'
      when 'mommy makeover' then 'Combines body procedures into one recovery plan, making surgical staging, downtime, and support needs especially important to compare.'
      when 'neck lift' then 'Refines the jawline and neck contour with recovery focused on swelling, tightness, and gradual softening of the result.'
      when 'otoplasty' then 'Reshapes or repositions the ears for better balance, with recovery centered on dressings, swelling, and protecting the new contour.'
      when 'pdo thread lift' then 'Provides a lighter-lift option with relatively quick downtime, but relies heavily on candidate fit and realistic expectations.'
      when 'prp / prf therapy' then 'Uses your own growth factors to support skin or hair improvement, with low downtime and results that tend to build gradually.'
      when 'rf microneedling' then 'Combines collagen stimulation and heat-based remodeling, with short downtime and a more progressive texture-tightening result.'
      when 'rf skin tightening' then 'Uses radiofrequency to encourage gradual tightening over a series of treatments, with little interruption to daily life.'
      when 'sculptra' then 'Stimulates collagen gradually instead of adding instant volume, making patience and treatment planning part of the result journey.'
      when 'ultherapy / hifu' then 'Uses ultrasound energy to encourage collagen remodeling over time, with subtle improvement appearing gradually after treatment.'
      when 'under eye filler' then 'Softens hollowness under the eyes with targeted volume, where injector technique and candidate selection matter especially much.'
      else editorial_summary
    end
  ),
  default_consult_questions = coalesce(
    default_consult_questions,
    case lower(name)
      when 'botox / dysport' then jsonb_build_array(
        'How much product would be appropriate for my goals and muscle movement?',
        'When should I expect the result to kick in and how long will it last?',
        'How do you keep the result soft and natural-looking?'
      )
      when 'brazilian butt lift' then jsonb_build_array(
        'How much change is realistic based on my anatomy and donor fat?',
        'How long do I need to avoid pressure on the area after surgery?',
        'What should I expect from swelling, shape changes, and fat retention?'
      )
      when 'breast augmentation' then jsonb_build_array(
        'How do you help patients choose size, shape, and implant profile?',
        'What should I expect from implant settling during recovery?',
        'How do you decide incision placement for my goals and anatomy?'
      )
      when 'breast lift' then jsonb_build_array(
        'What level of lift is realistic for my skin and breast shape?',
        'How should I think about scars and how they mature over time?',
        'Will I need an implant as well to reach the look I want?'
      )
      when 'breast reduction' then jsonb_build_array(
        'How much reduction is realistic while keeping my desired shape?',
        'What improvements in comfort or activity do patients usually notice?',
        'How should I think about scars, nipple sensation, and long-term support?'
      )
      when 'brow lift' then jsonb_build_array(
        'What kind of brow lift would best fit my anatomy and goals?',
        'How long should I expect swelling or tightness to affect my appearance?',
        'How do you keep the result lifted without looking overdone?'
      )
      when 'cheek filler' then jsonb_build_array(
        'How much structure or lift would look balanced for my face?',
        'What product and placement strategy do you recommend?',
        'How long should I expect the result to last?'
      )
      when 'chemical peel' then jsonb_build_array(
        'What peel depth is appropriate for my skin concerns and tone?',
        'How much downtime or peeling should I realistically plan for?',
        'How many treatments are usually needed to see the result I want?'
      )
      when 'chin augmentation' then jsonb_build_array(
        'Would an implant or filler-based approach suit my anatomy better?',
        'How much projection change is realistic for my profile?',
        'What should I expect from swelling and final contour timing?'
      )
      when 'coolsculpting' then jsonb_build_array(
        'Am I a good candidate for this versus surgery or another contour treatment?',
        'How many sessions would typically be needed for my goals?',
        'When do results usually start becoming visible?'
      )
      when 'dermal filler' then jsonb_build_array(
        'What product and placement would best match the result I want?',
        'How much filler would look balanced without overdoing it?',
        'How long should I expect the result to last in this area?'
      )
      when 'emsculpt / emsculpt neo' then jsonb_build_array(
        'Am I a good candidate for this treatment based on my goals?',
        'How many sessions are usually needed before people notice change?',
        'How should I combine this with exercise or other treatments?'
      )
      when 'fat transfer' then jsonb_build_array(
        'How much volume is realistic to expect after healing settles?',
        'What should I know about graft survival and how results change over time?',
        'What recovery should I expect in both the donor and treated areas?'
      )
      when 'hydrafacial' then jsonb_build_array(
        'How often should this be repeated for my skin goals?',
        'What kind of glow or clarity improvement should I realistically expect?',
        'How should I pair this with my regular skincare routine?'
      )
      when 'ipl photofacial' then jsonb_build_array(
        'Is this the best fit for my redness or pigment concerns?',
        'How many sessions are usually needed before results show clearly?',
        'What should I expect right after treatment and during healing?'
      )
      when 'jawline filler' then jsonb_build_array(
        'How much definition is realistic for my facial structure?',
        'What product and technique do you use for jawline contouring?',
        'How long should I expect the result to last in this area?'
      )
      when 'kybella' then jsonb_build_array(
        'How many treatments do patients like me usually need?',
        'How much swelling should I expect after each session?',
        'How do you decide whether this is a better fit than liposuction or other options?'
      )
      when 'laser hair removal' then jsonb_build_array(
        'How many sessions are usually needed for my skin and hair type?',
        'What kind of reduction should I realistically expect?',
        'What should I avoid before and after each session?'
      )
      when 'laser resurfacing' then jsonb_build_array(
        'What laser intensity makes sense for my goals and downtime tolerance?',
        'How long will redness, peeling, or sensitivity typically last?',
        'How many treatments are usually needed to see meaningful improvement?'
      )
      when 'microfocused ultrasound' then jsonb_build_array(
        'Am I likely to benefit from this compared with other tightening options?',
        'When do results usually start to appear and peak?',
        'How subtle versus noticeable should I expect the change to be?'
      )
      when 'microneedling' then jsonb_build_array(
        'How many treatments are usually needed for my skin goals?',
        'What downtime should I expect after each session?',
        'Should I pair this with PRP, RF, or another treatment?'
      )
      when 'mommy makeover' then jsonb_build_array(
        'Which procedures make the most sense to combine for my goals?',
        'What kind of recovery help and downtime should I realistically plan for?',
        'How do you decide whether to stage procedures or combine them?'
      )
      when 'neck lift' then jsonb_build_array(
        'Would a neck lift alone meet my goals, or should I compare it with a facelift?',
        'How long should I expect swelling and tightness to affect my appearance?',
        'Where are scars typically placed and how visible are they over time?'
      )
      when 'otoplasty' then jsonb_build_array(
        'What ear shape or position change is realistic for me?',
        'How long will I need to protect the ears during healing?',
        'What should I expect from swelling, dressing wear, and scar care?'
      )
      when 'pdo thread lift' then jsonb_build_array(
        'Am I a good candidate for this versus a surgical lift or another treatment?',
        'How long should I expect the result to last?',
        'What kind of swelling, bruising, or asymmetry can happen early on?'
      )
      when 'prp / prf therapy' then jsonb_build_array(
        'What kind of improvement should I realistically expect for my concern?',
        'How many sessions are usually needed before changes become visible?',
        'How should I compare this with filler, laser, or other options?'
      )
      when 'rf microneedling' then jsonb_build_array(
        'Is this the right intensity for my texture, acne scar, or tightening goals?',
        'How much downtime should I expect after each treatment?',
        'How many sessions are usually needed for a noticeable result?'
      )
      when 'rf skin tightening' then jsonb_build_array(
        'Am I a good candidate for this compared with ultrasound or surgery?',
        'How gradual are the results and how many sessions are usually needed?',
        'What kind of tightening should I realistically expect?'
      )
      when 'sculptra' then jsonb_build_array(
        'How much change should I expect from collagen stimulation versus instant filler?',
        'How many vials or sessions are usually needed for my goals?',
        'When do results usually start becoming noticeable?'
      )
      when 'ultherapy / hifu' then jsonb_build_array(
        'How subtle or noticeable should I expect the lifting effect to be?',
        'When do results usually appear and how long do they last?',
        'How does this compare with other tightening or surgical options?'
      )
      when 'under eye filler' then jsonb_build_array(
        'Am I a good candidate for filler in this area or should I consider another option?',
        'How do you avoid puffiness, visibility, or overfilling under the eyes?',
        'How long should I expect swelling and the final result timeline to last?'
      )
      else default_consult_questions
    end
  )
where editorial_summary is null
   or default_consult_questions is null;
