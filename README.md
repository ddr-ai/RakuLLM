# RakuLLM

A high-performance iOS LLM chat client combining cloud intelligence, on-device GGUF inference, Hugging Face discovery, and remote Model Context Protocol (MCP) tool integration.

## Key Features

1. **On-Device GGUF Inference (Zero API Keys Required)** — Download GGUF models directly from Hugging Face. The app detects downloaded models and lets you select them right in the chat interface. Run 100% locally and privately on-device with llama.cpp.
2. **Optional Cloud Providers** — Commercial LLMs (Gemini, OpenAI, Grok, Anthropic) are completely optional. API keys are saved securely in the iOS Keychain only when commercial models are selected.
3. **Public Tool & Services Catalog (Grid Layer)** — Browse hundreds of free tools and services across 8 categories with a 1-tap "Connect" button into the MCP runtime, plus a manual authentication sheet for custom Bearer tokens and endpoints.
4. **Live Web Search & Production Code Toggles** — Beside the chat input, toggle real-time live web search (DuckDuckGo / Wikipedia) and activate the Production Code directive for clean, highly accurate, real-world production code.
5. **Rich Code Formatting** — Formatted output for Swift, Python, TypeScript, Rust, Go, C++, SQL, Bash, JSON, etc. with syntax language badges, line counts, and 1-tap "Copy Code" buttons.
6. **Chat Management & Memory Rollover** — Rename chats, delete chats with cascade cleanup, and enjoy automatic chat rollover with distilled memory carryover whenever the token limit is approached.
7. **Swipe-to-Dismiss Keyboard** — Swipe down anywhere on the screen to immediately dismiss the keyboard, tap to chat to bring it right back.

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
