import Foundation
import UIKit
import Flutter

final class NativeDocumentChannel {
    static func register(messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "scanexcel/native_document", binaryMessenger: messenger)
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "detectDocumentCorners":
                guard
                    let args = call.arguments as? [String: Any],
                    let imagePath = args["imagePath"] as? String,
                    let image = UIImage(contentsOfFile: imagePath)
                else {
                    result(FlutterError(code: "bad_args", message: "imagePath is required", details: nil))
                    return
                }
                let width = max(Double(image.size.width), 1)
                let height = max(Double(image.size.height), 1)
                let insetX = width * 0.08
                let insetY = height * 0.06
                result([
                    insetX, insetY,
                    width - insetX, insetY,
                    width - insetX, height - insetY,
                    insetX, height - insetY,
                ])
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
}
