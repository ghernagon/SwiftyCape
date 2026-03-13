import Foundation

enum CapeConverterError: LocalizedError {
    case emptyInputFolder
    case emptyInfFile
    case emptyOutputPath
    case conversionFailed(String)
    case executableNotFound
    
    var errorDescription: String? {
        switch self {
        case .emptyInputFolder:
            return "Please select an input folder"
        case .emptyInfFile:
            return "Please select an INF file"
        case .emptyOutputPath:
            return "Please select an output path"
        case .conversionFailed(let message):
            return message
        case .executableNotFound:
            return "Capeify executable not found. Please reinstall the app."
        }
    }
}

struct CapeConverter {
    // Path to the bundled executable
    private static let executablePath: String = {
        // First try to find in the app bundle's MacOS folder
        if let bundlePath = Bundle.main.path(forAuxiliaryExecutable: "CapeifyCLI") {
            return bundlePath
        }
        // Fallback to a known location during development
        return "~/Developer/cursors/capeify/dist/CapeifyCLI"
    }()
    
    static func convert(
        inputFolder: String,
        infFile: String,
        outputPath: String
    ) async -> Result<String, CapeConverterError> {
        // Validation
        guard !inputFolder.isEmpty else { return .failure(.emptyInputFolder) }
        guard !infFile.isEmpty else { return .failure(.emptyInfFile) }
        guard !outputPath.isEmpty else { return .failure(.emptyOutputPath) }
        
        // Check if executable exists
        guard FileManager.default.fileExists(atPath: executablePath) else {
            return .failure(.executableNotFound)
        }
        
        // Check if ImageMagick is installed
        let imagemagickCheck = Process()
        imagemagickCheck.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/convert")
        imagemagickCheck.arguments = ["--version"]
        
        do {
            try imagemagickCheck.run()
            imagemagickCheck.waitUntilExit()
            if imagemagickCheck.terminationStatus != 0 {
                return .failure(.conversionFailed("ImageMagick is not installed. Please run: brew install imagemagick"))
            }
        } catch {
            return .failure(.conversionFailed("ImageMagick is not installed. Please run: brew install imagemagick"))
        }
        
        return await withCheckedContinuation { continuation in
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            
            // Set up environment to find ImageMagick libraries
            var env = ProcessInfo.processInfo.environment
            // Add ImageMagick library path
            let imagemagickPath = "/opt/homebrew/opt/imagemagick/lib"
            if let existingPath = env["DYLD_LIBRARY_PATH"] {
                env["DYLD_LIBRARY_PATH"] = "\(imagemagickPath):\(existingPath)"
            } else {
                env["DYLD_LIBRARY_PATH"] = imagemagickPath
            }
            // Also add to PATH for the executable
            if let existingPath = env["PATH"] {
                env["PATH"] = "\(imagemagickPath):\(existingPath)"
            }
            process.environment = env
            
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = [
                "convert",
                "--path", inputFolder,
                "--inf-file", infFile,
                "--out", outputPath
            ]
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                
                let output = String(data: outputData, encoding: .utf8) ?? ""
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                
                if process.terminationStatus == 0 {
                    continuation.resume(returning: .success(output))
                } else {
                    let errorMessage = errorOutput.isEmpty ? output : errorOutput
                    continuation.resume(returning: .failure(.conversionFailed(errorMessage)))
                }
            } catch {
                continuation.resume(returning: .failure(.conversionFailed(error.localizedDescription)))
            }
        }
    }
}
