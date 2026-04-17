# Autonomous Orchestrator / Project Manager - Feature Specification

## Overview

This document specifies the implementation of an **Autonomous Orchestrator AI** that acts as a Project Manager for the Synapse AI platform. The orchestrator will keep projects moving autonomously while escalating decisions to the user via the built-in messaging capabilities when human input is required.

## Current Architecture Analysis

### Core Components

#### 1. **Backend Server** (`backend/core/server.py`)
- FastAPI-based server with lifespan management
- MCP (Model Context Protocol) client manager for external tool connections
- Agent sessions management for tool execution
- Messaging manager integration for multi-platform communication
- Schedule manager for timed orchestration execution

#### 2. **Orchestration Engine** (`backend/core/orchestration/engine.py`)
- Executes workflow graphs defined by `Orchestration` models
- Supports step types: AGENT, LLM, TOOL, EVALUATOR, PARALLEL, MERGE, LOOP, HUMAN, TRANSFORM, END
- Shared state management with JSON checkpointing
- SSE (Server-Sent Events) streaming for real-time updates
- Loop guards and turn limits for safety

#### 3. **Step Executors** (`backend/core/orchestration/steps.py`)
- **AgentStepExecutor**: Runs sub-agent ReAct loops
- **EvaluatorStepExecutor**: Pure LLM-based routing decisions
- **ParallelStepExecutor**: Sequential branch execution
- **MergeStepExecutor**: Combines parallel outputs
- **LoopStepExecutor**: Iterative body execution
- **HumanStepExecutor**: Pauses for human input via messaging
- **TransformStepExecutor**: Sandboxed Python code execution
- **LLMStepExecutor**: Direct LLM calls without agents
- **ToolStepExecutor**: Forced single tool calls
- **EndStepExecutor**: Terminates orchestration

#### 4. **Messaging System** (`backend/core/messaging/`)
- **Manager** (`manager.py`): Central lifecycle controller
  - Starts/stops adapters for enabled channels
  - Manages per-chat active agent selection
  - Handles human-step Future resolution (first-response-wins)
  - Provides agent runner function for all adapters
- **Base Adapter** (`base.py`): Abstract interface for platforms
  - Built-in commands: `/start`, `/help`, `/reset`, `/agent`, `/agents`
  - Command routing before agent processing
  - Human-step future resolution
- **Adapters**: Telegram, Discord, Slack, Teams, WhatsApp

#### 5. **Scheduler** (`backend/core/scheduler.py`)
- Interval and cron-based schedule execution
- Restart-proof state persistence
- Automatic overdue schedule handling
- Messaging notifications for schedule completion

#### 6. **Agent Models** (`backend/core/models.py`, `routes/agents.py`)
- Agent types: `conversational`, `analysis`, `code`, `orchestrator`
- Orchestrator agents have `orchestration_id` linking to workflow graphs
- Per-agent model overrides and turn limits
- System prompt generation via LLM

#### 7. **Orchestration Models** (`backend/core/models_orchestration.py`)
- `Orchestration`: Workflow graph with steps, entry point, state schema
- `StepConfig`: Node definition with type-specific configuration
- `OrchestrationRun`: Execution instance with shared state

---

## Feature Requirements

### 1. Autonomous Orchestrator Agent Type

**Goal**: Create a special "autonomous" agent type that continuously executes its orchestration without user intervention.

**Requirements**:
- New agent type: `autonomous` (extends `orchestrator`)
- Configurable autonomy level (1-100%)
- Automatic escalation to user via messaging when decisions are needed
- Continuous execution loop with configurable pause intervals

**Implementation**:
```python
# In backend/core/models.py, Agent model
class Agent(BaseModel):
    # ... existing fields ...
    type: str = "conversational"  # New value: "autonomous"
    autonomy_level: int = 50  # 0-100, percentage of autonomous execution
    escalation_threshold: float = 0.7  # Confidence threshold for escalation
    check_in_interval: int = 3600  # Seconds between user check-ins
```

### 2. Decision Escalation System

**Goal**: When the orchestrator encounters uncertain decisions, it should escalate to the user via messaging.

**Requirements**:
- Confidence scoring for all orchestration decisions
- Configurable escalation thresholds
- Messaging channel integration for user notifications
- User response handling via `/agent` commands or direct messages

**Implementation**:
- Add `confidence_score` field to `OrchestrationRun` and step results
- Create `Decision` model with:
  - `decision_id`: Unique identifier
  - `context`: Decision context and options
  - `confidence`: 0.0-1.0 score
  - `escalated`: Boolean flag
  - `user_response`: Stored response
- Modify `EvaluatorStepExecutor` to track confidence scores
- Add `HumanStepExecutor` enhancement for autonomous mode

### 3. Autonomous Execution Loop

**Goal**: The autonomous orchestrator runs continuously, executing its orchestration and making decisions independently until escalation is required.

**Requirements**:
- Background task for continuous execution
- Configurable execution intervals
- State persistence between runs
- Graceful shutdown handling

**Implementation**:
```python
# New file: backend/core/autonomous_manager.py
class AutonomousManager:
    """Manages autonomous orchestrator execution."""
    
    async def start(self, agent_id: str):
        """Start the autonomous execution loop."""
        while self._running:
            await self._execute_orchestration(agent_id)
            await asyncio.sleep(self.check_in_interval)
    
    async def _execute_orchestration(self, agent_id: str):
        """Execute the orchestrator's workflow."""
        # Load orchestration
        # Run orchestration with autonomy mode
        # Handle escalations via messaging
        # Update state and persist
```

### 4. Enhanced Human Step for Autonomous Mode

**Goal**: Modify `HumanStepExecutor` to support autonomous escalation patterns.

**Requirements**:
- Detect autonomous mode context
- Send escalation prompts to messaging channels
- Wait for user response with configurable timeout
- Resume orchestration after response

**Implementation**:
```python
# In backend/core/orchestration/steps.py, HumanStepExecutor
async def execute(self, step, run, engine):
    # ... existing code ...
    
    # Check if orchestrator is in autonomous mode
    if self._is_autonomous_mode():
        # Send escalation to messaging channels
        await self._escalate_to_messaging(step, run)
        
        # Wait for user response
        user_response = await self._wait_for_response(step, run)
        
        # Update shared state with response
        run.shared_state[step.output_key] = user_response
```

### 5. Decision Registry

**Goal**: Track all decisions made by the autonomous orchestrator for audit and learning.

**Requirements**:
- Persistent storage of decision history
- Confidence scores and outcomes
- User feedback tracking
- Analytics for improving autonomy

**Implementation**:
```python
# New file: backend/core/decision_registry.py
class DecisionRegistry:
    """Tracks and persists orchestration decisions."""
    
    async def record_decision(self, decision: Decision):
        """Record a new decision."""
        # Store in JSON file or database
        # Index by orchestration_id, timestamp
    
    async def get_decisions(self, orchestration_id: str, limit: int = 100):
        """Retrieve decision history."""
    
    async def analyze_confidence(self, orchestration_id: str):
        """Analyze confidence patterns for improvement."""
```

### 6. User Communication Interface

**Goal**: Enable users to interact with the autonomous orchestrator via messaging platforms.

**Requirements**:
- `/autonomous` command to check status
- `/approve <decision_id>` to approve escalations
- `/pause` and `/resume` commands
- Configuration via messaging

**Implementation**:
```python
# In backend/core/messaging/base.py, extend _handle_command
async def _handle_command(self, chat_id, command, args, session_id):
    # ... existing commands ...
    
    if command == "/autonomous":
        status = await self.manager.get_autonomous_status(chat_id)
        await self.send_message(chat_id, status)
        return True
    
    if command == "/approve":
        decision_id = args.strip()
        approved = await self.manager.approve_decision(chat_id, decision_id)
        await self.send_message(chat_id, f"Decision {decision_id} approved")
        return True
    
    if command == "/pause":
        await self.manager.pause_autonomous(chat_id)
        await self.send_message(chat_id, "Autonomous mode paused")
        return True
    
    if command == "/resume":
        await self.manager.resume_autonomous(chat_id)
        await self.send_message(chat_id, "Autonomous mode resumed")
        return True
```

### 7. Configuration UI Enhancements

**Goal**: Add UI components for configuring autonomous orchestrator settings.

**Requirements**:
- New "Autonomous" tab in Settings
- Autonomy level slider (0-100%)
- Escalation threshold configuration
- Messaging channel selection for notifications
- Execution interval settings

**Implementation**:
- New component: `frontend/src/components/settings/AutonomousTab.tsx`
- API endpoint: `GET /api/agents/autonomous-config`
- API endpoint: `POST /api/agents/autonomous-config`

---

## Implementation Plan

### Phase 1: Core Infrastructure (Week 1)

1. **Extend Agent Model**
   - Add `autonomy_level`, `escalation_threshold`, `check_in_interval` fields
   - Update `backend/core/models.py`
   - Update database migrations if applicable

2. **Create Autonomous Manager**
   - Implement `backend/core/autonomous_manager.py`
   - Background execution loop
   - State persistence
   - Graceful shutdown

3. **Enhance Human Step Executor**
   - Modify `backend/core/orchestration/steps.py`
   - Add autonomous mode detection
   - Implement escalation messaging

### Phase 2: Decision System (Week 2)

4. **Decision Registry**
   - Implement `backend/core/decision_registry.py`
   - Decision model with confidence scoring
   - Persistent storage

5. **Confidence Scoring**
   - Modify `EvaluatorStepExecutor`
   - Add confidence tracking to `OrchestrationRun`
   - Decision escalation logic

6. **Messaging Integration**
   - Extend `backend/core/messaging/base.py`
   - Add autonomous commands (`/autonomous`, `/approve`, `/pause`, `/resume`)
   - Test with all platform adapters

### Phase 3: UI & Configuration (Week 3)

7. **Autonomous Settings UI**
   - Create `frontend/src/components/settings/AutonomousTab.tsx`
   - Configure autonomy level, thresholds, intervals
   - Messaging channel selection

8. **Orchestration UI Enhancements**
   - Add autonomy controls to orchestration editor
   - Visual indicators for autonomous steps
   - Decision history viewer

9. **API Endpoints**
   - `GET /api/agents/autonomous-config`
   - `POST /api/agents/autonomous-config`
   - `GET /api/decisions`
   - `POST /api/decisions/:id/approve`

### Phase 4: Testing & Refinement (Week 4)

10. **Integration Testing**
    - Test autonomous execution with sample orchestrations
    - Verify escalation flow via messaging
    - Test pause/resume functionality

11. **Performance Optimization**
    - Optimize state checkpointing
    - Reduce memory footprint for long-running orchestrations
    - Add metrics and monitoring

12. **Documentation**
    - User guide for autonomous mode
    - API documentation
    - Troubleshooting guide

---

## Data Models

### Extended Agent Model
```python
class Agent(BaseModel):
    id: str
    name: str
    description: str
    avatar: str = "default"
    type: str = "conversational"  # New: "autonomous"
    tools: list[str]
    repos: list[str] = []
    db_configs: list[str] = []
    system_prompt: str
    orchestration_id: str | None = None
    model: str | None = None
    provider: str | None = None
    max_turns: int | None = None
    
    # Autonomous-specific fields
    autonomy_level: int = 50  # 0-100
    escalation_threshold: float = 0.7  # 0.0-1.0
    check_in_interval: int = 3600  # seconds
    enabled: bool = True
```

### Decision Model
```python
class Decision(BaseModel):
    decision_id: str
    orchestration_id: str
    step_id: str
    context: dict  # Decision context
    options: list[str]  # Available options
    confidence: float  # 0.0-1.0
    selected_option: str | None = None
    user_response: str | None = None
    escalated_at: str | None = None
    resolved_at: str | None = None
    status: str = "pending"  # pending, approved, rejected
```

### Autonomous Configuration Model
```python
class AutonomousConfig(BaseModel):
    agent_id: str
    autonomy_level: int = 50
    escalation_threshold: float = 0.7
    check_in_interval: int = 3600
    messaging_channels: list[str] = []  # channel_ids
    enabled: bool = True
    allowed_tools: list[str] = ["all"]
```

---

## Integration Points

### Existing Systems

1. **Orchestration Engine** (`backend/core/orchestration/engine.py`)
   - Integrate autonomous execution loop
   - Add confidence tracking to step results
   - Modify `_resolve_next()` for autonomous routing

2. **Messaging Manager** (`backend/core/messaging/manager.py`)
   - Add `get_autonomous_status()` method
   - Add `approve_decision()` method
   - Add `pause_autonomous()` / `resume_autonomous()` methods

3. **Scheduler** (`backend/core/scheduler.py`)
   - Support autonomous schedule triggers
   - Add autonomous execution to scheduled runs

4. **React Engine** (`backend/core/react_engine.py`)
   - Detect autonomous agent type
   - Delegate to orchestration engine
   - Handle autonomous-specific prompts

### New Components

1. **Autonomous Manager** (`backend/core/autonomous_manager.py`)
   - Background execution loop
   - Escalation handling
   - State management

2. **Decision Registry** (`backend/core/decision_registry.py`)
   - Decision persistence
   - Confidence analytics
   - Feedback tracking

3. **UI Components**
   - `AutonomousTab.tsx`
   - `DecisionHistoryView.tsx`
   - `AutonomyControl.tsx`

---

## Security Considerations

1. **Autonomy Level Limits**
   - Never allow 100% autonomy without any human oversight
   - Require minimum escalation threshold (e.g., 0.3)

2. **Tool Access Control**
   - Autonomous agents should have restricted tool access
   - Configurable allowed tools per agent

3. **Escalation Rate Limiting**
   - Prevent message spam from frequent escalations
   - Batch non-urgent escalations

4. **Audit Logging**
   - Log all autonomous decisions
   - Track user approvals/rejections
   - Monitor for anomalous behavior

---

## Testing Strategy

### Unit Tests
- `AutonomousManager` execution loop
- `DecisionRegistry` persistence
- Confidence scoring logic
- Human step escalation

### Integration Tests
- End-to-end autonomous orchestration
- Messaging channel escalation
- Pause/resume functionality
- UI configuration round-trip

### Manual Tests
- Test with sample orchestrations
- Verify escalation flow on each platform
- Test long-running autonomous sessions
- Verify state persistence across restarts

---

## Success Metrics

1. **Autonomy Achievement**
   - Percentage of orchestrations completed without human intervention
   - Target: 70%+ for well-defined workflows

2. **Escalation Accuracy**
   - False positive rate (unnecessary escalations)
   - False negative rate (missed escalations)
   - Target: <10% false positives, <5% false negatives

3. **User Satisfaction**
   - User approval rate for escalated decisions
   - Target: >80% approval rate

4. **Performance**
   - Time to execute orchestration vs. manual mode
   - Memory footprint for long-running sessions
   - Target: <20% overhead for autonomous mode

---

## Future Enhancements

1. **Learning from Feedback**
   - Use user approvals/rejections to improve confidence scoring
   - Adaptive escalation thresholds

2. **Multi-Orchestrator Coordination**
   - Multiple autonomous agents collaborating
   - Conflict resolution between orchestrators

3. **Predictive Escalation**
   - ML-based prediction of when human input is needed
   - Proactive rather than reactive escalation

4. **Autonomy Marketplace**
   - Pre-configured autonomous orchestrator templates
   - Community-shared autonomy profiles

---

## Conclusion

This specification defines a comprehensive Autonomous Orchestrator feature that enables Synapse AI to act as an autonomous Project Manager. The system balances automation with human oversight through configurable autonomy levels and messaging-based escalation.

The implementation follows a phased approach, starting with core infrastructure and progressively adding decision management, UI integration, and testing.

Key success factors:
- Clear separation of autonomous vs. manual execution modes
- Transparent escalation process via messaging
- Persistent state for long-running orchestrations
- Comprehensive audit logging for accountability
