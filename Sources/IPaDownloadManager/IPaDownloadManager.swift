//
//  IPaDownloadManager.swift
//  IPaDownloadManager
//
//  Created by IPa Chen on 2019/4/26.
//

import UIKit
import IPaLog
import IPaSecurity
import IPaFileCache
public typealias IPaDownloadResult = Result<(URLResponse?,URL),Error>
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
    
    open func download(from url:URL,to directory:URL? = nil,headerFields:[String:String]? = nil, useCache:Bool = true) async -> IPaDownloadResult {
        // 檢查快取
        if useCache, let cachedData = IPaFileCache.shared.cacheData(for: url) {
            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
            do {
                try cachedData.write(to: tempURL)
                return .success((nil, tempURL))
            } catch {
                // 快取寫入失敗，繼續下載
            }
        }

        let result: IPaDownloadResult = await withCheckedContinuation { continuation in
            let operation = self.downloadOperation(from: url, to:directory, headerFields:headerFields,complete: {
                result in
                continuation.resume(returning: result)
            })
            self.operationQueue.addOperation(operation)
        }

        return result
    }
    @discardableResult
    open func download(from url:URL,to directory:URL? = nil,headerFields:[String:String]? = nil, useCache:Bool = true, complete:@escaping IPaDownloadCompletedHandler) -> IPaDownloadOperation?  {
        // 檢查快取
        if useCache, let cachedData = IPaFileCache.shared.cacheData(for: url) {
            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
            do {
                try cachedData.write(to: tempURL)
                let response = URLResponse(url: url, mimeType: nil, expectedContentLength: cachedData.count, textEncodingName: nil)
                complete(.success((response, tempURL)))
                return nil
            } catch {
                // 快取寫入失敗，繼續下載
            }
        }

        let operation = self.downloadOperation(from: url, to:directory, headerFields:headerFields,complete: complete)
        self.operationQueue.addOperation(operation)
        return operation
    }
    open func downloadOperation(from url:URL,to directory:URL? = nil,headerFields:[String:String]? = nil,complete:@escaping IPaDownloadCompletedHandler) -> IPaDownloadOperation  {
        let targetDirectory = directory ?? URL(fileURLWithPath:cachePath).appendingPathComponent(url.absoluteString.md5String ?? url.absoluteString.base64UrlString, isDirectory: true)
        
        let operation = IPaDownloadOperation(url: url, session: self.session,headerFields:headerFields,targetDirectory:targetDirectory)
        
        operation.completionBlock = {
            if let loadedFileURL = operation.loadedFileURL,let response = operation.loadedURLResponse {
                // 下載成功後存入快取
                if let data = try? Data(contentsOf: loadedFileURL) {
                    IPaFileCache.shared.setCache(data, for: url)
                }
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
    
    /// 下載圖片並回傳 UIImage。
    /// - 有 cache：直接 return UIImage（同步），complete 不會被呼叫
    /// - 沒有 cache：return nil，下載完成後透過 complete callback 回傳
    @discardableResult
    open func downloadImage(from url:URL, useCache:Bool = true, complete:((UIImage?) -> Void)? = nil) -> UIImage? {
        // 檢查 image cache
        if useCache, let cachedImage = IPaImageCache.shared.cacheImage(for: url) {
            return cachedImage
        }

        // 沒有 cache，啟動下載
        download(from: url, useCache: useCache) { result in
            if let locationUrl = result.locationUrl,
               let data = try? Data(contentsOf: locationUrl),
               let image = UIImage(data: data) {
                IPaImageCache.shared.setCache(image, for: url)
                DispatchQueue.main.async {
                    complete?(image)
                }
            } else {
                DispatchQueue.main.async {
                    complete?(nil)
                }
            }
        }
        return nil
    }

    /// 下載圖片（async 版本），內部自動處理 IPaImageCache。
    open func downloadImage(from url:URL, useCache:Bool = true) async -> UIImage? {
        // 檢查 image cache
        if useCache, let cachedImage = IPaImageCache.shared.cacheImage(for: url) {
            return cachedImage
        }

        let result = await download(from: url, useCache: useCache)
        if let locationUrl = result.locationUrl,
           let data = try? Data(contentsOf: locationUrl),
           let image = UIImage(data: data) {
            IPaImageCache.shared.setCache(image, for: url)
            return image
        }
        return nil
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
