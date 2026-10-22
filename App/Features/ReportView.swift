import SwiftUI
import AuthenticationServices

struct ReportView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let place: Place
    @State private var zoneID: String?
    @State private var seat: Seat?
    @State private var noise: Noise?
    @State private var nearby = false
    @State private var submitting = false
    @State private var accepted = false
    @State private var error: String?
    @State private var needsReconfirmation = false
    @State private var key = UUID().uuidString
    @State private var confirmedAt = Date()
    init(place: Place, initialZone: String? = nil) { self.place = place; _zoneID = State(initialValue: initialZone) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if accepted {
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 64)).foregroundStyle(Color.forest)
                            Text(store.config.isDemo ? "Demo report saved" : "Thanks for the heads-up").font(.title2.weight(.bold))
                            Text(store.config.isDemo ? "This update only changed the isolated demo store." : "The server accepted your observation. It will help someone find their next spot.").font(.subheadline).foregroundStyle(Color.metadata).multilineTextAlignment(.center)
                            PrimaryButton(title: "Back to the place", symbol: "arrow.turn.up.left") { dismiss() }
                        }.padding(.vertical, 40).frame(maxWidth: .infinity).accessibilityIdentifier("report-success")
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Eyebrow(text: "A quick look around")
                            Text("How’s it looking?").font(.system(.largeTitle, design: .rounded, weight: .bold)).tracking(-1)
                            Text(place.name).font(.subheadline).foregroundStyle(Color.metadata)
                        }
                        if !place.zones.isEmpty {
                            Picker("Where are you reporting?", selection: $zoneID) {
                                Text("Building-wide").tag(Optional<String>.none)
                                ForEach(place.zones) { Text($0.name).tag(Optional($0.id)) }
                            }.pickerStyle(.menu).frame(minHeight: 44)
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            Eyebrow(text: "Seats · required")
                            ForEach(Seat.allCases, id: \.self) { option in
                                Button { seat = option } label: {
                                    HStack(spacing: 14) {
                                        Image(systemName: option.symbol).frame(width: 24)
                                        Text(option.label).font(.body.weight(.medium))
                                        Spacer()
                                        Image(systemName: seat == option ? "checkmark.circle.fill" : "circle").foregroundStyle(seat == option ? Color.forest : .secondary)
                                    }.foregroundStyle(Color.ink).padding(16).frame(minHeight: 56).background(seat == option ? Color.softForest : Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(seat == option ? Color.forest : .clear, lineWidth: 1.5))
                                }.buttonStyle(.plain).accessibilityIdentifier("seat-\(option.rawValue)").accessibilityAddTraits(seat == option ? .isSelected : [])
                            }
                        }
                        VStack(alignment: .leading, spacing: 12) {
                            Eyebrow(text: "Sound · optional")
                            Picker("Sound level", selection: $noise) {
                                Text("Skip").tag(Optional<Noise>.none)
                                ForEach(Noise.allCases, id: \.self) { Text($0.label).tag(Optional($0)) }
                            }.pickerStyle(.menu).frame(minHeight: 44)
                        }
                        Surface {
                            VStack(alignment: .leading, spacing: 10) {
                                Toggle("Add a nearby check", isOn: $nearby).onChange(of: nearby) { if nearby { store.location.request() } }
                                Text(nearby ? "A recent location is checked by the server, then discarded. This is a limited proximity signal, not proof of a floor or of accuracy." : "Self-reported · no location needed").font(.caption).foregroundStyle(Color.metadata)
                                if let message = store.location.message, nearby { Text(message).font(.caption).foregroundStyle(Color.metadata) }
                            }
                        }
                        if !store.signedIn {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Contribute with a little accountability.").font(.headline)
                                Text("Sign in to report. You can keep browsing and saving as a guest. Apple sign-in does not verify UF affiliation.").font(.caption).foregroundStyle(Color.metadata)
                                if store.config.isDemo {
                                    PrimaryButton(title: "Use demo contributor", symbol: "person.crop.circle.badge.checkmark") { store.signedIn = true }.accessibilityIdentifier("demo-sign-in")
                                } else if store.live != nil {
                                    SignInWithAppleButton(.signIn, onRequest: store.prepareApple) { result in Task { await store.completeApple(result) } }.frame(height: 50).clipShape(RoundedRectangle(cornerRadius: 12))
                                } else { NoticeView(title: "Live reporting needs the backend configuration. Your choices will stay here.") }
                            }
                        }
                        if let error = error ?? store.error { NoticeView(title: error, symbol: "exclamationmark.triangle") }
                        if needsReconfirmation {
                            Button { confirmedAt = Date(); needsReconfirmation = false; error = nil } label: { Label("I’ve checked again · conditions are current", systemImage: "checkmark.circle").font(.subheadline).frame(minHeight: 48) }.accessibilityIdentifier("reconfirm")
                        }
                        Text("Report what you can see right now. Reports expire after 30 minutes, and repeated reports don’t count as new people.").font(.caption).foregroundStyle(Color.metadata)
                    }
                }.padding(20)
            }.background(Color.canvas)
            .navigationTitle("Report conditions").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(accepted ? "Done" : "Cancel") { dismiss() } } }
            .safeAreaInset(edge: .bottom) {
                if !accepted {
                    PrimaryButton(title: submitting ? "Submitting…" : store.config.isDemo ? "Submit demo report" : "Submit observation", symbol: "arrow.up") {
                        guard let seat else { return }
                        submitting = true
                        Task {
                            do {
                                try await store.submit(place: place, zone: zoneID, seat: seat, noise: noise, key: key, confirmedAt: confirmedAt, checkNearby: nearby)
                                accepted = true
                            } catch { self.error = error.localizedDescription; needsReconfirmation = true }
                            submitting = false
                        }
                    }.disabled(seat == nil || submitting || !store.signedIn || needsReconfirmation).opacity(seat == nil || !store.signedIn || needsReconfirmation ? 0.5 : 1).padding(20).background(.bar).accessibilityIdentifier("submit-report")
                }
            }
        }
    }
}
struct EvidenceView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var place: Place
    var zone: String?
    private var evidence: Evidence { store.status(place: place.id, zone: zone) }
    var body: some View {
        NavigationStack {
            List {
                if let error = store.error { Section { NoticeView(title: error, symbol: "exclamationmark.triangle") } }
                Section("Student observations") {
                    StatusLabel(evidence: evidence, now: store.now)
                    EvidenceCaption(evidence: evidence, now: store.now)
                    Text("One effective report per person in this space. Recent observations carry more weight. Opposing observations are labeled ‘Reports differ’. No numerical seat counts are inferred.").font(.subheadline)
                    Text("Noise is aggregated separately. Skipped sound reports stay unknown.").font(.subheadline)
                    if let expiry = evidence.expiresAt, evidence.current(at: store.now) { Text("Next expiry: \(CampusClock.timeLabel(expiry)) campus time").font(.caption) }
                }
                Section("Venue policy") {
                    Text("Quiet-floor designations describe library policy, not what someone hears right now. Building and floor reports are separate.")
                }
                Section("Official occupancy") {
                    Text("No authorized occupancy provider is connected. The UF status page is a separate source; building occupancy does not measure empty desks.")
                    Link("Open UF occupancy page", destination: URL(string: "https://www.uflib.ufl.edu/status/")!)
                }
                if evidence.current(at: store.now) && !evidence.references.isEmpty {
                    Section("Help keep reports useful") {
                        ForEach(Array(evidence.references.enumerated()), id: \.element) { index, reference in
                            Menu("CommunityObservation \(index + 1)") {
                                Button("Flag inaccurate or abusive report", systemImage: "flag") { feedback(reference, block: false) }
                                Button("Mute this contributor", systemImage: "person.crop.circle.badge.minus") { feedback(reference, block: true) }
                            }.frame(minHeight: 44)
                        }
                        Text("Mute targets are resolved securely from a report reference. Contributor identity and activity history are never shown here.").font(.caption).foregroundStyle(Color.metadata)
                    }
                }
            }.navigationTitle("Behind the report").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
    private func feedback(_ reference: String, block: Bool) {
        Task { do { try await store.flag(reference: reference, block: block) } catch { store.error = error.localizedDescription } }
    }
}
