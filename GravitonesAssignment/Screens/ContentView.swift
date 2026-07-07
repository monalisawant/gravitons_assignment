//
//  ContentView.swift
//  Gravitons
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "play.rectangle.on.rectangle")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Gravitons")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
