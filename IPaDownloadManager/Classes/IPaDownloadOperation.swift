//
//  IPaDownloadOperation.swift
//  IPaDownloadManager
//
//  Created by IPa Chen on 2019/4/26.
//

import Foundation
import IPaLog
@objc class IPaDownloadOperation : Operation {
    var targetDirectory:URL
    var url:URL
    var fileName:String?
    var headerFields:[String:String]?
    var task:URLSessionDownloadTask?
    weak var session:URLSession?
    var _finished:Bool = false
    var loadedFileURL:URL?
    var loadedURLResponse:HTTPURLResponse?
    override var isExecuting:Bool {
        get {
            return !isFinished && (task != nil && task!.state == .running)
        }
        
    }
    
    override var isFinished:Bool {
        get { return _finished }
        set {
            willChangeValue(forKey: "isFinished")
            _finished = newValue
            didChangeValue(forKey: "isFinished")
        }
    }
    override var isConcurrent:Bool {
        get {
            return true
        }
    }
    init(url:URL,session:URLSession,headerFields:[String:String]?,targetDirectory:URL) {
        self.url = url
        self.session = session
        self.headerFields = headerFields
        self.targetDirectory = targetDirectory
    }
    override func start() {
        if isCancelled
        {
            isFinished = true
            return;
        }
        self.willChangeValue(forKey: "isExecuting")
//        if FileManager.default.fileExists(atPath: self.loadedFileURL.absoluteString) {
//
//            self.willChangeValue(forKey: "isExecuting")
//            self.isFinished = true
//            self.didChangeValue(forKey: "isExecuting")
//            return;
//        }
        
        
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        if let headerFields = headerFields {
            for headerField in headerFields.keys {
                request.setValue(headerFields[headerField], forHTTPHeaderField: headerField)
            }
        }
        task = session?.downloadTask(with: request, completionHandler: {(location,response,error) in
            if error == nil {
                if self.isCancelled {
                    IPaLog("IPaDownloadManager:isCancelled")
                    return
                }
                guard let location = location else {
                    return
                }
                if let httpResponse = response as? HTTPURLResponse ,let asciiFileName = httpResponse.suggestedFilename{
                    let byte = asciiFileName.cString(using: .isoLatin1)
                    
                    let fileName = String(cString: byte!, encoding: .utf8)!
                    
                    let loadedFileURL = self.targetDirectory.appendingPathComponent(fileName)
                    try? FileManager.default.copyItem(at: location, to: loadedFileURL)
                    self.loadedFileURL = loadedFileURL
                    self.loadedURLResponse = httpResponse
                    self.fileName = fileName
                }
            }
            else {
                
                IPaLog(error.debugDescription)
                
            }
            self.willChangeValue(forKey: "isExecuting")
            self.isFinished = true
            self.didChangeValue(forKey: "isExecuting")
            
        })
        task?.resume()
        self.didChangeValue(forKey: "isExecuting")
        
    }
    override func cancel() {
        super.cancel()
        if isExecuting {
            self.willChangeValue(forKey: "isExecuting")
            self.isFinished = true
            task?.cancel()
            task = nil
            self.didChangeValue(forKey: "isExecuting")
            
        }
    }
}
