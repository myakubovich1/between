import SwiftUI

struct PlanView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var plan = TimePlan()
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("A little time can go a long way.").font(.title2.weight(.bold)).listRowBackground(Color.clear)
                    HStack(spacing: 8) {
                        ForEach([30, 45, 60, 90], id: \.self) { minutes in
                            Button { plan.available = minutes } label: { Text("\(minutes)m").font(.headline).frame(maxWidth: .infinity, minHeight: 46).background(plan.available == minutes ? Color.brandFill : Color.highlight, in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(plan.available == minutes ? Color.onBrand : Color.ink) }.buttonStyle(.plain).accessibilityLabel("\(minutes) minutes").accessibilityIdentifier("duration-\(minutes)")
                        }
                    }
                    Stepper("Custom: \(plan.available) minutes", value: $plan.available, in: 15...240, step: 5)
                } header: { Text("How long is your gap?") }
                Section("Next commitment") {
                    Picker("Next destination", selection: $plan.nextID) {
                        Text("No next destination").tag(Optional<String>.none)
                        ForEach(store.places) { Text($0.shortName).tag(Optional($0.id)) }
                    }
                    Stepper("Leave a \(plan.buffer)-minute buffer", value: $plan.buffer, in: 0...20)
                    Text("Study time = your gap − walk there − onward walk − buffer. Closing time can shorten your plan.").font(.footnote).foregroundStyle(Color.metadata)
                    if plan.nextID == nil { Text("Without a destination, your plan excludes travel to the next commitment.").font(.footnote).foregroundStyle(Color.metadata) }
                }
                Section {
                    HStack(alignment: .top) {
                        Image(systemName: "clock.badge.checkmark").font(.title2).foregroundStyle(Color.ink)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("More useful minutes").font(.headline)
                            Text("A 45-minute gap, 6-minute walk there, 7 minutes onward and 5 minutes to spare leaves 27 minutes to study.").font(.subheadline).foregroundStyle(Color.metadata)
                            Text("Illustration with synthetic route values").font(.caption2).foregroundStyle(Color.metadata)
                        }
                    }.padding(.vertical, 8)
                }
            }.scrollContentBackground(.hidden).background(Color.canvas)
                .navigationTitle("Your in-between").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Find a spot") { store.plan = plan; store.persistPreferences(); dismiss() }.fontWeight(.semibold) }
                }
        }.onAppear { plan = store.plan }
    }
}
struct FiltersView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var filters = Filters()
    private var count: Int { RecommendationEngine.recommendations(places: store.places, journeys: store.journeys, evidence: store.evidenceByPlace, filters: filters, plan: store.plan, now: store.now).count }
    var body: some View {
        NavigationStack {
            Form {
                Section("What you need") {
                    Toggle("Confirmed open now", isOn: $filters.openNow)
                    Toggle("Designated quiet space", isOn: $filters.quiet)
                    Toggle("Known outlets", isOn: $filters.outlets)
                    Toggle("Known Wi-Fi", isOn: $filters.wifi)
                    Toggle("Group study suitability", isOn: $filters.group)
                    Picker("Prefer current sound", selection: $filters.preferredNoise) {
                        Text("No preference").tag(Optional<Noise>.none)
                        ForEach(Noise.allCases, id: \.self) { Text($0.label).tag(Optional($0)) }
                    }
                    Text("Sound is a soft preference. Missing or conflicting observations never count as a confirmed match.").font(.footnote).foregroundStyle(Color.metadata)
                    Text("These are requirements. An unknown amenity will not pass its filter. Group suitability does not guarantee adjacent seats.").font(.footnote).foregroundStyle(Color.metadata)
                }
                Section("Your walk & study time") {
                    Stepper("Up to \(filters.maxWalk) minutes walking", value: $filters.maxWalk, in: 5...30, step: 5)
                    Stepper("At least \(filters.minimumStudy) minutes studying", value: $filters.minimumStudy, in: 5...60, step: 5)
                }
                Section("Entry eligibility") {
                    Toggle("Only confirmed entry eligibility", isOn: $filters.confirmedAccess)
                    Picker("I can access", selection: $filters.eligibility) {
                        Text("Public spaces").tag(Access.unrestricted)
                        Text("UF student spaces").tag(Access.uf)
                        Text("Graduate student spaces").tag(Access.graduate)
                    }
                    Text("Apple sign-in does not verify UF affiliation. Unknown entry rules are shown as uncertain, never confirmed access.").font(.footnote).foregroundStyle(Color.metadata)
                }
                Section { Button("Reset all filters") { filters = Filters() } }
            }.scrollContentBackground(.hidden).background(Color.canvas)
                .navigationTitle("Find your fit").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Apply · \(count)") { store.filters = filters; store.persistPreferences(); dismiss() }.fontWeight(.semibold) }
                }
        }.onAppear { filters = store.filters }
    }
}
struct OriginView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { store.location.request() } label: { Label(store.location.requesting ? "Finding your location…" : "Use my location", systemImage: "location.fill").frame(minHeight: 44) }.disabled(store.location.requesting)
                    if let message = store.location.message { Text(message).font(.footnote).foregroundStyle(Color.metadata) }
                    if store.location.sample != nil {
                        Button("Start from this location") { store.usesLocation = true; store.scheduleRoutes(); dismiss() }
                    }
                } footer: { Text("Location is used only for this foreground task. No continuous tracking.") }
                Section("Or choose a manual campus origin") {
                    ForEach(store.places) { place in
                        Button { store.originID = place.id; store.usesLocation = false; store.location.clear(); store.scheduleRoutes(); dismiss() } label: {
                            HStack { Text(place.shortName); Spacer(); if store.originID == place.id && !store.usesLocation { Image(systemName: "checkmark") } }.frame(minHeight: 44)
                        }
                    }
                }
            }.navigationTitle("Where from?").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
    }
}
