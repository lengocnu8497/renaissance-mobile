# Chat History Storage - Quick Start Guide

## What Was Implemented

✅ **Database Schema**: PostgreSQL tables for conversations and messages
✅ **Image Storage**: Supabase Storage for chat images
✅ **Message Persistence**: All messages saved to database
✅ **Conversation Management**: Automatic session creation
✅ **Analytics**: DAU/MAU tracking views
✅ **Data Retention**: Manual cleanup for old conversations
✅ **RLS Security**: Row-level security policies

## Quick Deploy (5 Minutes)

### 1. Run Migrations (2 min)

```bash
cd "Renaissance Mobile"
supabase link --project-ref gqporfhogzyqgsxincbx
supabase db push
```

### 2. Deploy Functions (2 min)

```bash
supabase functions deploy chat-ai
```

### 3. Update Xcode Project (1 min)

Add these files to your Xcode project:
- `Helpers/AnyCodable.swift`
- `Services/ChatDatabaseService.swift`

**How to add**:
1. Open Xcode
2. Right-click "Renaissance Mobile" folder
3. Add Files to "Renaissance Mobile"
4. Select both files
5. Check "Copy items if needed"
6. Click "Add"

### 4. Build & Run

```bash
# In Xcode: Cmd+R to build and run
```

## What Changed in Your App

### Before
- Messages stored in memory only
- Lost on app restart
- No analytics
- No image persistence

### After
- Messages saved to database ✅
- Conversations persist across sessions ✅
- DAU/MAU analytics available ✅
- Images uploaded to cloud storage ✅

## How It Works

### User Flow

1. **User opens app** → ChatViewModel loads latest conversation
2. **User sends message** → Saved to database + sent to AI
3. **AI responds** → Response saved to database
4. **User closes app** → All messages preserved
5. **User reopens app** → Conversation history loaded

### Data Flow

```
User Message
    ↓
ChatViewModel
    ↓
ChatDatabaseService (save to DB)
    ↓
Edge Function (chat-ai)
    ↓
OpenAI API
    ↓
AI Response
    ↓
ChatDatabaseService (save to DB)
    ↓
Display in UI
```

### Storage Structure

**Database**:
- `chat_conversations`: One row per chat session
- `chat_messages`: All messages (user + AI)

**Storage**:
- Bucket: `chat-images`
- Path: `{user_id}/{conversation_id}/{message_id}.jpg`

## Key Features

### 1. Automatic Conversation Creation
Each time the app starts, it either:
- Loads the most recent conversation, OR
- Creates a new conversation automatically

### 2. Message Persistence
Every message is automatically saved:
- User messages: Immediately upon sending
- AI responses: After completion
- Images: Uploaded to Storage, URL saved in DB

### 3. Analytics Tracking
Three built-in views for analytics:
- `chat_analytics_dau`: Daily active users
- `chat_analytics_mau`: Monthly active users
- `chat_analytics_daily_volume`: Message counts per day

### 4. Data Retention
- Active conversations: Kept indefinitely
- Archived conversations: Delete manually when needed via SQL query

## Verify It Works

### Check Database

```sql
-- See all conversations
SELECT * FROM chat_conversations ORDER BY created_at DESC LIMIT 10;

-- See all messages
SELECT * FROM chat_messages ORDER BY created_at DESC LIMIT 20;

-- Check today's active users
SELECT * FROM chat_analytics_dau;
```

### Check Storage

Go to Supabase Dashboard → Storage → chat-images

You should see folders structured like:
```
chat-images/
  ├── {user-id-1}/
  │   └── {conversation-id}/
  │       └── {message-id}.jpg
  └── {user-id-2}/
      └── {conversation-id}/
          └── {message-id}.png
```

### Check App

1. Send a message in the app
2. Close the app completely
3. Reopen the app
4. ✅ Your message should still be there!

## Common Issues & Fixes

### Issue: App crashes on launch

**Fix**: Make sure AnyCodable.swift is added to Xcode target
1. Select file in Navigator
2. File Inspector → Target Membership
3. Check "Renaissance Mobile"

### Issue: Messages not saving

**Fix**: Check database connection
```sql
-- Verify tables exist
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name LIKE 'chat_%';
```

### Issue: Images not uploading

**Fix**: Verify storage bucket exists
```sql
-- Check bucket
SELECT * FROM storage.buckets WHERE id = 'chat-images';
```

### Issue: "Not authenticated" error

**Fix**: User must be signed in
- Check auth token is valid
- User should see authenticated session

## Analytics Queries

### Daily Active Users (Last 7 Days)

```sql
SELECT
  DATE(created_at) as date,
  COUNT(DISTINCT user_id) as active_users
FROM chat_messages
WHERE created_at >= NOW() - INTERVAL '7 days'
GROUP BY DATE(created_at)
ORDER BY date DESC;
```

### Total Messages by User

```sql
SELECT
  user_id,
  COUNT(*) as message_count,
  COUNT(*) FILTER (WHERE is_from_user) as user_messages,
  COUNT(*) FILTER (WHERE NOT is_from_user) as ai_messages
FROM chat_messages
GROUP BY user_id
ORDER BY message_count DESC;
```

### Average Response Time

```sql
SELECT
  AVG(response_time_ms) as avg_ms,
  MIN(response_time_ms) as min_ms,
  MAX(response_time_ms) as max_ms
FROM chat_messages
WHERE response_time_ms IS NOT NULL;
```

### Token Usage (Cost Tracking)

```sql
SELECT
  DATE(created_at) as date,
  SUM(tokens_used) as total_tokens,
  COUNT(*) as message_count,
  AVG(tokens_used) as avg_tokens
FROM chat_messages
WHERE tokens_used IS NOT NULL
GROUP BY DATE(created_at)
ORDER BY date DESC;
```

## Testing Checklist

- [ ] User can send message
- [ ] Message appears in chat
- [ ] Message saved to database (check Supabase)
- [ ] AI responds
- [ ] AI response saved to database
- [ ] Close and reopen app
- [ ] Conversation history loads
- [ ] Send message with image
- [ ] Image uploads to storage
- [ ] Image displays in chat
- [ ] Check analytics views return data

## Performance Tips

### For Large Message Histories

If conversations grow very large (1000+ messages):

1. **Enable Pagination**: Already implemented in ChatDatabaseService
```swift
// Load only last 50 messages
let messages = try await databaseService.getMessages(
    conversationId: id,
    limit: 50
)
```

2. **Archive Old Conversations**: Manually archive via:
```swift
try await databaseService.archiveConversation(id: conversationId)
```

3. **Monitor Database Size**: Run periodically
```sql
SELECT pg_size_pretty(pg_database_size('postgres'));
```

## Security Notes

✅ **RLS Enabled**: Users can only access their own data
✅ **JWT Auth**: All requests authenticated
✅ **Private Storage**: Images not publicly accessible
✅ **Validated Uploads**: Only allowed image types
✅ **Size Limits**: 5MB max per image

## What's Next?

After basic deployment works, consider:

1. **Add Conversation List UI**: Show all user conversations
2. **Search Messages**: Full-text search across history
3. **Export Conversations**: PDF or text export
4. **Conversation Sharing**: Share via link
5. **Advanced Analytics Dashboard**: Visualize metrics

## Support & Documentation

- **Full Plan**: See [CHAT_HISTORY_STORAGE_PLAN.md](CHAT_HISTORY_STORAGE_PLAN.md)
- **Deployment Guide**: See [CHAT_HISTORY_DEPLOYMENT.md](CHAT_HISTORY_DEPLOYMENT.md)
- **Supabase Docs**: https://supabase.com/docs
- **Supabase Dashboard**: https://app.supabase.com

## Summary

You now have a fully functional chat history system that:
- ✅ Persists all messages to database
- ✅ Stores images in cloud storage
- ✅ Tracks analytics (DAU/MAU)
- ✅ Secured with RLS policies
- ✅ Ready for production use

**Total Implementation Time**: ~5 minutes to deploy
**Total Development Time**: Complete solution provided
**Maintenance**: Minimal

Enjoy your persistent chat history! 🎉
