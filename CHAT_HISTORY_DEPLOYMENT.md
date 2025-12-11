# Chat History Storage - Deployment Guide

This guide walks through deploying the chat history storage implementation to your Supabase project.

## Prerequisites

- Supabase CLI installed (`npm install -g supabase`)
- Supabase project created
- OpenAI API key configured

## Step 1: Run Database Migrations

Apply the database schema to create tables, indexes, and RLS policies:

```bash
cd "Renaissance Mobile"

# Login to Supabase (if not already)
supabase login

# Link to your project (if not already linked)
supabase link --project-ref gqporfhogzyqgsxincbx

# Run migrations
supabase db push

# Or apply migrations individually:
supabase db execute -f supabase/migrations/20251210_create_chat_tables.sql
supabase db execute -f supabase/migrations/20251210_create_storage_bucket.sql
```

### Verify Tables Created

Check in Supabase Dashboard > Table Editor:
- ✅ `chat_conversations` table exists
- ✅ `chat_messages` table exists
- ✅ Storage bucket `chat-images` created

### Verify RLS Policies

Check in Supabase Dashboard > Authentication > Policies:
- ✅ 4 policies on `chat_conversations`
- ✅ 4 policies on `chat_messages`
- ✅ 3 policies on `storage.objects` for chat-images bucket

## Step 2: Deploy Edge Functions

### Deploy chat-ai function (updated)

```bash
cd "Renaissance Mobile"

# Deploy the updated chat-ai function
supabase functions deploy chat-ai
```

### Verify Deployment

```bash
# List all functions
supabase functions list

# Test the chat-ai function via the iOS app
```

## Step 3: Data Retention (Manual Cleanup)

To delete archived conversations older than 90 days, run this SQL query in Supabase SQL Editor when needed:

```sql
DELETE FROM chat_conversations
WHERE is_archived = TRUE
AND updated_at < NOW() - INTERVAL '90 days';
```

**Note**: Messages are automatically deleted via CASCADE when conversations are deleted.

## Step 4: Update iOS App

The Swift code has already been updated. To build and deploy:

```bash
# Open in Xcode
open "Renaissance Mobile.xcodeproj"

# Build and run
# The app will now automatically:
# - Create conversations for each session
# - Save messages to database
# - Upload images to Supabase Storage
# - Load conversation history on launch
```

### Important: Add Files to Xcode

Make sure these new files are added to your Xcode project:

1. **Helpers/AnyCodable.swift** - JSONB support
2. **Services/ChatDatabaseService.swift** - Database operations

To add files in Xcode:
1. Right-click project in Navigator
2. Add Files to "Renaissance Mobile"
3. Select the new files
4. Ensure "Copy items if needed" is checked
5. Add to target "Renaissance Mobile"

## Step 5: Verify Everything Works

### Test Checklist

1. **User Authentication**
   - ✅ User can sign in
   - ✅ JWT token is valid

2. **Conversation Creation**
   - ✅ New conversation created on first message
   - ✅ Conversation appears in database
   - ✅ Initial greeting message saved

3. **Message Persistence**
   - ✅ User messages saved to database
   - ✅ AI responses saved to database
   - ✅ Messages persist across app restarts
   - ✅ Response IDs tracked correctly

4. **Image Upload**
   - ✅ Images upload to Supabase Storage
   - ✅ Image URLs saved in messages
   - ✅ Images display correctly in chat

5. **Analytics Views**
   - ✅ Query DAU view for daily active users
   - ✅ Query MAU view for monthly active users
   - ✅ Query daily volume view

### Query Analytics

Check analytics in Supabase SQL Editor:

```sql
-- Daily Active Users (today)
SELECT * FROM chat_analytics_dau;

-- Monthly Active Users
SELECT * FROM chat_analytics_mau;

-- Daily message volume
SELECT * FROM chat_analytics_daily_volume LIMIT 7;

-- Total conversations
SELECT COUNT(*) FROM chat_conversations;

-- Total messages
SELECT COUNT(*) FROM chat_messages;

-- Messages by user
SELECT user_id, COUNT(*) as message_count
FROM chat_messages
GROUP BY user_id
ORDER BY message_count DESC;
```

## Step 6: Monitor and Optimize

### Check Storage Usage

```sql
-- Storage usage by user
SELECT
  (storage.foldername(name))[1] as user_id,
  COUNT(*) as image_count,
  SUM(metadata->>'size')::bigint / 1024 / 1024 as total_mb
FROM storage.objects
WHERE bucket_id = 'chat-images'
GROUP BY user_id
ORDER BY total_mb DESC;
```

### Monitor Database Size

```sql
-- Table sizes
SELECT
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE tablename IN ('chat_conversations', 'chat_messages')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

### Check Index Performance

```sql
-- Index usage stats
SELECT
  schemaname,
  tablename,
  indexname,
  idx_scan as scans,
  idx_tup_read as tuples_read,
  idx_tup_fetch as tuples_fetched
FROM pg_stat_user_indexes
WHERE tablename IN ('chat_conversations', 'chat_messages')
ORDER BY idx_scan DESC;
```

## Troubleshooting

### Issue: Tables Not Created

**Solution**: Check migration files for syntax errors
```bash
supabase db lint
```

### Issue: RLS Policies Blocking Access

**Solution**: Verify user is authenticated
```sql
-- Check current user
SELECT auth.uid();

-- Temporarily disable RLS for debugging (NOT for production)
ALTER TABLE chat_conversations DISABLE ROW LEVEL SECURITY;
-- Re-enable after debugging
ALTER TABLE chat_conversations ENABLE ROW LEVEL SECURITY;
```

### Issue: Images Not Uploading

**Solution**: Check storage bucket policies
```sql
-- View storage policies
SELECT * FROM storage.policies WHERE bucket_id = 'chat-images';
```

### Issue: App Crashes on Launch

**Solution**: Check AnyCodable.swift is added to Xcode target

1. Select AnyCodable.swift in Navigator
2. Check "Target Membership" in File Inspector
3. Ensure "Renaissance Mobile" is checked

## Rollback Plan

If you need to rollback the changes:

```sql
-- Drop tables (WARNING: Deletes all data!)
DROP TABLE IF EXISTS chat_messages CASCADE;
DROP TABLE IF EXISTS chat_conversations CASCADE;

-- Drop views
DROP VIEW IF EXISTS chat_analytics_dau;
DROP VIEW IF EXISTS chat_analytics_mau;
DROP VIEW IF EXISTS chat_analytics_daily_volume;

-- Drop storage bucket
DELETE FROM storage.buckets WHERE id = 'chat-images';

-- Drop functions
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;
DROP FUNCTION IF EXISTS delete_old_archived_conversations() CASCADE;
```

Then revert code changes in Git:
```bash
git checkout HEAD -- "Renaissance Mobile/Renaissance Mobile/Models.swift"
git checkout HEAD -- "Renaissance Mobile/Renaissance Mobile/ViewModels/ChatViewModel.swift"
```

## Next Steps

After successful deployment:

1. **Monitor Usage**: Track DAU/MAU metrics
2. **Optimize**: Add caching if needed
3. **Add Features**:
   - Conversation search
   - Export conversations
   - Conversation sharing
   - Analytics dashboard

## Support

If you encounter issues:

1. Check Supabase logs: Dashboard > Logs
2. Check Edge Function logs: `supabase functions logs chat-ai`
3. Check iOS console for error messages
4. Verify RLS policies are not blocking access

## Security Checklist

Before going to production:

- ✅ All RLS policies enabled
- ✅ Service role key kept secret
- ✅ CRON_SECRET is strong and random
- ✅ Storage bucket is private (not public)
- ✅ Image size limits enforced (5MB)
- ✅ Rate limiting considered
- ✅ User data encrypted in transit (HTTPS)
- ✅ Backup strategy in place

## Cost Estimation

Based on 1,000 active users:

- **Database Storage**: ~100 MB/month = Free (within limits)
- **Storage (Images)**: ~5 GB/month = $0.021/GB = ~$0.10/month
- **Bandwidth**: ~50 GB/month = $0.09/GB = ~$4.50/month
- **Edge Functions**: ~50k invocations = Free (within limits)

**Total**: ~$5/month (excluding OpenAI API costs)

Scale linearly with user growth. Monitor via Supabase Dashboard > Usage.
