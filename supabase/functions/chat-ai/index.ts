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

    const { message, conversationHistory, previousResponseId } = await req.json()

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
                "action-oriented while still being educational"

    // Initialize OpenAI client
    const openai = new OpenAI({
      apiKey: Deno.env.get('OPENAI_API_KEY'),
    })

    // Build the input messages
    let inputMessages: any[]

    // If we have a previous response ID, include it for context continuity
    if (previousResponseId) {
      inputMessages = [{ role: 'user', content: message }]
      console.log(`Including previous_response_id: ${previousResponseId}`)
    } else if (conversationHistory && conversationHistory.length > 0) {
      // Include conversation history for first message or non-reasoning models
      inputMessages = [
        ...conversationHistory,
        { role: 'user', content: message }
      ]
    } else {
      inputMessages = [{ role: 'user', content: message }]
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

        }

        // Send final message with complete response
        await writer.write(encoder.encode(`data: ${JSON.stringify({
          type: 'done',
          reply: fullText,
          responseId: responseId
        })}\n\n`))

        console.log(`Streaming complete. Response ID: ${responseId}, Full text length: ${fullText.length}`)
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