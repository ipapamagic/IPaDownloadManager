//
//  IPaImageURLButton.swift
//  IPaImageURLLoader
//
//  Created by IPa Chen on 2015/6/16.
//  Copyright (c) 2015年 AMagicStudio. All rights reserved.
//

import Foundation
import UIKit
import IPaDesignableUI
@objc open class IPaImageURLButton : IPaDesignableButton {
    private var _imageURL:String?
    private var _backgroundImageURL:String?
    private var imageObserver:NSObjectProtocol?
    @objc open var imageURL:String? {
        get {
            return _imageURL
        }
        set {
            setImageURL(newValue, defaultImage: nil)
        }
    }
    @objc open var backgroundImageURL:String? {
        get {
            return _backgroundImageURL
        }
        set {
            setBackgroundImageURL(newValue, defaultImage: nil)
        }
    }
    deinit {
        if let imageObserver = imageObserver {
            NotificationCenter .default
                .removeObserver(imageObserver)
        }
    }
    func createImageObserver () {
        if imageObserver != nil {
            return
        }
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: IPA_NOTIFICATION_IMAGE_LOADED), object: nil, queue: OperationQueue.main, using: {
            noti in
            if let userInfo = noti.userInfo {
                let imageID = userInfo[IPA_NOTIFICATION_KEY_IMAGEID] as! String
                
                if let imageURL = self.imageURL {
                    if imageID == imageURL {
                        do {
                            let data = try Data(contentsOf: (userInfo[IPA_NOTIFICATION_KEY_IMAGEFILEURL] as! URL))
                            let image = UIImage(data: data)
                            self.setImage(image, for: .normal)
                            
                        }

                        catch {
                            
                        }
                            
                    
                    }
                }
                if let backgroundImageURL = self.backgroundImageURL {
                    if imageID == backgroundImageURL {
                        do {
                            let data = try Data(contentsOf: (userInfo[IPA_NOTIFICATION_KEY_IMAGEFILEURL] as! URL))
                            let image = UIImage(data: data)
                            self.setBackgroundImage(image, for: .normal)
                        }
                        catch {
                            
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
            image = IPaImageURLLoader.sharedInstance.loadImage(url: (imageURL as NSString).addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlQueryAllowed)!, imageID: imageURL)
            
        }
        
        setImage((image == nil) ? defaultImage :image, for: .normal)
    }
    @objc open func setBackgroundImageURL(_ imageURL:String?,defaultImage:UIImage?) {
        createImageObserver()
        _backgroundImageURL = imageURL
        var image:UIImage?
        if let imageURL = imageURL {
            image = IPaImageURLLoader.sharedInstance.loadImage(url: (imageURL as NSString).addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlQueryAllowed)!, imageID: imageURL)
            
        }
        
        setBackgroundImage((image == nil) ? defaultImage :image, for: .normal)
    }
}

