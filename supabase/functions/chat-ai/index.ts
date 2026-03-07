import { createClient } from 'jsr:@supabase/supabase-js@2'
import OpenAI from 'openai'
import prompts from './prompts.json' with { type: 'json' }

const modelUsed = 'gpt-4o'

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

/**
 * Safely subtracts one calendar month, clamping to the last day of the target
 * month when the source day doesn't exist there (e.g. Mar 31 → Feb 28).
 * JS Date.setMonth() alone rolls over (Mar 31 → Mar 3) which produces a wrong
 * period_start key and can silently reset quota mid-period.
 */
function subtractOneMonth(date: Date): Date {
  const d = new Date(date)
  const originalDay = d.getDate()
  d.setMonth(d.getMonth() - 1)
  // If the day overflowed (e.g. Jan 31 → Mar 3), back up to last day of target month
  if (d.getDate() !== originalDay) {
    d.setDate(0)
  }
  return d
}

// DALL-E image generation function
async function generateImageWithDalle(openai: OpenAI, prompt: string): Promise<string> {
  const response = await openai.images.generate({
    model: "dall-e-3",
    prompt: prompt,
    n: 1,
    size: "1024x1024",
    quality: "standard",
    response_format: "b64_json"
  })
  return response.data[0].b64_json!
}

// Upload image to Supabase Storage and return public URL
async function uploadImageToStorage(
  supabaseClient: any,
  userId: string,
  conversationId: string,
  base64Data: string,
  prefix: string,
  contentType: string
): Promise<string> {
  const imageId = crypto.randomUUID()
  const ext = contentType === 'image/png' ? 'png' : 'jpg'
  const filePath = `${userId}/${conversationId}/${prefix}-${imageId}.${ext}`

  const binaryString = atob(base64Data)
  const bytes = new Uint8Array(binaryString.length)
  for (let i = 0; i < binaryString.length; i++) {
    bytes[i] = binaryString.charCodeAt(i)
  }

  const { error } = await supabaseClient.storage
    .from('chat-images')
    .upload(filePath, bytes, { contentType })

  if (error) {
    console.error(`Failed to upload ${prefix} image:`, error)
    throw error
  }

  const { data } = supabaseClient.storage
    .from('chat-images')
    .getPublicUrl(filePath)

  return data.publicUrl
}

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

    // SERVICE CLIENT: Bypasses RLS for quota operations (get_or_create_usage_record,
    // increment_usage). Never used for user-data reads/writes.
    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
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

    const { message, conversationHistory, previousResponseId, imageBase64, conversationId } = await req.json()

    // Validate conversationId is a UUID to prevent path traversal in storage uploads
    if (!conversationId || !UUID_REGEX.test(conversationId)) {
      return new Response(
        JSON.stringify({ error: 'Invalid conversationId' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

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
    // Allow 'active' status, but also allow 'canceled' if still within the paid period
    // (Stripe cancellations set cancel_at_period_end=true, meaning access continues until period end)
    const isActive = subscription_status === 'active'
    const isCanceledButStillInPeriod = subscription_status === 'canceled'
      && subscription_current_period_end
      && new Date(subscription_current_period_end) > new Date()

    if (!subscription_tier || (!isActive && !isCanceledButStillInPeriod)) {
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
    const periodEnd   = new Date(subscription_current_period_end)
    const periodStart = subtractOneMonth(periodEnd)

    // Get or create usage record for current period using RPC
    const { data: usageRecord, error: usageError } = await adminClient
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

    // Validate input
    if (!message || typeof message !== 'string') {
      return new Response(
        JSON.stringify({ error: 'Invalid message' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // System instructions for the AI
    const instructions = prompts.systemInstructions

    // Initialize OpenAI client
    const openai = new OpenAI({
      apiKey: Deno.env.get('OPENAI_API_KEY'),
    })

    // Build the user message content
    // If image is provided, upload to Supabase Storage first and send URL to OpenAI
    // (sending base64 inline counts against TPM and blows rate limits)
    let userMessageContent: any
    if (imageBase64) {
      const publicImageUrl = await uploadImageToStorage(
        supabaseClient,
        user.id,
        conversationId,
        imageBase64,
        'input',
        'image/jpeg'
      )

      userMessageContent = [
        {
          type: 'input_text',
          text: message
        },
        {
          type: 'input_image',
          image_url: publicImageUrl,
          detail: 'low'
        }
      ]
    } else {
      userMessageContent = message
    }

    // Build the input messages
    let inputMessages: any[]

    // If we have a previous response ID, include it for context continuity
    if (previousResponseId) {
      inputMessages = [{ role: 'user', content: userMessageContent }]
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
      model: modelUsed,
      input: inputMessages,
      instructions: instructions,
      temperature: 0.7,
      max_output_tokens: 300,
    }

    // Add previous_response_id if available
    if (previousResponseId) {
      requestParams.previous_response_id = previousResponseId
    }

    // Call OpenAI Responses API (non-streaming)
    const response = await openai.responses.create(requestParams)

    // Extract text from the response output
    let fullText = ''
    const output = response.output
    if (output && output.length > 0) {
      const content = (output[0] as any)?.content
      if (content && content.length > 0) {
        fullText = content[0]?.text || ''
      }
    }

    if (!fullText) {
      console.error('No text in response output:', JSON.stringify(response.output))
    }

    // Extract token usage
    const tokensUsed = response.usage?.total_tokens || 0
    const responseId = response.id || ''

    // DALL-E generation costs 8 additional credits
    const dalleCredits = 8
    let generatedImageUrl: string | null = null
    let dalleCreditsUsed = 0

    // Check if GPT-4o wants to generate an image
    const generateMatch = fullText.match(/\[GENERATE_IMAGE:\s*(.+?)\]/s)
    if (generateMatch) {
      const dallePrompt = generateMatch[1].trim()

      // Check if user has enough credits for DALL-E generation
      const canGenerateImage = (usageRecord.credits_used + creditCost + dalleCredits) <= usageRecord.credits_limit

      if (canGenerateImage) {
        try {
          console.log('Generating image with DALL-E:', dallePrompt.substring(0, 100) + '...')

          // Generate image with DALL-E
          const dalleBase64 = await generateImageWithDalle(openai, dallePrompt)

          // Upload to Supabase Storage
          generatedImageUrl = await uploadImageToStorage(
            supabaseClient,
            user.id,
            conversationId,
            dalleBase64,
            'generated',
            'image/png'
          )

          dalleCreditsUsed = dalleCredits
          console.log('Image generated and uploaded:', generatedImageUrl)
        } catch (dalleError) {
          console.error('DALL-E generation failed:', dalleError)
          fullText = fullText.replace(
            /\[GENERATE_IMAGE:\s*.+?\]/s,
            '\n\n(Image generation failed. Please try again.)'
          )
        }
      } else {
        fullText = fullText.replace(
          /\[GENERATE_IMAGE:\s*.+?\]/s,
          '\n\n(Image generation skipped - quota limit reached. Please upgrade your plan for more credits.)'
        )
      }

      // Remove the marker from displayed text (if image was generated successfully)
      if (generatedImageUrl) {
        fullText = fullText.replace(/\[GENERATE_IMAGE:\s*.+?\]/s, '').trim()
      }
    }

    // INCREMENT USAGE COUNTERS after successful response
    // Uses SECURITY DEFINER RPC so the increment lands regardless of RLS policies.
    try {
      const { error: updateError } = await adminClient
        .rpc('increment_usage', {
          p_usage_id: usageRecord.id,
          p_user_id:  user.id,
          p_messages: messageCost,
          p_images:   imageCost + (generatedImageUrl ? 1 : 0),
          p_credits:  creditCost + dalleCreditsUsed
        })

      if (updateError) {
        console.error('Failed to update usage:', updateError)
      }
    } catch (usageUpdateError) {
      console.error('Exception updating usage:', usageUpdateError)
    }

    // Return the response as JSON
    return new Response(
      JSON.stringify({
        reply: fullText,
        responseId: responseId,
        model: modelUsed,
        tokens_used: tokensUsed,
        generated_image_url: generatedImageUrl
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Edge function error:', error)
    return new Response(
      JSON.stringify({
        reply: "I'm sorry, I'm having trouble processing your request right now. Please try again."
      }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})
