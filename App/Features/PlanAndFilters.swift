import SwiftUI

struct PlanView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var plan = TimePlan()
    @State private var campusSearch = false
    private var destinationBinding: Binding<String?> {
        Binding(get: { plan.nextDestination != nil ? "custom" : plan.nextID }, set: { value in
            if value != "custom" { plan.nextID = value; plan.nextDestination = nil }
        })
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("How much time do you have from now?") {
                    HStack(spacing: 8) {
                        ForEach([30, 45, 60, 90], id: \.self) { minutes in
                            Button { plan.available = minutes } label: {
                                Text("\(minutes)m").font(.headline).frame(maxWidth: .infinity, minHeight: 46)
                                    .background(plan.available == minutes ? Color.brandFill : Color.highlight, in: RoundedRectangle(cornerRadius: 12))
                                    .foregroundStyle(plan.available == minutes ? Color.onBrand : Color.ink)
                            }.buttonStyle(BetweenPressStyle()).accessibilityLabel("\(minutes) minutes").accessibilityIdentifier("duration-\(minutes)")
                        }
                    }
                    Stepper("Custom: \(plan.available) minutes", value: $plan.available, in: 15...240, step: 5)
                    Text("Your remaining time will count down after you apply this plan.").font(.caption).foregroundStyle(Color.metadata)
                }
                Section("Where do you need to be next?") {
                    Picker("Next stop", selection: destinationBinding) {
                        Text("No next stop").tag(Optional<String>.none)
                        if let destination = plan.nextDestination { Text(destination.name).tag(Optional("custom")) }
                        ForEach(store.places) { Text($0.shortName).tag(Optional($0.id)) }
                    }
                    Button { campusSearch = true } label: { Label("Find my next class or building", systemImage: "building.2").frame(minHeight: 44) }.accessibilityIdentifier("next-campus")
                    Stepper("Arrive \(plan.buffer) minutes early", value: $plan.buffer, in: 0...20)
                    Text(plan.hasNextDestination ? "We include the walk to this destination and your arrival buffer." : "Set a next stop to include the walk to class. Without one, the plan only includes getting to the library and your buffer.").font(.footnote).foregroundStyle(Color.metadata)
                }
                Section("How your time is used") {
                    Text("Your gap minus the walk to the library, the walk to your next stop, and your arrival buffer. Closing time can shorten the session.").font(.subheadline).foregroundStyle(Color.metadata)
                    if store.hasOrigin { Text("Starting from " + store.originName).font(.caption) }
                    else { Text("Choose a starting point on Find to calculate walking times.").font(.caption) }
                }
            }.scrollContentBackground(.hidden).background(Color.canvas)
                .navigationTitle("Study plan").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Find a spot") {
                            plan.endsAt = (store.config.isDemo ? store.now : Date()).addingTimeInterval(Double(plan.available) * 60)
                            store.plan = plan; store.persistPreferences(); dismiss()
                        }.fontWeight(.semibold)
                    }
                }
                .sheet(isPresented: $campusSearch) {
                    CampusPlacePicker(title: "Next class or stop", allowNone: true) { destination in
                        plan.nextDestination = destination; plan.nextID = nil
                    }
                }
        }.onAppear {
            plan = store.plan
            plan.available = max(15, store.remainingMinutes)
            plan.endsAt = nil
        }
    }
}
struct FiltersView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var filters = Filters()
    private var count: Int { store.recommendations(using: filters).count }
    var body: some View {
        NavigationStack {
            Form {
                Section("What you need") {
                    Toggle("Confirmed open now", isOn: $filters.openNow)
                    Toggle("Designated quiet space", isOn: $filters.quiet)
                    Toggle("Bookable rooms or carrels", isOn: Binding(get: { filters.reservableRooms == true }, set: { filters.reservableRooms = $0 }))
                    if store.places.contains(where: { $0.amenities.outlets == true }) || filters.outlets { Toggle("Verified outlets", isOn: $filters.outlets) }
                    if store.places.contains(where: { $0.amenities.wifi == true }) || filters.wifi { Toggle("Verified Wi-Fi", isOn: $filters.wifi) }
                    Toggle("Group study suitability", isOn: $filters.group)
                    if store.communityAvailable {
                    Picker("Prefer current sound", selection: $filters.preferredNoise) {
                        Text("No preference").tag(Optional<Noise>.none)
                        ForEach(Noise.allCases, id: \.self) { Text($0.label).tag(Optional($0)) }
                    }
                    }
                    Text("Quiet means a published quiet-study policy. Room availability is checked for your chosen time in the library details.").font(.footnote).foregroundStyle(Color.metadata)
                    Text("Unverified amenities are not offered as filters. Group study does not guarantee adjacent seats.").font(.footnote).foregroundStyle(Color.metadata)
                }
                Section("Your walk & study time") {
                    Stepper("Up to \(filters.maxWalk) minutes walking", value: $filters.maxWalk, in: 5...30, step: 5).disabled(!store.hasOrigin)
                    if !store.hasOrigin { Text("Choose a starting point to filter by walking time.").font(.caption).foregroundStyle(Color.metadata) }
                    Stepper("At least \(filters.minimumStudy) minutes studying", value: $filters.minimumStudy, in: 5...60, step: 5)
                }
                Section("Entry eligibility") {
                    if store.places.contains(where: { $0.access != .unknown }) || filters.confirmedAccess { Toggle("Only confirmed entry eligibility", isOn: $filters.confirmedAccess) }
                    Picker("I can access", selection: $filters.eligibility) {
                        Text("Public spaces").tag(Access.unrestricted)
                        Text("UF student spaces").tag(Access.uf)
                        Text("Graduate student spaces").tag(Access.graduate)
                    }
                    Text("Choose the access that applies to you. Check the library’s entry rules, especially late at night.").font(.footnote).foregroundStyle(Color.metadata)
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
    @State private var campusSearch = false
    @State private var requestedHere = false
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { requestedHere = true; store.location.request() } label: { Label(store.location.requesting ? "Finding your location…" : "Use my location", systemImage: "location.fill").frame(minHeight: 44) }.disabled(store.location.requesting)
                    if let message = store.location.message { Text(message).font(.footnote).foregroundStyle(Color.metadata) }
                    Button { campusSearch = true } label: { Label("Find a campus building", systemImage: "building.2").frame(minHeight: 44) }.accessibilityIdentifier("origin-campus")
                } footer: { Text("Location is optional and used for this trip. You can choose a building instead.") }
                Section("Start at a library") {
                    ForEach(store.places) { place in
                        if let coordinate = place.coordinate {
                            Button {
                                store.chooseOrigin(.init(id: place.id, name: place.shortName, coordinate: coordinate, address: place.address)); dismiss()
                            } label: {
                                HStack { Text(place.shortName); Spacer(); if store.manualOrigin?.id == place.id { Image(systemName: "checkmark") } }.frame(minHeight: 44)
                            }
                        }
                    }
                }
            }.navigationTitle("Starting point").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
                .sheet(isPresented: $campusSearch) {
                    CampusPlacePicker(title: "Starting building") { destination in
                        if let destination { store.chooseOrigin(destination); dismiss() }
                    }
                }
        }
        .onChange(of: store.location.sample?.sampledAt) { _, sampled in
            if requestedHere, sampled != nil {
                store.chooseCurrentLocation(); dismiss()
            }
        }
    }
}
