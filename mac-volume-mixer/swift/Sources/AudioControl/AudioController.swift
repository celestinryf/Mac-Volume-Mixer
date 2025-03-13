import Foundation
import CoreAudio
import AVFoundation

enum AudioControlError: Error {
    case couldNotGetDevices
    case couldNotGetApplications
    case volumeControlFailed
}

class AudioController {
    // Structure to hold audio application information
    struct AudioApp: Codable {
        let name: String
        let bundleId: String
        let pid: Int
        var volume: Float
    }
    
    // Get all applications currently playing audio
    func getAudioApps() throws -> [AudioApp] {
        var audioApps = [AudioApp]()
        
        // Get all audio devices
        var propertySize: UInt32 = 0
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize
        )
        
        guard status == noErr else {
            throw AudioControlError.couldNotGetDevices
        }
        
        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceIDs
        )
        
        guard status == noErr else {
            throw AudioControlError.couldNotGetDevices
        }
        
        // For each device, get processes that are playing audio
        for deviceID in deviceIDs {
            // Get output streams
            propertyAddress.mSelector = kAudioDevicePropertyStreams
            propertyAddress.mScope = kAudioDevicePropertyScopeOutput
            
            var streamSize: UInt32 = 0
            status = AudioObjectGetPropertyDataSize(
                deviceID,
                &propertyAddress,
                0,
                nil,
                &streamSize
            )
            
            if status == noErr && streamSize > 0 {
                // Get process PIDs for this device
                propertyAddress.mSelector = kAudioDevicePropertyProcessIDs
                
                var processSize: UInt32 = 0
                status = AudioObjectGetPropertyDataSize(
                    deviceID,
                    &propertyAddress,
                    0,
                    nil,
                    &processSize
                )
                
                if status == noErr && processSize > 0 {
                    let processCount = Int(processSize) / MemoryLayout<pid_t>.size
                    var processPIDs = [pid_t](repeating: 0, count: processCount)
                    
                    status = AudioObjectGetPropertyData(
                        deviceID,
                        &propertyAddress,
                        0,
                        nil,
                        &processSize,
                        &processPIDs
                    )
                    
                    if status == noErr {
                        // For each process, get app information and volume
                        for pid in processPIDs {
                            if let appInfo = getApplicationInfo(forPID: pid) {
                                let volume = getApplicationVolume(forPID: pid) ?? 1.0
                                let app = AudioApp(
                                    name: appInfo.name,
                                    bundleId: appInfo.bundleId,
                                    pid: pid,
                                    volume: volume
                                )
                                
                                // Only add if not already in list
                                if !audioApps.contains(where: { $0.pid == pid }) {
                                    audioApps.append(app)
                                }
                            }
                        }
                    }
                }
            }
        }
        
        return audioApps
    }
    
    // Set volume for a specific application by PID
    func setAppVolume(pid: Int, volume: Float) throws -> Bool {
        // Get the audio device
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var deviceID: AudioDeviceID = 0
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        var status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceID
        )
        
        guard status == noErr else {
            throw AudioControlError.volumeControlFailed
        }
        
        // Set volume for the process
        propertyAddress.mSelector = kAudioDevicePropertyVolumeScalarForProcessID
        propertyAddress.mScope = kAudioDevicePropertyScopeOutput
        
        var volumeAndPID = [Float(volume), Float(pid)]
        propertySize = UInt32(MemoryLayout<Float>.size * 2)
        
        status = AudioObjectSetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            propertySize,
            &volumeAndPID
        )
        
        return status == noErr
    }
    
    // Get application info from PID
    private func getApplicationInfo(forPID pid: pid_t) -> (name: String, bundleId: String)? {
        // Get process information
        guard let app = NSRunningApplication(processIdentifier: pid) else {
            return nil
        }
        
        return (
            name: app.localizedName ?? "Unknown App",
            bundleId: app
                .bundleIdentifier ?? "unknown.bundleid"
        )
    }
    
    // Get current volume for an application
    private func getApplicationVolume(forPID pid: pid_t) -> Float? {
        // Get the audio device
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var deviceID: AudioDeviceID = 0
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        var status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceID
        )
        
        guard status == noErr else {
            return nil
        }
        
        // Get volume for the process
        propertyAddress.mSelector = kAudioDevicePropertyVolumeScalarForProcessID
        propertyAddress.mScope = kAudioDevicePropertyScopeOutput
        
        var volumeScalar: Float = 0.0
        propertySize = UInt32(MemoryLayout<Float>.size)
        
        // Need to pass the PID along with the request
        var pidValue = pid
        
        status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            UInt32(MemoryLayout<pid_t>.size),
            &pidValue,
            &propertySize,
            &volumeScalar
        )
        
        return status == noErr ? volumeScalar : nil
    }
}