import CoreAudio
import AudioToolbox
import Foundation

struct AudioInputDevice: Identifiable, Equatable {
    let id: AudioDeviceID
    let uid: String
    let name: String
    let isBuiltIn: Bool
}

enum InputDeviceManager {

    static func availableInputDevices() -> [AudioInputDevice] {
        var propAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &propAddr, 0, nil, &dataSize
        ) == noErr else { return [] }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &propAddr, 0, nil, &dataSize, &deviceIDs
        ) == noErr else { return [] }

        var result: [AudioInputDevice] = []

        for devID in deviceIDs {
            // Check input channels
            var streamAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )

            var streamSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(devID, &streamAddr, 0, nil, &streamSize) == noErr else { continue }

            let bufferListPtr = UnsafeMutableRawPointer.allocate(
                byteCount: Int(streamSize),
                alignment: MemoryLayout<AudioBufferList>.alignment
            )
            defer { bufferListPtr.deallocate() }

            guard AudioObjectGetPropertyData(devID, &streamAddr, 0, nil, &streamSize, bufferListPtr) == noErr else { continue }

            let bufferList = bufferListPtr.assumingMemoryBound(to: AudioBufferList.self).pointee
            guard bufferList.mNumberBuffers > 0 else { continue }

            let buffers = UnsafeMutableAudioBufferListPointer(
                bufferListPtr.assumingMemoryBound(to: AudioBufferList.self)
            )
            let inputChannels = buffers.reduce(0) { $0 + Int($1.mNumberChannels) }
            guard inputChannels > 0 else { continue }

            // Device name
            var nameAddr = AudioObjectPropertyAddress(
                mSelector: kAudioObjectPropertyName,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var name: CFString = "" as CFString
            var nameSize = UInt32(MemoryLayout<CFString>.size)
            AudioObjectGetPropertyData(devID, &nameAddr, 0, nil, &nameSize, &name)

            // Device UID
            var uidAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var uid: CFString = "" as CFString
            var uidSize = UInt32(MemoryLayout<CFString>.size)
            AudioObjectGetPropertyData(devID, &uidAddr, 0, nil, &uidSize, &uid)

            // Transport type
            var transportAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyTransportType,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var transport: UInt32 = 0
            var transportSize = UInt32(MemoryLayout<UInt32>.size)
            AudioObjectGetPropertyData(devID, &transportAddr, 0, nil, &transportSize, &transport)

            let uidStr = uid as String
            let isBuiltIn = transport == kAudioDeviceTransportTypeBuiltIn
                || uidStr.lowercased().contains("builtin")

            result.append(AudioInputDevice(
                id: devID,
                uid: uidStr,
                name: name as String,
                isBuiltIn: isBuiltIn
            ))
        }

        // Built-in first, then sorted by name
        return result.sorted { a, b in
            if a.isBuiltIn != b.isBuiltIn { return a.isBuiltIn }
            return a.name < b.name
        }
    }

    static func builtInMicrophone() -> AudioInputDevice? {
        availableInputDevices().first(where: \.isBuiltIn)
    }

    static func device(forUID uid: String) -> AudioInputDevice? {
        availableInputDevices().first(where: { $0.uid == uid })
    }
}
