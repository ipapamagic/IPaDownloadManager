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
    var queueList = [String:IPaDownloadOperation]()
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
    
    func getCache(with url:URL) -> URL
    {
        let filePath = (cachePath as NSString).appendingPathComponent("\(url.absoluteString.md5String!)")
        return URL(fileURLWithPath: filePath)
    }
    
    open func download(from url:URL,downloadId:String,complete:@escaping IPaDownloadCompletedHandler){
        let cacheFileUrl = getCache(with: url)
        
        let operation = IPaDownloadOperation(url: url, session: session,loadedFileURL:cacheFileUrl)
        self.queueList[downloadId] = operation
        operation.completionBlock = {
            self.queueList.removeValue(forKey: downloadId)
            complete(.success(operation.loadedFileURL))
            
        }
        guard let operations = operationQueue.operations as? [IPaDownloadOperation] else {
            return
        }
        let targetOperation = queueList[downloadId]
        for workingOperation in operations {
            
            if workingOperation.url.absoluteString == url.absoluteString {
                operation.addDependency(workingOperation)
            }
            else if workingOperation == targetOperation {
                workingOperation.cancel()
            }
            
        }
        operationQueue.addOperation(operation)
    }

 
    
    open func cancelDownload(with downloadId:String) {
        if let operation = self.queueList[downloadId] {
            operation.cancel()
        }
    }
    open func cancelAllOperation (){
        operationQueue.cancelAllOperations()
    }
    
}
