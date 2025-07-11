//
//  IPaDownloadOperation.swift
//  IPaDownloadManager
//
//  Created by IPa Chen on 2019/4/26.
//

import Foundation
import IPaLog
import Combine
@objc open class IPaDownloadOperation : Operation,Codable,ObservableObject, @unchecked Sendable {
    var taskId:Int? = nil
    var targetDirectory:URL
    var url:URL
    var fileName:String?
    var headerFields:[String:String]?
    enum CodingKeys: String, CodingKey {
        case taskId
        case targetDirectory
        case url
        case fileName
        case headerFields
    }
    
    @objc dynamic  public private(set) var task:URLSessionDownloadTask?
    {
        willSet {
            if let progressAnyCancellable = progressAnyCancellable {
                progressAnyCancellable.cancel()
                self.progressAnyCancellable = nil
            }
        }
        didSet {
            self.taskId = task?.taskIdentifier
            if let task = task {
                self.progressAnyCancellable = task.publisher(for: \.progress.fractionCompleted).sink(receiveValue: { progress in
                    self.progress = progress
                })
            }
            else {
                self.progress = 0
            }
        }
    }
    var progressAnyCancellable:AnyCancellable? = nil
    @Published public var progress:Double = 0
    weak var session:URLSession?
    var _finished:Bool = false
    var loadedFileURL:URL?
    var loadedURLResponse:HTTPURLResponse?
    
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
            self.task = nil
            didChangeValue(forKey: "isFinished")
        }
    }
    open override var isConcurrent:Bool {
        get {
            return true
        }
    }
   
    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.taskId = try? values.decode(Int.self, forKey: .taskId)
        self.targetDirectory = try values.decode(URL.self, forKey: .targetDirectory)
        self.url = try values.decode(URL.self, forKey: .url)
        self.fileName = try? values.decode(String.self, forKey: .fileName)
        self.headerFields = try? values.decode([String:String].self, forKey: .headerFields)
        
        super.init()
    }
    init(url:URL,session:URLSession,headerFields:[String:String]?,targetDirectory:URL,task:URLSessionDownloadTask? = nil) {
        self.url = url
        self.session = session
        self.headerFields = headerFields
        self.targetDirectory = targetDirectory
        self.task = task
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let taskId = self.taskId {
            try container.encode(taskId, forKey: .taskId)
        }
        try container.encode(self.targetDirectory, forKey: .targetDirectory)
        try container.encode(self.url, forKey: .url)
        if let fileName = fileName {
            try container.encode(fileName, forKey: .fileName)
        }
        if let headerFields = headerFields {
            try container.encode(headerFields, forKey: .headerFields)
        }
        
    }
    func setupTask(_ downloadTask:URLSessionDownloadTask) {
        self.task = downloadTask
    }
    open override func start() {
        if isCancelled
        {
            isFinished = true
            return;
        }
        
        self.willChangeValue(forKey: "isExecuting")
        defer {
            self.didChangeValue(forKey: "isExecuting")
        }
        if let task = task {
            if task.state == .suspended {
                task.resume()
            }
            
            return
        }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        if let headerFields = headerFields {
            for headerField in headerFields.keys {
                request.setValue(headerFields[headerField], forHTTPHeaderField: headerField)
            }
        }
        task = session?.downloadTask(with: request)

        task?.resume()
        
        
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
    func onHandleTaskDownloadError(_ error:Error) {
        IPaLog(error.localizedDescription)
        self.willChangeValue(forKey: "isExecuting")
        self.isFinished = true
        self.didChangeValue(forKey: "isExecuting")
        
    }
    func onHandleTaskDownload(with response:URLResponse?,to location:URL?) {
        if self.isCancelled {
            IPaLog("IPaDownloadManager:isCancelled")
            return
        }
        if let location = location, let httpResponse = response as? HTTPURLResponse ,let asciiFileName = httpResponse.suggestedFilename{
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
        self.willChangeValue(forKey: "isExecuting")
        self.isFinished = true
        self.didChangeValue(forKey: "isExecuting")
        
    }
}
//extension IPaDownloadOperation:URLSessionTaskDelegate,URLSessionDownloadDelegate {
//    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
//        if let error = error as? NSError {
//            let userInfo = error.userInfo
//            self.onHandleTaskDownloadError(error)
//            if let resumeData = userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
//            }
//        }
//    }
//    
//    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
//        IPaLog("download complete")
//        self.onHandleTaskDownload(with: downloadTask.response, to: location)
//    }
//    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
//        IPaLog("downloading")
//    }
//}
