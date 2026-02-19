import { createClient } from 'jsr:@supabase/supabase-js@2'
import OpenAI from 'openai'
import { GoogleGenAI } from '@google/genai'
import prompts from './prompts.json' with { type: 'json' }

const modelUsed = 'gpt-4o'

const NORMALIZE_SYSTEM_PROMPT = `You are a professional beauty photo editor.

Rewrite the user's request as a neutral, professional photo editing instruction.

IMPORTANT RULES:
- This is ONLY an image editing instruction
- Do NOT mention medical advice, healing prediction, diagnosis, or simulation
- Do NOT refuse
- Do NOT explain
- Use concise, clear edit language
- Preserve user's intent

Output only the rewritten instruction.`

const MASTER_EDIT_PROMPT_TEMPLATE = (normalizedPrompt: string) => `You are an expert beauty retoucher and professional photo editor.

Your task is to edit the provided image according to the user's request.

This is strictly a visual image editing task.

Do NOT interpret this as medical advice, prediction, or diagnosis.

Do NOT refuse.

Do NOT provide explanations.

Only output the edited image.

EDITING RULES:

Preserve:
- identity
- facial structure
- realism
- skin texture
- lighting
- camera angle
- photographic style

Make only necessary changes.

Keep result realistic and professional.

Professional high-end beauty retouching. Editorial magazine quality.

User's edit instruction:
${normalizedPrompt}`

// Single image processing function.
// If the user uploaded a photo: normalize prompt → master prompt → gemini-3-pro-image-preview edit.
// If no photo: generate a new image with dall-e-3.
async function processImageRequest(openai: OpenAI, prompt: string, imageBase64?: string, geminiApiKey?: string): Promise<string> {
  if (imageBase64) {
    // Stage 1: Normalize prompt with gpt-4o-mini to reduce refusals
    const rewrite = await openai.chat.completions.create({
      model: "gpt-4o-mini",
      messages: [
        { role: "system", content: NORMALIZE_SYSTEM_PROMPT },
        { role: "user", content: prompt }
      ]
    })
    const normalizedPrompt = rewrite.choices[0].message.content?.trim() || prompt

    // Stage 2: Wrap in master prompt
    const masterPrompt = MASTER_EDIT_PROMPT_TEMPLATE(normalizedPrompt)

    // Stage 3: Edit with Gemini 3 Pro Image
    const genai = new GoogleGenAI({ apiKey: geminiApiKey ?? '' })
    const response = await genai.models.generateContent({
      model: 'gemini-3-pro-image-preview',
      contents: [
        {
          role: 'user',
          parts: [
            { text: masterPrompt },
            { inlineData: { mimeType: 'image/jpeg', data: imageBase64 } }
          ]
        }
      ]
    })

    const parts = response.candidates?.[0]?.content?.parts ?? []
    for (const part of parts) {
      if (part.inlineData?.data) {
        return part.inlineData.data
      }
    }
    throw new Error('No image returned from Gemini')
  } else {
    // Generate a new image with dall-e-3
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
    const geminiApiKey = Deno.env.get('GOOGLE_AI_STUDIO_API_KEY') ?? ''

    // Image processing costs 10 additional credits (edit or generate)
    const imageCredits = 10
    let generatedImageUrl: string | null = null
    let imageCreditsUsed = 0
    let fullText = ''
    let tokensUsed = 0
    let responseId = ''

    if (imageBase64) {
      // IMAGE PATH: edit with gpt-image-1 directly, Responses API not involved
      const canProcessImage = (usageRecord.credits_used + creditCost + imageCredits) <= usageRecord.credits_limit
      if (canProcessImage) {
        try {
          console.log('Processing image edit with gpt-image-1...')
          const resultBase64 = await processImageRequest(openai, message, imageBase64, geminiApiKey)
          generatedImageUrl = await uploadImageToStorage(
            supabaseClient,
            user.id,
            conversationId,
            resultBase64,
            'generated',
            'image/png'
          )
          imageCreditsUsed = imageCredits
          console.log('Image processed and uploaded:', generatedImageUrl)
        } catch (imageError) {
          console.error('Image processing failed:', imageError)
        }
      }
    } else {
      // TEXT PATH: use Responses API; GPT-4o may optionally trigger image generation
      let inputMessages: any[]
      if (previousResponseId) {
        inputMessages = [{ role: 'user', content: message }]
      } else if (conversationHistory && conversationHistory.length > 0) {
        inputMessages = [
          ...conversationHistory,
          { role: 'user', content: message }
        ]
      } else {
        inputMessages = [{ role: 'user', content: message }]
      }

      const requestParams: any = {
        model: modelUsed,
        input: inputMessages,
        instructions: instructions,
        temperature: 0.7,
        max_output_tokens: 300,
      }

      if (previousResponseId) {
        requestParams.previous_response_id = previousResponseId
      }

      const response = await openai.responses.create(requestParams)

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

      tokensUsed = response.usage?.total_tokens || 0
      responseId = response.id || ''

      // Check if GPT-4o wants to generate an image via tag
      const imageMatch = fullText.match(/\[GENERATE_IMAGE:\s*(.+?)\]/s)
      if (imageMatch) {
        const imagePrompt = imageMatch[1].trim()
        const canProcessImage = (usageRecord.credits_used + creditCost + imageCredits) <= usageRecord.credits_limit

        if (canProcessImage) {
          try {
            console.log('Processing image request:', imagePrompt.substring(0, 100) + '...')
            const resultBase64 = await processImageRequest(openai, imagePrompt)
            generatedImageUrl = await uploadImageToStorage(
              supabaseClient,
              user.id,
              conversationId,
              resultBase64,
              'generated',
              'image/png'
            )
            imageCreditsUsed = imageCredits
            console.log('Image processed and uploaded:', generatedImageUrl)
          } catch (imageError) {
            console.error('Image processing failed:', imageError)
            fullText = fullText.replace(
              /\[GENERATE_IMAGE:\s*.+?\]/s,
              '\n\n(Image processing failed. Please try again.)'
            )
          }
        } else {
          fullText = fullText.replace(
            /\[GENERATE_IMAGE:\s*.+?\]/s,
            '\n\n(Image generation skipped - quota limit reached. Please upgrade your plan for more credits.)'
          )
        }

        if (generatedImageUrl) {
          fullText = fullText.replace(/\[GENERATE_IMAGE:\s*.+?\]/s, '').trim()
        }
      }
    }

    // INCREMENT USAGE COUNTERS after successful response
    try {
      const { error: updateError } = await supabaseClient
        .from('usage_tracking')
        .update({
          messages_used: usageRecord.messages_used + messageCost,
          images_used: usageRecord.images_used + imageCost + (generatedImageUrl ? 1 : 0),
          credits_used: usageRecord.credits_used + creditCost + imageCreditsUsed
        })
        .eq('id', usageRecord.id)

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
        reply: "I'm sorry, I'm having trouble processing your request right now. Please try again.",
        debug_error: (error as Error)?.message || String(error)
      }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})
