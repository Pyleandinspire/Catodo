[English](README.md) | [中文](README.zh-CN.md) | [日本語](README.ja.md) | **[Deutsch](README.de.md)**

---

# Catodo

Eine plattformübergreifende Aufgabenverwaltungs-App, entwickelt mit Flutter. Verwalten Sie Ihre Aufgaben mit intelligenten Ansichten, KI-gestützter Unterstützung und nahtloser geräteübergreifender Synchronisierung über WebDAV.

## Funktionen

- **Aufgabenverwaltung** - Aufgaben erstellen, bearbeiten, abschließen und löschen mit Prioritäten, Tags, Gruppen, Fälligkeitsdaten und mehreren Erinnerungen
- **Intelligente Ansichten** - Listenansicht, Tagesansicht (Heute fokussieren / Überfällige ausblenden) und Eisenhower-Matrix zur prioritätsbasierten Organisation
- **Wiederkehrende Aufgaben** - Tägliche, wöchentliche oder monatliche Wiederholungsregeln festlegen; nächste Instanz wird beim Abschließen automatisch generiert
- **WebDAV-Sync** - Inkrementelle geräteübergreifende Synchronisierung mit drei Konfliktlösungsmodi (Auto-Zusammenführung, Lokal zuerst, Remote zuerst) und Soft-Delete-Weitergabe
- **KI-Assistent** - Per natürlicher Sprache mit einem LLM-Agenten chatten, um Aufgaben zu erstellen, zu aktualisieren, zu zerlegen und zu verwalten
- **Daten-Import/Export** - `.ics`-Kalenderformat und `.catodo`-Vollbackup-Format (mit optionaler Einbindung sensibler Einstellungen)
- **Lokale Benachrichtigungen** - Geplante Erinnerungen, die App-Neustarts überdauern
- **Multi-Plattform** - Android, iOS, Windows, macOS, Linux und Web

## Installation

### Voraussetzungen

- [Flutter SDK](https://docs.flutter.dev/get-started/install) >= 3.12.0
- Dart SDK >= 3.12.0
- Für Android: Android SDK mit minSdkVersion 21+
- Für iOS: Xcode 15+, CocoaPods
- Für Desktop: Entsprechende Plattform-Build-Tools

### Aus dem Quellcode erstellen

```bash
# Repository klonen
git clone https://github.com/your-username/catodo.git
cd catodo

# Abhängigkeiten installieren
flutter pub get

# Isar-Schemas generieren
dart run build_runner build --delete-conflicting-outputs

# Auf verbundenem Gerät oder Emulator ausführen
flutter run
```

### Release-Build

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release

# Windows
flutter build windows --release

# macOS
flutter build macos --release

# Linux
flutter build linux --release

# Web
flutter build web --release
```

## Verwendung

### Aufgabenverwaltung

| Aktion | Vorgehensweise |
|--------|----------------|
| Aufgabe erstellen | Die **+**-Schaltfläche in der unteren Leiste antippen, Formular ausfüllen, **Speichern** antippen |
| Aufgabe bearbeiten | Eine Aufgabenkarte antippen, um den Editor zu öffnen |
| Aufgabe abschließen | Das kreisförmige Kontrollkästchen auf der Aufgabenkarte antippen |
| Aufgabe löschen | Aufgabeneditor öffnen, nach unten scrollen, **Aufgabe löschen** antippen, bestätigen |
| Priorität festlegen | Im Aufgabenformular Keine / Niedrig / Mittel / Hoch wählen |
| Erinnerung festlegen | Im Aufgabenformular **Erinnerung hinzufügen** antippen, Datum und Uhrzeit wählen |
| Wiederholung festlegen | Im Formular **Wiederkehrende Aufgabe** einschalten, Täglich/Wöchentlich/Monatlich und Intervall wählen |

### Ansichten

- **Listenansicht** (Standard) - Alle aktiven Aufgaben mit Gruppen- und Tag-Filtern
- **Tagesansicht** - Nach Fälligkeitsdatum gruppierte Aufgaben; umschaltbar zwischen Alle / Heute fokussieren / Überfällige ausblenden
- **Eisenhower-Matrix** - Vier-Quadranten-Ansicht basierend auf Dringlichkeit und Wichtigkeit (Priorität)

### WebDAV-Synchronisierung

1. Zu **Einstellungen > WebDAV-Sync** navigieren
2. WebDAV-Server-URL, Benutzername und Passwort eingeben
3. **Verbindung testen** antippen zur Überprüfung
4. **Konfiguration speichern** antippen
5. Sync-Modus wählen:
   - **Auto-Zusammenführung** (Standard) - Konflikte werden durch neuestes `updatedAt` gelöst
   - **Lokal zuerst** - Bei Konflikten wird die lokale Version bevorzugt
   - **Remote zuerst** - Bei Konflikten wird die Remote-Version bevorzugt
6. **Synchronisierung starten** antippen

### KI-Assistent

1. Zu **Einstellungen > KI-Assistent** navigieren und den LLM-Anbieter konfigurieren (OpenAI, DeepSeek, Doubao, GLM, Qwen, Kimi oder benutzerdefinierten Endpunkt)
2. API-Schlüssel und Modellnamen eingeben, dann **Konfiguration speichern** antippen
3. Zum **KI**-Tab in der unteren Navigation wechseln
4. Natürlich chatten - der KI-Agent kann Aufgaben erstellen, zerlegen, Tags hinzufügen, Prioritäten setzen und mehr
5. Risikarme Aktionen (Erstellen, Tag, Gruppe, Priorität) werden automatisch ausgeführt; risikoreiche Aktionen (Aktualisieren, Abschließen, Löschen) erfordern Bestätigung

### Daten-Import/Export

Zu **Einstellungen > Datenverwaltung** navigieren:

| Aktion | Format | Beschreibung |
|--------|--------|--------------|
| Importieren | `.ics` | Aufgaben aus Kalenderdateien importieren |
| Importieren | `.catodo` | Aus einem vollständigen Catodo-Backup wiederherstellen |
| Exportieren | `.ics` | Aktive Aufgaben als Kalenderdatei exportieren |
| Exportieren | `.catodo` | Alle Aufgaben und Einstellungen exportieren (optional einschließlich sensibler Daten) |

## Konfiguration

### KI-Anbieter-Einstellungen

Gespeichert in `SharedPreferences`:

| Schlüssel | Beschreibung |
|-----------|--------------|
| `ai_provider_id` | Anbieter-ID (`openai`, `deepseek`, `doubao`, `glm`, `qwen`, `moonshot`, `custom`) |
| `ai_api_url` | API-Endpunkt-URL |
| `ai_api_key` | API-Schlüssel |
| `ai_model` | Modellname |

### WebDAV-Einstellungen

Gespeichert in `SharedPreferences`:

| Schlüssel | Beschreibung |
|-----------|--------------|
| `webdav_url` | WebDAV-Server-URL |
| `webdav_username` | Benutzername |
| `webdav_password` | Passwort |
| `sync_mode` | Konfliktlösungsmodus (`autoMerge`, `localFirst`, `remoteFirst`) |

### Tagesansicht-Einstellungen

| Schlüssel | Beschreibung |
|-----------|--------------|
| `day_view_mode` | Ansichtsfilter (`all`, `focusToday`, `hideOverdue`) |

## Projektstruktur

```
lib/
├── main.dart                    # App-Einstieg, Navigation, Erinnerungsplanung
├── models/
│   ├── task.dart                # Task-Modell (Isar Collection)
│   └── filter.dart              # TaskFilter-Modell
├── data/
│   └── task_dao.dart            # Datenzugriffsobjekt
├── services/
│   ├── database_service.dart    # Isar-Singleton-Verwaltung
│   ├── webdav_service.dart      # WebDAV-Sync-Dienst
│   ├── ai_service.dart          # KI-API-Client
│   ├── ai_agent.dart            # KI-Agent-Aktionen und Ausführung
│   ├── nlp_service.dart         # Natürlichsprachverarbeitung
│   ├── ics_service.dart         # ICS-Datei-Parser und -Generator
│   ├── catodo_io_service.dart   # .catodo-Format Import/Export
│   ├── notification_service.dart # Benachrichtigungsdienst (bedingter Export)
│   ├── repeat_task_service.dart  # Wiederkehrende Aufgaben generieren
│   └── llm_provider_registry.dart # LLM-Anbieter-Definitionen
├── providers/
│   ├── isar_provider.dart       # Isar-Instanz-Provider
│   ├── task_providers.dart      # Aufgabenbezogene Provider
│   ├── webdav_provider.dart     # WebDAV-Konfiguration und Sync-Modus
│   └── day_view_provider.dart   # Tagesansichtsmodus
└── ui/
    ├── screens/                 # Seiten-Widgets
    └── components/              # Wiederverwendbare UI-Komponenten
```

## Entwicklung

### Tests ausführen

```bash
# Unit-Tests
flutter test

# Statische Analyse
flutter analyze

# Isar-Schemas nach Modelländerungen neu generieren
dart run build_runner build --delete-conflicting-outputs
```

### Architektur

Die App folgt einer Schichtenarchitektur:

```
UI-Schicht (Bildschirme, Komponenten)
    ↓
Zustandsverwaltungsschicht (Riverpod Provider)
    ↓
Dienstschicht (WebDAV, KI, Benachrichtigungen usw.)
    ↓
Datenschicht (TaskDao, Isar-Datenbank)
```

## Mitwirken

Beiträge sind willkommen! So können Sie helfen:

1. Repository **forken**
2. Feature-Branch **erstellen**: `git checkout -b feature/your-feature-name`
3. Änderungen mit klaren, beschreibenden Commit-Nachrichten **committen**
4. Änderungen **testen**: `flutter test` und `flutter analyze` ausführen
5. Zum Fork **pushen**: `git push origin feature/your-feature-name`
6. Pull Request gegen den `main`-Branch **eröffnen**

### Richtlinien

- Dem bestehenden Code-Stil und der Projektstruktur folgen
- Tests für neue Funktionen hinzufügen
- PRs auf ein einzelnes Anliegen fokussieren
- Öffentliche APIs und komplexe Logik dokumentieren
- Sicherstellen, dass `flutter analyze` ohne Warnungen durchläuft

## Lizenz

Dieses Projekt ist unter der GNU General Public License v3.0 lizenziert - siehe die [LICENSE](LICENSE)-Datei für Details.

## Kontakt

- **Projektbetreuer**: [Issue erstellen](https://github.com/your-username/catodo/issues)
- **Fehlerberichte**: [GitHub Issues](https://github.com/your-username/catodo/issues)
- **Funktionswünsche**: [GitHub Issues](https://github.com/your-username/catodo/issues)
