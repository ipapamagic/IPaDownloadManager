//
//  IPaImageURLView.swift
//  IPaImageURLLoader
//
//  Created by IPa Chen on 2015/6/16.
//  Copyright (c) 2015年 AMagicStudio. All rights reserved.
//

import Foundation
import UIKit
import IPaDesignableUI
@objc open class IPaImageURLView : IPaDesignableImageView {
    fileprivate var _imageURL:String?
    fileprivate var _highlightedImageURL:String?
    fileprivate var imageObserver:NSObjectProtocol?
    
    @objc open var imageURL:String? {
        get {
            return _imageURL
        }
        set {
            setImageURL(newValue, defaultImage: nil)
        }
    }
    @objc open var highlightedImageURL:String? {
        get {
            return _highlightedImageURL
        }
        set {
            setHighlightedImageURL(newValue, defaultImage: nil)
        }
    }
    deinit {
        if let imageObserver = imageObserver {
            NotificationCenter.default.removeObserver(imageObserver)
        }
    }
    func createImageObserver () {
        if imageObserver != nil {
            return
        }
        imageObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: IPA_NOTIFICATION_IMAGE_LOADED), object: nil, queue: OperationQueue.main, using: {
            noti in
            
            
            if let userInfo = (noti as NSNotification).userInfo {
                let imageID = userInfo[IPA_NOTIFICATION_KEY_IMAGEID] as! String
                if let imageURL = self.imageURL {
                    if imageID == imageURL {
                        if let data = try? Data(contentsOf: userInfo[IPA_NOTIFICATION_KEY_IMAGEFILEURL] as! URL ) {
                            self.image = UIImage(data: data)
                        }
                    }
                }
                else if let imageURL = self.highlightedImageURL {
                    if imageID == imageURL {
                        if let data = try? Data(contentsOf: userInfo[IPA_NOTIFICATION_KEY_IMAGEFILEURL] as! URL ) {
                            self.highlightedImage = UIImage(data: data)
                        }
                    }
                }
            }
        })
    }
    @objc open func setImageURL(_ imageURL:String?,defaultImage:UIImage?) {
        createImageObserver()
        _imageURL = imageURL
        var image:UIImage?
        if let imageURL = imageURL {
            image = IPaImageURLLoader.sharedInstance.loadImage(url: (imageURL as NSString).addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!, imageID: imageURL)
            
        }
        self.image = (image == nil) ? defaultImage :image
    }
    @objc open func setHighlightedImageURL(_ imageURL:String?,defaultImage:UIImage?) {
        createImageObserver()
        _highlightedImageURL = imageURL
        var image:UIImage?
        if let imageURL = imageURL {
            image = IPaImageURLLoader.sharedInstance.loadImage(url: (imageURL as NSString).addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!, imageID: imageURL)
            
        }
        self.highlightedImage = (image == nil) ? defaultImage :image
    }
    
}
