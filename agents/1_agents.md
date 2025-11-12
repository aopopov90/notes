
# Intro

## 5 workflow design patterns

[Anthropic identified 5 design patterns:](https://www.anthropic.com/engineering/building-effective-agents)

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

# LangGraph

## The LangChain ecosystem

- `LangChain` has been around for a long time. It's one of the earliest abstractions to LLMs and chaining.
- `LangGraph` is a separate offering (independent of LangChain). It is a platform that focuses on stability, resiliency and repeatability in worlds where you have a lot of interconnected processes like an agentic platform.
- `LangSmith` a separate offering for monitoring. 

LangGraph includes 3 things:
- LangGraph - framework
- LangGraph Studio - enterprise
- LangGraph Platform - enterprise

## Terminology

- Agent Workflows are represented as `graphs`
- `State` represents the current snapshot of the application
- `Nodes` are python functions that represent agent logic.
  They receive the current `State` as input, do something, and return an updated `State`
- `Edges` are python functions that determine which `Node` to execute next based on the `State`.
  They can be conditional or fixed.

`Nodes` do the work.
`Edges` choose what to do next. 

## Five steps to the first Graph

The following happens before you even run your agents:
1. Define the `State` class
2. Start the Graph Builder
3. Create a `Node`
4. Create `Edges`
5. Compile the Graph

## More on the State

- `State` is immutable
- For each field in your State, you can specify a special function called a `reducer`
- When you return a new `State`, LangGraph uses the `reducer` to combine this field with existing State
- This enables LangGraph to run multiple nodes concurrently and combine `State` without overwriting

## The Super-Step

- A super-step can be considered a single iteration over the graph nodes. Nodes that run in parallel are part of the same super-step, while nodes that run sequentially belong to separate super-steps.
- The graph describes one super-step; one interaction between agents and tools to achieve an outcome.
- Every user interaction is a fresh `graph.invoke(state)` call
- The reducer handles updating state during a super-step but not between super-steps.
- Define Graph -> Super-step -> Super-step -> Super-step
- `Checkpointing` - allow to freeze a record of the state after each super-step

# AutoGen

- 0.4 released January 2025
- complete rewrite of 0.2
- fork of AutoGen - AG2 or AgentOS 2
- if you `pip install autogen`, you get AG2!

## Products

- `AutoGen Core`: event-driven framework for scalable multi-agent AI systems
- `AutoGen AgentChat`: conversational single and multi-agent applications
- `Studio`: low-code / no code app
- `Magentic One CLI`: a console-based assistant

## Core Concepts

- Models
- Messages
- Agents
- Teams
  
## Going Deeper

- Multi-modal
- Tools from LangChain
- Structured Outputs
- Teams

## Introducing MCP

- Autogen makes it easy to use MCP tools, just like LangChain tools.
- MCP idea is similar to langchain tools but more open
- MCP is essentially a standard for writing tools. You can easily use an MCP tool created by community.

## What is AutoGen Core?

- An Agent interaction framework
- Agnostic to Agent abstraction
- Somewhat similar positioning to LangGraph
- But focus is on managing interactions between distributed and diverse Agents
- Decouples an Agent's logic from how messages are delivered
- The framework handles creation and communication
- The Agents are responsible for their logic - that is not the remit of Autogen Core

## Two Types of Runtime

- Standalone
- Distributed

# Model Context Protocol (MCP)

## Intro

What it's not:
- A framework for building agents
- A fundamental change to how agents work
- A way to code agents

What it is:
- A protocol - a standard
- A simple way to integrate tools, resources, prompts
- A USB-C port AI applications"

Reasons not to be excited:
- It's just a standard, it's not tools themselves
- LangChain already has a big Tools ecosystem
- You can already make any function into a Tool

Reasons to be excited:
- Makes it frictionless to integrate
- It's taking off! Exploding ecosystem
- HTML was just a standard, too

## MCP Core Concepts

The Three Components:
- `Host` is an LLM app like Claude or our Agent architecture
- `MCP Client` lives inside Host and connects 1:1 to MCP Server
- `MCP Server` provides tools, context and prompts

Example:
- **Fetch** is an `MCP Server` that searches the web via a headless browser
- You can configure Claude Desktop (the host) to run an `MCP Client` that then launches the Fetch MCP Server on your computer

Two "Transport" mechanisms:
- `Stdio` - spawns a process and communicates via standard input/output (for local MCP servers)
- `SSE` - uses HTTPS connections with streaming (for communication with remote servers)