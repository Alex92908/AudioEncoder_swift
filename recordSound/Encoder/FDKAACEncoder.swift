//
//  FDKAACEncoder.swift
//  recordSound
//
//  Created by AlexZhu on 2022/1/19.
//  Copyright © 2022 ZWTech. All rights reserved.
//

import UIKit

/// encoder moudle
struct AACEncModule: OptionSet {
    let rawValue: UInt8

    init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    /// -DEFAULT:  full enc moudles
    static let `default`: AACEncModule = .init(rawValue: 0)

    /// - AAC: Allocate AAC Core Encoder module.
    static let aac: AACEncModule = .init(rawValue: 1 << 0)

    /// - SBR: Allocate Spectral Band Replication module.
    static let sbr: AACEncModule = .init(rawValue: 1 << 1)

    /// - PS: Allocate Parametric Stereo module.
    static let ps: AACEncModule = .init(rawValue: 1 << 2)

    /// - MD: Allocate Meta Data module within AAC encoder.
    static let md: AACEncModule = .init(rawValue: 1 << 4)
}

struct AACEncChannel: OptionSet {
    let rawValue: UInt
    init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    static let `default`: AACEncChannel = .init(rawValue: 1)

    static func minChannel(rawValue: UInt) -> AACEncChannel {
        return AACEncChannel(rawValue: rawValue << 8)
    }

    static func maxChannel(rawValue: UInt) -> AACEncChannel {
        return AACEncChannel(rawValue: rawValue)
    }
}

/// VBR moudle
struct AACEncBitrateMode: OptionSet {
    let rawValue: UInt8

    init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    /// -DEFAULT:  Constant bitrate, use bitrate according
    static let `default`: AACEncBitrateMode = .init(rawValue: 0)

    /// - veryLow: Variable bitrate mode, \ref vbrmode "very low bitrate".
    static let veryLow: AACEncBitrateMode = .init(rawValue: 1)

    /// - low: Variable bitrate mode, \ref vbrmode "low bitrate".
    static let low: AACEncBitrateMode = .init(rawValue: 2)

    /// - medium:  Variable bitrate mode, \ref vbrmode "medium bitrate".
    static let medium: AACEncBitrateMode = .init(rawValue: 3)

    /// - high:  Variable bitrate mode, \ref vbrmode "high bitrate".
    static let high: AACEncBitrateMode = .init(rawValue: 4)

    /// - veryHigh:  Variable bitrate mode, \ref vbrmode "very high bitrate".
    static let veryHigh: AACEncBitrateMode = .init(rawValue: 5)
}

class FDKAACEncoder: NSObject {
    private let pcmFile: FileHandle
    private let aacFile: FileHandle
    private var aacEncoder: HANDLE_AACENCODER?
    private var page: UInt32 = 0
    private var channels: AACEncChannel = .default
    private var frameSize: UINT = 0
    private lazy var encInfo: AACENC_InfoStruct = .init()

    init?(pcmFilePath: String, aacFilePath: String, sampleRate: Int32, channels: AACEncChannel = .default, bitRate: Int32, encMoudle: AACEncModule = .default, aot: AUDIO_OBJECT_TYPE = AOT_AAC_LC, transtype: TRANSPORT_TYPE = TT_MP4_ADTS, isEldSbrMode: Bool = false, vbr: AACEncBitrateMode = .default, afterburner: Int = 0) {
        if !FileManager.default.fileExists(atPath: aacFilePath) {
            FileManager.default.createFile(atPath: aacFilePath, contents: nil, attributes: nil)
        }
        guard let pcmFileHandle = FileHandle(forReadingAtPath: pcmFilePath), let aacFileHandle = FileHandle(forWritingAtPath: aacFilePath) else {
            return nil
        }
        pcmFile = pcmFileHandle
        aacFile = aacFileHandle
        self.channels = channels
        super.init()
        if aacEncOpen(&aacEncoder, UINT(encMoudle.rawValue), UINT(channels.rawValue)) != AACENC_OK {
            return nil
        }
        if aacEncoder_SetParam(aacEncoder, AACENC_AOT, UINT(aot.rawValue)) != AACENC_OK {
            return nil
        }
        if isEldSbrMode, aot == AOT_ER_AAC_ELD {
            if aacEncoder_SetParam(aacEncoder, AACENC_SBR_MODE, 1) != AACENC_OK {
                return nil
            }
        }

        if aacEncoder_SetParam(aacEncoder, AACENC_SAMPLERATE, UINT(sampleRate)) != AACENC_OK {
            return nil
        }
        if aacEncoder_SetParam(aacEncoder, AACENC_CHANNELMODE, UINT(getChannelMode(nChannels: channels.rawValue).rawValue)) != AACENC_OK {
            return nil
        }
        if aacEncoder_SetParam(aacEncoder, AACENC_CHANNELORDER, 1) != AACENC_OK {
            return nil
        }

        if vbr != .default {
            if aacEncoder_SetParam(aacEncoder, AACENC_BITRATEMODE, UINT(vbr.rawValue)) != AACENC_OK {
                return nil
            }
        } else {
            if aacEncoder_SetParam(aacEncoder, AACENC_BITRATE, UINT(bitRate)) != AACENC_OK {
                return nil
            }
        }

        if aacEncoder_SetParam(aacEncoder, AACENC_TRANSMUX, UINT(transtype.rawValue)) != AACENC_OK {
            return nil
        }

        if aacEncoder_SetParam(aacEncoder, AACENC_AFTERBURNER, UINT(afterburner)) != AACENC_OK {
            return nil
        }

        if aacEncEncode(aacEncoder, nil, nil, nil, nil) != AACENC_OK {
            return nil
        }
        if aacEncInfo(aacEncoder, &encInfo) != AACENC_OK {
            return nil
        }
        frameSize = encInfo.frameLength
    }

    func getChannelMode(nChannels: UInt) -> CHANNEL_MODE {
        var chMode: CHANNEL_MODE = MODE_INVALID
        switch nChannels {
        case 1:
            chMode = MODE_1
        case 2:
            chMode = MODE_2
        case 3:
            chMode = MODE_1_2
        case 4:
            chMode = MODE_1_2_1
        case 5:
            chMode = MODE_1_2_2
        case 6:
            chMode = MODE_1_2_2_1
        case 7:
            chMode = MODE_6_1
        case 8:
            chMode = MODE_7_1_BACK
        default:
            chMode = MODE_INVALID
        }
        return chMode
    }

    func encode() {
        let input_size = UInt32(channels.rawValue) * 2 * frameSize
        page = 0
        while true {
            page += 1
            var read = 0
            let data = pcmFile.readData(ofLength: Int(input_size))
            let bytes = [UInt8](data)
            if bytes.count <= 0 {
                return
            }
            read = bytes.count
            let convert_buf: UnsafeMutableRawPointer? = UnsafeMutableRawPointer.allocate(byteCount: read, alignment: MemoryLayout<Int16>.alignment)
            var in_buf = AACENC_BufDesc()
            var out_buf = AACENC_BufDesc()
            var in_args = AACENC_InArgs()
            var out_args = AACENC_OutArgs()
            let in_identifier = Int(IN_AUDIO_DATA.rawValue)
            var in_size = 0, in_elem_size = 0
            let out_identifier = Int(OUT_BITSTREAM_DATA.rawValue)
            var out_size = 0, out_elem_size = 0

            let outbufSize = 20480
            let outbuf: UnsafeMutableRawPointer? = UnsafeMutableRawPointer.allocate(byteCount: outbufSize, alignment: MemoryLayout<UInt8>.alignment)
            var err: AACENC_ERROR?
            for i in 0 ..< read / 2 {
                convert_buf?.advanced(by: MemoryLayout<INT_PCM>.stride * i).storeBytes(of: INT_PCM(bytes[2 * i]) | INT_PCM(bytes[2 * i + 1]) << 8, as: INT_PCM.self)
            }
            in_size = bytes.count
            in_elem_size = 2

            in_args.numInSamples = INT(read <= 0 ? -1 : read / 2)
            in_buf.numBufs = 1
            let inBufPointer = UnsafeMutablePointer<UnsafeMutableRawPointer?>.allocate(capacity: 1)
            inBufPointer.pointee = convert_buf
            in_buf.bufs = inBufPointer
            let inBufferIdsPointer: UnsafeMutablePointer<INT> = UnsafeMutablePointer.allocate(capacity: 1)
            inBufferIdsPointer.pointee = INT(in_identifier)
            in_buf.bufferIdentifiers = inBufferIdsPointer
            let inBufferSizesPointer: UnsafeMutablePointer<INT> = UnsafeMutablePointer.allocate(capacity: 1)
            inBufferSizesPointer.pointee = INT(in_size)
            in_buf.bufSizes = inBufferSizesPointer
            let inBufferElSizesPointer: UnsafeMutablePointer<INT> = UnsafeMutablePointer.allocate(capacity: 1)
            inBufferElSizesPointer.pointee = INT(in_elem_size)
            in_buf.bufElSizes = inBufferElSizesPointer
            out_size = outbufSize * MemoryLayout<UInt8>.size
            out_elem_size = 1
            out_buf.numBufs = 1
            let outBufPointer = UnsafeMutablePointer<UnsafeMutableRawPointer?>.allocate(capacity: 1)
            outBufPointer.pointee = outbuf
            out_buf.bufs = outBufPointer
            let outBufferIdsPointer: UnsafeMutablePointer<INT> = UnsafeMutablePointer.allocate(capacity: 1)
            outBufferIdsPointer.pointee = INT(out_identifier)
            out_buf.bufferIdentifiers = outBufferIdsPointer
            let outBufferSizesPointer: UnsafeMutablePointer<INT> = UnsafeMutablePointer.allocate(capacity: 1)
            outBufferSizesPointer.pointee = INT(out_size)
            out_buf.bufSizes = outBufferSizesPointer
            let outBufferElSizesPointer: UnsafeMutablePointer<INT> = UnsafeMutablePointer.allocate(capacity: 1)
            outBufferElSizesPointer.pointee = INT(out_elem_size)
            out_buf.bufElSizes = outBufferElSizesPointer
            err = aacEncEncode(aacEncoder, &in_buf, &out_buf, &in_args, &out_args)

            convert_buf?.deallocate()
            inBufPointer.deallocate()
            inBufferIdsPointer.deallocate()
            inBufferElSizesPointer.deallocate()

            func freeOutBufs() {
                outbuf?.deallocate()
                outBufPointer.deallocate()
                outBufferIdsPointer.deallocate()
                outBufferElSizesPointer.deallocate()
            }

            if err != AACENC_OK {
                if err == AACENC_ENCODE_EOF {
                    break
                }
                return
            }
            if out_args.numOutBytes == 0 {
                freeOutBufs()
                pcmFile.seek(toFileOffset: UInt64(input_size * page))
                continue
            }
            var aacBuffer: [UInt8] = []
            for i in 0 ..< out_args.numOutBytes {
                if let byte = outbuf?.advanced(by: MemoryLayout<UInt8>.stride * Int(i)).load(as: UInt8.self) {
                    aacBuffer.append(byte)
                }
            }
            aacFile.write(Data(aacBuffer))
            freeOutBufs()
            pcmFile.seek(toFileOffset: UInt64(input_size * page))
        }
    }

    deinit {
        if aacEncoder != nil {
            aacEncClose(&aacEncoder)
        }
    }
}
