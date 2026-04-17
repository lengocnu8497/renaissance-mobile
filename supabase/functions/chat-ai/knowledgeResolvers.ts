export type ActiveProcedure = {
  procedureName: string
  procedureId: string | null
  source: 'message' | 'conversation' | 'recovery_plan' | 'journal' | 'profile'
  confidence: 'high' | 'medium' | 'low'
}

export type RecoveryPlanCacheRow = {
  procedure_id?: string | null
  procedure_name: string
  procedure_date: string
  generated_at: string
  current_phase_id: string
  current_phase_title: string
  current_phase_status: string
  current_phase_summary: string
  current_phase_focus_areas: string[] | null
  personalization_summary: string[] | null
  plan_json?: Record<string, unknown> | null
}

type UserSnapshot = {
  name: string | null
  demographicsLine: string | null
  goals: string[]
  bodyAreas: string[]
  proceduresOfInterest: string[]
  previousProcedures: string[]
  healthFlags: string[]
}

type JournalSnapshot = {
  procedureName: string
  latestEntryDate: string
  currentRecoveryDay: number | null
  recentEntryCount: number
  latestMetrics: {
    pain: number | null
    swelling: number | null
    bruising: number | null
    redness: number | null
    overall: number | null
  }
  trendSummary: string[]
  latestNotes: string[]
  latestAISummary: string | null
}

type ProcedureKnowledgeSnippet = {
  procedureName: string
  category: string
  recoveryLabel: string | null
  type: 'surgical' | 'non_surgical'
  summary: string
}

type RecoveryPlanSnapshot = {
  procedureName: string
  procedureDate: string
  generatedAt: string
  currentPhaseId: string
  currentPhaseTitle: string
  currentPhaseStatus: string
  currentPhaseSummary: string
  currentPhaseFocusAreas: string[]
  personalizationSummary: string[]
}

export function normalizeText(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9\s/+-]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
}

export function flattenConversationText(history: any[] | undefined): string {
  if (!history || history.length === 0) return ''

  const parts: string[] = []
  for (const message of history.slice(-6)) {
    const content = message?.content

    if (typeof content === 'string') {
      parts.push(content)
      continue
    }

    if (Array.isArray(content)) {
      for (const item of content) {
        if (typeof item?.text === 'string') {
          parts.push(item.text)
        } else if (typeof item?.content === 'string') {
          parts.push(item.content)
        }
      }
    }
  }

  return parts.join('\n')
}

function trimText(value: string | null | undefined): string | null {
  const trimmed = value?.trim()
  return trimmed ? trimmed : null
}

function uniqueStrings(values: (string | null | undefined)[]): string[] {
  return [...new Set(values.map((value) => value?.trim()).filter(Boolean) as string[])]
}

function findProcedureDetails(
  procedureName: string,
  procedures: Record<string, any>[]
): { id: string | null, canonicalName: string } {
  const normalized = normalizeText(procedureName)
  const match = procedures.find((procedure) => normalizeText(procedure.name) === normalized)
  return {
    id: match?.id ?? null,
    canonicalName: match?.name ?? procedureName,
  }
}

export function resolveActiveProcedure(params: {
  message: string
  conversationHistory: any[] | undefined
  userProfile: Record<string, any>
  journalEntries: Record<string, any>[]
  recoveryPlanRows: RecoveryPlanCacheRow[]
  procedures: Record<string, any>[]
}): ActiveProcedure | null {
  const normalizedMessage = normalizeText(params.message)
  const normalizedConversation = normalizeText(flattenConversationText(params.conversationHistory))

  const candidates = new Map<string, {
    procedureName: string
    score: number
    source: ActiveProcedure['source']
    confidence: ActiveProcedure['confidence']
  }>()

  const addCandidate = (
    rawName: string | null | undefined,
    score: number,
    source: ActiveProcedure['source'],
    confidence: ActiveProcedure['confidence']
  ) => {
    const procedureName = trimText(rawName)
    if (!procedureName) return
    const key = normalizeText(procedureName)
    const existing = candidates.get(key)
    if (!existing || score > existing.score) {
      candidates.set(key, { procedureName, score, source, confidence })
    }
  }

  for (const procedure of params.procedures) {
    const normalizedProcedureName = normalizeText(procedure.name)
    if (normalizedMessage.includes(normalizedProcedureName)) {
      addCandidate(procedure.name, 100, 'message', 'high')
    } else if (normalizedConversation.includes(normalizedProcedureName)) {
      addCandidate(procedure.name, 60, 'conversation', 'medium')
    }
  }

  const latestJournalProcedure = trimText(params.journalEntries?.[0]?.procedure_name)
  addCandidate(latestJournalProcedure, 40, 'journal', 'medium')

  const latestRecoveryPlanProcedure = trimText(params.recoveryPlanRows?.[0]?.procedure_name)
  addCandidate(latestRecoveryPlanProcedure, 45, 'recovery_plan', 'medium')

  for (const name of params.userProfile.procedures_of_interest ?? []) {
    addCandidate(name, 25, 'profile', 'low')
  }
  for (const name of params.userProfile.previous_procedures ?? []) {
    addCandidate(name, 20, 'profile', 'low')
  }

  const winner = [...candidates.values()].sort((lhs, rhs) => rhs.score - lhs.score)[0]
  if (!winner) return null

  const details = findProcedureDetails(winner.procedureName, params.procedures)
  return {
    procedureName: details.canonicalName,
    procedureId: details.id,
    source: winner.source,
    confidence: winner.confidence,
  }
}

export function buildUserSnapshot(profile: Record<string, any>): UserSnapshot | null {
  const demographics = [
    trimText(profile.gender),
    trimText(profile.age_range) ? `age range ${trimText(profile.age_range)}` : null,
    trimText(profile.race_ethnicity),
  ].filter(Boolean) as string[]

  const snapshot: UserSnapshot = {
    name: trimText(profile.full_name),
    demographicsLine: demographics.length ? demographics.join(', ') : null,
    goals: uniqueStrings(profile.aesthetic_goals ?? []),
    bodyAreas: uniqueStrings(profile.body_areas_of_interest ?? []),
    proceduresOfInterest: uniqueStrings(profile.procedures_of_interest ?? []),
    previousProcedures: uniqueStrings(profile.previous_procedures ?? []),
    healthFlags: uniqueStrings(profile.health_flags ?? []),
  }

  const hasContent = snapshot.name
    || snapshot.demographicsLine
    || snapshot.goals.length
    || snapshot.bodyAreas.length
    || snapshot.proceduresOfInterest.length
    || snapshot.previousProcedures.length
    || snapshot.healthFlags.length

  return hasContent ? snapshot : null
}

export function buildJournalSnapshot(params: {
  activeProcedure: ActiveProcedure | null
  journalEntries: Record<string, any>[]
}): JournalSnapshot | null {
  if (!params.journalEntries || params.journalEntries.length === 0) return null

  const normalizedActiveProcedure = normalizeText(params.activeProcedure?.procedureName ?? '')
  const relevantEntries = params.journalEntries
    .filter((entry) => {
      if (!normalizedActiveProcedure) return true
      return normalizeText(entry.procedure_name ?? '') === normalizedActiveProcedure
    })
    .slice(0, 5)

  const entries = relevantEntries.length ? relevantEntries : params.journalEntries.slice(0, 5)
  const latest = entries[0]
  if (!latest?.procedure_name) return null

  const oldest = entries[entries.length - 1]
  const trendSummary: string[] = []

  const addTrend = (
    label: string,
    latestValue: number | null | undefined,
    oldestValue: number | null | undefined
  ) => {
    if (latestValue == null || oldestValue == null || latestValue === oldestValue) return
    const improving = latestValue < oldestValue
    trendSummary.push(`${label} ${improving ? 'improving' : 'trending higher'} over recent entries`)
  }

  addTrend('Swelling is', latest.swelling_index, oldest?.swelling_index)
  addTrend('Pain is', latest.pain_index, oldest?.pain_index)

  const latestNotes = entries
    .map((entry) => trimText(entry.notes))
    .filter(Boolean)
    .slice(0, 2)
    .map((note) => note!.slice(0, 180))

  return {
    procedureName: latest.procedure_name,
    latestEntryDate: latest.entry_date,
    currentRecoveryDay: latest.day_number ?? null,
    recentEntryCount: entries.length,
    latestMetrics: {
      pain: latest.pain_index ?? null,
      swelling: latest.swelling_index ?? null,
      bruising: latest.bruising_index ?? null,
      redness: latest.redness_index ?? null,
      overall: latest.overall_score ?? null,
    },
    trendSummary,
    latestNotes,
    latestAISummary: trimText(latest.summary),
  }
}

export function selectRecoveryPlanSnapshot(params: {
  activeProcedure: ActiveProcedure | null
  recoveryPlanRows: RecoveryPlanCacheRow[]
}): RecoveryPlanSnapshot | null {
  if (!params.recoveryPlanRows || params.recoveryPlanRows.length === 0) return null

  const normalizedActiveProcedure = normalizeText(params.activeProcedure?.procedureName ?? '')
  const matchingRow = params.recoveryPlanRows.find((row) =>
    normalizedActiveProcedure
      ? normalizeText(row.procedure_name) === normalizedActiveProcedure
      : true
  ) ?? params.recoveryPlanRows[0]

  return {
    procedureName: matchingRow.procedure_name,
    procedureDate: matchingRow.procedure_date,
    generatedAt: matchingRow.generated_at,
    currentPhaseId: matchingRow.current_phase_id,
    currentPhaseTitle: matchingRow.current_phase_title,
    currentPhaseStatus: matchingRow.current_phase_status,
    currentPhaseSummary: matchingRow.current_phase_summary,
    currentPhaseFocusAreas: matchingRow.current_phase_focus_areas ?? [],
    personalizationSummary: matchingRow.personalization_summary ?? [],
  }
}

export function buildProcedureKnowledge(params: {
  activeProcedure: ActiveProcedure | null
  procedures: Record<string, any>[]
  userProfile: Record<string, any>
}): ProcedureKnowledgeSnippet[] {
  const scored = params.procedures.map((procedure) => {
    const normalizedName = normalizeText(procedure.name)
    let score = 0

    if (params.activeProcedure && normalizeText(params.activeProcedure.procedureName) === normalizedName) {
      score += 100
    }
    if ((params.userProfile.procedures_of_interest ?? []).some((name: string) => normalizeText(name) === normalizedName)) {
      score += 35
    }
    if ((params.userProfile.previous_procedures ?? []).some((name: string) => normalizeText(name) === normalizedName)) {
      score += 20
    }

    return { procedure, score }
  })

  return scored
    .filter((item) => item.score > 0)
    .sort((lhs, rhs) => rhs.score - lhs.score)
    .slice(0, 3)
    .map(({ procedure }) => ({
      procedureName: procedure.name,
      category: procedure.category ?? 'Other',
      recoveryLabel: procedure.recovery_duration_label ?? null,
      type: procedure.is_surgical ? 'surgical' : 'non_surgical',
      summary: String(procedure.description ?? '').split('. ')[0]?.trim() ?? '',
    }))
}

export function buildRecentConversationSummary(conversationHistory: any[] | undefined): string | null {
  const recentConversation = flattenConversationText(conversationHistory)
  const summary = trimText(recentConversation)?.slice(0, 600) ?? null
  return summary
}

export function buildKnowledgePack(params: {
  userSnapshot: UserSnapshot | null
  activeProcedure: ActiveProcedure | null
  journalSnapshot: JournalSnapshot | null
  recoveryPlanSnapshot: RecoveryPlanSnapshot | null
  procedureKnowledge: ProcedureKnowledgeSnippet[]
  recentConversationSummary: string | null
}): string {
  const lines: string[] = ['--- KNOWLEDGE PACK ---']

  if (params.userSnapshot) {
    lines.push('', 'USER SNAPSHOT')
    if (params.userSnapshot.name) lines.push(`Name: ${params.userSnapshot.name}`)
    if (params.userSnapshot.demographicsLine) lines.push(`Demographics: ${params.userSnapshot.demographicsLine}`)
    if (params.userSnapshot.goals.length) lines.push(`Goals: ${params.userSnapshot.goals.join(', ')}`)
    if (params.userSnapshot.bodyAreas.length) lines.push(`Body areas of interest: ${params.userSnapshot.bodyAreas.join(', ')}`)
    if (params.userSnapshot.proceduresOfInterest.length) lines.push(`Procedures of interest: ${params.userSnapshot.proceduresOfInterest.join(', ')}`)
    if (params.userSnapshot.previousProcedures.length) lines.push(`Previous procedures: ${params.userSnapshot.previousProcedures.join(', ')}`)
    if (params.userSnapshot.healthFlags.length) lines.push(`Health flags: ${params.userSnapshot.healthFlags.join(', ')}`)
  }

  if (params.activeProcedure) {
    lines.push('', 'ACTIVE PROCEDURE')
    lines.push(`Procedure: ${params.activeProcedure.procedureName}`)
    lines.push(`Resolved from: ${params.activeProcedure.source}`)
    lines.push(`Confidence: ${params.activeProcedure.confidence}`)
    if (
      params.journalSnapshot
      && normalizeText(params.journalSnapshot.procedureName) === normalizeText(params.activeProcedure.procedureName)
    ) {
      lines.push('Current status: the user already appears to be in recovery for this procedure.')
    }
  }

  if (params.journalSnapshot) {
    const metrics = params.journalSnapshot.latestMetrics
    lines.push('', 'RECENT RECOVERY SIGNALS')
    lines.push(`Procedure: ${params.journalSnapshot.procedureName}`)
    lines.push(`Current recovery day: ${params.journalSnapshot.currentRecoveryDay ?? 'Unknown'}`)
    lines.push(`Latest logged: ${params.journalSnapshot.latestEntryDate}`)
    lines.push(`Recent entries: ${params.journalSnapshot.recentEntryCount}`)
    lines.push(
      `Latest metrics: pain ${metrics.pain ?? 'n/a'}/10, swelling ${metrics.swelling ?? 'n/a'}/10, bruising ${metrics.bruising ?? 'n/a'}/10, redness ${metrics.redness ?? 'n/a'}/10`
    )
    if (params.journalSnapshot.trendSummary.length) {
      lines.push('Trend summary:')
      for (const trend of params.journalSnapshot.trendSummary.slice(0, 2)) {
        lines.push(`- ${trend}`)
      }
    }
    if (params.journalSnapshot.latestNotes.length) {
      lines.push('Latest notes:')
      for (const note of params.journalSnapshot.latestNotes) {
        lines.push(`- ${note}`)
      }
    }
    if (params.journalSnapshot.latestAISummary) {
      lines.push(`Latest AI summary: ${params.journalSnapshot.latestAISummary}`)
    }
  }

  if (params.recoveryPlanSnapshot) {
    lines.push('', 'CURRENT RECOVERY PLAN')
    lines.push(`Procedure: ${params.recoveryPlanSnapshot.procedureName}`)
    lines.push(`Current phase: ${params.recoveryPlanSnapshot.currentPhaseTitle}`)
    lines.push(`Phase summary: ${params.recoveryPlanSnapshot.currentPhaseSummary}`)
    if (params.recoveryPlanSnapshot.currentPhaseFocusAreas.length) {
      lines.push('Focus areas:')
      for (const area of params.recoveryPlanSnapshot.currentPhaseFocusAreas.slice(0, 4)) {
        lines.push(`- ${area}`)
      }
    }
    if (params.recoveryPlanSnapshot.personalizationSummary.length) {
      lines.push('Personalization:')
      for (const summary of params.recoveryPlanSnapshot.personalizationSummary.slice(0, 4)) {
        lines.push(`- ${summary}`)
      }
    }
  }

  if (params.procedureKnowledge.length) {
    lines.push('', 'PROCEDURE KNOWLEDGE')
    for (const snippet of params.procedureKnowledge) {
      lines.push(`- ${snippet.procedureName} (${snippet.category}, ${snippet.type}, recovery ${snippet.recoveryLabel ?? 'Unknown'}): ${snippet.summary}`)
    }
  }

  if (params.recentConversationSummary) {
    lines.push('', 'RECENT CONVERSATION')
    lines.push(params.recentConversationSummary)
  }

  if (
    params.activeProcedure
    && params.journalSnapshot
    && normalizeText(params.journalSnapshot.procedureName) === normalizeText(params.activeProcedure.procedureName)
  ) {
    lines.push('', 'RESPONSE PRIORITY')
    lines.push('Answer in a post-op or current-state frame for this procedure unless the user explicitly asks about a future procedure or revision.')
  }

  lines.push('', '--- END KNOWLEDGE PACK ---')
  return lines.join('\n')
}
