# Interface Contracts: iOS On-Device Hoibe

**Feature**: 002-ios-on-device  
**Date**: 2026-05-03

## Overview

These contracts define the public interfaces between Swift modules. All protocols are `@MainActor`-isolated where they interact with UI, and use structured concurrency (`async throws`) for inference operations.

## Module Dependency Graph

```
ContentView
    └── SipDetector (protocol: SipDetecting)
            ├── ModelManager (protocol: ModelManaging)
            ├── FrameExtractor (protocol: FrameExtracting)
            └── PromptEngine (protocol: PromptBuilding)
```
