//
//  DiskImage.swift
//  DosImgWriter-cli
//
//  Created by Harry Culpan on 11/17/17.
//  Copyright © 2017 Harry Culpan. All rights reserved.
//

import Foundation

enum DiskImageError: Error {
    case FileNotFound
    case DuplicateFileFound
}

class FileImage {
    var name: String = ""
    
    var ext: String = ""
    
    var attribute: UInt8 = 0
    
    var firstCluster: UInt16
    
    var fileSize: UInt32
    
    init(name: String, attr: UInt8, firstCluster: UInt16, fileSize: UInt32) {
        self.name = name
        self.attribute = attr
        self.firstCluster = firstCluster
        self.fileSize = fileSize
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
            return name.trimmingCharacters(in: .whitespaces)
        } else {
            return name.trimmingCharacters(in: .whitespaces) + "." + ext.trimmingCharacters(in: .whitespaces)
        }
    }
    
    func equals(fullName: String) -> Bool {
        return fullName.trimmingCharacters(in: .whitespaces) == getFullNameTrimmed()
    }
    
    func equals(name: String, ext: String) -> Bool {
        return self.name.trimmingCharacters(in: .whitespaces) == name.trimmingCharacters(in: .whitespaces) &&
            self.ext.trimmingCharacters(in: .whitespaces) == ext.trimmingCharacters(in: .whitespaces)
    }
    
    func getAttributesDescription() -> String {
        var text = ""
        
        if isReadOnly()    { text += "R" } else { text += " " }
        if isHidden()      { text += "H" } else { text += " " }
        if isSystem()      { text += "S" } else { text += " " }
        if isVolumeLabel() { text += "L" } else { text += " " }
        if isDirectory()   { text += "D" } else { text += " " }
        if isArchive()     { text += "A" } else { text += " " }
        if isDevice()      { text += "V" } else { text += " " }

        return text
    }
    
    func isReadOnly() -> Bool {
        return attribute & UInt8(0x01) > 0
    }
    
    func isHidden() -> Bool {
        return attribute & UInt8(0x02) > 0
    }
    
    func isSystem() -> Bool {
        return attribute & UInt8(0x04) > 0
    }

    func isVolumeLabel() -> Bool {
        return attribute & UInt8(0x08) > 0
    }
    
    func isDirectory() -> Bool {
        return attribute & UInt8(0x10) > 0
    }

    func isFile() -> Bool {
        return attribute & UInt8(0x10) == 0
    }
    
    func isArchive() -> Bool {
        return attribute & UInt8(0x20) > 0
    }
    
    func isDevice() -> Bool {
        return attribute & UInt8(0x40) > 0
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
            fileSystemId = getString(start: 54, length: 8)
            sectorsPerFat = getUInt16(start: 22)
            
            // Derived values
            clusterSize = UInt16(UInt16(sectorsPerCluster) * blockSize)
            addressOfFirstFat = UInt32(numberOfBlocks * blockSize)
            addressOfRootDir = addressOfFirstFat + UInt32(((sectorsPerFat * blockSize) * 2))

            volumeLabel = getVolumeLabel()
        } catch {
            print(error)
        }
    }
    
    func getDisplayableDirectory(name: String) throws -> [FileImage] {
        return try getDirectory(name: name).filter { (value: FileImage) -> Bool in
            return (value.attribute & 0x08 == 0) && (value.attribute & 0x40 == 0)
        }
    }
    
    func getRootDirectory() -> [FileImage] {
        var result: [FileImage] = []
        
        for i in 0...rootDirEntries {
            let startOffset = Int(addressOfRootDir + UInt32(i * 32))
            if (allowableCharacterInFilename(char: UInt8(rawdata[startOffset]))) {
                let newFileImage = FileImage(name: getString(start: startOffset, length: 8),
                                             attr: UInt8(rawdata[startOffset + 11]),
                                             firstCluster: getUInt16(start: startOffset + 26),
                                             fileSize: getUInt32(start: startOffset + 28))
                let exchar: UInt8 = UInt8(rawdata[startOffset + 8])
                if (allowableCharacterInFilename(char: exchar)) {
                    newFileImage.ext = getString(start: startOffset + 8, length: 3)
                }
                result.append(newFileImage)
            }
        }
        
        return result
    }
    
    func getDirectory(name: String) throws -> [FileImage] {
        guard (name == "\\") else {
            throw DiskImageError.FileNotFound
        }
        
        return getRootDirectory()
    }
    
    func getFileImage(name: String, ext:String, path: String) throws -> FileImage {
        let files = try getDirectory(name: path).filter { (i: FileImage) -> Bool in
            return i.equals(name: name, ext: ext)
        }
        
        guard files.count < 2 else {
            throw DiskImageError.DuplicateFileFound
        }
        
        guard files.count == 1 else {
            throw DiskImageError.FileNotFound
        }
        
        return files[0]
    }
    
    func getClustersForFile(name: String, ext:String, path: String) throws -> [UInt16] {
        var result: [UInt16] = []
        
        let fileImage = try getFileImage(name: name, ext: ext, path: path)
        var nextCluster = fileImage.firstCluster
        repeat {
            result.append(nextCluster)
            nextCluster = getFatTableEntry(index: nextCluster)
        } while (nextCluster > 0x001 && nextCluster <= 0xFEF)
        
        return result
    }
    
    func getVolumeLabel() -> String {
        do {
            let rootFiles = try getDirectory(name: "\\").filter { (value: FileImage) -> Bool in
                return value.isVolumeLabel() && !value.isSystem()
            }
            if (rootFiles.count > 0) {
                return rootFiles[0].getFullName()
            }
        } catch {
        }
        
        return getString(start: 43, length: 11)
    }
    
    func allowableCharacterInFilename(char: UInt8) -> Bool {
        return ((char >= 48 && char <= 57) ||
            (char >= 65 && char <= 90) ||
            (char >= 97 && char <= 122) ||
            (char == 95) || (char == 35))
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
    
    func getUInt32(start: Int) -> UInt32 {
        let intBits = rawdata.withUnsafeBytes({(bytePointer: UnsafePointer<UInt8>) -> UInt32 in
            bytePointer.advanced(by: start).withMemoryRebound(to: UInt32.self, capacity: 4) { pointer in
                return pointer.pointee
            }
        })
        return UInt32(littleEndian: intBits)
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
    
    func getFatTableEntry(index: UInt16) -> UInt16 {
        var result: UInt16 = getUInt16(start: Int(addressOfFirstFat + UInt32((index * 15) / 10)))
        if (index % 2 == 0) {
            result &= 0x0FFF
        } else {
            result >>= 4
        }
        
        return result
    }
    
    func getString(start: Int, length: Int) -> String {
        return String(data: rawdata[start..<(start + length)], encoding: String.Encoding.utf8)!
    }
}
