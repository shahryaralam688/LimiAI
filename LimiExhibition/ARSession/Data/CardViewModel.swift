//
//  CardViewModel.swift
//  IKEA_NC1
//
//  Created by Federica Mosca on 23/11/23.
//

import Foundation
import Observation
import SwiftUI

class CardsViewModel {
    let cards: [Card] = [
        Card(
            imageName: ["chairFront", "chairSide", "chairBack"],
            title: "Amazing Chair",
            price: 49.0,
            description: "Perfect for watching old TV Shows",
            objectName: "ceilingmultiplependants",
            size: "22 x 22 x 22",
            color: "red"
        ),
        Card(
            imageName: ["vaseFront", "vaseSide", "vaseBack"],
            title: "Cute Vase",
            price: 10.0,
            description: "Ideal to keep your flower alive",
            objectName: "ceilingonependant",
            size: "33 x 33 x 33",
            color: "orange"
        ),
        Card(
            imageName: ["tvFront", "tvSide", "tvBack"],
            title: "Formidable TV",
            price: 800.0,
            description: "TV description",
            objectName: "ceilingpendant",
            size: "44 x 44 x 44",
            color: "brown"
        ),
        Card(
            imageName: ["guitarFront", "guitarSide", "guitarBack"],
            title: "Perfect Guitar",
            price: 100.0,
            description: "For amazing artists",
            objectName: "guitar",
            size: "11 x 11 x 11",
            color: "brown"
        ),
        Card(
            imageName: ["lampFront", "lampSide", "lampBack"],
            title: "Floor Lamp",
            price: 65.0,
            description: "Light up your space",
            objectName: "floorlamp",
            size: "25 x 25 x 150",
            color: "white"
        ),
        Card(
            imageName: ["lightFront", "lightSide", "lightBack"],
            title: "Wall Light",
            price: 35.0,
            description: "Stylish and modern",
            objectName: "walllight",
            size: "20 x 20 x 30",
            color: "black"
        )
    ]
}

