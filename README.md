# TRUEQUEAPP

TRUEQUEAPP is a mobile application built with Flutter, designed for trading and exchanging items between users.

## Project Structure

This project follows the principles of Clean Architecture, organized by features to ensure a scalable and maintainable codebase.

```
lib/
|
|-- core/
|   |-- di/                       # Dependency Injection setup (GetIt)
|   |-- router/                   # App navigation logic (GoRouter)
|
|-- features/
|   |-- auth/
|   |   |-- data/                 # Data sources (remote/local) and repository implementations
|   |   |-- domain/               # Core business logic (entities, repositories, use cases)
|   |   |-- presentation/         # UI (pages, widgets) and state management (Riverpod Notifiers)
|
|-- main.dart                     # Main entry point of the application
|
|-- firebase_options.dart         # Firebase configuration
```

### Core
The `core` directory contains shared code used across multiple features, such as dependency injection, navigation, and base classes.

### Features
Each feature is a self-contained module representing a specific functionality of the app (e.g., `auth`, `items`, `profile`). This modular approach makes it easier to develop and test features in isolation.

Each feature folder is divided into three layers:
-   **Data**: Implements the repository contracts defined in the domain layer. It fetches data from sources like Firebase and exposes it to the rest of the app.
-   **Domain**: Contains the core business logic. This includes entities (the business objects), repository contracts (interfaces), and use cases (the application-specific business rules).
-   **Presentation**: Handles the UI and user interaction. It uses Riverpod for state management to react to state changes and display the appropriate UI to the user.

## Tech Stack

-   **Framework**: Flutter
-   **State Management**: Riverpod
-   **Backend & Authentication**: Firebase
-   **Navigation**: GoRouter
-   **Dependency Injection**: GetIt
-   **Architecture**: Clean Architecture (Feature-driven)
