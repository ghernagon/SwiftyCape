import Foundation

enum CapeConverterError: LocalizedError {
    case emptyInputFolder
    case emptyInfFile
    case emptyOutputPath
    case executionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .emptyInputFolder:
            return "Please select an input folder"
        case .emptyInfFile:
            return "Please select an INF file"
        case .emptyOutputPath:
            return "Please select an output path"
        case .executionFailed(let message):
            return "Conversion failed: \(message)"
        }
    }
}

struct CapeConverter {
    static func convert(
        inputFolder: String,
        infFile: String,
        outputPath: String
    ) async -> Result<String, CapeConverterError> {
        // Validation
        guard !inputFolder.isEmpty else { return .failure(.emptyInputFolder) }
        guard !infFile.isEmpty else { return .failure(.emptyInfFile) }
        guard !outputPath.isEmpty else { return .failure(.emptyOutputPath) }
        
        // Get the Python path from pyenv
        let pythonPath = NSHomeDirectory() + "/.pyenv/versions/cursors_env/bin/python"
        
        // Get the Capeify module path
        let capeifyPath = NSHomeDirectory() + "/Developer/cursors/capeify"
        
        // Build the command - execute Python directly, no shell needed
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.currentDirectoryURL = URL(fileURLWithPath: capeifyPath)
        
        // Set environment variables for ImageMagick
        var environment = ProcessInfo.processInfo.environment
        environment["MAGICK_HOME"] = "/opt/homebrew/opt/imagemagick"
        environment["PATH"] = "/opt/homebrew/opt/imagemagick/bin:" + (environment["PATH"] ?? "")
        environment["DYLD_LIBRARY_PATH"] = "/opt/homebrew/opt/imagemagick/lib:" + (environment["DYLD_LIBRARY_PATH"] ?? "")
        process.environment = environment
        
        // Python module arguments
        process.arguments = [
            "-m", "Capeify.main", "convert",
            "--path", inputFolder,
            "--inf-file", infFile,
            "--out", outputPath
        ]
        
        // Create pipes for output
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            
            let output = String(data: outputData, encoding: .utf8) ?? ""
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
            let combinedOutput = output + (errorOutput.isEmpty ? "" : "\n" + errorOutput)
            
            if process.terminationStatus == 0 {
                // Always show output for success too
                if !combinedOutput.isEmpty {
                    return .success(combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                return .success("Conversion completed successfully!")
            } else {
                let errorMessage = combinedOutput.isEmpty ? "Unknown error (exit code: \(process.terminationStatus))" : combinedOutput
                return .failure(.executionFailed(errorMessage.trimmingCharacters(in: .whitespacesAndNewlines)))
            }
        } catch {
            return .failure(.executionFailed(error.localizedDescription))
        }
    }
}
