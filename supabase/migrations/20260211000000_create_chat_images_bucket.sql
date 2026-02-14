-- Create chat-images storage bucket (or update existing to ensure it's public)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'chat-images',
    'chat-images',
    true,  -- public so images can be displayed in chat and fetched by OpenAI
    5242880,  -- 5MB size limit
    ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
    public = true,
    file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp'];

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Chat images are viewable by owner" ON storage.objects;
DROP POLICY IF EXISTS "Chat images are publicly readable" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload own chat images" ON storage.objects;
DROP POLICY IF EXISTS "Users can update own chat images" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own chat images" ON storage.objects;
DROP POLICY IF EXISTS "Service role can manage chat images" ON storage.objects;

-- Policy: Chat images are publicly readable (needed for OpenAI to fetch image URLs)
CREATE POLICY "Chat images are publicly readable"
ON storage.objects FOR SELECT
USING (bucket_id = 'chat-images');

-- Policy: Users can upload their own chat images
-- Path format: {user_id}/{conversation_id}/{prefix}-{id}.{ext}
-- Use lower() to handle UUID case differences (Swift sends uppercase, Postgres stores lowercase)
CREATE POLICY "Users can upload own chat images"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'chat-images'
    AND lower(CASE
        WHEN position('/' in name) > 0
        THEN substring(name from 1 for position('/' in name) - 1)
        ELSE name
    END) = lower(auth.uid()::text)
);

-- Policy: Users can update their own chat images
CREATE POLICY "Users can update own chat images"
ON storage.objects FOR UPDATE
USING (
    bucket_id = 'chat-images'
    AND lower(CASE
        WHEN position('/' in name) > 0
        THEN substring(name from 1 for position('/' in name) - 1)
        ELSE name
    END) = lower(auth.uid()::text)
)
WITH CHECK (
    bucket_id = 'chat-images'
    AND lower(CASE
        WHEN position('/' in name) > 0
        THEN substring(name from 1 for position('/' in name) - 1)
        ELSE name
    END) = lower(auth.uid()::text)
);

-- Policy: Users can delete their own chat images
CREATE POLICY "Users can delete own chat images"
ON storage.objects FOR DELETE
USING (
    bucket_id = 'chat-images'
    AND lower(CASE
        WHEN position('/' in name) > 0
        THEN substring(name from 1 for position('/' in name) - 1)
        ELSE name
    END) = lower(auth.uid()::text)
);

-- Policy: Service role can manage all chat images (needed for edge function uploads like DALL-E generated images)
CREATE POLICY "Service role can manage chat images"
ON storage.objects FOR ALL
USING (
    bucket_id = 'chat-images'
    AND auth.role() = 'service_role'
)
WITH CHECK (
    bucket_id = 'chat-images'
    AND auth.role() = 'service_role'
);
