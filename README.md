# Gut Check · Reflect & Turbo

A native SwiftUI app built from the WhyNot Figma design. Open `WhyNot.xcodeproj` with Xcode 27.1; the deployment target is iOS 27. All app interface text is in English. Unbounded is bundled under the OFL license; body text uses the system rounded font. Mascots and backgrounds are local assets from the original design.

## Run

1. Open `WhyNot.xcodeproj` and select the **WhyNot** scheme.
2. Choose **WhyNot · Figma QA**, another iOS 27 simulator, or an iPhone with iOS 27.
3. Run with **⌘R**, then choose **Reflect** or **Turbo**.

## Apple Watch

Gut Check includes a companion app for watchOS 27. To run it in Xcode, select **GutCheckWatch Watch App** and a paired Apple Watch destination. Start a Reflect walk on iPhone and open Gut Check on Apple Watch. Tap **Start walk** when the watch shows that the iPhone walk is ready. The watch counts toward the 2,000-step goal and can finish early with **End walk**. Finishing the linked walk advances Reflect on iPhone.

Allow notifications on Apple Watch to get a walk invitation when the system delivers the Reflect request in the background. If the Watch app is open, the invitation appears on its start screen. Both devices show the higher of their cumulative counts for a linked walk, preventing the same steps from being counted twice.

The Watch keeps the active walk and queues completed walks locally when you leave the iPhone behind. After reconnection, a linked completion advances the matching Reflect session, and a standalone walk appears as the latest Watch walk on the Reflect pause screen. Watch Connectivity exchanges walk identifiers, times, and counts. Reflection questions and answers stay on iPhone.

## Turbo

Turbo (Panic Mode) is a short, game-like round for when there are a few options and little time:

- Enter three to six different options. A repeated option is flagged under its field ("Sushi is already on your list. Try a different option."), ignoring capitals, accents, and extra spaces, and Start stays disabled until it changes. Dictation fills a selected or empty field.
- The first Start opens How to play. After that, Start shows a 3–2–1 countdown and the round begins.
- Each option is a Liquid Glass bubble filled with a Gut Check brand color (Dare Devil, Electric, Gold, Royal, Arctic). The liquid level is the time that option has left.
- Every option gets its own hidden timer, spread between 3 and 12 seconds and shuffled each round, so the order you typed them never predicts which pops first. An option pops the moment its timer reaches zero and leaves a ghost.
- Tap to save: every tap adds a second, as often as you like, up to a full bubble (12 seconds), with a bounce, a splash and a haptic. Hold still to pick now; a ring fills while you hold. Flick to let go: the bubble flies off screen in the direction you threw it and never comes back.
- The round lasts 15 seconds and never gets longer. It ends when one option is left, when you hold one, or when time runs out. At time-up the option tapped most wins; equal taps ask you to pick between the tied options with no timer. If nothing was tapped or let go, the round ends in Time’s up with no pick.
- Back or Pause freezes the timers and offers Resume (with a 3–2–1), Start over with new timers, Save for later, or Discard. Leaving the options screen with something typed offers Save for later, Keep editing, or Discard. Saved-for-later decisions appear in Waiting for you as "Turbo · Unfinished"; resuming keeps the options and starts a fresh round with new timers.
- After the pick, the feeling slider starts neutral. Rating the pick Not great suggests the runner-up: the option tapped most during the round, or the one that lasted longest. You can go with it, keep the pick, or try again. Going with it asks how that option feels before saving, so the saved feeling is about the final choice; the switch is saved with the original pick.
- Sounds, the app-switcher privacy cover, and the 3–2–1 on return are unchanged.

Round timing uses monotonic system uptime, and several expiries inside one slow frame are processed in time order. Reduce Motion stops bubble drift, the liquid wave, and the wobble. Decisions are stored in `Documents/turbo-decisions.json` with atomic writes and complete file protection; records from the earlier Turbo still load. Timing values live in `TurboRules` and scale from the round length.

## Reflect

Reflect includes the welcome screen, mode selection, editable question, Mixed / Best case / Worst case lenses, six swipeable Yes/No cards, an early Ready action, pause, walk, return options, decision entry, feeling slider, answer recap, and local saving. Back navigation preserves the current card and answers. A 300 ms guard rejects accidental duplicate answers. Decisions are stored in `Documents/decisions.json` with atomic writes and complete file protection.

**Generate cards** checks the typed or dictated dilemma for safety, then opens a full-screen shuffle with the selected lens mascot. Private Cloud Compute can generate the complete six-question deck. The on-device model extracts a short English description of the choice, which the app uses to compose six Yes/No questions for the selected lens. Each deck is validated before use. If the model is unavailable or generation fails, the standard deck for the lens opens. Generation has a five-second deadline, and **Use standard cards** skips the wait. A walk draft retains the actual personalized deck and answers across relaunches.

Private Cloud Compute takes priority when the iPhone build is configured for it and the person has allowed it in Reflect. An unavailable cloud service or an attempt that takes two seconds triggers the on-device attempt for the remainder of the deadline. To enable PCC, first obtain Apple’s managed entitlement `com.apple.developer.private-cloud-compute` and include it in the WhyNot iPhone target’s signing configuration and provisioning profile. Set the iPhone target’s user-defined build setting `REFLECTION_PRIVATE_CLOUD_COMPUTE_ENABLED` to `YES` for that configuration. The app uses the on-device model directly in other builds. [Apple’s PCC access requirements](https://developer.apple.com/private-cloud-compute/)

Speech callbacks are explicitly Sendable and generation checked. An actor serializes microphone start/stop, and audio session activation/deactivation uses the asynchronous API. The microphone waveform uses 50 ms RMS measurements, a bounded history, and a scrolling 14-bar display. Reduce Motion updates levels without scrolling. Dictation stops on navigation away and when safety support opens.

The simulator does not provide real step counts and may not provide a usable microphone input. Verify dictation, motion permissions, step counting, and haptics on an iPhone. Permissions are handled without requiring access to continue typing or leave a walk.

## Safety support

A compact English bottom sheet uses the app’s Unbounded heading, rounded body text, dark surfaces, and a coral emergency action. Both emergency and listening contacts fit in the default presentation for Italy. Large accessibility text uses the large sheet and scrollable content. The support button is also available manually in Reflect.

The country is selected automatically from the device region using `Locale`; there is no country picker or manual override and no location permission. Device region is not physical location and cannot reliably detect travel. Unknown or unsupported regions do not inherit another country’s number.

The offline, versioned catalog is `WhyNot/Resources/SafetyContacts.json`. Verified on November 16, 2026, it covers emergency contacts in the 27 EU countries, the UK, the USA, Canada, Australia, and New Zealand (32 countries). The Italy listening contact was verified with the dedicated helpline service. Unconfirmed hours are labeled as unconfirmed, with a link to the service website; the app does not infer that a service is currently open. Global listening-service coverage and remaining country coverage still need verified data.

A deterministic local screening layer checks typed/dictated text after 700 ms of inactivity and again before starting Reflect cards or a Turbo round. It recognizes selected Italian and English expressions relating to self-harm, violence, and possible medical emergencies. It can miss signals or produce false positives, and is not a clinical risk assessment. Reflect stops card generation for model safety blocks and refuses to substitute a different model or deck in that case. Contact information comes from the verified catalog.

Call actions open a `tel:` URL only after an explicit tap; iOS handles the phone confirmation. Attribution parameters are excluded from dialer URLs. No real calls were made during testing. Screening does not log text or create additional copies, and does not send text to a remote model. Apple dictation remains subject to the speech-recognition permission.

Emergency sources: [European Commission](https://digital-strategy.ec.europa.eu/en/policies/112), [Belgian Crisis Centre](https://crisiscenter.be/en/what-can-you-do/right-reflex/raise-alarm/call-112), [UK Government](https://www.gov.uk/guidance/999-and-112-the-uks-national-emergency-numbers), [National 911 Program](https://www.911.gov/calling-911/), [Public Safety Canada](https://www.getprepared.gc.ca/cnt/hzd/drng-en.aspx), [Australian Government](https://www.infrastructure.gov.au/media-communications/phone/triple-zero/how-call-triple-zero-000), [Triple Zero Victoria](https://www.triplezero.vic.gov.au/our-services), [Immigration New Zealand](https://www.immigration.govt.nz/live/staying-safe-and-knowing-your-rights/police-emergency-services-and-natural-disasters/).

## Checks

Run `zsh Checks/run.sh` for model checks covering Reflect navigation/persistence, local screening and the contact catalog, and Turbo options and repeats, spread timers, unlimited taps up to a full bubble, the fixed round, every ending including the tie, pause/resume, the runner-up, drafts, failed writes, and loading older records. Run `zsh Checks/run-audio.sh` for waveform/RMS checks without microphone access.

### Reflect Evaluations

In Xcode 27.1, select the shared **ReflectEvaluations** scheme and an iPhone running iOS 27 with Apple Intelligence available. Run **Product → Test**, then open **Evaluations** under the test run in the Report navigator. The local model runs through the same session, validation and fallback path as **Generate cards**. The model gets a one-second prewarm before the timer starts, and the timer ends when the deck is ready in the session. Use a physical iPhone for device timing.

The baseline covers 24 synthetic English and Italian dilemmas across all three lenses. Six additional safety cases verify the expected support route and check that the generator received zero requests. These safety cases run even when Apple Intelligence is unavailable.

- **Personalized deck within 5 seconds** is the main product metric. **Standard deck shown** and **Model block or refusal** show how the remaining requests ended. The detailed results distinguish Apple guardrails, the model requesting support, local output screening and model refusals.
- **Six valid questions and correct lenses** checks the app’s deck validation and the expected lens sequence for each case.
- **Expected details present** checks reference terms in personalized decks with concrete input. **Known unsupported detail markers absent** flags recurring inventions in annotated cases. Inspect the questions in the report for semantic lens fit, repeated ideas, natural English, other invented details and leading language.
- **Seconds until deck is ready** reports the median and 95th percentile for all decks shown, including standard decks. The detailed rows show the provider attempts and outcome for each case.

Export the baseline report before changing the prompt, then rerun the same cases on the same device and OS. For the cloud-first comparison, turn on `WHYNOT_EVALUATE_PCC` under **Edit Scheme → Test → Arguments** after enabling the PCC capability on the signed host app. That test uses the same synthetic cases and the production cloud-to-device fallback.

The app builds for iPhone Simulator. Reflect and Turbo have both been exercised through saving. Turbo’s manual simulator check covered editing a fourth option, countdown, bubble rendering, rescue by tap, choosing by long press, feeling selection, and the saved summary. The compact English support sheet has been visually checked on iPhone 17 with both Italian contacts visible and no country selector.

## Structure

- `DesignSystem`: tokens, typography, backgrounds, mascots, inputs, and buttons.
- `Models`: Reflect/Turbo state, routes, records, safety screening, and the contact directory.
- `Features`: welcome, Reflect, and Turbo screens.
- `Services`: speech capture, audio metering, and motion tracking.
- `Resources`: font, license, and offline contact catalog.

Live Activities and iCloud synchronization remain future work. The original two ideas are retained in `idee da implementare.md`, visible in Xcode’s project navigator.
