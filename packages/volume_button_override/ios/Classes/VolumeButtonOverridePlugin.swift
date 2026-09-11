import AVFoundation
import Flutter
import MediaPlayer
import UIKit

public class VolumeButtonOverridePlugin: NSObject, FlutterPlugin {
  private var volumeView: MPVolumeView?
  private var isListening: Bool = false
  private var volumeUpAction: String?
  private var volumeDownAction: String?
  private var channel: FlutterMethodChannel?
  private var initialVolume: Float = 0.5
  private var originalVolume: Float = 0.5
  private var audioSession: AVAudioSession?
  private var volumeObserver: NSKeyValueObservation?
  private var lastButtonPressTime: Date = Date()
  private let debounceInterval: TimeInterval = 0.3
  private var anchorVolume: Float = 0.5
  private var volumeViewGeneration = 0

  private var isSimulator: Bool {
    #if targetEnvironment(simulator)
      return true
    #else
      return false
    #endif
  }

  private let volumeButtonQueue = DispatchQueue(
    label: "com.volume_button_override.volumeQueue", qos: .userInteractive)

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.volume_button_override/channel",
      binaryMessenger: registrar.messenger()
    )
    let instance = VolumeButtonOverridePlugin()
    instance.channel = channel
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "startListening":
      guard let args = call.arguments as? [String: Any] else {
        result(
          FlutterError(
            code: "INVALID_ARGUMENTS",
            message: "Arguments are invalid",
            details: nil
          )
        )
        return
      }
      volumeUpAction = args["volumeUpAction"] as? String
      volumeDownAction = args["volumeDownAction"] as? String

      if isSimulator {
        setupSimulatorControls()
        isListening = true
        result(true)
      } else {
        setupVolumeControl()
        isListening = true
        result(true)
      }

    case "stopListening":
      if isSimulator {
        removeSimulatorControls()
      } else {
        removeVolumeControl()
      }
      isListening = false
      volumeUpAction = nil
      volumeDownAction = nil
      result(true)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func setupSimulatorControls() {
    DispatchQueue.main.async {
      guard let keyWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) else {
        return
      }

      let controlView = UIView(frame: CGRect(x: 0, y: 0, width: 80, height: 160))
      controlView.backgroundColor = UIColor(white: 0.1, alpha: 0.3)
      controlView.layer.cornerRadius = 12
      controlView.tag = 9876

      let upButton = UIButton(type: .system)
      upButton.frame = CGRect(x: 10, y: 10, width: 60, height: 60)
      upButton.setTitle("+", for: .normal)
      upButton.titleLabel?.font = UIFont.systemFont(ofSize: 30)
      upButton.backgroundColor = UIColor.systemGray
      upButton.layer.cornerRadius = 30
      upButton.addTarget(self, action: #selector(self.volumeUpPressed), for: .touchUpInside)

      let downButton = UIButton(type: .system)
      downButton.frame = CGRect(x: 10, y: 90, width: 60, height: 60)
      downButton.setTitle("-", for: .normal)
      downButton.titleLabel?.font = UIFont.systemFont(ofSize: 30)
      downButton.backgroundColor = UIColor.systemGray
      downButton.layer.cornerRadius = 30
      downButton.addTarget(self, action: #selector(self.volumeDownPressed), for: .touchUpInside)

      controlView.addSubview(upButton)
      controlView.addSubview(downButton)

      controlView.frame.origin.x = keyWindow.bounds.width - controlView.frame.width - 20
      controlView.frame.origin.y = keyWindow.bounds.height - controlView.frame.height - 100

      keyWindow.addSubview(controlView)
    }
  }

  @objc private func volumeUpPressed() {
    if shouldHandleButtonPress() {
      if let action = volumeUpAction {
        channel?.invokeMethod("onVolumeButtonPressed", arguments: ["action": action])
      }
    }
  }

  @objc private func volumeDownPressed() {
    if shouldHandleButtonPress() {
      if let action = volumeDownAction {
        channel?.invokeMethod("onVolumeButtonPressed", arguments: ["action": action])
      }
    }
  }

  private func removeSimulatorControls() {
    DispatchQueue.main.async {
      for window in UIApplication.shared.windows {
        for view in window.subviews where view.tag == 9876 {
          view.removeFromSuperview()
        }
      }
    }
  }

  private func shouldHandleButtonPress() -> Bool {
    let now = Date()
    let elapsed = now.timeIntervalSince(lastButtonPressTime)
    if elapsed > debounceInterval {
      lastButtonPressTime = now
      return true
    }
    return false
  }

  private func setupVolumeControl() {
    // Just drop any leftover observer/view from a previous session. Do not go
    // through removeVolumeControl(), whose restore/deferred-removal logic only
    // belongs on the stop path.
    volumeObserver?.invalidate()
    volumeObserver = nil
    volumeView?.removeFromSuperview()
    volumeView = nil

    audioSession = AVAudioSession.sharedInstance()
    do {
      try audioSession?.setCategory(
        .ambient,
        mode: .default,
        options: [.mixWithOthers]
      )
      try audioSession?.setActive(true)

      hideVolumeHUD()

      originalVolume = audioSession?.outputVolume ?? 0.5

      // Anchor the volume near the user's original value instead of a fixed 0.5:
      // keep everyday volumes untouched, and only nudge extreme volumes away from
      // the boundary (at 0 or 1 the pressed direction has no room, so KVO won't fire).
      // Use exact 1/16 steps (0.125 / 0.875) so the restore always lands on a clean
      // value the system reports back verbatim.
      if originalVolume <= 0.05 {
        anchorVolume = 0.125
      } else if originalVolume >= 0.95 {
        anchorVolume = 0.875
      } else {
        anchorVolume = originalVolume
      }

      if originalVolume <= 0.05 || originalVolume >= 0.95 {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
          // Bail out if the reader was already closed before the nudge landed;
          // the off-screen view is removed with a delay, so setSystemVolume would
          // otherwise still touch the volume after removeVolumeControl restored it.
          guard let self = self, self.isListening else { return }
          self.setSystemVolume(self.anchorVolume)
          self.initialVolume = self.anchorVolume
        }
      }

      volumeObserver = audioSession?.observe(
        \.outputVolume,
        options: [.new, .old]
      ) { [weak self] _, change in
        guard let self = self,
          self.isListening,
          let newVol = change.newValue,
          let oldVol = change.oldValue
        else { return }

        // A real hardware press always moves the volume one step further away from
        // the anchor, while a programmatic restore (resetVolume) moves it back toward
        // the anchor. Use this instead of a time-based lock: the old 0.2s lock used
        // to swallow presses made inside the lock window and left the volume stuck
        // off-anchor (e.g. at one bar) where further presses changed nothing.
        if abs(newVol - self.anchorVolume) <= abs(oldVol - self.anchorVolume) {
          return
        }

        if newVol > oldVol {
          DispatchQueue.main.async {
            self.channel?.invokeMethod(
              "onVolumeButtonPressed",
              arguments: ["action": self.volumeUpAction ?? ""]
            )
          }
        } else {
          DispatchQueue.main.async {
            self.channel?.invokeMethod(
              "onVolumeButtonPressed",
              arguments: ["action": self.volumeDownAction ?? ""]
            )
          }
        }

        self.resetVolume()
      }
    } catch {}
  }

  private func hideVolumeHUD() {
    volumeViewGeneration += 1
    let hud = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 1, height: 1))
    hud.alpha = 0.0001
    hud.isHidden = false
    hud.showsRouteButton = false
    hud.showsVolumeSlider = true
    DispatchQueue.main.async { [weak self] in
      guard let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) else {
        return
      }
      window.addSubview(hud)
      self?.volumeView = hud
    }
  }

  private func resetVolume() {
    DispatchQueue.main.async {
      // Guard against running after teardown: a reset queued just before the
      // reader closed must not change the volume once removeVolumeControl has
      // already restored the original value (and the off-screen view is gone).
      guard self.isListening, let hud = self.volumeView else { return }
      for subview in hud.subviews {
        if let slider = subview as? UISlider {
          slider.setValue(self.anchorVolume, animated: false)
          slider.sendActions(for: .valueChanged)
          break
        }
      }
      self.initialVolume = self.anchorVolume
    }
  }

  private func removeVolumeControl() {
    volumeObserver?.invalidate()
    volumeObserver = nil

    // Only restore the original volume when the current volume is still one that
    // we set; if the user changed the volume while the app was in the background,
    // keep theirs. Allow a one-bar (0.0625) tolerance: if the user exits right
    // after pressing a key, the volume can still be a step away from the anchor
    // because the queued resetVolume has not landed yet.
    let currentVolume = audioSession?.outputVolume ?? 0.5
    if abs(currentVolume - anchorVolume) < 0.1 {
      setSystemVolume(originalVolume)
    }

    // Keep the off-screen volume view around briefly so the system volume HUD
    // triggered by the last key press is still suppressed, then remove it.
    // Removing it immediately lets an in-flight HUD presentation pop up right
    // after leaving the reader. The generation guard ignores this block if the
    // reader is re-entered before the delay elapses: setupVolumeControl drops the
    // old view and hideVolumeHUD bumps the generation, so this only ever removes
    // the view it captured.
    let generation = volumeViewGeneration
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
      guard let self = self, self.volumeViewGeneration == generation else { return }
      self.volumeView?.removeFromSuperview()
      self.volumeView = nil
    }
    // Keep the audio session active so the system volume HUD keeps showing after
    // leaving the reader page. Deactivating it would suppress the system volume
    // overlay until some other code re-activates the session.
    audioSession = nil
  }

  private func setSystemVolume(_ level: Float) {
    guard let hud = self.volumeView else { return }
    for subview in hud.subviews {
      if let slider = subview as? UISlider {
        // MPVolumeSlider clamps its minimum to one volume bar (0.0625) by default,
        // which would prevent restoring a muted volume (0.0) via setValue(0).
        if level <= 0.0 {
          slider.minimumValue = 0
        }
        slider.setValue(level, animated: false)
        slider.sendActions(for: .valueChanged)
        break
      }
    }
  }

  deinit {
    if isSimulator {
      removeSimulatorControls()
    } else {
      removeVolumeControl()
    }
  }
}
