import SwiftUI
import AppKit

struct ContentView: View {
    @State private var infFile: String = ""
    @State private var outputPath: String = ""
    @State private var isConverting: Bool = false
    @State private var statusMessage: String = ""
    @State private var showError: Bool = false
    @State private var showSuccess: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("SwiftyCape")
                .font(.system(size: 28, weight: .bold))
                .padding(.top, 20)
            
            // INF File
            HStack {
                Text("INF File:")
                    .frame(width: 100, alignment: .leading)
                TextField("Select .inf file...", text: $infFile)
                    .textFieldStyle(.roundedBorder)
                Button("Browse") {
                    selectInfFile()
                }
            }
            .padding(.horizontal)
            
            // Output Path
            HStack {
                Text("Output:")
                    .frame(width: 100, alignment: .leading)
                TextField("Save as .cape...", text: $outputPath)
                    .textFieldStyle(.roundedBorder)
                Button("Browse") {
                    selectOutputPath()
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Status Message - TextEditor para poder seleccionar y copiar
            if !statusMessage.isEmpty {
                TextEditor(text: .constant(statusMessage))
                    .font(.system(size: 12, design: .monospaced))
                    .frame(maxHeight: 100)
                    .foregroundColor(showError ? .red : (showSuccess ? .green : .primary))
                    .background(Color(white: 0.95))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .scrollContentBackground(.hidden)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(showError ? Color.red.opacity(0.3) : (showSuccess ? Color.green.opacity(0.3) : Color.gray.opacity(0.3)), lineWidth: 1)
                    )
            }
            
            // Convert Button
            Button(action: convert) {
                HStack {
                    if isConverting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                    Text(isConverting ? "Converting..." : "Convert")
                        .frame(width: 120)
                }
                .frame(width: 200)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isConverting || !canConvert())
            .padding(.bottom, 20)
        }
        .frame(minWidth: 500, minHeight: 280)
    }
    
    private func canConvert() -> Bool {
        !infFile.isEmpty && !outputPath.isEmpty
    }
    
    private func selectInfFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.init(filenameExtension: "inf")!]
        panel.message = "Select .inf file"
        
        if panel.runModal() == .OK {
            infFile = panel.url?.path ?? ""
        }
    }
    
    private func selectOutputPath() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "cape")!]
        panel.nameFieldStringValue = "output.cape"
        panel.message = "Save .cape file"
        
        if panel.runModal() == .OK {
            outputPath = panel.url?.path ?? ""
        }
    }
    
    private func convert() {
        isConverting = true
        statusMessage = ""
        showError = false
        showSuccess = false
        
        // Derive input folder from INF file path (parent directory)
        let inputFolder = (infFile as NSString).deletingLastPathComponent
        let infFileName = (infFile as NSString).lastPathComponent
        
        Task {
            let result = await CapeConverter.convert(
                inputFolder: inputFolder,
                infFile: infFileName,
                outputPath: outputPath
            )
            
            await MainActor.run {
                isConverting = false
                switch result {
                case .success(let message):
                    statusMessage = message
                    showSuccess = true
                case .failure(let error):
                    statusMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}
