# RAG Implementation Plan for Kindura Voice Agent

**Status**: FUTURE PLAN - Not yet approved for implementation
**Created**: 2025-12-13
**Last Updated**: 2025-12-13

## Overview
Implement Retrieval-Augmented Generation (RAG) to enable the voice agent to learn about each user over time, remember past conversations, and provide increasingly personalized health guidance.

## User Choices
- **Vector Store**: pgvector (PostgreSQL) - Keep all data in one place
- **Memory Types**: Everything (conversations, preferences, health patterns, personal facts, medication insights)
- **Retrieval Mode**: Hybrid - Load context at session start + retrieve on specific triggers (health questions, medication topics)
- **Compliance**: HIPAA-compliant architecture required
- **HIPAA Approach**: TBD - User will decide between Azure OpenAI vs Self-Hosted

---

## HIPAA Compliance Architecture

### Option A: Azure OpenAI (Recommended)
Azure OpenAI offers HIPAA compliance with BAA (Business Associate Agreement).

**Services to use:**
- **Embeddings**: Azure OpenAI `text-embedding-ada-002`
- **LLM**: Azure OpenAI `gpt-4o` or `gpt-4o-mini`
- **Speech-to-Text**: Azure Speech Services (HIPAA compliant)
- **Text-to-Speech**: Azure Speech Services (HIPAA compliant)

**Benefits:**
- Same API as OpenAI (minimal code changes)
- Microsoft signs BAA for HIPAA coverage
- Data stays in your Azure tenant
- Enterprise security controls

### Option B: Fully Self-Hosted (Maximum Privacy)
Run everything on your own infrastructure.

**Services to use:**
- **Embeddings**: `sentence-transformers/all-MiniLM-L6-v2` (local)
- **LLM**: Llama 3.1 70B via Ollama or vLLM (local)
- **Speech-to-Text**: Whisper (local) or Azure Speech
- **Text-to-Speech**: Coqui TTS (local) or Azure Speech

**Benefits:**
- Zero data leaves your servers
- Full control over all processing
- No third-party dependencies

**Drawbacks:**
- Requires GPU server ($200-500/month)
- Lower quality than GPT-4
- More maintenance

### Recommended: Option A (Azure OpenAI)

```
┌─────────────────────────────────────────────────────────────────┐
│                 HIPAA-COMPLIANT RAG ARCHITECTURE                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                YOUR AZURE TENANT (BAA Covered)            │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐   │  │
│  │  │Azure OpenAI │  │Azure Speech │  │Azure PostgreSQL │   │  │
│  │  │(GPT-4, Ada) │  │(STT + TTS)  │  │(with pgvector)  │   │  │
│  │  └─────────────┘  └─────────────┘  └─────────────────┘   │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              │                                  │
│                              ▼                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              YOUR SERVER (Django + LiveKit Agent)         │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐   │  │
│  │  │RAG Service  │  │LiveKit Agent│  │Django API       │   │  │
│  │  │(Python)     │  │(Python)     │  │(Python)         │   │  │
│  │  └─────────────┘  └─────────────┘  └─────────────────┘   │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              │                                  │
│                              ▼                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    LiveKit Cloud                          │  │
│  │         (Real-time audio/video transport only)            │  │
│  │              NO PHI stored - transient only               │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### HIPAA Compliance Checklist

| Requirement | Implementation |
|-------------|----------------|
| **BAA** | Sign BAA with Azure for OpenAI + Speech + PostgreSQL |
| **Encryption at Rest** | Azure PostgreSQL with TDE enabled |
| **Encryption in Transit** | TLS 1.2+ for all connections |
| **Access Controls** | Azure AD + RBAC for service access |
| **Audit Logging** | Azure Monitor + PostgreSQL audit logs |
| **Data Retention** | Configurable retention policies |
| **PHI Minimization** | Only store necessary health data |
| **User Consent** | App must obtain consent for data collection |

### Code Changes for Azure OpenAI

**File: `kinduralivekit-0.0.1/utils/rag_service.py`**

```python
from openai import AzureOpenAI

class RAGService:
    def __init__(self, auth_token: str, base_url: str):
        # Use Azure OpenAI instead of OpenAI
        self.client = AzureOpenAI(
            api_key=os.getenv("AZURE_OPENAI_API_KEY"),
            api_version="2024-02-01",
            azure_endpoint=os.getenv("AZURE_OPENAI_ENDPOINT")
        )

    async def generate_embedding(self, text: str) -> List[float]:
        response = self.client.embeddings.create(
            model="text-embedding-ada-002",  # Azure deployment name
            input=text
        )
        return response.data[0].embedding
```

**File: `kinduralivekit-0.0.1/agent.py`**

```python
# Replace OpenAI with Azure OpenAI for LLM
from livekit.plugins import openai as livekit_openai

# Configure Azure OpenAI
session = AgentSession(
    llm=livekit_openai.LLM.with_azure(
        model="gpt-4o-mini",  # Azure deployment name
        azure_endpoint=os.getenv("AZURE_OPENAI_ENDPOINT"),
        api_key=os.getenv("AZURE_OPENAI_API_KEY"),
        api_version="2024-02-01"
    ),
    # Azure Speech for STT/TTS (HIPAA compliant)
    stt=azure_speech.STT(
        speech_key=os.getenv("AZURE_SPEECH_KEY"),
        speech_region=os.getenv("AZURE_SPEECH_REGION")
    ),
    tts=azure_speech.TTS(
        speech_key=os.getenv("AZURE_SPEECH_KEY"),
        speech_region=os.getenv("AZURE_SPEECH_REGION")
    ),
    ...
)
```

### Environment Variables Needed

```bash
# .env
AZURE_OPENAI_API_KEY=your_azure_openai_key
AZURE_OPENAI_ENDPOINT=https://your-resource.openai.azure.com/
AZURE_SPEECH_KEY=your_azure_speech_key
AZURE_SPEECH_REGION=eastus  # or your region

# PostgreSQL (can be Azure PostgreSQL or self-hosted with encryption)
DATABASE_URL=postgresql://user:pass@host:5432/kindura_db?sslmode=require
```

---

## Current State Analysis

### Data Already Being Collected:
- **PatientObservation**: Sleep, mood, symptoms, energy, falls, side effects (timestamped)
- **MedicationEvent**: Dose taken/missed/late with timestamps
- **WatchVitals**: Heart rate, SpO2, sleep data time series
- **Biomarker**: Lab values with dates and facilities
- **PatientReport**: AI-generated daily/weekly/monthly summaries
- **Conversation transcripts**: Saved in Toon format to `user_logs/` and uploaded via API

### What's Missing:
1. No vector embeddings for semantic search
2. No conversation message persistence (only summaries)
3. No memory model for user preferences/patterns
4. No retrieval mechanism for relevant context

---

## Architecture Design

```
┌─────────────────────────────────────────────────────────────────┐
│                        KINDURA RAG SYSTEM                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────┐  │
│  │   LiveKit    │───▶│  RAG Service │───▶│  OpenAI LLM      │  │
│  │   Agent      │◀───│  (Python)    │◀───│  (gpt-4o-mini)   │  │
│  └──────────────┘    └──────────────┘    └──────────────────┘  │
│         │                   │                                   │
│         │                   ▼                                   │
│         │          ┌──────────────────┐                        │
│         │          │  Vector Store    │                        │
│         │          │  (pgvector)      │                        │
│         │          └──────────────────┘                        │
│         │                   │                                   │
│         ▼                   ▼                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    PostgreSQL                            │   │
│  │  ┌─────────────┐ ┌─────────────┐ ┌───────────────────┐  │   │
│  │  │Conversation │ │ Memory      │ │ Embedding         │  │   │
│  │  │Messages     │ │ Store       │ │ Cache             │  │   │
│  │  └─────────────┘ └─────────────┘ └───────────────────┘  │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Implementation Steps

### Phase 1: Database Schema (Django Backend)

**File: `KinduraAPIs-0.0.1/users/models.py`**

Add new models:

```python
# 1. ConversationMessage - Store individual messages
class ConversationMessage(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    session_id = models.CharField(max_length=100)  # LiveKit session
    role = models.CharField(max_length=20)  # 'user' or 'assistant'
    content = models.TextField()
    embedding = ArrayField(models.FloatField(), size=1536, null=True)  # OpenAI ada-002
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            models.Index(fields=['user', '-created_at']),
            models.Index(fields=['session_id']),
        ]

# 2. UserMemory - Long-term user knowledge
class UserMemory(models.Model):
    MEMORY_TYPES = [
        ('preference', 'User Preference'),      # "prefers morning calls"
        ('pattern', 'Behavioral Pattern'),       # "usually takes meds late on weekends"
        ('fact', 'Personal Fact'),              # "has daughter named Sarah"
        ('health', 'Health Pattern'),           # "blood pressure spikes after coffee"
        ('medication', 'Medication Insight'),   # "metformin causes nausea"
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE)
    memory_type = models.CharField(max_length=20, choices=MEMORY_TYPES)
    key = models.CharField(max_length=200)  # Short identifier
    content = models.TextField()  # Full memory content
    embedding = ArrayField(models.FloatField(), size=1536, null=True)
    confidence = models.FloatField(default=1.0)  # 0-1, decays over time
    source_messages = models.JSONField(default=list)  # Message IDs that formed this memory
    created_at = models.DateTimeField(auto_now_add=True)
    last_accessed = models.DateTimeField(auto_now=True)
    access_count = models.IntegerField(default=0)

    class Meta:
        indexes = [
            models.Index(fields=['user', 'memory_type']),
            models.Index(fields=['user', '-confidence']),
        ]

# 3. EmbeddingCache - Cache embeddings for observations/reports
class EmbeddingCache(models.Model):
    CONTENT_TYPES = [
        ('observation', 'Patient Observation'),
        ('report', 'Patient Report Summary'),
        ('biomarker', 'Biomarker Result'),
        ('medication', 'Medication Info'),
        ('insight', 'Health Insight'),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE)
    content_type = models.CharField(max_length=20, choices=CONTENT_TYPES)
    content_id = models.IntegerField()  # FK to source record
    content_text = models.TextField()  # Text that was embedded
    embedding = ArrayField(models.FloatField(), size=1536)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ['user', 'content_type', 'content_id']
        indexes = [
            models.Index(fields=['user', 'content_type']),
        ]
```

---

### Phase 2: RAG Service (New Python Module)

**File: `kinduralivekit-0.0.1/utils/rag_service.py`**

```python
class RAGService:
    """Retrieval-Augmented Generation service for Kindura agent"""

    def __init__(self, auth_token: str, base_url: str):
        self.auth_token = auth_token
        self.base_url = base_url
        self.openai_client = openai.OpenAI()

    # --- Embedding Generation ---
    async def generate_embedding(self, text: str) -> List[float]:
        """Generate embedding using OpenAI ada-002"""
        response = self.openai_client.embeddings.create(
            model="text-embedding-ada-002",
            input=text
        )
        return response.data[0].embedding

    # --- Message Storage ---
    async def save_message(self, session_id: str, role: str, content: str):
        """Save conversation message with embedding"""
        embedding = await self.generate_embedding(content)
        # POST to /api/users/conversation-messages/

    # --- Memory Extraction ---
    async def extract_memories(self, session_id: str):
        """Extract learnable facts from conversation session"""
        # 1. Fetch all messages from session
        # 2. Use LLM to identify memorable facts
        # 3. Deduplicate with existing memories
        # 4. Store new memories with embeddings

    # --- Context Retrieval ---
    async def get_relevant_context(self, query: str, limit: int = 10) -> str:
        """Retrieve relevant context for user query"""
        query_embedding = await self.generate_embedding(query)

        # 1. Search recent conversation messages (last 7 days)
        # 2. Search user memories
        # 3. Search relevant observations
        # 4. Search relevant biomarker insights

        # Combine and format for agent prompt
        return formatted_context

    # --- Memory Management ---
    async def decay_memories(self):
        """Reduce confidence of unused memories over time"""
        # Run periodically to prevent memory bloat
```

---

### Phase 3: Django API Endpoints

**File: `KinduraAPIs-0.0.1/users/views.py`**

Add new endpoints:

```python
# POST /api/users/conversation-messages/
# Save a conversation message with embedding

# GET /api/users/conversation-messages/search/
# Vector similarity search on messages

# POST /api/users/memories/
# Create/update a user memory

# GET /api/users/memories/
# Get user memories (optionally by type)

# POST /api/users/rag/context/
# Get relevant RAG context for a query

# POST /api/users/rag/extract-memories/
# Extract memories from a conversation session
```

---

### Phase 4: Agent Integration

**File: `kinduralivekit-0.0.1/agent.py`**

Modify agent to use RAG:

```python
# 1. Initialize RAG service
_rag_service = None

async def entrypoint(ctx: agents.JobContext):
    global _rag_service
    _rag_service = RAGService(auth_token, BASE_URL)

    # 2. Get relevant context before building prompt
    user_query_context = ""  # Will be populated during conversation

    # 3. Add RAG context to agent prompt
    full_prompt = global_variables.agent_prompt.format(
        ...existing params...,
        rag_context=rag_context,  # NEW
        user_memories=user_memories,  # NEW
    )

# 4. Add message logging to conversation flow
# After each user message and agent response, call:
await _rag_service.save_message(session_id, role, content)

# 5. Extract memories at end of session
ctx.add_shutdown_callback(extract_session_memories)
```

---

### Phase 5: Memory Extraction Logic

**File: `kinduralivekit-0.0.1/utils/memory_extractor.py`**

```python
MEMORY_EXTRACTION_PROMPT = """
Analyze this conversation and extract any learnable facts about the user.
Focus on:
- Personal preferences (communication style, timing preferences)
- Health patterns (when symptoms occur, medication effects)
- Personal facts (family members, lifestyle details)
- Medication insights (side effects, what helps)

Return JSON array of memories:
[
  {
    "type": "preference|pattern|fact|health|medication",
    "key": "short identifier",
    "content": "full memory content",
    "confidence": 0.0-1.0
  }
]

Only extract clear, factual information. Avoid speculation.
"""

async def extract_memories_from_conversation(messages: List[dict]) -> List[dict]:
    """Use LLM to extract memorable facts from conversation"""
    conversation_text = format_messages(messages)

    response = await gpt_model.chat(
        system_prompt=MEMORY_EXTRACTION_PROMPT,
        user_prompt=conversation_text,
        response_format={"type": "json_object"}
    )

    return json.loads(response)["memories"]
```

---

## Data Flow (Hybrid Retrieval Mode)

### At Session Start:
1. User connects to LiveKit room
2. **Initial RAG context loaded**:
   - Recent user memories (last 30 days, top 20 by confidence)
   - Recent conversation summaries (last 7 days)
   - Current health status (medications, recent observations)
3. Context injected into initial agent prompt

### During Conversation:
1. User speaks → Transcribed by LiveKit
2. Agent receives message
3. **Trigger-based retrieval** (if message contains health/medication keywords):
   - Search for relevant past observations
   - Search for related biomarker data
   - Search for similar past conversations
4. Retrieved context added to LLM context
5. Agent responds with personalized answer
6. **Both messages saved with embeddings**

### Trigger Keywords for Dynamic Retrieval:
- Medication names (from user's med list)
- Health terms: "pain", "symptom", "feeling", "side effect", "sleep", "energy"
- Time references: "last week", "before", "usually", "pattern"
- Questions about history: "remember", "told you", "mentioned"

### After Conversation:
1. Session ends
2. **Memory extraction runs** on conversation
3. New memories saved to UserMemory table
4. Existing memories updated if reinforced

### Periodic Maintenance:
1. Decay unused memories (reduce confidence)
2. Merge similar memories
3. Re-embed observations/reports as they're created

---

## Key Files to Modify

| File | Changes |
|------|---------|
| `KinduraAPIs-0.0.1/users/models.py` | Add ConversationMessage, UserMemory, EmbeddingCache models |
| `KinduraAPIs-0.0.1/users/views.py` | Add RAG API endpoints |
| `KinduraAPIs-0.0.1/users/urls.py` | Add URL routes |
| `KinduraAPIs-0.0.1/users/serializers.py` | Add serializers for new models |
| `kinduralivekit-0.0.1/utils/rag_service.py` | **NEW** - RAG service class |
| `kinduralivekit-0.0.1/utils/memory_extractor.py` | **NEW** - Memory extraction logic |
| `kinduralivekit-0.0.1/agent.py` | Integrate RAG into agent flow |
| `kinduralivekit-0.0.1/utils/global_variables.py` | Update prompt with RAG placeholders |
| `KinduraAPIs-0.0.1/requirements.txt` | Add `pgvector` dependency |

---

## Dependencies to Add

```
# KinduraAPIs-0.0.1/requirements.txt
pgvector==0.2.4
numpy>=1.24.0

# kinduralivekit-0.0.1/requirements.txt
openai>=1.0.0  # Already present, for embeddings API
numpy>=1.24.0
```

---

## Example RAG Context Output

When user asks "How am I doing with my medications?", RAG retrieves:

```
## Relevant Context from Past Interactions

From conversation 3 days ago:
- You mentioned feeling nauseous after taking Metformin in the morning
- You asked about taking it with food instead

From your health patterns:
- Your adherence is typically lower on weekends (72% vs 94% weekdays)
- You tend to take evening medications 15-30 minutes late

Recent observations:
- Dec 10: Reported mild stomach discomfort after morning meds
- Dec 8: Energy level was "low" - correlated with missed Vitamin D

## What I Remember About John

- Prefers brief, direct responses (preference)
- Takes medications better when reminded by daughter Sarah (fact)
- Metformin causes nausea if taken without food (medication)
- Blood pressure tends to be higher on Monday mornings (health)
```

---

## Success Metrics

1. **Personalization**: Agent references past conversations naturally
2. **Accuracy**: Retrieved context is relevant to current query
3. **Memory Growth**: User memories accumulate over time
4. **Performance**: RAG retrieval < 500ms latency
5. **User Satisfaction**: Users feel "understood" by the agent

---

## Implementation Order

1. **Week 1**: Database models + migrations + pgvector setup
2. **Week 2**: RAG service + API endpoints
3. **Week 3**: Agent integration + message logging
4. **Week 4**: Memory extraction + testing
5. **Week 5**: Refinement + performance optimization
