//
//  FileOperationsTests.swift
//
//  Created on 10.10.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import Foundation
import Testing
@testable import WardAxis

@Suite("File operation extensions")
final class FileOperationsTests {
    private let root: URL
    
    init() throws {
        root = URL.temporaryDirectory.appending(path: "FileOperationsTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    
    /// Runs after every test, also when one throws or a #require fails.
    deinit {
        root.remove()
    }
    
    private func write(_ text: String, to name: String) throws -> URL {
        let url = root.appending(path: name)
        try Data(text.utf8).write(to: url)
        return url
    }
    
    private func read(_ url: URL) throws -> String {
        try String(decoding: Data(contentsOf: url), as: UTF8.self)
    }
    
    // MARK: - FileManager+Copy
    
    @Test("secureCopyItem replaces an existing destination")
    func copyOverwrites() throws {
        let source = try write("new", to: "source.txt")
        let destination = try write("old", to: "destination.txt")
        
        try FileManager.default.secureCopyItem(at: source, to: destination)
        
        #expect(try read(destination) == "new")
        #expect(FileManager.default.fileExists(atPath: source.path))
    }
    
    @Test("secureSafeMoveItem replaces an existing destination and removes the source")
    func moveOverwrites() throws {
        let source = try write("new", to: "source.txt")
        let destination = try write("old", to: "destination.txt")
        
        #expect(FileManager.default.secureSafeMoveItem(at: source, to: destination))
        
        #expect(try read(destination) == "new")
        #expect(!FileManager.default.fileExists(atPath: source.path))
    }
    
    @Test("secureSafeCopyItem returns false for a missing source")
    func copyMissingSourceFails() {
        let missing = root.appending(path: "missing.txt")
        #expect(!FileManager.default.secureSafeCopyItem(at: missing, to: root.appending(path: "out.txt")))
    }
    
    @Test("A failed copy or move keeps the existing destination")
    func failedReplaceKeepsDestination() throws {
        let missing = root.appending(path: "missing.txt")
        let destination = try write("old", to: "destination.txt")
        
        #expect(!FileManager.default.secureSafeCopyItem(at: missing, to: destination))
        #expect(!FileManager.default.secureSafeMoveItem(at: missing, to: destination))
        
        #expect(try read(destination) == "old")
    }
    
    @Test("secureCopyItem gives a replaced destination the source's permissions")
    func copyKeepsSourcePermissions() throws {
        let source = try write("new", to: "source.sh")
        let destination = try write("old", to: "destination.sh")
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: source.path)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
        
        try FileManager.default.secureCopyItem(at: source, to: destination)
        
        let attributes = try FileManager.default.attributesOfItem(atPath: destination.path)
        #expect(attributes[.posixPermissions] as? Int == 0o755)
    }
    
    @Test("secureCopyItem and secureMoveItem replace a symbolic link whose target is missing")
    func replaceDanglingSymlink() throws {
        let copyLink = root.appending(path: "copy-link")
        let moveLink = root.appending(path: "move-link")
        try FileManager.default.createSymbolicLink(at: copyLink, withDestinationURL: root.appending(path: "gone"))
        try FileManager.default.createSymbolicLink(at: moveLink, withDestinationURL: root.appending(path: "gone"))
        let copySource = try write("copied", to: "copy-source.txt")
        let moveSource = try write("moved", to: "move-source.txt")
        
        try FileManager.default.secureCopyItem(at: copySource, to: copyLink)
        try FileManager.default.secureMoveItem(at: moveSource, to: moveLink)
        
        #expect(try read(copyLink) == "copied")
        #expect(try read(moveLink) == "moved")
        #expect((try? FileManager.default.destinationOfSymbolicLink(atPath: copyLink.path)) == nil)
        #expect(!FileManager.default.fileExists(atPath: moveSource.path))
    }
    
    // MARK: - URL+Create / URL+Remove
    
    @Test("createDir fails when a file is at the path")
    func createDirOverFileFails() throws {
        let file = try write("x", to: "cache")
        
        #expect(!file.createDir())
        #expect(!file.isFolder)
    }
    
    @Test("remove deletes a symbolic link whose target is missing")
    func removeDanglingSymlink() throws {
        let link = root.appending(path: "link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: root.appending(path: "gone"))
        
        #expect(link.remove())
        #expect((try? FileManager.default.destinationOfSymbolicLink(atPath: link.path)) == nil)
    }
    
    @Test("createDir creates intermediates and keeps an existing folder")
    func createDirKeepsContents() throws {
        let folder = root.appending(path: "a/b/c")
        #expect(folder.createDir())
        #expect(folder.isFolder)
        
        let file = folder.appending(path: "keep.txt")
        try Data("x".utf8).write(to: file)
        #expect(folder.createDir())
        #expect(FileManager.default.fileExists(atPath: file.path))
    }
    
    @Test("remove deletes an existing item and returns false for a missing one")
    func removeItem() throws {
        let file = try write("x", to: "file.txt")
        #expect(file.remove())
        #expect(!FileManager.default.fileExists(atPath: file.path))
        #expect(!file.remove())
    }
    
    // MARK: - URL+List
    
    @Test("recursiveFileList returns nested regular files and skips hidden ones")
    func recursiveList() throws {
        _ = try write("1", to: "top.txt")
        _ = try write("h", to: ".hidden")
        let nested = root.appending(path: "sub")
        #expect(nested.createDir())
        try Data("2".utf8).write(to: nested.appending(path: "inner.txt"))
        
        let names = Set(root.recursiveFileList.map(\.lastPathComponent))
        
        #expect(names == ["top.txt", "inner.txt"])
    }
    
    @Test("contents lists direct children and honours skipsHiddenFiles")
    func directContents() throws {
        _ = try write("1", to: "visible.txt")
        _ = try write("h", to: ".hidden")
        #expect(root.appending(path: "sub").createDir())
        
        let visible = Set(root.contents()?.map(\.lastPathComponent) ?? [])
        let all = Set(root.contents(skipsHiddenFiles: false)?.map(\.lastPathComponent) ?? [])
        
        #expect(visible == ["visible.txt", "sub"])
        #expect(all == ["visible.txt", "sub", ".hidden"])
    }
    
    @Test("fileNameList returns the names of the children of the listed folder")
    func fileNames() throws {
        _ = try write("1", to: "a.txt")
        _ = try write("h", to: ".hidden")
        
        #expect(Set(root.fileNameList ?? []) == ["a.txt", ".hidden"])
    }
}
