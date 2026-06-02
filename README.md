# 🚀 DevPilot — Unified AI Assistant for Android

> *The most powerful AI assistant on your device — cloud-connected, locally-run, always private.*

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-blue?logo=dart)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![Build](https://img.shields.io/badge/APK-64.8MB-brightgreen)](build/app/outputs/flutter-apk/app-release.apk)

---

## 🌟 What Is DevPilot?

**DevPilot** is a next-generation, open-source AI assistant built as a native Android app using Flutter. It unifies **cloud AI** and **on-device local models** in a single premium experience — giving you the power of GPT-5.5 or Claude Opus when online, and the full privacy of locally-run GGUF models (Llama 4, Qwen 2.5, Phi-4, Gemma 4, Mistral...) when offline.

**No vendor lock-in. No subscription required. No data leaves your device unless you choose it to.**

---

## ✨ Core Features

| Feature | Description |
|---|---|
| 💬 **AI Chat** | Streaming chat with 10+ providers — OpenAI, Anthropic, Gemini, Mistral, DeepSeek, Groq, Together, Kimi, OpenRouter, Ollama |
| 🧠 **Local Models** | 60+ GGUF models run 100% on-device via llama.cpp + Vulkan GPU |
| 📥 **Model Hub** | Browse, download, and manage models from Hugging Face or any direct URL — no API key required |
| 🤖 **Autonomous Agent** | ReAct loop agent with 11 built-in tools (web search, calculator, notes, URL reader, and more) |
| 🔍 **Research Engine** | Multi-source web research with AI synthesis into structured reports |
| 🧪 **Model Test Lab** | Chat, Voice Studio, Image Generation, and Embeddings Lab per model |
| 📚 **Study Mode** | AI-generated flashcards, spaced repetition (SM-2), quiz, and Pomodoro timer |
| 🎙️ **Voice Assistant** | Full STT → LLM → TTS pipeline with animated waveform UI |
| 🧠 **Memory System** | Episodic, semantic, profile, and note memories with keyword search |
| ⚙️ **Workflow Builder** | Visual DAG-based automation pipeline with reusable workflows |
| 🔐 **Secure Storage** | All API keys encrypted in Android Keystore via FlutterSecureStorage |

---

## 🎨 Design

Inspired by next-generation AI platforms like **Google Gemini**, **OpenAI Codex**, and **Antigravity IDE**:

- **Glassmorphic dark mode** with HSL-tuned gradients (vibrant purple, clean teal, neon pink)
- **Bubble-free typographic chat layout** with glowing avatar halos
- **Micro-animations** using `flutter_animate` throughout every screen
- **Responsive** — adapts from small phones to large tablets

---

## 🤖 Supported Cloud Providers

| Provider | Example Models |
|---|---|
| **OpenAI** | GPT-5.5, GPT-5.4 Mini, GPT-4.1 (1M context), GPT Image 2 |
| **Anthropic** | Claude Opus 4.8, Claude Sonnet 4.6, Claude Haiku 4.3 |
| **Google** | Gemini 2.5 Pro, Gemini 2.5 Flash, Gemini 2.0 Flash |
| **Mistral** | Mistral Medium 3, Codestral |
| **DeepSeek** | DeepSeek-V3, DeepSeek-R1 (full reasoning) |
| **Groq** | Llama-3.3-70B, Mixtral (ultra-fast inference) |
| **Together AI** | Llama 4 Scout/Maverick, Qwen3, DeepSeek-R1 |
| **Kimi** | Kimi K2 Instruct |
| **OpenRouter** | 200+ models via a single API |
| **Ollama** | Any model on your local Ollama server |

---

## 🧠 Local Model Categories

All models download as GGUF files and run fully offline with Vulkan GPU acceleration.

- **Tiny (< 1GB)**: Qwen 2.5 0.5B, Whisper Tiny — fits any phone
- **Small (1–4GB)**: Phi-4 Mini, Qwen 2.5 3B, Kokoro TTS
- **Medium (4–8GB)**: Mistral 7B, Gemma 4 4B, Llama 3.2 3B
- **Large (8GB+)**: Phi-4 14B, Gemma 4 12B, Llama 4 Scout, FLUX.1
- **Coding**: Qwen 2.5 Coder series (1.5B → 32B), DeepSeek Coder V2
- **Reasoning**: DeepSeek-R1 Distill, Qwen3 Thinking, Phi-4
- **Vision**: Gemma 4, Llama 4 Scout, Qwen 2.5 VL
- **Voice**: Whisper (tiny/base/small), Supertonic-3 TTS, XTTS-v2, Kokoro
- **Images**: FLUX.1 Schnell, SDXL Turbo, Stable Diffusion 3.5
- **Embeddings**: Nomic Embed, MiniLM-L6, mxbai-embed-large

---

## 🤖 Agent Tools

The built-in ReAct agent has 11 tools, all working without a subscription:

| Tool | Key |
|---|---|
| `web_search` | Free DuckDuckGo search — no key required |
| `brave_search` | Brave Search API (optional key in Settings) |
| `tavily_search` | Tavily research search (optional key in Settings) |
| `read_url` | Fetch and parse any webpage |
| `web_scraper` | Deep content extraction |
| `calculator` | Full math expression evaluator |
| `unit_converter` | 100+ unit conversions |
| `datetime` | Timezone-aware date/time |
| `text_processor` | Summarize, translate, transform |
| `create_note` | Save notes to local SQLite |
| `search_knowledge` | Search saved notes + past conversations |

---

## 🏗️ Architecture

```
lib/
├── features/         ← UI screens (feature-first, no business logic)
├── services/         ← Business logic services (zero UI dependency)
│   ├── ai/           ← AiClient: unified streaming for 10+ providers
│   ├── agent/        ← AgentOrchestrator: ReAct loop + tool execution
│   ├── local/        ← LocalLlmService: on-device GGUF inference
│   ├── memory/       ← MemoryService: keyword similarity search
│   ├── research/     ← ResearchEngine: multi-source web synthesis
│   ├── storage/      ← AppDatabase (SQLite) + StorageService (secure keys)
│   ├── study/        ← StudyAssistant + SpacedRepetition (SM-2)
│   ├── voice/        ← VoicePipeline: STT + TTS
│   └── workflow/     ← WorkflowExecutor: DAG automation
├── ffi/              ← Native C bindings (llama.cpp, whisper.cpp, TTS)
├── models/           ← Pure Dart data models (typed, no nulls)
└── providers/        ← Riverpod global providers
```

**Tech Stack**: Flutter · Dart · Riverpod · GoRouter · SQLite · FlutterSecureStorage · Dio · dart:ffi · llama_flutter_android · flutter_animate

---

## 🔐 Privacy

- **API keys**: Encrypted in Android Keystore — never stored in plain text
- **Chat history**: Local SQLite only — never synced anywhere
- **Local models**: 100% on-device inference — no tokens leave your phone
- **Downloads**: Direct HTTPS from Hugging Face CDN — no proxy server

---

## 🚀 Getting Started

### Prerequisites
- Flutter 3.x SDK
- Android SDK 21+
- Android device or emulator (API 24+ recommended)

### Run
```bash
git clone https://github.com/itsmesujan/DevPilot.git
cd DevPilot
flutter pub get
flutter run
```

### Build APK
```bash
flutter build apk
# Output: build/app/outputs/flutter-apk/app-release.apk (64.8 MB)
```

### Configure API Keys
Open the app → **Settings** → **API Keys** → Enter your key for any provider.

Free options that work without any key:
- **Local GGUF models** (download from Model Hub)
- **DuckDuckGo web search** (built-in agent tool)
- **Ollama** (if running locally)

---

## 🗺️ Roadmap

- [ ] **RAG** — Attach PDFs, docs, and code repos as context
- [ ] **sqlite-vec** — Real vector embeddings replacing keyword search
- [ ] **iOS support** — Core ML / Metal inference path
- [ ] **Desktop** — Windows/macOS system tray assistant
- [ ] **Code sandbox** — Execute Python/JS in a secure container
- [ ] **Plugin system** — Third-party tool integrations
- [ ] **Workflow sharing** — Export/import automation pipelines

---

## 📊 Build Status

| Check | Result |
|---|---|
| `flutter analyze` | ✅ No issues |
| Production APK | ✅ 64.8 MB |
| TODOs remaining | ✅ Zero |
| GitHub | ✅ Pushed to `main` |

---

## 🤝 Contributing

PRs welcome! The codebase is clean and well-structured:

- Add a **cloud provider**: extend `AiClient.streamChat()`
- Add an **agent tool**: register a `ToolDefinition` in `BuiltinTools`
- Add a **local model**: add a `ModelProfile` to `ModelCatalog.localModels`

---

## 📄 License

MIT License — see [LICENSE](LICENSE)

---

*DevPilot — Built with ❤️ for the next generation of AI-powered developers.*
