# PENSALO · Gut Check

Prototipo SwiftUI di una scelta rapida basata sull’istinto. **Il design attuale è una prima versione da rivedere**, non il redesign definitivo.

Il codice dell’app è contenuto in `GutCheck/GutCheck.swift`: schermata, motore del round e componenti. Non utilizza servizi esterni o dipendenze di terze parti. Le opzioni vengono salvate localmente sul dispositivo.

## Avvio in Xcode

1. Apri `GutCheck.xcodeproj` con Xcode 27.1 o successivo.
2. Seleziona lo schema `GutCheck` e un simulatore iPhone con iOS 27.
3. Premi Run. Il sorgente include anche una `#Preview`.

Il medesimo sorgente supporta macOS 26 o successivo. Per una prova locale dal Terminale:

```sh
xcrun swiftc -parse-as-library -target arm64-apple-macosx26.0 GutCheck/GutCheck.swift -o /tmp/GutCheck
/tmp/GutCheck
```

## Interazioni

- Tocca una bolla per salvarla.
- Trascinala lontano per scartarla.
- Tienila premuta per 0,7 secondi per sceglierla.
- Il pulsante con i cursori modifica opzioni, velocità e timer.

## Test del motore

`Tests/RoundEngineTests.swift` verifica salvataggi, pausa/ripresa, scadenze, spareggi, eliminazione, scelta diretta, modalità senza timer e validazione delle opzioni. I test non scrivono preferenze.

```sh
xcrun swiftc -D MODEL_TESTS -parse-as-library -target arm64-apple-macosx26.0 GutCheck/GutCheck.swift Tests/RoundEngineTests.swift -o /tmp/GutCheckTests
/tmp/GutCheckTests
```

## File versionati

Il repository contiene sorgenti, progetto Xcode, schema condiviso, test e questo README. Build locali, applicazioni compilate, anteprime, cache, impostazioni personali di Xcode e file di ambiente sono esclusi da Git.
