//
//  WaveEncoder.swift
//  WaveEncoder
//
//  Created by AlexZhu on 2021/12/23.
//  Copyright © 2021 ZWTech. All rights reserved.
//

import AVFoundation
import UIKit

class WaveEncoder: NSObject {
    static func writeWavFileHeader(totalAudioLength: Int64, totalDataLength: Int64, sampleRate: Int64, channels: UInt8, byteRate: Int64) -> Data? {
        var header = [UInt8](repeating: 0, count: 44)
        header[0] = ("R" as Character).asciiValue!
        header[1] = ("I" as Character).asciiValue!
        header[2] = ("F" as Character).asciiValue!
        header[3] = ("F" as Character).asciiValue!
        // 4byte,从下个地址到文件结尾的总字节数
        header[4] = UInt8(totalDataLength & 0xFF) // file-size (equals file-size - 8)
        header[5] = UInt8((totalDataLength >> 8) & 0xFF)
        header[6] = UInt8((totalDataLength >> 16) & 0xFF)
        header[7] = UInt8((totalDataLength >> 24) & 0xFF)
        // 4byte,wav文件标志:WAVE
        header[8] = ("W" as Character).asciiValue! // Mark it as type "WAVE"
        header[9] = ("A" as Character).asciiValue!
        header[10] = ("V" as Character).asciiValue!
        header[11] = ("E" as Character).asciiValue!
        // 4byte,波形文件标志:FMT(最后一位空格符)
        header[12] = ("f" as Character).asciiValue! // Mark the format section 'fmt ' chunk
        header[13] = ("m" as Character).asciiValue!
        header[14] = ("t" as Character).asciiValue!
        header[15] = (" " as Character).asciiValue!
        // 4byte,音频属性
        header[16] = 16 // 4 bytes: size of 'fmt ' chunk, Length of format data.  Always 16
        header[17] = 0
        header[18] = 0
        header[19] = 0
        // 2byte,格式种类(1-线性pcm-WAVE_FORMAT_PCM,WAVEFORMAT_ADPCM)
        header[20] = 1 // format = 1 ,Wave type PCM
        header[21] = 0
        // 2byte,通道数
        header[22] = UInt8(channels) // channels
        header[23] = 0
        // 4byte,采样率
        header[24] = UInt8(sampleRate & 0xFF)
        header[25] = UInt8((sampleRate >> 8) & 0xFF)
        header[26] = UInt8((sampleRate >> 16) & 0xFF)
        header[27] = UInt8((sampleRate >> 24) & 0xFF)
        // 4byte 传输速率,Byte率=采样频率*音频通道数*每次采样得到的样本位数/8，00005622H，也就是22050Byte/s=11025*1*16/8。
        header[28] = UInt8(byteRate & 0xFF)
        header[29] = UInt8((byteRate >> 8) & 0xFF)
        header[30] = UInt8((byteRate >> 16) & 0xFF)
        header[31] = UInt8((byteRate >> 24) & 0xFF)
        // 2byte   一个采样多声道数据块大小,块对齐=通道数*每次采样得到的样本位数/8，0002H，也就是2=1*16/8
        header[32] = UInt8(channels * 16 / 8)
        header[33] = 0
        // 2byte,采样精度-PCM位宽
        header[34] = 16 // bits per sample
        header[35] = 0
        // 4byte,数据标志:data
        header[36] = ("d" as Character).asciiValue! // "data" marker
        header[37] = ("a" as Character).asciiValue!
        header[38] = ("t" as Character).asciiValue!
        header[39] = ("a" as Character).asciiValue!
        // 4byte,从下个地址到文件结尾的总字节数，即除了wav header以外的pcm data length（纯音频数据）
        header[40] = UInt8(totalAudioLength & 0xFF) // data-size (equals file-size - 44).
        header[41] = UInt8((totalAudioLength >> 8) & 0xFF)
        header[42] = UInt8((totalAudioLength >> 16) & 0xFF)
        header[43] = UInt8((totalAudioLength >> 24) & 0xFF)
        return Data(bytes: &header, count: 44)
    }
}
