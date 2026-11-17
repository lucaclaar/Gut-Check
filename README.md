# Gut Check · Reflect

App SwiftUI da aprire con `WhyNot.xcodeproj`. Richiede Xcode 27.1 e iOS 27.

Il percorso implementato comprende benvenuto, scelta modalità, domanda modificabile, selezione Mixed / Best case / Worst case, sei carte con swipe e pulsanti Yes/No, pausa, camminata, ritorno, decisione, cursore delle emozioni, riepilogo delle risposte e salvataggio locale.

Unbounded è incluso con la licenza OFL. Mascotte e sfondi provengono dal Figma originale; le risorse sono locali e non dipendono dagli URL temporanei di Figma. I controlli di sistema usano SwiftUI e Liquid Glass.

La domanda iniziale contiene il testo dimostrativo del Figma e può essere sostituita. Le decisioni sono salvate nel contenitore dell’app in `Documents/decisions.json`, con scrittura atomica e protezione del file. Non è configurato un servizio remoto.

## Avvio

1. Aprire `WhyNot.xcodeproj`.
2. Selezionare lo schema **WhyNot** e il simulatore **WhyNot · Figma QA**, oppure un iPhone con iOS 27.
3. Eseguire con **⌘R**. Dalla schermata delle modalità, scegliere **Reflect**.

## Verifica

- Build Debug per iPhone 17 Simulator riuscita.
- Percorso verificato nel simulatore fino al salvataggio, incluso swipe, ritorno alla carta corrente, sei risposte, riepilogo e uscita anticipata dalla camminata.
- Controlli del modello superati: input vuoti, ordine delle prospettive, protezione di 300 ms dopo una risposta, conservazione delle risposte, pausa dopo sei carte, ritorno dalla camminata, tre stati emotivi, salvataggio e ricaricamento.
- Catalogo immagini verificato: 40 risorse locali, nessun file mancante o vuoto.

I controlli del modello si possono ripetere su macOS con `zsh Checks/run.sh` dalla cartella del progetto.

La forma d’onda legge l’ampiezza RMS dei campioni PCM del microfono, pubblica circa 20 misure al secondo e fa scorrere le barre verso sinistra. Lo storico è limitato a 80 campioni. Con Riduci movimento attivo le barre aggiornano l’altezza senza scorrere. `zsh Checks/run-audio.sh` verifica silenzio, volumi diversi, RMS noto, stereo, frequenza degli aggiornamenti e pulizia dello storico, senza richiedere il microfono.

Il simulatore non fornisce il conteggio reale dei passi. Conteggio, dettatura e feedback aptico devono essere verificati su un iPhone. Il permesso Movimento e fitness è stato rifiutato durante la verifica nel simulatore; per provare i sensori lì va ripristinato nelle impostazioni del simulatore. Il codice gestisce anche l’assenza o il rifiuto del permesso.

Turbo e l’app Apple Watch restano da sviluppare. Il foglio delle risposte è una vista nativa SwiftUI; i dettagli di quel frame e degli stati non acquisiti potranno essere confrontati al ripristino delle letture Figma.

## Aiuto e contatti · prima implementazione

Reflect controlla localmente la domanda scritta o dettata dopo una pausa di 700 ms e nuovamente prima di avviare le carte. Alcune espressioni in italiano e inglese relative ad autolesionismo, violenza o possibili emergenze mediche aprono un foglio dal basso, fermano il microfono e impediscono l’avvio delle carte con quella domanda. Il pulsante con il cuore apre lo stesso foglio in qualsiasi momento dalla schermata iniziale di Reflect. Chiudere il foglio consente di modificare il testo; non aggira il controllo all’avvio delle carte.

È un controllo preliminare a regole: può perdere segnali o produrre falsi positivi, non valuta clinicamente il rischio e non interpreta tutte le lingue o tutti i contesti. Foundation Models **non è ancora collegato**. La futura analisi del modello dovrà affiancare questo controllo prima della generazione delle carte; i numeri devono provenire esclusivamente dal catalogo, mai dal testo generato.

Il paese iniziale usa `Locale.autoupdatingCurrent.region`, senza permessi di localizzazione. Non identifica la posizione fisica né rileva automaticamente un viaggio. Il selettore consente di scegliere e ricordare manualmente un paese oppure di tornare alle impostazioni del dispositivo. Paese assente o non coperto: nessun numero di un altro paese viene proposto come ripiego.

`WhyNot/Resources/SafetyContacts.json` è il catalogo offline versionato, verificato il 16 novembre 2026. Include contatti di emergenza nei 27 paesi UE, Regno Unito, Stati Uniti, Canada, Australia e Nuova Zelanda (32 paesi). Il selettore elenca paesi e territori ISO, ma **la copertura mondiale dei numeri e dei servizi di ascolto resta da completare**. Per l’Italia include Telefono Amico Italia, verificato con il servizio dedicato alle helpline. Il numero Samaritans suggerito nella richiesta non è stato inserito perché non confermato da quella fonte. Per Telefono Amico gli orari non erano presenti nella risposta verificata: il foglio lo dichiara e rimanda al sito del servizio. Nessuna indicazione «aperto ora» viene dedotta. Prima di ampliare la copertura, verificare numeri e orari con le fonti competenti; gli eventuali orari limitati richiederanno anche il fuso orario del servizio.

Fonti del catalogo emergenze: [Commissione europea](https://digital-strategy.ec.europa.eu/en/policies/112), [Crisis Centre belga per la disponibilità del 112](https://crisiscenter.be/en/what-can-you-do/right-reflex/raise-alarm/call-112), [Governo britannico](https://www.gov.uk/guidance/999-and-112-the-uks-national-emergency-numbers), [National 911 Program](https://www.911.gov/calling-911/), [Public Safety Canada](https://www.getprepared.gc.ca/cnt/hzd/drng-en.aspx), [Governo australiano](https://www.infrastructure.gov.au/media-communications/phone/triple-zero/how-call-triple-zero-000), [Triple Zero Victoria per la disponibilità](https://www.triplezero.vic.gov.au/our-services), [Immigration New Zealand](https://www.immigration.govt.nz/live/staying-safe-and-knowing-your-rights/police-emergency-services-and-natural-disasters/).

Il pulsante Chiama apre un URL `tel:` solo dopo un tocco esplicito; l’iPhone gestisce la conferma della chiamata. Non sono state effettuate chiamate reali durante le prove. Il catalogo non richiede rete; i collegamenti ai siti sì. Il controllo non salva copie aggiuntive del testo né lo invia a servizi remoti; resta valido il funzionamento della dettatura Apple descritto dal relativo permesso.

Verificati: build iPhone Simulator; apertura automatica del foglio da un testo di prova; chiusura e nuovo tentativo di avvio delle carte; cambio Italia → Stati Uniti; stato senza contatti per il Giappone; ritorno al paese automatico. `Checks/run.sh` verifica anche le espressioni di rischio e alcuni casi negativi, i blocchi del percorso, i contatti per paese, i numeri telefonici e l’assenza di orari inventati.

## Struttura

- `DesignSystem`: colori, tipografia, sfondi, mascotte, pulsanti e input.
- `Models`: stato del percorso, carte, risposte e decisioni salvate.
- `Features`: benvenuto e schermate di Reflect.
- `Services`: dettatura e contapassi.
- `Resources`: font e licenza.

La navigazione usa `NavigationStack`; tornare dalla decisione conserva la carta corrente e le risposte. Il pulsante Ready ignora i tocchi nei 300 ms successivi a una risposta. La dettatura si arresta quando si lascia la schermata, anche se una richiesta di permesso era ancora in attesa.
