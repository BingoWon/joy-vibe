//
//  ContentView.swift
//  JoyVibe
//
//  Created by Bin Wang on 9/5/25.
//

import SwiftUI
import RealityKit

struct ContentView: View {
    var body: some View {
        Text("This view is deprecated. Use MainControlView instead.")
            .foregroundStyle(.secondary)
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
