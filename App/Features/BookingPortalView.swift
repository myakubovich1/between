import SwiftUI

/// A short, account-free directory. The user's browser owns UF sign-in, confirmation and cancellation.
struct BookingPortalView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Book directly with UF", systemImage: "calendar.badge.checkmark").font(.title3.bold())
                        Text("Choose a library to open UF’s official LibCal portal in your browser. Complete any required UF sign-in and confirm your reservation there.")
                            .font(.subheadline).foregroundStyle(Color.metadata)
                    }.padding(.vertical, 6)
                    Link(destination: UFBookingPortal.allSpaces) { Label("Browse all UF study spaces", systemImage: "arrow.up.right.square").frame(minHeight: 44) }
                        .accessibilityIdentifier("booking-all-spaces")
                }
                Section("Choose a library") {
                    ForEach(UFBookingPortal.destinations) { destination in
                        Link(destination: destination.url) {
                            HStack(spacing: 14) {
                                Image(systemName: "building.2").frame(width: 34, height: 34).background(Color.highlight, in: RoundedRectangle(cornerRadius: 10))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(destination.name).font(.headline)
                                    Text(destination.detail).font(.caption).foregroundStyle(Color.metadata)
                                }
                                Spacer(minLength: 4)
                                Image(systemName: "arrow.up.right").font(.caption)
                            }.foregroundStyle(Color.ink).frame(minHeight: 54)
                        }.accessibilityIdentifier("booking-library-" + destination.id)
                    }
                }
                Section("Already booked?") {
                    Text("Use the link in your UF confirmation email to view or cancel your booking. Between does not receive your reservations or UF credentials.")
                        .font(.subheadline).foregroundStyle(Color.metadata)
                    Link("UF study room policies", destination: UFBookingPortal.policies).frame(minHeight: 44)
                }
            }.scrollContentBackground(.hidden).background(Color.canvas)
                .navigationTitle("UF room bookings").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
