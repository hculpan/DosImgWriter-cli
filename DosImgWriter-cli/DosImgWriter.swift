//
//  DosImgWriter.swift
//  DosImgWriter-cli
//
//  Created by Harry Culpan on 11/17/17.
//  Copyright © 2017 Harry Culpan. All rights reserved.
//

import Foundation

enum OptionType: String {
    case inputfile = "i"
    case help = "h"
    case stats = "s"
    case extended = "x"
    case listing = "l"
    case unknown
    
    init(value: String) {
        switch value {
        case "i": self = .inputfile
        case "h": self = .help
        case "s": self = .stats
        case "x": self = .extended
        case "l": self = .listing
        default: self = .unknown
        }
    }
}

class Configuration {
    var executable: String = ""
    
    var noArguments: Bool = false
    
    var inputFile: String = ""
    
    var outputStats: Bool = false
    
    var outputExtendedStats: Bool = false
    
    var directoryListing: String = ""
    
    var help: Bool = false
}

class DosImgWriter {
    let consoleIO = ConsoleIO()
    
    func staticMode() {
        let configuration = configureFromCommandLine(arguments: CommandLine.arguments)
        
        if (configuration.help || configuration.noArguments) {
            printUsage()
        } else {
            consoleIO.writeMessage("Input file: \(configuration.inputFile)")
            let diskImage = DiskImage(imageFileName: configuration.inputFile)
            diskImage.doStuff()
            if (configuration.outputStats) { diskImage.outputDetails() }
            if (configuration.outputExtendedStats) { diskImage.outputExtendedDetails() }
            if (configuration.directoryListing != "") {
                let entries = diskImage.getDirectory(name: configuration.directoryListing)
                for entry in entries {
                    consoleIO.writeMessage(entry.getFullNameTrimmed())
                }
            }
        }
    }
    
    func printUsage() {
        let executableName = (CommandLine.arguments[0] as NSString).lastPathComponent
        
        consoleIO.writeMessage("usage:")
        consoleIO.writeMessage("\(executableName) -i input filename")
        consoleIO.writeMessage("or")
        consoleIO.writeMessage("\(executableName) -h to show usage information")
    }
    
    func configureFromCommandLine(arguments: [String]) -> Configuration {
        let argCount = arguments.count
        let done = false
        var argi = 1
        let configuration = Configuration()
        configuration.executable = arguments[0]
        configuration.noArguments = argCount < 2
        
        while (!done && argi < argCount) {
            let argument = CommandLine.arguments[argi]
            let (option, _) = getOption(String(argument[argument.index(argument.startIndex, offsetBy: 1)...]))
            switch option {
            case .listing:
                configuration.directoryListing = CommandLine.arguments[argi + 1]
                argi += 2
            case .inputfile:
                configuration.inputFile = CommandLine.arguments[argi + 1]
                argi += 2
            case .stats:
                configuration.outputStats = true
                argi += 1
            case .extended:
                configuration.outputStats = true
                configuration.outputExtendedStats = true
                argi += 1
            default:
                configuration.help = true
                argi += 1
            }
        }
        
        return configuration
    }
    
    func getOption(_ option: String) -> (option:OptionType, value: String) {
        return (OptionType(value: option), option)
    }
}
