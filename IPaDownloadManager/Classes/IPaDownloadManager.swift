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
    
    func getCacheURL(with fileId:String) -> URL
    {
        let filePath = (cachePath as NSString).appendingPathComponent("\(fileId.md5String!)")
        return URL(fileURLWithPath: filePath)
    }
    
    open func download(from url:URL,fileId:String,complete:@escaping IPaDownloadCompletedHandler){
        let cacheFileUrl = getCacheURL(with: fileId)
        if FileManager.default.fileExists(atPath: cacheFileUrl.absoluteString) {
            complete(.success(cacheFileUrl))
        }
        else {
            doDownload(url: url, fileId: fileId,cacheFileUrl: cacheFileUrl,complete:complete)
        }
        

    }
    func operation(with fileId:String) -> IPaDownloadOperation? {
        let currentQueue = operationQueue.operations
        return currentQueue.first(where: { (operation) -> Bool in
            guard let downloadOperation = operation as? IPaDownloadOperation else {
                return false
            }
            return downloadOperation.fileId == fileId
        }) as? IPaDownloadOperation
        
    }
 
    
    open func cancelDownload(with fileId:String) {
        if let operation = self.operation(with: fileId) {
            operation.cancel()
        }
    }
    open func cancelAllOperation (){
        operationQueue.cancelAllOperations()
    }
    func doDownload(url:URL,fileId:String,cacheFileUrl:URL,complete:@escaping IPaDownloadCompletedHandler) {
        if let operation = self.operation(with: fileId) {
            if !operation.isCancelled {
                if operation.request.url?.absoluteString != url.absoluteString {
                    operation.cancel()
                }
            }
        }
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        let operation = IPaDownloadOperation(request: request, fileId: fileId, session: session,loadedFileURL:cacheFileUrl)
        operation.completionBlock = {
            complete(.success(operation.loadedFileURL))
        }
        operationQueue.addOperation(operation)
    
    }
}
