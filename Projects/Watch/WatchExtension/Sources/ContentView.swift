import SwiftUI

struct ContentView: View {
    @EnvironmentObject var connectivity: WatchConnectivityManager

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Circle()
                    .fill(.blue.opacity(0.2))
                    .frame(width: 64, height: 64)

                Text("Watch App")
                    .font(.headline)

                Text(connectivity.isReachable ? "Connected" : "Disconnected")
                    .font(.caption2)
                    .foregroundStyle(connectivity.isReachable ? .green : .secondary)
            }
            .navigationTitle("Home")
        }
    }
}
