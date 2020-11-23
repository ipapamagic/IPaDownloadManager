//
//  IPaDownloadOperation.swift
//  IPaDownloadManager
//
//  Created by IPa Chen on 2019/4/26.
//

import Foundation
import IPaLog
@objc open class IPaDownloadOperation : Operation {
    var targetDirectory:URL
    var url:URL
    var fileName:String?
    var headerFields:[String:String]?
    var downloadTaskObserver:NSKeyValueObservation?
    var task:URLSessionDownloadTask? {
        didSet {
            if let downloadTaskObserver = downloadTaskObserver {
                downloadTaskObserver.invalidate()
                self.downloadTaskObserver = nil
            }
            guard let task = task else {
                
                return
            }
            downloadTaskObserver = task.progress.observe(\.fractionCompleted) {
                (progress,_) in
                self.progress = CGFloat(progress.fractionCompleted)
            }
        }
    }
    open var downloadTask:URLSessionDownloadTask? {
        get {
            return task
        }
    }
    weak var session:URLSession?
    var _finished:Bool = false
    var loadedFileURL:URL?
    var loadedURLResponse:HTTPURLResponse?
    @objc open dynamic var progress:CGFloat = 0
    open override var isExecuting:Bool {
        get {
            return !isFinished && (task != nil && task!.state == .running)
        }
        
    }
    
    open override var isFinished:Bool {
        get { return _finished }
        set {
            willChangeValue(forKey: "isFinished")
            _finished = newValue
            didChangeValue(forKey: "isFinished")
        }
    }
    open override var isConcurrent:Bool {
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
    deinit {
        if let downloadTaskObserver = downloadTaskObserver {
            downloadTaskObserver.invalidate()
            self.downloadTaskObserver = nil
        }
    }
    open override func start() {
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
                    var fileName = asciiFileName
                    if let fileNameData = asciiFileName.data(using: .isoLatin1), let _fileName = String(data: fileNameData, encoding: .utf8) {
                        fileName = _fileName
                    }
                    
                    
                    let urlDir = (self.url.absoluteString as NSString).deletingLastPathComponent.md5String!
                    let loadedDirURL = self.targetDirectory.appendingPathComponent(urlDir)
                    if !FileManager.default.fileExists(atPath: loadedDirURL.absoluteString) {
                        try? FileManager.default.createDirectory(at: loadedDirURL, withIntermediateDirectories: true, attributes: nil)
                    }
                    
                    var loadedFileURL = loadedDirURL.appendingPathComponent(fileName)
                    if FileManager.default.fileExists(atPath: loadedFileURL.absoluteString)
                    {
                        let fileNameWithoutExt = (fileName as NSString).deletingPathExtension
                        var idx = 1
                        var newFileURL:URL
                        repeat {
                            let newFileName = fileNameWithoutExt + "(\(idx))." + (fileName as NSString).pathExtension
                            newFileURL = self.targetDirectory.appendingPathComponent(urlDir).appendingPathComponent(newFileName)
                            idx += 1
                        } while FileManager.default.fileExists(atPath: newFileURL.absoluteString)
                        loadedFileURL = newFileURL
                    }
                    
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
    open override func cancel() {
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
