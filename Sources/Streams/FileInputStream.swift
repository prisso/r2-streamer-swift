//
//  SeekableFileInputStream.swift
//  R2Streamer
//
//  Created by Olivier Körner on 15/01/2017.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation

/// FileInputStream errors
///
/// - read: An error while reading data from the fileHandle occured.
/// - fileHandleInitialisation: An error occured while initializing the fileHandle
/// - fileHandle: The fileHandle is not set or invalid.
public enum FileInputStreamError: Error {
    case read
    case fileHandleInitialisation
    case fileHandleUnset
}

/// <#Description#>
open class FileInputStream: SeekableInputStream {
    /// The path to the file opened by the stream
    private var filePath: String
    /// The file handle (== fd) of the file at path `filePath`
    private var fileHandle: FileHandle?

    ///
    private var _streamError: Error?
    override open var streamError: Error? {
        get {
            return _streamError
        }
    }

    /// The status of the fileHandle
    private var _streamStatus: Stream.Status = .notOpen
    override open var streamStatus: Stream.Status {
        get {
            return _streamStatus
        }
    }

    /// The size attribute of the file at `filePath`
    private var _length: UInt64
    override public var length: UInt64 {
        get {
            return _length
        }
    }

    /// Current position in the stream.
    override public var offset: UInt64 {
        get {
            return fileHandle?.offsetInFile ?? 0
        }
    }

    /// True when the current offset is not arrived the the end of the stream.
    override open var hasBytesAvailable: Bool {
        get {
            return offset < _length
        }
    }

    // MARK: - Public methods.

    /// Initialize the object and the input stream meta data for file at 
    /// `fileAtPath`.
    public init?(fileAtPath: String) {
        let attributes: [FileAttributeKey : Any]

        // Does the file `atFilePath` exists
        guard FileManager.default.fileExists(atPath: fileAtPath) else {
            NSLog("File not found: \(fileAtPath)")
            return nil
        }
        filePath = fileAtPath
        // Try to retrieve attributes of `fileAtPath`
        do {
            attributes = try FileManager.default.attributesOfItem(atPath: filePath)
        } catch {
            NSLog("Exception retrieving attrs for item at path \(filePath) (\(error)) ")
            return nil
        }
        // Verify the size attribute of the file at `fileAtPath`
        guard let fileSize = attributes[FileAttributeKey.size] as? UInt64 else {
            NSLog("Error accessing size attribute")
            return nil
        }
        _length = fileSize
        super.init()
    }

    // MARK: - Open methods.

    /// Open a file handle (<=>fd) for file at path `filePath`.
    override open func open() {
        fileHandle = FileHandle(forReadingAtPath: filePath)
        _streamStatus = .open
    }

    /// Close the file handle.
    override open func close() {
        guard let fileHandle = fileHandle else {
            return
        }
        fileHandle.closeFile()
        _streamStatus = .closed
    }

    // TODO: to implement or delete ?
    override open func getBuffer(_ buffer: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
                                 length len: UnsafeMutablePointer<Int>) -> Bool {
        return false
    }


    // FIXME: Shouldn't we have smaller read in a loop?
    /// Read up to `maxLength` bytes from `fileHandle` and write them into `buffer`.
    ///
    /// - Parameters:
    ///   - buffer: The destination buffer.
    ///   - maxLength: The maximum number of bytes read.
    /// - Returns: Return the number of bytes read.
    override open func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength: Int) -> Int {
        let readError = -1
        let data: Data

        guard let fileHandle = fileHandle else {
            return readError
        }
        data = fileHandle.readData(ofLength: maxLength)
        if data.count < maxLength {
            _streamStatus = .atEnd
        }
        data.copyBytes(to: buffer, count: data.count)
        return Int(data.count)
    }

    /// Moves the file pointer to the specified offset within the file.
    ///
    /// - Parameters:
    ///   - offset: The offset.
    ///   - whence: From which position.
    override public func seek(offset: Int64, whence: SeekWhence) {
        assert(whence == .startOfFile, "Only seek from start of stream is supported for now.")
        assert(offset >= 0, "Since only seek from start of stream if supported, offset must be >= 0")
        
        NSLog("FileInputStream \(filePath) offset \(offset)")
        guard let fileHandle = fileHandle else {
            _streamStatus = .error
            _streamError = FileInputStreamError.fileHandleUnset
            return
        }
        fileHandle.seek(toFileOffset: UInt64(offset))
    }
}
