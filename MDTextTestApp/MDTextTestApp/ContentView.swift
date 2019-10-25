//
//  ContentView.swift
//  MDTextTestApp
//
//  Created by Andre Carrera on 10/9/19.
//  Copyright © 2019 Lambdo. All rights reserved.
//

import SwiftUI
import MDText

struct ContentView: View {
    @State var markdown =
#"""
Combine the Digestive Blend, Turmeric, and Yarrow Pom in an empty capsule and take it 3x daily on an empty stomach.

Apply a drop of each oil to the upper abdomen 3x daily at the same time as the capsule is taken.

Take 2 Digestive Blend Softgels with food.

Suggested Duration: 3-6 months

**Additional Support: Probiotic Complex (take 2 capsules 2x daily on an empty stomach), Digestive Enzymes (take 1 capsule with each meal)**
"""#
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                HStack {
                    Spacer()
                }
//                Text("Description")
//                .font(.headline)
                MDText(markdown: markdown)
//                    .multilineTextAlignment(.leading)
                    
                
//                MDText(markdown: markdown)
            }
            .padding(.horizontal)
        }
    .onAppear(perform: onLoad)
    }
    
    func onLoad() {
//        self.markdown =
//        """
//here is a **preview** and is very *long* !ssd
//that is multiple lines
//"""
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
