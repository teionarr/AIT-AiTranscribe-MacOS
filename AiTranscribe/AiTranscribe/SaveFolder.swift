/*
 SaveFolder.swift
 ================

 Where transcripts and summaries are written. The user picks a folder via
 "Choose Save Folder…"; the path is persisted in UserDefaults. If unset we
 default to ~/Documents/AiTranscribe.
 */

import Foundation

enum SaveFolder {
    private static let defaultsKey = "saveFolderPath"

    /// Folder name used under ~/Documents when no folder has been chosen.
    static let appFolderName = "AiTranscribe"

    /// The currently configured save folder (chosen folder, else the default).
    static var url: URL {
        if let path = UserDefaults.standard.string(forKey: defaultsKey), !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return defaultURL
    }

    /// ~/Documents/AiTranscribe
    static var defaultURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents", isDirectory: true)
        return documents.appendingPathComponent(appFolderName, isDirectory: true)
    }

    /// Persist a user-chosen folder.
    static func set(_ folder: URL) {
        UserDefaults.standard.set(folder.path, forKey: defaultsKey)
    }

    /// Ensure the save folder exists on disk; returns it, or nil on failure.
    @discardableResult
    static func ensureExists() -> URL? {
        let dir = url
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        } catch {
            print("SaveFolder: failed to create \(dir.path): \(error)")
            return nil
        }
    }
}
