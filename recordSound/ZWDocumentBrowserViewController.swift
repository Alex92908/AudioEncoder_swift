//
//  ZWDocumentBrowserViewController.swift
//  recordSound
//
//  Created by AlexZhu on 2021/12/24.
//  Copyright © 2021 ZWTech. All rights reserved.
//

import UIKit

class ZWDocumentBrowserViewController: UIDocumentBrowserViewController, UIDocumentBrowserViewControllerDelegate {
    let captureUrl: URL = {
        let temp = FileManager.default.temporaryDirectory
        return temp.appendingPathComponent("outputwav.wav")
    }()

    let mp3Url: URL = {
        let temp = FileManager.default.temporaryDirectory
        return temp.appendingPathComponent("outmp3.mp3")
    }()

    let aacUrl: URL = {
        let temp = FileManager.default.temporaryDirectory
        return temp.appendingPathComponent("outaac.m4a")
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        allowsDocumentCreation = true

        // Do any additional setup after loading the view.
    }

    /*
     // MARK: - Navigation

     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
         // Get the new view controller using segue.destination.
         // Pass the selected object to the new view controller.
     }
     */

    func documentBrowser(_: UIDocumentBrowserViewController, didRequestDocumentCreationWithHandler importHandler: @escaping (URL?, UIDocumentBrowserViewController.ImportMode) -> Void) {
        if FileManager.default.fileExists(atPath: aacUrl.path) {
            importHandler(aacUrl, .copy)
        }
//        if FileManager.default.fileExists(atPath: mp3Url.path) {
//            importHandler(mp3Url, .copy)
//        }
    }
}
