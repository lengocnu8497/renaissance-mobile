# Chat History Storage Implementation Plan

## Overview
Design and implement a database schema to store chat message history for all logged-in users in Supabase PostgreSQL, enabling message persistence, conversation analytics, and future features.

---

## Current State Analysis

### Existing Architecture
- **Authentication**: Supabase Auth with JWT tokens (email/password + Google Sign-In)
- **User Access**: `user.id` and `user.email` available in Edge Functions via JWT validation
- **Chat Implementation**: Client-side only (messages stored in memory via ChatViewModel)
- **AI Integration**: OpenAI Responses API with `previousResponseId` for context continuity
- **No Database Usage**: Currently no Supabase database tables or migrations exist

### Current ChatMessage Model (Swift)
```swift
struct ChatMessage: Identifiable {
    let id = UUID()                    // Client-side UUID
    let text: String                   // Message content
    let isFromUser: Bool               // User vs AI message
    let timestamp: String              // Display format (e.g., "3:45 PM")
    let responseId: String?            // OpenAI response ID
    let imageData: Data?               // Optional image attachment (base64)
}
```

### Limitations
- Messages lost on app restart
- No conversation history across devices
- Cannot perform analytics on user interactions
- Cannot train/improve AI based on past conversations
- Cannot implement features like "conversation threads" or "search history"

---

## Database Schema Design

### Table: `chat_conversations`
Represents a conversation session between a user and the AI.

```sql
CREATE TABLE chat_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT,                          -- Optional: Auto-generated or user-defined
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_archived BOOLEAN DEFAULT FALSE,   -- For soft deletion
    metadata JSONB                       -- Extensible: { device_type, app_version, etc. }
);

-- Indexes for performance
CREATE INDEX idx_conversations_user_id ON chat_conversations(user_id);
CREATE INDEX idx_conversations_created_at ON chat_conversations(created_at DESC);
CREATE INDEX idx_conversations_user_updated ON chat_conversations(user_id, updated_at DESC);
```

**Purpose**: Group messages into logical conversation sessions
**Analytics Use Cases**:
- Track number of conversations per user
- Identify active vs inactive users
- Measure conversation frequency over time

---

### Table: `chat_messages`
Stores individual messages within conversations.

```sql
CREATE TABLE chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES chat_conversations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    -- Message Content
    message_text TEXT NOT NULL,
    is_from_user BOOLEAN NOT NULL,

    -- Timestamps (full precision for analytics)
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- OpenAI Integration
    openai_response_id TEXT,            -- For Responses API context continuity
    openai_model TEXT,                  -- Track which model was used (gpt-4o, etc.)

    -- Image Support
    has_image BOOLEAN DEFAULT FALSE,
    image_url TEXT,                     -- Supabase Storage URL if image uploaded
    image_metadata JSONB,               -- { size, mime_type, dimensions, etc. }

    -- Analytics Fields
    tokens_used INTEGER,                -- Track token consumption
    response_time_ms INTEGER,           -- AI response latency

    -- Metadata for extensibility
    metadata JSONB                      -- { sentiment, topics, intent, etc. }
);

-- Indexes for performance
CREATE INDEX idx_messages_conversation_id ON chat_messages(conversation_id, created_at);
CREATE INDEX idx_messages_user_id ON chat_messages(user_id);
CREATE INDEX idx_messages_created_at ON chat_messages(created_at DESC);
CREATE INDEX idx_messages_openai_response ON chat_messages(openai_response_id) WHERE openai_response_id IS NOT NULL;
```

**Purpose**: Store all message exchanges with rich metadata
**Analytics Use Cases**:
- Message volume over time
- User vs AI message ratio
- Average response times
- Token consumption per user/conversation
- Image attachment frequency
- Popular topics/intents

---

### Table: `chat_analytics_events` (Optional - Future Enhancement)
Track specific user interactions and events for deeper analytics.

```sql
CREATE TABLE chat_analytics_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    conversation_id UUID REFERENCES chat_conversations(id) ON DELETE CASCADE,
    message_id UUID REFERENCES chat_messages(id) ON DELETE CASCADE,

    event_type TEXT NOT NULL,           -- 'message_sent', 'image_attached', 'conversation_started', etc.
    event_data JSONB,                   -- Event-specific data
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_analytics_user_event ON chat_analytics_events(user_id, event_type, created_at);
CREATE INDEX idx_analytics_created_at ON chat_analytics_events(created_at DESC);
```

**Purpose**: Granular event tracking for advanced analytics
**Analytics Use Cases**:
- User journey analysis
- Feature usage patterns
- A/B testing results
- Funnel analysis

---

## Row Level Security (RLS) Policies

### Conversations Table
```sql
-- Enable RLS
ALTER TABLE chat_conversations ENABLE ROW LEVEL SECURITY;

-- Users can only read their own conversations
CREATE POLICY "Users can view own conversations"
    ON chat_conversations FOR SELECT
    USING (auth.uid() = user_id);

-- Users can insert their own conversations
CREATE POLICY "Users can create own conversations"
    ON chat_conversations FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Users can update their own conversations
CREATE POLICY "Users can update own conversations"
    ON chat_conversations FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Users can delete their own conversations
CREATE POLICY "Users can delete own conversations"
    ON chat_conversations FOR DELETE
    USING (auth.uid() = user_id);
```

### Messages Table
```sql
-- Enable RLS
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

-- Users can only read their own messages
CREATE POLICY "Users can view own messages"
    ON chat_messages FOR SELECT
    USING (auth.uid() = user_id);

-- Users can insert their own messages
CREATE POLICY "Users can create own messages"
    ON chat_messages FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Users can update their own messages (e.g., for editing)
CREATE POLICY "Users can update own messages"
    ON chat_messages FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Users can delete their own messages
CREATE POLICY "Users can delete own messages"
    ON chat_messages FOR DELETE
    USING (auth.uid() = user_id);
```

### Analytics Events Table (if implemented)
```sql
ALTER TABLE chat_analytics_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own analytics"
    ON chat_analytics_events FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can create own analytics"
    ON chat_analytics_events FOR INSERT
    WITH CHECK (auth.uid() = user_id);
```

---

## Updated Swift Models

### ChatConversation Model
```swift
struct ChatConversation: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    var title: String?
    let createdAt: Date
    var updatedAt: Date
    var isArchived: Bool
    var metadata: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case isArchived = "is_archived"
        case metadata
    }
}
```

### Enhanced ChatMessage Model
```swift
struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let conversationId: UUID
    let userId: UUID
    let messageText: String
    let isFromUser: Bool
    let createdAt: Date
    var openaiResponseId: String?
    var openaiModel: String?
    var hasImage: Bool
    var imageUrl: String?
    var imageMetadata: [String: AnyCodable]?
    var tokensUsed: Int?
    var responseTimeMs: Int?
    var metadata: [String: AnyCodable]?

    // Computed property for display
    var displayTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: createdAt)
    }

    // For backward compatibility with current UI
    var text: String { messageText }
    var timestamp: String { displayTimestamp }
    var responseId: String? { openaiResponseId }

    // Image data (transient - not stored in DB)
    var imageData: Data?

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case userId = "user_id"
        case messageText = "message_text"
        case isFromUser = "is_from_user"
        case createdAt = "created_at"
        case openaiResponseId = "openai_response_id"
        case openaiModel = "openai_model"
        case hasImage = "has_image"
        case imageUrl = "image_url"
        case imageMetadata = "image_metadata"
        case tokensUsed = "tokens_used"
        case responseTimeMs = "response_time_ms"
        case metadata
    }
}
```

---

## Implementation Strategy

### Phase 1: Database Setup
1. Create migration file `supabase/migrations/001_create_chat_tables.sql`
2. Add conversations table with RLS policies
3. Add messages table with RLS policies
4. Apply migration to Supabase project
5. Verify tables and policies in Supabase Dashboard

### Phase 2: Image Storage (Optional)
1. Configure Supabase Storage bucket `chat-images`
2. Set up RLS policies for bucket access
3. Create helper function to upload images
4. Store image URLs instead of base64 data

### Phase 3: Swift Model Updates
1. Create new Codable models matching database schema
2. Add `AnyCodable` helper for JSONB fields
3. Create database service layer (`ChatDatabaseService.swift`)
4. Implement CRUD operations for conversations and messages

### Phase 4: ChatViewModel Integration
1. Add conversation management (create, load, switch)
2. Save messages to database after sending
3. Load conversation history on app launch
4. Handle offline mode with local caching
5. Sync when connection restored

### Phase 5: Edge Function Updates
1. Save messages to database in `chat-ai` function
2. Track tokens used and response time
3. Associate messages with conversation ID
4. Return updated message with database ID

### Phase 6: Analytics Foundation
1. Create database views for common analytics queries
2. Add helper functions for analytics aggregation
3. Document common analytics queries

### Phase 7: Testing & Validation
1. Test conversation creation and message persistence
2. Verify RLS policies prevent unauthorized access
3. Test offline/online sync scenarios
4. Performance testing with large message histories
5. Test multi-device synchronization

---

## Database Service API Design

### ChatDatabaseService.swift
```swift
class ChatDatabaseService {
    private let supabase: SupabaseClient

    // MARK: - Conversations

    /// Create a new conversation
    func createConversation(title: String? = nil) async throws -> ChatConversation

    /// Get all conversations for current user
    func getConversations(includeArchived: Bool = false) async throws -> [ChatConversation]

    /// Get a specific conversation by ID
    func getConversation(id: UUID) async throws -> ChatConversation?

    /// Update conversation title or metadata
    func updateConversation(_ conversation: ChatConversation) async throws

    /// Archive a conversation (soft delete)
    func archiveConversation(id: UUID) async throws

    /// Delete a conversation permanently
    func deleteConversation(id: UUID) async throws

    // MARK: - Messages

    /// Get all messages for a conversation
    func getMessages(conversationId: UUID) async throws -> [ChatMessage]

    /// Get messages with pagination
    func getMessages(conversationId: UUID, limit: Int, offset: Int) async throws -> [ChatMessage]

    /// Save a new message
    func saveMessage(_ message: ChatMessage) async throws -> ChatMessage

    /// Update an existing message
    func updateMessage(_ message: ChatMessage) async throws

    /// Delete a message
    func deleteMessage(id: UUID) async throws

    // MARK: - Image Upload

    /// Upload image to Supabase Storage and return URL
    func uploadImage(_ imageData: Data, conversationId: UUID) async throws -> String
}
```

---

## Analytics Query Examples

### Conversation Analytics
```sql
-- Total conversations per user
SELECT user_id, COUNT(*) as conversation_count
FROM chat_conversations
GROUP BY user_id;

-- Average conversation length (messages)
SELECT
    c.user_id,
    AVG(message_count) as avg_messages_per_conversation
FROM chat_conversations c
LEFT JOIN (
    SELECT conversation_id, COUNT(*) as message_count
    FROM chat_messages
    GROUP BY conversation_id
) m ON c.id = m.conversation_id
GROUP BY c.user_id;

-- Active users (conversations in last 7 days)
SELECT COUNT(DISTINCT user_id) as active_users
FROM chat_conversations
WHERE created_at >= NOW() - INTERVAL '7 days';
```

### Message Analytics
```sql
-- Total messages sent over time (daily)
SELECT
    DATE_TRUNC('day', created_at) as date,
    COUNT(*) as message_count,
    SUM(CASE WHEN is_from_user THEN 1 ELSE 0 END) as user_messages,
    SUM(CASE WHEN NOT is_from_user THEN 1 ELSE 0 END) as ai_messages
FROM chat_messages
GROUP BY DATE_TRUNC('day', created_at)
ORDER BY date DESC;

-- Average AI response time
SELECT AVG(response_time_ms) as avg_response_time_ms
FROM chat_messages
WHERE is_from_user = FALSE AND response_time_ms IS NOT NULL;

-- Token consumption by user
SELECT
    user_id,
    SUM(tokens_used) as total_tokens,
    AVG(tokens_used) as avg_tokens_per_message
FROM chat_messages
WHERE tokens_used IS NOT NULL
GROUP BY user_id
ORDER BY total_tokens DESC;

-- Image attachment frequency
SELECT
    COUNT(*) FILTER (WHERE has_image = TRUE) * 100.0 / COUNT(*) as image_percentage
FROM chat_messages
WHERE is_from_user = TRUE;
```

### User Engagement Analytics
```sql
-- User retention (users who returned after first conversation)
WITH first_conversation AS (
    SELECT user_id, MIN(created_at) as first_date
    FROM chat_conversations
    GROUP BY user_id
),
returning_users AS (
    SELECT DISTINCT c.user_id
    FROM chat_conversations c
    JOIN first_conversation f ON c.user_id = f.user_id
    WHERE c.created_at > f.first_date + INTERVAL '1 day'
)
SELECT
    COUNT(DISTINCT f.user_id) as total_users,
    COUNT(DISTINCT r.user_id) as returning_users,
    COUNT(DISTINCT r.user_id) * 100.0 / COUNT(DISTINCT f.user_id) as retention_rate
FROM first_conversation f
LEFT JOIN returning_users r ON f.user_id = r.user_id;
```

---

## Migration File Structure

### File: `supabase/migrations/001_create_chat_tables.sql`
```sql
-- =====================================================
-- Chat History Storage Schema
-- =====================================================
-- Purpose: Store user chat conversations and messages
-- Created: 2025-12-10
-- =====================================================

-- Create conversations table
CREATE TABLE chat_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_archived BOOLEAN DEFAULT FALSE,
    metadata JSONB
);

-- Create messages table
CREATE TABLE chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES chat_conversations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    message_text TEXT NOT NULL,
    is_from_user BOOLEAN NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    openai_response_id TEXT,
    openai_model TEXT,
    has_image BOOLEAN DEFAULT FALSE,
    image_url TEXT,
    image_metadata JSONB,
    tokens_used INTEGER,
    response_time_ms INTEGER,
    metadata JSONB
);

-- Create indexes
CREATE INDEX idx_conversations_user_id ON chat_conversations(user_id);
CREATE INDEX idx_conversations_created_at ON chat_conversations(created_at DESC);
CREATE INDEX idx_conversations_user_updated ON chat_conversations(user_id, updated_at DESC);
CREATE INDEX idx_messages_conversation_id ON chat_messages(conversation_id, created_at);
CREATE INDEX idx_messages_user_id ON chat_messages(user_id);
CREATE INDEX idx_messages_created_at ON chat_messages(created_at DESC);
CREATE INDEX idx_messages_openai_response ON chat_messages(openai_response_id) WHERE openai_response_id IS NOT NULL;

-- Enable RLS
ALTER TABLE chat_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

-- RLS Policies for chat_conversations
CREATE POLICY "Users can view own conversations"
    ON chat_conversations FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can create own conversations"
    ON chat_conversations FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own conversations"
    ON chat_conversations FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own conversations"
    ON chat_conversations FOR DELETE
    USING (auth.uid() = user_id);

-- RLS Policies for chat_messages
CREATE POLICY "Users can view own messages"
    ON chat_messages FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can create own messages"
    ON chat_messages FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own messages"
    ON chat_messages FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own messages"
    ON chat_messages FOR DELETE
    USING (auth.uid() = user_id);

-- Trigger to auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_chat_conversations_updated_at
    BEFORE UPDATE ON chat_conversations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
```

---

## Edge Function Updates

### Updated `chat-ai/index.ts` with message saving
```typescript
// After getting AI response, save both user message and AI response
const saveUserMessage = {
    conversation_id: conversationId,
    message_text: message,
    is_from_user: true,
    has_image: !!imageBase64,
    image_url: imageUrl, // If uploaded to Storage
    created_at: new Date().toISOString()
}

const { data: savedUserMsg } = await supabaseClient
    .from('chat_messages')
    .insert(saveUserMessage)
    .select()
    .single()

// Save AI response after completion
const saveAIMessage = {
    conversation_id: conversationId,
    message_text: fullText,
    is_from_user: false,
    openai_response_id: responseId,
    openai_model: MODEL,
    tokens_used: totalTokens, // From OpenAI response
    response_time_ms: responseTimeMs, // Calculated
    created_at: new Date().toISOString()
}

const { data: savedAIMsg } = await supabaseClient
    .from('chat_messages')
    .insert(saveAIMessage)
    .select()
    .single()
```

---

## Image Storage Strategy

### Option 1: Supabase Storage (Recommended)
**Pros**:
- Efficient storage and delivery via CDN
- Built-in access control with RLS
- Scalable and cost-effective
- No base64 overhead in database

**Cons**:
- Additional setup required
- Need to handle upload failures

### Option 2: Base64 in Database
**Pros**:
- Simple implementation
- No additional services needed

**Cons**:
- Poor performance for large images
- Increases database size significantly
- Slower queries

### Recommendation: Use Supabase Storage
1. Create bucket: `chat-images`
2. Set RLS policy: Users can only access their own images
3. Upload flow:
   - Client uploads image to Storage
   - Gets back public URL
   - Passes URL to Edge Function
   - Edge Function saves URL to database

---

## Data Retention & Privacy Considerations

### GDPR Compliance
1. **Right to Access**: Users can export their conversation history
2. **Right to Deletion**: CASCADE deletes remove all user data
3. **Data Minimization**: Only store necessary fields
4. **Purpose Limitation**: Use data only for stated purposes

### Data Retention Policy
```sql
-- Auto-delete archived conversations older than 90 days
CREATE OR REPLACE FUNCTION delete_old_archived_conversations()
RETURNS void AS $$
BEGIN
    DELETE FROM chat_conversations
    WHERE is_archived = TRUE
    AND updated_at < NOW() - INTERVAL '90 days';
END;
$$ LANGUAGE plpgsql;

-- Schedule with pg_cron (if enabled)
SELECT cron.schedule('delete-old-conversations', '0 2 * * *',
    'SELECT delete_old_archived_conversations()');
```

---

## Performance Considerations

### Pagination
- Implement cursor-based pagination for large message histories
- Default to last 50 messages, load more on demand

### Caching
- Cache recent conversations in memory
- Use Redis for frequently accessed data (future enhancement)

### Query Optimization
- Use indexes on commonly queried fields
- Avoid SELECT * - only fetch needed columns
- Use LIMIT/OFFSET for pagination

### Archiving
- Soft delete with `is_archived` flag
- Permanently delete after retention period
- Keep analytics aggregated data

---

## Success Metrics

### Technical Metrics
- [ ] Message save success rate > 99.9%
- [ ] Database query response time < 100ms (p95)
- [ ] Image upload success rate > 99%
- [ ] Zero RLS policy violations

### Business Metrics
- [ ] Track daily active users (DAU)
- [ ] Track average messages per conversation
- [ ] Track conversation retention rate
- [ ] Track average AI response quality (user feedback)

---

## Future Enhancements

### Short-term (Next Sprint)
1. Conversation search functionality
2. Export conversation to PDF/text
3. Share conversation via link
4. Message editing/deletion UI

### Medium-term (Next Quarter)
1. Multi-device sync with optimistic updates
2. Conversation folders/categories
3. Favorite/bookmark messages
4. Advanced analytics dashboard

### Long-term (Future)
1. AI conversation summarization
2. Semantic search across all conversations
3. Conversation insights and recommendations
4. Integration with appointment booking
5. Conversation sentiment analysis

---

## Questions for Clarification

Before finalizing this plan, please confirm:

1. **Conversation Sessions**: Should we automatically create a new conversation for each chat session, or let users manually create/manage conversations?

2. **Image Storage**: Should we implement Supabase Storage now, or start with storing image URLs only (assuming future implementation)?

3. **Analytics Priority**: Which analytics are most important for initial launch?
   - User engagement metrics (DAU, MAU, retention)
   - Cost tracking (tokens, API costs)
   - Conversation quality metrics
   - Performance metrics

4. **Data Retention**: What's the desired retention policy?
   - Keep all messages forever
   - Delete after X months
   - Archive old conversations

5. **Offline Support**: Should messages be queued locally and synced when online, or require internet connection?

6. **Migration Strategy**: Should we:
   - Migrate all users at once
   - Gradual rollout with feature flag
   - New users only, existing users opt-in

---

## Implementation Timeline Estimate

**Phase 1: Database Setup** - 1 day
**Phase 2: Image Storage** - 1 day (if implementing now)
**Phase 3: Swift Models** - 1 day
**Phase 4: ChatViewModel Integration** - 2 days
**Phase 5: Edge Function Updates** - 1 day
**Phase 6: Analytics Foundation** - 1 day
**Phase 7: Testing & Validation** - 2 days

**Total**: ~7-9 days (excluding analytics dashboard UI)

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Migration failures | High | Test on staging environment first |
| RLS policy gaps | High | Comprehensive security testing |
| Performance degradation | Medium | Load testing, indexing, pagination |
| Image storage costs | Medium | Compression, size limits, CDN caching |
| Offline sync conflicts | Medium | Last-write-wins strategy, conflict UI |
| Privacy compliance | High | Legal review, data retention policies |

---

## Conclusion

This plan provides a comprehensive, scalable foundation for chat history storage that:
- ✅ Supports user authentication and privacy
- ✅ Enables rich analytics and insights
- ✅ Maintains compatibility with current implementation
- ✅ Scales to support millions of messages
- ✅ Provides extensibility for future features
- ✅ Follows Supabase and PostgreSQL best practices

The schema design prioritizes:
1. **Security**: RLS policies, CASCADE deletes, user isolation
2. **Performance**: Strategic indexing, pagination support
3. **Analytics**: Rich metadata, tracking fields
4. **Extensibility**: JSONB metadata fields for future needs
5. **Maintainability**: Clear naming, documentation, migrations
