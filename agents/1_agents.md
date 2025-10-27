
# Intro

## 5 workflow design patterns

1. Prompt chaining: decompose into fixed sub-tasks
2. Routing: direct an input into a specialised sub-task, ensuring separation of concerns
3. Parallelisation: breaking down tasks and running multiple subtasks concurrently
4. Orchestrator-worker: complex tasks are broken down dynamically and combined
5. Evaluator-optimiser: LLM output is validated by another

By contrast, Agents:
1. Open-ended
2. Feedback loops
3. No fixed path

## Agentic AI Frameworks

There are 3 levels of Agentic AI Frameworks in terms of their complexity:
- Level 3: LangGraph, AutoGen
- Level 2: OpenAI Agents SDK, Crew AI
- Level 1: No framework, MCP

## Tools

- Tools are at the heart of Agentic LLM
- They give an LLM the power to carry out actions like query a database or message other LLMs
- In practices LLM does not call the tools itself. It responds with the actions needed and your programme has to call the tools.

# Open AI Agents SDK

## Async
- All the Agent Frameworks use asynchronous python.
- `Asyncio` provides a lightweight alternative to threading or multiprocessing.
- Functions defined with `async def` are called coroutines - they're special functions that can be paused and resumed.
- Calling a coroutine doesn't execute it immediately - it returns a coroutine object.
- To actually run a coroutine, you must `await` it, which schedules it for execution within an `event loop`.
- While a coroutine is waiting (e.g. for I/O), the `event loop` can run other coroutines.

## Intro

- Lightweight and flexible
- Not opinionated 
- Works with different models, not just gpt

## Three steps

- Create an instance of Agent
- Use `with trace()` to track the agent
- Call `runner.run()` to run the agent (async coroutine)

## Vibe coding tips

- Good vibes - prompt well - ask for short answers and latest APIs for today's date
- Vibe but verify - ask 2 LLMs the same question
- Step up the vibe - ask to break down your request into independently testable steps
- Vibe and validate - ask an LLM then get another LLM to check
- Vibe with variety - ask for 3 solutions to the same problem, pick the best


## Tools and handoffs

- You can convert a function to a tool using the `@function_tool` decorator
- You can convert an agent to a tool using `as_tool` agent method
- Agents can collaborate with each other as tools or as handoffs
- With tools it's more like a request/response model, the control comes back to the calling agent
- With handoffs the control is handed over to the other agent (and does not come back)

## Guardrails

- Use `@input_guardrail` annotation to define a guardrails
- Pass it as `input_guardrails` to an agent
- The agent will throw a standardised `InputGuardrailTripwireTriggered` exception if violation detected
- Use `output_type` for structured outputs


## Deep Research

- OpenAI provides 3 hosted tools: `WebSearchTool`, `FileSearchTool` and `ComputerTool`


# Crew AI

## Intro

- CrewAI Enterprise
- CrewAI UI Studio
- CrewAI open-source framework

Two flavours of the OSS framework:
- `CrewAI Crews` - autonomous solutions with AI teams of Agents with different roles
- `CrewAI Flows` - structured automations by dividing complex tasks into precise workflows

## Core concepts

`Agent`: an autonomous unit, with an LLM, a role, a goal, a backstory, memory, tools
`Task`: a specific assignment to be carried out, with a description, expected output agent
`Crew`: a team of `Agents` and `Tasks`; either:
 - Sequential: run tasks in order they are defined
 - Hierarchical: use a Manager LLM to assign 
 
The key file is `crew.py`.

Install crewai: `uv tool install crewai` 
Create a new project: `crewai create crew my_crew` 
Run with: `crewai run` 

## Going deeper

`Tools`: equiping agents with capabilities
`Context`: information passed from one  task to another
`Structed output`:
`Custom tools`:
`Hierarchical process`:

## Memory

CreaAI is highly opinionated about memory.

Several types of memory:
- `Short-term memory` - temporarily stores recent interactions and outcomes using RAG (in a vector database), enabling agents to access relevant information during the current executions.
- `Long-term memory` - preserves valuable insights and learnings (in a SQL database), building knowledge over time.
- `Entity memory` - information about people, places and concepts encountered during tasks, facilitating deeper understanding and relationship mapping. Uses RAG for storing entity information.
- `Contextual memory` - maintains the context of interactions by combining all of the above.
- `User memory` - stores user-specific information and preferences, enhancing personalization and user experience (this is up to us to manage and include in prompts)

## Giving coding skills to an agent

It's hard and complex, but you can have an Agent in Crew that has the ability to write code, execute it in a Docker container, and investigate results.

Except it's not.
```python
Agent(
    allow_code_execution=True,
    code_execution_mode="Safe"
)
```