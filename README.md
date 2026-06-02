# 🚀 DevPilot Edge — Unified AI Operating Layer for Mobile & Edge Devices

DevPilot Edge is a premium, edge-first mobile AI operational companion built with Flutter and Riverpod. It integrates cloud models (OpenAI, Gemini, Anthropic, Mistral, DeepSeek, Groq, Together, Moonshot) with local, offline GGUF model execution directly on-device via Vulkan GPU acceleration.

---

## 🎨 Design Theme & Core Concept
Inspired by next-generation AI platforms like **Google Gemini**, **Codex**, and **Antigravity**, DevPilot Edge features:
*   **Vibrant Glassmorphic Aesthetics**: Modern dark mode with HSL-tailored color gradients (Vibrant Purple, Clean Teal, Neon Pink) and translucent container backdrops.
*   **Bubble-Free Conversational Layout**: Sleek, bubble-free typographical alignment for assistant replies with left-aligned glowing avatar halos.
*   **Micro-Animations**: Fluid transitions, slide-ins, and animated color-wave loader bars using `flutter_animate`.
*   **Multimodal Offline Integration**: Attached image grids, speech dictation (STT), and voice playback (TTS) natively bound to offline operational capabilities.

---

## 📂 Codebase Architecture & Feature Map

The project implements a **feature-first** directory structure. Legacy, redundant root stubs have been cleaned up to maintain high code quality and strict type safety:

```
lib/
├── core/
│   ├── router/
│   │   └── app_router.dart          # Shell layout routing with GoRouter
│   └── theme/
│       └── app_theme.dart           # Dark/Light theme design specifications
├── features/
│   ├── agent/
│   │   └── agent_screen.dart        # ReAct agent loop visualizer with thinking steps
│   ├── chat/
│   │   └── chat_screen.dart         # Multimodal Chat UI, Image Picker, Dictation
│   ├── memory/
│   │   └── memory_screen.dart       # Episodic & long-term memory explorer
│   ├── model_hub/
│   │   ├── model_hub_screen.dart    # GGUF Downloads and System Hardware Diagnostics
│   │   └── model_test_lab.dart      # Interactive text, voice, image, & embeddings lab
│   ├── research/
│   │   └── research_screen.dart     # AI deep research engine logs
│   ├── settings/
│   │   └── settings_screen.dart     # API Keys & active model configuration panel
│   ├── study/
│   │   └── study_screen.dart        # Flashcards, SM-2 Spaced Repetition, Quizzes, Pomodoro
│   └── voice/
│       └── voice_screen.dart        # Configurable voice assistant studio
├── ffi/                             # Native interface stubs (llama, whisper, TTS)
├── models/                          # Data models (ChatMessage, StudyModels, etc.)
├── providers/
│   └── service_providers.dart       # Riverpod services dependency providers
└── services/                        # Core subfolder service implementations
    ├── agent/                       # ReAct agent loop, thinking engine, & tools
    ├── ai/                          # Cloud HTTP clients & Hugging Face download manager
    ├── local/                       # Llama.cpp Android Vulkan bindings
    ├── memory/                      # SQLite-based episodic memory retriever
    ├── research/                    # Web-search based research report synthesizer
    ├── storage/                     # SQLite AppDatabase & SharedPreferences service
    ├── study/                       # SM-2 Spaced Repetition scheduler
    └── voice/                       # Text-to-Speech & Speech-to-Text pipeline
```

---

## ✨ Key Feature Modules

### 1. 💬 Chat Hub (Multimodal AI Chat)
*   **Dual Engine routing**: Instantly toggle between cloud APIs and local loaded GGUF models.
*   **Multimodal Attachment Bar**: Select images via FilePicker, rendering them as interactive preview thumbnails before sending.
*   **Inline Dictation**: Use the voice button to record and type messages hands-free.
*   **Color-Wave Loader**: Animated linear gradient reasoning bar representing thinking waves.
*   **Inline Actions**: Instantly copy responses or read them aloud via Text-to-Speech.

### 2. 📚 Study Mode
*   **Flashcards & Spaced Repetition**: Utilizes the SuperMemo SM-2 algorithm to estimate optimal reviews and spacing intervals (Again/Hard/Good/Easy).
*   **Interactive Quizzes**: Generate multiple-choice or true/false quizzes using active AI models.
*   **Pomodoro Focus Timer**: Customizable work sessions and breaks with animated countdowns.
*   **AI Study Co-Pilot**: Summarize text, generate day-by-day study schedules, create mnemonics, or explain complex concepts.

### 3. 🧠 ReAct Agent Orchestrator
*   Executes complex goals using a **Reasoning + Acting** loop.
*   **Built-in Tools**: Web Search (DuckDuckGo, Brave, Tavily), URL Reader (markdown extraction), Calculator, DateTime.
*   **Thinking Visualizer**: Lists collapsible CoT reasoning steps, parameters, and results.

### 4. 🎤 Voice Studio
*   Advanced voice configuration console.
*   Configure speech pitch, rate, language locale, and select from device-available TTS voice profiles.

### 5. 📊 Model Test Lab
*   **LLM Test Panel**: Chat prompt field, streaming token speed parameters, and temperature controls.
*   **Voice Test Panel**: TTS playback console and microphone speech transcript feedback.
*   **Image Creator Panel**: Configure sampler, resolution, and generation steps to draw SD designs (uses HF API or draws procedural vectors when offline).
*   **Embeddings Lab**: Computes semantic cosine similarity score side-by-side using local vector embeddings.

### 6. ⚙️ Settings & System Diagnostics
*   Estimates available RAM, CPU threads, platform architecture, and local folder storage metrics.
*   **Custom Downloader**: Paste any Hugging Face URL resolver (e.g. `https://huggingface.co/{repo}/resolve/{branch}/{filename}`) to pull GGUFs.
*   Safe Keychain/Keystore API key storage for multiple providers.

---

## 🛠️ Setup & Local Execution

### Prerequisites
*   Flutter SDK: `>=3.3.0 <4.0.0`
*   Android Studio / Android SDK (for Android compilation)

### Getting Started

1.  Clone the repository and pull dependencies:
    ```bash
    flutter pub get
    ```

2.  Run the static analysis to verify compilation:
    ```bash
    flutter analyze
    ```

3.  Run the application on an Android device/emulator:
    ```bash
    flutter run
    ```

---

## 📊 Core Local Model Catalog (GGUF)

The Model Hub features public Hugging Face download parameters for 26+ curated edge models:

| Category | Model Name | HF Repository Path | Size (MB) | Min RAM |
|---|---|---|---|---|
| **Chat/Reasoning** | Gemma 4 1B/4B/12B | `bartowski/google_gemma-4-1b-it-GGUF` | ~770M-7.5G | 1.5G - 10G |
| | Qwen 3 0.6B/1.7B/4B/8B | `unsloth/Qwen3-1.7B-GGUF` | ~430M-5.2G | 768M - 8G |
| | DeepSeek R1 7B/14B Distilled | `bartowski/DeepSeek-R1-Distill-Qwen-7B-GGUF` | ~4.7G - 8.9G | 6G - 10G |
| | Phi-4 & Phi-4 Mini | `bartowski/Phi-4-mini-instruct-GGUF` | ~2.4G - 8.7G | 3G - 10G |
| **Uncensored** | Dolphin 3.0 Llama 3.1 8B 🔓 | `bartowski/dolphin-3.0-llama3.1-8b-GGUF` | ~4.9G | 6G |
| | WizardLM-2 7B 🔓 | `bartowski/WizardLM-2-7B-GGUF` | ~4.4G | 6G |
| **Vision** | MiniCPM-V 2.6 | `openbmb/MiniCPM-V-2_6-gguf` | ~5.2G | 6G |
| | Moondream 2 | `vikhyatk/moondream2` | ~3.4G | 4G |
| **Voice (Speech)**| Whisper Tiny / Base / Small | `ggerganov/whisper.cpp` | ~75M - 466M | 512M - 1G |
| **Image Gen** | FLUX.1 Schnell | `city96/FLUX.1-schnell-gguf` | ~6.7G | 10G |
| | Stable Diffusion 1.5 | `second-state/stable-diffusion-v1-5-GGUF` | ~2.0G | 4G |
| **Embeddings** | Nomic Embed v1.5 | `nomic-ai/nomic-embed-text-v1.5-GGUF` | ~84M | 512M |

---

## ⚡ Main Third-Party Dependencies

*   [flutter_riverpod](https://pub.dev/packages/flutter_riverpod) — Declares state management providers.
*   [go_router](https://pub.dev/packages/go_router) — Declarative URL-based routing.
*   [sqlite3](https://pub.dev/packages/sqlite3) / [sqlite3_flutter_libs](https://pub.dev/packages/sqlite3_flutter_libs) — Local database operations.
*   [llama_flutter_android](https://pub.dev/packages/llama_flutter_android) — Mobile-optimized lllama.cpp Vulkan runner.
*   [flutter_animate](https://pub.dev/packages/flutter_animate) — Streamlined widget transitions.
*   [file_picker](https://pub.dev/packages/file_picker) — Image selection.
*   [flutter_tts](https://pub.dev/packages/flutter_tts) / [speech_to_text](https://pub.dev/packages/speech_to_text) — Speech pipeline controls.
*   [shared_preferences](https://pub.dev/packages/shared_preferences) — Rapid settings persistence.
*   [flutter_markdown](https://pub.dev/packages/flutter_markdown) — High-quality streaming text styling.
