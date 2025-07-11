//
//  IPaDownloadManager.swift
//  IPaDownloadManager
//
//  Created by IPa Chen on 2019/4/26.
//

import UIKit
import IPaLog
import IPaSecurity
public typealias IPaDownloadResult = Result<(URLResponse,URL),Error>
public typealias IPaDownloadCompletedHandler = ((IPaDownloadResult) ->())

extension IPaDownloadResult {
    public var locationUrl:URL? {
        switch self {
        case .success(let (_,url)):
            return url
        case .failure(_):
            return nil
        }
    }
    
}


open class IPaDownloadManager: NSObject {
    static public let shared = IPaDownloadManager()
    public private(set) lazy var operationQueue:OperationQueue = {
        let queue = OperationQueue()
        queue.qualityOfService = .default
        return queue
    }()
    lazy var session:URLSession = URLSession(configuration: URLSessionConfiguration.default,delegate: self, delegateQueue: nil)
    lazy var cachePath:String = {
        var cachePath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0]
        cachePath = (cachePath as NSString).appendingPathComponent("IPaDownloadCache")
        let fileMgr = FileManager.default
        if !fileMgr.fileExists(atPath: cachePath) {
            do {
                try fileMgr.createDirectory(atPath: cachePath, withIntermediateDirectories: true, attributes: nil)
            } catch let error as NSError {
                IPaLog(error.localizedDescription)
            }
            
        }
        return cachePath
    }()
    var maxConcurrent:Int {
        get {
            return operationQueue.maxConcurrentOperationCount
        }
        set {
            operationQueue.maxConcurrentOperationCount = newValue
        }
    }
    public var downloadOperationsData:Data? {
        let operationList = self.operationQueue.operations.compactMap { operation in
            return operation as? IPaDownloadOperation
        }
        return try? JSONEncoder().encode(operationList)
    }
    fileprivate var initContinuation:CheckedContinuation<IPaDownloadManager,Never>? = nil
    fileprivate var initOperationData:Data? = nil
    public override init() {
        super.init()
    }
    
    public init(with configuration: URLSessionConfiguration,operationsData:Data? = nil) {
        super.init()
        self.session = URLSession(configuration: configuration,delegate: self, delegateQueue: nil)
        if let operationsData = operationsData, let operations = try? JSONDecoder().decode([IPaDownloadOperation].self, from: operationsData) {
            for operation in operations {
                self.operationQueue.addOperation(operation)
            }
        }
    }
        
    public init(waitingEventWith configuration: URLSessionConfiguration,operationsData:Data? = nil) async {
        super.init()
        self.initOperationData = operationsData
        _ = await withCheckedContinuation { continuation in
            self.initContinuation = continuation
            self.session = URLSession(configuration: configuration,delegate: self, delegateQueue: nil)
        }
       
    }
    
    open func download(from url:URL,to directory:URL? = nil,headerFields:[String:String]? = nil) async -> IPaDownloadResult {
        await withCheckedContinuation { continuation in
            let operation = self.downloadOperation(from: url, to:directory, headerFields:headerFields,complete: {
                result in
                continuation.resume(returning: result)
            })
            self.operationQueue.addOperation(operation)
        }
    }
    @discardableResult
    open func download(from url:URL,to directory:URL? = nil,headerFields:[String:String]? = nil,complete:@escaping IPaDownloadCompletedHandler) -> IPaDownloadOperation  {
        
        let operation = self.downloadOperation(from: url, to:directory, headerFields:headerFields,complete: complete)
        self.operationQueue.addOperation(operation)
        return operation
    }
    open func downloadOperation(from url:URL,to directory:URL? = nil,headerFields:[String:String]? = nil,complete:@escaping IPaDownloadCompletedHandler) -> IPaDownloadOperation  {
        let targetDirectory = directory ?? URL(fileURLWithPath:cachePath).appendingPathComponent(url.absoluteString.md5String ?? url.absoluteString.base64UrlString, isDirectory: true)
        
        let operation = IPaDownloadOperation(url: url, session: self.session,headerFields:headerFields,targetDirectory:targetDirectory)
        
        operation.completionBlock = {
            if let loadedFileURL = operation.loadedFileURL,let response = operation.loadedURLResponse {
                complete(.success((response,loadedFileURL)))
            }
            else {
                let error = NSError(domain:"IPaDownloadManager", code:-1, userInfo:[NSLocalizedDescriptionKey:"file not loaded! url:\(url)"])
                complete(.failure(error))
            }
            
            
        }
        if let operations = operationQueue.operations as? [IPaDownloadOperation] {
            for workingOperation in operations {
                
                if workingOperation.url.absoluteString == url.absoluteString {
                    operation.addDependency(workingOperation)
                }
            }
        }
        
        return operation
    }
    
    open func cancelAllOperation (){
        operationQueue.cancelAllOperations()
    }
    func operation(for task:URLSessionTask) -> IPaDownloadOperation? {
        return operationQueue.operations.first(where: {
            op in
            guard let op = op as? IPaDownloadOperation else {
                return false
            }
            return op.taskId == task.taskIdentifier
        }) as? IPaDownloadOperation
    }
}
extension IPaDownloadManager:URLSessionDelegate ,URLSessionDownloadDelegate {
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error as? NSError {
            let userInfo = error.userInfo
            self.operation(for: task)?.onHandleTaskDownloadError(error)
            if let _ = userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
            }
        }
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        self.operation(for: downloadTask)?.onHandleTaskDownload(with: downloadTask.response, to: location)
    }
    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        defer {
            self.initContinuation?.resume(returning: self)
            self.initContinuation = nil
            self.initOperationData = nil
        }
        if let operationsData = self.initOperationData {
            let operations = try? JSONDecoder().decode([IPaDownloadOperation].self, from: operationsData)
            session.getTasksWithCompletionHandler { _, _, downloadTasks in
                
                for downloadTask in downloadTasks {
                    guard let operation = operations?.first(where: { op in
                        guard let taskId = op.taskId,taskId == downloadTask.taskIdentifier else {
                            return false
                        }
                        return true
                    }) else {
                        continue
                    }
                    operation.setupTask(downloadTask)
                    self.operationQueue.addOperation(operation)
                }
            }
        }
    }
  
}
