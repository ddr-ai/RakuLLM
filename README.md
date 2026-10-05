# RakuLLM

A high-performance iOS LLM chat client combining cloud intelligence, on-device GGUF inference, Hugging Face discovery, and remote Model Context Protocol (MCP) tool integration.

## Four Pillars

1. **Cloud Providers** — Stream with Gemini, OpenAI, Grok, and Anthropic. All API credentials remain protected in the iOS Keychain.
2. **On-Device GGUF via llama.cpp** — Search Hugging Face directly within the app, view device-fit badges before downloading, and run models locally on your phone with zero network latency.
3. **Silent Auto-Configuration** — Automatic memory and hardware profiling on every model load. Balances context length, KV cache precision (`f16`/`q8_0`), thread allocation, and Metal GPU offloading within a safe 60% memory ceiling.
4. **Remote MCP Tool Calling** — Connect to remote Streamable HTTP MCP servers. Comprehensive 4-tier permission model (always allow, always deny, per-chat override, server default) with automatic heuristics requiring confirmation for destructive actions (`delete`, `exec`, `write`, `send`).

## Context Window & Memory Discipline

- **T1 Exact Token Accounting** — Exact local token counts via loaded vocabulary, conservative ceiling estimation for cloud streams.
- **T2 Window Budget** — Reserves output tokens upfront; requests never exceed model capacity.
- **T3 Non-Destructive Windowing** — System prompts and personas are retained verbatim. Older turns are pruned gracefully with in-transcript visual markers.
- **T4 Explicit Output Caps** — Enforces bounded token limits on every request.
- **T5 Streaming Only** — Persists assistant responses incrementally throttled to 500 ms or 256 characters to avoid memory spikes and data loss.
- **T6 64 KB Tool Result Cap** — Prevents unbounded tool results from exhausting model context windows.
- **T7 Tool Schema Budget** — Prioritizes and admits tool schemas within context bounds.
- **T8 Bounded Network Buffers** — Enforces 1 MB SSE frame limits and 8 MB response body ceilings.
- **T9 Memory Ceilings** — Refuses loads exceeding 60% available RAM and reclaims idle context memory.

## Sideload the IPA

Every push to `main` runs the GitHub Actions workflow to build an unsigned IPA and releases it on the rolling `ios-latest` release tag.

Direct download:
https://github.com/ddr-ai/RakuLLM/releases/download/ios-latest/RakuLLM.ipa

Download the IPA and install it using your preferred sideloading tool:
- [SideStore](https://sidestore.io/)
- [AltStore](https://altstore.io/)
- [Sideloadly](https://sideloadly.io/)
- [Feather](https://github.com/khcrysalis/Feather)

No paid Apple Developer account is required.

## Building Locally

Prerequisites: macOS with Xcode 16+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
# 1. Bootstrap pinned llama.cpp XCFramework
./scripts/bootstrap.sh

# 2. Generate procedural 1024px app icon
python3 scripts/make_icon.py

# 3. Generate Xcode project
xcodegen generate

# 4. Open project in Xcode
open RakuLLM.xcodeproj
```

Target: iOS 17.0+, arm64.
Bundle ID: `io.github.ddr-ai.rakullm`
