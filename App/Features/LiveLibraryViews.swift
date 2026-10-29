import SwiftUI

struct PublishedHoursView: View {
    let place: Place
    let now: Date
    @State private var expanded = false
    @Environment(\.betweenReducedMotion) private var reduceMotion
    private var days: [Date] {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: calendar.startOfDay(for: now)) }
    }
    var body: some View {
        Surface {
            VStack(alignment: .leading, spacing: 12) {
                Button { withAnimation(BetweenMotion.animation(reduceMotion)) { expanded.toggle() } } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Eyebrow(text: "Published opening hours")
                            Text(place.hoursLabel(at: now)).font(.headline)
                            if place.hours?.closing(at: now) == .closed { Text(place.nextOpeningLabel(at: now)).font(.caption).foregroundStyle(Color.metadata) }
                        }
                        Spacer()
                        Image(systemName: "chevron.down").rotationEffect(.degrees(expanded ? 180 : 0))
                    }.foregroundStyle(Color.ink).frame(minHeight: 44)
                }.buttonStyle(BetweenPressStyle()).accessibilityLabel("Published hours, \(expanded ? "collapse" : "expand") week").accessibilityIdentifier("published-hours")
                if expanded {
                    VStack(spacing: 12) {
                        ForEach(days, id: \.self) { day in
                            HStack(alignment: .top) {
                                Text(CampusClock.sameDay(now, day) ? "Today" : CampusClock.dayLabel(day)).fontWeight(CampusClock.sameDay(now, day) ? .semibold : .regular)
                                Spacer(minLength: 20)
                                Text(label(day)).multilineTextAlignment(.trailing)
                            }.font(.subheadline)
                        }
                        Text("Campus time · America/New_York").font(.caption2).foregroundStyle(Color.metadata).frame(maxWidth: .infinity, alignment: .leading)
                    }.transition(.opacity)
                }
                if let fetched = place.hours?.fetchedAt {
                    Text("UF LibCal · checked " + CampusClock.timeLabel(fetched)).font(.caption).foregroundStyle(Color.metadata)
                }
                Link("View official hours", destination: place.hoursURL).font(.subheadline.weight(.medium)).frame(minHeight: 44)
            }
        }
    }
    private func label(_ day: Date) -> String {
        guard let hours = place.hours, let fetched = hours.fetchedAt, now.timeIntervalSince(fetched) < 86400 else { return "Not confirmed" }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "America/New_York")!
        guard let next = calendar.date(byAdding: .day, value: 1, to: day), hours.verifiedDays?.contains(where: { $0.start <= day && day < $0.end }) == true else { return "Not confirmed" }
        let intervals = hours.intervals.filter { $0.start < next && $0.end > day }
        guard !intervals.isEmpty else { return "Closed" }
        if intervals.contains(where: { $0.start <= day && $0.end >= next }) { return "24 hours" }
        return intervals.map { range in
            let start = max(day, range.start)
            // Preserve overnight closing times without pretending an opening earlier in the day.
            return CampusClock.timeLabel(start) + " – " + (range.end >= next ? "midnight" : CampusClock.timeLabel(range.end))
        }.joined(separator: ", ")
    }
}

struct StudyRoomsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.betweenReducedMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    let place: Place
    @State private var start = StudyRoomService.nextSlot(after: Date())
    @State private var minutes = 30
    @State private var healthGroup = false
    @State private var capacity = 0
    @State private var availability: RoomAvailability?
    @State private var loading = false
    @State private var issue: String?
    @State private var refreshID = 0
    @State private var generation = RequestGeneration()
    private var query: String { "\(start.timeIntervalSince1970)-\(minutes)-\(healthGroup)-\(capacity)-\(refreshID)" }
    private var selectionKey: String { "\(start.timeIntervalSince1970)-\(minutes)-\(healthGroup)-\(capacity)" }
    @State private var loadedKey: String?
    @State private var showAllRooms = false
    @State private var alignedWithPlan = false
    var body: some View {
        Surface {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Eyebrow(text: "Reserve a room or carrel")
                    Spacer()
                    if loading { ProgressView().controlSize(.small) }
                    Button { refreshID += 1 } label: { Image(systemName: "arrow.clockwise").frame(width: 44, height: 44) }.accessibilityLabel("Refresh room availability")
                }
                Text("Available for your time").font(.title3.weight(.bold))
                if place.id == "health" {
                    Picker("Room type", selection: $healthGroup) { Text("Individual").tag(false); Text("Group study").tag(true) }.pickerStyle(.segmented)
                }
                DatePicker("Start", selection: Binding(get: { start }, set: { start = StudyRoomService.nextSlot(after: $0) }), in: Date()...Date().addingTimeInterval(13 * 86400), displayedComponents: [.date, .hourAndMinute])
                    .environment(\.timeZone, TimeZone(identifier: "America/New_York")!)
                    .accessibilityIdentifier("room-start")
                Picker("Duration", selection: $minutes) {
                    ForEach([30, 60, 90, 120], id: \.self) { Text("\($0)m").tag($0) }
                }.pickerStyle(.segmented).accessibilityIdentifier("room-duration")
                Picker("Room size", selection: $capacity) {
                    Text("Any size").tag(0); Text("1 person").tag(1); Text("2–4 people").tag(2); Text("5–8 people").tag(3); Text("9+ people").tag(4)
                }.pickerStyle(.menu)
                Text("Times are at UF · Confirm availability before booking.").font(.caption).foregroundStyle(Color.metadata)
                if store.hasOrigin, let journey = store.journeys[place.id] {
                    let arrival = store.now.addingTimeInterval(journey.to * 60)
                    let finish = store.plan.deadline(at: store.now).addingTimeInterval(-Double(store.plan.buffer) * 60 - journey.onward * 60)
                    if start < arrival {
                        NoticeView(title: "This booking starts before your estimated arrival.", symbol: "figure.walk")
                        Button("Use my arrival time") { start = StudyRoomService.nextSlot(after: arrival) }.frame(minHeight: 44)
                    } else if start.addingTimeInterval(Double(minutes) * 60) > finish {
                        NoticeView(title: "This search is outside your current study gap. Choose another time for a future booking, or use library seating for a shorter visit.", symbol: "clock")
                    }
                }
                if let issue { NoticeView(title: issue, symbol: "wifi.exclamationmark") }
                if let availability, loadedKey == selectionKey {
                    let current = availability.isCurrent(at: Date()) && issue == nil
                    HStack {
                        Image(systemName: current ? "calendar.badge.checkmark" : "clock.badge.exclamationmark")
                        Text("\(availability.total) \(availability.total == 1 ? "space" : "spaces") \(current ? "listed" : "previously listed")").fontWeight(.semibold).contentTransition(.numericText())
                    }.accessibilityIdentifier("room-result-count")
                    if availability.total == 0 {
                        Text("UF lists no reservable spaces for this time. Try a different time or library.").font(.subheadline).foregroundStyle(Color.metadata)
                    }
                    ForEach(Array(showAllRooms ? availability.rooms[...] : availability.rooms.prefix(3))) { room in
                        Link(destination: room.url) {
                            HStack(spacing: 12) {
                                Image(systemName: room.capacity == 1 ? "person" : "person.2").frame(width: 34, height: 34).background(Color.highlight, in: RoundedRectangle(cornerRadius: 10))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(room.name).font(.subheadline.weight(.semibold))
                                    if let capacity = room.capacity { Text("Capacity \(capacity)").font(.caption).foregroundStyle(Color.metadata) }
                                }
                                Spacer(minLength: 4)
                                Image(systemName: "arrow.up.right").font(.caption)
                            }.foregroundStyle(Color.ink).frame(minHeight: 48)
                        }.buttonStyle(BetweenPressStyle()).accessibilityIdentifier("room-\(room.id)")
                    }
                    if availability.rooms.count > 3 {
                        Button(showAllRooms ? "Show fewer spaces" : "Show all \(availability.rooms.count) spaces") { withAnimation(BetweenMotion.animation(reduceMotion)) { showAllRooms.toggle() } }.font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                    }
                    if availability.total == 0 { Button("Try 30 minutes later") { start = start.addingTimeInterval(1800) }.frame(minHeight: 44) }
                    Text("UF LibCal · checked " + CampusClock.timeLabel(availability.retrievedAt)).font(.caption).foregroundStyle(Color.metadata)
                    Link("Confirm availability & book with UF", destination: availability.searchURL).font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                } else if loading { Text("Checking UF’s reservation system…").font(.subheadline).foregroundStyle(Color.metadata) }
                Text("Booking requires UF’s eligibility rules. A listed room is not a confirmed reservation.").font(.caption2).foregroundStyle(Color.metadata)
            }
        }
        .animation(BetweenMotion.animation(reduceMotion), value: availability?.total)
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(60)) } catch { return }
                refreshID += 1
            }
        }
        .task(id: query) {
            if !alignedWithPlan {
                alignedWithPlan = true
                if store.filters.group { capacity = 2; if place.id == "health" { healthGroup = true } }
                let walk = store.hasOrigin ? store.journeys[place.id]?.to ?? 0 : 0
                let arrival = StudyRoomService.nextSlot(after: Date().addingTimeInterval(walk * 60))
                if arrival != start { start = arrival; return }
            }
            let ticket = generation.next(); loading = true; issue = nil
            if loadedKey != selectionKey { showAllRooms = false }
            defer { if generation.accepts(ticket) { loading = false } }
            do {
                let selectedKey = selectionKey
                let value = try await store.roomData.availability(placeID: place.id, start: start, minutes: minutes, groupID: place.id == "health" && healthGroup ? 9718 : nil, capacity: capacity, force: refreshID > 0)
                guard !Task.isCancelled, generation.accepts(ticket) else { return }
                availability = value; loadedKey = selectedKey
            } catch {
                guard !Task.isCancelled, generation.accepts(ticket) else { return }
                issue = (error as? AppFailure)?.localizedDescription ?? "UF room availability could not load. Refresh or open UF reservations."
            }
        }
        if let url = place.reservationURL, issue != nil { Link("Open UF reservations", destination: url).font(.subheadline).frame(minHeight: 44) }
    }
}
