# RakuLLM — implementation plan

**Repo** `ddr-ai/RakuLLM` (empty, no default branch) · **Bundle ID** `io.github.ddr-ai.rakullm` · **Target** iOS 17.0, SwiftUI, arm64 device, unsigned IPA via GitHub Actions · **Conventions** mirror `ddr-ai/depot` + `ddr-ai/vidX`

> Every table below is at most two narrow columns so nothing clips or scrolls sideways when this file is opened in a mobile Markdown viewer. Detail that will not fit in a cell lives in a bullet directly underneath its table.

## Read-order

| Phase | Read |
| --- | --- |
| 0 skeleton | §5, §9 R1 |
| 1 chat | §6 P1, §7, §8 |
| 2 llama.cpp | §6 P2, §8 |
| 3 huggingface | §6 P3 |
| 4 MCP | §6 P4, §8 |
| 5 local tools | §6 P5 |
| 6 polish | §6 P6 |

Load only what the current phase needs. Sections are self-contained; no phase requires re-reading an earlier one.

## 1. Scope

**In, all four pillars**

- Cloud providers: Gemini, OpenAI, Grok, Anthropic.
- Hugging Face as the model search interface; download GGUF; run on device.
- Silent automatic configuration check on every model load.
- Remote MCP servers with per-server permissions, usable by cloud and local models.

**Also in v1**

- Token, speed, and cost tracking.
- Edit, regenerate, fork.
- Prompt library and personas.

**Out of v1**

- Vision / image input; voice; LAN LLM servers (Ollama, LM Studio).
- Chat export; encrypted key backup; document RAG.
- Apple FoundationModels; MLX-Swift; LiteRT-LM.
- MCP OAuth 2.1, stdio transport, resources, prompts.
- Generic custom-base-URL provider field.

**Out-of-scope items that still constrain v1 design**

- *No export.* Re-signing a free-Apple-ID app can reset the container, losing chats and Keychain secrets. Handle inside existing UI only: on launch, a configured provider whose Keychain secret is gone shows a re-enter prompt instead of a silent 401. Do not add an export feature.
- *No MCP stdio.* `mcp.json` import will meet `command` entries. Mark them unsupported with a reason; never skip silently.

## 2. Decisions

| ID | Decision |
| --- | --- |
| D1 | XCFramework via `bootstrap.sh` |
| D2 | llama.cpp / GGUF only engine |
| D3 | MCP auth is a bearer token |
| D4 | Presets + per-tool + per-chat |
| D5 | Native tool calls, else router |
| D6 | Config check silent and automatic |
| D7 | Hub search shows fit badges |
| D8 | MCP: manual plus `mcp.json` |
| D9 | Four providers, no custom URL |
| D10 | XcodeGen, project gitignored |
| D11 | SwiftData, JSON, Keychain |
| D12 | Committed `Info.plist` |
| D13 | Streaming, no big buffers |

Rationale:

- **D1** — llama.cpp XCFramework via `bootstrap.sh`. The official artefact; nothing binary enters git; CI keeps control over signing a nested framework inside an unsigned build.
- **D2** — llama.cpp with GGUF is the only on-device engine. MediaPipe dropped its iOS LLM engine in v1.0.0; LiteRT-LM is young; MLX reads only Q4_0 / Q4_1 / Q8_0 from GGUF (everything else upcasts to fp16, about 4x RAM) and collides with llama.cpp on the `gguf_get_key` symbol.
- **D3** — MCP auth is a per-server bearer token. Reaches every self-hosted and API-key server. OAuth 2.1 is deferred.
- **D4** — MCP permissions are presets plus per-tool and per-conversation overrides. The default of Allow all honours "full control unless specified", and the per-conversation override is the dropdown beside the composer, so one conversation can be stricter without editing server settings.
- **D5** — Local models use native tool calling with a decoding grammar when capable, else an app-side intent router. This is the only approach that covers the whole 1B–4B zoo without degrading local models to chat-only.
- **D6** — The config check is fully automatic and silent. Manual overrides live in a per-model settings panel instead.
- **D7** — Hub search shows per-quant device-fit badges. Most Hub models are far too large for a phone, and finding out after a multi-gigabyte download is unacceptable.
- **D8** — MCP onboarding is manual URL plus token, with `mcp.json` import. Manual-only is tedious; a curated directory needs upkeep.
- **D9** — Exactly four providers, no custom base-URL field. Grok shares the OpenAI wire format internally, so it is one table entry rather than a new provider.
- **D10** — XcodeGen, generated `.xcodeproj` gitignored. Matches vidX and avoids a hand-maintained pbxproj.
- **D11** — SwiftData for chats, JSON manifests on disk for models, Keychain for secrets. No persistence precedent exists in the prior repos.
- **D12** — A committed `Resources/Info.plist`. The ATS and local-network keys do not suit `INFOPLIST_KEY_` build settings.
- **D13** — Streaming everywhere with no unbounded buffering. See §3.

## 3. Context-window and memory discipline

Non-negotiable. Every rule keeps token spend and RAM bounded without silently degrading output.

**T1 — Exact token counting.** Local: `llama_tokenize` against the loaded GGUF. Cloud: provider `usage` after the fact; before the fact estimate conservatively as `ceil(chars / 3.5) + 4` per message and round **up**. Never under-count.

**T2 — Window budget.** `windowBudget = n_ctx - reserve`, where `reserve = min(maxOutputTokens, n_ctx / 4)`. A request never exceeds `windowBudget`.

**T3 — History windowing, never a silent cut.** System prompt and persona are retained verbatim and always sent. Walk turns newest-to-oldest while `used + turnTokens <= windowBudget`. If a single newest turn does not fit, stop and surface an explicit choice — raise context, start a new conversation, or trim — rather than mangling the message. Pruned messages are not deleted: the UI draws a "pruned to fit context" divider so the transcript stays truthful.

**T4 — Explicit output cap.** Always send `maxOutputTokens = max(256, n_ctx - promptTokens)`. Never rely on a provider default; unbounded generation is the main way a context window gets exceeded.

**T5 — Streaming only.** No code path buffers a full response. Assistant text is persisted to the message row incrementally, throttled to every 500 ms or 256 chars, so a crash mid-stream loses at most one chunk.

**T6 — MCP tool-result cap.** Hard cap 64 KB of text per result. Over the cap, truncate on a UTF-8 boundary and append `[truncated N of M bytes — re-run the tool with a narrower query]`. An unbounded tool result is the single most likely way this app exceeds a context window.

**T7 — Tool-schema budget.** Tools are scored for relevance by the `IntentRouter` scorer, then admitted best-first until schema tokens reach `min(8 KB, windowBudget / 4)`. State the withheld tool names in the system prompt so the model says a capability is unavailable instead of hallucinating it.

**T8 — Bounded buffers.** SSE frame buffer max 1 MB — a larger frame is a server bug, so fail the request. Non-streamed response bodies cap 8 MB. Hub search paginates at 50. Tool catalogs cache per server and invalidate on `notifications/tools/list_changed`.

**T9 — Memory ceilings.** Refuse to load when weights plus KV exceed 60% of available RAM. Cap `n_gpu_layers` by the Metal working-set budget, not total RAM. Free the inference context when idle over 10 minutes; keep weights resident.

**T10 — Implementing-agent token hygiene.** Read a phase's sections plus §2 only; grep and slice rather than pasting whole files; cap any source file near 400 lines and split along the §4 layout; each phase ends green so no later phase re-reads earlier code beyond its own files.

## 4. Layout

```text
project.yml
scripts/llama-version.env      pinned XCFramework tag + sha256
scripts/bootstrap.sh           download, verify, unzip, strip signature
scripts/make_icon.py           1024px procedural icon, stdlib only
.github/workflows/ipa.yml      build + unsigned IPA + ios-latest release
RakuLLMTests/                  unit tests for all pure-Swift logic
RakuLLM/App/                   RakuLLMApp, AppEnvironment, Theme, RootTabView
RakuLLM/Models/                Conversation, Message, Persona, ProviderConfig,
                               MCPServerRecord, MCPToolPolicy, DownloadRecord,
                               ModelRecord, ModelSettings
RakuLLM/Providers/             LLMProvider, ChatRequest, ChatEvent, Gemini,
                               OpenAI, Grok, Anthropic, SSECodec
RakuLLM/Inference/             LLMEngine, LlamaEngine, GGUFReader, DeviceProfile,
                               AutoConfigurator, TokenCounter, ChatTemplateProbe,
                               JSONSchemaGrammar, IntentRouter
RakuLLM/MCP/                   MCPClient, JSONRPC, StreamableHTTP, MCPRegistry,
                               MCPConfigImporter, PermissionEngine, ToolCatalog
RakuLLM/HF/                    HubAPI, ModelSearch, DownloadManager, FitCalculator
RakuLLM/Services/              ChatOrchestrator, TokenMeter, CostTable, Keychain
RakuLLM/Views/                 Chat/, Models/, MCP/, Settings/, Components/
RakuLLM/Resources/             Info.plist, Assets.xcassets
```

## 5. Build and CI

`scripts/llama-version.env` holds `LLAMA_TAG` and `LLAMA_SHA256`. The newest llama.cpp build observed at planning time is `b10842` (2026-09-07). Confirm the current tag at implementation and never change the tag without replacing the checksum. `bootstrap.sh` hard-fails on digest mismatch. Unzip to `Vendor/llama.xcframework`, which is gitignored.

`project.yml` dependency block:

```yaml
dependencies:
  - framework: Vendor/llama.xcframework
    embed: true
    codeSign: false
```

Target settings beyond the vidX base: `LD_RUNPATH_SEARCH_PATHS = $(inherited) @executable_path/Frameworks`, `SUPPORTED_PLATFORMS = iphoneos`, `TARGETED_DEVICE_FAMILY = 1`, `SWIFT_VERSION = 5.0`.

`macos-15` workflow. Triggers: push to `main` plus `workflow_dispatch`. `contents: write`. Concurrency on `${{ github.ref }}`.

1. checkout; `sudo xcode-select`; `scripts/bootstrap.sh`
2. `scripts/make_icon.py`
3. `xcodegen generate`
4. `xcodebuild test -scheme RakuLLMTests -destination 'platform=iOS Simulator,name=iPhone 16'`
5. build Release for `generic/platform=iOS` with `CODE_SIGNING_ALLOWED=NO`, `CODE_SIGNING_REQUIRED=NO`, `CODE_SIGN_IDENTITY=""`, `DEVELOPMENT_TEAM=""`, `ARCHS=arm64`, `ONLY_ACTIVE_ARCH=NO`, `COMPILER_INDEX_STORE_ENABLE=NO`
6. **framework smoke check** — assert `RakuLLM.app/Frameworks/llama.framework/llama` exists, `otool -L` on the app binary lists `@rpath/llama.framework/llama`, and `otool -l` shows `LC_BUILD_VERSION` with platform iOS
7. `codesign --force --deep --sign -` the bundle; `ditto -c -k --keepParent` into `RakuLLM.ipa`
8. upload artefact with `compression-level: 0`; recreate the rolling `ios-latest` release

`set -euo pipefail` in every multi-line block; keep the `test -s` guards.

`Info.plist` beyond depot's set:

- `NSAppTransportSecurity.NSAllowsLocalNetworking = true` — LAN `http://` MCP without disabling ATS generally
- `NSLocalNetworkUsageDescription`
- `ITSAppUsesNonExemptEncryption = false`
- portrait-only; forced dark mode; `UILaunchScreen` bound to `LaunchBackground`
- **No `UIBackgroundModes`** — see R4

## 6. Phases

Each ends with a green IPA.

**P0 — Skeleton and pipeline.** `project.yml`, `.gitignore`, `Info.plist`, asset catalog, `Theme.swift` (depot palette pattern, `Avenir Next` scale), `RakuLLMApp`, stub `RootTabView`, `bootstrap.sh`, `make_icon.py`, `ipa.yml` including steps 4 and 6. Sideload the stub IPA on the phone before writing any feature: R1 is verified here or nowhere.

**P1 — Providers, chat, persistence, personas, metrics.** `LLMProvider.stream(_:) -> AsyncThrowingStream<ChatEvent, Error>`, where `ChatEvent` is `.textDelta`, `.thinking`, `.usage`, `.done`. One shared SSE parser carrying the T8 cap. Gemini, OpenAI, Grok on the same codec, Anthropic. SwiftData `Conversation` and `Message`. Chat view with streaming, stop, and per-message metric chips. `Persona` plus built-ins. `TokenMeter`, `CostTable`. Apply T1 through T5 from the start.

**P2 — llama.cpp and the configuration check.** `LlamaEngine` actor: `gguf_init_from_file`, `llama_model_load_from_file`, `llama_new_context_with_model`, token loop, callback bridged into `AsyncThrowingStream<ChatEvent>`. Plus `GGUFReader`, `DeviceProfile`, `TokenCounter`, `AutoConfigurator`, and the per-model settings panel. No llama symbol outside `LlamaEngine.swift`.

**P3 — Hugging Face.** `HubAPI`, `FitCalculator`, `ModelSearch` view, `DownloadManager` with progress and pause/resume via persisted resume data, plus the curated starter list.

**P4 — MCP.** `JSONRPC`, `StreamableHTTP`, `MCPClient`, `MCPRegistry`, `MCPConfigImporter`, `PermissionEngine`, and the MCP settings views. T6 and T7 land with this phase.

**P5 — Local tool routing.** `ChatTemplateProbe`, `JSONSchemaGrammar`, `IntentRouter`, the composer permission dropdown, tool-call rendering, approval sheets.

**P6 — Polish.** Empty, loading, and error states in house style; README; icon; first-run flow.

## 7. Data model

Each type is listed with its fields on wrapped lines so nothing runs off the page.

**`Conversation`**
`id`, `title`, `createdAt`, `updatedAt`, `providerKind`,
`modelIdentifier`, `personaID`, `systemPromptOverride`,
`toolPermissionOverride` (`inherit` / `allowAll` / `confirmEach` / `allowlist`),
`forkedFromID`, `forkedAtMessageID`, `pinned`

**`Message`**
`id`, `conversationID`, `sequence`, `role`, `text`, `createdAt`,
`variants` (`[String]`), `activeVariant`,
`tokensIn`, `tokensOut`, `ttps`, `firstTokenMs`, `durationMs`,
`costUSD`, `isUsageEstimated`, `toolInvocationID`

**`ModelRecord`**
`id` (`repo::filename`), `repo`, `filename`, `localPath`, `fileSizeBytes`,
`quantLabel`, `archLabel`, `parameterCount`, `contextLength`,
`chatTemplatePresent`, `supportsTools`, `downloadState`, `progress`,
`sha256`, `lastUsedAt`

**`ModelSettings`**
`modelID`, `nCtx`, `nBatch`, `nGPUlayers`, `nThreads`, `kvCacheType`,
`useMmap`, `flashAttention`, `backend`,
plus a per-field `isOverridden` flag set only by manual edits

**`MCPServerRecord`**
`id`, `name`, `url`, `transport`, `sessionID`, `protocolVersion`,
`serverInfoJSON`, `lastConnectedAt`, `lastError`, `mode`, `enabled`

**`MCPToolPolicy`**
`serverID`, `toolName`,
`override` (`inherit` / `alwaysAllow` / `alwaysDeny`),
`isConfirmedDestructive`

Message variants live on the message, so regenerate and swipe-between need no extra table.

## 8. Specs

### 8.1 Providers

| Provider | Endpoint |
| --- | --- |
| Gemini | `models:streamGenerateContent` |
| OpenAI | `api.openai.com/v1/chat/completions` |
| Grok | `api.x.ai/v1/chat/completions` |
| Anthropic | `api.anthropic.com/v1/messages` |

- **Gemini** — `POST /v1beta/{model}:streamGenerateContent?alt=sse`, auth header `x-goog-api-key`. Body `contents[{role, parts}]`, top-level `systemInstruction`, `generationConfig`. Usage arrives in the trailing `usageMetadata`.
- **OpenAI / Grok** — auth header `Authorization: Bearer`. Set `stream_options.include_usage = true`; text is at `choices[0].delta.content`.
- **Anthropic** — auth headers `x-api-key` plus `anthropic-version: 2023-06-01`. `system` is a top-level parameter, not a message. Handle `message_start`, `content_block_delta` carrying `text_delta` and `thinking_delta`, and `message_delta` for usage.

Shared `ChatRequest`: messages, systemPrompt, temperature, topP, maxOutputTokens (always set, per T4), stopSequences, tools. Shared `Usage`: inputTokens, outputTokens, cachedInputTokens, reasoningTokens.

Transport: `URLSession.bytes(for:)`, incremental `text/event-stream` parse, `Task.cancel()` to abort. The OpenAI Responses API is a follow-up; Chat Completions is what Grok shares and is fully supported.

Store one golden JSON request fixture per provider in `RakuLLMTests`.

### 8.2 Automatic configuration check

Silent, runs on every load, never overwrites an override.

1. **GGUF metadata** — `general.architecture`, `general.file_type`, `<arch>.context_length`, `.embedding_length`, `.block_count`, `.attention.head_count`, `.attention.head_count_kv`, `.rope.dimension_count`, `tokenizer.chat_template`.
2. **Device** — `hw.memsize` via `sysctlbyname`; `os_proc_available_memory()`; `volumeAvailableCapacityForImportantUsage`; `MTLCreateSystemDefaultDevice()` plus `recommendedMaxWorkingSetSize`; `uname` machine id mapped to a RAM tier, using the `L*`/`D*` identifier rather than marketing names.
3. **Budget** — usable = available x 0.60. If weights alone exceed it, refuse and name the file size, the available memory, and the largest quant in the same repo that would fit.
4. **Context** — `min(trainedContext, budgetCap)` snapped to 2048 / 4096 / 8192 / 16384. KV bytes = `n_ctx * n_layers * n_kv_heads * head_dim * 2 * bytesPerElement`; re-test the budget after choosing.
5. **KV type** — `f16` at 8192 context or below, `q8_0` above.
6. **Offload** — all layers if weights plus KV fit the Metal budget, else `floor((gpuBudget - overhead) / bytesPerLayer)`, else 0.
7. **Threads** — `activeProcessorCount` clamped to 1...6; more regresses on mobile SoCs.
8. **Batch** — `n_batch` 256, `n_ubatch` 128, mmap on, flash attention on when arch and build allow.
9. **Backend** — `.metal` if a Metal device exists, else `.cpu` in the simulator or after a Metal init failure, else a clear refusal if neither initialises.

All resolved values stay visible in the per-model settings panel, with the auto-chosen value shown next to any override.

### 8.3 Hugging Face

- **Search** — `GET /api/models` with `filter=gguf`, `search`, `sort=downloads`, `direction=-1`, `limit=50`, `full=true`. Send an optional `Authorization: Bearer` from a stored HF token for gated repos.
- **File listing** — `GET /api/models/{repo}/tree/main?recursive=1`.
- **Download** — `https://huggingface.co/{repo}/resolve/main/{path}` via a `URLSessionDownloadDelegate` task writing `Application Support/Models/<repo>__<file>.part`, then renamed. Persist resume data. Set `isExcludedFromBackup = true`.
- **Fit badge** — per GGUF file, `fileSize + kvEstimate(4096) <= available * 0.60` is *fits*; at 85% of that it is *tight*; otherwise *too large*. Label the 4096 reference context so the number is interpretable.

### 8.4 MCP

Streamable HTTP only, spec revision `2025-06-18`.

Every request: `POST`, `Accept: application/json, text/event-stream`, `Content-Type: application/json`, `Authorization: Bearer <token>`, and `MCP-Protocol-Version` once negotiated.

Lifecycle: `initialize`, capture the `Mcp-Session-Id` response header, send `notifications/initialized`, then `tools/list`. On a `404` for any request carrying a session id, drop the session, re-initialise, and retry once — a spec requirement. Parse either a plain JSON body or SSE frames.

**Send no `Origin` header.** Servers must validate `Origin` against DNS rebinding, and a request carrying no `Origin` is the legitimate non-browser case.

`mcp.json` import accepts both `mcpServers` and `servers` keys. A `url` entry becomes a server; a `command` entry is recorded unsupported, with the reason.

### 8.5 Permissions

Precedence, highest first: `alwaysDeny`, `alwaysAllow`, conversation override, server default.

Modes are `allowAll` (the default), `confirmEach`, and `allowlist`. The conversation override is a dropdown beside the composer showing the current mode and how many servers and tools it covers; `inherit` defers to each server's setting.

A destructive-name heuristic scans tool name plus description for `delete`, `remove`, `destroy`, `drop`, `erase`, `write`, `send`, `post`, `put`, `patch`, `create`, `exec`, `run`, `shell`, `command`, `publish`, `deploy`, `transfer`, `invoice`, `payment`, `revoke`. A match forces a one-time confirmation per tool per server, recorded in `isConfirmedDestructive`, regardless of mode. The approval sheet always shows the server, the tool, and the exact arguments.

### 8.6 Local tool routing

**Probe** — after `ModelRecord` is built, pass a synthetic tool array through `llama_chat_apply_template`. A serialised tool block in the output means natively capable; store it in `supportsTools`.

**Native path** — tools via the native template plus a GBNF grammar over `{"tool": "<enum of names>", "arguments": {...}}`. The XCFramework ships `llama.h` and the sampling API but **not** llama.cpp's `common/` directory, so `json_schema_to_grammar` is unavailable. Write a compact JSON-schema-to-GBNF converter in Swift over the MCP subset — object, array, string, integer, number, boolean, enum, required, `additionalProperties` — and enum-constrain `tool` so an invalid name is not generatable.

**Fallback path** — `IntentRouter` scores tools by token overlap between the user message and each tool's name plus description. The top three above threshold go to a confirm sheet; a clear top margin renders as a tappable chip instead. The same scorer drives T7.

Both paths pass through `PermissionEngine` before `tools/call`.

### 8.7 Chat features

Edit truncates from the edited message and re-runs. Regenerate appends a variant; the user swipes between them. Fork duplicates the conversation up to a chosen message. Personas are reusable system prompts, and the MCP persona embeds the live tool list plus the permission rules so a cloud model reasons about its real capabilities.

`CostTable` is a static per-million-token price map with an `effectiveDate`, user-editable because published prices change. Provider `usage` is used when available; otherwise the T1 estimate applies, setting `isUsageEstimated` so the UI can mark it.

## 9. Risks

| ID | Risk |
| --- | --- |
| R1 | Nested framework re-signing |
| R2 | Upstream tag vanishes |
| R3 | llama.cpp API churn |
| R4 | Downloads die when backgrounded |
| R5 | Container reset loses data |
| R6 | Weak local tool-call accuracy |
| R7 | MCP OAuth gap |

Mitigations:

- **R1** — The highest-impact risk. A prebuilt `llama.framework` inside an unsigned `.app` must be re-signed by the sideloading tool; if it is not, `dyld` fails at launch while CI stays green. Mitigate with `codeSign: false`, the ad-hoc `--force --deep --sign -`, the step 6 smoke check, and an on-device verification in P0.
- **R2** — Hard-fail on checksum. Bumping the pin is one line plus a new checksum.
- **R3** — All llama symbols confined to `LlamaEngine.swift`; bump in isolation.
- **R4** — Deliberate. A background `URLSession` needs `handleEventsForBackgroundURLSession`, which is unreliable under a 7-day free-Apple-ID expiry. Pause/resume plus the `.part` file survives termination.
- **R5** — Detection plus the re-enter prompt from §1. No export feature.
- **R6** — The Allow-all default makes a wrong pick consequential. Keep destructive confirmation regardless of mode, and always show exact arguments.
- **R7** — A 401 yields "server needs OAuth, not implemented yet — paste a token", not a generic error.

## 10. Validation

**CI on every push**

- Simulator unit tests
- Unsigned arm64 build
- Framework smoke check
- IPA non-empty and listing `Payload/RakuLLM.app`
- `ios-latest` recreated

**Unit tests** (`RakuLLMTests`, pure Swift)

- SSE framing, including split frames and multi-line `data:`
- The T8 1 MB frame cap
- JSON-RPC request and response shapes
- `StreamableHTTP` session-id handling, including the 404 re-initialise path
- Permission precedence across all four levels
- Destructive-name matching
- GGUF metadata parse against a synthetic fixture
- JSON-schema-to-GBNF over the MCP subset
- `FitCalculator` boundaries
- `CostTable` lookups
- Golden request JSON per provider
- T2 and T3 windowing arithmetic; T6 tool-result truncation at a UTF-8 boundary; T7 schema-budget admission
- Message branching and variant logic

**On the phone, per phase**

- Install from `ios-latest` via Sideloadly or AltStore
- One streamed conversation against each of the four providers
- Download a GGUF; confirm the check applied silently and the model loads
- An MCP tool call end to end under each permission mode
- Edit, regenerate, and fork
- Verify token and cost figures against provider dashboards

**Not established by this plan**

- Tokens per second on any specific device, which is a runtime property.
- Whether your sideloading tool re-signs nested frameworks. That is R1, deliberately first in P0.
