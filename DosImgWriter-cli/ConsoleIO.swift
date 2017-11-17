//
//  ConsoleIO.swift
//  DosImgWriter-cli
//
//  Created by Harry Culpan on 11/17/17.
//  Copyright © 2017 Harry Culpan. All rights reserved.
//

import Foundation

enum OutputType {
    case error
    case standard
}

class ConsoleIO {
    func writeMessage(_ message: String, to: OutputType = .standard) {
        switch to {
        case .standard:
            print("\(message)")
        case .error:
            fputs("Error: \(message)\n", stderr)
        }
    }
    
}
