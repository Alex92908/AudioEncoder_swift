//
//  Mp3Encoder.swift
//  recordSound
//
//  Created by AlexZhu on 2022/1/18.
//  Copyright © 2022 ZWTech. All rights reserved.
//

import UIKit

class Mp3Encoder: NSObject {
    let pcmFile: FileHandle
    let mp3File: FileHandle
    let lameClient: lame_t
    var page: Int = 0
    
    init?(pcmFilePath: String, mp3FilePath: String, sampleRate: Int32, channels: Int32, bitRate: Int32) {
        if !FileManager.default.fileExists(atPath: mp3FilePath) {
            FileManager.default.createFile(atPath: mp3FilePath, contents: nil, attributes: nil)
        }
        guard let pcmFileHandle = FileHandle(forReadingAtPath: pcmFilePath), let mp3FileHandle = FileHandle(forWritingAtPath: mp3FilePath) else {
            return nil
        }
        pcmFile = pcmFileHandle
        mp3File = mp3FileHandle
        lameClient = lame_init()
        lame_set_in_samplerate(lameClient, sampleRate)
        lame_set_out_samplerate(lameClient, sampleRate)
        lame_set_num_channels(lameClient, channels)
        lame_set_brate(lameClient, bitRate / 1000)
        lame_init_params(lameClient)
    }
    
    func encode() {
        let bufferSize = 1024 * 256
        page = 0
        readData(bufferSize: bufferSize)
    }
    
    func readData(bufferSize: Int) {
        let data = pcmFile.readData(ofLength: bufferSize)
        if data.count > 0 {
            var leftBuffer = [Int16](repeatElement(0, count: bufferSize / 2))
            var rightBuffer = [Int16](repeatElement(0, count: bufferSize / 2))
            var mp3Buffer = [UInt8](repeatElement(0, count: bufferSize))
            let bytes = [UInt8](data)
            for i in stride(from: 0, through: bytes.count - 2, by: 2) {
                if i / 2 % 2 == 0 {
                    leftBuffer[i / 2] = Int16(bytes[i]) | Int16(bytes[i + 1]) << 8
                } else {
                    rightBuffer[i / 2] = Int16(bytes[i]) | Int16(bytes[i + 1]) << 8
                }
            }
            lame_encode_buffer(lameClient, &leftBuffer, &rightBuffer, Int32(bytes.count) / 2, &mp3Buffer, Int32(bytes.count))
            mp3File.write(Data(mp3Buffer))
            leftBuffer.removeAll()
            rightBuffer.removeAll()
            mp3Buffer.removeAll()
            page += 1
        }
        if data.count < bufferSize {
            return
        }
        pcmFile.seek(toFileOffset: UInt64(bufferSize * page))
        readData(bufferSize: bufferSize)
    }
    
    deinit {
        if #available(iOS 13.0, *) {
            try? pcmFile.close()
            try? mp3File.close()
        }
        lame_close(lameClient)
    }
}
