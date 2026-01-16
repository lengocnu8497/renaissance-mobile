import { createClient } from 'jsr:@supabase/supabase-js@2'
import OpenAI from 'openai'

Deno.serve(async (req) => {
  try {
    // AUTHENTICATION: Create Supabase client with user's auth context
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! },
        },
      }
    )

    // AUTHORIZATION: Verify user is authenticated
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Missing authorization header' }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      )
    }

    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: authError } = await supabaseClient.auth.getUser(token)

    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized - Invalid or expired token' }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Now we have the authenticated user - you can use user.id, user.email, etc.
    console.log(`Request from authenticated user: ${user.email}`)

    const { message, conversationHistory, previousResponseId, imageBase64, conversationId } = await req.json()

    // QUOTA ENFORCEMENT: Check user's subscription and usage limits
    const { data: userProfile, error: profileError } = await supabaseClient
      .from('user_profiles')
      .select('subscription_tier, subscription_current_period_end, subscription_status')
      .eq('id', user.id)
      .single()

    if (profileError || !userProfile) {
      return new Response(
        JSON.stringify({ error: 'Failed to fetch user profile' }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      )
    }

    const { subscription_tier, subscription_current_period_end, subscription_status } = userProfile

    // Check if user has active subscription
    if (!subscription_tier || subscription_status !== 'active') {
      return new Response(
        JSON.stringify({
          error: 'No active subscription',
          code: 'NO_SUBSCRIPTION',
          message: 'Please upgrade to a Silver or Gold plan to use the AI concierge.'
        }),
        { status: 403, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Calculate billing period boundaries
    const periodEnd = new Date(subscription_current_period_end)
    const periodStart = new Date(periodEnd)
    periodStart.setMonth(periodStart.getMonth() - 1)

    // Get or create usage record for current period using RPC
    const { data: usageRecord, error: usageError } = await supabaseClient
      .rpc('get_or_create_usage_record', {
        p_user_id: user.id,
        p_period_start: periodStart.toISOString(),
        p_period_end: periodEnd.toISOString(),
        p_tier: subscription_tier
      })

    if (usageError || !usageRecord) {
      console.error('Failed to fetch usage record:', usageError)
      return new Response(
        JSON.stringify({ error: 'Failed to fetch usage data' }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Calculate cost of this request
    const hasImage = !!imageBase64
    const messageCost = 1
    const imageCost = hasImage ? 1 : 0
    const creditCost = hasImage ? 4 : 2

    // Check if request would exceed any quota limit
    const wouldExceedMessages = (usageRecord.messages_used + messageCost) > usageRecord.messages_limit
    const wouldExceedImages = hasImage && ((usageRecord.images_used + imageCost) > usageRecord.images_limit)
    const wouldExceedCredits = (usageRecord.credits_used + creditCost) > usageRecord.credits_limit

    if (wouldExceedMessages || wouldExceedImages || wouldExceedCredits) {
      const limitType = wouldExceedMessages ? 'messages' :
                        wouldExceedImages ? 'images' : 'credits'

      return new Response(
        JSON.stringify({
          error: 'Quota exceeded',
          code: 'QUOTA_EXCEEDED',
          limitType: limitType,
          usage: {
            messages: { used: usageRecord.messages_used, limit: usageRecord.messages_limit },
            images: { used: usageRecord.images_used, limit: usageRecord.images_limit },
            credits: { used: usageRecord.credits_used, limit: usageRecord.credits_limit }
          },
          periodEnd: subscription_current_period_end
        }),
        { status: 429, headers: { 'Content-Type': 'application/json' } }
      )
    }

    console.log(`Quota check passed - Messages: ${usageRecord.messages_used}/${usageRecord.messages_limit}, Images: ${usageRecord.images_used}/${usageRecord.images_limit}, Credits: ${usageRecord.credits_used}/${usageRecord.credits_limit}`)

    // Validate input
    if (!message || typeof message !== 'string') {
      return new Response(
        JSON.stringify({ error: 'Invalid message' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // System instructions for the AI
    const instructions = "You are an educational assistant helping people understand plastic surgery procedures. " +
                "You provide evidence-based information about cosmetic procedures, candidacy requirements, " +
                "and what to expect. You always emphasize the importance of consulting with board-certified " +
                "plastic surgeons and never provide specific medical advice or diagnoses. You are supportive but " +
                "realistic about expectations. Please maintain the tone of being concise, conversational, and " +
                "action-oriented while still being educational. " +
                "When users share images of themselves or reference photos, you can provide general educational " +
                "information about relevant procedures they might be interested in, but you must always clarify " +
                "that you cannot provide medical diagnoses or personalized treatment plans. Instead, guide them " +
                "toward consulting with board-certified plastic surgeons for professional assessments."

    // Initialize OpenAI client
    const openai = new OpenAI({
      apiKey: Deno.env.get('OPENAI_API_KEY'),
    })

    // Build the user message content
    // If image is provided, use Vision API format with content array
    let userMessageContent: any
    if (imageBase64) {
      userMessageContent = [
        {
          type: 'text',
          text: message
        },
        {
          type: 'image_url',
          image_url: {
            url: `data:image/jpeg;base64,${imageBase64}`
          }
        }
      ]
      console.log('Including image in user message')
    } else {
      userMessageContent = message
    }

    // Build the input messages
    let inputMessages: any[]

    // If we have a previous response ID, include it for context continuity
    if (previousResponseId) {
      inputMessages = [{ role: 'user', content: userMessageContent }]
      console.log(`Including previous_response_id: ${previousResponseId}`)
    } else if (conversationHistory && conversationHistory.length > 0) {
      // Include conversation history for first message or non-reasoning models
      inputMessages = [
        ...conversationHistory,
        { role: 'user', content: userMessageContent }
      ]
    } else {
      inputMessages = [{ role: 'user', content: userMessageContent }]
    }

    // Build request parameters
    const requestParams: any = {
      model: Deno.env.get('MODEL') || 'gpt-4o',
      input: inputMessages,
      instructions: instructions,
      temperature: 0.7,
      max_output_tokens: 300,
      stream: true,
    }

    // Add previous_response_id if available
    if (previousResponseId) {
      requestParams.previous_response_id = previousResponseId
    }

    // Call OpenAI Responses API with streaming
    const stream = await openai.responses.create(requestParams)

    // Create a TransformStream to convert OpenAI's stream to SSE format
    const transformStream = new TransformStream()
    const writer = transformStream.writable.getWriter()
    const encoder = new TextEncoder()

    let fullText = ''
    let responseId = ''
    let tokensUsed = 0
    const modelUsed = Deno.env.get('MODEL') || 'gpt-4o'

    // Process the OpenAI stream in the background
    ;(async () => {
      try {
        for await (const event of stream) {
          // Store response ID from first event
          if (!responseId && event.id) {
            responseId = event.id
          }

          // Extract text delta from the event
          const type = event.type

          if (type !== "response.completed") {
            continue
          }

          if (type === "response.failed") {
            throw new Error("Response creation stream failed!")
          }

          fullText = event.response.output[0].content[0].text

          // Extract token usage if available
          if (event.response.usage) {
            tokensUsed = event.response.usage.total_tokens || 0
          }
        }

        // Send final message with complete response
        await writer.write(encoder.encode(`data: ${JSON.stringify({
          type: 'done',
          reply: fullText,
          responseId: responseId,
          model: modelUsed,
          tokens_used: tokensUsed
        })}\n\n`))

        console.log(`Streaming complete. Response ID: ${responseId}, Tokens: ${tokensUsed}, Full text length: ${fullText.length}`)
        console.log(`Conversation ID: ${conversationId}`)

        // INCREMENT USAGE COUNTERS after successful response
        try {
          const { error: updateError } = await supabaseClient
            .from('usage_tracking')
            .update({
              messages_used: usageRecord.messages_used + messageCost,
              images_used: usageRecord.images_used + imageCost,
              credits_used: usageRecord.credits_used + creditCost
            })
            .eq('id', usageRecord.id)

          if (updateError) {
            console.error('Failed to update usage counters:', updateError)
            // Don't fail the request - just log the error
          } else {
            console.log(`Usage updated: messages +${messageCost}, images +${imageCost}, credits +${creditCost}`)
          }
        } catch (usageUpdateError) {
          console.error('Exception updating usage:', usageUpdateError)
          // Don't fail the request
        }
      } catch (error) {
        console.error('Streaming error:', error)
        await writer.write(encoder.encode(`data: ${JSON.stringify({
          type: 'error',
          error: 'Streaming failed'
        })}\n\n`))
      } finally {
        await writer.close()
      }
    })()

    // Return the stream to the client
    return new Response(transformStream.readable, {
      headers: {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive',
      },
    })

  } catch (error) {
    return new Response(
      JSON.stringify({
        reply: "I'm sorry, I'm having trouble processing your request right now. Please try again."
      }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})