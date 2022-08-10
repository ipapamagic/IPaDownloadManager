//
//  IPaDownloadManager.swift
//  IPaDownloadManager
//
//  Created by IPa Chen on 2019/4/26.
//

import UIKit
import IPaLog
import IPaSecurity
public typealias IPaDownloadCompletedHandler = ((Result<(URLResponse,URL),Error>) ->())
open class IPaDownloadManager: NSObject {
    public let IPaFileDownloadedNotification = Notification.Name(rawValue: "IPaFileDownloadedNotification")
    public let IPaFileDownloadedKeyFileUrl = "IPaFileDownloadedKeyFileUrl"
    public let IPaFileDownloadedKeyFileId = "IPaFileDownloadedKeyFileId"
    static public let shared = IPaDownloadManager()
    public private(set) lazy var operationQueue:OperationQueue = {
        let queue = OperationQueue()
        queue.qualityOfService = .default
        return queue
    }()
    lazy var session:URLSession = URLSession(configuration: URLSessionConfiguration.default)
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
   
//    open func download(from url:URL,fileExt:String,headerFields:[String:String]? = nil,complete:@escaping IPaDownloadCompletedHandler) -> Operation  {
//        return self.download(from: url, to: URL(fileURLWithPath:cacheFilePath(with:url) + ".\(fileExt)"),headerFields:headerFields, complete: complete)
//    }
    @discardableResult
    open func download(from url:URL,to directory:URL? = nil,headerFields:[String:String]? = nil,complete:@escaping IPaDownloadCompletedHandler) -> IPaDownloadOperation  {
        
        let operation = self.downloadOperation(from: url, complete: complete)
        self.operationQueue.addOperation(operation)
        return operation
    }
    open func downloadOperation(from url:URL,to directory:URL? = nil,headerFields:[String:String]? = nil,complete:@escaping IPaDownloadCompletedHandler) -> IPaDownloadOperation  {
        let targetDirectory = directory ?? URL(fileURLWithPath:cachePath)
        
        let operation = IPaDownloadOperation(url: url, session: session,headerFields:headerFields,targetDirectory:targetDirectory)
        
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
    
}
