//
//  main.swift
//  DosImgWriter-cli
//
//  Created by Harry Culpan on 11/16/17.
//  Copyright © 2017 Harry Culpan. All rights reserved.
//

import Foundation

do {
    let dosImgWriter = DosImgWriter()
    try dosImgWriter.staticMode()
} catch {
    print(error)
}

