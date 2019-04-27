//
//  IPaDownloadOperation.swift
//  IPaDownloadManager
//
//  Created by IPa Chen on 2019/4/26.
//

import Foundation
import IPaLog
@objc class IPaDownloadOperation : Operation {
    var loadedFileURL:URL
    let fileId:String
    var request:URLRequest
    var task:URLSessionDownloadTask?
    weak var session:URLSession?
    var _finished:Bool = false
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
    init(request:URLRequest,fileId:String,session:URLSession,loadedFileURL:URL) {
        self.request = request
        self.fileId = fileId
        self.session = session
        self.loadedFileURL = loadedFileURL
    }
    override func start() {
        if isCancelled
        {
            isFinished = true
            return;
        }
        self.willChangeValue(forKey: "isExecuting")
        task = session?.downloadTask(with: request, completionHandler: {(location,response,error) in
            if error == nil {
                if self.isCancelled {
                    IPaLog("IPaDownloadManager:isCancelled")
                    return
                }
                guard let location = location else {
                    return
                }
                //move file to cache first
                
                if FileManager.default.fileExists(atPath: self.loadedFileURL.absoluteString) {
                    try? FileManager.default.removeItem(at: self.loadedFileURL)
                }
                try? FileManager.default.copyItem(at: location, to: self.loadedFileURL)
                
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
