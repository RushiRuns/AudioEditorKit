//
//  ContentView.swift
//  AudioEditorExample
//
//  Created by 秋星桥 on 5/1/25.
//

import AudioEditorKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var isShowingFilePicker = false
    @State private var selectedURL: URL?

    var body: some View {
        NavigationStack {
            List {
                Section("Editor") {
                    Button("Import...") {
                        isShowingFilePicker = true
                    }
                }

                Section("Test Music") {
                    NavigationLink("Image Film 046") {
                        EditorController(fileName: "imagefilm-046.mp3")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Audio Editor Example")
            .sheet(isPresented: $isShowingFilePicker) {
                DocumentPicker(selectedURL: $selectedURL)
            }
            .onChange(of: selectedURL) { newValue in
                if let url = newValue {
                    handleSelectedFile(url)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func handleSelectedFile(_ url: URL) {
        selectedURL = nil
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = url.lastPathComponent
        let tempURL = tempDir.appendingPathComponent(fileName)

        do {
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }
            try FileManager.default.copyItem(at: url, to: tempURL)

            let viewController = UIApplication.shared.windows.first?.rootViewController
            let preVC = PrePresentationViewController(url: tempURL)
            viewController?.present(preVC, animated: true)
        } catch {
            print(error)
        }
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedURL: URL?

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let supportedTypes: [UTType] = [.audio, .mp3, .wav, .mpeg4Audio]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_: UIDocumentPickerViewController, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker

        init(_ parent: DocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.selectedURL = url
        }
    }
}
