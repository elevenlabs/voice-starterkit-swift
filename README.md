<img src="./.github/assets/app-icon.png" alt="Voice Agent App Icon" width="100" height="100">

# ElevenLabs Swift Voice Starter Kit

This is a starter template for [ElevenLabs Conversational AI Agents](https://elevenlabs.io/docs/conversational-ai/overview) that provides a simple voice interface using the [ElevenLabs Swift SDK](https://github.com/elevenlabs/elevenlabs-swift-sdk).

This template is compatible with iOS, iPadOS, macOS, and visionOS and is free for you to use or modify as you see fit.

## Getting started

First, create a new public [Conversational AI agent](https://elevenlabs.io/app/conversational-ai).

Replace `publicAgentId` in `AppViewModel.swift` with your public agent id.

Note: Be sure to enable the user transcript and agent response client events.

Built and run the app from Xcode by opening `VoiceStarterKit.xcodeproj`. You may need to adjust your app signing settings to run the app on your device.

## Token generation

In a production environment, you will be responsible for developing a solution to generate WebRTC tokens for your users, which is integrated with your authentication solution. Your should use non-public voice agents in production.

## Contributing

This template is open source and we welcome contributions! Please open a PR or issue through GitHub, and don't forget to join us in the [ElevenLabs Community Slack](https://discord.com/invite/elevenlabs).
