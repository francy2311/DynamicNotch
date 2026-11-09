import AppKit
import Combine
import CoreAudio
import CoreGraphics
import Darwin

@MainActor
final class HardwareHUDMonitor: ObservableObject {

    // MARK: - Types

    enum Kind:
        Equatable {

        case volume
        case brightness
    }

    struct Presentation:
        Equatable {

        let kind:
            Kind

        let value:
            Double

        let isMuted:
            Bool

        var title:
            String {

            switch kind {

                
            case .volume:

                return isMuted
                    ? "Audio disattivato"
                    : "Volume"

            case .brightness:

                return "Luminosità"
            }
        }

        var systemImage:
            String {

            switch kind {

            case .volume:

                if isMuted || value <= 0 {

                    return "speaker.slash.fill"
                }

                if value < 0.33 {

                    return "speaker.wave.1.fill"
                }

                if value < 0.66 {

                    return "speaker.wave.2.fill"
                }

                return "speaker.wave.3.fill"

            case .brightness:

                if value < 0.33 {

                    return "sun.min.fill"
                }

                return "sun.max.fill"
            }
        }

        var percentage:
            Int {

            Int(
                (value * 100)
                    .rounded()
            )
        }
    }

    // MARK: - State

    @Published
    private(set)
    var presentation:
        Presentation?

    @Published
    private(set)
    var revision:
        UInt = 0

    private var activeKind:
        Kind?

    // MARK: - Event Monitors

    private var globalMonitor:
        Any?

    private var localMonitor:
        Any?

    // MARK: - Framework Handles

    private var displayServicesHandle:
        UnsafeMutableRawPointer?

    private var coreDisplayHandle:
        UnsafeMutableRawPointer?

    // MARK: - DisplayServices Types

    private typealias DisplayServicesGetBrightnessFunction =
        @convention(c) (
            CGDirectDisplayID,
            UnsafeMutablePointer<Float>
        ) -> Int32

    private typealias DisplayServicesSetBrightnessFunction =
        @convention(c) (
            CGDirectDisplayID,
            Float
        ) -> Int32

    private typealias DisplayServicesBrightnessChangedFunction =
        @convention(c) (
            CGDirectDisplayID,
            Double
        ) -> Void

    // MARK: - CoreDisplay Types

    private typealias CoreDisplaySetBrightnessFunction =
        @convention(c) (
            CGDirectDisplayID,
            Double
        ) -> Void

    // MARK: - Init

    init() {

        startMonitoring()
    }

    deinit {

        if let globalMonitor {

            NSEvent.removeMonitor(
                globalMonitor
            )
        }

        if let localMonitor {

            NSEvent.removeMonitor(
                localMonitor
            )
        }

        if let displayServicesHandle {

            dlclose(
                displayServicesHandle
            )
        }

        if let coreDisplayHandle {

            dlclose(
                coreDisplayHandle
            )
        }
    }

    // MARK: - Public Presentation

    func showVolume() {

        activeKind =
            .volume

        publishVolume()
    }

    func showBrightness() {

        activeKind =
            .brightness

        if let brightness =
            readBrightness() {

            presentation =
                Presentation(
                    kind:
                        .brightness,
                    value:
                        clamp(
                            brightness
                        ),
                    isMuted:
                        false
                )

        } else {

            presentation =
                Presentation(
                    kind:
                        .brightness,
                    value:
                        presentation?.value
                        ?? 0.5,
                    isMuted:
                        false
                )
        }

        revision &+= 1
    }

    func clear() {

        presentation =
            nil

        activeKind =
            nil
    }

    // MARK: - Public Interaction

    func setCurrentValue(
        _ value:
            Double
    ) {

        let kind =
            presentation?.kind
            ?? activeKind

        guard
            let kind
        else {

            return
        }

        switch kind {

        case .volume:

            setVolume(
                value
            )

        case .brightness:

            setBrightness(
                value
            )
        }
    }

    func toggleMute() {

        guard
            presentation?.kind
            == .volume
        else {

            return
        }

        let currentMute:
            Bool

        if let value =
            readOutputMute() {

            currentMute =
                value

        } else {

            currentMute =
                presentation?.isMuted
                ?? false
        }

        setMuted(
            !currentMute
        )
    }

    // MARK: - Monitoring

    private func startMonitoring() {

        globalMonitor =
            NSEvent.addGlobalMonitorForEvents(
                matching:
                    .systemDefined
            ) { [weak self] event in

                Task { @MainActor in

                    self?
                        .handleSystemEvent(
                            event
                        )
                }
            }

        localMonitor =
            NSEvent.addLocalMonitorForEvents(
                matching:
                    .systemDefined
            ) { [weak self] event in

                Task { @MainActor in

                    self?
                        .handleSystemEvent(
                            event
                        )
                }

                return event
            }
    }

    // MARK: - Hardware Keys

    private func handleSystemEvent(
        _ event:
            NSEvent
    ) {

        guard
            event.subtype.rawValue
            == 8
        else {

            return
        }

        let data =
            event.data1

        let keyCode =
            (data & 0xFFFF0000)
            >> 16

        let keyFlags =
            data
            & 0x0000FFFF

        let keyState =
            (keyFlags & 0xFF00)
            >> 8

        guard
            keyState
            == 0x0A
        else {

            return
        }

        switch keyCode {

        case 0,
             1,
             7:

            scheduleVolumeUpdate()

        case 2,
             3:

            scheduleBrightnessUpdate()

        default:

            break
        }
    }

    private func scheduleVolumeUpdate() {

        DispatchQueue.main.asyncAfter(
            deadline:
                .now() + 0.06
        ) { [weak self] in

            self?
                .publishVolume()
        }
    }

    private func scheduleBrightnessUpdate() {

        DispatchQueue.main.asyncAfter(
            deadline:
                .now() + 0.06
        ) { [weak self] in

            self?
                .publishBrightness()
        }
    }

    // MARK: - Volume Publish

    private func publishVolume() {

        guard
            let rawVolume =
                readOutputVolume()
        else {

            return
        }

        activeKind =
            .volume

        let volume =
            clamp(
                rawVolume
            )

        let muted =
            readOutputMute()
            ?? (volume <= 0.0001)

        presentation =
            Presentation(
                kind:
                    .volume,
                value:
                    volume,
                isMuted:
                    muted
            )

        revision &+= 1
    }

    // MARK: - Volume Read

    private func readOutputVolume()
        -> Double? {

        guard
            let device =
                defaultOutputDevice()
        else {

            return nil
        }

        var address =
            AudioObjectPropertyAddress(
                mSelector:
                    kAudioDevicePropertyVolumeScalar,
                mScope:
                    kAudioDevicePropertyScopeOutput,
                mElement:
                    kAudioObjectPropertyElementMain
            )

        if AudioObjectHasProperty(
            device,
            &address
        ) {

            var value:
                Float32 = 0

            var size =
                UInt32(
                    MemoryLayout<Float32>.size
                )

            let status =
                AudioObjectGetPropertyData(
                    device,
                    &address,
                    0,
                    nil,
                    &size,
                    &value
                )

            if status == noErr {

                return Double(
                    value
                )
            }
        }

        var values:
            [Double] = []

        let channels:
            [AudioObjectPropertyElement] =
                [
                    1,
                    2
                ]

        for channel in channels {

            address =
                AudioObjectPropertyAddress(
                    mSelector:
                        kAudioDevicePropertyVolumeScalar,
                    mScope:
                        kAudioDevicePropertyScopeOutput,
                    mElement:
                        channel
                )

            guard
                AudioObjectHasProperty(
                    device,
                    &address
                )
            else {

                continue
            }

            var value:
                Float32 = 0

            var size =
                UInt32(
                    MemoryLayout<Float32>.size
                )

            let status =
                AudioObjectGetPropertyData(
                    device,
                    &address,
                    0,
                    nil,
                    &size,
                    &value
                )

            if status == noErr {

                values.append(
                    Double(
                        value
                    )
                )
            }
        }

        guard
            !values.isEmpty
        else {

            return nil
        }

        return values.reduce(
            0,
            +
        )
        /
        Double(
            values.count
        )
    }

    // MARK: - Volume Write

    private func setVolume(
        _ value:
            Double
    ) {

        let safeValue =
            clamp(
                value
            )

        guard
            let device =
                defaultOutputDevice()
        else {

            return
        }

        var scalar =
            Float32(
                safeValue
            )

        var address =
            AudioObjectPropertyAddress(
                mSelector:
                    kAudioDevicePropertyVolumeScalar,
                mScope:
                    kAudioDevicePropertyScopeOutput,
                mElement:
                    kAudioObjectPropertyElementMain
            )

        var changed =
            false

        if AudioObjectHasProperty(
            device,
            &address
        ) {

            let status =
                AudioObjectSetPropertyData(
                    device,
                    &address,
                    0,
                    nil,
                    UInt32(
                        MemoryLayout<Float32>.size
                    ),
                    &scalar
                )

            changed =
                status == noErr
        }

        if !changed {

            let channels:
                [AudioObjectPropertyElement] =
                    [
                        1,
                        2
                    ]

            for channel in channels {

                address =
                    AudioObjectPropertyAddress(
                        mSelector:
                            kAudioDevicePropertyVolumeScalar,
                        mScope:
                            kAudioDevicePropertyScopeOutput,
                        mElement:
                            channel
                    )

                guard
                    AudioObjectHasProperty(
                        device,
                        &address
                    )
                else {

                    continue
                }

                var channelScalar =
                    scalar

                let status =
                    AudioObjectSetPropertyData(
                        device,
                        &address,
                        0,
                        nil,
                        UInt32(
                            MemoryLayout<Float32>.size
                        ),
                        &channelScalar
                    )

                if status == noErr {

                    changed =
                        true
                }
            }
        }

        if safeValue > 0.0001 {

            _ =
                writeMute(
                    false
                )
        }

        guard changed else {

            return
        }

        activeKind =
            .volume

        presentation =
            Presentation(
                kind:
                    .volume,
                value:
                    safeValue,
                isMuted:
                    false
            )

        revision &+= 1
    }

    // MARK: - Mute

    private func setMuted(
        _ muted:
            Bool
    ) {

        guard
            writeMute(
                muted
            )
        else {

            return
        }

        let volume =
            readOutputVolume()
            ?? presentation?.value
            ?? 0

        presentation =
            Presentation(
                kind:
                    .volume,
                value:
                    clamp(
                        volume
                    ),
                isMuted:
                    muted
            )

        revision &+= 1
    }

    @discardableResult
    private func writeMute(
        _ muted:
            Bool
    ) -> Bool {

        guard
            let device =
                defaultOutputDevice()
        else {

            return false
        }

        var address =
            AudioObjectPropertyAddress(
                mSelector:
                    kAudioDevicePropertyMute,
                mScope:
                    kAudioDevicePropertyScopeOutput,
                mElement:
                    kAudioObjectPropertyElementMain
            )

        guard
            AudioObjectHasProperty(
                device,
                &address
            )
        else {

            return false
        }

        var value:
            UInt32 =
                muted
                ? 1
                : 0

        let status =
            AudioObjectSetPropertyData(
                device,
                &address,
                0,
                nil,
                UInt32(
                    MemoryLayout<UInt32>.size
                ),
                &value
            )

        return status == noErr
    }

    private func readOutputMute()
        -> Bool? {

        guard
            let device =
                defaultOutputDevice()
        else {

            return nil
        }

        var address =
            AudioObjectPropertyAddress(
                mSelector:
                    kAudioDevicePropertyMute,
                mScope:
                    kAudioDevicePropertyScopeOutput,
                mElement:
                    kAudioObjectPropertyElementMain
            )

        guard
            AudioObjectHasProperty(
                device,
                &address
            )
        else {

            return nil
        }

        var value:
            UInt32 = 0

        var size =
            UInt32(
                MemoryLayout<UInt32>.size
            )

        let status =
            AudioObjectGetPropertyData(
                device,
                &address,
                0,
                nil,
                &size,
                &value
            )

        guard
            status == noErr
        else {

            return nil
        }

        return value != 0
    }

    // MARK: - Output Device

    private func defaultOutputDevice()
        -> AudioDeviceID? {

        var address =
            AudioObjectPropertyAddress(
                mSelector:
                    kAudioHardwarePropertyDefaultOutputDevice,
                mScope:
                    kAudioObjectPropertyScopeGlobal,
                mElement:
                    kAudioObjectPropertyElementMain
            )

        var device =
            AudioDeviceID(
                kAudioObjectUnknown
            )

        var size =
            UInt32(
                MemoryLayout<AudioDeviceID>.size
            )

        let status =
            AudioObjectGetPropertyData(
                AudioObjectID(
                    kAudioObjectSystemObject
                ),
                &address,
                0,
                nil,
                &size,
                &device
            )

        guard
            status == noErr,
            device != kAudioObjectUnknown
        else {

            return nil
        }

        return device
    }

    // MARK: - Brightness Publish

    private func publishBrightness() {

        guard
            let brightness =
                readBrightness()
        else {

            return
        }

        activeKind =
            .brightness

        presentation =
            Presentation(
                kind:
                    .brightness,
                value:
                    clamp(
                        brightness
                    ),
                isMuted:
                    false
            )

        revision &+= 1
    }

    // MARK: - Brightness Read

    private func readBrightness()
        -> Double? {

        guard
            let function =
                displayServicesGetBrightness()
        else {

            print(
                "❌ DisplayServicesGetBrightness non disponibile"
            )

            return nil
        }

        let displayID =
            builtInDisplayID()
            ?? CGMainDisplayID()

        var brightness:
            Float = 0

        let result =
            function(
                displayID,
                &brightness
            )

        guard
            result == 0
        else {

            print(
                "❌ Lettura luminosità fallita:",
                result
            )

            return nil
        }

        return Double(
            brightness
        )
    }

    // MARK: - Brightness Write

    private func setBrightness(
        _ value:
            Double
    ) {

        let safeValue =
            clamp(
                value
            )

        let displayID =
            builtInDisplayID()
            ?? CGMainDisplayID()

        var changed =
            false

        if let function =
            displayServicesSetBrightness() {

            let result =
                function(
                    displayID,
                    Float(
                        safeValue
                    )
                )

            print(
                "☀️ DisplayServicesSetBrightness",
                "display:",
                displayID,
                "value:",
                safeValue,
                "result:",
                result
            )

            if result == 0 {

                changed =
                    true

                notifyBrightnessChanged(
                    displayID:
                        displayID,
                    value:
                        safeValue
                )
            }
        }

        if !changed,
           let fallback =
            coreDisplaySetBrightness() {

            print(
                "☀️ Fallback CoreDisplay",
                "display:",
                displayID,
                "value:",
                safeValue
            )

            fallback(
                displayID,
                safeValue
            )

            changed =
                true

            notifyBrightnessChanged(
                displayID:
                    displayID,
                value:
                    safeValue
            )
        }

        guard changed else {

            print(
                "❌ Impossibile modificare luminosità"
            )

            return
        }

        activeKind =
            .brightness

        presentation =
            Presentation(
                kind:
                    .brightness,
                value:
                    safeValue,
                isMuted:
                    false
            )

        revision &+= 1
    }

    // MARK: - Display

    private func builtInDisplayID()
        -> CGDirectDisplayID? {

        var count:
            UInt32 = 0

        guard
            CGGetActiveDisplayList(
                0,
                nil,
                &count
            ) == .success
        else {

            return nil
        }

        guard
            count > 0
        else {

            return nil
        }

        var displays =
            Array(
                repeating:
                    CGDirectDisplayID(),
                count:
                    Int(
                        count
                    )
            )

        guard
            CGGetActiveDisplayList(
                count,
                &displays,
                &count
            ) == .success
        else {

            return nil
        }

        return displays.first {

            CGDisplayIsBuiltin(
                $0
            ) != 0
        }
    }

    // MARK: - DisplayServices

    private func displayServicesGetBrightness()
        -> DisplayServicesGetBrightnessFunction? {

        guard
            let handle =
                getDisplayServicesHandle()
        else {

            return nil
        }

        guard
            let symbol =
                dlsym(
                    handle,
                    "DisplayServicesGetBrightness"
                )
        else {

            return nil
        }

        return unsafeBitCast(
            symbol,
            to:
                DisplayServicesGetBrightnessFunction.self
        )
    }

    private func displayServicesSetBrightness()
        -> DisplayServicesSetBrightnessFunction? {

        guard
            let handle =
                getDisplayServicesHandle()
        else {

            return nil
        }

        guard
            let symbol =
                dlsym(
                    handle,
                    "DisplayServicesSetBrightness"
                )
        else {

            return nil
        }

        return unsafeBitCast(
            symbol,
            to:
                DisplayServicesSetBrightnessFunction.self
        )
    }

    private func notifyBrightnessChanged(
        displayID:
            CGDirectDisplayID,
        value:
            Double
    ) {

        guard
            let handle =
                getDisplayServicesHandle()
        else {

            return
        }

        guard
            let symbol =
                dlsym(
                    handle,
                    "DisplayServicesBrightnessChanged"
                )
        else {

            return
        }

        let function =
            unsafeBitCast(
                symbol,
                to:
                    DisplayServicesBrightnessChangedFunction.self
            )

        function(
            displayID,
            value
        )
    }

    private func getDisplayServicesHandle()
        -> UnsafeMutableRawPointer? {

        if displayServicesHandle == nil {

            displayServicesHandle =
                dlopen(
                    "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
                    RTLD_LAZY
                )
        }

        return displayServicesHandle
    }

    // MARK: - CoreDisplay

    private func coreDisplaySetBrightness()
        -> CoreDisplaySetBrightnessFunction? {

        guard
            let handle =
                getCoreDisplayHandle()
        else {

            return nil
        }

        guard
            let symbol =
                dlsym(
                    handle,
                    "CoreDisplay_Display_SetUserBrightness"
                )
        else {

            return nil
        }

        return unsafeBitCast(
            symbol,
            to:
                CoreDisplaySetBrightnessFunction.self
        )
    }

    private func getCoreDisplayHandle()
        -> UnsafeMutableRawPointer? {

        if coreDisplayHandle == nil {

            coreDisplayHandle =
                dlopen(
                    "/System/Library/Frameworks/CoreDisplay.framework/CoreDisplay",
                    RTLD_LAZY
                )
        }

        return coreDisplayHandle
    }

    // MARK: - Helpers

    private func clamp(
        _ value:
            Double
    ) -> Double {

        min(
            max(
                value,
                0
            ),
            1
        )
    }
}
