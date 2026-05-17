<div align="center">

# 🏏 Pocket Score — Box Cricket Scoring, Reimagined

[![Flutter](https://img.shields.io/badge/Flutter-3.11.1+-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=flat-square&logo=dart&logoColor=white)](https://dart.dev)
[![HydratedBloc](https://img.shields.io/badge/HydratedBloc-State%20Mgmt-8B5CF6?style=flat-square)](https://pub.dev/packages/hydrated_bloc)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](./LICENSE)

*Every ball matters. Every run counts.*

</div>

---

## 📖 What is Pocket Score?

Pocket Score is a sophisticated, high-performance cricket scoring app built specifically for the box cricket ecosystem. It adopts a premium **"Midnight Studio"** design philosophy — blending professional-grade analytics with a cinematic dark-mode interface.

From squad building to the final result screen, every interaction is designed to feel premium and fluid.

---

## ✨ Key Features

| Feature | Description |
|---|---|
| 🏆 **Midnight Studio UI** | Dark-mode design with Outfit font and fluid micro-animations |
| ⚡ **Pro Scoring Engine** | Ball-by-ball tracking with 4s, 6s, wides, no-balls, free hits & all wicket types |
| 🎉 **Live Event Animations** | Full-screen FOUR!, SIX!, and OUT! celebration overlays with confetti |
| 🔄 **Auto-Persistence** | Powered by `HydratedBloc` — progress is never lost |
| 📊 **Career Analytics** | Track strike rates, averages, and economy rates across all matches |
| 📋 **Match History** | Revisit every game with high-fidelity scorecards |
| 🎯 **Smart Match Flow** | Squad → Team Selection → Lineup Preview → Toss → Openers → Score |

---

## 🛠 Tech Stack

```
Framework       →   Flutter 3.11.1+
State Mgmt      →   flutter_bloc + hydrated_bloc (auto-persistence)
Local Storage   →   path_provider
Typography      →   Google Fonts — Outfit
Models          →   Equatable
```

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK `^3.11.1`
- Dart SDK `3.x`
- Android Studio or VS Code with Flutter & Dart extensions

### 1. Clone the repository

```bash
git clone https://github.com/your-username/pocket_score.git
cd pocket_score
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Run the app

```bash
flutter run
```

---

## 📱 App Gallery

> Follow the complete match journey — from squad management to the final scoreboard.

---

### 🏠 Stage 1 — Home & Squad Management

*Your command center. View the latest result, browse match history, and manage your squad roster.*

| Home Screen & Match History | Manage Squad |
| :---: | :---: |
| ![Home Screen](assets/app_images/image_1.png) | ![Manage Squad](assets/app_images/image_2.png) |

---

### ⚙️ Stage 2 — Match Setup & Team Selection

*Configure your match, assign players to teams, designate captains, and preview the final lineups before kickoff.*

| Match Setup | Select Teams | Lineup Preview |
| :---: | :---: | :---: |
| ![Match Setup](assets/app_images/image_3.png) | ![Select Teams](assets/app_images/image_4.png) | ![Lineup Preview](assets/app_images/image_5.png) |

---

### 🪙 Stage 3 — Toss & Opening Selection

*The classic pre-match ritual. Toss the coin, choose to bat or bowl, and pick your opening striker, non-striker, and first bowler.*

| Coin Toss | Select Openers |
| :---: | :---: |
| ![Coin Toss](assets/app_images/image_6.png) | ![Select Openers](assets/app_images/image_7.png) |

---

### 🎮 Stage 4 — Live Scoring Engine

*The heart of Pocket Score. Real-time ball-by-ball scoring with animated event overlays for every boundary, six, and wicket.*

| FOUR! 🟦 | SIX! 🟩 | OUT! 🟥 |
| :---: | :---: | :---: |
| ![Four Animation](assets/app_images/image_8.png) | ![Six Animation](assets/app_images/image_9.png) | ![Out Animation](assets/app_images/image_10.png) |

---

### 🎯 Stage 5 — Advanced In-Game Events

*Handle every cricket scenario with precision — wicket type selection, free hit & no-ball tracking, bowler rotation, and player retirement.*

| Wicket Type | Free Hit / No-Ball | Next Bowler | Retire Player |
| :---: | :---: | :---: | :---: |
| ![Wicket Type](assets/app_images/image_11.png) | ![Free Hit](assets/app_images/image_12.png) | ![Next Bowler](assets/app_images/image_13.png) | ![Retire Player](assets/app_images/image_14.png) |

---

### 🏆 Stage 6 — Results & Rankings

*Match concluded — view the winner announcement with full scorecard access, then check the career-wide player rankings leaderboard.*

| Match Result | Player Rankings |
| :---: | :---: |
| ![Match Result](assets/app_images/image_15.png) | ![Player Rankings](assets/app_images/image_16.png) |

---

## ⚡ Available Commands

```bash
flutter run                   # Run on connected device
flutter run --release         # Release build on device
flutter build apk             # Android APK
flutter build ipa             # iOS archive
flutter pub get               # Install dependencies
flutter analyze               # Static analysis
flutter test                  # Run tests
```

---

## 🗺 Roadmap

- [ ] Online multiplayer scoring (real-time sync)
- [ ] Tournament bracket management
- [ ] Custom scoring rules per match
- [ ] Share scorecards as image/PDF
- [ ] Player profile pages with career graphs
- [ ] Dark / light theme toggle

---

## 📝 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

<div align="center">

Built by [Javiya Raj](https://github.com/JAVIYARAJ) — Flutter developer, product builder.

*"Every ball matters. Every run counts."*

</div>
