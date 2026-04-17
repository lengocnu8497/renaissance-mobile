import { serve } from 'https://deno.land/std@0.192.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

async function deleteFolderObjects(
  adminClient: ReturnType<typeof createClient>,
  bucket: string,
  rootFolder: string,
) {
  const pathsToDelete: string[] = []
  const foldersToVisit = [rootFolder]

  while (foldersToVisit.length > 0) {
    const folder = foldersToVisit.pop()!
    const { data, error } = await adminClient.storage.from(bucket).list(folder, {
      limit: 100,
      offset: 0,
    })

    if (error) {
      console.warn('delete-account storage list failed', { bucket, folder, message: error.message })
      continue
    }

    for (const item of data ?? []) {
      if (!item.name) continue

      const itemPath = folder ? `${folder}/${item.name}` : item.name
      if (item.id === null) {
        foldersToVisit.push(itemPath)
      } else {
        pathsToDelete.push(itemPath)
      }
    }
  }

  if (pathsToDelete.length === 0) return

  const { error } = await adminClient.storage.from(bucket).remove(pathsToDelete)
  if (error) {
    console.warn('delete-account storage remove failed', { bucket, message: error.message })
  }
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

    const authClient = createClient(supabaseUrl, anonKey, {
      global: {
        headers: { Authorization: req.headers.get('Authorization') ?? '' },
      },
    })
    const adminClient = createClient(supabaseUrl, serviceRoleKey)

    const token = req.headers.get('Authorization')?.replace('Bearer ', '')
    if (!token) {
      return new Response(
        JSON.stringify({ error: 'Missing authorization header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const { data: { user }, error: authError } = await authClient.auth.getUser(token)
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized', details: authError?.message }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const userId = user.id.toLowerCase()

    const { data: conversations, error: conversationsError } = await adminClient
      .from('chat_conversations')
      .select('id')
      .eq('user_id', userId)

    if (conversationsError) {
      throw conversationsError
    }

    const conversationIds = (conversations ?? [])
      .map((conversation) => conversation.id)
      .filter(Boolean)

    if (conversationIds.length > 0) {
      const { error: conversationMessageDeleteError } = await adminClient
        .from('chat_messages')
        .delete()
        .in('conversation_id', conversationIds)

      if (conversationMessageDeleteError) {
        throw conversationMessageDeleteError
      }
    }

    const { error: userMessageDeleteError } = await adminClient
      .from('chat_messages')
      .delete()
      .eq('user_id', userId)
    if (userMessageDeleteError) {
      throw userMessageDeleteError
    }

    const tablesByUserId = [
      'saved_procedures',
      'usage_tracking',
      'weekly_recovery_reports',
      'transactions',
      'journal_entries',
      'chat_conversations',
    ]

    for (const table of tablesByUserId) {
      const { error } = await adminClient
        .from(table)
        .delete()
        .eq('user_id', userId)

      if (error) {
        throw error
      }
    }

    const { error: profileDeleteError } = await adminClient
      .from('user_profiles')
      .delete()
      .eq('id', userId)
    if (profileDeleteError) {
      throw profileDeleteError
    }

    await deleteFolderObjects(adminClient, 'journals', userId)
    await deleteFolderObjects(adminClient, 'chat-images', userId)
    await deleteFolderObjects(adminClient, 'profile-image', userId)

    const { error: deleteUserError } = await adminClient.auth.admin.deleteUser(user.id)
    if (deleteUserError) {
      throw deleteUserError
    }

    return new Response(
      JSON.stringify({ success: true }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  } catch (error) {
    console.error('delete-account error:', error)

    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : 'Unknown error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }
})
