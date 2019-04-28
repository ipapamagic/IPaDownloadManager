//
//  IPaDownloadManager.swift
//  IPaDownloadManager
//
//  Created by IPa Chen on 2019/4/26.
//

import UIKit
import IPaSecurity
public typealias IPaDownloadCompletedHandler = ((Result<URL,Error>) ->())
open class IPaDownloadManager: NSObject {
    public let IPaFileDownloadedNotification = Notification.Name(rawValue: "IPaFileDownloadedNotification")
    public let IPaFileDownloadedKeyFileUrl = "IPaFileDownloadedKeyFileUrl"
    public let IPaFileDownloadedKeyFileId = "IPaFileDownloadedKeyFileId"
    static public let shared = IPaDownloadManager()
    lazy var operationQueue:OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 3
        return queue
    }()
    lazy var session:URLSession = URLSession(configuration: URLSessionConfiguration.default)
    lazy var cachePath:String = {
        var cachePath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0]
        cachePath = (cachePath as NSString).appendingPathComponent("IPaDownloadCache")
        let fileMgr = FileManager.default
        if !fileMgr.fileExists(atPath: cachePath) {
            var error:NSError?
            do {
                try fileMgr.createDirectory(atPath: cachePath, withIntermediateDirectories: true, attributes: nil)
            } catch let error1 as NSError {
                error = error1
            }
            if let error = error {
                print(error)
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
    func cacheFilePath(with url:URL) -> String {
         return (cachePath as NSString).appendingPathComponent("\(url.absoluteString.md5String!)")
    }
    open func download(from url:URL,fileExt:String,complete:@escaping IPaDownloadCompletedHandler) -> Operation  {
        return self.download(from: url, to: URL(fileURLWithPath:cacheFilePath(with:url) + ".\(fileExt)"), complete: complete)
    }
    open func download(from url:URL,to path:URL? = nil,complete:@escaping IPaDownloadCompletedHandler) -> Operation  {
        let cacheFileUrl = path ?? URL(fileURLWithPath:cacheFilePath(with:url))
        
        let operation = IPaDownloadOperation(url: url, session: session,loadedFileURL:cacheFileUrl)
        
        operation.completionBlock = {
            complete(.success(operation.loadedFileURL))
            
        }
        if let operations = operationQueue.operations as? [IPaDownloadOperation] {
            for workingOperation in operations {
                
                if workingOperation.url.absoluteString == url.absoluteString {
                    operation.addDependency(workingOperation)
                }
            }
        }
        operationQueue.addOperation(operation)
        return operation
    }
    
    open func cancelAllOperation (){
        operationQueue.cancelAllOperations()
    }
    
}
