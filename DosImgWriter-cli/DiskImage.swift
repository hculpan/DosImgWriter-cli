//
//  DiskImage.swift
//  DosImgWriter-cli
//
//  Created by Harry Culpan on 11/17/17.
//  Copyright © 2017 Harry Culpan. All rights reserved.
//

import Foundation

class FileImage {
    var name: String = ""
    
    var ext: String = ""
    
    var isFile: Bool = true
    
    var isDirectory: Bool = false
    
    init(name: String, ext: String) {
        self.name = name
        self.ext = ext
    }

    init(name: String) {
        self.name = name
    }
    
    func getFullName() -> String {
        if (ext == "") {
            return name
        } else {
            return name + "." + ext
        }
    }
    
    func getFullNameTrimmed() -> String {
        if (ext == "") {
            return name.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            return name.trimmingCharacters(in: .whitespacesAndNewlines) + "." + ext.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}

class DiskImage {
    let consoleIO = ConsoleIO()
    
    var imageFile: String
    
    var oemSignature = ""
    
    var blockSize: UInt16 = 0
    
    var numberOfBlocks: UInt16 = 0
    
    var numberOfFats: Int8 = 0
    
    var totalBlocks: Int32 = 0
    
    var rootDirEntries: Int16 = 0
    
    var volumeLabel: String = ""
    
    var fileSystemId: String = ""
    
    var mediaDescriptor: String = ""
    
    var sectorsPerFat: UInt16 = 0
    
    var sectorsPerCluster: UInt8 = 0
    
    var clusterSize: UInt16 = 0
    
    var addressOfFirstFat: UInt32 = 0
    
    var addressOfRootDir: UInt32 = 0
    
    var rawdata: Data = Data()
    
    init(imageFileName: String) {
        imageFile = imageFileName
    }
    
    func doStuff() {
        do {
            rawdata = try Data(contentsOf: URL(string: "file://\(imageFile)")!, options: .alwaysMapped)
            oemSignature = getString(start: 3, length: 8)
            blockSize = getUInt16(start: 11)
            sectorsPerCluster = UInt8(rawdata[13])
            numberOfBlocks = getUInt16(start: 14)
            numberOfFats = Int8(rawdata[16])
            rootDirEntries = getInt16(start: 17)
            totalBlocks = Int32(getInt16(start: 19))
            mediaDescriptor = determineMediaDescriptor(value: UInt8(rawdata[21]))
            volumeLabel = getString(start: 43, length: 11   )
            fileSystemId = getString(start: 54, length: 8)
            sectorsPerFat = getUInt16(start: 22)
            
            // Derived values
            clusterSize = UInt16(UInt16(sectorsPerCluster) * blockSize)
            addressOfFirstFat = UInt32(numberOfBlocks * blockSize)
            addressOfRootDir = addressOfFirstFat + UInt32(((sectorsPerFat * blockSize) * 2))
        } catch {
            print(error)
        }
    }
    
    func getDirectory(name: String) -> [FileImage] {
        var result: [FileImage] = []
        
        for i in 0...rootDirEntries {
            let startOffset = Int(addressOfRootDir + UInt32(i * 32))
            let value: UInt8 = UInt8(rawdata[startOffset])
            if (value != 0x00 && value != 0x05 && value != 0xE5) {
                let exchar: UInt8 = UInt8(rawdata[startOffset + 8])
                if ((exchar >= 48 && exchar <= 57) ||
                    (exchar >= 65 && exchar <= 90) ||
                    (exchar >= 97 && exchar <= 122) ||
                    (exchar == 95)) {
                    let ext = getString(start: startOffset + 8, length: 3)
                    result.append(FileImage(name: getString(start: startOffset, length: 8), ext: ext))
                } else {
                    result.append(FileImage(name: getString(start: startOffset, length: 8)))
                }
            }
        }
        
        return result
    }
    
    func outputExtendedDetails() {
        consoleIO.writeMessage("First FAT offset       : \(String(format: "0x%04X", addressOfFirstFat))")
        consoleIO.writeMessage("Root directory offset  : \(String(format: "0x%04X", addressOfRootDir))")
    }
    
    func outputDetails() {
        consoleIO.writeMessage("Data size              : \(rawdata.count)")
        consoleIO.writeMessage("Signature              : \(oemSignature)")
        consoleIO.writeMessage("Block size             : \(blockSize)")
        consoleIO.writeMessage("Sectors per cluster    : \(sectorsPerCluster)")
        consoleIO.writeMessage("Cluster size           : \(clusterSize)")
        consoleIO.writeMessage("Num of reserved blocks : \(numberOfBlocks)")
        consoleIO.writeMessage("Num of FAT             : \(numberOfFats)")
        consoleIO.writeMessage("Sectors per FAT        : \(sectorsPerFat)")
        consoleIO.writeMessage("Root directory entries : \(rootDirEntries)")
        consoleIO.writeMessage("Total blocks on disk   : \(totalBlocks)")
        consoleIO.writeMessage("Volume label           : \(volumeLabel)")
        consoleIO.writeMessage("File System Identifier : \(fileSystemId)")
        consoleIO.writeMessage("Media type descriptor  : \(mediaDescriptor)")
    }
    
    func getInt16(start: Int) -> Int16 {
        let intBits = rawdata.withUnsafeBytes({(bytePointer: UnsafePointer<UInt8>) -> Int16 in
            bytePointer.advanced(by: start).withMemoryRebound(to: Int16.self, capacity: 2) { pointer in
                return pointer.pointee
            }
        })
        return Int16(littleEndian: intBits)
    }

    func getUInt16(start: Int) -> UInt16 {
        let intBits = rawdata.withUnsafeBytes({(bytePointer: UnsafePointer<UInt8>) -> UInt16 in
            bytePointer.advanced(by: start).withMemoryRebound(to: UInt16.self, capacity: 2) { pointer in
                return pointer.pointee
            }
        })
        return UInt16(littleEndian: intBits)
    }
    
    func getInt32(start: Int) -> Int32 {
        let intBits = rawdata.withUnsafeBytes({(bytePointer: UnsafePointer<UInt8>) -> Int32 in
            bytePointer.advanced(by: start).withMemoryRebound(to: Int32.self, capacity: 4) { pointer in
                return pointer.pointee
            }
        })
        return Int32(littleEndian: intBits)
    }
    
    func determineMediaDescriptor(value: UInt8)-> String {
        switch value {
        case 0xF0:
            return "3.5 (1.44mb or 2.88mb) or 5.25 (1.2mb) double sided foppy"
        default:
            return "Unknown media type"
        }
    }
    
    func getString(start: Int, length: Int) -> String {
        return String(data: rawdata[start..<(start + length)], encoding: String.Encoding.utf8)!
    }
}
