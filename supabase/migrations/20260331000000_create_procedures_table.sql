-- Create procedures table
CREATE TABLE IF NOT EXISTS public.procedures (
  id                     UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  name                   TEXT        NOT NULL,
  description            TEXT        NOT NULL,
  category               TEXT        NOT NULL
    CHECK (category IN ('Face', 'Body', 'Skin', 'Injectables', 'Non-Surgical', 'Surgical')),
  recovery_duration_days INTEGER     NOT NULL DEFAULT 0,
  recovery_duration_label TEXT       NOT NULL DEFAULT 'No downtime',
  is_surgical            BOOLEAN     NOT NULL DEFAULT false,
  sort_order             INTEGER     NOT NULL DEFAULT 0,
  created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Public read — no auth required to browse procedures
ALTER TABLE public.procedures ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Procedures are publicly readable"
  ON public.procedures
  FOR SELECT
  USING (true);

-- Index for category filtering
CREATE INDEX idx_procedures_category ON public.procedures (category);
CREATE INDEX idx_procedures_sort_order ON public.procedures (sort_order);

-- ─────────────────────────────────────────────────────────────────────────────
-- SEED DATA
-- ─────────────────────────────────────────────────────────────────────────────

-- FACE (surgical face procedures)
INSERT INTO public.procedures (name, description, category, recovery_duration_days, recovery_duration_label, is_surgical, sort_order) VALUES
  ('Rhinoplasty',
   'Surgical reshaping of the nose to improve appearance or correct breathing issues. Bruising and swelling peak in the first week; a splint is worn for 7–10 days. Final results settle over 12 months as residual swelling gradually subsides.',
   'Face', 14, '1–2 weeks', true, 10),

  ('Facelift',
   'Surgical lifting of the face and neck to reduce sagging skin and deep folds. Most patients feel presentable in public after 2–3 weeks, though subtle swelling continues for up to 3 months.',
   'Face', 21, '2–3 weeks', true, 20),

  ('Blepharoplasty',
   'Eyelid surgery that removes excess skin and fat from upper or lower lids to restore a rested, more youthful look. Bruising typically resolves in 1–2 weeks; sutures are removed at 5–7 days.',
   'Face', 14, '1–2 weeks', true, 30),

  ('Brow Lift',
   'Elevates the forehead and brow to reduce drooping and horizontal forehead lines. Swelling peaks around day 2–3 and fades within 1–2 weeks; most return to work in 7–10 days.',
   'Face', 14, '1–2 weeks', true, 40),

  ('Neck Lift',
   'Tightens loose neck skin and the platysma muscle to sharpen the jaw line and reduce banding. Visible recovery is 2–3 weeks; full softening of scars takes 6–12 months.',
   'Face', 21, '2–3 weeks', true, 50),

  ('Chin Augmentation',
   'Improves chin projection and facial balance using a silicone implant or structural fat grafting. Implant swelling resolves in 1–2 weeks; numbness may persist for several weeks.',
   'Face', 14, '1–2 weeks', true, 60),

  ('Otoplasty',
   'Ear reshaping surgery to correct prominent or asymmetric ears by reshaping cartilage. A bandage is worn for the first week; most resume normal activity within 2–3 weeks.',
   'Face', 7, '1 week', true, 70);

-- BODY (surgical body procedures)
INSERT INTO public.procedures (name, description, category, recovery_duration_days, recovery_duration_label, is_surgical, sort_order) VALUES
  ('Breast Augmentation',
   'Silicone or saline implants placed to increase breast volume and improve shape. Expect tightness and limited arm movement for 2–4 weeks; strenuous activity resumes at 6 weeks.',
   'Body', 28, '2–4 weeks', true, 110),

  ('Breast Lift',
   'Removes excess skin and reshapes breast tissue to restore a firmer, elevated contour. Most patients return to desk work within 1–2 weeks; physical activity at 4–6 weeks.',
   'Body', 14, '1–2 weeks', true, 120),

  ('Breast Reduction',
   'Removes excess breast tissue, fat, and skin to relieve physical discomfort and create a proportionate shape. Return to light activity in 2–3 weeks; full recovery in 6 weeks.',
   'Body', 21, '2–3 weeks', true, 130),

  ('Brazilian Butt Lift',
   'Uses liposuction to harvest your own fat, which is purified and re-injected into the buttocks for natural augmentation. A sitting restriction of 6–8 weeks is critical for fat survival.',
   'Body', 56, '6–8 weeks', true, 140),

  ('Mommy Makeover',
   'A customised combination — typically breast surgery plus a tummy tuck — performed in a single session to restore pre-pregnancy contour. Recovery reflects the most involved procedure: usually 4–6 weeks.',
   'Body', 42, '4–6 weeks', true, 150);

-- SKIN (energy-based and surface treatments)
INSERT INTO public.procedures (name, description, category, recovery_duration_days, recovery_duration_label, is_surgical, sort_order) VALUES
  ('Microneedling',
   'Collagen-induction therapy using fine needles to remodel skin texture, reduce pores, and fade scars and pigmentation. Skin appears red for 24–48 hours and returns to normal within 2–4 days.',
   'Skin', 4, '2–4 days', false, 210),

  ('Chemical Peel',
   'A chemical solution is applied to exfoliate damaged outer skin layers, improving tone, texture, fine lines, and acne scarring. Light peels have 1–3 days of flaking; medium peels peel for up to 7 days.',
   'Skin', 7, '3–7 days', false, 220),

  ('Laser Resurfacing',
   'Ablative or fractional laser removes damaged skin cells to reveal smoother, more even-toned skin underneath. Redness and peeling last 5–14 days depending on the depth of treatment.',
   'Skin', 14, '5–14 days', false, 230),

  ('IPL Photofacial',
   'Intense pulsed light targets sun spots, redness, and broken capillaries without damaging surrounding skin. Treated pigment darkens and flakes off within 1–2 weeks; social downtime is minimal at 1–3 days.',
   'Skin', 3, '1–3 days', false, 240),

  ('HydraFacial',
   'A multi-step treatment combining cleansing, exfoliation, extraction, and hydration using a patented vortex tip. No downtime — skin looks refreshed and glowing immediately.',
   'Skin', 0, 'No downtime', false, 250),

  ('Ultherapy / HIFU',
   'Non-invasive focused ultrasound that stimulates deep collagen to lift brows, tighten the lower face, and smooth the neck. Mild tenderness for a few days; no visible downtime.',
   'Skin', 1, 'Minimal', false, 260),

  ('RF Microneedling',
   'Combines microneedling with radiofrequency energy for deeper collagen remodeling in the face and body. Redness and mild swelling resolve in 3–5 days; make-up is typically avoided for 24 hours.',
   'Skin', 5, '3–5 days', false, 270),

  ('Laser Hair Removal',
   'Targeted laser pulses disable hair follicles for long-term reduction of unwanted hair. Mild redness and follicular swelling resolve within 1–2 days; multiple sessions are needed for full clearance.',
   'Skin', 2, '1–2 days', false, 280);

-- INJECTABLES
INSERT INTO public.procedures (name, description, category, recovery_duration_days, recovery_duration_label, is_surgical, sort_order) VALUES
  ('Botox / Dysport',
   'Neuromodulator injections that temporarily relax facial muscles to smooth dynamic wrinkles such as forehead lines, frown lines, and crow''s feet. Results appear in 3–7 days; no downtime.',
   'Injectables', 0, 'No downtime', false, 310),

  ('Lip Filler',
   'Hyaluronic acid injections that add volume, define the cupid''s bow, and balance lip symmetry. Swelling peaks at 24–48 hours and typically resolves within 3 days.',
   'Injectables', 3, '1–3 days', false, 320),

  ('Cheek Filler',
   'Restores midface volume, lifts the cheek contour, and softens nasolabial folds using hyaluronic acid or biostimulatory filler. Mild swelling or bruising resolves in 1–3 days.',
   'Injectables', 3, '1–3 days', false, 330),

  ('Jawline Filler',
   'Defines and sharpens the jawline by adding structure and projection using hyaluronic acid filler. Results are immediate; swelling settles within 3–5 days.',
   'Injectables', 5, '3–5 days', false, 340),

  ('Under Eye Filler',
   'Hyaluronic acid injected into the tear trough to address hollowness and dark circles under the eyes. Bruising is common and can last 3–7 days; careful aftercare is important in this delicate area.',
   'Injectables', 7, '3–7 days', false, 350),

  ('Dermal Filler',
   'Hyaluronic acid or biostimulatory filler used to restore volume, smooth lines, and enhance facial contours. Duration and downtime vary by area; typical swelling resolves within 3–5 days.',
   'Injectables', 5, '3–5 days', false, 360),

  ('Kybella',
   'Deoxycholic acid injections that permanently destroy fat cells under the chin to reduce a double chin. Significant swelling for 1–2 weeks is expected; multiple sessions may be needed.',
   'Injectables', 14, '1–2 weeks', false, 370),

  ('Sculptra',
   'Poly-L-lactic acid filler that gradually stimulates your own collagen over 2–3 sessions spaced 6 weeks apart. The final result builds over 3–6 months; minimal downtime per session.',
   'Injectables', 3, '1–3 days', false, 380),

  ('PRP / PRF Therapy',
   'Platelet-rich plasma or fibrin derived from your own blood is injected to stimulate skin renewal, hair growth, or wound healing. Mild redness and swelling resolve within 1–3 days.',
   'Injectables', 3, '1–3 days', false, 390);

-- NON-SURGICAL (non-invasive body and face treatments)
INSERT INTO public.procedures (name, description, category, recovery_duration_days, recovery_duration_label, is_surgical, sort_order) VALUES
  ('CoolSculpting',
   'Cryolipolysis treatment that freezes and destroys fat cells in targeted areas such as the abdomen, flanks, and thighs. The treated area may feel numb and tender for 1–2 weeks; results appear over 1–3 months.',
   'Non-Surgical', 0, 'No downtime', false, 410),

  ('Emsculpt / Emsculpt NEO',
   'High-intensity electromagnetic energy stimulates supramaximal muscle contractions to build muscle and reduce fat simultaneously. Mild muscle soreness similar to an intense workout lasts 1–2 days.',
   'Non-Surgical', 2, '1–2 days', false, 420),

  ('RF Skin Tightening',
   'Radiofrequency energy heats the deep dermis to stimulate collagen and tighten lax skin on the face or body. Mild redness fades within 1–2 days; results improve progressively over 3–6 months.',
   'Non-Surgical', 2, '1–2 days', false, 430),

  ('PDO Thread Lift',
   'Dissolvable polydioxanone threads are inserted under the skin to mechanically lift sagging tissue and stimulate collagen. Mild swelling and thread visibility resolve in 3–5 days.',
   'Non-Surgical', 5, '3–5 days', false, 440),

  ('Microfocused Ultrasound',
   'Targets collagen-rich skin layers with focused ultrasound energy to lift and tighten the brow, cheek, chin, and neck area. No visible downtime; mild tenderness possible for a few days.',
   'Non-Surgical', 1, 'Minimal', false, 450);

-- SURGICAL (body contouring procedures not categorised under Body or Face)
INSERT INTO public.procedures (name, description, category, recovery_duration_days, recovery_duration_label, is_surgical, sort_order) VALUES
  ('Liposuction',
   'Surgical removal of localised fat deposits through a thin cannula to refine body contour. A compression garment is worn for 4–6 weeks; most return to desk work in 1–2 weeks.',
   'Surgical', 14, '1–2 weeks', true, 510),

  ('Tummy Tuck',
   'Removes excess abdominal skin and tightens weakened abdominal muscles for a flatter, firmer midsection. Light activity resumes at 4–6 weeks; full physical activity at 8–12 weeks.',
   'Surgical', 42, '4–6 weeks', true, 520),

  ('Fat Transfer',
   'Fat is harvested by liposuction, purified, and re-injected to add volume to the face, hands, breasts, or buttocks. Both the donor and recipient sites have mild bruising resolving in 1–2 weeks.',
   'Surgical', 14, '1–2 weeks', true, 530),

  ('Body Contouring Surgery',
   'Surgical removal of excess loose skin following significant weight loss, including procedures such as arm lift, thigh lift, and lower body lift. Recovery varies by extent but is typically 2–4 weeks.',
   'Surgical', 28, '2–4 weeks', true, 540);
