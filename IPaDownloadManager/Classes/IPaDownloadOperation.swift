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
    var url:URL
    var headerFields:[String:String]?
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
    init(url:URL,session:URLSession,headerFields:[String:String]?,loadedFileURL:URL) {
        self.url = url
        self.session = session
        self.headerFields = headerFields
        self.loadedFileURL = loadedFileURL
    }
    override func start() {
        if isCancelled
        {
            isFinished = true
            return;
        }
        self.willChangeValue(forKey: "isExecuting")
        if FileManager.default.fileExists(atPath: self.loadedFileURL.absoluteString) {
            
            self.willChangeValue(forKey: "isExecuting")
            self.isFinished = true
            self.didChangeValue(forKey: "isExecuting")
            return;
        }
        
        
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
