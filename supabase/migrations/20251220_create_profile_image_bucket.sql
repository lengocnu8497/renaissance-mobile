-- Create profile-image storage bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'profile-image',
    'profile-image',
    true,  -- public bucket so images can be displayed
    5242880,  -- 5MB size limit
    ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Public profile images are viewable by everyone" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload own profile image" ON storage.objects;
DROP POLICY IF EXISTS "Users can update own profile image" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own profile image" ON storage.objects;

-- Policy: Users can view all profile images (public bucket)
CREATE POLICY "Public profile images are viewable by everyone"
ON storage.objects FOR SELECT
USING (bucket_id = 'profile-image');

-- Policy: Users can upload their own profile image
-- The path format is: {user_id}/profile.{ext}
-- We need to extract the first part of the path and compare with auth.uid()
CREATE POLICY "Users can upload own profile image"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'profile-image'
    AND (CASE
        WHEN position('/' in name) > 0
        THEN substring(name from 1 for position('/' in name) - 1)
        ELSE name
    END) = auth.uid()::text
);

-- Policy: Users can update their own profile image
CREATE POLICY "Users can update own profile image"
ON storage.objects FOR UPDATE
USING (
    bucket_id = 'profile-image'
    AND (CASE
        WHEN position('/' in name) > 0
        THEN substring(name from 1 for position('/' in name) - 1)
        ELSE name
    END) = auth.uid()::text
)
WITH CHECK (
    bucket_id = 'profile-image'
    AND (CASE
        WHEN position('/' in name) > 0
        THEN substring(name from 1 for position('/' in name) - 1)
        ELSE name
    END) = auth.uid()::text
);

-- Policy: Users can delete their own profile image
CREATE POLICY "Users can delete own profile image"
ON storage.objects FOR DELETE
USING (
    bucket_id = 'profile-image'
    AND (CASE
        WHEN position('/' in name) > 0
        THEN substring(name from 1 for position('/' in name) - 1)
        ELSE name
    END) = auth.uid()::text
);
