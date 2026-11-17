# Correzione dettatura e camminata

I report `WhyNot-2026-11-16-114252.ips` e `WhyNot-2026-11-16-114302.ips` mostravano un `SIGTRAP` in `_dispatch_assert_queue_fail`, nel callback di autorizzazione di `SpeechInput.start()`. Il callback legacy di Speech ereditava l’isolamento MainActor e veniva chiamato su una coda di sistema.

- Callback di autorizzazione esplicitamente `@Sendable`, in una funzione `nonisolated`.
- Callback di riconoscimento e contapassi esplicitamente `@Sendable`, con aggiornamenti dello stato tramite MainActor e controllo della generazione per ignorare risposte tardive.
- Audio engine isolato in un actor. Attivazione e disattivazione usano le API asincrone iOS 27; i comandi attendono il completamento dell’operazione precedente.
- Uscire dalla schermata senza aver avviato la dettatura non attiva né disattiva l’audio.
- In background la dettatura si arresta; il contapassi conserva l’istante iniziale quando riprende. Il simulatore non crea un contapassi hardware.
- Stato di registrazione con bordo arancione e microfono rosso, senza scritta Listening né pallino. Le barre ricevono le misure RMS dal vero flusso audio, scorrono e restano ritagliate in una zona separata dal pulsante; anche l’alone del pulsante rimane dentro il campo. Durante l’attivazione viene mostrato Starting microphone e i doppi avvii sono disabilitati.

Verifiche: build iPhone Simulator e iPhone reale riuscite; controlli di navigazione e persistenza superati; ripetuto avvio della dettatura oltre il punto del vecchio crash e ingresso nella camminata. Il microfono è stato autorizzato per la prova, ma il simulatore ha restituito un formato d’ingresso non valido: questo caso ora mostra un errore e lascia l’app utilizzabile. La trascrizione reale e il conteggio su sensore restano da verificare su iPhone. `listening-preview.png` è una resa del componente SwiftUI, non una registrazione reale.

I messaggi PointerUI e CoreAnimation riportati in console sono separati dal crash con stack trace identificato; non sono stati soppressi.

La successiva correzione grafica ripristina il campo da 120 pt e il centro del microfono a 34 pt dal bordo destro e inferiore, come nel design iniziale. La forma d’onda è nuovamente compatta (122 × 34 pt), con barre da 4 pt, passo uniforme da 9 pt, estremità arrotondate e nessuna traccia a puntini. Una sola fase governa lo scorrimento di tutte le barre; i silenzi mantengono piccole barre verticali anziché punti. La sensibilità di visualizzazione è adattata alla voce normale sul microfono del telefono. Le misure RMS e la risposta a volumi diversi sono state nuovamente verificate con PCM di prova.
